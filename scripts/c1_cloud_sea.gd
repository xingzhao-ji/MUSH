extends Node3D
## Static, visual-only C1 cloud sea. One native twelve-triangle box per spatial
## ellipsoid bounds a depth-clipped ray integration; no custom mesh channels,
## collision, physics forces, lights, or autonomous process. The scenery owns
## ordinary night/rain/sun updates through its existing material registry.
const CLOUD_SHADER: Shader = preload("res://assets/world/c1_cloud_sea.gdshader")
## [C1 pixel x, horizontal distance, centre y, radius x, radius y, radius z, density, lobe strength].
## Milestone 9 (ChatGPT checkpoint 9: the continuous blanket hid the valley's islands and water): separate, smaller,
## translucent banks between the cliffs in the near and middle valley so ~half of its floor shows; the far broad
## layers keep the distance soft; a few taller crowns where the falls land.
const BANKS: Array = [
	# near and middle valley: separated banks between the masses
	[600.0, 640.0, -22.0, 125.0, 58.0, 100.0, 0.009, 1.0],  # M10b: taller, softer top (a hard edge at frame y ~430)
	[860.0, 780.0, -12.0, 150.0, 46.0, 115.0, 0.011, 0.7],
	[1170.0, 880.0, -8.0, 140.0, 48.0, 115.0, 0.012, 0.7],
	[470.0, 1080.0, 2.0, 165.0, 52.0, 130.0, 0.012, 0.7],
	[1000.0, 1180.0, 10.0, 175.0, 56.0, 140.0, 0.012, 0.7],
	# thin translucent ground haze: softens the exposed valley floor without hiding islands and water
	[780.0, 760.0, -30.0, 330.0, 26.0, 260.0, 0.0028, 0.35],
	[1080.0, 1000.0, -22.0, 360.0, 28.0, 280.0, 0.0028, 0.35],
	[560.0, 1050.0, -20.0, 300.0, 26.0, 240.0, 0.0028, 0.35],
	# far broad layers (distance haze over the far valley floor)
	[530.0, 1430.0, 27.0, 330.0, 80.0, 255.0, 0.011, 0.55],
	[790.0, 1500.0, 25.0, 360.0, 85.0, 275.0, 0.011, 0.55],
	[1060.0, 1650.0, 35.0, 390.0, 90.0, 300.0, 0.011, 0.55],
	[1280.0, 1800.0, 40.0, 430.0, 96.0, 330.0, 0.011, 0.55],
	[400.0, 1900.0, 40.0, 370.0, 88.0, 280.0, 0.011, 0.55],
	[670.0, 2050.0, 45.0, 430.0, 95.0, 340.0, 0.011, 0.55],
	[920.0, 2200.0, 53.0, 430.0, 100.0, 350.0, 0.011, 0.55],
	# M10 (ChatGPT checkpoint 12: the viaduct's even arch cadence read as a wall): mist around its middle piers
	[800.0, 900.0, 70.0, 150.0, 75.0, 110.0, 0.011, 0.8],
	# M10b (ChatGPT checkpoint 13: the smooth basin-wall domes at frame 440-900 x 60-310 enclose the scene; Fable: lit
	# cloud puffs): sunset cloud masses in front of the domes, so the backdrop reads as clouds and staggered crests.
	# (M10e, ChatGPT checkpoint 15 / Fable: sunset cloud #F2C1A6, lit tops #F3CDD0, bases #9A8FC8; a ninth field marks
	# a warm sunset bank)
	# (M11, ChatGPT checkpoint 16 / Fable fifth look: at density 0.01 and centre y 330 they were invisible, #ABA5C3
	# against a #B1AAC6 sky; frame y 100-220 at 1.6-1.9 km is world y ~290-560): denser, higher, staggered.
	[585.0, 1650.0, 430.0, 300.0, 120.0, 230.0, 0.024, 1.0, true],
	[700.0, 1820.0, 500.0, 260.0, 105.0, 210.0, 0.022, 1.0, true],
	[790.0, 1700.0, 400.0, 230.0, 95.0, 190.0, 0.024, 1.0, true],
	[480.0, 1900.0, 360.0, 260.0, 110.0, 220.0, 0.020, 1.0, true],
	[1215.0, 1750.0, 420.0, 260.0, 110.0, 210.0, 0.020, 1.0, true],
	# M11d (region analysis: concept-1's upper sky, frame x 300-800, y 0-120, reads L 54 b -3 with big pink-lit cumulus;
	# ours L 46 b -12): high warm cumulus at 2.4-3.2 km, world y 700-950 (frame y ~20-110)
	[420.0, 2600.0, 820.0, 420.0, 130.0, 320.0, 0.012, 1.0, true],
	[640.0, 3000.0, 950.0, 480.0, 140.0, 360.0, 0.011, 1.0, true],
	[820.0, 2400.0, 760.0, 360.0, 110.0, 280.0, 0.012, 1.0, true],
	# lower layer: the domes' lower arcs (frame y 150-230) behind a second, softer row
	[640.0, 1560.0, 300.0, 300.0, 80.0, 230.0, 0.016, 1.0, true],
	[860.0, 1650.0, 330.0, 260.0, 75.0, 200.0, 0.014, 1.0, true],
	# M10b (Fable: the arch bridge's left end sat on a rock chunk hanging in the fog): mist wrapping that end's foot
	[760.0, 700.0, 70.0, 70.0, 55.0, 60.0, 0.012, 1.0],
	# M10d (cells: the near forest at frame 640-1280 x 540-720 read L 25-36 vs the concept's 31-44, where concept-1
	# has mist between the trees): low translucent banks over the near canopy
	[1010.0, 640.0, -10.0, 220.0, 34.0, 170.0, 0.0055, 0.8],
	[1210.0, 560.0, -20.0, 180.0, 30.0, 150.0, 0.0055, 0.8],
	# taller crowns where the falls land
	[700.0, 760.0, 22.0, 105.0, 70.0, 95.0, 0.011, 1.0],  # M10e: softer (a hard top edge at frame y ~430)
	[1230.0, 1080.0, 40.0, 130.0, 62.0, 110.0, 0.017, 1.0],
	[830.0, 1660.0, 50.0, 180.0, 90.0, 160.0, 0.018, 1.0],
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
		material.set_shader_parameter("density", float(spec[6]))
		material.set_shader_parameter("lobe_strength", float(spec[7]))
		material.set_shader_parameter("march_steps", _march_steps())
		var warm_bank: bool = spec.size() > 8 and bool(spec[8])
		# (m11b: lit #F3CDD0 rendered near white after tonemapping; concept-1's banks read #F0BDBD)
		material.set_shader_parameter("cloud_lit", Color("eeb0b8") if warm_bank else Color("b4adcf"))
		# (M11c, Fable: the shade won over the banks' bodies, #C8BDE0; shade raised toward #B9A0C0)
		material.set_shader_parameter("cloud_shade", Color("d0a4bc") if warm_bank else Color("736e98"))
		material.set_shader_parameter("cloud_warm", Color("f0a890") if warm_bank else Color("cbbcc6"))
		material.set_shader_parameter("sky_bank", warm_bank)
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
