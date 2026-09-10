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
const FINGER_AXIS := Vector3(0, 0, 1)

const BONES := {
	"thigh_l": "DEF-Thigh_1.L", "thigh_r": "DEF-Thigh_1.R",
	"knee_l": "DEF-Knee_1.L", "knee_r": "DEF-Knee_1.R",
	"foot_l": "DEF-Foot.L", "foot_r": "DEF-Foot.R",
	"arm_l": "DEF-UpperArm_1.L", "arm_r": "DEF-UpperArm_1.R",
	"elbow_l": "DEF-Forearm_1.L", "elbow_r": "DEF-Forearm_1.R",
	"spine1": "DEF-Spine1", "spine2": "DEF-Spine2", "spine3": "DEF-Spine3",
	"head": "DEF-Head",
}
# the exported rest hand has splayed, slightly-clawed fingers; curl them into a
# soft relaxed hand. Segments 1/2/3 of each finger (skip the carpals).
const FINGER_SEGMENTS := ["DEF-Finger_Index1", "DEF-Finger_Index2", "DEF-Finger_Index3",
	"DEF-Finger_Middle1", "DEF-Finger_Middle2", "DEF-Finger_Middle3",
	"DEF-Finger_Ring1", "DEF-Finger_Ring2", "DEF-Finger_Ring3",
	"DEF-Finger_Pinky1", "DEF-Finger_Pinky2", "DEF-Finger_Pinky3"]
const THUMB_SEGMENTS := ["DEF-Finger_Thumb1", "DEF-Finger_Thumb2", "DEF-Finger_Thumb3"]
var _fingers: Array[int] = []
var _thumbs: Array[int] = []
var _adduct := {}   # arm bone idx -> local axis that adducts toward the body

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
	# per-arm axis that rotates the arm in the frontal plane (adduction)
	for arm_key in ["arm_l", "arm_r"]:
		var ai: int = _b.get(arm_key, -1)
		if ai != -1:
			var gb := _sk.get_bone_global_rest(ai).basis
			_adduct[ai] = (gb.inverse() * Vector3(0, 0, 1)).normalized()
	for i in _sk.get_bone_count():
		var bn := _sk.get_bone_name(i)
		for seg in FINGER_SEGMENTS:
			if bn == seg + ".L" or bn == seg + ".R":
				_fingers.append(i)
				_rest[i] = _sk.get_bone_pose_rotation(i)
		for seg in THUMB_SEGMENTS:
			if bn == seg + ".L" or bn == seg + ".R":
				_thumbs.append(i)
				_rest[i] = _sk.get_bone_pose_rotation(i)
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
@export var thigh_swing := 0.42   # walk stride amplitude (radians, each way)

func _pose_legs() -> void:
	var walk := _spd * (1.0 - _crouch * 0.7)
	var amp := lerpf(0.7, 1.0, _spd) * thigh_swing * clampf(walk * 1.4, 0.0, 1.0)
	var lt := cos(_phase)
	var rt := cos(_phase + PI)
	# a modest shooter-style crouch, not a deep squat
	var crouch_thigh := 0.75 * _crouch
	var crouch_knee := 1.25 * _crouch
	var crouch_ankle := 0.35 * _crouch

	_apply("thigh_l", Quaternion(AX_PITCH, lt * amp + crouch_thigh))
	_apply("thigh_r", Quaternion(AX_PITCH, rt * amp + crouch_thigh))

	# knee bends through the back half of the swing (leg passing under / lifting)
	var knee_amp := lerpf(0.8, 1.2, _spd)
	var lk := 0.1 + knee_amp * walk * clampf(-sin(_phase - 0.6), 0.0, 1.0) + crouch_knee
	var rk := 0.1 + knee_amp * walk * clampf(-sin(_phase + PI - 0.6), 0.0, 1.0) + crouch_knee
	_apply("knee_l", Quaternion(AX_PITCH, -lk))
	_apply("knee_r", Quaternion(AX_PITCH, -rk))

	var ankle := 0.25 * walk
	_apply("foot_l", Quaternion(AX_PITCH, -sin(_phase - 0.3) * ankle - crouch_ankle))
	_apply("foot_r", Quaternion(AX_PITCH, -sin(_phase + PI - 0.3) * ankle - crouch_ankle))

@export var arm_tuck := 0.45   # bring the arms in from the rest A-pose to the sides
@export var arm_swing_gain := 0.9

func _pose_arms() -> void:
	var breathe := sin(_idle_t * 1.6) * 0.02 * (1.0 - _spd)
	var swing := lerpf(0.12, 0.42, _spd) * _spd * arm_swing_gain
	var tuck := arm_tuck + 0.12 * _crouch
	var il: int = _b.get("arm_l", -1)
	var ir: int = _b.get("arm_r", -1)
	if il != -1:
		_pose[il] = _rest[il] * Quaternion(_adduct[il], -tuck) * Quaternion(AX_PITCH, -cos(_phase) * swing + breathe)
	if ir != -1:
		_pose[ir] = _rest[ir] * Quaternion(_adduct[ir], tuck) * Quaternion(AX_PITCH, -cos(_phase + PI) * swing + breathe)
	var elbow := 0.15 + 0.25 * _spd + 0.35 * _crouch
	_apply("elbow_l", Quaternion(AX_PITCH, -elbow))
	_apply("elbow_r", Quaternion(AX_PITCH, -elbow))

func _pose_spine() -> void:
	var lean := 0.14 * _spd + 0.32 * _crouch
	var twist := sin(_phase) * 0.05 * _spd
	var bob := sin(_phase * 2.0) * 0.03 * _spd
	_apply("spine1", Quaternion(AX_PITCH, lean * 0.4 + bob) * Quaternion(Vector3(0, 1, 0), twist))
	_apply("spine2", Quaternion(AX_PITCH, lean * 0.35))
	_apply("spine3", Quaternion(AX_PITCH, lean * 0.25))
	_apply("head", Quaternion(AX_PITCH, -lean * 0.55))

@export var finger_curl := 0.26   # soft relaxed curl per finger segment
@export var thumb_curl := 0.18

func _pose_fingers() -> void:
	var extra := 0.5 * _crouch + 0.25 * _spd
	for i in _fingers:
		_pose[i] = _rest[i] * Quaternion(FINGER_AXIS, finger_curl + extra)
	for i in _thumbs:
		_pose[i] = _rest[i] * Quaternion(FINGER_AXIS, thumb_curl)

# ---------------------------------------------------------------------------
func _commit(delta: float) -> void:
	var t := clampf(16.0 * delta, 0, 1)
	for idx in _pose:
		var cur := _sk.get_bone_pose_rotation(idx)
		_sk.set_bone_pose_rotation(idx, cur.slerp(_pose[idx], t))

func _move_body(delta: float) -> void:
	var bob := (0.5 - 0.5 * cos(_phase * 2.0)) * 0.03 * _spd
	var drop := 0.22 * _crouch
	var y := _model_base_y + bob - drop
	_model.position.y = lerpf(_model.position.y, y, clampf(12.0 * delta, 0, 1))
	var roll := sin(_phase) * 0.04 * _spd
	_model.rotation.z = lerpf(_model.rotation.z, roll, clampf(10.0 * delta, 0, 1))
