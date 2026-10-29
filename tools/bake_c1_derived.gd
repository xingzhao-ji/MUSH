extends SceneTree
## Root-owned offline entry; never invoked by ordinary startup.
## Godot --headless --path . --script tools/bake_c1_derived.gd -- --capture
## Optional --output=res://reports/.../c1-derived.res keeps an authoring candidate.
## --verify-dependencies validates the saved source manifest without loading main.
const Cache = preload("res://scripts/c1_derived_cache.gd")
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--verify-dependencies" in args:
		var proof_path: String = Cache.PROOF
		for arg: String in args:
			if arg.begins_with("--proof="): proof_path = arg.trim_prefix("--proof=")
		var checked: Dictionary = Cache.verify_dependencies(proof_path)
		print("C1_DERIVED_DEPENDENCIES ", JSON.stringify(checked))
		quit(0 if checked.get("passed", false) else 2)
		return
	if DisplayServer.get_name() != "headless" or not "--capture" in args:
		push_error("C1 bake requires headless and --capture for the existing private verification slot")
		quit(2)
		return
	if not OS.get_environment("MUSH_SCENERY_DIAG").is_empty() or not OS.get_environment("MUSH_GOAL_VISTA").is_empty():
		push_error("C1 bake requires the default vista and an empty MUSH_SCENERY_DIAG; diagnostic variants cannot replace the default artifact")
		quit(2)
		return
	var output: String = Cache.ARTIFACT
	for arg: String in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	OS.set_environment("MUSH_C1_DERIVED_BAKE", "1")
	var started: int = Time.get_ticks_msec()
	game = load("res://main.tscn").instantiate()
	# The authoring entry reads the real startup result; suppress only the separate
	# automatic screenshot runner that --capture would otherwise enqueue.
	game.set_meta("capture_started", true)
	root.add_child(game)
	var deadline: int = started + 180000
	while game.get("environment_controller") == null and Time.get_ticks_msec() < deadline:
		await process_frame
	var scenery: Node = game.get("prototype_scenery")
	if game.get("environment_controller") == null or scenery == null or scenery.get("_c1_derived") == null:
		scenery = null
		await _finish({"passed": false, "reason": "Real startup did not expose its C1 derived cache"})
		return
	var cache: RefCounted = scenery.get("_c1_derived")
	var models: Dictionary = scenery.get("_model_cache")
	for path: String in models: cache.add_dependency(path)
	# The installed neutral world determines the ground used by the C1 eye and
	# path. Bind retained baked inputs as well as every imported model/settings.
	for path: String in ["res://baked/clearing.res", "res://baked/clearing-renderer-neutral.res", "res://baked/renderer-neutral-proof.json"]:
		cache.add_dependency(path)
	var report: Dictionary = cache.save(output)
	report["elapsed_s"] = float(Time.get_ticks_msec() - started) / 1000.0
	report["cache"] = cache.get_report()
	# Drop our references before freeing the live scene. Reassign the model map,
	# rather than clearing the scenery-owned Dictionary through an alias.
	models = {}
	cache = null
	scenery = null
	await _finish(report)

func _finish(report: Dictionary) -> void:
	print("C1_DERIVED_BAKE ", JSON.stringify(report))
	if is_instance_valid(game):
		var controller: Node = game.get("environment_controller")
		if controller != null and controller.has_method("shutdown_visuals"): controller.shutdown_visuals()
		controller = null
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.queue_free()
		game = null
		for frame: int in 3: await process_frame
	# Let both authoring coroutine frames return before the SceneTree shuts down.
	call_deferred("quit", 0 if report.get("passed", false) else 2)
