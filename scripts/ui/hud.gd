extends CanvasLayer
## In-game HUD: top-right inventory button (opens the customizer), a subtle
## reticle, control hints, and — on touch devices — a movement stick, a look
## pad and action buttons.

const VJoystick := preload("res://scripts/ui/virtual_joystick.gd")

signal inventory_pressed
signal move_input_changed(vector: Vector2)
signal look_input(delta: Vector2)
signal jump_pressed
signal crouch_toggled(pressed: bool)
signal sprint_toggled(pressed: bool)

var _root: Control
var _look_last := Vector2.ZERO
var _look_id := -1

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_inventory_button()
	_build_reticle()
	_build_hints()
	if _is_touch():
		_build_touch_controls()

func _is_touch() -> bool:
	return OS.has_feature("mobile") or "--touch" in OS.get_cmdline_args()

# ---------------------------------------------------------------------------
func _build_inventory_button() -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(60, 60)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.position = Vector2(-76, 16)
	btn.tooltip_text = "Customize (I)"
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.72)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.22)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.16, 0.18, 0.22, 0.85)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)

	var icon := _IconRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	btn.pressed.connect(func(): inventory_pressed.emit())
	_root.add_child(btn)

func _build_reticle() -> void:
	var r := _Reticle.new()
	r.set_anchors_preset(Control.PRESET_CENTER)
	r.custom_minimum_size = Vector2(22, 22)
	r.position = -r.custom_minimum_size * 0.5
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)

func _build_hints() -> void:
	if _is_touch():
		return
	var lbl := Label.new()
	lbl.text = "WASD move   Shift sprint   C crouch   Space jump   Mouse look   Q shoulder   I customize"
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position.y = -30
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)

# ---------------------------------------------------------------------------
func _build_touch_controls() -> void:
	var stick := VJoystick.new()
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.position = Vector2(30, -250)
	stick.custom_minimum_size = Vector2(220, 220)
	stick.size = Vector2(220, 220)
	stick.moved.connect(func(v): move_input_changed.emit(v))
	_root.add_child(stick)

	# right half = look pad
	var look := Control.new()
	look.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	look.anchor_left = 0.42
	look.mouse_filter = Control.MOUSE_FILTER_STOP
	look.gui_input.connect(_on_look_input)
	_root.add_child(look)

	_add_action_button("Jump", Vector2(-110, -230), func(p): if p: jump_pressed.emit())
	_add_action_button("Crouch", Vector2(-110, -150), func(p): crouch_toggled.emit(p), true)
	_add_action_button("Run", Vector2(-210, -190), func(p): sprint_toggled.emit(p), true)

func _add_action_button(text: String, pos: Vector2, cb: Callable, hold := false) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = hold
	b.custom_minimum_size = Vector2(90, 64)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = pos
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.13, 0.6)
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	if hold:
		b.toggled.connect(func(on): cb.call(on))
	else:
		b.button_down.connect(func(): cb.call(true))
		b.button_up.connect(func(): cb.call(false))
	_root.add_child(b)

func _on_look_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _look_id == -1:
			_look_id = event.index
			_look_last = event.position
		elif not event.pressed and event.index == _look_id:
			_look_id = -1
	elif event is InputEventScreenDrag and event.index == _look_id:
		look_input.emit(event.position - _look_last)
		_look_last = event.position

# ---------------------------------------------------------------------------
class _IconRect extends Control:
	func _draw() -> void:
		var col := Color(0.92, 0.94, 0.98)
		var r := Rect2(size * 0.5 - Vector2(15, 13), Vector2(30, 26))
		draw_rect(Rect2(r.position + Vector2(0, 4), r.size - Vector2(0, 4)), col, false, 2.0)
		# lid
		draw_arc(Vector2(size.x * 0.5, r.position.y + 6), 9, PI, TAU, 16, col, 2.0)
		# straps
		draw_line(Vector2(size.x * 0.5 - 5, r.position.y + 3), Vector2(size.x * 0.5 - 5, r.position.y + 12), col, 2.0)
		draw_line(Vector2(size.x * 0.5 + 5, r.position.y + 3), Vector2(size.x * 0.5 + 5, r.position.y + 12), col, 2.0)
		# front pocket
		draw_rect(Rect2(size * 0.5 + Vector2(-8, 4), Vector2(16, 9)), col, false, 1.5)

class _Reticle extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.5)
		draw_circle(c, 2.0, col)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 5, c + d * 10, col, 1.5)
