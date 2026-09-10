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

	await _film("walkcycle", Vector2(0, -1), false, false)
	await _film("runcycle", Vector2(0, -1), true, false)
	await _wardrobe_check()
	_done()

## walk past a world-fixed side camera; shoot a run of frames to judge the cycle,
## foot sliding and transition smoothness in motion (no freeze)
func _film(label: String, move: Vector2, sprint: bool, crouch: bool) -> void:
	_player.set_process(true)
	_player.set_physics_process(true)
	_player._cam_rig.set_process(false)
	_player.velocity = Vector3.ZERO
	_player.set_sprint_held(sprint)
	_player.set_crouch_held(crouch)
	_player.set_mobile_move_vector(move)                 # walks along world -Z
	await get_tree().create_timer(0.5).timeout           # spin the cycle up
	_cam.current = true
	for i in 24:
		var f: Vector3 = _freja.global_position
		_cam.global_position = Vector3(f.x + 3.0, 0.55, f.z)   # dead side-on, low, tracking
		_cam.look_at(Vector3(f.x, 0.75, f.z), Vector3.UP)
		await get_tree().create_timer(0.06).timeout
		_foot_trace(label)
		if i % 2 == 0:
			await _snap("%s_%02d" % [label, i / 2])
	_player.set_mobile_move_vector(Vector2.ZERO)
	_player.set_sprint_held(false)

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

var _ft_prevL := Vector3.ZERO
var _ft_prevR := Vector3.ZERO
func _foot_trace(label: String) -> void:
	var sk := _find_skel(_freja)
	if sk == null:
		return
	sk.force_update_all_bone_transforms()
	var gt := sk.global_transform
	var lo := gt * sk.get_bone_global_pose(sk.find_bone("DEF-Foot.L")).origin
	var ro := gt * sk.get_bone_global_pose(sk.find_bone("DEF-Foot.R")).origin
	# horizontal travel of whichever foot is on the ground since the last frame
	var msg := "%s pf.y=%.2f L(y%.3f d%.3f) R(y%.3f d%.3f)" % [label, _player.global_position.y,
		lo.y, Vector2(lo.x - _ft_prevL.x, lo.z - _ft_prevL.z).length() if lo.y < 0.16 and _ft_prevL.y < 0.16 else -1.0,
		ro.y, Vector2(ro.x - _ft_prevR.x, ro.z - _ft_prevR.z).length() if ro.y < 0.16 and _ft_prevR.y < 0.16 else -1.0]
	_dbg(msg)
	_ft_prevL = lo
	_ft_prevR = ro

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null

func _dbg(s: String) -> void:
	var f := FileAccess.open("res://.debug/_dbg.txt", FileAccess.READ_WRITE if FileAccess.file_exists("res://.debug/_dbg.txt") else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(s)
		f.close()

func _done() -> void:
	var f := FileAccess.open("res://.debug/_capture_done.txt", FileAccess.WRITE)
	f.store_string("shots=%d\n" % _shot)
	f.close()
	get_tree().quit()
