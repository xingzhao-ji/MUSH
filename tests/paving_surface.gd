extends SceneTree
## Isolated rendered material comparison. Does not qualify art, motion or speed.
class PavingSurfaceGame:
	extends "res://scripts/playable.gd"
	func _start_new() -> void:
		verification = true
		_preview_slot = "user://verification/paving_surface_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		store.directory = _preview_slot
		super._start_new()
	func _title() -> void: _start_new()
	func _start_benchmark() -> void: pass
	func _start_acceptance() -> void: pass
	func _capture_review() -> void: pass

const TOP := "BatchedStaticWorld/Static_-9223371981221525344_0_0"
const TEXTURE := "res://assets/world/textures/rock_01_diff_1k.jpg"
const TEXTURE_SHA := "0b5f0418eb1e686190c5d33bb54c400b1f9ed58813b5e34aa5e573a5197302b5"
const PARAMETERS: Array[String] = ["surface_albedo", "surface_blend", "surface_scale", "surface_triplanar"]
var game: Node3D
var controller: Node
var owner: RefCounted
var top: MeshInstance3D
var original: ShaderMaterial
var candidate: ShaderMaterial
var installed: ShaderMaterial
var integrated: bool = false
var installed_art: Dictionary
var installed_configuration: String
var texture: Texture2D
var output: String
var checks: Array[Dictionary] = []
var views: Array[Dictionary] = []
var pairs: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var geometry_before: String
var collision_before: String
var bindings_before: String
var original_art: Dictionary
var original_configuration: String
var geometry_unchanged: bool = false
var collision_unchanged: bool = false
var material_rollback_exact: bool = false
var source_material_unchanged: bool = true
var texture_readback: Dictionary = {}
var registration: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output = arg.trim_prefix("--report-dir=")
	var reports := ProjectSettings.globalize_path("res://reports/").simplify_path().trim_suffix("/")
	output = output.simplify_path()
	if output.is_empty() or not output.is_absolute_path() or not output.begins_with(reports + "/") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		push_error("Paving comparison requires a new --report-dir= directory beneath res://reports/")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	if not _check("Actual main scene and rendered display available", scene != null and DisplayServer.get_name() != "headless"):
		_finish(); return
	game = scene.instantiate() as Node3D
	game.set_script(PavingSurfaceGame)
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 90000
	while game.get("environment_controller") == null and Time.get_ticks_msec() < deadline:
		await process_frame
	controller = game.get("environment_controller") as Node
	owner = game.world.get("paving_preview_prebuilt") as RefCounted
	top = game.world.get_node_or_null(TOP) as MeshInstance3D
	if not _check("Real playable startup and actual preview owner verified", controller != null and owner != null and top != null and game.world.snapshot_loaded and bool(owner.call("verify", game.world, true))):
		_finish(); return
	_check("Fresh test-only save profile", str(game.store.directory).begins_with("user://verification/paving_surface_"))
	game.get_window().unfocusable = true
	game.get_window().mouse_passthrough = true
	game.set_process(false); game.set_physics_process(false)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.player.enabled = false
	await _frames(15)
	game.player.set_process(false); game.player.set_physics_process(false)
	game.player._visual.process_mode = Node.PROCESS_MODE_DISABLED
	game.world.set_living_motion_enabled(false)
	game.ui.hide(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paused = false
	game.get_window().size = Vector2i(960, 960)
	game.get_window().content_scale_size = Vector2i(960, 960)
	installed = top.material_override as ShaderMaterial
	original = game.world.get("paving_surface_original") as ShaderMaterial
	integrated = original != null
	if not integrated: original = installed
	var integration_report: Variant = game.world.get("paving_surface_report")
	if not _check("Admitted installed top pointer and retained baseline tactile material", installed != null and original != null and original.shader != null and original.shader.resource_path == "res://assets/world/tactile.gdshader" and installed.shader == original.shader and top.mesh.surface_get_array_len(0) == 4638 and top == owner.get("_entries")[0].node and installed == owner.get("_entries")[0].material and (not integrated or (installed != original and integration_report is Dictionary and bool(integration_report.get("passed", false))))):
		_finish(); return
	var initial := _parameters(original)
	if not _check("Retained material has scale4/grain.9 and no surface texture blend", initial.texture_scale == 4.0 and is_equal_approx(initial.grain, .9) and initial.surface_blend == 0.0 and initial.surface_scale == 1.0 and initial.surface_triplanar == false and initial.env_anchor_enabled == 0.0 and FileAccess.get_sha256(TEXTURE) == TEXTURE_SHA):
		_finish(); return
	texture = load(TEXTURE) as Texture2D
	var image: Image = texture.get_image() if texture != null else null
	if not _check("Exact imported Rock01 with native1024 square and ten mip levels", texture != null and image != null and texture.get_size() == Vector2(1024, 1024) and image.has_mipmaps() and image.get_mipmap_count() == 10):
		_finish(); return
	texture_readback = {"file":TEXTURE, "sha256":TEXTURE_SHA, "width":texture.get_width(), "height":texture.get_height(), "class":texture.get_class(), "image_format":image.get_format(), "mipmap_count":image.get_mipmap_count(), "image_data_bytes":image.get_data().size(), "image_data_sha256":_sha(image.get_data()), "scope":"CPU native image readback; not measured GPU residency or sampling cost."}
	original_art = _art(original)
	original_configuration = _configuration(original)
	installed_art = _art(installed)
	installed_configuration = _configuration(installed)
	candidate = installed if integrated else original.duplicate(false) as ShaderMaterial
	if not _check("Shallow material fork retains original Shader and stored configuration", candidate != null and candidate != original and candidate.shader == original.shader and _configuration(candidate) == _configuration(original)):
		_finish(); return
	# An integrated material is observed, never rewritten. Only first-trial mode sets it.
	if not integrated:
		candidate.set_shader_parameter("surface_albedo", texture)
		candidate.set_shader_parameter("surface_blend", .60)
		candidate.set_shader_parameter("surface_scale", 2.0 / 3.0)
		candidate.set_shader_parameter("surface_triplanar", false)
	if not _check("Exactly four declared surface parameters; other art uniforms exact", _candidate_exact(false)):
		_finish(); return
	geometry_before = _geometry(); collision_before = _collision(); bindings_before = _bindings()
	var old_rows := _binding_rows()
	var missing: ShaderMaterial = original if integrated else candidate
	var expected_append: int = 1 if _binding_count(missing) == 0 else 0
	top.material_override = missing
	controller.refresh_bindings()
	top.material_override = installed
	var new_rows := _binding_rows()
	registration = {"public_api":"refresh_bindings", "before_count":old_rows.size(), "after_count":new_rows.size(), "expected_append":expected_append, "registration_target_id":str(missing.get_instance_id()), "source_count":_binding_count(original), "candidate_count":_binding_count(candidate), "installed_pointer_restored":top.material_override == installed, "private_list_mutated":false}
	if not _check("Public refresh retains existing bindings and adds only missing comparison material", new_rows.size() == old_rows.size() + expected_append and var_to_bytes(new_rows.slice(0, old_rows.size())) == var_to_bytes(old_rows) and registration.source_count == 1 and registration.candidate_count == 1 and bool(owner.call("verify", game.world, true)) and _bindings() == bindings_before):
		_finish(); return
	for label: String in ["close-day", "close-night", "wide-day", "close-rain"]:
		await _pair(label)
	_finish()

func _pair(label: String) -> void:
	top.material_override = original
	var night := label == "close-night"
	var rain := label == "close-rain"
	var close := label.begins_with("close")
	game.player.visible = not close
	game.review_camera.position = Vector3(1.8, 1.6, 9.5) if close else Vector3(4.8, 2.65, 17.0)
	var target := Vector3(0, .2, 5.8) if close else Vector3(0, 1.3, 3.6)
	game.review_camera.fov = 55.0 if close else 58.0
	game.review_camera.look_at(target); game.review_camera.make_current()
	game.world.set_environment_foreground(true); controller.set_foreground(true)
	controller.set_inspection_state("rain" if rain else ("night" if night else "calm"))
	game.set_appearance("night" if night else "day", "rain" if rain else "sunny")
	var clock_before: float = controller.clock_seconds
	var live_exact := true
	var environment_names: Array[String] = []
	for name: String in _parameters(original):
		if name.begins_with("env_"): environment_names.append(name)
	for sample: int in range(16):
		await create_timer(.25).timeout
		var a := _parameters(original); var b := _parameters(candidate)
		for name: String in environment_names: live_exact = live_exact and _same(a[name], b[name])
		live_exact = live_exact and _candidate_exact()
	var clock_after: float = controller.clock_seconds
	live_exact = live_exact and clock_after > clock_before and environment_names.size() == 15
	_check(label + ": both resources independently receive live environment updates", live_exact)
	transitions.append({"label":label, "passed":live_exact, "samples":16, "environment_names":environment_names, "clock_before":clock_before, "clock_after":clock_after, "wetness":controller.wetness, "parameter_copying":false})
	game.world.set_environment_foreground(false); controller.set_foreground(false)
	await _frames(3)
	# Prime native storage defaults before recording a held material snapshot.
	_all_materials()
	var held_materials := _all_materials()
	var held := _context()
	var endpoint: bool = game.world.night_amount == (1.0 if night else 0.0) and game.world.rain_amount == (1.0 if rain else 0.0) and controller._sunset == 0.0
	var pair_passed := live_exact and endpoint
	var context_held := true
	for selected: bool in [false, true]:
		top.material_override = candidate if selected else original
		await _frames(10)
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		var one := frame != null and not frame.is_empty()
		var filename := label + ("-after.png" if selected else "-before.png")
		if one:
			frame.convert(Image.FORMAT_RGBA8)
			one = frame.get_size() == Vector2i(960, 960) and frame.save_png(output.path_join(filename)) == OK
		var same_context: bool = _context() == held and _all_materials() == held_materials
		var same_geometry: bool = _geometry() == geometry_before and _collision() == collision_before
		var same_source: bool = var_to_bytes(_art(installed)) == var_to_bytes(installed_art) and _configuration(installed) == installed_configuration and _candidate_exact()
		one = one and same_context and same_geometry and same_source and _bindings() == bindings_before and _candidate_aliases(selected) and root.get_camera_3d() == game.review_camera
		pair_passed = pair_passed and one; context_held = context_held and same_context
		source_material_unchanged = source_material_unchanged and same_source and same_context
		views.append({"file":filename, "label":filename.trim_suffix(".png"), "pair":label, "selected":selected, "width":frame.get_width() if frame != null else 0, "height":frame.get_height() if frame != null else 0, "png_sha256":FileAccess.get_sha256(output.path_join(filename)) if FileAccess.file_exists(output.path_join(filename)) else "", "rgba_sha256":_sha(frame.get_data()) if frame != null else "", "passed":one})
	top.material_override = installed
	_check(label + ": matched frozen images, bindings and all native geometry/contact held", pair_passed and bool(owner.call("verify", game.world, true)))
	pairs.append({"label":label, "passed":pair_passed, "context_held":context_held, "context_sha256":held, "camera_position":str(game.review_camera.position), "target":str(target), "fov":game.review_camera.fov, "night_amount":game.world.night_amount, "rain_amount":game.world.rain_amount, "wetness":controller.wetness})

func _parameters(material: ShaderMaterial) -> Dictionary:
	var result: Dictionary = {}
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		var name: String = str(uniform.name)
		var value: Variant = material.get_shader_parameter(name)
		result[name] = value if value != null else RenderingServer.shader_get_parameter_default(material.shader.get_rid(), name)
	return result

func _same(a: Variant, b: Variant) -> bool:
	return a == b if a is Object or b is Object else var_to_bytes(a) == var_to_bytes(b)

func _art(material: ShaderMaterial) -> Dictionary:
	var result := _parameters(material)
	for name: String in result.keys():
		if name.begins_with("env_"): result.erase(name)
	return result

func _configuration(material: ShaderMaterial) -> String:
	var omit: Array[String] = []
	for property: Dictionary in material.get_property_list():
		if str(property.name).begins_with("shader_parameter/"): omit.append(str(property.name))
	return _sha(var_to_bytes({"stored":owner.call("_stored", material, omit), "metadata":owner.call("_metadata", material), "shader":material.shader.get_instance_id(), "shader_code":material.shader.code}))

func _candidate_exact(compare_environment: bool = true) -> bool:
	if candidate == null or original == null or candidate.shader != original.shader or _configuration(original) != original_configuration or _configuration(candidate) != original_configuration: return false
	var a := _parameters(original); var b := _parameters(candidate)
	if a.keys() != b.keys() or b.surface_albedo != texture or not is_equal_approx(b.surface_blend, .60) or not is_equal_approx(b.surface_scale, 2.0 / 3.0) or b.surface_triplanar != false: return false
	for name: String in a:
		# The retained baseline may not have an initial controller binding yet.
		# All env parameters are required exact during every live/capture sample.
		if not compare_environment and name.begins_with("env_"): continue
		if not name in PARAMETERS and not _same(a[name], b[name]): return false
	return var_to_bytes(_art(original)) == var_to_bytes(original_art)

func _binding_rows() -> Array:
	var result: Array = []
	for row: Dictionary in controller.get("_materials"):
		result.append({"id":str(row.material.get_instance_id()), "keys":row["keys"].keys(), "shader":row.material.shader.get_instance_id()})
	return result

func _binding_count(material: ShaderMaterial) -> int:
	var count := 0
	for row: Dictionary in controller.get("_materials"):
		if row.material == material: count += 1
	return count

func _materials_and_aliases() -> Dictionary:
	var materials: Dictionary = {}; var aliases: Dictionary = {}
	for node: Node in game.world.find_children("*", "GeometryInstance3D", true, false):
		var slots: Dictionary = {"override":node.material_override, "overlay":node.material_overlay}
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null)
		if mesh != null:
			for index: int in range(mesh.get_surface_count()): slots["mesh/%d" % index] = mesh.surface_get_material(index)
		if node is MeshInstance3D:
			for index: int in range(node.get_surface_override_material_count()): slots["surface/%d" % index] = node.get_surface_override_material(index)
		if node is GPUParticles3D:
			slots["process"] = node.process_material
			for index: int in range(node.draw_passes):
				var draw: Mesh = node.get_draw_pass_mesh(index)
				if draw != null:
					for surface: int in range(draw.get_surface_count()): slots["draw/%d/%d" % [index, surface]] = draw.surface_get_material(surface)
		for slot: String in slots:
			var material: Material = slots[slot]
			if material != null: materials[material.get_instance_id()] = material
			aliases[str(game.world.get_path_to(node)) + ":" + slot] = "selected" if node == top and slot == "override" else (str(material.get_instance_id()) if material != null else "null")
	return {"materials":materials, "aliases":aliases}

func _bindings() -> String:
	return _sha(var_to_bytes(_materials_and_aliases().aliases))

func _candidate_aliases(selected: bool) -> bool:
	var aliases: Dictionary = _materials_and_aliases().aliases
	# The sole omitted slot is positively checked here; every other slot is exact.
	return top.material_override == (candidate if selected else original) and not str(candidate.get_instance_id()) in aliases.values()

func _all_materials() -> String:
	var materials: Dictionary = _materials_and_aliases().materials
	materials[original.get_instance_id()] = original
	materials[candidate.get_instance_id()] = candidate
	var ids: Array = materials.keys(); ids.sort()
	var rows: Array = []; var omit: Array[String] = []
	for id: int in ids:
		var material: Material = materials[id]
		# Storage before effective getters prevents lazy-default snapshot mismatch.
		var stored: Dictionary = owner.call("_stored", material, omit)
		rows.append({"id":str(id), "stored":stored, "metadata":owner.call("_metadata", material), "uniforms":_parameters(material) if material is ShaderMaterial else {}, "shader_code":material.shader.code if material is ShaderMaterial else ""})
	return _sha(var_to_bytes(rows))

func _geometry() -> String:
	var rows: Array = []; var omit: Array[String] = ["mesh", "material_override"]
	for entry: Dictionary in owner.get("_entries"):
		rows.append({"node":entry.node.get_instance_id(), "mesh":entry.node.mesh.get_instance_id(), "native":owner.call("_native_prebuilt_record", entry.node.mesh), "state":owner.call("_node_state", entry.node, omit)})
	return _sha(var_to_bytes(rows))

func _collision() -> String:
	var body: StaticBody3D = owner.get("_body")
	var shape_node: CollisionShape3D = owner.get("_collision")
	var shape: ConcavePolygonShape3D = shape_node.shape
	var index: int = owner.get("_shape_index")
	var omit: Array[String] = []
	return _sha(var_to_bytes({"body":owner.call("_body_native_state"), "node":owner.call("_node_state", shape_node, omit), "shape":shape.get_instance_id(), "faces":shape.get_faces(), "configuration":owner.call("_shape_configuration", shape), "server_rid":PhysicsServer3D.body_get_shape(body.get_rid(), index), "binding_exact":owner.call("_body_binding_exact", shape)}))

func _context() -> String:
	return _sha(var_to_bytes({"geometry":_geometry(), "collision":_collision(), "bindings":_bindings(), "lighting":game._review_lighting_state(), "camera":game.review_camera.global_transform, "fov":game.review_camera.fov, "viewport_size":root.get_visible_rect().size, "resolution_scale":root.scaling_3d_scale, "night":game.world.night_amount, "rain":game.world.rain_amount, "clock":controller.clock_seconds, "detail_clock":controller.detail_clock_seconds, "cloud":controller.cloud_offset, "wetness":controller.wetness, "player_position":game.player.global_position, "player_visible":game.player.visible, "player_visual":game.player._visual.transform, "world_foreground":game.world._environment_foreground, "controller_foreground":controller.foreground}))

func _frames(count: int) -> void:
	for index: int in range(count): await process_frame

func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _check(label: String, passed: bool) -> bool:
	checks.append({"label":label, "passed":passed})
	if not passed: print("PAVING_SURFACE_FAIL ", label)
	return passed

func _finish() -> void:
	if installed != null and is_instance_valid(top): top.material_override = installed
	if owner != null and original != null and installed != null:
		geometry_unchanged = not geometry_before.is_empty() and _geometry() == geometry_before
		collision_unchanged = not collision_before.is_empty() and _collision() == collision_before
		material_rollback_exact = not bindings_before.is_empty() and _bindings() == bindings_before and top.material_override == installed and var_to_bytes(_art(installed)) == var_to_bytes(installed_art) and _configuration(installed) == installed_configuration and var_to_bytes(_art(original)) == var_to_bytes(original_art) and _configuration(original) == original_configuration and bool(owner.call("verify", game.world, true))
		_check("Actual installed material, native owner, geometry and contact restored", geometry_unchanged and collision_unchanged and material_rollback_exact)
	_check("Four complete paired frozen views", pairs.size() == 4 and views.size() == 8)
	var failed := 0
	for row: Dictionary in checks:
		if not row.passed: failed += 1
	var pins: Dictionary = {}
	for path: String in ["res://tests/paving_surface.gd", "res://scripts/paving_preview_prebuilt.gd", "res://baked/paving-preview192.json", "res://baked/paving-preview192.res", "res://assets/world/tactile.gdshader", "res://scripts/environment_controller.gd", TEXTURE]: pins[path] = FileAccess.get_sha256(path)
	var report := {"schema":"mush-portable-paving-surface/1", "passed":failed == 0, "failed":failed, "assertions":checks.size(), "checks":checks, "views":views, "pairs":pairs, "geometry_unchanged":geometry_unchanged, "collision_unchanged":collision_unchanged, "material_rollback_exact":material_rollback_exact, "source_material_unchanged":source_material_unchanged and material_rollback_exact, "source_material_scope":"The original installed material retains its art/configuration; both comparison materials retain full stored/effective maps within each frozen pair. Live env values intentionally advance between pairs.", "rollback_scope":"Restore the actual installed startup pointer, not the untextured comparison baseline.", "integrated_source":integrated, "installed_material_id":str(installed.get_instance_id()) if installed != null else "", "baseline_material_id":str(original.get_instance_id()) if original != null else "", "candidate_material_id":str(candidate.get_instance_id()) if candidate != null else "", "texture":texture_readback, "registration":registration, "live_transitions":transitions, "pins":pins, "engine":Engine.get_version_info().string, "renderer":RenderingServer.get_current_rendering_method(), "temporary_binding_retained_until_shutdown":registration.get("expected_append", 0) == 1, "environmental_shader_motion_frozen":true, "shader_TIME_frozen":false, "art_approved":false, "motion_verified":false, "performance_verified":false, "scope":"Real Main startup, one shallow top-material fork and four declared surface parameters. Existing geometry/physics/camera controller retained; fixed diagnostic cameras. No traversal, GPU-cost, exported-app or visual approval."}
	var file := FileAccess.open(output.path_join("paving-surface.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write paving surface report"); failed += 1
	else:
		file.store_string(JSON.stringify(report, "\t")); file.close()
	print("PAVING_SURFACE_COMPLETE ", JSON.stringify({"passed":failed == 0, "failed":failed, "assertions":checks.size(), "views":views.size()}))
	if is_instance_valid(game): game._quit_clean(0 if failed == 0 else 2)
	else: quit(2)
