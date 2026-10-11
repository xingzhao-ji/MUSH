extends "res://tests/paving_surface.gd"
## Temporary native shape swap with matched lighting and exact pointer rollback.
## The authoring report and real traversal are separate gates.
var shape_path: String
var shape_library: MeshLibrary
var old_meshes: Array[ArrayMesh] = []
var new_meshes: Array[ArrayMesh] = []
var old_shape: ConcavePolygonShape3D
var new_shape: ConcavePolygonShape3D
var candidate_geometry: String
var candidate_collision: String
var baseline_geometry: String
var baseline_collision: String

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output = arg.trim_prefix("--report-dir=")
		if arg.begins_with("--candidate="): shape_path = arg.trim_prefix("--candidate=")
	var reports := ProjectSettings.globalize_path("res://reports/").simplify_path().trim_suffix("/")
	output = output.simplify_path(); shape_path = shape_path.simplify_path()
	if not output.begins_with(reports + "/") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output) or not shape_path.begins_with(reports + "/") or not FileAccess.file_exists(shape_path):
		push_error("Use a new report directory and an existing candidate under res://reports/")
		quit(2); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: quit(2); return
	var scene := load("res://main.tscn") as PackedScene
	if not _check("Rendered actual Main available", scene != null and DisplayServer.get_name() != "headless"):
		_finish(); return
	game = scene.instantiate() as Node3D; game.set_script(PavingSurfaceGame)
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 90000
	while game.get("environment_controller") == null and Time.get_ticks_msec() < deadline: await process_frame
	controller = game.get("environment_controller") as Node
	owner = game.world.get("paving_preview_prebuilt") as RefCounted
	top = game.world.get_node_or_null(TOP) as MeshInstance3D
	if not _check("Actual preview owner verified before isolated swap", controller != null and owner != null and top != null and game.world.snapshot_loaded and bool(owner.call("verify", game.world, true))):
		_finish(); return
	game.get_window().unfocusable = true; game.get_window().mouse_passthrough = true
	game.set_process(false); game.set_physics_process(false)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.player.enabled = false
	await _frames(15)
	game.player.set_process(false); game.player.set_physics_process(false)
	game.player._visual.process_mode = Node.PROCESS_MODE_DISABLED
	game.world.set_living_motion_enabled(false)
	game.ui.hide(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; paused = false
	game.get_window().size = Vector2i(960, 960); game.get_window().content_scale_size = Vector2i(960, 960)
	original = top.material_override as ShaderMaterial; candidate = original; installed = original
	shape_library = ResourceLoader.load(shape_path, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	if not _check("Candidate has the retained three-item, one-shape structure", shape_library != null and bool(owner.call("_library_exact", shape_library))):
		_finish(); return
	for i: int in range(3):
		var entry: Dictionary = owner.get("_entries")[i]
		old_meshes.append(entry.node.mesh as ArrayMesh)
		new_meshes.append(shape_library.get_item_mesh(i) as ArrayMesh)
	old_shape = owner.get("_collision").shape as ConcavePolygonShape3D
	new_shape = shape_library.get_item_shapes(0)[0] as ConcavePolygonShape3D
	baseline_geometry = _geometry(); baseline_collision = _collision(); bindings_before = _bindings()
	_check("Retained contact configuration and distinct resource", old_shape != new_shape and var_to_bytes(owner.call("_shape_configuration", old_shape)) == var_to_bytes(owner.call("_shape_configuration", new_shape)))
	_set_shape(true)
	candidate_geometry = _geometry(); candidate_collision = _collision()
	_check("Candidate is registered on the same body; material aliases unchanged", bool(owner.call("_body_binding_exact", new_shape)) and _bindings() == bindings_before)
	_set_shape(false)
	for label: String in ["close-day", "close-night", "wide-day", "close-rain"]: await _pair(label)
	_finish()

func _set_shape(selected: bool) -> void:
	for i: int in range(3): owner.get("_entries")[i].node.mesh = new_meshes[i] if selected else old_meshes[i]
	owner.get("_collision").shape = new_shape if selected else old_shape

func _pair(label: String) -> void:
	_set_shape(false)
	var night := label == "close-night"; var rain := label == "close-rain"; var close := label.begins_with("close")
	game.player.visible = not close
	game.review_camera.position = Vector3(1.4, 1.65, 10.8) if close else Vector3(4.8, 2.65, 17.0)
	var target := Vector3(-.45, .18, 7.8) if close else Vector3(0, 1.3, 3.6)
	game.review_camera.fov = 55.0 if close else 58.0
	game.review_camera.look_at(target); game.review_camera.make_current()
	game.world.set_environment_foreground(true); controller.set_foreground(true)
	controller.set_inspection_state("rain" if rain else ("night" if night else "calm"))
	game.set_appearance("night" if night else "day", "rain" if rain else "sunny")
	await create_timer(4.0).timeout
	game.world.set_environment_foreground(false); controller.set_foreground(false)
	await _frames(3)
	_all_materials()
	var held_materials := _all_materials(); var held := _context()
	var pair_passed: bool = game.world.night_amount == (1.0 if night else 0.0) and game.world.rain_amount == (1.0 if rain else 0.0) and controller._sunset == 0.0
	for selected: bool in [false, true]:
		_set_shape(selected)
		await _frames(10); await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		var one := frame != null and not frame.is_empty()
		var filename := label + ("-after.png" if selected else "-before.png")
		if one:
			frame.convert(Image.FORMAT_RGBA8)
			one = frame.get_size() == Vector2i(960, 960) and frame.save_png(output.path_join(filename)) == OK
		one = one and _context() == held and _all_materials() == held_materials and _bindings() == bindings_before and _geometry() == (candidate_geometry if selected else baseline_geometry) and _collision() == (candidate_collision if selected else baseline_collision) and bool(owner.call("_body_binding_exact", new_shape if selected else old_shape)) and root.get_camera_3d() == game.review_camera
		pair_passed = pair_passed and one
		views.append({"file":filename, "label":filename.trim_suffix(".png"), "passed":one, "selected":selected, "png_sha256":FileAccess.get_sha256(output.path_join(filename)) if FileAccess.file_exists(output.path_join(filename)) else "", "rgba_sha256":_sha(frame.get_data()) if frame != null else ""})
	_set_shape(false)
	_check(label + ": matched context, exact resources and restored native owner", pair_passed and bool(owner.call("verify", game.world, true)))
	pairs.append({"label":label, "passed":pair_passed, "context_sha256":held, "camera_position":str(game.review_camera.position), "target":str(target), "fov":game.review_camera.fov})

func _context() -> String:
	# Geometry/contact deliberately differ. Everything defining this view is held.
	return _sha(var_to_bytes({"lighting":game._review_lighting_state(), "camera":game.review_camera.global_transform, "fov":game.review_camera.fov, "viewport_size":root.get_visible_rect().size, "resolution_scale":root.scaling_3d_scale, "night":game.world.night_amount, "rain":game.world.rain_amount, "clock":controller.clock_seconds, "detail_clock":controller.detail_clock_seconds, "cloud":controller.cloud_offset, "wetness":controller.wetness, "player_position":game.player.global_position, "player_visible":game.player.visible, "player_visual":game.player._visual.transform, "world_foreground":game.world._environment_foreground, "controller_foreground":controller.foreground}))

func _finish() -> void:
	if old_meshes.size() == 3 and old_shape != null:
		_set_shape(false)
		_check("Exact native geometry, collision, material aliases and owner rollback", _geometry() == baseline_geometry and _collision() == baseline_collision and _bindings() == bindings_before and bool(owner.call("verify", game.world, true)))
	_check("Four complete matched pairs", views.size() == 8 and pairs.size() == 4)
	var failed := 0
	for row: Dictionary in checks:
		if not row.passed: failed += 1
	var report := {"schema":"mush-paving-shape-comparison/1", "passed":failed == 0, "failed":failed, "assertions":checks.size(), "checks":checks, "pairs":pairs, "views":views, "candidate":shape_path, "candidate_sha256":FileAccess.get_sha256(shape_path) if FileAccess.file_exists(shape_path) else "", "motion_verified":false, "art_approved":false, "traversal_verified":false, "performance_verified":false, "scope":"Native isolated geometry/contact swap through current Main, held materials/light/camera and exact rollback. Separate authoring and real traversal required."}
	var file := FileAccess.open(output.path_join("paving-shape-comparison.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	else: failed += 1
	print("PAVING_SHAPE_COMPLETE ", JSON.stringify({"passed":failed == 0, "assertions":checks.size(), "failed":failed, "views":views.size()}))
	if is_instance_valid(game): game._quit_clean(0 if failed == 0 else 2)
	else: quit(2)
