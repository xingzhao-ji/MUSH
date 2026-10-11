extends Control
## Native joystick reuse plus ID-owned camera/actions. Gameplay touches never reach menus.
const Stick = preload("res://scripts/mobile_stick.gd")
var game: Node3D
var stick_adapter: Control
var owners: Dictionary = {}
var action_rects: Dictionary = {}
var safe_rect := Rect2()
var active := false
var requested := false
var look_id := -1
var stick_id := -1
var _last_context := ""
var _last_mode := ""
var _style: StyleBoxFlat

func configure(clearing: Node3D) -> void:
	game = clearing
	requested = OS.has_feature("android") or OS.has_feature("ios") or "--touch-preview" in OS.get_cmdline_user_args()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stick_adapter = Stick.new()
	add_child(stick_adapter)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.11,0.18,0.14,0.40)
	_style.border_color = Color(0.96,0.90,0.74,0.45)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(28)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	set_active(requested and game.mode in ["explore","garden_place"] and not get_tree().paused and not bool(game.get("_mobile_suspended")) and not bool(game.get("_quitting")))

func _update_safe_area() -> void:
	var viewport_size := get_viewport_rect().size
	var rect := Rect2(Vector2.ZERO,viewport_size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var physical := DisplayServer.get_display_safe_area()
		var scale := get_viewport().get_screen_transform()
		if physical.size.x>0 and physical.size.y>0:
			# ScreenTouch is in viewport coordinates; map the physical safe area through
			# the same screen transform used by canvas stretch, including letterboxing.
			var inverse := scale.affine_inverse()
			var a: Vector2 = inverse * Vector2(physical.position)
			var b: Vector2 = inverse * Vector2(physical.end)
			rect = Rect2(a,b-a).intersection(rect)
	layout_for_rect(rect)

func layout_for_rect(rect: Rect2) -> void:
	if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x<320 or rect.size.y<200: return
	reset_all("layout")
	safe_rect = rect
	var pad_rect := Rect2(rect.position+Vector2(16,rect.size.y*0.50),Vector2(rect.size.x*0.36-16,rect.size.y*0.45))
	stick_adapter.position = pad_rect.position
	stick_adapter.size = pad_rect.size
	var edge := rect.end
	action_rects = {
		"hover":Rect2(edge-Vector2(116,104),Vector2(96,84)),
		"glow":Rect2(edge-Vector2(224,104),Vector2(96,84)),
		"context":Rect2(edge-Vector2(116,200),Vector2(96,84)),
		"decorate":Rect2(edge-Vector2(224,200),Vector2(96,84)),
		"pause":Rect2(Vector2(edge.x-92,rect.position.y+16),Vector2(72,68))
	}
	if game.has_method("_layout_mobile_hud"): game._layout_mobile_hud(rect)
	queue_redraw()

func set_active(value: bool) -> void:
	if active == value and visible == value: return
	active = value
	reset_all("mode")
	visible = value
	stick_adapter.set_active(value)
	if requested:
		Input.emulate_mouse_from_touch = not value
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()

func reset_all(_reason: String = "release") -> void:
	owners.clear()
	look_id = -1
	stick_id = -1
	if is_instance_valid(stick_adapter): stick_adapter.reset_all()
	if is_instance_valid(game) and is_instance_valid(game.player): game.player.set_touch_hover(false)
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	set_active(requested and game.mode in ["explore","garden_place"] and not get_tree().paused and not bool(game.get("_mobile_suspended")) and not bool(game.get("_quitting")))
	if game.context != _last_context or game.mode != _last_mode:
		_last_context = game.context
		_last_mode = game.mode
		queue_redraw()

func _action_visible(action: String) -> bool:
	if action == "context": return not game.context.is_empty() or game.mode == "garden_place"
	if action == "decorate": return game.mode == "explore" and game._inside_home()
	return true

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventScreenTouch:
		var id: int = event.index
		if event.canceled:
			if owners.get(id,"") == "stick" and id == stick_id:
				stick_adapter.reset_all()
				stick_id = -1
			if id == look_id: look_id = -1
			owners.erase(id)
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			if owners.has(id): return
			for action: String in action_rects:
				if _action_visible(action) and action_rects[action].has_point(event.position):
					owners[id] = action
					get_viewport().set_input_as_handled()
					return
			if stick_adapter.get_global_rect().has_point(event.position):
				if stick_id >= 0:
					owners[id] = "blocked"
					get_viewport().set_input_as_handled()
					return
				owners[id] = "stick"
				stick_id = id
				return # The native joystick receives its real GUI touch.
			if safe_rect.has_point(event.position) and event.position.x >= safe_rect.get_center().x and look_id < 0:
				owners[id] = "look"
				look_id = id
			else: owners[id] = "blocked"
			get_viewport().set_input_as_handled()
		else:
			var role: String = owners.get(id,"")
			owners.erase(id)
			if role == "stick":
				stick_id = -1
				return
			if id == look_id: look_id = -1
			if role in action_rects and action_rects[role].has_point(event.position): game._touch_action(role)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var role: String = owners.get(event.index,"")
		if role == "stick": return
		if role == "look" and event.index == look_id:
			game.player.touch_look(event.relative, get_viewport_rect().size.y)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not active or not is_instance_valid(game): return
	var font := ThemeDB.fallback_font
	for action: String in action_rects:
		if not _action_visible(action): continue
		var rect: Rect2 = action_rects[action]
		draw_style_box(_style,rect)
		var label := "Hover" if action == "hover" else "Glow" if action == "glow" else "Home" if action == "decorate" else "Pause" if action == "pause" else "Plant" if game.mode=="garden_place" else "Use"
		var width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		draw_string(font,rect.get_center()+Vector2(-width*0.5,7),label,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("f0ead8"))
