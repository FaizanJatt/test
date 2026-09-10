extends Node
## Procedural locomotion for the Freja deform skeleton.
##
## The glb was exported "deform bones only", which left the chain-start bones
## (neck, head, shoulders, upper arms, thighs, finger/toe roots) parented to the
## armature instead of their real parent. Godot's set_bone_parent needs the
## parent to come *before* the child in the bone list, which these violate, so we
## can't re-parent. Instead every frame we FORCE those bones' local pose to
## "intended-parent global pose * rest offset * our animation" - since their real
## parent is the skeleton root, local pose == the world pose we want.

var is_bound := false
var _sk: Skeleton3D
var _model: Node3D

var _phase := 0.0
var _spd := 0.0
var _crouch := 0.0
var _idle_t := 0.0
var _model_base_y := 0.0

const AX_PITCH := Vector3(1, 0, 0)
const FINGER_AXIS := Vector3(0, 0, 1)

@export var thigh_swing := 0.4
@export var arm_tuck := 0.5
@export var arm_swing_gain := 0.9
@export var finger_curl := 0.28
@export var crouch_amount := 1.0   # multiplier for the whole crouch pose

# direct (chained) bones - normal local pose
var _b := {}
var _rest := {}

# managed root bones: name -> {idx, parent_idx, offset:Transform3D}
var _managed := []            # ordered list of dicts
var _adduct := {}

const CHAINED := {
	"knee_l": "DEF-Knee_1.L", "knee_r": "DEF-Knee_1.R",
	"foot_l": "DEF-Foot.L", "foot_r": "DEF-Foot.R",
	"elbow_l": "DEF-Forearm_1.L", "elbow_r": "DEF-Forearm_1.R",
	"spine1": "DEF-Spine1", "spine2": "DEF-Spine2", "spine3": "DEF-Spine3",
	"f2_l": "", "f3_l": "",   # placeholders; finger 2/3 handled by name scan
}

func bind(skeleton: Skeleton3D, model: Node3D) -> void:
	_sk = skeleton
	_model = model
	_model_base_y = model.position.y

	for key in CHAINED:
		if CHAINED[key] == "":
			continue
		var idx := _sk.find_bone(CHAINED[key])
		if idx != -1:
			_b[key] = idx
			_rest[idx] = _sk.get_bone_pose_rotation(idx)

	# managed roots, in dependency order (parent must be resolved first)
	var spec: Array = [
		["DEF-Neck", "DEF-Spine3", "neck"],
		["DEF-Head", "DEF-Neck", "head"],
		["DEF-Shoulder.L", "DEF-Spine3", "static"], ["DEF-Shoulder.R", "DEF-Spine3", "static"],
		["DEF-UpperArm_1.L", "DEF-Shoulder.L", "arm_l"], ["DEF-UpperArm_1.R", "DEF-Shoulder.R", "arm_r"],
		["DEF-Thigh_1.L", "DEF-Spine1", "thigh_l"], ["DEF-Thigh_1.R", "DEF-Spine1", "thigh_r"],
	]
	for fin in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
		for s in [".L", ".R"]:
			spec.append(["DEF-Finger_%s1%s" % [fin, s], "DEF-Wrist" + s, "finger"])
	for fin in ["Index", "Middle", "Ring", "Pinky"]:
		for s in [".L", ".R"]:
			spec.append(["DEF-Finger_%s_Carpal%s" % [fin, s], "DEF-Wrist" + s, "static"])
	for i in _sk.get_bone_count():
		var bn := _sk.get_bone_name(i)
		if bn.begins_with("DEF-Toe") and not bn.begins_with("DEF-Toes"):
			spec.append([bn, "DEF-Foot.R" if bn.ends_with(".R") else "DEF-Foot.L", "static"])

	for e in spec:
		var ci := _sk.find_bone(e[0])
		var pi := _sk.find_bone(e[1])
		if ci == -1 or pi == -1:
			continue
		var off := _sk.get_bone_global_rest(pi).affine_inverse() * _sk.get_bone_global_rest(ci)
		_managed.append({"idx": ci, "parent": pi, "offset": off, "role": e[2]})
		if e[2] == "arm_l" or e[2] == "arm_r":
			var gb := _sk.get_bone_global_rest(ci).basis
			_adduct[ci] = (gb.inverse() * Vector3(0, 0, 1)).normalized()

	# finger 2/3 segments (chained under finger 1) - curl them locally
	for fin in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
		for s in [".L", ".R"]:
			for seg in ["2", "3"]:
				var idx := _sk.find_bone("DEF-Finger_%s%s%s" % [fin, seg, s])
				if idx != -1:
					_b["fseg_%s%s%s" % [fin, seg, s]] = idx
					_rest[idx] = _sk.get_bone_pose_rotation(idx)

	is_bound = true

func update_state(planar_speed: float, _t: float, crouching: bool, _g: bool, delta: float) -> void:
	if not is_bound:
		return
	var moving := planar_speed > 0.2
	var norm := clampf(planar_speed / 4.2, 0.0, 1.0)
	_spd = lerpf(_spd, norm if moving else 0.0, clampf(9.0 * delta, 0, 1))
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, clampf(10.0 * delta, 0, 1))
	_idle_t += delta

	var freq := lerpf(1.55, 2.45, _spd)
	if _crouch > 0.5:
		freq *= 0.85
	if moving:
		_phase = fmod(_phase + delta * freq * TAU, TAU)
	elif _spd < 0.05:
		_phase = lerp_angle(_phase, 0.0, clampf(5.0 * delta, 0, 1))

	_pose_chained()
	_pose_managed()
	_move_body(delta)

# ---------------------------------------------------------------------------
func _pose_chained() -> void:
	var c := _crouch * crouch_amount
	var walk := _spd * (1.0 - _crouch * 0.7)

	# spine lean
	var lean := 0.13 * _spd + 0.3 * c
	_set_local("spine1", Quaternion(AX_PITCH, lean * 0.4))
	_set_local("spine2", Quaternion(AX_PITCH, lean * 0.35))
	_set_local("spine3", Quaternion(AX_PITCH, lean * 0.3))

	# knees
	var knee_amp := lerpf(0.8, 1.2, _spd)
	var lk := 0.08 + knee_amp * walk * clampf(-sin(_phase - 0.6), 0.0, 1.0) + 1.15 * c
	var rk := 0.08 + knee_amp * walk * clampf(-sin(_phase + PI - 0.6), 0.0, 1.0) + 1.15 * c
	_set_local("knee_l", Quaternion(AX_PITCH, -lk))
	_set_local("knee_r", Quaternion(AX_PITCH, -rk))

	# ankles
	var ankle := 0.22 * walk
	_set_local("foot_l", Quaternion(AX_PITCH, -sin(_phase - 0.3) * ankle - 0.3 * c))
	_set_local("foot_r", Quaternion(AX_PITCH, -sin(_phase + PI - 0.3) * ankle - 0.3 * c))

	# elbows
	var elbow := 0.16 + 0.22 * _spd + 0.3 * c
	_set_local("elbow_l", Quaternion(AX_PITCH, -elbow))
	_set_local("elbow_r", Quaternion(AX_PITCH, -elbow))

	# finger 2/3 curl
	for k in _b:
		if k.begins_with("fseg_"):
			_sk.set_bone_pose_rotation(_b[k], _rest[_b[k]] * Quaternion(FINGER_AXIS, finger_curl * 0.9))

func _set_local(key: String, q: Quaternion) -> void:
	var idx: int = _b.get(key, -1)
	if idx != -1:
		_sk.set_bone_pose_rotation(idx, _rest[idx] * q)

# ---------------------------------------------------------------------------
func _pose_managed() -> void:
	var c := _crouch * crouch_amount
	var walk := _spd * (1.0 - _crouch * 0.7)
	var amp := lerpf(0.7, 1.0, _spd) * thigh_swing * clampf(walk * 1.4, 0.0, 1.0)
	var arm_swing := lerpf(0.12, 0.4, _spd) * _spd * arm_swing_gain
	var breathe := sin(_idle_t * 1.6) * 0.02 * (1.0 - _spd)
	var lean := 0.13 * _spd + 0.3 * c

	for m in _managed:
		var q := Quaternion.IDENTITY
		match m["role"]:
			"head":
				q = Quaternion(AX_PITCH, -lean * 0.5)
			"neck":
				q = Quaternion(AX_PITCH, lean * 0.15)
			"arm_l":
				q = Quaternion(_adduct[m["idx"]], -arm_tuck - 0.12 * c) * Quaternion(AX_PITCH, -cos(_phase) * arm_swing + breathe)
			"arm_r":
				q = Quaternion(_adduct[m["idx"]], arm_tuck + 0.12 * c) * Quaternion(AX_PITCH, -cos(_phase + PI) * arm_swing + breathe)
			"thigh_l":
				q = Quaternion(AX_PITCH, cos(_phase) * amp + 0.7 * c)
			"thigh_r":
				q = Quaternion(AX_PITCH, cos(_phase + PI) * amp + 0.7 * c)
			"finger":
				q = Quaternion(FINGER_AXIS, finger_curl + 0.35 * c)
			_:
				pass
		var parent_global: Transform3D = _sk.get_bone_global_pose(m["parent"])
		var target: Transform3D = parent_global * m["offset"] * Transform3D(Basis(q), Vector3.ZERO)
		# the managed bone's real parent is the skeleton root, so local == world
		_sk.set_bone_pose_position(m["idx"], target.origin)
		_sk.set_bone_pose_rotation(m["idx"], target.basis.get_rotation_quaternion())
		_sk.set_bone_pose_scale(m["idx"], target.basis.get_scale())

func _move_body(delta: float) -> void:
	var bob := (0.5 - 0.5 * cos(_phase * 2.0)) * 0.03 * _spd
	var drop := 0.16 * _crouch * crouch_amount
	var y := _model_base_y + bob - drop
	_model.position.y = lerpf(_model.position.y, y, clampf(12.0 * delta, 0, 1))
	var roll := sin(_phase) * 0.035 * _spd
	_model.rotation.z = lerpf(_model.rotation.z, roll, clampf(10.0 * delta, 0, 1))
