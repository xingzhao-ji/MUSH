extends Node
## Diagnostic only: observable near-crown LOD transitions. A fixed-orientation review camera
## aimed at one dense-crown batch moves 130 m -> 70 m -> 130 m in 2 m steps with world and
## environmental motion frozen; rendered primitives are logged at every step, so the actual
## switch distances (with Godot's hysteresis) appear as primitive jumps. Frames on both sides
## of each jump are kept. Pop magnitude is isolated at one identical pose (dense vs forced
## far LOD, plus a no-change repeat as the noise floor), measured inside the batch's projected
## screen rectangle. Stills only: this is not manual motion review.
const SIZE := Vector2i(1280,720)
var game: Node
var scenery: Node
var output := "user://verification/lod"

func _ready() -> void:
	game = get_parent()
	_run.call_deferred()

func _v(value: Vector3) -> Array:
	return [snappedf(value.x,0.01),snappedf(value.y,0.01),snappedf(value.z,0.01)]

func _settle(frames: int) -> void:
	for _i: int in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _grab(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	if label != "": frame.save_png(output.path_join(label + ".png"))
	return frame

func _roi(camera: Camera3D, node: MultiMeshInstance3D) -> Rect2i:
	var box: AABB = node.global_transform * node.get_aabb()
	var rect := Rect2()
	var first := true
	for i: int in 8:
		var corner: Vector3 = box.get_endpoint(i)
		if camera.is_position_behind(corner): continue
		var point: Vector2 = camera.unproject_position(corner)
		rect = Rect2(point, Vector2.ZERO) if first else rect.expand(point)
		first = false
	var clipped: Rect2 = rect.intersection(Rect2(Vector2.ZERO, Vector2(SIZE)))
	return Rect2i(clipped.position.floor(), clipped.size.ceil())

func _diff(a: Image, b: Image, roi: Rect2i) -> Dictionary:
	var changed: int = 0
	var total: float = 0.0
	var count: int = 0
	for y: int in range(roi.position.y, roi.end.y, 2):
		for x: int in range(roi.position.x, roi.end.x, 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			var d: float = maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))
			total += d
			count += 1
			if d > 24.0 / 255.0: changed += 1
	return {"changed_fraction": snappedf(float(changed) / maxf(count, 1), 0.0001), "mean_abs": snappedf(total / maxf(count, 1) * 255.0, 0.01), "sampled_pixels": count}

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index: int in range(arguments.size()-1):
		if arguments[index] == "--report-dir": output = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	game.get_window().content_scale_size = SIZE
	game.get_window().size = SIZE
	scenery = game.get("prototype_scenery")
	var report: Dictionary = {"schema":"mush-lod-check/1", "diagnostic_only":true, "manual_motion_verified":false}
	if not is_instance_valid(scenery) or not is_instance_valid(scenery.route):
		report["error"] = "prototype scenery or route absent"
		_finish(report, false)
		return
	game.ui.hide()
	game.player.visible = false
	game.world.set_appearance(false, false, false)
	await get_tree().create_timer(4.5).timeout
	# Freeze world living motion and the shared environment (wind, clouds) for stills.
	game.world.set_living_motion_enabled(false)
	game.environment_controller.set_foreground(false)
	game.world.set_environment_foreground(false)
	scenery.set_frozen(true)
	var near: MultiMeshInstance3D = null
	var far: MultiMeshInstance3D = null
	var best: float = INF
	for node: Node in scenery.get_children():
		if node.get_meta("lod_range", "") != "near": continue
		for point: Vector3 in scenery.route._p:
			var gap: float = (node as Node3D).global_position.distance_to(point)
			if gap < best:
				best = gap
				near = node
	if near == null:
		report["error"] = "no near-LOD batch"
		_finish(report, false)
		return
	# The far LOD partner shares the batch cell, so it is the nearest far batch.
	var far_gap: float = INF
	for node: Node in scenery.get_children():
		if node.get_meta("lod_range", "") == "far" and (node as Node3D).global_position.distance_to(near.global_position) < far_gap:
			far_gap = (node as Node3D).global_position.distance_to(near.global_position)
			far = node
	var centre: Vector3 = near.global_position
	var route_point: Vector3 = scenery.route._p[0]
	for point: Vector3 in scenery.route._p:
		if point.distance_to(centre) < route_point.distance_to(centre): route_point = point
	var heading: Vector3 = Vector3(route_point.x - centre.x, 0.0, route_point.z - centre.z).normalized()
	var camera: Camera3D = game.review_camera
	camera.fov = 50.0
	camera.make_current()
	report["batch"] = {"name":String(near.name), "instances":near.multimesh.instance_count, "centre":_v(centre), "far_partner":String(far.name) if far != null else null, "route_point":_v(route_point), "range_end":near.visibility_range_end, "end_margin":near.visibility_range_end_margin}
	# 1. Sweep 130 -> 70 -> 130 m at fixed orientation; log primitives every step.
	var distances: Array[float] = []
	for d: int in range(130, 69, -2): distances.append(float(d))
	for d: int in range(72, 131, 2): distances.append(float(d))
	var sweep: Array = []
	var previous: float = -1.0
	var previous_frame: Image = null
	var jumps: Array = []
	for i: int in distances.size():
		var d: float = distances[i]
		camera.global_position = centre + heading * d + Vector3.UP * 10.0
		camera.look_at(centre + Vector3.UP * 6.0)
		await _settle(4)
		var prims: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var frame: Image = await _grab("")
		sweep.append({"step":i, "distance_m":d, "direction":"in" if i < 31 else "out", "primitives":prims})
		if previous >= 0.0 and absf(prims - previous) > 20000.0:
			var tag: String = "jump-%02d" % jumps.size()
			previous_frame.save_png(output.path_join(tag + "-before.png"))
			frame.save_png(output.path_join(tag + "-after.png"))
			var roi: Rect2i = _roi(camera, near)
			jumps.append({"before_distance_m":distances[i - 1], "after_distance_m":d, "primitives_before":previous, "primitives_after":prims, "files":[tag + "-before.png", tag + "-after.png"], "roi":[roi.position.x, roi.position.y, roi.size.x, roi.size.y], "roi_diff_including_2m_move":_diff(previous_frame, frame, roi)})
		previous = prims
		previous_frame = frame
	report["sweep"] = sweep
	report["jumps"] = jumps
	# 2. Isolated pop at one identical pose (95 m: inside the near range on approach).
	camera.global_position = centre + heading * 95.0 + Vector3.UP * 10.0
	camera.look_at(centre + Vector3.UP * 6.0)
	await _settle(6)
	var roi_iso: Rect2i = _roi(camera, near)
	var dense_a: Image = await _grab("isolated-dense")
	await _settle(6)
	var dense_b: Image = await _grab("isolated-dense-repeat")
	var far_begin: float = far.visibility_range_begin if far != null else 0.0
	near.visible = false
	if far != null: far.visibility_range_begin = 0.0
	await _settle(6)
	var far_frame: Image = await _grab("isolated-far-lod")
	near.visible = true
	if far != null: far.visibility_range_begin = far_begin
	report["isolated"] = {"distance_m":95.0, "roi":[roi_iso.position.x, roi_iso.position.y, roi_iso.size.x, roi_iso.size.y], "noise_floor":_diff(dense_a, dense_b, roi_iso), "lod_change":_diff(dense_a, far_frame, roi_iso), "files":["isolated-dense.png","isolated-dense-repeat.png","isolated-far-lod.png"]}
	_finish(report, true)

func _finish(report: Dictionary, ok: bool) -> void:
	report["passed"] = ok
	var file := FileAccess.open(output.path_join("lod.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("LOD_CHECK_COMPLETE ", ok)
	game._quit_clean(0 if ok else 1)
