extends SceneTree
## Diagnostic only: samples the installed prototype terrain_height/terrain_slope (and real
## physics ground inside the clearing) on a grid, for route planning. No assertions.
class ProbeGame:
	extends "res://scripts/playable.gd"
	func _start_new() -> void:
		verification = true
		_preview_slot = "user://verification/terrain_probe_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		store.directory = _preview_slot
		super._start_new()
	func _title() -> void: _start_new()
	func _start_benchmark() -> void: pass
	func _start_acceptance() -> void: pass
	func _capture_review() -> void: pass

var game: Node3D
var output: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output = arg.trim_prefix("--report-dir=")
	if output.is_empty() or not output.begins_with(ProjectSettings.globalize_path("res://reports/")):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.set_script(ProbeGame)
	root.add_child(game)
	var deadline: int = Time.get_ticks_msec() + 90000
	while game.get("environment_controller") == null and Time.get_ticks_msec() < deadline: await process_frame
	var scenery: Node = game.get("prototype_scenery")
	if scenery == null:
		quit(3)
		return
	var step: float = 10.0
	var rows: Array = []
	for z: int in range(-800, 301, int(step)):
		var row: Array = []
		for x: int in range(-150, 551, int(step)):
			row.append([snappedf(scenery.terrain_height(x, z), 0.1), snappedf(scenery.terrain_slope(x, z), 0.01)])
		rows.append(row)
	var route_points: Array = []
	for p: Vector3 in scenery.route._p: route_points.append([snappedf(p.x, 0.1), snappedf(p.y, 0.01), snappedf(p.z, 0.1)])
	var report := {"schema": "mush-terrain-probe/1", "diagnostic_only": true, "x0": -150, "z0": -800, "step": step,
		"height_slope": rows, "route": route_points, "baked_extent": scenery.get_report().baked_extent_xz,
		"giants": scenery.GIANTS, "lake": [scenery.LAKE_CENTER.x, scenery.LAKE_CENTER.y, scenery.LAKE_Y], "knoll": [scenery.KNOLL.x, scenery.KNOLL.y]}
	# Junction diagnosis: surface heights and colliders along the walking line, and a sweep of
	# the player's own capsule across the junction.
	var junction_rows: Array = []
	var cast_rows: Array = []
	if scenery.get("slice_route") != null and scenery.slice_route.valid:
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var end: Vector3 = scenery.route.get_end_point()
		var heading: Vector3 = scenery.route.get_end_direction()
		var side := Vector3(-heading.z, 0.0, heading.x)
		for lateral: float in [-1.2, 0.0, 1.2]:
			for k: int in range(-60, 61):
				var at: Vector3 = end + heading * (k * 0.05) + side * lateral
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, 1))
				junction_rows.append([lateral, snappedf(k * 0.05, 0.01), snappedf((hit.position as Vector3).y, 0.0001) if not hit.is_empty() else null, String((hit.collider as Node).get_parent().name) if not hit.is_empty() else null, snappedf((hit.normal as Vector3).y, 0.001) if not hit.is_empty() else null])
		var capsule: Shape3D = game.player._capsule
		for lateral: float in [-1.2, 0.0, 1.2]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.exclude = [game.player.get_rid()]
			var from: Vector3 = end - heading * 2.0 + side * lateral
			var ground: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 3.0, from + Vector3.DOWN * 3.0, 1))
			var base_y: float = (ground.position as Vector3).y if not ground.is_empty() else end.y
			query.transform = Transform3D(Basis(), Vector3(from.x, base_y + 0.505 + 0.02, from.z))
			query.motion = heading * 4.0
			var fractions: PackedFloat32Array = space.cast_motion(query)
			var info: Dictionary = {}
			if fractions.size() == 2 and fractions[1] < 1.0:
				query.transform.origin += query.motion * fractions[1]
				query.motion = Vector3.ZERO
				info = space.get_rest_info(query)
			cast_rows.append({"lateral": lateral, "fractions": fractions, "blocked_at_m": fractions[1] * 4.0 - 2.0 if fractions.size() == 2 else null, "rest": {"point": info.get("point"), "normal": info.get("normal"), "collider": String(instance_from_id(info.get("collider_id")).get_parent().name) if info.has("collider_id") else null}})
	# Knoll-summit ribbon map: which collider is uppermost on a 0.5 m grid around the junction
	# ('O' existing route, 'S' slice, '.' none: rendered terrain shows there).
	if scenery.get("slice_route") != null and scenery.slice_route.valid:
		var space2: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var centre: Vector3 = scenery.route.get_end_point()
		var rows_map: Array = []
		for j: int in range(-60, 61):
			var line: String = ""
			for i: int in range(-60, 61):
				var at := Vector3(centre.x + i * 0.5, centre.y + 30.0, centre.z + j * 0.5)
				var hit: Dictionary = space2.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 60.0, 1))
				if hit.is_empty(): line += "."
				elif hit.collider == scenery.route._body: line += "O"
				elif hit.collider == scenery.slice_route._body: line += "S"
				else: line += "?"
			rows_map.append(line)
		report["summit_map"] = {"origin": [centre.x - 30.0, centre.z - 30.0], "step": 0.5, "rows_z_ascending": rows_map}
		var near: Array = []
		for k: int in scenery.slice_route._p.size():
			var p: Vector3 = scenery.slice_route._p[k]
			var best: float = INF
			for q: Vector3 in scenery.route._p: best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
			if best < 12.0: near.append([k, snappedf(p.x, 0.1), snappedf(p.y, 0.01), snappedf(p.z, 0.1), snappedf(best, 0.01)])
		report["slice_near_existing_route"] = near
		# Junction cross-section gap widths: for each lateral offset, the longest run along the
		# heading (1 cm steps, -1.5..+1.5 m) with no ribbon collider under the ray.
		var heading2: Vector3 = scenery.route.get_end_direction()
		var side2 := Vector3(-heading2.z, 0.0, heading2.x)
		var gaps: Array = []
		for li: int in range(-24, 25):
			var lateral: float = li * 0.25
			var run: int = 0
			var longest: int = 0
			var at_longest: float = 0.0
			for k: int in range(-150, 151):
				var at: Vector3 = centre + heading2 * (k * 0.01) + side2 * lateral + Vector3.UP * 30.0
				var hit: Dictionary = space2.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 60.0, 1))
				var on_ribbon: bool = not hit.is_empty() and (hit.collider == scenery.route._body or hit.collider == scenery.slice_route._body)
				run = 0 if on_ribbon else run + 1
				if run > longest:
					longest = run
					at_longest = k * 0.01
			gaps.append([lateral, longest * 0.01, at_longest])
		report["junction_gap_widths"] = gaps
	report["junction_rows"] = junction_rows
	report["capsule_casts"] = cast_rows
	var file := FileAccess.open(output.path_join("terrain.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("TERRAIN_PROBE_COMPLETE")
	game._quit_clean(0)
