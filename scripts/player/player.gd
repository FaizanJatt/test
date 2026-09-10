extends CharacterBody3D
## PUBG-style third-person controller: camera-relative movement, sprint, crouch,
## jump, gravity. Owns the spring-arm camera and the procedural locomotion driver.

const Locomotion := preload("res://scripts/player/locomotion.gd")
const CameraRig := preload("res://scripts/player/camera_rig.gd")

@export var walk_speed := 2.4
@export var run_speed := 6.2
@export var crouch_speed := 1.5
@export var accel := 14.0
@export var jump_velocity := 6.5
@export var turn_speed := 12.0

var _freja: Node3D
var _loco: Locomotion
var _cam_rig: CameraRig
var _capsule: CollisionShape3D

var _input_enabled := true
var _crouching := false
var _sprint_held := false
var _crouch_held := false
var _want_jump := false
var _mobile_move := Vector2.ZERO
var _mobile_look := Vector2.ZERO
var _yaw_model := 0.0
var _stand_height := 1.75
var _crouch_height := 1.15

func setup(freja: Node3D) -> void:
	_freja = freja

	# collision capsule
	_capsule = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = _stand_height
	_capsule.shape = cap
	_capsule.position.y = _stand_height * 0.5
	add_child(_capsule)

	# camera
	_cam_rig = CameraRig.new()
	_cam_rig.name = "CameraRig"
	add_child(_cam_rig)
	_cam_rig.position.y = 1.5

	# locomotion (deferred until the skeleton exists)
	_loco = Locomotion.new()
	add_child(_loco)
	if _freja.skeleton:
		_loco.bind(_freja.skeleton, _freja)
	else:
		_freja.model_ready.connect(func(): _loco.bind(_freja.skeleton, _freja))

	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_rig.add_look(-event.relative * 0.15)
	elif event.is_action_pressed("cam_zoom_in"):
		_cam_rig.zoom(-0.4)
	elif event.is_action_pressed("cam_zoom_out"):
		_cam_rig.zoom(0.4)
	elif event.is_action_pressed("cam_toggle_shoulder"):
		_cam_rig.toggle_shoulder()
	elif event.is_action_pressed("jump"):
		_want_jump = true

func add_mobile_look(delta: Vector2) -> void:
	if _input_enabled:
		_cam_rig.add_look(delta * Vector2(-0.2, -0.2))

func set_mobile_move_vector(v: Vector2) -> void:
	_mobile_move = v

func request_jump() -> void:
	_want_jump = true

func set_crouch_held(v: bool) -> void:
	_crouch_held = v

func set_sprint_held(v: bool) -> void:
	_sprint_held = v

func set_input_enabled(v: bool) -> void:
	_input_enabled = v
	if not v:
		_mobile_move = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# ---- gather intent ----
	var move_in := Vector2.ZERO
	if _input_enabled:
		move_in = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if move_in == Vector2.ZERO:
			move_in = _mobile_move
	var sprinting := (_input_enabled and Input.is_action_pressed("sprint")) or _sprint_held
	var crouch_want := (_input_enabled and Input.is_action_pressed("crouch")) or _crouch_held
	_set_crouch(crouch_want)

	# ---- camera-relative direction ----
	var cam_basis := _cam_rig.get_yaw_basis()
	var dir := (cam_basis * Vector3(move_in.x, 0, move_in.y)).normalized()
	var has_move := dir.length() > 0.05

	var target_speed := walk_speed
	if _crouching:
		target_speed = crouch_speed
	elif sprinting and has_move and move_in.y <= 0.2:
		target_speed = run_speed

	var horiz := Vector3(velocity.x, 0, velocity.z)
	var desired := dir * target_speed if has_move else Vector3.ZERO
	horiz = horiz.move_toward(desired, accel * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	# ---- gravity + jump ----
	if not on_floor:
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	elif _want_jump and not _crouching:
		velocity.y = jump_velocity
	_want_jump = false

	move_and_slide()

	# ---- face movement direction ----
	if has_move:
		var target_yaw := atan2(-dir.x, -dir.z)
		_yaw_model = lerp_angle(_yaw_model, target_yaw, clampf(turn_speed * delta, 0, 1))
		_freja.rotation.y = _yaw_model

	# ---- feed locomotion ----
	var planar := Vector3(velocity.x, 0, velocity.z).length()
	if _loco.is_bound:
		_loco.update_state(planar, target_speed, _crouching, on_floor, delta)

func _set_crouch(want: bool) -> void:
	if want == _crouching:
		return
	if not want:
		# check headroom before standing
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * _crouch_height,
			global_position + Vector3.UP * (_stand_height + 0.1))
		q.exclude = [self]
		if space.intersect_ray(q):
			return
	_crouching = want
	var cap := _capsule.shape as CapsuleShape3D
	var h := _crouch_height if want else _stand_height
	cap.height = h
	_capsule.position.y = h * 0.5
	_cam_rig.set_crouch(want)
