extends Control
## Reuses Godot4.7.2's joystick; owns only isolated actions and lifecycle reset.
var actions := {"left":"touch_move_left","right":"touch_move_right","up":"touch_move_forward","down":"touch_move_back"}
var stick: Control
var active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_resize)
	for action: String in actions.values():
		if not InputMap.has_action(action): InputMap.add_action(action,0.0)
	_rebuild()

func _rebuild() -> void:
	if is_instance_valid(stick): stick.free()
	stick = ClassDB.instantiate("VirtualJoystick") as Control
	stick.name = "GodotVirtualJoystick"
	stick.size = size
	stick.set("joystick_mode",1)
	stick.set("joystick_size",120.0)
	stick.set("tip_size",46.0)
	stick.set("deadzone_ratio",0.08)
	stick.set("initial_offset_ratio",Vector2(0.35,0.62))
	for direction: String in actions: stick.set("action_"+direction,actions[direction])
	for name: String in ["normal_joystick","pressed_joystick","normal_tip","pressed_tip"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.92,0.87,0.72,0.08 if name.ends_with("joystick") else 0.18)
		style.border_color = Color(0.95,0.90,0.76,0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(80)
		stick.add_theme_stylebox_override(name,style)
	add_child(stick)
	stick.visible = active

func _resize() -> void:
	reset_all()

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	reset_all()
	visible = value

func reset_all() -> void:
	for action: String in actions.values(): Input.action_release(action)
	if is_inside_tree(): _rebuild()

func get_movement() -> Vector2:
	if not active: return Vector2.ZERO
	return Input.get_vector(actions.left,actions.right,actions.up,actions.down,0.0)

func _exit_tree() -> void:
	for action: String in actions.values(): Input.action_release(action)
