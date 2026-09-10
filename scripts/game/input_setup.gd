extends Node
## Autoload "GameInput" - registers all input actions at boot so project.godot
## stays free of version-fragile InputEvent serialization.

const ACTIONS := {
	"move_forward":  [KEY_W, KEY_UP],
	"move_back":     [KEY_S, KEY_DOWN],
	"move_left":     [KEY_A, KEY_LEFT],
	"move_right":    [KEY_D, KEY_RIGHT],
	"sprint":        [KEY_SHIFT],
	"crouch":        [KEY_C, KEY_CTRL],
	"jump":          [KEY_SPACE],
	"toggle_customizer": [KEY_I, KEY_TAB],
	"cam_toggle_shoulder": [KEY_Q],
	"ui_cancel_menu": [KEY_ESCAPE],
}

func _enter_tree() -> void:
	for action_name in ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key in ACTIONS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action_name, ev)
	# Mouse button for camera zoom
	for action_name in ["cam_zoom_in", "cam_zoom_out"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("cam_zoom_in", wheel_up)
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event("cam_zoom_out", wheel_down)
