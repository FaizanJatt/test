extends Control
## Simple on-screen thumbstick. Emits a normalized Vector2 (y-down screen space).

signal moved(vector: Vector2)

@export var radius := 90.0
@export var deadzone := 0.12

var _touch_id := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed and _touch_id == -1:
			_touch_id = event.get("index") if event is InputEventScreenTouch else 0
			_origin = event.position
			_knob = event.position
			_active = true
			queue_redraw()
		elif not event.pressed and _is_same_touch(event):
			_end()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _active and _is_same_touch(event):
		_knob = event.position
		var off := _knob - _origin
		if off.length() > radius:
			off = off.normalized() * radius
			_knob = _origin + off
		var v := off / radius
		if v.length() < deadzone:
			v = Vector2.ZERO
		moved.emit(v)
		queue_redraw()

func _is_same_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.get("index") == _touch_id
	return true

func _end() -> void:
	_touch_id = -1
	_active = false
	moved.emit(Vector2.ZERO)
	queue_redraw()

func _draw() -> void:
	var c := _origin if _active else size * 0.5
	draw_circle(c, radius, Color(1, 1, 1, 0.10))
	draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	var knob := _knob if _active else c
	draw_circle(knob, radius * 0.42, Color(1, 1, 1, 0.28))
