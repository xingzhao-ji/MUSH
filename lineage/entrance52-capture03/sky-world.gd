extends "res://lineage/entrance52-appearance-proposal02/cap-world.gd"

const SKY_DATA: String = "res://lineage/sky36-proposal01/constellations.json"
var _r36_root: Node3D
var _r36_lines: Node3D
var _r36_sun: MeshInstance3D
var _r36_star_transforms: Array[Transform3D] = []
var _r36_patterns: Array = []
var _r36_edges: int = 0
var _r36_light_rng_exact: bool = false
var _r36_errors: Array[String] = []
var _r36_star_material: StandardMaterial3D

func _create_lighting() -> void:
	super._create_lighting()
	var original_rng: int = _rng.state
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(SKY_DATA)) != OK or not json.data is Dictionary:
		_r36_errors.append("Sky36 data failed to parse")
		return
	var data: Dictionary = json.data as Dictionary
	if data.get("schema", "") != "mush-sky36-constellation-data/1" or data.get("revision", "") != "sky36-full-heavens-v1":
		_r36_errors.append("Sky36 data schema/revision differs")
		return
	_r36_patterns = data["patterns"] as Array
	_r36_root = Node3D.new()
	_r36_root.name = "ProposedSky36"
	add_child(_r36_root)
	_stars.reparent(_r36_root, false)
	_r36_lines = Node3D.new()
	_r36_lines.name = "FictionalConstellations"
	_r36_root.add_child(_r36_lines)
	var stars_info: Dictionary = data["stars"] as Dictionary
	var radius: float = float(stars_info["radius_m_proposed"])
	var count: int = int(stars_info["random_count"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(stars_info["seed"])
	var star_mesh: Mesh = _stars.multimesh.mesh
	_r36_star_material = star_mesh.surface_get_material(0) as StandardMaterial3D
	for i: int in range(count):
		var y: float = rng.randf_range(float(stars_info["upper_hemisphere_min_y"]), 1.0)
		var angle: float = rng.randf_range(0.0, TAU)
		var horizontal: float = sqrt(maxf(0.0, 1.0 - y * y))
		var point: Vector3 = Vector3(sin(angle) * horizontal, y, -cos(angle) * horizontal) * radius
		var scale_value: float = rng.randf_range(1.2, 4.8)
		if i % 47 == 0:
			scale_value = rng.randf_range(6.0, 9.0)
		_r36_star_transforms.append(Transform3D(Basis().scaled(Vector3.ONE * scale_value), point))
	var line_material: StandardMaterial3D = _r36_star_material.duplicate(false) as StandardMaterial3D
	line_material.albedo_color = Color("405978")
	line_material.emission = Color("617ea7")
	line_material.emission_energy_multiplier = 0.24
	for pattern: Dictionary in _r36_patterns:
		var azimuth: float = deg_to_rad(float(pattern["azimuth_deg"]))
		var altitude: float = deg_to_rad(float(pattern["altitude_deg"]))
		var direction: Vector3 = Vector3(sin(azimuth) * cos(altitude), sin(altitude), -cos(azimuth) * cos(altitude))
		var east: Vector3 = Vector3(cos(azimuth), 0.0, sin(azimuth))
		var up: Vector3 = east.cross(direction).normalized()
		var points: Array[Vector3] = []
		for coordinates: Array in pattern["points"]:
			var point: Vector3 = (direction + east * float(coordinates[0]) * 0.10 + up * float(coordinates[1]) * 0.10).normalized() * radius
			points.append(point)
			_r36_star_transforms.append(Transform3D(Basis().scaled(Vector3.ONE * 9.0), point))
		for edge: Array in pattern["edges"]:
			_sky36_line(points[int(edge[0])], points[int(edge[1])], line_material)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = star_mesh
	multimesh.instance_count = _r36_star_transforms.size()
	for i: int in range(_r36_star_transforms.size()):
		multimesh.set_instance_transform(i, _r36_star_transforms[i])
	_stars.multimesh = multimesh
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sun_material: StandardMaterial3D = _r36_star_material.duplicate(false) as StandardMaterial3D
	sun_material.albedo_color = Color("ffe3a4")
	sun_material.emission = Color("ffdea0")
	sun_material.emission_energy_multiplier = 2.1
	_r36_sun = _sphere(Vector3.ZERO, Vector3.ONE * 1.8, sun_material, _r36_root, 32, 20)
	_r36_sun.name = "VisibleSun"
	_r36_sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_r36_light_rng_exact = _rng.state == original_rng

func _sky36_line(a: Vector3, b: Vector3, material: StandardMaterial3D) -> void:
	var delta: Vector3 = b - a
	var y: Vector3 = delta.normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.040
	mesh.bottom_radius = 0.040
	mesh.height = delta.length()
	mesh.radial_segments = 6
	mesh.rings = 1
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "ConstellationLink" + str(_r36_edges)
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_r36_lines.add_child(instance)
	_r36_edges += 1

func _batch_static_meshes() -> void:
	# Original batching drops per-node shadow settings. Keep celestial geometry out.
	if is_instance_valid(_r36_lines):
		for child: MeshInstance3D in _r36_lines.get_children(): child.hide()
	if is_instance_valid(_r36_sun): _r36_sun.hide()
	super._batch_static_meshes()
	if is_instance_valid(_r36_lines):
		for child: MeshInstance3D in _r36_lines.get_children(): child.show()
	if is_instance_valid(_r36_sun): _r36_sun.show()

func _apply_appearance() -> void:
	super._apply_appearance()
	if is_instance_valid(_r36_lines):
		_r36_lines.visible = night_amount > 0.6 and rain_amount < 0.4
	if is_instance_valid(_r36_sun):
		_r36_sun.visible = night_amount < 0.4
		_r36_sun.position = sun.global_basis.z.normalized() * 120.0

func _process(delta: float) -> void:
	super._process(delta)
	# Celestial objects stay distant while walking; actual scenery keeps parallax.
	if is_instance_valid(_r36_root):
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null: _r36_root.global_position = camera.global_position

func get_sky36_report() -> Dictionary:
	var errors: Array[String] = _r36_errors.duplicate()
	if not is_instance_valid(_r36_root) or not is_instance_valid(_r36_sun) or not is_instance_valid(_r36_lines) or not is_instance_valid(_stars) or _stars.multimesh == null:
		errors.append("Sky36 construction refused or incomplete")
		return {"schema": "mush-sky36-heavens/1", "passed": false, "errors": errors, "source_adopted": false, "art_approved": false, "scope": "Sky construction refusal; no native/render evidence."}
	var octants: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	var poses_exact: bool = is_instance_valid(_stars) and _stars.multimesh.instance_count == _r36_star_transforms.size()
	for i: int in range(_r36_star_transforms.size()):
		var authored: Transform3D = _r36_star_transforms[i]
		var actual: Transform3D = _stars.multimesh.get_instance_transform(i)
		poses_exact = poses_exact and var_to_bytes(authored) == var_to_bytes(actual)
		var angle: float = fposmod(atan2(actual.origin.x, -actual.origin.z), TAU)
		octants[mini(7, int(angle / (TAU / 8.0)))] += 1
		if not actual.origin.is_finite() or actual.origin.y <= 0.0 or absf(actual.origin.length() - 120.0) > 0.001:
			errors.append("Celestial star is outside authored upper hemisphere")
	if not poses_exact: errors.append("Native star transforms differ from authored poses")
	if not _r36_light_rng_exact: errors.append("Sky authoring changed original lighting RNG")
	if octants.min() < 200: errors.append("Stars do not cover the full upper hemisphere")
	if _r36_patterns.size() != 8 or _r36_edges != 48: errors.append("Constellation pattern topology differs")
	var lines_preserved: bool = _r36_lines.get_child_count() == 48
	for child: MeshInstance3D in _r36_lines.get_children():
		lines_preserved = lines_preserved and child.mesh != null and child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not lines_preserved or _r36_sun.mesh == null: errors.append("Sky geometry was consumed by scenery batching")
	return {"schema": "mush-sky36-heavens/1", "passed": errors.is_empty(), "sky_meshes_retained_outside_batches": lines_preserved and _r36_sun.mesh != null, "errors": errors, "source_sha256": FileAccess.get_sha256(get_script().resource_path), "data_sha256": FileAccess.get_sha256(SKY_DATA), "random_stars": 2400, "total_stars": _r36_star_transforms.size(), "constellations": _r36_patterns.size(), "links": _r36_edges, "azimuth_octant_populations": octants, "native_star_poses_equal": poses_exact, "original_rng_preserved": _r36_light_rng_exact, "moon_visible": _moon.visible, "sun_visible": _r36_sun.visible, "stars_visible": _stars.visible, "constellations_visible": _r36_lines.visible, "sun_direction": [_r36_sun.position.x, _r36_sun.position.y, _r36_sun.position.z], "night_amount": night_amount, "rain_amount": rain_amount, "source_adopted": false, "art_approved": false, "scope": "Proposed full upper sky using existing unshaded star material, preserved moon and a visible sun aligned with existing directional light. Private RNG; no world light, shader, ground, physics, restoration, UI or travel changes. Native transform proof requires actual rendered replay; authoring/pixels/free-camera/performance remain separate evidence."}
