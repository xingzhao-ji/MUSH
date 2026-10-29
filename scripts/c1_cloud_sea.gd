extends Node3D
## Static, visual-only C1 cloud sea. One native twelve-triangle box per spatial
## ellipsoid bounds a depth-clipped ray integration; no custom mesh channels,
## collision, physics forces, lights, or autonomous process. The scenery owns
## ordinary night/rain/sun updates through its existing material registry.
const CLOUD_SHADER: Shader = preload("res://assets/world/c1_cloud_sea.gdshader")
## [C1 pixel x, horizontal distance, centre y, radius x, radius y, radius z].
## Lower broad banks close the water surface; smaller higher banks break the
## outline and submerge subordinate islands without burying the principal crowns.
const BANKS: Array = [
	[700.0, 580.0, -11.0, 205.0, 62.0, 160.0],
	[1030.0, 720.0, -1.0, 260.0, 70.0, 190.0],
	[1250.0, 850.0, 0.0, 280.0, 70.0, 225.0],
	[430.0, 980.0, 7.0, 235.0, 66.0, 210.0],
	[670.0, 1020.0, 13.0, 310.0, 72.0, 235.0],
	[920.0, 1100.0, 11.0, 330.0, 75.0, 245.0],
	[1170.0, 1250.0, 19.0, 340.0, 84.0, 260.0],
	[530.0, 1430.0, 27.0, 330.0, 80.0, 255.0],
	[790.0, 1500.0, 25.0, 360.0, 85.0, 275.0],
	[1060.0, 1650.0, 35.0, 390.0, 90.0, 300.0],
	[1280.0, 1800.0, 40.0, 430.0, 96.0, 330.0],
	[400.0, 1900.0, 40.0, 370.0, 88.0, 280.0],
	[670.0, 2050.0, 45.0, 430.0, 95.0, 340.0],
	[920.0, 2200.0, 53.0, 430.0, 100.0, 350.0],
	[680.0, 780.0, -7.0, 235.0, 68.0, 210.0],
	[1080.0, 1320.0, 45.0, 210.0, 52.0, 150.0],
	[580.0, 1670.0, 59.0, 230.0, 58.0, 180.0],
	# Seven taller, smaller banks break the low sea into rounded cloud crowns.
	# Their bases overlap the broad layers; no independent floating puff bases.
	[680.0, 780.0, 25.0, 130.0, 58.0, 115.0],
	[900.0, 710.0, 15.0, 145.0, 65.0, 130.0],
	[1100.0, 880.0, 25.0, 160.0, 76.0, 140.0],
	[1230.0, 1080.0, 45.0, 165.0, 70.0, 145.0],
	[600.0, 1350.0, 35.0, 145.0, 80.0, 120.0],
	[830.0, 1660.0, 50.0, 180.0, 90.0, 160.0],
	[1120.0, 1720.0, 70.0, 195.0, 90.0, 175.0],
]
var _materials: Array[ShaderMaterial] = []
var _configured: bool = false
var _quality: String = "balanced"
var _report: Dictionary = {}

func configure(scene: Node3D, eye: Vector3) -> Dictionary:
	if _configured: return get_report()
	if not is_instance_valid(scene) or get_parent() != scene or not eye.is_finite() or not scene.has_method("_c1_point"):
		return {"enabled": false, "reason": "Requires a direct scenery parent, finite eye, and C1 placement helper"}
	var shared_materials: Array = scene.get("_geology_materials")
	var shared_static: Array = scene.get("_static")
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * 2.0
	var placements: Array[Dictionary] = []
	for i: int in BANKS.size():
		var spec: Array = BANKS[i]
		var point: Vector2 = scene.call("_c1_point", eye, float(spec[0]), float(spec[1]))
		var centre := Vector3(point.x, float(spec[2]), point.y)
		var radii := Vector3(float(spec[3]), float(spec[4]), float(spec[5]))
		if not centre.is_finite() or not radii.is_finite() or minf(radii.x, minf(radii.y, radii.z)) <= 0.0:
			return {"enabled": false, "reason": "Non-finite or non-positive bank extent", "bank": i}
		var material := ShaderMaterial.new()
		material.shader = CLOUD_SHADER
		material.set_shader_parameter("bank_center", centre)
		material.set_shader_parameter("bank_radii", radii)
		material.set_shader_parameter("seed", 1.73 * float(i))
		material.set_shader_parameter("density", 0.022 if i >= 17 else (0.016 if i < 14 else 0.013))
		material.set_shader_parameter("lobe_strength", 1.0 if i >= 17 else 0.55)
		material.set_shader_parameter("march_steps", _march_steps())
		material.set_shader_parameter("cloud_lit", Color("c6c7e1"))
		material.set_shader_parameter("cloud_shade", Color("777ba3"))
		material.set_shader_parameter("cloud_warm", Color("cfc3c9"))
		material.set_shader_parameter("cloud_night_lit", Color("666c96"))
		material.set_shader_parameter("cloud_night_shade", Color("2c2d4c"))
		_materials.append(material)
		shared_materials.append(material)
		var node := MeshInstance3D.new()
		node.name = "C1CloudBank%02d" % i
		node.mesh = box
		node.material_override = material
		node.position = centre
		node.scale = radii
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node)
		shared_static.append(node)
		placements.append({"center": centre, "radii": radii, "top_y": centre.y + radii.y})
	_configured = true
	_report = {"enabled": true, "banks": BANKS.size(), "container_triangles": BANKS.size() * 12,
		"placements": placements, "geometry": "Shared native BoxMesh, analytic soft ellipsoid bounds, opaque-depth clipping",
		"colliders": 0, "new_lights": 0, "animation": "Static; no independent clock or wind", "max_ray_samples": 16,
		"low_camera_fade": "Distance and height fade; ground-level visibility is not exhaustively verified"}
	return get_report()

func _march_steps() -> int:
	return 8 if _quality == "low" else (16 if _quality == "high" else 12)

func set_quality(value: String) -> void:
	var chosen: String = value if value in ["low", "balanced", "high"] else "balanced"
	if chosen == _quality: return
	_quality = chosen
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("march_steps", _march_steps())

func get_report() -> Dictionary:
	var result: Dictionary = _report.duplicate(true)
	result["quality"] = _quality
	result["ray_samples"] = _march_steps()
	return result
