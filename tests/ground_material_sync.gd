extends SceneTree
## Native material parity through the actual playable startup; no frame-rate claim.
class GroundSyncGame:
	extends "res://tests/mobile_game_fixture.gd"
	func _title() -> void:
		verification = true
		_preview_slot = "user://verification/ground_sync_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		store.directory = _preview_slot
		_start_new()

var game: Node3D
var controller: Node
var checks: Array[Dictionary] = []
var output: String = ""
var initial_aliases: Dictionary = {}
var compared_parameters: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output = arg.trim_prefix("--report-dir=")
	var reports: String = ProjectSettings.globalize_path("res://reports/")
	if output.is_empty(): output = reports.path_join("ground-material-sync-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if not output.is_absolute_path() or not output.simplify_path().begins_with(reports) or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		push_error("Ground material test requires a new directory under res://reports/")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	game = GroundSyncGame.new()
	root.add_child(game)
	var deadline: int = Time.get_ticks_msec() + 30000
	while game.get("environment_controller") == null and Time.get_ticks_msec() < deadline:
		await process_frame
	controller = game.get("environment_controller") as Node
	_check("Actual playable startup installed the coordinator", is_instance_valid(controller) and bool(game.world.snapshot_loaded))
	if not is_instance_valid(controller):
		_finish()
		return
	_check("The fixture owns a unique verification profile", str(game.store.directory).begins_with("user://verification/ground_sync_"))
	# Keep ordinary owners/resources, but drive their existing updates explicitly.
	# This removes wall-clock/input variability from a material synchronization test.
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.world.set_process(false)
	controller.set_process(false)
	paused = false
	controller._process(0.0)
	initial_aliases = _aliases(controller)
	_check("Actual rooted material variants exist and are bounded", not initial_aliases.is_empty() and initial_aliases.size() <= 32)
	var families: Dictionary = {}
	for row: Dictionary in controller._ground_factory_proof.get("families", []):
		families[str(row.family)] = bool(row.root_plane_exact)
	_check("All five retained root templates remain admitted", controller._ground_factory_proof.get("passed", false) and families == {"fern":true, "broadleaf":true, "flower":true, "grass":true, "glow":true})
	_phase("day", false, false, false, false)
	_phase("night", true, false, false, false)
	_phase("rain", true, true, false, false)
	_phase("paused appearance", false, false, true, false)
	_phase("reduced motion", true, true, false, true)
	_phase("resumed ordinary motion", false, false, false, false)
	for index: int in range(4): controller.refresh_bindings()
	controller._process(0.0)
	_check("Repeated refresh retains the same material/resource aliases", _aliases(controller) == initial_aliases)
	_check("Repeated refresh preserves every non-environment art parameter", _parity(controller))
	_capacity_case()
	_finish()

func _phase(label: String, night: bool, rain: bool, stopped: bool, reduced: bool) -> void:
	paused = stopped
	controller.set_reduced_motion(reduced)
	game.set_appearance("night" if night else "day", "rain" if rain else "sunny")
	var clock_before: float = controller.clock_seconds
	var exact: bool = true
	for index: int in range(24):
		game.world._process(0.1)
		controller._process(0.1)
		exact = _parity(controller) and exact
	_check(label + ": all sampled native art uniforms and texture/shader aliases match", exact)
	_check(label + ": retained material resources remain identical", _aliases(controller) == initial_aliases)
	_check(label + ": requested appearance endpoint reached", game.world.night_amount == (1.0 if night else 0.0) and game.world.rain_amount == (1.0 if rain else 0.0))
	_check(label + ": pause clock contract preserved", controller.clock_seconds == clock_before if stopped else controller.clock_seconds > clock_before)

func _aliases(owner: Node) -> Dictionary:
	var result: Dictionary = {}
	for key: String in owner._ground_material_variants:
		var entry: Dictionary = owner._ground_material_variants[key]
		result[key] = [entry.original.get_instance_id(), entry.selected.get_instance_id(), entry.original.shader.get_instance_id(), entry.selected.shader.get_instance_id()]
	return result

func _parity(owner: Node) -> bool:
	var exact: bool = not owner._ground_material_variants.is_empty()
	for key: String in owner._ground_material_variants:
		var entry: Dictionary = owner._ground_material_variants[key]
		var original: ShaderMaterial = entry.original
		var selected: ShaderMaterial = entry.selected
		exact = exact and original != selected and original.shader == selected.shader and original.next_pass == selected.next_pass and original.render_priority == selected.render_priority
		# Derive expected names from the actual shader, independently of the cache.
		for uniform: Dictionary in original.shader.get_shader_uniform_list():
			var name: String = str(uniform.name)
			if name.begins_with("env_"): continue
			var before: Variant = original.get_shader_parameter(name)
			var after: Variant = selected.get_shader_parameter(name)
			compared_parameters += 1
			exact = exact and (before == after if before is Object else var_to_bytes(before) == var_to_bytes(after))
		exact = exact and selected.get_shader_parameter("env_anchor_enabled") == 1.0 and var_to_bytes(selected.get_shader_parameter("env_root_y")) == var_to_bytes(float(entry.root_y))
	return exact

func _capacity_case() -> void:
	# Exercise the existing finite cache off-tree; these resources never join World.
	var isolated: Node = load("res://scripts/environment_controller.gd").new()
	var sources: Array[ShaderMaterial] = []
	var admitted: bool = true
	for index: int in range(32):
		var source := ShaderMaterial.new()
		source.shader = load("res://assets/world/tactile.gdshader")
		sources.append(source)
		var variant: ShaderMaterial = isolated._ground_material_variant(source, 0.0)
		admitted = admitted and variant != null and isolated._ground_material_variant(source, 0.0) == variant
		# A later source edit must still reach every cached variant.
		source.set_shader_parameter("base_color", Color(float(index) / 32.0, 0.25, 0.5))
	isolated._sync_ground_material_variants()
	_check("All 32 cache entries synchronize independent source values", admitted and isolated._ground_material_variants.size() == 32 and _parity(isolated))
	var extra := ShaderMaterial.new()
	extra.shader = sources[0].shader
	_check("A 33rd distinct material is refused without cache growth", isolated._ground_material_variant(extra, 0.0) == null and isolated._ground_material_variants.size() == 32)
	isolated.free()

func _check(label: String, passed: bool) -> void:
	checks.append({"label":label, "passed":passed})
	if not passed: print("GROUND_MATERIAL_SYNC_FAIL ", label)

func _finish() -> void:
	var failed: int = 0
	for row: Dictionary in checks:
		if not row.passed: failed += 1
	var report: Dictionary = {"schema":"mush-ground-material-sync/1", "passed":failed == 0, "assertions":checks.size(), "failed":failed, "checks":checks, "native_parameter_comparisons":compared_parameters, "engine":Engine.get_version_info().string, "renderer":RenderingServer.get_current_rendering_method(), "scope":"Actual playable startup and native material parity under explicitly driven existing updates. No rendered motion, frame-rate improvement or physical-device performance claim."}
	var file := FileAccess.open(output.path_join("ground-material-sync.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write ground material sync report")
		failed += 1
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("GROUND_MATERIAL_SYNC ", JSON.stringify({"passed":failed == 0, "assertions":checks.size(), "failed":failed, "native_parameter_comparisons":compared_parameters}))
	if is_instance_valid(game): game._quit_clean(0 if failed == 0 else 2)
	else: quit(2)
