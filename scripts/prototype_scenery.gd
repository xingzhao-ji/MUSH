extends Node3D
## Reversible far-layer scenery for the clearing: a graded terraced valley, forest
## carpet, fungal giants and rock pillars. Built once at startup; no colliders, no
## shadows, no per-frame geometry. LABELED VISUAL BLOCKOUT: none of this is walkable.
## Selected by project setting mush/prototype/scenery or --prototype-scenery=on|off.
const SHADER := preload("res://assets/world/far_canopy.gdshader")
const Route := preload("res://scripts/prototype_route.gd")
const TERRAIN_SHADER := preload("res://assets/world/far_terrain.gdshader")
const WATER_SHADER := preload("res://assets/world/far_water.gdshader")
## Existing detailed project textures (import settings unchanged; moss has no mipmaps).
const MOSS_TEXTURE := preload("res://assets/world/textures/moss-albedo-proposal-v1.png")
const ROCK_TEXTURE := preload("res://assets/world/textures/rock_01_diff_1k.jpg")
const HERO := Vector2(378.0, -648.0)
## Stem bend at the top, in stem radii; the cap sits on the bent top.
const STEM_BEND := 2.0
## Integrated buttress lobes: (angle, outward reach in stem radii), deliberately uneven.
const STEM_BUTTRESSES: Array[Vector2] = [Vector2(0.3, 1.45), Vector2(1.55, 0.95), Vector2(2.7, 1.3), Vector2(3.95, 0.75), Vector2(5.1, 1.15)]
## Far plane and fog end are chosen together: every hero element is inside 0.55 x far
## and fog reaches full strength (FOG_END) well inside the far plane.
const FAR_PLANE := 2600.0
const FOG_END := 1400.0
const TERRAIN_HALF := 1500.0
const TERRAIN_CELLS := 220
const VALLEY_DIR := Vector2(0.447, -0.894)
const LAKE_CENTER := Vector2(190.0, -330.0)
const LAKE_Y := -82.0
## Southern overlook knoll and the walkable route that climbs to it from the baked
## collider seam. The original collision box is x -24..25, z -24..29; the player's
## original movement box ends at z 26, so a short explicit approach strip joins them.
const KNOLL := Vector2(72.0, 215.0)
const ROUTE_SEAM := Vector2(-2.0, 29.0)
const ROUTE_WAYPOINTS: Array[Vector2] = [Vector2(-2.0, 29.0), Vector2(-3.0, 45.0), Vector2(-1.0, 62.0), Vector2(6.0, 80.0), Vector2(24.0, 96.0), Vector2(48.0, 108.0), Vector2(76.0, 118.0), Vector2(100.0, 135.0), Vector2(110.0, 160.0), Vector2(104.0, 185.0), Vector2(88.0, 205.0), Vector2(72.0, 215.0)]
## Tread grade limit (route module rejects beyond 14 degrees after its own smoothing).
const ROUTE_GRADE := 0.194
const SOIL_BUCKET := 8.0
const APPROACH_Z_FROM := 25.5
const DAY_SUN := Color("ffc07e")
const NIGHT_SUN := Color("a9a6ee")

var canopy_count: int = 0
var rock_count: int = 0
var carpet_count: int = 0
var terrain_triangles: int = 0
var carpet_triangles: int = 0
var grounded_stems: int = 0
var frozen: bool = false
var baked_extent: Rect2 = Rect2(-25.0, -24.0, 50.0, 53.0)
var winding_checks: Dictionary = {}
var hero: Dictionary = {}
var _time: float = 0.0
var _reduced_motion: bool = false
var _overview: bool = false
var _debug_colors: bool = false
var _art: Array[ShaderMaterial] = []
var _mask: StandardMaterial3D
var _nodes: Array[MultiMeshInstance3D] = []
var _static: Array[GeometryInstance3D] = []
var _terrain_material: ShaderMaterial
var _lake_material: ShaderMaterial
var _moss_mean := Color(0.30, 0.36, 0.18)
var tree_count: int = 0
var tree_instances: int = 0
var tree_report: Dictionary = {}
var carpet_chunks: int = 0
var diagnostic_skips: PackedStringArray = PackedStringArray()
var _world: Node3D
var _ridge_noise: FastNoiseLite
var _hill_noise: FastNoiseLite
var _terrace_noise: FastNoiseLite
var route: Node3D
var route_report: Dictionary = {}
var seam_height: float = NAN
var _approach := Rect2()
var _soil_tris: PackedVector3Array = PackedVector3Array()
var _soil_boxes: Array[Rect2] = []
var _soil_buckets: Dictionary = {}
var _edge_heights: PackedFloat32Array = PackedFloat32Array()
var _edge_inner: PackedFloat32Array = PackedFloat32Array()
var _edge_step: float = 2.0
var _route_points: PackedVector3Array = PackedVector3Array()
var _route_box := Rect2()
var _shaping_route: bool = false

static func is_enabled() -> bool:
	if "prototype_off" in OS.get_environment("MUSH_SCENERY_DIAG").split(",", false): return false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--prototype-scenery=off": return false
		if argument == "--prototype-scenery=on": return true
	return bool(ProjectSettings.get_setting("mush/prototype/scenery", false))

# --- Terrain: one height source for the mesh, stems, pillars, carpet and cameras ---

func _box_distance(x: float, z: float) -> float:
	var e: Rect2 = baked_extent
	var dx: float = maxf(maxf(e.position.x - x, x - e.end.x), 0.0)
	var dz: float = maxf(maxf(e.position.y - z, z - e.end.y), 0.0)
	return Vector2(dx, dz).length()

func _terrace(value: float, step: float, width: float) -> float:
	var scaled: float = value / step
	return step * floorf(scaled) + step * smoothstep(1.0 - width, 1.0, scaled - floorf(scaled))

## Final terrain: landforms plus the graded trail bed along the walkable route.
func terrain_height(x: float, z: float) -> float:
	var raw: float = _raw_height(x, z)
	if _route_points.is_empty() or _shaping_route or not _route_box.has_point(Vector2(x, z)) or _box_distance(x, z) <= 0.0:
		return raw
	var best: float = INF
	var tread: float = raw
	for i: int in _route_points.size() - 1:
		var a := Vector2(_route_points[i].x, _route_points[i].z)
		var ab := Vector2(_route_points[i + 1].x, _route_points[i + 1].z) - a
		var t: float = clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var dist: float = Vector2(x, z).distance_to(a + ab * t)
		if dist < best:
			best = dist
			tread = lerpf(_route_points[i].y, _route_points[i + 1].y, t)
	return lerpf(tread - 0.12, raw, smoothstep(4.0, 11.0, best))

## Baked-ground continuity: outside the baked extent, the measured height of the baked
## soil at the nearest perimeter point; inside it, just below that soil (hidden).
func _edge_base(x: float, z: float) -> float:
	if _edge_heights.is_empty(): return -0.3
	var e: Rect2 = baked_extent
	var px: float = clampf(x, e.position.x, e.end.x)
	var pz: float = clampf(z, e.position.y, e.end.y)
	var inside: bool = px == x and pz == z
	if inside:
		var to_edge: float = minf(minf(x - e.position.x, e.end.x - x), minf(z - e.position.y, e.end.y - z))
		if to_edge > 8.0: return -1.5
		var gaps := [x - e.position.x, e.end.x - x, z - e.position.y, e.end.y - z]
		var side: int = gaps.find(to_edge)
		if side == 0: px = e.position.x
		elif side == 1: px = e.end.x
		elif side == 2: pz = e.position.y
		else: pz = e.end.y
	var u: float = _perimeter_u(px, pz) / _edge_step
	var i0: int = int(floorf(u)) % _edge_heights.size()
	var i1: int = (i0 + 1) % _edge_heights.size()
	var f: float = u - floorf(u)
	var edge: float = lerpf(_edge_heights[i0], _edge_heights[i1], f)
	if inside:
		return minf(edge, lerpf(_edge_inner[i0], _edge_inner[i1], f)) - 0.3
	return edge

func _perimeter_u(px: float, pz: float) -> float:
	var e: Rect2 = baked_extent
	if absf(pz - e.position.y) < 0.001: return px - e.position.x
	if absf(px - e.end.x) < 0.001: return e.size.x + (pz - e.position.y)
	if absf(pz - e.end.y) < 0.001: return e.size.x + e.size.y + (e.end.x - px)
	return 2.0 * e.size.x + e.size.y + (e.end.y - pz)

func _raw_height(x: float, z: float) -> float:
	var d: float = _box_distance(x, z)
	var r: float = Vector2(x, z).length()
	var dir: Vector2 = Vector2(x, z) / maxf(r, 0.001)
	var valley: float = smoothstep(0.15, 0.7, dir.dot(VALLEY_DIR))
	var apron: float = smoothstep(12.0, 57.0, d)
	# Valley sector: the clearing's rim drops about 70 m in terraces to a valley floor.
	var drop: float = -70.0 * apron * valley
	var terraced: float = _terrace(drop, 20.0, 0.3)
	var terrace_mask: float = smoothstep(0.1, 0.5, _terrace_noise.get_noise_2d(x, z) * 0.5 + 0.5)
	var height: float = _edge_base(x, z) + lerpf(drop, terraced, terrace_mask)
	height += _hill_noise.get_noise_2d(x, z) * 8.0 * apron * valley
	# Lake basin sits low in the valley.
	var to_lake: float = Vector2(x, z).distance_to(LAKE_CENTER)
	height -= exp(-(to_lake * to_lake) / (2.0 * 120.0 * 120.0)) * 25.0
	# Far terraced mesas in the valley half.
	var mesa_mask: float = smoothstep(550.0, 900.0, r) * smoothstep(0.0, 0.6, dir.dot(VALLEY_DIR))
	var mesa: float = smoothstep(0.25, 0.4, _ridge_noise.get_noise_2d(x, z)) * 220.0
	# Domain-warped terraces: ledge heights wander, so mesas do not read as stacked boxes.
	var warped: float = mesa + _terrace_noise.get_noise_2d(x * 1.7, z * 1.7) * 26.0 * smoothstep(0.0, 40.0, mesa)
	height += _terrace(warped, 55.0, 0.3) * mesa_mask
	# The hero giant stands on its own grassy rise above the valley floor, not in water.
	height += 30.0 * smoothstep(190.0, 0.0, Vector2(x, z).distance_to(HERO))
	# South and west keep clearing height, then rise into forested hills behind the home.
	var enclosed: float = (1.0 - valley) * smoothstep(40.0, 420.0, d)
	height += enclosed * 55.0 + _hill_noise.get_noise_2d(x + 900.0, z) * 12.0 * smoothstep(80.0, 400.0, d) * (1.0 - valley * 0.7)
	# Southern overlook knoll; zero within 10 m of the baked ground so it never rises over it.
	# Broad knoll the grade-limited route can climb without a deep cut. (A concave summit
	# was tried and rejected: the tread lagged it by 4.3 m and the bank crowded the camera.)
	height += 16.0 * smoothstep(300.0, 0.0, Vector2(x, z).distance_to(KNOLL)) * smoothstep(10.0, 160.0, d)
	# Rim hills close the horizon.
	height += maxf(0.0, r - 1000.0) * 0.1
	return height

func terrain_slope(x: float, z: float) -> float:
	var e: float = 6.0
	var dx: float = terrain_height(x + e, z) - terrain_height(x - e, z)
	var dz: float = terrain_height(x, z + e) - terrain_height(x, z - e)
	return Vector2(dx, dz).length() / (2.0 * e)

func _compute_baked_extent() -> Rect2:
	var rect := Rect2()
	var first := true
	var roots: Array[Node] = []
	var ground: Node = _world.get_node_or_null("GroundAndPaths")
	if ground != null: roots.append(ground)
	var backdrop: Variant = _world.get("forest_backdrop")
	if backdrop != null and backdrop.get("root") is Node: roots.append(backdrop.get("root"))
	for root: Node in roots:
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			var flat := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
			rect = flat if first else rect.merge(flat)
			first = false
	return rect if not first else baked_extent

# --- Setup ---

func configure(world: Node3D) -> void:
	_world = world
	name = "PrototypeScenery"
	baked_extent = _compute_baked_extent()
	_ridge_noise = FastNoiseLite.new()
	_ridge_noise.seed = 4242
	_ridge_noise.frequency = 0.0016
	_ridge_noise.fractal_octaves = 3
	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = 77
	_hill_noise.frequency = 0.0035
	_terrace_noise = FastNoiseLite.new()
	_terrace_noise.seed = 91
	_terrace_noise.frequency = 0.003
	_mask = StandardMaterial3D.new()
	_mask.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mask.albedo_color = Color(1, 0, 1)
	_mask.disable_fog = true
	var swatch: Image = MOSS_TEXTURE.get_image()
	if swatch != null:
		swatch = swatch.duplicate()
		swatch.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		_moss_mean = swatch.get_pixel(0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	_collect_soil(baked_extent.grow(6.0))
	_sample_edges()
	_plan_route()
	# Diagnostic-only performance bisection (empty by default; never set by the game).
	var skip: PackedStringArray = OS.get_environment("MUSH_SCENERY_DIAG").split(",", false)
	_add_terrain()
	if "plain_terrain" in skip: _terrain_material.shader = preload("res://assets/world/far_canopy.gdshader"); _terrain_material.set_shader_parameter("mode", 2)
	if "no_water" in skip: _static[_static.size() - 1].visible = false
	_add_route()
	_add_giants(rng)
	_add_pillars(rng)
	_add_boulders(rng)
	if not "no_trees" in skip: _add_trees(rng)
	if not "no_carpet" in skip: _add_carpet(rng)
	if "no_giants" in skip:
		for node: MultiMeshInstance3D in _nodes: node.visible = false
	diagnostic_skips = skip
	var player: Node = _world.get_parent().get("player")
	if player != null and is_instance_valid(player.get("_camera")):
		player._camera.far = FAR_PLANE

func _add_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int = TERRAIN_CELLS + 1
	for row: int in columns:
		for column: int in columns:
			var sx: float = lerpf(-1.0, 1.0, float(column) / TERRAIN_CELLS)
			var sz: float = lerpf(-1.0, 1.0, float(row) / TERRAIN_CELLS)
			# Graded grid: dense near the clearing, coarse toward the horizon.
			var x: float = TERRAIN_HALF * signf(sx) * pow(absf(sx), 1.7)
			var z: float = TERRAIN_HALF * signf(sz) * pow(absf(sz), 1.7)
			st.set_color(Color(0, 0, 0))
			st.set_uv(Vector2(float(column) / TERRAIN_CELLS, float(row) / TERRAIN_CELLS))
			st.add_vertex(Vector3(x, terrain_height(x, z), z))
	for row: int in TERRAIN_CELLS:
		for column: int in TERRAIN_CELLS:
			var i0: int = row * columns + column
			var i1: int = i0 + 1
			var i2: int = i0 + columns
			var i3: int = i2 + 1
			# Clockwise as seen from above (Godot front face), verified in get_report().
			st.add_index(i0); st.add_index(i1); st.add_index(i2)
			st.add_index(i1); st.add_index(i3); st.add_index(i2)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	terrain_triangles = TERRAIN_CELLS * TERRAIN_CELLS * 2
	var centre: int = (TERRAIN_CELLS / 2) * columns + TERRAIN_CELLS / 2
	winding_checks["terrain_centre_normal_y"] = (mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array)[centre].y
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	_terrain_material.set_shader_parameter("moss_tex", MOSS_TEXTURE)
	_terrain_material.set_shader_parameter("rock_tex", ROCK_TEXTURE)
	_terrain_material.set_shader_parameter("moss_mean", _moss_mean)
	var terrain := MeshInstance3D.new()
	terrain.name = "WorldTerrain"
	terrain.mesh = mesh
	terrain.material_override = _terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	_static.append(terrain)
	var disc := CylinderMesh.new()
	disc.top_radius = 300.0
	disc.bottom_radius = 300.0
	disc.height = 0.2
	disc.radial_segments = 64
	disc.rings = 1
	_lake_material = ShaderMaterial.new()
	_lake_material.shader = WATER_SHADER
	var lake := MeshInstance3D.new()
	lake.name = "WorldLake"
	lake.mesh = disc
	lake.material_override = _lake_material
	lake.position = Vector3(LAKE_CENTER.x, LAKE_Y, LAKE_CENTER.y)
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lake)
	_static.append(lake)

func _giant_specs() -> Array:
	# x, z, cap radius, underside height above local ground. The hero stands about
	# 20 degrees from the sun direction as seen from the clearing, so it is backlit.
	return [
		[378.0, -648.0, 220.0, 264.0],
		[-280.0, -760.0, 110.0, 140.0],
		[700.0, -420.0, 90.0, 120.0],
		[480.0, -900.0, 36.0, 55.0],
		[-60.0, -850.0, 30.0, 48.0],
		[820.0, -760.0, 40.0, 60.0],
		[250.0, -1000.0, 34.0, 50.0],
	]

func _add_giants(rng: RandomNumberGenerator) -> void:
	var hero_cap: ArrayMesh = _cap_mesh(PackedFloat32Array([0.4, 2.1, 4.0, 1.3, 5.2, 0.7]))
	var cap: ArrayMesh = _cap_mesh(PackedFloat32Array([3.1, 0.6, 1.8, 4.4, 2.5, 3.6]))
	var stem: ArrayMesh = _stem_mesh()
	var hero_caps: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	var tints: Array[Color] = []
	var stem_tints: Array[Color] = []
	for row: Array in _giant_specs():
		var x: float = row[0]; var z: float = row[1]; var r: float = row[2]; var h: float = row[3]
		var yaw: float = rng.randf_range(0.0, TAU)
		var ground: float = terrain_height(x, z)
		var underside: float = ground + h
		var thickness: float = r * 0.5
		var stem_r: float = r * 0.15
		# The stem leans gently; its bent top carries the cap.
		var lean: Vector3 = Basis(Vector3.UP, yaw) * Vector3(STEM_BEND * stem_r, 0.0, 0.0)
		var tilt := Basis(Vector3(1, 0, 0), rng.randf_range(-0.05, 0.05)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.05, 0.05))
		var cap_pose := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * tilt * Basis.from_scale(Vector3(r, thickness, r)), Vector3(x + lean.x, underside, z + lean.z))
		if hero.is_empty(): hero_caps.append(cap_pose)
		else: caps.append(cap_pose)
		# One continuous stem from below local ground into the cap underside.
		# Deep enough that the integrated buttresses' outer edges end under the terrain.
		var base: float = ground - maxf(12.0, stem_r * 0.9)
		var length: float = underside + thickness * 0.22 - base
		stems.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(stem_r, length, stem_r)), Vector3(x, base, z)))
		if base < ground and base + length > underside: grounded_stems += 1
		if not hero.is_empty(): tints.append(Color(rng.randf(), 0, 0))
		stem_tints.append(Color(rng.randf(), 1, 1))
		if hero.is_empty():
			# Camera framing anchor stays where the previous checkpoint framed it, so the
			# rim composition (and the framing trees placed from it) is unchanged.
			var anchor: Vector3 = Basis(Vector3.UP, yaw) * Vector3(STEM_BEND * r * 0.2, 0.0, 0.0)
			hero = {"position": Vector3(x + lean.x, underside, z + lean.z), "view_focus": Vector3(x + anchor.x, underside, z + anchor.z), "base": Vector3(x, ground, z), "radius": r, "ground": ground}
	canopy_count = hero_caps.size() + caps.size()
	var hero_tint: Array[Color] = [Color(0.5, 0, 0)]
	_add(hero_cap, hero_caps, hero_tint, 0, "HeroCanopy")
	_add(cap, caps, tints, 0, "LuminousCanopies")
	_add(stem, stems, stem_tints, 1, "CanopyStems")

func _add_pillars(rng: RandomNumberGenerator) -> void:
	var pillar: ArrayMesh = _pillar_mesh()
	var xs: Array[Transform3D] = []
	var tints: Array[Color] = []
	for spot: Vector3 in [Vector3(540.0, 190.0, -980.0), Vector3(120.0, 160.0, -930.0), Vector3(-520.0, 140.0, -520.0)]:
		var ground: float = terrain_height(spot.x, spot.z)
		var width: float = spot.y * rng.randf_range(0.38, 0.5)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis.from_scale(Vector3(width, spot.y, width)), Vector3(spot.x, ground - 15.0, spot.z)))
		tints.append(Color(rng.randf(), 0, 0))
	rock_count += xs.size()
	_add(pillar, xs, tints, 2, "RockPillars")

func _add_boulders(rng: RandomNumberGenerator) -> void:
	# Squat boulders along the clearing rim in the valley direction, framing the overlook.
	var boulder: ArrayMesh = _boulder_mesh()
	var xs: Array[Transform3D] = []
	var tints: Array[Color] = []
	var edge: Vector2 = _rim_point(6.0)
	var side := Vector2(-VALLEY_DIR.y, VALLEY_DIR.x)
	for offset: Vector2 in [Vector2(-1.0, -9.0), Vector2(-4.0, 10.0), Vector2(3.0, 13.0), Vector2(1.0, -14.0), Vector2(-6.0, -12.0)]:
		var p: Vector2 = edge + VALLEY_DIR * offset.x + side * offset.y
		var size: float = rng.randf_range(1.2, 2.6)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis.from_scale(Vector3(size * 1.3, size, size * 1.1)), Vector3(p.x, terrain_height(p.x, p.y) - 0.3, p.y)))
		tints.append(Color(rng.randf(), 0, 0))
	rock_count += xs.size()
	_add(boulder, xs, tints, 2, "RimBoulders")

## Whole trees copied from the existing forest ring (scripts/forest_enclosure.gd): the
## same trunk and layered-crown meshes and materials, re-posed. Roots are recreated from
## that script's seeded generator; only tall-cohort trees are used as templates.
func _forest_templates() -> Array:
	var layer: Node = _world.get_node_or_null("ForestMiddleLayer")
	if layer == null: return []
	var random := RandomNumberGenerator.new()
	random.seed = 530052
	var roots: Array[Vector3] = []
	for index: int in range(22):
		var angle: float = lerpf(-1.48, 1.48, float(index) / 21.0)
		var radius: float = random.randf_range(24.0, 28.0)
		roots.append(Vector3(sin(angle) * radius, -0.35, -cos(angle) * radius + 2.0))
	for side: int in [-1, 1]:
		for index: int in range(4):
			roots.append(Vector3(float(side) * random.randf_range(23.0, 25.0), -0.35, float(index) * 5.0))
	for i: int in roots.size():
		if roots[i].x > 7.3 and roots[i].x < 10.7: roots[i].x = 11.4
	var picks: Array[int] = [2, 4, 9, 11, 16, 18]
	var parts: Dictionary = {}
	for node: Node in layer.get_children():
		if not node is MultiMeshInstance3D: continue
		var label: String = String(node.name)
		if not (label.begins_with("BentTrunks") or label.begins_with("LayeredCanopies")): continue
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		for i: int in multi.instance_count:
			var pose: Transform3D = (node as MultiMeshInstance3D).global_transform * multi.get_instance_transform(i)
			var nearest: int = -1
			var best: float = INF
			for r: int in roots.size():
				var gap: float = Vector2(pose.origin.x - roots[r].x, pose.origin.z - roots[r].z).length()
				if gap < best:
					best = gap
					nearest = r
			if not nearest in picks or best > 9.0: continue
			if not parts.has(nearest): parts[nearest] = []
			parts[nearest].append({"mesh": multi.mesh, "material": (node as MultiMeshInstance3D).material_override, "kind": label.get_slice("_", 0), "local": Transform3D(Basis(), -roots[nearest]) * pose})
	var templates: Array = []
	for key: int in parts: templates.append(parts[key])
	return templates

func _add_trees(rng: RandomNumberGenerator) -> void:
	var templates: Array = _forest_templates()
	tree_report = {"templates": templates.size()}
	if templates.is_empty():
		tree_report["error"] = "ForestMiddleLayer templates not found"
		return
	var spots: Array[Vector2] = []
	# 1. Framing trees beside the rim overlook, kept out of the central view.
	var pose: Dictionary = overlook_pose()
	var eye: Vector3 = pose.position
	var forward := Vector2(pose.target.x - eye.x, pose.target.z - eye.z).normalized()
	var right := Vector2(-forward.y, forward.x)
	for frame: Vector2 in [Vector2(10.0, -9.5), Vector2(14.0, 10.5), Vector2(22.0, -15.5), Vector2(27.0, 17.0), Vector2(7.0, 14.0)]:
		spots.append(Vector2(eye.x, eye.z) + forward * frame.x + right * frame.y)
	var framing: int = spots.size()
	# 2. Terrace shelves, 3. lake-shore groves, 4. route flanks.
	var tries: int = 0
	var shelf: int = 0
	var shore: int = 0
	var flank: int = 0
	while tries < 6000 and (shelf < 14 or shore < 12 or flank < 14):
		tries += 1
		var spot: Vector2
		var group: int = 0
		if shelf < 14:
			spot = _rim_point(rng.randf_range(10.0, 110.0)).rotated(rng.randf_range(-0.6, 0.6))
			group = 2
		elif shore < 12:
			spot = LAKE_CENTER + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(150.0, 330.0)
			group = 3
		else:
			var anchor: Vector3 = route._p[rng.randi_range(0, route._p.size() - 1)] if is_instance_valid(route) and route.valid else Vector3(KNOLL.x, 0, KNOLL.y)
			spot = Vector2(anchor.x, anchor.z) + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(12.0, 40.0)
			group = 4
		var ground: float = terrain_height(spot.x, spot.y)
		if _box_distance(spot.x, spot.y) < 8.0 or terrain_slope(spot.x, spot.y) > 0.45: continue
		if ground < LAKE_Y + 2.5: continue
		if is_instance_valid(route) and route.valid and route.is_in_corridor(Vector3(spot.x, ground, spot.y), 6.0): continue
		var rel: Vector2 = spot - Vector2(eye.x, eye.z)
		var along: float = rel.dot(forward)
		if along > 0.0 and along < 220.0 and absf(rel.dot(right)) < along * 0.32 + 6.0: continue
		if group == 3 and absf(ground - LAKE_Y) > 30.0: continue
		# Keep the walkable knoll overlook's view of the hero open as well.
		if group == 4:
			var summit: Vector3 = route.get_end_point() if is_instance_valid(route) and route.valid else Vector3(KNOLL.x, 0, KNOLL.y)
			var gaze := Vector2(110.0 - summit.x, -500.0 - summit.z).normalized()
			var off: Vector2 = spot - Vector2(summit.x, summit.z)
			var ahead: float = off.dot(gaze)
			if ahead > 0.0 and ahead < 260.0 and absf(off.dot(Vector2(-gaze.y, gaze.x))) < ahead * 0.45 + 8.0: continue
		spots.append(spot)
		if group == 2: shelf += 1
		elif group == 3: shore += 1
		else: flank += 1
	var batches: Dictionary = {}
	for index: int in spots.size():
		var spot: Vector2 = spots[index]
		var template: Array = templates[rng.randi_range(0, templates.size() - 1)]
		var size: float = rng.randf_range(0.9, 1.3) if index >= framing else rng.randf_range(1.05, 1.3)
		var root := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * size), Vector3(spot.x, terrain_height(spot.x, spot.y) - 0.35, spot.y))
		var cell := Vector2i(floori(spot.x / 160.0), floori(spot.y / 160.0))
		for part: Dictionary in template:
			var key: String = "%s|%d|%d|%d" % [part.kind, part.mesh.get_instance_id(), cell.x, cell.y]
			if not batches.has(key): batches[key] = {"mesh": part.mesh, "material": part.material, "kind": part.kind, "poses": []}
			batches[key].poses.append(root * part.local)
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch.mesh
		multi.instance_count = batch.poses.size()
		for i: int in batch.poses.size(): multi.set_instance_transform(i, batch.poses[i])
		var node := MultiMeshInstance3D.new()
		node.name = "CopiedTrees_" + str(batch.kind)
		node.multimesh = multi
		node.material_override = batch.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 2.0
		node.visibility_range_end = 700.0
		add_child(node)
		_static.append(node)
		tree_instances += multi.instance_count
	tree_count = spots.size()
	tree_report.merge({"trees": tree_count, "framing": framing, "shelf": shelf, "shore": shore, "flank": flank, "instances": tree_instances, "batches": batches.size()})

func _add_carpet(rng: RandomNumberGenerator) -> void:
	var base_color := Color("48752e")
	var accent_color := Color("a3ac49")
	var materials: Variant = _world.get("_materials")
	var leaf: Variant = materials.get("leaf") if materials is Dictionary else null
	if leaf is ShaderMaterial:
		var a: Variant = leaf.get_shader_parameter("base_color")
		var b: Variant = leaf.get_shader_parameter("accent_color")
		if a is Color: base_color = a
		if b is Color: accent_color = b
	var clump: ArrayMesh = _clump_mesh()
	var xs: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries: int = 0
	while xs.size() < 3000 and tries < 60000:
		tries += 1
		# Denser near the clearing: squared radius sampling, then far scatter.
		var reach: float = 1300.0 * pow(rng.randf(), 1.6)
		var bearing: float = rng.randf_range(0.0, TAU)
		var x: float = cos(bearing) * reach
		var z: float = sin(bearing) * reach
		if _box_distance(x, z) < 22.0 or Vector2(x, z).length() < 230.0: continue
		var ground: float = terrain_height(x, z)
		if ground < LAKE_Y + 4.0 and Vector2(x, z).distance_to(LAKE_CENTER) < 320.0: continue
		if terrain_slope(x, z) > 0.5: continue
		if is_instance_valid(route) and route.valid and route.is_in_corridor(Vector3(x, ground, z), 2.0): continue
		if Vector2(x, z).distance_to(KNOLL) < 140.0: continue
		var width: float = rng.randf_range(12.0, 22.0)
		var height: float = rng.randf_range(11.0, 19.0)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis.from_scale(Vector3(width, height, width)), Vector3(x, ground - 1.0, z)))
		var shade: float = rng.randf_range(0.92, 1.08)
		var tone: Color = base_color.lerp(accent_color, rng.randf_range(0.0, 0.55)) * shade
		# Leave the hero's rooted base open; filtered after every draw, so the random
		# stream (and every other clump) is unchanged.
		if not hero.is_empty() and Vector2(x, z).distance_to(Vector2(hero.base.x, hero.base.z)) < float(hero.radius) * 0.75:
			xs.pop_back()
			continue
		colors.append(tone)
	carpet_count = xs.size()
	carpet_triangles = (clump.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3) * carpet_count
	# One shared material; 400 m spatial chunks so off-screen forest is frustum-culled
	# (a single map-wide MultiMesh was always drawn, even from inside the clearing).
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", 5)
	_art.append(material)
	var chunks: Dictionary = {}
	for index: int in xs.size():
		var cell := Vector2i(floori(xs[index].origin.x / 400.0), floori(xs[index].origin.z / 400.0))
		if not chunks.has(cell): chunks[cell] = []
		chunks[cell].append(index)
	for cell: Vector2i in chunks:
		var members: Array = chunks[cell]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = clump
		multi.instance_count = members.size()
		for k: int in members.size():
			multi.set_instance_transform(k, xs[members[k]])
			multi.set_instance_color(k, colors[members[k]])
		var node := MultiMeshInstance3D.new()
		node.name = "ForestCarpet_%d_%d" % [cell.x, cell.y]
		node.multimesh = multi
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		node.visibility_range_end = 1700.0
		add_child(node)
		_static.append(node)
	carpet_chunks = chunks.size()

func _add(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], mode: int, label: String) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", mode)
	material.set_shader_parameter("rock_tex", ROCK_TEXTURE)
	material.set_shader_parameter("moss_mean", _moss_mean)
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
	node.name = label
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	_nodes.append(node)

# --- Meshes (profile x = radius, y = height, z = v parameter) ---

# Parasol cap: radius 1, drooping fleshy rim (a rounded bulb, not a knife edge) and a
# gill underside. `phases` drive mixed integer-frequency rim variation with random
# phase, so no two caps share a mechanical 360-degree symmetry. The profile runs from the
# top centre outward then back under, so the front face needs the flipped index order.
func _cap_mesh(phases: PackedFloat32Array) -> ArrayMesh:
	var profile: Array[Vector3] = []
	var top_rows := 24
	for i: int in top_rows + 1:
		var s: float = float(i) / top_rows
		var droop: float = 0.12 * pow(smoothstep(0.7, 1.0, s), 1.5)
		profile.append(Vector3(s * 0.97, 0.08 + 0.38 * (1.0 - pow(s, 2.1)) - droop, 0.5 * s * 0.97))
	for degrees: float in [60.0, 20.0, -20.0, -60.0, -100.0]:
		var angle: float = deg_to_rad(degrees)
		profile.append(Vector3(0.97 + 0.045 * cos(angle), -0.075 + 0.045 * sin(angle), 0.5))
	var under_rows := 18
	for i: int in under_rows + 1:
		var u: float = float(i) / under_rows
		profile.append(Vector3(lerpf(0.94, 0.08, u), -0.10 + 0.27 * pow(u, 1.4), 0.5 + 0.5 * u))
	var mesh: ArrayMesh = _lathe(profile, 72, "cap", true, phases)
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	winding_checks["cap_top_normal_y"] = normals[3 * 73].y
	return mesh

func _stem_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = []
	# Gentle base swell, slight taper, and a collar that opens into the cap underside.
	# Rows are denser near the base, where the integrated buttresses curve.
	var rows := 34
	for i: int in rows + 1:
		var t: float = pow(float(i) / rows, 1.5)
		profile.append(Vector3((1.0 + 0.35 * pow(1.0 - t, 3.0)) * (1.0 - 0.18 * t) + 0.5 * pow(smoothstep(0.86, 1.0, t), 2.0), t, t))
	# Closed top: the stem end is buried in the cap, never seen as an open tube.
	profile.append(Vector3(0.0, 1.0, 1.0))
	var mesh: ArrayMesh = _lathe(profile, 72, "stem", false)
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	winding_checks["stem_side_normal_outward"] = normals[20 * 73].x > 0.0
	return mesh

# Rock pillar: smooth angular fluting plus horizontal ledges, closed at the top.
func _pillar_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = []
	var rows := 28
	for i: int in rows + 1:
		var t: float = float(i) / rows
		var ledge: float = 1.0 - 0.09 * fposmod(t * 5.0, 1.0)
		profile.append(Vector3(lerpf(1.0, 0.62, t) * ledge, t, t))
	profile.append(Vector3(0.0, 1.0, 1.0))
	return _lathe(profile, 24, "pillar", false)

func _boulder_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = [Vector3(0.0, -0.1, 0.0), Vector3(0.9, 0.0, 0.1), Vector3(1.0, 0.3, 0.3), Vector3(0.78, 0.7, 0.6), Vector3(0.4, 0.95, 0.85), Vector3(0.0, 1.0, 1.0)]
	return _lathe(profile, 14, "boulder", false)

# Distant forest clump: three rounded lobes; only placed far from every camera.
func _clump_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.45, 0.4), Vector3(0.75, 0.92, 0.8), Vector3(0.3, 1.08, 0.95), Vector3(0.0, 1.12, 1.0)]
	var lobe: ArrayMesh = _lathe(profile, 7, "blob", false)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for placement: Array in [[Vector3(-0.35, 0.0, 0.0), 0.62, 0.9], [Vector3(0.3, 0.0, 0.2), 0.55, 0.8], [Vector3(0.0, 0.0, -0.32), 0.5, 1.0]]:
		st.append_from(lobe, 0, Transform3D(Basis.from_scale(Vector3(placement[1], placement[2], placement[1])), placement[0]))
	return st.commit()

func _lathe(profile: Array[Vector3], segments: int, style: String, flip: bool, phases: PackedFloat32Array = PackedFloat32Array()) -> ArrayMesh:
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
			var cavity: float = 1.0
			match style:
				"cap":
					var edge: float = pow(smoothstep(0.3, 1.0, p.x), 1.5)
					var f: PackedFloat32Array = phases if phases.size() >= 6 else PackedFloat32Array([0, 0, 0, 0, 0, 0])
					radius *= 1.0 + edge * (0.055 * sin(2.0 * a + f[0]) + 0.035 * sin(3.0 * a + f[1]) + 0.02 * sin(5.0 * a + f[2]) + 0.01 * sin(11.0 * a + f[3]))
					height += edge * (0.07 * sin(a + f[4]) + 0.025 * sin(4.0 * a + f[5]))
				"stem":
					# A few fused strands twisting up the stem (macro grooves, not fine flutes).
					var twist: float = p.z * 1.4
					var lobes: float = 0.13 * cos(4.0 * a + twist + 0.6) + 0.07 * cos(7.0 * a - twist * 0.6 + 2.1) + 0.04 * cos(11.0 * a + 1.0)
					radius *= 1.0 + lobes * (0.6 + 0.4 * p.z)
					# Low rounded buttresses grown from the same surface: five asymmetric
					# angular lobes, strongest at the base and gone by a fifth of the height.
					var reach: float = pow(1.0 - smoothstep(0.0, 0.2, p.z), 2.0)
					var flare: float = 0.0
					for lobe: Vector2 in STEM_BUTTRESSES:
						var gap: float = fposmod(a - lobe.x + PI, TAU) - PI
						flare += lobe.y * exp(-gap * gap / (2.0 * 0.26 * 0.26))
					radius *= 1.0 + reach * flare
					cavity = clampf(0.5 + lobes * 3.0 + reach * (minf(flare, 1.0) - 0.45) * 0.9, 0.0, 1.0)
				"pillar":
					radius *= 1.0 + 0.10 * sin(5.0 * a + 1.1) + 0.05 * sin(11.0 * a)
				"boulder":
					radius *= 1.0 + 0.14 * sin(3.0 * a + 0.4) + 0.07 * sin(7.0 * a + 1.9)
				"blob":
					radius *= 1.0 + 0.16 * sin(3.0 * a + 0.8)
			st.set_uv(Vector2(u, p.z))
			# Godot multiplies vertex colour into the MultiMesh instance colour: keep it white,
			# except the stem's green channel, which carries groove depth for shading.
			st.set_color(Color(1, cavity, 1))
			var bend: float = STEM_BEND * p.z * p.z if style == "stem" else 0.0
			st.add_vertex(Vector3(cos(a) * radius + bend, height, sin(a) * radius))
	for row: int in profile.size() - 1:
		for column: int in segments:
			var i0: int = row * columns + column
			var i1: int = i0 + 1
			var i2: int = i0 + columns
			var i3: int = i2 + 1
			if flip:
				st.add_index(i0); st.add_index(i2); st.add_index(i1)
				st.add_index(i1); st.add_index(i2); st.add_index(i3)
			else:
				st.add_index(i0); st.add_index(i1); st.add_index(i2)
				st.add_index(i1); st.add_index(i3); st.add_index(i2)
	st.generate_normals()
	return st.commit()

# --- Walkable route (the only collider this layer owns) ---

func _collect_soil(region: Rect2) -> void:
	var roots: Array[Node] = []
	var ground: Node = _world.get_node_or_null("GroundAndPaths")
	if ground != null: roots.append(ground)
	var backdrop: Variant = _world.get("forest_backdrop")
	if backdrop != null and backdrop.get("root") is Node: roots.append(backdrop.get("root"))
	for root: Node in roots:
		for mesh_node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if mesh_node.mesh == null: continue
			var box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
			if not Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)).intersects(region): continue
			var faces: PackedVector3Array = mesh_node.mesh.get_faces()
			for i: int in range(0, faces.size(), 3):
				var a: Vector3 = mesh_node.global_transform * faces[i]
				var b: Vector3 = mesh_node.global_transform * faces[i + 1]
				var c: Vector3 = mesh_node.global_transform * faces[i + 2]
				var tri := Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z)).expand(Vector2(c.x, c.z))
				if not tri.intersects(region): continue
				var index: int = _soil_boxes.size()
				_soil_tris.append(a); _soil_tris.append(b); _soil_tris.append(c)
				_soil_boxes.append(tri)
				for bx: int in range(floori(tri.position.x / SOIL_BUCKET), floori(tri.end.x / SOIL_BUCKET) + 1):
					for bz: int in range(floori(tri.position.y / SOIL_BUCKET), floori(tri.end.y / SOIL_BUCKET) + 1):
						var key := Vector2i(bx, bz)
						if not _soil_buckets.has(key): _soil_buckets[key] = PackedInt32Array()
						var list: PackedInt32Array = _soil_buckets[key]
						list.append(index)
						_soil_buckets[key] = list

## Highest baked visual surface (render mesh, not collision) at x,z below 20 m, or NAN.
## Startup only; bucketed so each query tests only nearby triangles.
func baked_visual_height(x: float, z: float) -> float:
	var best: float = NAN
	var here := Vector2(x, z)
	var key := Vector2i(floori(x / SOIL_BUCKET), floori(z / SOIL_BUCKET))
	if not _soil_buckets.has(key): return best
	for t: int in _soil_buckets[key]:
		if not _soil_boxes[t].grow(0.01).has_point(here): continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(x, 20.0, z), Vector3.DOWN, _soil_tris[t * 3], _soil_tris[t * 3 + 1], _soil_tris[t * 3 + 2])
		if hit is Vector3 and (is_nan(best) or (hit as Vector3).y > best): best = (hit as Vector3).y
	return best

## Baked soil height around the extent perimeter (0.5 m and 6 m inside), every 2 m.
func _sample_edges() -> void:
	var e: Rect2 = baked_extent
	var perimeter: float = 2.0 * (e.size.x + e.size.y)
	var count: int = int(ceil(perimeter / _edge_step))
	_edge_heights.resize(count)
	_edge_inner.resize(count)
	var centre: Vector2 = e.get_center()
	for i: int in count:
		var u: float = float(i) * _edge_step
		var p: Vector2
		if u < e.size.x: p = Vector2(e.position.x + u, e.position.y)
		elif u < e.size.x + e.size.y: p = Vector2(e.end.x, e.position.y + u - e.size.x)
		elif u < 2.0 * e.size.x + e.size.y: p = Vector2(e.end.x - (u - e.size.x - e.size.y), e.end.y)
		else: p = Vector2(e.position.x, e.end.y - (u - 2.0 * e.size.x - e.size.y))
		var inward: Vector2 = (centre - p).normalized()
		var edge: float = baked_visual_height(p.x + inward.x * 0.5, p.y + inward.y * 0.5)
		var inner: float = baked_visual_height(p.x + inward.x * 6.0, p.y + inward.y * 6.0)
		_edge_heights[i] = edge if not is_nan(edge) else -0.3
		_edge_inner[i] = inner if not is_nan(inner) else _edge_heights[i]

## Dense tread points: surface = max(baked soil, landform), then a forward grade limit
## from the pinned seam so the ribbon never exceeds ROUTE_GRADE. The terrain is later
## graded to this tread outside the baked extent (cut and fill), never inside it.
func _plan_route() -> void:
	seam_height = _measure_seam()
	_shaping_route = true
	var profile: Array = []
	# Catmull-Rom through the waypoints, sampled every 4 m: continuous curvature.
	var curve := Curve2D.new()
	var count: int = ROUTE_WAYPOINTS.size()
	for i: int in count:
		var before: Vector2 = ROUTE_WAYPOINTS[maxi(i - 1, 0)]
		var after: Vector2 = ROUTE_WAYPOINTS[mini(i + 1, count - 1)]
		var tangent: Vector2 = (after - before) * 0.5
		curve.add_point(ROUTE_WAYPOINTS[i], -tangent / 3.0, tangent / 3.0)
	curve.bake_interval = 0.5
	var raw := PackedVector3Array()
	var length: float = curve.get_baked_length()
	var steps: int = int(ceil(length / 4.0))
	for k: int in steps + 1:
		var q: Vector2 = curve.sample_baked(minf(length, float(k) * length / steps))
		raw.append(Vector3(q.x, 0.0, q.y))
	_route_points.resize(raw.size())
	for i: int in raw.size():
		var surface: float = _raw_height(raw[i].x, raw[i].z)
		var soil: float = baked_visual_height(raw[i].x, raw[i].z)
		var wanted: float = (maxf(surface, soil) if not is_nan(soil) else surface) + 0.06
		var y: float = wanted
		if i == 0:
			y = seam_height if not is_nan(seam_height) else 0.04
		else:
			var run: float = Vector2(raw[i].x - raw[i - 1].x, raw[i].z - raw[i - 1].z).length()
			var previous: float = _route_points[i - 1].y
			y = clampf(wanted, previous - ROUTE_GRADE * run, previous + ROUTE_GRADE * run)
			if not is_nan(soil): y = maxf(y, soil + 0.04)
		_route_points[i] = Vector3(raw[i].x, y, raw[i].z)
		profile.append([snappedf(raw[i].x, 0.1), snappedf(raw[i].z, 0.1), snappedf(surface, 0.01), snappedf(soil, 0.01) if not is_nan(soil) else null, snappedf(y, 0.01)])
	_route_box = Rect2(Vector2(_route_points[0].x, _route_points[0].z), Vector2.ZERO)
	for point: Vector3 in _route_points: _route_box = _route_box.expand(Vector2(point.x, point.z))
	_route_box = _route_box.grow(14.0)
	_shaping_route = false
	route_report["profile_x_z_raw_soil_tread"] = profile

func _measure_seam() -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null: return NAN
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ROUTE_SEAM.x, 5.0, ROUTE_SEAM.y - 0.05), Vector3(ROUTE_SEAM.x, -5.0, ROUTE_SEAM.y - 0.05), 1))
	return (hit.position as Vector3).y if not hit.is_empty() else NAN

func _add_route() -> void:
	route = Route.new()
	route.name = "NaturalRoute"
	add_child(route)
	var profile: Variant = route_report.get("profile_x_z_raw_soil_tread")
	# Trodden earth: the existing Rock01 texture, world-triplanar at real scale, warm tint.
	var earth := StandardMaterial3D.new()
	earth.albedo_texture = ROCK_TEXTURE
	earth.albedo_color = Color(0.86, 0.66, 0.48)
	earth.uv1_triplanar = true
	earth.uv1_world_triplanar = true
	earth.uv1_scale = Vector3.ONE * 0.22
	earth.roughness = 0.95
	earth.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var built: bool = route.configure({"centerline": _route_points, "tread_width": 3.6, "shoulder_width": 2.2, "max_grade_deg": 14.0,
		"exclusion_rects": [Rect2(-24.0, -24.0, 49.0, 53.0)], "ground_height": Callable(self, "terrain_height"), "material": earth})
	route_report = route.get_report()
	route_report["profile_x_z_raw_soil_tread"] = profile
	route_report["requested_points"] = _route_points.size()
	route_report["seam_height_measured"] = seam_height
	route_report["soil_triangles"] = _soil_boxes.size()
	route_report["edge_samples"] = _edge_heights.size()
	if built:
		var start: Vector3 = route.get_start_point()
		_approach = Rect2(start.x - 1.8, APPROACH_Z_FROM, 3.6, start.z - APPROACH_Z_FROM + 0.3)

## Movement-only extension used by the player: the exact route corridor, or the short
## approach strip over baked collider ground between the old movement box (z 26) and the
## seam (z 29). Saves and teleports do NOT use this; they keep the original box.
func allows_movement(point: Vector3) -> bool:
	if not is_instance_valid(route) or not route.valid or not point.is_finite(): return false
	if _approach.has_point(Vector2(point.x, point.z)) and point.y > -1.0 and point.y < 4.0: return true
	return route.is_in_corridor(point)

## Camera on the route's end at eye height, facing back over the clearing to the valley.
func route_overlook_pose() -> Dictionary:
	var end: Vector3 = route.get_end_point() if is_instance_valid(route) and route.valid else Vector3(KNOLL.x, terrain_height(KNOLL.x, KNOLL.y), KNOLL.y)
	return {"player": end + Vector3(0.0, 0.08, 0.0), "look_at": Vector3(150.0, 20.0, -500.0)}

# --- Camera poses ---

# Point on the valley-side edge of the baked ground, pushed `outset` metres outward.
func _rim_point(outset: float) -> Vector2:
	var e: Rect2 = baked_extent
	var t: float = INF
	if VALLEY_DIR.x > 0.0: t = minf(t, e.end.x / VALLEY_DIR.x)
	if VALLEY_DIR.y < 0.0: t = minf(t, e.position.y / VALLEY_DIR.y)
	return VALLEY_DIR * (t + outset)

## Rim overlook: eye height 2.4 m on the clearing's valley edge, 48 degree vertical FOV,
## aimed between the hero giant's stem and cap. This is a camera pose, not a walkable place.
func overlook_pose() -> Dictionary:
	var rim: Vector2 = _rim_point(5.0)
	var ground: float = terrain_height(rim.x, rim.y)
	var focus: Vector3 = hero.get("view_focus", hero.get("position", Vector3(378.0, 260.0, -648.0)))
	return {"position": Vector3(rim.x, ground + 2.4, rim.y), "target": Vector3(focus.x, focus.y * 0.55, focus.z), "fov": 48.0}

# --- Runtime state ---

func _process(delta: float) -> void:
	if frozen or _reduced_motion or (is_inside_tree() and get_tree().paused): return
	_time += delta
	for material: ShaderMaterial in _art + [_lake_material]:
		material.set_shader_parameter("shimmer_time", _time)

func set_frozen(value: bool) -> void:
	frozen = value

func set_overview(value: bool) -> void:
	_overview = value

## Capture-only: terrain/lake own colour with no lighting and no fog, to separate
## colour from lighting and haze when diagnosing the grade.
func set_debug_colors(enabled: bool) -> void:
	_debug_colors = enabled
	_terrain_material.set_shader_parameter("debug_unlit", enabled)
	_lake_material.set_shader_parameter("debug_unlit", enabled)

## Capture-only: paint just the giant caps and stems magenta for coverage metrics.
func set_debug_mask(enabled: bool) -> void:
	for node: MultiMeshInstance3D in _nodes:
		if not String(node.name) in ["HeroCanopy", "LuminousCanopies", "CanopyStems"]: continue
		node.material_override = _mask if enabled else _art[_nodes.find(node)]

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	for material: ShaderMaterial in _art:
		material.set_shader_parameter("shimmer_amount", 0.0 if value else 1.0)

## Amber/lavender grade, written after the shared lighting owner's endpoints.
func apply_look(environment: Environment, sun: DirectionalLight3D, night: float, rain: float, sunset: float) -> void:
	var toward_sun: Vector3 = sun.global_basis.z.normalized()
	_lake_material.set_shader_parameter("horizon", Color("f2b08e").lerp(Color("3a3466"), night))
	for material: ShaderMaterial in _art + [_terrain_material, _lake_material]:
		material.set_shader_parameter("night", night)
		material.set_shader_parameter("rain", rain)
		material.set_shader_parameter("sun_dir", toward_sun)
	sun.light_color = DAY_SUN.lerp(NIGHT_SUN, night).lerp(Color("ffa86a"), sunset * 0.5)
	sun.light_energy = lerpf(1.45, 0.60, night) * lerpf(1.0, 0.65, rain)
	sun.rotation_degrees.x = lerpf(-22.0, -27.45, night)
	sun.rotation_degrees.y = lerpf(130.0, 153.79, night)
	sun.light_angular_distance = 2.2
	environment.ambient_light_color = Color("e2c9cf").lerp(Color("8f90c8"), night)
	environment.ambient_light_energy = 0.32
	environment.fog_enabled = not _debug_colors
	environment.fog_light_color = Color("c3a4d0").lerp(Color("2f2b5a"), night).lerp(Color("9c97b4"), rain * 0.5)
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 120.0
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.2
	environment.fog_density = (0.14 if _overview else lerpf(0.5, 0.8, rain))
	environment.fog_aerial_perspective = 0.35
	environment.fog_sun_scatter = 0.2
	environment.fog_sky_affect = 0.0
	var sky: ShaderMaterial = _world.get("_cloud_sky_material")
	if sky != null:
		sky.set_shader_parameter("top_color", Color("4a4aa0").lerp(Color("141a44"), night).lerp(Color("5d5f86"), rain * 0.4))
		sky.set_shader_parameter("horizon_color", Color("ffb88a").lerp(Color("3a3466"), night).lerp(Color("a79aa8"), rain * 0.4))

func get_report() -> Dictionary:
	var colliders: int = find_children("*", "CollisionObject3D", true, false).size() - (route_report.get("colliders", 0) as int)
	var shadows: int = 0
	for node: GeometryInstance3D in _nodes + _static:
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadows += 1
	var winding_ok: bool = float(winding_checks.get("terrain_centre_normal_y", -1.0)) > 0.0 and float(winding_checks.get("cap_top_normal_y", -1.0)) > 0.0 and bool(winding_checks.get("stem_side_normal_outward", false))
	return {"passed": colliders == 0 and shadows == 0 and winding_ok, "trees": tree_report, "moss_mean": _moss_mean.to_html(false), "winding_checks": winding_checks, "winding_ok": winding_ok, "colliders": colliders, "shadow_casters": shadows, "canopies": canopy_count, "grounded_stems": grounded_stems, "rocks": rock_count, "forest_clumps": carpet_count, "forest_chunks": carpet_chunks, "stem_buttresses": "5 lobes integrated into the stem surface", "diagnostic_skips": diagnostic_skips, "terrain_triangles": terrain_triangles, "carpet_triangles": carpet_triangles, "draw_nodes": _nodes.size() + _static.size(), "baked_extent_xz": [baked_extent.position.x, baked_extent.position.y, baked_extent.end.x, baked_extent.end.y], "far_plane": FAR_PLANE, "fog_end": FOG_END, "built_at_startup_only": true, "route": route_report, "traversable": "route corridor only (see route.runtime_tested)", "scope": "Far terrain, giants, pillars and carpet are a non-colliding visual blockout. Only the NaturalRoute ribbon has collision."}
