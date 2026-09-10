extends Node
## Procedural locomotion for the Freja deform skeleton.
## No animation clips ship in the glb, so we pose the leg / arm / spine chains
## from a walk phase and blend idle <-> walk <-> run <-> crouch by speed.
##
## All poses are expressed as a local-space rotation applied on top of the bone
## rest pose. Axis signs are tuned against screenshots (see LOCO_TUNE below).

var is_bound := false
var _sk: Skeleton3D
var _model: Node3D

var _b := {}            # logical name -> bone idx
var _rest := {}         # bone idx -> Quaternion (rest)
var _pose := {}         # bone idx -> Quaternion (current, smoothed)

var _phase := 0.0
var _speed_blend := 0.0     # 0 idle .. 1 full run
var _crouch_blend := 0.0
var _model_base_y := 0.0

# swing axis in bone-local space for each joint family
const AX_LEG := Vector3(1, 0, 0)
const AX_LEG_ADD := Vector3(0, 0, 1)   # adduction (bring feet under the hips)
const AX_ARM := Vector3(1, 0, 0)
const AX_ARM_IN := Vector3(0, 0, 1)
const AX_SPINE := Vector3(1, 0, 0)

# amplitude tuning (radians)
const TUNE := {
	"thigh_swing": 0.82,
	"knee_bend": 1.15,
	"knee_base": 0.12,
	"foot_roll": 0.45,
	"arm_swing": 0.62,
	"arm_base": 0.10,       # arms slightly forward at all times
	"arm_in": 0.34,         # tuck arms toward the body (rest is splayed)
	"elbow_bend": 0.55,
	"spine_bob": 0.055,
	"spine_lean_run": 0.2,
	"crouch_thigh": 0.95,
	"crouch_knee": 1.4,
	"crouch_lean": 0.42,
	"crouch_drop": 0.44,    # metres the body lowers
	"bob_height": 0.06,
	"sway_roll": 0.055,
}

const BONES := {
	"thigh_l": "DEF-Thigh_1.L", "thigh_r": "DEF-Thigh_1.R",
	"knee_l": "DEF-Knee_1.L", "knee_r": "DEF-Knee_1.R",
	"foot_l": "DEF-Foot.L", "foot_r": "DEF-Foot.R",
	"arm_l": "DEF-UpperArm_1.L", "arm_r": "DEF-UpperArm_1.R",
	"elbow_l": "DEF-Forearm_1.L", "elbow_r": "DEF-Forearm_1.R",
	"spine1": "DEF-Spine1", "spine2": "DEF-Spine2", "spine3": "DEF-Spine3",
	"head": "DEF-Head",
}

func bind(skeleton: Skeleton3D, model: Node3D) -> void:
	_sk = skeleton
	_model = model
	_model_base_y = model.position.y
	for key in BONES:
		var idx := _sk.find_bone(BONES[key])
		if idx == -1:
			push_warning("locomotion: bone not found " + BONES[key])
			continue
		_b[key] = idx
		_rest[idx] = _sk.get_bone_pose_rotation(idx)
		_pose[idx] = _rest[idx]
	is_bound = true

func update_state(planar_speed: float, target_speed: float, crouching: bool, _grounded: bool, delta: float) -> void:
	if not is_bound:
		return
	var moving := planar_speed > 0.15
	var norm := clampf(planar_speed / 3.4, 0.0, 1.35)
	_speed_blend = lerpf(_speed_blend, norm if moving else 0.0, clampf(8.0 * delta, 0, 1))
	_crouch_blend = lerpf(_crouch_blend, 1.0 if crouching else 0.0, clampf(9.0 * delta, 0, 1))

	# stride frequency scales with speed
	var freq := lerpf(1.7, 2.7, clampf(_speed_blend, 0, 1))
	if _crouch_blend > 0.5:
		freq *= 0.85
	if moving:
		_phase += delta * freq * TAU

	_pose_legs()
	_pose_arms()
	_pose_spine()
	_commit(delta)
	_move_body(delta)

func _swing(base_key: String, ax: Vector3, ang: float) -> void:
	var idx: int = _b.get(base_key, -1)
	if idx == -1:
		return
	_pose[idx] = _rest[idx] * Quaternion(ax, ang)

func _swing2(base_key: String, ax1: Vector3, a1: float, ax2: Vector3, a2: float) -> void:
	var idx: int = _b.get(base_key, -1)
	if idx == -1:
		return
	_pose[idx] = _rest[idx] * Quaternion(ax1, a1) * Quaternion(ax2, a2)

func _pose_legs() -> void:
	var s := sin(_phase)
	var s2 := sin(_phase + PI)
	var sw: float = TUNE["thigh_swing"] * _speed_blend
	var kb: float = TUNE["knee_bend"]

	var crouch_th: float = TUNE["crouch_thigh"] * _crouch_blend
	var crouch_kn: float = TUNE["crouch_knee"] * _crouch_blend

	# thighs: fore/aft swing + a little adduction so the feet track under the hips
	var add: float = 0.05 + 0.04 * _speed_blend
	_swing2("thigh_l", AX_LEG, s * sw - crouch_th, AX_LEG_ADD, add)
	_swing2("thigh_r", AX_LEG, s2 * sw - crouch_th, AX_LEG_ADD, -add)
	# knees bend most as the leg passes under / lifts back
	var kl: float = TUNE["knee_base"] + maxf(0.0, -s) * kb * _speed_blend + crouch_kn
	var kr: float = TUNE["knee_base"] + maxf(0.0, -s2) * kb * _speed_blend + crouch_kn
	_swing("knee_l", AX_LEG, -kl)
	_swing("knee_r", AX_LEG, -kr)
	# ankle counter-roll
	var fr: float = TUNE["foot_roll"]
	_swing("foot_l", AX_LEG, -s * fr * _speed_blend + crouch_th * 0.4)
	_swing("foot_r", AX_LEG, -s2 * fr * _speed_blend + crouch_th * 0.4)

func _pose_arms() -> void:
	var s := sin(_phase)
	var sw: float = TUNE["arm_swing"] * _speed_blend
	var base: float = TUNE["arm_base"]
	var tuck: float = TUNE["arm_in"] + _crouch_blend * 0.15
	# arms counter-swing to legs, tucked toward the torso
	_swing2("arm_l", AX_ARM, -s * sw + base, AX_ARM_IN, -tuck)
	_swing2("arm_r", AX_ARM, s * sw + base, AX_ARM_IN, tuck)
	var eb: float = TUNE["elbow_bend"] * (0.45 + 0.55 * _speed_blend) + _crouch_blend * 0.3
	_swing("elbow_l", AX_ARM, -eb)
	_swing("elbow_r", AX_ARM, -eb)

func _pose_spine() -> void:
	var lean: float = TUNE["spine_lean_run"] * _speed_blend + TUNE["crouch_lean"] * _crouch_blend
	var spine_bob: float = TUNE["spine_bob"]
	var bob: float = sin(_phase * 2.0) * spine_bob * _speed_blend
	_swing("spine1", AX_SPINE, lean * 0.35 + bob)
	_swing("spine2", AX_SPINE, lean * 0.35)
	_swing("spine3", AX_SPINE, lean * 0.3)
	# keep head roughly level
	_swing("head", AX_SPINE, -lean * 0.6)

func _commit(delta: float) -> void:
	var t := clampf(18.0 * delta, 0, 1)
	for idx in _pose:
		var cur := _sk.get_bone_pose_rotation(idx)
		_sk.set_bone_pose_rotation(idx, cur.slerp(_pose[idx], t))

func _move_body(delta: float) -> void:
	var bh: float = TUNE["bob_height"]
	var bob: float = absf(sin(_phase)) * bh * _speed_blend
	var drop: float = TUNE["crouch_drop"] * _crouch_blend
	var target_y: float = _model_base_y + bob - drop
	_model.position.y = lerpf(_model.position.y, target_y, clampf(12.0 * delta, 0, 1))
	var sr: float = TUNE["sway_roll"]
	var roll: float = sin(_phase) * sr * _speed_blend
	_model.rotation.z = lerpf(_model.rotation.z, roll, clampf(10.0 * delta, 0, 1))
