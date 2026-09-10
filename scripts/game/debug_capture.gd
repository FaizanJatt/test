extends Node
## Locomotion QA harness (launch with `--capture`).
##
## For each of idle / walk / run / crouch / crouch-walk it lets the real player
## reach that state, FREEZES the sim, poses the cycle at a chosen phase, then
## orbits a dedicated camera 360 degrees around Freja so we can judge the pose
## from every side. PNGs -> res://.debug/.

var _main: Node
var _player: Node
var _loco: Node
var _freja: Node3D
var _cam: Camera3D
var _shot := 0
const DIR := "res://.debug/"

func _ready() -> void:
	_main = get_parent()
	DirAccess.make_dir_recursive_absolute(DIR)
	_run.call_deferred()

func _run() -> void:
	_player = _main.player
	_freja = _main.freja
	_loco = _player._loco

	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	await get_tree().create_timer(0.4).timeout

	await _state("idle", Vector2.ZERO, false, false, 0.0)
	await _state("walk", Vector2(0, -1), false, false, 1.6)
	await _state("run", Vector2(0, -1), true, false, 1.6)
	await _state("crouch", Vector2.ZERO, false, true, 0.0)
	await _state("crouchwalk", Vector2(0, -1), false, true, 1.6)

	await _wardrobe_check()
	_done()

func _state(label: String, move: Vector2, sprint: bool, crouch: bool, phase: float) -> void:
	_player.set_process(true)
	_player.set_physics_process(true)
	_player._cam_rig.set_process(true)
	_player.set_sprint_held(sprint)
	_player.set_crouch_held(crouch)
	_player.set_mobile_move_vector(move)
	await get_tree().create_timer(1.2).timeout

	# freeze everything and pose a clean frame of the cycle
	_player.set_physics_process(false)
	_player._cam_rig.set_process(false)
	_cam.current = true
	if _loco.is_bound and (move != Vector2.ZERO):
		_loco._phase = phase
		_loco._pose()

	var centre: Vector3 = _freja.global_position + Vector3.UP * (0.85 if crouch else 1.0)
	var radius := 3.1
	var height := 0.35 if crouch else 0.55
	for i in 4:
		var ang := TAU * float(i) / 4.0
		_cam.global_position = centre + Vector3(sin(ang) * radius, height, cos(ang) * radius)
		_cam.look_at(centre, Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await _snap("%s_%d" % [label, int(round(rad_to_deg(ang)))])

func _wardrobe_check() -> void:
	_player.set_physics_process(true)
	_player.set_crouch_held(false)
	_player.set_sprint_held(false)
	_player.set_mobile_move_vector(Vector2.ZERO)
	await get_tree().create_timer(0.6).timeout
	_main._open_customizer()
	_main.customizer_screen.set_process(false)
	await get_tree().create_timer(0.3).timeout
	for oid in [0, 1, 2, 3, 4]:
		_main.customizer_screen._on_outfit_selected(oid)
		var f: Vector3 = _freja.global_position + Vector3.UP
		_cam.current = true
		_cam.global_position = f + Vector3(1.7, 0.15, 3.1)
		_cam.look_at(f, Vector3.UP)
		await get_tree().create_timer(0.35).timeout
		await _snap("outfit_%d" % oid)

func _snap(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_shot += 1
	if img == null:
		push_error("[capture] null image " + label)
		return
	img.save_png("%s%02d_%s.png" % [DIR, _shot, label])

func _done() -> void:
	var f := FileAccess.open("res://.debug/_capture_done.txt", FileAccess.WRITE)
	f.store_string("shots=%d\n" % _shot)
	f.close()
	get_tree().quit()
