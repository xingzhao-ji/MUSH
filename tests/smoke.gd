extends Node
## Bounded live-scene smoke: preserve the rendered scene while checking its bindings.
var game: Node

func _ready() -> void:
	game = get_parent()
	_run.call_deferred()

func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var aliases := true
	for entry: Dictionary in game.world._m37_materials:
		var found := false
		for node: Node in game.world.find_children("*", "MultiMeshInstance3D", true, false):
			if node.material_override == entry.selected:
				found = true
				break
		aliases = aliases and found
	var checks := {
		"native_snapshot_loaded":game.world.snapshot_loaded,
		"physical_spawn_support":game.player.is_on_floor(),
		"one_player":game.get_node_or_null("Player") == game.player,
		"entry_hinge_binding":is_instance_valid(game.world.door_hinge),
		"room_collision_bindings":not game.world._room_colliders.is_empty(),
		"live_material_aliases":aliases,
		"motion_initialized":game.world._m37_initialized,
		"current_world_ready":game.living_motion_startup.passed,
		"explicit_firefly_shader":game.world._fireflies.process_material is ShaderMaterial,
	}
	var clock: float = game.world._m37_elapsed
	await get_tree().create_timer(.3).timeout
	checks["ordinary_motion_clock_advances"] = game.world._m37_elapsed > clock
	game._pause()
	clock = game.world._m37_elapsed
	await get_tree().create_timer(.2, true).timeout
	checks["pause_freezes_motion"] = game.world._m37_elapsed == clock
	game._explore()
	var arguments := OS.get_cmdline_user_args()
	if "--exercise-effects" in arguments:
		game.world.set_room_ready(true)
		game.world.set_appearance(true,true,false)
		await get_tree().create_timer(2.4).timeout
		checks["night_and_rain_complete"] = game.world.night_amount > .99 and game.world.rain_amount > .99
	var directory := "user://verification/smoke"
	for index: int in range(arguments.size()-1):
		if arguments[index] == "--report-dir": directory = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(directory)
	var passed := true
	for value: bool in checks.values(): passed = passed and value
	var report := {"schema":"mush-current-playable-smoke/1", "passed":passed, "checks":checks, "exported":not OS.has_feature("editor"), "world_load_seconds":game.world.snapshot_load_seconds, "engine":Engine.get_version_info().string, "driver":RenderingServer.get_current_rendering_driver_name()}
	var file := FileAccess.open(directory.path_join("smoke.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SMOKE_COMPLETE ", JSON.stringify(report))
	game._quit_clean.call_deferred(0 if passed else 1)
