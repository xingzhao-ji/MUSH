extends Node3D
## C1 visual-only silk balloons. Add this helper directly to the scenery before
## configure(); the caller supplies the EnvironmentController's shared wind and
## owns foreground/frozen timing. No autonomous process, physics or new lights.
## Original MUSH Forge workspace asset, accepted in codex-assets/out/manifest.json.
## Source: MUSH-exchange/codex-assets/work/spore_silk_balloon.py (original geometry
## and procedural painted textures; concept artwork was not loaded into the model).
## GLB SHA256: edbc09c227f72aa078b23231e325887851f2e2ace1d5c02c8b95494ee4918338
const MODEL: String = "res://assets/world/models/c1-procedural/spore_silk_balloon.glb"
const SOURCE_SHA256: String = "edbc09c227f72aa078b23231e325887851f2e2ace1d5c02c8b95494ee4918338"
const TRIANGLES_PER_BALLOON: int = 67660
## Basket base: concept pixel x/y, distance from eye, model height in metres.
const POSES: Array[Vector4] = [Vector4(640.0, 245.0, 900.0, 45.0), Vector4(720.0, 285.0, 1100.0, 42.0), Vector4(1085.0, 280.0, 1500.0, 55.0)]
const YAWS: Array[float] = [0.25, -0.65, 1.1]
const PHASES: Array[float] = [0.0, 2.1, 4.3]
const MAX_STEP: float = 0.25
const MAX_DRIFT_M: float = 3.2
const MAX_BOB_M: float = 0.85
const MAX_TILT_RADIANS: float = 0.018
var _rigs: Array[Node3D] = []
var _anchors: Array[Vector3] = []
var _clock: float = 0.0
var _reduced_motion: bool = false
var _quality: String = "balanced"
var _configured: bool = false
var _mesh_instances: int = 0
var _report: Dictionary = {}

func configure(scene: Node3D, eye: Vector3) -> Dictionary:
	if _configured: return get_report()
	if not is_instance_valid(scene) or get_parent() != scene or not eye.is_finite():
		return {"enabled": false, "reason": "Requires a direct scenery parent and finite eye"}
	for method: String in ["_model_parts", "_model_box", "_c1_pixel_ray", "_refuge_mesh", "_blender_mat"]:
		if not scene.has_method(method): return {"enabled": false, "reason": "Missing scenery helper " + method}
	var parts: Array = scene.call("_model_parts", MODEL)
	var box: AABB = scene.call("_model_box", MODEL)
	if parts.is_empty() or not box.position.is_finite() or not box.size.is_finite() or box.size.y <= 0.001:
		return {"enabled": false, "reason": "Balloon GLB unavailable or invalid bounds"}
	var centre: Vector3 = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var placements: Array[Dictionary] = []
	for i: int in POSES.size():
		var pose: Vector4 = POSES[i]
		var ray: Vector3 = scene.call("_c1_pixel_ray", eye, pose.x, pose.y)
		var anchor: Vector3 = eye + ray * pose.z
		var rig: Node3D = Node3D.new()
		rig.name = "C1SilkBalloon%d" % i
		rig.position = anchor
		rig.rotation.y = YAWS[i]
		rig.visible = i < (2 if _quality == "low" else 3)
		add_child(rig)
		_rigs.append(rig)
		_anchors.append(anchor)
		var scale_factor: float = pose.w / box.size.y
		var fit: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -centre)
		for part_index: int in parts.size():
			var part: Array = parts[part_index]
			var mesh: Mesh = part[0] as Mesh
			var part_transform: Transform3D = part[1]
			if mesh == null: continue
			# The scenery helper registers these meshes for its ordinary visual-only
			# diagnostics; reparent without changing their fitted local coordinates.
			var node: MeshInstance3D = scene.call("_refuge_mesh", mesh, null, fit * part_transform, "C1SilkBalloon%d_%d" % [i, part_index]) as MeshInstance3D
			node.reparent(rig, false)
			for surface_index: int in mesh.get_surface_count():
				var source: StandardMaterial3D = mesh.surface_get_material(surface_index) as StandardMaterial3D
				if source == null: continue
				var material: StandardMaterial3D = scene.call("_blender_mat", source) as StandardMaterial3D
				node.set_surface_override_material(surface_index, material)
			_mesh_instances += 1
		placements.append({"basket_base": anchor, "height_m": pose.w, "distance_m": pose.z})
	_configured = true
	_report = {"enabled": true, "asset": MODEL, "source_sha256": SOURCE_SHA256, "placements": placements,
		"mesh_instances": _mesh_instances, "shared_model_meshes": parts.size(), "triangles_per_balloon": TRIANGLES_PER_BALLOON,
		"materials": "Cached scenery Blender materials; embedded texture and ordinary day/night/rain handling",
		"motion": "Three bounded whole-rig transforms; shared external wind; ropes remain attached",
		"horizontal_drift_bound_m": MAX_DRIFT_M, "vertical_bob_bound_m": MAX_BOB_M, "tilt_bound_radians": MAX_TILT_RADIANS,
		"colliders": 0, "gameplay_forces": false, "new_lights": 0, "continuous_motion_reviewed": false}
	return get_report()

func set_reduced_motion(value: bool) -> void:
	# Freeze at the current pose: entering/leaving the setting introduces no snap.
	_reduced_motion = value

func set_quality(value: String) -> void:
	var selected: String = value if value in ["low", "balanced", "high"] else "balanced"
	if selected == _quality: return
	_quality = selected
	for i: int in _rigs.size():
		_rigs[i].visible = i < (2 if _quality == "low" else 3)

func update_motion(delta: float, shared_wind_direction: Vector3, shared_wind_strength: float, quality: String = "balanced") -> void:
	set_quality(quality)
	if not _configured or _reduced_motion or (is_inside_tree() and get_tree().paused): return
	if not is_finite(delta) or delta <= 0.0 or not shared_wind_direction.is_finite() or not is_finite(shared_wind_strength): return
	var direction: Vector3 = Vector3(shared_wind_direction.x, 0.0, shared_wind_direction.z)
	if direction.length_squared() < 0.000001: return
	direction = direction.normalized()
	var strength: float = clampf(shared_wind_strength, 0.0, 1.0)
	_clock += minf(delta, MAX_STEP)
	# Zero-relative sinusoids start exactly at the authored pose. All movement is
	# bounded about that anchor; no integration drift, mesh edits or detached ropes.
	for i: int in _rigs.size():
		var phase: float = PHASES[i]
		var drift: float = 0.5 * MAX_DRIFT_M * strength * (sin(_clock * 0.13 + phase) - sin(phase))
		var bob: float = 0.5 * MAX_BOB_M * strength * (sin(_clock * 0.19 + phase * 0.7) - sin(phase * 0.7))
		var tilt: float = 0.5 * MAX_TILT_RADIANS * strength * (sin(_clock * 0.17 + phase) - sin(phase))
		var rotation_basis: Basis = Basis(Vector3(direction.z, 0.0, -direction.x), tilt) * Basis(Vector3.UP, YAWS[i])
		_rigs[i].transform = Transform3D(rotation_basis, _anchors[i] + direction * drift + Vector3.UP * bob)

func get_report() -> Dictionary:
	var result: Dictionary = _report.duplicate(true)
	result["quality"] = _quality
	result["visible_balloons"] = mini(_rigs.size(), 2 if _quality == "low" else 3)
	result["visible_triangles"] = int(result["visible_balloons"]) * TRIANGLES_PER_BALLOON
	result["reduced_motion"] = _reduced_motion
	result["clock_seconds"] = _clock
	return result
