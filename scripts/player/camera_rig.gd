extends Node3D
## Third-person spring-arm camera with yaw pivot, pitch clamp, zoom and an
## optional over-the-shoulder offset (PUBG style).

var _yaw := 0.0
var _pitch := -12.0
var _pivot: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _distance := 3.2
var _shoulder := true
var _target_h := 1.5

const PITCH_MIN := -60.0
const PITCH_MAX := 32.0
const SHOULDER_OFFSET := Vector3(0.55, 0.0, 0.0)

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	_arm = SpringArm3D.new()
	_arm.name = "SpringArm"
	_arm.spring_length = _distance
	_arm.margin = 0.3
	_arm.collision_mask = 1
	_pivot.add_child(_arm)

	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.fov = 68.0
	_cam.current = true
	_arm.add_child(_cam)
	_apply_shoulder()

func add_look(delta: Vector2) -> void:
	_yaw = wrapf(_yaw + delta.x, -180.0, 180.0)
	_pitch = clampf(_pitch + delta.y, PITCH_MIN, PITCH_MAX)

func zoom(amount: float) -> void:
	_distance = clampf(_distance + amount, 1.6, 6.0)

func toggle_shoulder() -> void:
	_shoulder = not _shoulder
	_apply_shoulder()

func set_crouch(v: bool) -> void:
	_target_h = 1.05 if v else 1.5

func _apply_shoulder() -> void:
	_cam.position = SHOULDER_OFFSET if _shoulder else Vector3.ZERO

func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_yaw))

func _process(delta: float) -> void:
	position.y = lerpf(position.y, _target_h, clampf(10.0 * delta, 0, 1))
	_pivot.rotation_degrees = Vector3(_pitch, _yaw, 0)
	_arm.spring_length = lerpf(_arm.spring_length, _distance, clampf(8.0 * delta, 0, 1))
