extends Control
## Full-screen wardrobe / customization UI. Opened from the HUD inventory button.
## Edits a FrejaConfig live and re-applies it to the character. While open it
## frames the real character with an orbiting preview camera.

const Wardrobe := preload("res://scripts/character/wardrobe.gd")

signal closed

var _freja: Node3D
var _cfg: FrejaConfig
var _player: Node3D
var _preview_cam: Camera3D
var _prev_cam: Camera3D
var _orbit := 0.0
var _dim: ColorRect

var _panel: PanelContainer
var _tabs: TabContainer
var _pieces_box: VBoxContainer
var _color_box: VBoxContainer
var _outfit_row: GridContainer

func setup(freja: Node3D, cfg: FrejaConfig) -> void:
	_freja = freja
	_cfg = cfg
	_player = freja.get_parent()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.05, 0.35)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_build_panel()

	_preview_cam = Camera3D.new()
	_preview_cam.fov = 40.0
	_player.get_parent().add_child(_preview_cam)

func _fit_viewport() -> void:
	var vp := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp

func _build_panel() -> void:
	var panel := PanelContainer.new()
	_panel = panel
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -460
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.10, 0.11, 0.14, 0.96)
	psb.set_border_width_all(0)
	psb.border_color = Color(1, 1, 1, 0.12)
	psb.border_width_left = 1
	panel.add_theme_stylebox_override("panel", psb)
	add_child(panel)

	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 22)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "WARDROBE"
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	# --- outfit selector ---
	vb.add_child(_section_label("Outfit"))
	_outfit_row = GridContainer.new()
	_outfit_row.columns = 3
	_outfit_row.add_theme_constant_override("h_separation", 6)
	_outfit_row.add_theme_constant_override("v_separation", 6)
	vb.add_child(_outfit_row)
	for oid in Wardrobe.outfit_ids():
		var b := Button.new()
		b.text = Wardrobe.get_outfit(oid)["name"]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 34
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_outfit_selected.bind(oid))
		_outfit_row.add_child(b)

	# --- tabs: pieces / colours ---
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_tabs)

	var pieces_scroll := ScrollContainer.new()
	pieces_scroll.name = "Pieces"
	pieces_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pieces_box = VBoxContainer.new()
	_pieces_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pieces_box.add_theme_constant_override("separation", 4)
	_pieces_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pieces_scroll.add_child(_pieces_box)
	_tabs.add_child(pieces_scroll)

	var color_scroll := ScrollContainer.new()
	color_scroll.name = "Appearance"
	color_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_color_box = VBoxContainer.new()
	_color_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_box.add_theme_constant_override("separation", 8)
	color_scroll.add_child(_color_box)
	_tabs.add_child(color_scroll)

	# --- footer ---
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	vb.add_child(footer)
	var reset := Button.new()
	reset.text = "Reset Outfit"
	reset.pressed.connect(_reset_pieces)
	footer.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var done := Button.new()
	done.text = "Done  (Esc)"
	done.pressed.connect(_close)
	footer.add_child(done)

func _section_label(t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	return l

# ---------------------------------------------------------------------------
func open() -> void:
	visible = true
	_orbit = 0.0
	if _cfg.pieces.is_empty():
		_cfg.pieces = Wardrobe.default_pieces(_cfg.outfit_id)
	_prev_cam = get_viewport().get_camera_3d()
	_preview_cam.current = true
	_fit_viewport()
	_refresh_all()
	_freja.apply_config(_cfg)
	set_process(true)

func _close() -> void:
	set_process(false)
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	visible = false
	closed.emit()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(_player):
		return
	_orbit += delta * 0.22                    # slow, continuous full 360 turntable
	var focus: Vector3 = _player.global_position + Vector3.UP * 1.05
	var dist := 4.0
	var off := Vector3(sin(_orbit) * dist, 0.35, cos(_orbit) * dist)
	var campos: Vector3 = focus + off + Vector3.UP * 0.1
	_preview_cam.global_position = campos
	# aim right of the character so it sits in the left ~60% of the screen (panel is on the right)
	var view_dir: Vector3 = (focus - campos).normalized()
	var right: Vector3 = view_dir.cross(Vector3.UP).normalized()
	_preview_cam.look_at(focus + right * 0.62 - Vector3.UP * 0.04, Vector3.UP)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel_menu"):
		_close()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
func _on_outfit_selected(oid: int) -> void:
	if _cfg.outfit_id == oid:
		return
	_cfg.outfit_id = oid
	_cfg.pieces = Wardrobe.default_pieces(oid)
	_refresh_all()
	_freja.apply_config(_cfg)

func _reset_pieces() -> void:
	_cfg.pieces = Wardrobe.default_pieces(_cfg.outfit_id)
	_refresh_pieces()
	_freja.apply_config(_cfg)

func _refresh_all() -> void:
	for i in _outfit_row.get_child_count():
		(_outfit_row.get_child(i) as Button).button_pressed = (i == _cfg.outfit_id)
	_refresh_pieces()
	_refresh_colors()

func _refresh_pieces() -> void:
	for c in _pieces_box.get_children():
		c.queue_free()
	for p in Wardrobe.get_outfit(_cfg.outfit_id)["pieces"]:
		var cb := CheckButton.new()
		cb.text = p["label"]
		cb.button_pressed = _cfg.pieces.get(p["id"], p["on"])
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			_cfg.pieces[p["id"]] = on
			_freja.apply_config(_cfg))
		_pieces_box.add_child(cb)

func _refresh_colors() -> void:
	for c in _color_box.get_children():
		c.queue_free()

	if Wardrobe.get_outfit(_cfg.outfit_id).get("has_skin_color", false):
		_color_box.add_child(_section_label("Skin Tone"))
		var opt := OptionButton.new()
		for i in Wardrobe.SKIN_COLORS.size():
			opt.add_item(Wardrobe.SKIN_COLORS[i], i)
		opt.selected = _cfg.skin_color
		opt.item_selected.connect(func(idx):
			_cfg.skin_color = idx
			_freja.apply_config(_cfg))
		_color_box.add_child(opt)

	_color_box.add_child(_section_label("Hair Colour"))
	_color_box.add_child(_color_picker(_cfg.hair_color, func(c):
		_cfg.hair_color = c
		_freja.apply_config(_cfg)))

	_color_box.add_child(_section_label("Eye Colour"))
	_color_box.add_child(_color_picker(_cfg.eye_color, func(c):
		_cfg.eye_color = c
		_freja.apply_config(_cfg)))

	_color_box.add_child(_section_label("Body"))
	for entry in [["Fitness", "Fitness"], ["Curves", "Voluptuous"],
			["Muscle Tone", "BodyTone"], ["Shoulders", "Broad Shoulders"],
			["Thighs", "ThighsSize"], ["Hips", "HipSize"]]:
		_color_box.add_child(_slider(entry[0], _cfg.body.get(entry[1], 0.0), func(v):
			_cfg.body[entry[1]] = v
			_freja.apply_config(_cfg)))

func _color_picker(initial: Color, cb: Callable) -> Control:
	var pb := ColorPickerButton.new()
	pb.color = initial
	pb.custom_minimum_size.y = 30
	pb.edit_alpha = false
	pb.color_changed.connect(func(c): cb.call(c))
	return pb

func _slider(label: String, initial: float, cb: Callable) -> Control:
	var row := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.02
	s.value = initial
	s.custom_minimum_size.y = 20
	s.value_changed.connect(func(v): cb.call(v))
	row.add_child(s)
	return row
