extends Node
## Screenshot harness. Enabled when the game is launched with `--capture`.
## Drives the player through a scripted sequence and saves PNGs to res://.debug/.

var _main: Node
var _shot := 0
var _dir := "res://.debug/"

func _ready() -> void:
	_main = get_parent()
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	await _snap("idle")

	_main.player.set_mobile_move_vector(Vector2(0, -1))
	await get_tree().create_timer(0.5).timeout
	await _snap("walk")

	_main.player.set_sprint_held(true)
	await get_tree().create_timer(0.5).timeout
	await _snap("run")
	_main.player.set_sprint_held(false)

	_main.player.set_crouch_held(true)
	await get_tree().create_timer(0.5).timeout
	await _snap("crouch")
	_main.player.set_crouch_held(false)
	_main.player.set_mobile_move_vector(Vector2.ZERO)
	await get_tree().create_timer(0.6).timeout

	_main.player._cam_rig.add_look(Vector2(150, 6))
	await get_tree().create_timer(0.5).timeout
	await _snap("char_front")

	_main._open_customizer()
	_main.customizer_screen.set_process(false)
	_main.freja.rotation.y = PI
	_frame_char(Vector3(1.6, 1.1, 3.0))
	await get_tree().create_timer(0.5).timeout
	await _snap("customizer")

	for oid in [0, 1, 2, 3, 4]:
		_main.customizer_screen._on_outfit_selected(oid)
		_frame_char(Vector3(1.6, 1.1, 3.0))
		await get_tree().create_timer(0.5).timeout
		await _snap("outfit_%d" % oid)

	# appearance tab + a colour change
	_main.customizer_screen._on_outfit_selected(2)
	_main.customizer_screen._cfg.hair_color = Color(0.15, 0.5, 0.9)
	_main.customizer_screen._cfg.body["Voluptuous"] = 0.45
	_main.freja.apply_config(_main.customizer_screen._cfg)
	await get_tree().create_timer(0.5).timeout
	await _snap("appearance")

	# every piece off -> should be bare skin + eyes + hair
	_main.customizer_screen._on_outfit_selected(3)
	for p in _main.customizer_screen._cfg.pieces.keys():
		_main.customizer_screen._cfg.pieces[p] = false
	_main.customizer_screen._cfg.pieces["hair"] = true    # keep hair so she's not bald
	_main.freja.apply_config(_main.customizer_screen._cfg)
	_frame_char(Vector3(1.6, 1.1, 3.0))
	await get_tree().create_timer(0.5).timeout
	await _snap("all_pieces_off")

	# head close-up from four sides so we can see the face regardless of facing
	_main.customizer_screen._cfg.pieces["hair"] = false
	_main.customizer_screen._cfg.pieces["sports_bra"] = true
	_main.customizer_screen._cfg.pieces["panties"] = true
	_main.freja.apply_config(_main.customizer_screen._cfg)
	var head: Vector3 = _main.freja.global_position + Vector3.UP * 1.62
	var cam: Camera3D = _main.customizer_screen._preview_cam
	for i in 2:
		var a := PI * i
		cam.global_position = head + Vector3(sin(a), 0.05, cos(a)) * 0.55
		cam.look_at(head, Vector3.UP)
		await get_tree().create_timer(0.3).timeout
		await _snap("head_%d" % i)

	# hand close-up (arm hangs ~ x 0.28, y 0.95 relative to feet)
	var hand: Vector3 = _main.freja.global_position + Vector3(-0.32, 0.92, 0.0)
	for i in 2:
		cam.global_position = hand + Vector3(-0.35 + 0.7 * i, 0.05, 0.4)
		cam.look_at(hand, Vector3.UP)
		await get_tree().create_timer(0.3).timeout
		await _snap("hand_%d" % i)

	print("[capture] done, %d shots in %s" % [_shot, _dir])
	get_tree().quit()

func _frame_char(offset: Vector3) -> void:
	var f: Vector3 = _main.freja.global_position + Vector3.UP * 1.0
	var cam: Camera3D = _main.customizer_screen._preview_cam
	cam.global_position = f + offset
	cam.look_at(f + Vector3(0.25, 0, 0), Vector3.UP)

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot += 1
	var path := "%s%02d_%s.png" % [_dir, _shot, label]
	img.save_png(path)
	print("[capture] ", path)
