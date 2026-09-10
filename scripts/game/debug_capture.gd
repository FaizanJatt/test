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
	await get_tree().create_timer(1.2).timeout
	await _snap("idle")

	_main.player.set_mobile_move_vector(Vector2(0, -1))
	await get_tree().create_timer(1.3).timeout
	await _snap("walk")

	_main.player.set_sprint_held(true)
	await get_tree().create_timer(1.1).timeout
	await _snap("run")
	_main.player.set_sprint_held(false)

	_main.player.set_crouch_held(true)
	await get_tree().create_timer(1.0).timeout
	await _snap("crouch")
	_main.player.set_crouch_held(false)
	_main.player.set_mobile_move_vector(Vector2.ZERO)
	await get_tree().create_timer(0.6).timeout

	_main.player._cam_rig.add_look(Vector2(150, 6))
	await get_tree().create_timer(0.5).timeout
	await _snap("char_front")

	_main._open_customizer()
	# freeze the turntable at a front 3/4 angle so every outfit is shot the same way
	_main.customizer_screen.set_process(false)
	_main.customizer_screen._preview_cam.global_position = _main.player.global_position + Vector3(1.7, 1.35, 2.7)
	_main.customizer_screen._preview_cam.look_at(_main.player.global_position + Vector3(-0.3, 1.0, 0), Vector3.UP)
	await get_tree().create_timer(0.8).timeout
	await _snap("customizer")

	for oid in [0, 1, 2, 3, 4]:
		_main.customizer_screen._on_outfit_selected(oid)
		await get_tree().create_timer(0.9).timeout
		await _snap("outfit_%d" % oid)

	# appearance tab + a colour change
	_main.customizer_screen._on_outfit_selected(2)
	_main.customizer_screen._tabs.current_tab = 1
	_main.customizer_screen._cfg.hair_color = Color(0.15, 0.5, 0.9)
	_main.customizer_screen._cfg.body["Voluptuous"] = 0.45
	_main.freja.apply_config(_main.customizer_screen._cfg)
	await get_tree().create_timer(0.9).timeout
	await _snap("appearance")

	# toggle pieces off
	_main.customizer_screen._cfg.pieces["gloves"] = false
	_main.customizer_screen._cfg.pieces["boots"] = false
	_main.freja.apply_config(_main.customizer_screen._cfg)
	await get_tree().create_timer(0.7).timeout
	await _snap("pieces_off")

	print("[capture] done, %d shots in %s" % [_shot, _dir])
	get_tree().quit()

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot += 1
	var path := "%s%02d_%s.png" % [_dir, _shot, label]
	img.save_png(path)
	print("[capture] ", path)
