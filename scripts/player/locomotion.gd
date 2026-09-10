extends Node
## Procedural locomotion for the Freja deform skeleton (the glb ships no clips).
## A cosine-driven walk/run cycle plus idle and crouch, all layered on top of the
## bone rest pose. Amplitudes are clamped so fast speeds can't tear the legs apart.

var is_bound := false
var _sk: Skeleton3D
var _model: Node3D

var _b := {}
var _rest := {}
var _pose := {}

var _phase := 0.0
var _spd := 0.0          # 0 idle .. 1 run  (clamped)
var _crouch := 0.0
var _idle_t := 0.0
var _model_base_y := 0.0

# local-space rotation axes (verified against the exported skeleton)
const AX_PITCH := Vector3(1, 0, 0)   # fore/aft swing for legs & arms, bend for knees/elbows
const AX_ROLL := Vector3(0, 0, 1)    # ad/abduction

const BONES := {
	"thigh_l": "DEF-Thigh_1.L", "thigh_r": "DEF-Thigh_1.R",
	"knee_l": "DEF-Knee_1.L", "knee_r": "DEF-Knee_1.R",
	"foot_l": "DEF-Foot.L", "foot_r": "DEF-Foot.R",
	"arm_l": "DEF-UpperArm_1.L", "arm_r": "DEF-UpperArm_1.R",
	"elbow_l": "DEF-Forearm_1.L", "elbow_r": "DEF-Forearm_1.R",
	"spine1": "DEF-Spine1", "spine2": "DEF-Spine2", "spine3": "DEF-Spine3",
	"head": "DEF-Head",
}
# finger chains to un-curl the CloudRig "relaxed" rest grip
const FINGER_PREFIXES := ["DEF-Finger_Index", "DEF-Finger_Middle", "DEF-Finger_Ring",
	"DEF-Finger_Pinky", "DEF-Finger_Thumb"]
var _fingers: Array[int] = []

func bind(skeleton: Skeleton3D, model: Node3D) -> void:
	_sk = skeleton
	_model = model
	_model_base_y = model.position.y
	for key in BONES:
		var idx := _sk.find_bone(BONES[key])
		if idx == -1:
			continue
		_b[key] = idx
		_rest[idx] = _sk.get_bone_pose_rotation(idx)
		_pose[idx] = _rest[idx]
	for i in _sk.get_bone_count():
		var bn := _sk.get_bone_name(i)
		for p in FINGER_PREFIXES:
			if bn.begins_with(p):
				_fingers.append(i)
				_rest[i] = _sk.get_bone_pose_rotation(i)
				break
	is_bound = true

func update_state(planar_speed: float, _target: float, crouching: bool, _grounded: bool, delta: float) -> void:
	if not is_bound:
		return
	var moving := planar_speed > 0.2
	var norm := clampf(planar_speed / 4.2, 0.0, 1.0)
	_spd = lerpf(_spd, norm if moving else 0.0, clampf(9.0 * delta, 0, 1))
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, clampf(10.0 * delta, 0, 1))
	_idle_t += delta

	# stride frequency ~ matches ground speed so the feet barely slide
	var freq := lerpf(1.55, 2.45, _spd)
	if _crouch > 0.5:
		freq *= 0.8
	if moving:
		_phase = fmod(_phase + delta * freq * TAU, TAU)
	elif _spd < 0.05:
		_phase = lerp_angle(_phase, 0.0, clampf(5.0 * delta, 0, 1))

	_pose_legs()
	_pose_arms()
	_pose_spine()
	_pose_fingers()
	_commit(delta)
	_move_body(delta)

func _apply(key: String, q: Quaternion) -> void:
	var idx: int = _b.get(key, -1)
	if idx != -1:
		_pose[idx] = _rest[idx] * q

# ---------------------------------------------------------------------------
func _pose_legs() -> void:
	var walk := _spd * (1.0 - _crouch * 0.6)
	# thigh: forward at phase 0, back at phase PI
	var thigh_amp := lerpf(0.5, 0.72, _spd) * clampf(walk * 1.6, 0.0, 1.0)
	var lt := cos(_phase)
	var rt := cos(_phase + PI)
	var crouch_sit := 0.9 * _crouch          # thighs up when crouching
	var add := 0.06 + 0.03 * _spd            # keep feet under the hips

	_apply("thigh_l", Quaternion(AX_PITCH, lt * thigh_amp - crouch_sit) * Quaternion(AX_ROLL, add))
	_apply("thigh_r", Quaternion(AX_PITCH, rt * thigh_amp - crouch_sit) * Quaternion(AX_ROLL, -add))

	# knee: nearly straight at contact (leg forward), bent through the back swing
	var knee_amp := lerpf(0.9, 1.5, _spd)
	var lk := 0.12 + knee_amp * walk * clampf(-sin(_phase - 0.6), 0.0, 1.0)
	var rk := 0.12 + knee_amp * walk * clampf(-sin(_phase + PI - 0.6), 0.0, 1.0)
	lk += 1.5 * _crouch
	rk += 1.5 * _crouch
	_apply("knee_l", Quaternion(AX_PITCH, -lk))
	_apply("knee_r", Quaternion(AX_PITCH, -rk))

	# ankle: toe-off push at the back of the swing
	var ankle := 0.3 * walk
	_apply("foot_l", Quaternion(AX_PITCH, -sin(_phase - 0.3) * ankle + 0.35 * _crouch))
	_apply("foot_r", Quaternion(AX_PITCH, -sin(_phase + PI - 0.3) * ankle + 0.35 * _crouch))

func _pose_arms() -> void:
	# opposite phase to the legs, tucked to the body, subtle breathing when idle
	var breathe := sin(_idle_t * 1.6) * 0.03 * (1.0 - _spd)
	var swing := lerpf(0.18, 0.5, _spd) * _spd
	var tuck := 0.42 + 0.12 * _crouch
	var la := -cos(_phase) * swing + 0.08 + breathe
	var ra := -cos(_phase + PI) * swing + 0.08 + breathe
	_apply("arm_l", Quaternion(AX_PITCH, la) * Quaternion(AX_ROLL, -tuck))
	_apply("arm_r", Quaternion(AX_PITCH, ra) * Quaternion(AX_ROLL, tuck))
	var elbow := 0.35 + 0.35 * _spd + 0.3 * _crouch
	_apply("elbow_l", Quaternion(AX_PITCH, -elbow))
	_apply("elbow_r", Quaternion(AX_PITCH, -elbow))

func _pose_spine() -> void:
	var lean := 0.16 * _spd + 0.4 * _crouch
	var twist := sin(_phase) * 0.05 * _spd
	var bob := sin(_phase * 2.0) * 0.03 * _spd
	_apply("spine1", Quaternion(AX_PITCH, lean * 0.4 + bob) * Quaternion(Vector3(0, 1, 0), twist))
	_apply("spine2", Quaternion(AX_PITCH, lean * 0.35))
	_apply("spine3", Quaternion(AX_PITCH, lean * 0.25))
	_apply("head", Quaternion(AX_PITCH, -lean * 0.55))

func _pose_fingers() -> void:
	# Relax the claw: rotate each finger segment slightly open around its bend axis.
	for i in _fingers:
		_pose[i] = _rest[i] * Quaternion(AX_PITCH, 0.16)

# ---------------------------------------------------------------------------
func _commit(delta: float) -> void:
	var t := clampf(16.0 * delta, 0, 1)
	for idx in _pose:
		var cur := _sk.get_bone_pose_rotation(idx)
		_sk.set_bone_pose_rotation(idx, cur.slerp(_pose[idx], t))

func _move_body(delta: float) -> void:
	var bob := (0.5 - 0.5 * cos(_phase * 2.0)) * 0.03 * _spd
	var drop := 0.42 * _crouch
	var y := _model_base_y + bob - drop
	_model.position.y = lerpf(_model.position.y, y, clampf(12.0 * delta, 0, 1))
	var roll := sin(_phase) * 0.04 * _spd
	_model.rotation.z = lerpf(_model.rotation.z, roll, clampf(10.0 * delta, 0, 1))
