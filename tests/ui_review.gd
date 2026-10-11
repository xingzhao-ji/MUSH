extends Node
## Real menu rendering and scripted focus visibility checks. No physical input claim.
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(960, 600), Vector2i(1280, 800)]
const MENUS: Array[String] = ["title", "pause", "weather", "settings", "rebinding", "decorating", "plant", "growth"]
const ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "float", "glow", "interact", "decorate", "pause"]
var game: Node
var output: String = ""
var assertions: Array[Dictionary] = []
var views: Array[Dictionary] = []
var focus_checks: Array[Dictionary] = []
var failed: int = 0
var capture_serial: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	_run.call_deferred()

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(arguments.size() - 1):
		if arguments[index] == "--report-dir":
			output = arguments[index + 1]
	if output.is_empty() or not output.is_absolute_path():
		print("UI_REVIEW_REFUSED explicit absolute --report-dir is required")
		game._quit_clean(2)
		return
	if FileAccess.file_exists(output.path_join("ui-review.json")):
		print("UI_REVIEW_REFUSED report already exists")
		game._quit_clean(2)
		return
	var directory_error: int = DirAccess.make_dir_recursive_absolute(output)
	if directory_error != OK:
		print("UI_REVIEW_REFUSED cannot create output directory: ", directory_error)
		game._quit_clean(2)
		return
	_assert(bool(game.verification), "Harness requires verification mode")
	_assert(str(game.store.directory).begins_with("user://verification/"), "Save store remains in a private verification slot", game.store.directory)
	if failed > 0:
		_write_report({})
		game._quit_clean(1)
		return
	var fingerprint_start: Dictionary = _build_fingerprint()
	var window: Window = game.get_window()
	var original_scaling: Dictionary = _scaling_state(window)
	var original_profile: String = str(game.store.directory)
	game.save_timer = -1
	game.ui.show()
	for action: String in ACTIONS:
		Input.action_release(action)
	# Menu inspection freezes only living cosmetics, without substituting a fake UI.
	game.world.set_living_motion_enabled(false)
	game.world.set_appearance(false, false, bool(game.settings.reduced_effects))
	await _frames(4)
	for size: Vector2i in WINDOW_SIZES:
		window.size = size
		await _frames(6)
		_assert(window.size == size, "Native window accepted requested size " + str(size), _vector(window.size))
		_assert(_scaling_state(window) == original_scaling, "Project canvas scaling is unchanged at " + str(size), _scaling_state(window))
		for menu_name: String in MENUS:
			await _show_menu(menu_name)
			await _capture(menu_name, size, "keyboard")
		for menu_name: String in ["settings", "rebinding"]:
			for device: String in ["keyboard", "controller"]:
				game.last_device = device
				await _show_menu(menu_name)
				await _check_focus_visibility(menu_name, size, device)
	_assert(str(game.store.directory) == original_profile, "Menu captures did not redirect the private save slot")
	var fingerprint_end: Dictionary = _build_fingerprint()
	_assert(fingerprint_start == fingerprint_end, "Exported executable and resource packs stayed unchanged")
	_write_report({"initial_scaling": original_scaling, "build_fingerprint": fingerprint_start, "final_build_fingerprint": fingerprint_end, "private_save_slot": original_profile})
	print("UI_REVIEW_COMPLETE ", JSON.stringify({"passed": failed == 0, "assertions": assertions.size(), "failed": failed, "views": views.size(), "focus_checks": focus_checks.size()}))
	game._quit_clean(0 if failed == 0 else 1)

func _show_menu(menu_name: String) -> void:
	# Cancel real uncommitted previews before opening the next actual menu.
	if game.mode != "title":
		game._pause()
	game._explore()
	game.last_device = "keyboard"
	if menu_name == "decorating":
		game.player.teleport_safe(Vector3(0, 0.6, 0))
		await _physics_frames(6)
	match menu_name:
		"title": game._title()
		"pause": game._pause()
		"weather": game._appearance_menu()
		"settings": game._settings_menu()
		"rebinding": game._controls_menu()
		"decorating": game._decorate_menu()
		"plant": game._plant_menu(false)
		"growth": game._growth_menu()
	await _frames(5)
	_assert(game.modal.visible and get_tree().paused, "Actual " + menu_name + " menu is visible and pauses gameplay", {"mode": game.mode, "paused": get_tree().paused})

func _check_focus_visibility(menu_name: String, size: Vector2i, device: String) -> void:
	game.last_device = device
	var scroll: ScrollContainer = _scroll()
	var controls: Array[Control] = []
	for child: Node in game.content.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			if child is BaseButton and child.disabled:
				continue
			controls.append(child as Control)
	_assert(not controls.is_empty(), menu_name + " has focusable controls")
	if controls.is_empty(): return
	var first: Control = controls[0]
	var last: Control = controls[controls.size() - 1]
	scroll.scroll_vertical = 0
	first.grab_focus()
	await _frames(4)
	var scroll_rect: Rect2 = scroll.get_global_rect()
	var last_before: Rect2 = last.get_global_rect()
	var offscreen_before: bool = not _contains(scroll_rect, last_before, 1.0)
	last.grab_focus()
	await _frames(5)
	var last_after: Rect2 = last.get_global_rect()
	var last_visible: bool = _contains(scroll.get_global_rect(), last_after, 1.0)
	_assert(get_viewport().gui_get_focus_owner() == last, menu_name + " last control receives scripted focus for " + device)
	_assert(last_visible, menu_name + " last focused control is wholly visible for " + device, {"scroll_rect": _rect(scroll.get_global_rect()), "control_rect": _rect(last_after), "scroll_vertical": scroll.scroll_vertical, "offscreen_before": offscreen_before})
	if offscreen_before:
		_assert(scroll.scroll_vertical > 0, menu_name + " focus automatically scrolls an initially clipped control for " + device, scroll.scroll_vertical)
	elif menu_name == "rebinding":
		_assert(false, "Rebinding fixture must exercise a genuinely off-screen lower control", {"last_rect": _rect(last_before), "scroll_rect": _rect(scroll_rect)})
	await _capture(menu_name + "-focus-last", size, device)
	var scroll_at_last: int = scroll.scroll_vertical
	game._focus_first()
	await _frames(5)
	_assert(get_viewport().gui_get_focus_owner() == first, menu_name + " first control receives scripted return focus for " + device)
	_assert(_contains(scroll.get_global_rect(), first.get_global_rect(), 1.0), menu_name + " first focused control scrolls back into view for " + device, {"scroll_vertical": scroll.scroll_vertical, "first_rect": _rect(first.get_global_rect()), "scroll_rect": _rect(scroll.get_global_rect())})
	var scroll_at_first: int = scroll.scroll_vertical
	if offscreen_before:
		_assert(scroll_at_first < scroll_at_last, menu_name + " returning first-control focus scrolls toward the top for " + device, {"at_last": scroll_at_last, "at_first": scroll_at_first})
	_assert(scroll.scroll_vertical == 0 and _contains(scroll.get_global_rect(), first.get_global_rect(), 1.0), menu_name + " production first-control focus restores the menu top and heading for " + device, scroll.scroll_vertical)
	await _capture(menu_name + "-focus-first", size, device)
	focus_checks.append({"menu": menu_name, "requested_window_size": _vector(size), "hint_device_mode": device, "focus_input_kind": "scripted_Control.grab_focus and production _focus_first", "last_control_text": _control_text(last), "last_initially_offscreen": offscreen_before, "last_visible_after_focus": last_visible, "scroll_at_last_focus": scroll_at_last, "scroll_at_first_focus": scroll_at_first, "physical_keyboard_or_controller_tested": false})

func _capture(menu_name: String, requested_size: Vector2i, device: String) -> void:
	var root: Control = game.ui.get_child(0) as Control
	var scroll: ScrollContainer = _scroll()
	var logical_viewport: Rect2 = root.get_global_rect()
	var modal_rect: Rect2 = game.modal.get_global_rect()
	_assert(logical_viewport.size.x > 0 and logical_viewport.size.y > 0, "UI root has a positive logical visible viewport")
	_assert(_contains(logical_viewport, modal_rect, 1.0), menu_name + " modal is contained in its logical visible viewport at " + str(requested_size), {"logical_viewport": _rect(logical_viewport), "modal_rect": _rect(modal_rect)})
	_assert(scroll.clip_contents and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, menu_name + " scroll clips overflowing rows and disables horizontal scrolling")
	_assert(scroll.follow_focus, menu_name + " scroll follows keyboard/controller focus")
	_assert(_contains(modal_rect, scroll.get_global_rect(), 1.0), menu_name + " scroll viewport stays inside the modal")
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var filename: String = "%dx%d-%02d-%s-%s.png" % [requested_size.x, requested_size.y, capture_serial, menu_name, device]
	capture_serial += 1
	var fresh: bool = not FileAccess.file_exists(output.path_join(filename))
	_assert(fresh, "PNG output is fresh: " + filename)
	if not fresh: return
	var save_result: int = frame.save_png(output.path_join(filename))
	_assert(save_result == OK, "Actual rendered PNG was written: " + filename, save_result)
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(frame.get_data())
	var focus: Control = get_viewport().gui_get_focus_owner()
	views.append({"file": filename, "menu": menu_name, "mode": game.mode, "requested_window_size": _vector(requested_size), "actual_window_size": _vector(game.get_window().size), "texture_size": _vector(frame.get_size()), "viewport_visible_rect": _rect(get_viewport().get_visible_rect()), "logical_visible_viewport_authority": "full-rect UI root Control", "ui_root_logical_rect": _rect(logical_viewport), "modal_logical_rect": _rect(modal_rect), "scroll_logical_rect": _rect(scroll.get_global_rect()), "scroll_vertical": scroll.scroll_vertical, "scroll_max_value": scroll.get_v_scroll_bar().max_value, "scroll_page": scroll.get_v_scroll_bar().page, "clip_contents": scroll.clip_contents, "follow_focus": scroll.follow_focus, "canvas_transform": _transform(root.get_canvas_transform()), "ui_root_global_transform_with_canvas": _transform(root.get_global_transform_with_canvas()), "modal_global_transform_with_canvas": _transform(game.modal.get_global_transform_with_canvas()), "focus_owner_text": _control_text(focus), "hint_device_mode": device, "rgba_sha256": hash.finish().hex_encode(), "png_sha256": FileAccess.get_sha256(output.path_join(filename)), "png_save_result": save_result})

func _scroll() -> ScrollContainer:
	return game.modal.get_child(0) as ScrollContainer

func _scaling_state(window: Window) -> Dictionary:
	return {"content_scale_size": _vector(window.content_scale_size), "content_scale_factor": window.content_scale_factor, "content_scale_mode": int(window.content_scale_mode), "content_scale_aspect": int(window.content_scale_aspect)}

func _contains(outer: Rect2, inner: Rect2, tolerance: float = 0.0) -> bool:
	return outer.grow(tolerance).encloses(inner)

func _control_text(control: Control) -> String:
	if control == null: return ""
	if control is BaseButton: return (control as BaseButton).text
	if control is Label: return (control as Label).text
	return str(control.name)

func _vector(value: Variant) -> Array:
	return [value.x, value.y]

func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

func _transform(value: Transform2D) -> Array:
	return [value.x.x, value.x.y, value.y.x, value.y.y, value.origin.x, value.origin.y]

func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func _physics_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame

func _assert(condition: bool, message: String, observed: Variant = null) -> void:
	assertions.append({"passed": condition, "message": message, "observed": observed})
	if not condition:
		failed += 1
		print("UI_REVIEW_ASSERTION_FAILED ", message, " ", JSON.stringify(observed))

func _build_fingerprint() -> Dictionary:
	if OS.has_feature("editor"):
		var source_hashes: Dictionary = {}
		for filename: String in ["project.godot", "scripts/playable.gd", "scripts/main.gd", "tests/ui_review.gd"]:
			source_hashes[filename] = FileAccess.get_sha256("res://" + filename)
		return {"kind": "editor_source", "source_sha256": source_hashes}
	var packs: Dictionary = {}
	var resource_dir: String = OS.get_executable_path().get_base_dir().path_join("../Resources")
	var directory: DirAccess = DirAccess.open(resource_dir)
	if directory:
		for filename: String in directory.get_files():
			if filename.ends_with(".pck"):
				packs[filename] = FileAccess.get_sha256(resource_dir.path_join(filename))
	return {"kind": "native_export", "executable_sha256": FileAccess.get_sha256(OS.get_executable_path()), "resource_pack_sha256": packs}

func _write_report(extra: Dictionary) -> void:
	var report: Dictionary = {"schema": "mush-native-ui-review/1", "build": "0.2.2", "passed": failed == 0, "failed_assertions": failed, "assertion_count": assertions.size(), "assertions": assertions, "views": views, "focus_checks": focus_checks, "engine": Engine.get_version_info().string, "native_export": not OS.has_feature("editor"), "rendered_ui_captured": not views.is_empty(), "manual_usability_verified": false, "physical_input_tested": false, "art_approved": false, "scope": "Actual production menu construction/rendering, logical viewport containment, scroll clipping and scripted focus visibility at three native window sizes. Hint-device modes do not simulate hardware.", "remaining_scope": ["Human UI readability and usability review", "Physical keyboard/controller navigation and controller unplug/reconnect", "Motion comfort and user visual approval"]}
	report.merge(extra)
	var file: FileAccess = FileAccess.open(output.path_join("ui-review.json"), FileAccess.WRITE)
	if file == null:
		failed += 1
		print("UI_REVIEW_REPORT_WRITE_FAILED ", FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
