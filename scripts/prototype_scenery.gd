extends Node3D
## Reversible far-layer scenery: luminous umbrella canopies, their stems and
## natural rock spires. Built once at startup; no colliders, shadows or per-frame
## geometry. Selected by project setting mush/prototype/scenery or the
## --prototype-scenery=on|off user argument.
const SHADER := preload("res://assets/world/far_canopy.gdshader")
const FAR_PLANE := 1400.0
const DAY_SUN := Color("ffc07e")
const NIGHT_SUN := Color("a9a6ee")

var canopy_triangles: int = 0
var spire_triangles: int = 0
var canopy_count: int = 0
var spire_count: int = 0
var frozen: bool = false
var _time: float = 0.0
var _reduced_motion: bool = false
var _night: float = 0.0
var _rain: float = 0.0
var _art: Array[ShaderMaterial] = []
var _mask: StandardMaterial3D
var _nodes: Array[MultiMeshInstance3D] = []
var _masked: bool = false
var _world: Node3D

static func is_enabled() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--prototype-scenery=off": return false
		if argument == "--prototype-scenery=on": return true
	return bool(ProjectSettings.get_setting("mush/prototype/scenery", false))

func configure(world: Node3D) -> void:
	_world = world
	name = "PrototypeScenery"
	_mask = StandardMaterial3D.new()
	_mask.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mask.albedo_color = Color(1, 0, 1)
	_mask.disable_fog = true
	_mask.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ridge_noise = FastNoiseLite.new()
	_ridge_noise.seed = 4242
	_ridge_noise.frequency = 0.0022
	_ridge_noise.fractal_octaves = 3
	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = 77
	_hill_noise.frequency = 0.0035
	var cap: ArrayMesh = _cap_mesh()
	var stem: ArrayMesh = _stem_mesh()
	var spire: ArrayMesh = _spire_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	# Hero giants sit beyond the playable ring and rise above the tree line; the
	# smaller companions step down in scale so distance reads as layers.
	var caps: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	var tints: Array[Color] = []
	var stem_tints: Array[Color] = []
	var specs: Array = [
		# x, z, cap radius, underside height ABOVE LOCAL GROUND, cap thickness. Mostly far and low-contrast;
		# one clear focal giant keeps its silhouette against open sky.
		[110.0, -380.0, 90.0, 140.0, 70.0],
		[-290.0, -720.0, 120.0, 210.0, 90.0],
		[430.0, -470.0, 78.0, 150.0, 60.0],
		[60.0, -1120.0, 175.0, 300.0, 130.0],
		[-520.0, -520.0, 62.0, 115.0, 48.0],
	]
	for row: Array in specs:
		var x: float = row[0]; var z: float = row[1]; var r: float = row[2]; var h: float = row[3]; var t: float = row[4]
		var yaw: float = rng.randf_range(0.0, TAU)
		var tilt := Basis(Vector3(1, 0, 0), rng.randf_range(-0.04, 0.04)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.04, 0.04))
		var ground: float = terrain_height(x, z)
		var underside: float = ground + h
		var basis: Basis = Basis(Vector3.UP, yaw) * tilt * Basis.from_scale(Vector3(r, t, r))
		caps.append(Transform3D(basis, Vector3(x, underside, z)))
		# One continuous stem from below the local ground up into the cap.
		var stem_base: float = ground - 12.0
		var stem_r: float = r * 0.12
		var sb: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(stem_r, underside + t * 0.15 - stem_base, stem_r))
		stems.append(Transform3D(sb, Vector3(x, stem_base, z)))
		if stem_base < ground and stem_base + sb.get_scale().y > underside: grounded_bases += 1
		tints.append(Color(rng.randf(), 0, 0))
		stem_tints.append(Color(rng.randf(), 0, 0))
	canopy_count = caps.size()
	_add(cap, caps, tints, 0)
	_add(stem, stems, stem_tints, 1)
	canopy_triangles = (cap.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3) * caps.size() + (stem.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3) * stems.size()
	var rocks: Array[Transform3D] = []
	var rock_tints: Array[Color] = []
	var clusters: Array = [[-380.0, -700.0, 6], [560.0, -480.0, 5], [-60.0, -900.0, 7], [-760.0, -300.0, 4], [760.0, -220.0, 4]]
	for cluster: Array in clusters:
		for i: int in int(cluster[2]):
			var sx: float = cluster[0] + rng.randf_range(-45, 45)
			var sz: float = cluster[1] + rng.randf_range(-40, 40)
			var spot := Vector3(sx, terrain_height(sx, sz) - 8.0, sz)
			var height: float = rng.randf_range(60.0, 150.0) * (1.5 if i == 0 else 1.0)
			var width: float = height * rng.randf_range(0.14, 0.24)
			var b: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.08, 0.08)) * Basis.from_scale(Vector3(width, height, width))
			rocks.append(Transform3D(b, spot))
			rock_tints.append(Color(rng.randf(), 0, 0))
	spire_count = rocks.size()
	_add(spire, rocks, rock_tints, 2)
	spire_triangles = (spire.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3) * rocks.size()
	_add_terrain()
	var ledge_rocks: Array[Transform3D] = []
	var ledge_tints: Array[Color] = []
	for spot: Vector2 in [Vector2(-64, 188), Vector2(-2, 190), Vector2(-50, 172), Vector2(16, 176), Vector2(-78, 205), Vector2(24, 200)]:
		var height: float = rng.randf_range(3.5, 8.0)
		var width: float = height * rng.randf_range(0.5, 0.8)
		var b: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.12, 0.12)) * Basis.from_scale(Vector3(width, height, width))
		ledge_rocks.append(Transform3D(b, Vector3(spot.x, terrain_height(spot.x, spot.y) - 1.5, spot.y)))
		ledge_tints.append(Color(rng.randf(), 0, 0))
	_add(spire, ledge_rocks, ledge_tints, 2)
	var player: Node = _world.get_parent().get("player")
	if player != null and is_instance_valid(player.get("_camera")):
		player._camera.far = FAR_PLANE

const TERRAIN_HALF := 1500.0
const TERRAIN_CELLS := 100
const LEDGE := Vector2(-30.0, 215.0)
const LAKE_CENTER := Vector2(-430.0, -200.0)
const LAKE_Y := -8.0
var _static: Array[MeshInstance3D] = []
var _terrain_material: ShaderMaterial
var _lake_material: ShaderMaterial
var terrain_triangles: int = 0
var _overview: bool = false
var _ridge_noise: FastNoiseLite
var _hill_noise: FastNoiseLite
var grounded_bases: int = 0

## Map-inspection haze: lighter fog so the whole world layout reads. Capture/inspection only.
func set_overview(value: bool) -> void:
	_overview = value

func terrain_height(x: float, z: float) -> float:
	var ridge: FastNoiseLite = _ridge_noise
	var hills: FastNoiseLite = _hill_noise
	var r: float = Vector2(x, z).length()
	var calm: float = smoothstep(110.0, 380.0, r)
	var lake: float = exp(-(pow(x - LAKE_CENTER.x, 2.0) + pow(z - LAKE_CENTER.y, 2.0)) / (2.0 * 110.0 * 110.0))
	var rolling: float = hills.get_noise_2d(x, z) * 20.0 * (1.0 - lake)
	# Northern highlands: a belt of ridges, steepest far from the clearing.
	var north: float = smoothstep(-250.0, -750.0, z) * (0.35 + 0.65 * (1.0 - absf(ridge.get_noise_2d(x, z))))
	var highlands: float = north * 170.0
	# Eastern meadow shelf, raised and gently terraced.
	var shelf: float = smoothstep(180.0, 520.0, x) * smoothstep(250.0, -150.0, z) * 28.0
	# Western lake basin: its shoreline is where this surface crosses LAKE_Y.
	var basin: float = lake * 70.0
	# Rim hills close the horizon on every side.
	var rim: float = maxf(0.0, r - 950.0) * 0.12
	var wanted: float = rolling + highlands + shelf - basin + rim
	# South overlook ledge: a raised promontory above the tree line, outside the playable bounds.
	var ledge: float = smoothstep(125.0, 0.0, Vector2(x - LEDGE.x, z - LEDGE.y).length()) * 44.0
	return lerpf(-1.5, wanted, calm) + ledge

func _add_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int = TERRAIN_CELLS + 1
	for row: int in columns:
		for column: int in columns:
			var x: float = lerpf(-TERRAIN_HALF, TERRAIN_HALF, float(column) / TERRAIN_CELLS)
			var z: float = lerpf(-TERRAIN_HALF, TERRAIN_HALF, float(row) / TERRAIN_CELLS)
			st.set_color(Color(0, 0, 0))
			st.set_uv(Vector2(float(column) / TERRAIN_CELLS, float(row) / TERRAIN_CELLS))
			st.add_vertex(Vector3(x, terrain_height(x, z), z))
	for row: int in TERRAIN_CELLS:
		for column: int in TERRAIN_CELLS:
			var i0: int = row * columns + column
			var i1: int = i0 + 1
			var i2: int = i0 + columns
			var i3: int = i2 + 1
			st.add_index(i0); st.add_index(i2); st.add_index(i1)
			st.add_index(i1); st.add_index(i2); st.add_index(i3)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	terrain_triangles = TERRAIN_CELLS * TERRAIN_CELLS * 2
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = SHADER
	_terrain_material.set_shader_parameter("mode", 3)
	var terrain := MeshInstance3D.new()
	terrain.name = "WorldTerrain"
	terrain.mesh = mesh
	terrain.material_override = _terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	_static.append(terrain)
	var plane := CylinderMesh.new()
	plane.top_radius = 280.0
	plane.bottom_radius = 280.0
	plane.height = 0.2
	plane.radial_segments = 64
	plane.rings = 1
	_lake_material = ShaderMaterial.new()
	_lake_material.shader = SHADER
	_lake_material.set_shader_parameter("mode", 4)
	var lake := MeshInstance3D.new()
	lake.name = "WorldLake"
	lake.mesh = plane
	lake.material_override = _lake_material
	lake.position = Vector3(LAKE_CENTER.x, LAKE_Y, LAKE_CENTER.y)
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lake)
	_static.append(lake)

func _add(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], mode: int) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", mode)
	_art.append(material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in transforms.size():
		multi.set_instance_transform(index, transforms[index])
		multi.set_instance_color(index, colors[index])
	var node := MultiMeshInstance3D.new()
	node.name = ["LuminousCanopies", "CanopyStems", "RockSpires"][mode]
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	_nodes.append(node)

# Unit umbrella: radius 1, rim near y 0, dome rising to about +1, gills below.
func _cap_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = []  # x radius, y height, z v-parameter
	var top_rows := 22
	for i: int in top_rows + 1:
		var s: float = float(i) / top_rows
		profile.append(Vector3(s, 0.10 + 0.95 * (1.0 - pow(s, 2.3)) + 0.05 * sin(s * 3.1), 0.5 * s))
	for i: int in 1:
		profile.append(Vector3(1.01, 0.0, 0.5))
	profile.append(Vector3(0.96, -0.08, 0.5))
	var under_rows := 16
	for i: int in under_rows + 1:
		var u: float = float(i) / under_rows
		profile.append(Vector3(lerpf(0.94, 0.07, u), -0.08 + 0.34 * pow(u, 1.5), 0.5 + 0.5 * u))
	return _lathe(profile, 56, true)

func _stem_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = []
	var rows := 24
	for i: int in rows + 1:
		var t: float = float(i) / rows
		var flare: float = 1.0 + 4.5 * pow(1.0 - t, 7.0)
		profile.append(Vector3(flare * (1.0 - 0.28 * t), t, t))
	return _lathe(profile, 28, false)

func _spire_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = []
	var rows := 20
	for i: int in rows + 1:
		var t: float = float(i) / rows
		profile.append(Vector3(pow(1.0 - t, 0.85) * 0.98 + 0.02, t, t))
	return _lathe(profile, 14, false, true)

func _lathe(profile: Array[Vector3], segments: int, scallop: bool, craggy: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := segments + 1
	for row: int in profile.size():
		var p: Vector3 = profile[row]
		for column: int in columns:
			var u: float = float(column) / segments
			var a: float = u * TAU
			var radius: float = p.x
			var height: float = p.y
			if scallop:
				var edge: float = pow(clampf(absf(p.x), 0.0, 1.0), 3.0)
				radius *= 1.0 + edge * (0.05 * sin(a * 7.0 + 0.6) + 0.03 * sin(a * 13.0 + 2.0))
				height += edge * 0.05 * sin(a * 9.0 + 1.3)
			if craggy:
				var wedge: float = 0.78 + 0.45 * fposmod(sin(float(column % segments) * 12.9898 + float(row) * 78.233) * 43758.5453, 1.0)
				radius *= wedge
				height += 0.02 * sin(a * 3.0 + p.y * 9.0)
			st.set_uv(Vector2(u, p.z))
			st.set_color(Color(0, 0, 0))
			st.add_vertex(Vector3(cos(a) * radius, height, sin(a) * radius))
	for row: int in profile.size() - 1:
		for column: int in segments:
			var i0: int = row * columns + column
			var i1: int = i0 + 1
			var i2: int = i0 + columns
			var i3: int = i2 + 1
			st.add_index(i0); st.add_index(i1); st.add_index(i2)
			st.add_index(i1); st.add_index(i3); st.add_index(i2)
	st.generate_normals()
	return st.commit()

func _process(delta: float) -> void:
	if frozen or _reduced_motion or (is_inside_tree() and get_tree().paused): return
	_time += delta
	for material: ShaderMaterial in _art + [_lake_material]:
		material.set_shader_parameter("shimmer_time", _time)

func set_frozen(value: bool) -> void:
	frozen = value

func set_debug_mask(enabled: bool) -> void:
	_masked = enabled
	for node: MultiMeshInstance3D in _nodes:
		node.material_override = _mask if enabled else _art[_nodes.find(node)]

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	for material: ShaderMaterial in _art:
		material.set_shader_parameter("shimmer_amount", 0.0 if value else 1.0)

## Amber/lavender grade, written after the shared lighting owner's endpoints.
func apply_look(environment: Environment, sun: DirectionalLight3D, night: float, rain: float, sunset: float) -> void:
	_night = night
	_rain = rain
	var toward_sun: Vector3 = sun.global_basis.z.normalized()
	for material: ShaderMaterial in _art + [_terrain_material, _lake_material]:
		material.set_shader_parameter("night", night)
		material.set_shader_parameter("rain", rain)
		material.set_shader_parameter("sun_dir", toward_sun)
	sun.light_color = DAY_SUN.lerp(NIGHT_SUN, night).lerp(Color("ffa86a"), sunset * 0.5)
	sun.light_energy = lerpf(1.45, 0.60, night) * lerpf(1.0, 0.65, rain)
	sun.rotation_degrees.x = lerpf(-22.0, -27.45, night)
	sun.rotation_degrees.y = lerpf(130.0, 153.79, night)
	sun.light_angular_distance = 2.2
	environment.ambient_light_color = Color("d4bcd8").lerp(Color("8f90c8"), night)
	environment.ambient_light_energy = lerpf(0.30, 0.30, night)
	var fog: Color = Color("c3a4d0").lerp(Color("2f2b5a"), night).lerp(Color("9c97b4"), rain * 0.5)
	environment.fog_light_color = fog
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 60.0
	environment.fog_depth_end = 1100.0
	environment.fog_depth_curve = 1.6
	environment.fog_density = (0.14 if _overview else lerpf(0.55, 0.80, rain))
	environment.fog_aerial_perspective = 0.35
	environment.fog_sky_affect = 0.0
	var sky: ShaderMaterial = _world.get("_cloud_sky_material")
	if sky != null:
		sky.set_shader_parameter("top_color", Color("4a4aa0").lerp(Color("141a44"), night).lerp(Color("5d5f86"), rain * 0.4))
		sky.set_shader_parameter("horizon_color", Color("ffb88a").lerp(Color("3a3466"), night).lerp(Color("a79aa8"), rain * 0.4))

## Camera pose on the overlook ledge: above the tree line, looking over forest, lake and giants.
func overlook_pose() -> Dictionary:
	var ground: float = terrain_height(LEDGE.x, LEDGE.y)
	return {"position": Vector3(LEDGE.x, ground + 3.5, LEDGE.y), "target": Vector3(-190.0, 12.0, -385.0), "fov": 80.0}

func get_report() -> Dictionary:
	var colliders: int = find_children("*", "CollisionObject3D", true, false).size()
	var shadows: int = 0
	for node: GeometryInstance3D in _nodes + _static:
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadows += 1
	return {"passed": colliders == 0 and shadows == 0, "canopies": canopy_count, "spires": spire_count, "triangles": canopy_triangles + spire_triangles + terrain_triangles, "terrain_triangles": terrain_triangles, "draw_nodes": _nodes.size() + _static.size(), "colliders": colliders, "grounded_stems": grounded_bases, "shadow_casters": shadows, "built_at_startup_only": true}
