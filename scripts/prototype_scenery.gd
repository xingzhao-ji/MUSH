extends Node3D
## Reversible far-layer scenery for the clearing: a graded terraced valley, forest
## carpet, fungal giants and rock pillars. Built once at startup; no colliders, no
## shadows, no per-frame geometry. LABELED VISUAL BLOCKOUT: none of this is walkable.
## Selected by project setting mush/prototype/scenery or --prototype-scenery=on|off.
const SHADER := preload("res://assets/world/far_canopy.gdshader")
const Route := preload("res://scripts/prototype_route.gd")
const TERRAIN_SHADER := preload("res://assets/world/far_terrain.gdshader")
const PATH_SHADER := preload("res://assets/world/prototype_path.gdshader")
const WATER_SHADER := preload("res://assets/world/far_water.gdshader")
const LEAF_SHADER := preload("res://assets/world/prototype_leaf.gdshader")
const SOURCE_LEAF_SHADER := preload("res://lineage/living-scenery37-proposal01/canopy-wind37.gdshader")
## Existing detailed project textures (import settings unchanged; moss has no mipmaps).
const MOSS_TEXTURE := preload("res://assets/world/textures/moss-albedo-proposal-v1.png")
const ROCK_TEXTURE := preload("res://assets/world/textures/rock_01_diff_1k.jpg")
const HERO := Vector2(378.0, -648.0)
## Giants: x, z, cap radius, underside height above local ground. The hero stands about
## 20 degrees from the sun direction as seen from the clearing, so it is backlit.
const GIANTS: Array = [[378.0, -648.0, 220.0, 264.0], [-280.0, -760.0, 110.0, 140.0], [700.0, -420.0, 90.0, 120.0], [480.0, -900.0, 36.0, 55.0], [-60.0, -850.0, 30.0, 48.0], [820.0, -760.0, 40.0, 60.0], [250.0, -1000.0, 34.0, 50.0]]
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
## Local detail patch over the rim view's central cliff band (target cell size, metres).
const DETAIL_CELL := 6.0
## Giant footing heights must match the legacy landform within this tolerance (metres).
const FOOTING_TOLERANCE := 0.01
## Near-tree crowns may use a denser existing canopy mesh up to this many vertices.
## Near-tree crowns may use a distinct existing canopy mesh up to this many times the ring mesh's triangles.
const NEAR_CROWN_MAX_RATIO := 8
## Dense near crowns are drawn only within this distance; the ring crown is their far LOD.
const NEAR_CROWN_RANGE := 100.0
const NEAR_CROWN_MARGIN := 12.0
const FOREST_HUES: Array[Color] = [Color("2f5a2a"), Color("3f6e2e"), Color("5a7a30"), Color("5d6b2c"), Color("2a4a2c")]
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
## Connected slice: knoll junction (continuing straight out of the existing route's end,
## so both ribbons share one flush cross-section) -> 13 m loop round the knoll summit's
## south side -> eastern high ground -> two switchbacks down the
## terrace benches -> valley floor -> east shoreline (10-15 m from the water) -> hero root.
## Laid out from a grade-constrained search over the installed heightfield (diagnostic
## tests/terrain_probe.gd); the last point lies inside the hero stem so its root stops
## the walker. The junction point is taken from the existing route's end at runtime.
const SLICE_WAYPOINTS: Array[Vector2] = [Vector2(57.1, 228.3), Vector2(58.1, 238), Vector2(65.1, 244.1), Vector2(69.6, 244.9), Vector2(85, 243), Vector2(100, 237), Vector2(114, 226), Vector2(127, 211), Vector2(150, 180), Vector2(170, 161), Vector2(195, 148), Vector2(230, 130), Vector2(270, 110), Vector2(300, 96), Vector2(320, 85.5), Vector2(331, 80), Vector2(340, 76), Vector2(349.9, 71.9), Vector2(354, 62), Vector2(349.9, 52.1), Vector2(340, 48), Vector2(329, 47.5), Vector2(316, 47.5), Vector2(290, 50), Vector2(262, 47), Vector2(238, 40), Vector2(221, 38.5), Vector2(209, 38.2), Vector2(198, 38), Vector2(188.1, 33.9), Vector2(184, 24), Vector2(188.1, 14.1), Vector2(198, 10), Vector2(209, 9.8), Vector2(222, 9.8), Vector2(247, 10), Vector2(270, 8), Vector2(292, 4), Vector2(312, -6), Vector2(334, -18), Vector2(360, -22), Vector2(385, -32), Vector2(410, -45), Vector2(436, -60), Vector2(462, -76), Vector2(488, -90), Vector2(505, -106), Vector2(500, -125), Vector2(482, -142), Vector2(455, -175), Vector2(420, -204), Vector2(393, -243), Vector2(387, -298), Vector2(397, -356), Vector2(402, -418), Vector2(390, -478), Vector2(378, -540), Vector2(377, -608)]
const SLICE_GRADE := 0.205
## Switchback turns are flattened: inside turns tighter than SLICE_TURN_RADIUS the tread
## grade is capped, so the inner shoulder edge stays far below the 30 degree surface limit.
## Both hairpins are 14 m arcs sampled every 45 degrees.
const SLICE_TURN_GRADE := 0.12
const SLICE_TURN_RADIUS := 20.0
## Trail bed: matches the ribbon cross-section (flat tread 1.8 m, shoulders falling at the
## module's 18 degrees to 4 m) 0.12 m below it, then blends back to natural ground by 30 m.
const SLICE_BED_EDGE := 4.0
const SLICE_BED_BLEND := 30.0
const SLICE_BUCKET := 40.0
## Second detail patch over the slice (world x/z), disjoint from the cliff patch's rows.
const SLICE_PATCH := Rect2(60.0, -393.0, 460.0, 663.0)
## Clearing edge feather: far-terrain moss tone gain near the baked ground (linear), so
## the square no longer reads by colour from afar; measured from the overview capture.
const CLEARING_GAIN := Color(2.6, 2.2, 2.0)
const DAY_SUN := Color("ffc07e")
## Palette/depth pass: warm sunlit foreground and cooler, layered distance. Day endpoints only
## (night and rain endpoints, fog density and distances are unchanged); with look_depth false
## apply_look writes exactly the previous values. The ambient stays as before: a cooler ambient
## darkened and cooled the shaded clearing (scenic-20261026-103711-32659).
## Sky: the live sky (drifting-clouds37) is mix(horizon, top, pow(height, 0.45)), so at the
## 10-30 degree elevations these views see, about half of every sky pixel is the horizon colour;
## a peach horizon blended with a violet top reads as lavender. A pale warm cream horizon and a
## clear cool blue top give a warm horizon line under a cooler blue sky.
const DEPTH_LOOK := {"sun": Color("ffbc72"), "ambient": Color("d2d0ca"), "fog": Color("8ea4d4"), "sky_top": Color("3d74c8"), "sky_horizon": Color("f0dcbc"), "lake_horizon": Color("c2b4d6")}
var look_depth: bool = true
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
## Foreground corridor understory (see _add_corridor_understory).
## Limited stretch: the east-shore and lower root-approach walk (z -240 .. -440).
const UNDERSTORY_Z := Vector2(-240.0, -440.0)
const UNDERSTORY_CLEAR := 60.0
const UNDERSTORY_RANGE := 110.0
const UNDERSTORY_CHUNK := 80.0
var understory: Node3D
var replaced_carpet: MultiMeshInstance3D
var understory_report: Dictionary = {}
var _understory_sync: Array = []
## Hero stem organic finish (far_canopy mode 1), masked to this radius around the hero base;
## the nearest other giant stands ~395 m away.
const STEM_FOCUS_RADIUS := 200.0
const STEM_ORGANIC := 1.0
var stem_material: ShaderMaterial
## Cliff readability, applied by the shared terrain shader only inside the cliff detail patch's
## region (the near massif whose shaded faces read near-black from the root approach).
const ROCK_READABILITY := {"rock_breakup": 1.0, "rock_relief": 0.5, "rock_fill": 1.0, "rock_albedo_lift": 2.2}
var rock_material: ShaderMaterial
var _tree_templates: Array = []
var _near_crown: Dictionary = {}
var corridor_trees: Array[MultiMeshInstance3D] = []
## Visible near-corridor forest clumps (centre within this of the stretch's path) are replaced
## by layered groups of the copied native trees; clumps beyond it stay as distant backdrop.
const CORRIDOR_TREE_REACH := 125.0
var leaf_materials_restrained: int = 0
var diagnostic_skips: PackedStringArray = PackedStringArray()
var _world: Node3D
var _ridge_noise: FastNoiseLite
var _hill_noise: FastNoiseLite
var _terrace_noise: FastNoiseLite
var _legacy_mesa: bool = false
## World rect of the 5 m detail patch; fine flutes/peaks are weighted to it (coarse cells would alias them).
var _detail_region := Rect2()
var rock_triangles: int = 0
var landform_checks: Dictionary = {}
var detail_patch_triangles: int = 0
## [original material, softened duplicate] pairs; dynamic wind/night uniforms are copied.
var _crown_sync: Array = []
var detail_cells_replaced: int = 0
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
var slice_route: Node3D
var slice_report: Dictionary = {}
var root_body: StaticBody3D
var root_collision_triangles: int = 0
var slice_patch_triangles: int = 0
var _slice_bed: PackedVector3Array = PackedVector3Array()
## Vegetation decision phases ignore the slice's trail bed (as they ignore the eroded
## landform), so their random draws, and every existing placement, stay unchanged.
var _skip_slice_bed: bool = false
var _slice_buckets: Dictionary = {}
var _slice_box := Rect2()
var _rendered_buckets: Dictionary = {}
var _rendered_faces: PackedVector3Array = PackedVector3Array()

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
	var height: float = _raw_height(x, z)
	var slice_flat: float = NAN
	if not (_skip_slice_bed or _slice_bed.is_empty() or not _slice_box.has_point(Vector2(x, z)) or _box_distance(x, z) <= 0.0):
		var info: Vector2 = _slice_bed_info(x, z)
		if info.x < SLICE_BED_BLEND: height = lerpf(info.y, height, smoothstep(SLICE_BED_EDGE, SLICE_BED_BLEND, info.x))
		if info.x < SLICE_BED_EDGE: slice_flat = info.y
	var route_flat: float = NAN
	var route_info: Vector2 = _route_bed_info(x, z)
	if route_info.x < INF:
		height = lerpf(route_info.y - 0.12, height, smoothstep(4.0, 11.0, route_info.x))
		if route_info.x < 4.0: route_flat = route_info.y - 0.12
	# Where both trail beds meet (the knoll junction), neither may raise ground over the
	# other route's walking surface inside its flat zone.
	if not is_nan(slice_flat): height = minf(height, slice_flat)
	if not is_nan(route_flat): height = minf(height, route_flat)
	return height

## Slice trail bed at x,z from the built ribbon's own samples (bucketed): (distance to the
## centreline, bed surface matching the ribbon cross-section 0.12 m below it), or INF.
func _slice_bed_info(x: float, z: float) -> Vector2:
	var key := Vector2i(floori(x / SLICE_BUCKET), floori(z / SLICE_BUCKET))
	if not _slice_buckets.has(key): return Vector2(INF, 0.0)
	var here := Vector2(x, z)
	var best: float = INF
	var tread: float = 0.0
	for i: int in _slice_buckets[key]:
		var a := Vector2(_slice_bed[i].x, _slice_bed[i].z)
		var ab := Vector2(_slice_bed[i + 1].x, _slice_bed[i + 1].z) - a
		var t: float = clampf((here - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var dist: float = here.distance_to(a + ab * t)
		if dist < best:
			best = dist
			tread = lerpf(_slice_bed[i].y, _slice_bed[i + 1].y, t)
	return Vector2(best, tread - 0.12 - maxf(0.0, minf(best, SLICE_BED_EDGE) - 1.8) * 0.325)

## Existing route trail bed (unchanged rule): (distance to the planned centreline, tread), or INF.
func _route_bed_info(x: float, z: float) -> Vector2:
	if _route_points.is_empty() or _shaping_route or not _route_box.has_point(Vector2(x, z)) or _box_distance(x, z) <= 0.0:
		return Vector2(INF, 0.0)
	var best: float = INF
	var tread: float = 0.0
	for i: int in _route_points.size() - 1:
		var a := Vector2(_route_points[i].x, _route_points[i].z)
		var ab := Vector2(_route_points[i + 1].x, _route_points[i + 1].z) - a
		var t: float = clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var dist: float = Vector2(x, z).distance_to(a + ab * t)
		if dist < best:
			best = dist
			tread = lerpf(_route_points[i].y, _route_points[i + 1].y, t)
	return Vector2(best, tread)

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
	# Far eroded massifs in the valley half (see _mesa_height).
	height += _mesa_height(x, z, r, dir)
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

## Eroded layered massifs: broad warped bodies with talus feet, uneven strata ledges
## that survive only where an erosion mask allows, gullies cut down the faces and
## undulating crowns. The previous stacked-terrace form is kept (_legacy_mesa_height)
## under every giant's footing, so giants do not move, and for vegetation placement
## decisions, so the seeded placement stream does not shift.
func _mesa_height(x: float, z: float, r: float, dir: Vector2) -> float:
	var mask: float = smoothstep(550.0, 900.0, r) * smoothstep(0.0, 0.6, dir.dot(VALLEY_DIR))
	if mask <= 0.0: return 0.0
	var legacy: float = _legacy_mesa_height(x, z)
	if _legacy_mesa: return legacy * mask
	var keep: float = _giant_footing(x, z)
	if keep >= 1.0: return legacy * mask
	return lerpf(_eroded_mesa_height(x, z), legacy, keep) * mask

func _legacy_mesa_height(x: float, z: float) -> float:
	var mesa: float = smoothstep(0.25, 0.4, _ridge_noise.get_noise_2d(x, z)) * 220.0
	var warped: float = mesa + _terrace_noise.get_noise_2d(x * 1.7, z * 1.7) * 26.0 * smoothstep(0.0, 40.0, mesa)
	return _terrace(warped, 55.0, 0.3)

## True where the eroded massif changed the height relative to the legacy form.
func _landform_changed(x: float, z: float) -> bool:
	var was: bool = _legacy_mesa
	_legacy_mesa = false
	var now: float = terrain_height(x, z)
	_legacy_mesa = true
	var before: float = terrain_height(x, z)
	_legacy_mesa = was
	return absf(now - before) > 0.5

## The legacy landform is kept only under the hero giant's footing, so the composition
## anchor does not move. Small giants stand on the eroded landform at the same x/z (their
## stems are grounded from terrain_height); keeping legacy discs under them left stepped
## terrace columns standing out of the new massifs.
## Every giant keeps its footing (base height unchanged) inside a narrow, smoothly faded
## support zone sized to its stem and buttress footprint (stem radius 0.15 x cap radius;
## full within 2.6 stem radii, gone by 4.8). Cap-sized discs (used before 036ae7d) kept a
## stepped legacy terrace tower standing behind the hero's stem.
func _giant_footing(x: float, z: float) -> float:
	var keep: float = 0.0
	for row: Array in GIANTS:
		var stem_r: float = float(row[2]) * 0.15
		keep = maxf(keep, 1.0 - smoothstep(stem_r * 2.6, stem_r * 4.8, Vector2(x, z).distance_to(Vector2(row[0], row[1]))))
	return keep

func _eroded_mesa_height(x: float, z: float) -> float:
	var warp := Vector2(_hill_noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6), _hill_noise.get_noise_2d(x * 0.6, z * 0.6 - 300.0)) * 90.0
	var n: float = _ridge_noise.get_noise_2d(x + warp.x, z + warp.y)
	var talus: float = smoothstep(0.02, 0.3, n) * 38.0
	# Cliff line crenellated into buttress spurs (~55 m) and, inside the detail patch,
	# columnar flutes (~24 m): the face becomes vertical ribs and recesses, not a ramp.
	var region: float = _detail_weight(x, z)
	var edge: float = 1.0 - smoothstep(0.0, 0.16, absf(n - 0.28))
	var spur: float = pow(1.0 - absf(_hill_noise.get_noise_2d(x * 2.6 + 1300.0, z * 2.6)), 2.0)
	var flute: float = pow(1.0 - absf(_terrace_noise.get_noise_2d(x * 14.0, z * 14.0)), 3.0)
	var n2: float = n + edge * ((spur - 0.45) * 0.07 + (flute - 0.35) * 0.03 * region)
	var body: float = smoothstep(0.16, 0.40, n2)
	if body <= 0.0: return talus
	var top: float = smoothstep(0.7, 1.0, body)
	var face: float = smoothstep(0.15, 0.6, body) * (1.0 - top * 0.6)
	var tall: float = 160.0 + 100.0 * (_terrace_noise.get_noise_2d(x * 0.5, z * 0.5) * 0.5 + 0.5)
	var raw: float = body * tall
	# Strata: step height varies over ~300 m; risers are wide enough to span several
	# detail cells (no grid-aliased teeth) and fade out on the tops (no stepped crests).
	var step: float = 22.0 + 20.0 * (_hill_noise.get_noise_2d(x * 0.9 + 900.0, z * 0.9) * 0.5 + 0.5)
	var strata: float = _terrace(raw + _terrace_noise.get_noise_2d(x * 2.1, z * 2.1) * 9.0, step, 0.78)
	var survive: float = smoothstep(-0.25, 0.35, _terrace_noise.get_noise_2d(x * 0.9 + 500.0, z * 0.9))
	var shaped: float = lerpf(raw, strata, survive * smoothstep(0.2, 0.55, body) * (1.0 - top * 0.85))
	# Erosion at three scales, each domain-warped differently: large gullies (~220 m),
	# medium couloirs (~90 m) and small breakup (~65 m); the finest term is kept weak.
	var gully: float = pow(1.0 - absf(_hill_noise.get_noise_2d(x * 1.3 - 400.0, z * 1.3)), 6.0) * 34.0 * smoothstep(0.25, 0.7, body) * (1.0 - smoothstep(0.9, 1.0, body))
	var bend := Vector2(_terrace_noise.get_noise_2d(x * 1.1, z * 1.1 + 40.0), _terrace_noise.get_noise_2d(x * 1.1 - 40.0, z * 1.1)) * 45.0
	var couloir: float = pow(1.0 - absf(_ridge_noise.get_noise_2d((x + bend.x) * 6.0, (z + bend.y) * 6.0)), 4.0) * 14.0 * face
	var breakup: float = (_terrace_noise.get_noise_2d((x + bend.y) * 5.0, (z + bend.x) * 5.0) * 5.0 + _hill_noise.get_noise_2d(x * 9.0 + 200.0, z * 9.0) * 1.2) * face
	# Tops: soft ridgelines and saddles instead of one flat plateau.
	var ridges: float = (pow(1.0 - absf(_ridge_noise.get_noise_2d(x * 2.2 + 900.0, z * 2.2)), 2.2) * 55.0 - 15.0) * top
	var crown: float = _hill_noise.get_noise_2d(x * 0.8, z * 0.8 + 700.0) * 22.0 * top
	# Occasional sharp skyline peaks along narrow crests (full strength only in the patch).
	var peak_mask: float = smoothstep(0.1, 0.45, _terrace_noise.get_noise_2d(x * 0.7 + 2000.0, z * 0.7))
	var peaks: float = pow(1.0 - absf(_ridge_noise.get_noise_2d(x * 4.0 + 333.0, z * 4.0)), 8.0) * 80.0 * top * peak_mask * (0.35 + 0.65 * region)
	return maxf(shaped - gully - couloir + crown + ridges + breakup + peaks, talus)

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
	_detail_region = _detail_bounds()
	_collect_soil(baked_extent.grow(6.0))
	_sample_edges()
	_plan_route()
	# The existing ribbon depends only on its planned points, so building it before the
	# terrain mesh leaves it identical; the slice starts from its measured end.
	_add_route()
	_add_slice_route()
	# Diagnostic-only performance bisection (empty by default; never set by the game).
	var skip: PackedStringArray = OS.get_environment("MUSH_SCENERY_DIAG").split(",", false)
	_add_terrain()
	if "plain_terrain" in skip: _terrain_material.shader = preload("res://assets/world/far_canopy.gdshader"); _terrain_material.set_shader_parameter("mode", 2)
	if "no_water" in skip: _static[_static.size() - 1].visible = false
	_add_giants(rng)
	_add_root_collision()
	_add_pillars(rng)
	_add_boulders(rng)
	if not "no_trees" in skip: _add_trees(rng)
	if not "no_carpet" in skip: _add_carpet(rng)
	if not "no_understory" in skip: _add_corridor_understory()
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
	var coarse := PackedFloat32Array()
	for column: int in columns:
		var sx: float = lerpf(-1.0, 1.0, float(column) / TERRAIN_CELLS)
		coarse.append(TERRAIN_HALF * signf(sx) * pow(absf(sx), 1.7))
	var patch: Rect2i = _detail_patch_cells(coarse)
	var slice_cells: Rect2i = _slice_patch_cells(coarse, patch)
	for row: int in TERRAIN_CELLS:
		for column: int in TERRAIN_CELLS:
			if patch.has_point(Vector2i(column, row)) or slice_cells.has_point(Vector2i(column, row)): continue
			var i0: int = row * columns + column
			var i1: int = i0 + 1
			var i2: int = i0 + columns
			var i3: int = i2 + 1
			# Clockwise as seen from above (Godot front face), verified in get_report().
			st.add_index(i0); st.add_index(i1); st.add_index(i2)
			st.add_index(i1); st.add_index(i3); st.add_index(i2)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	detail_cells_replaced = patch.get_area()
	terrain_triangles = (TERRAIN_CELLS * TERRAIN_CELLS - detail_cells_replaced - slice_cells.get_area()) * 2
	landform_checks["slice_coarse_cells_replaced"] = slice_cells.get_area()
	var centre: int = (TERRAIN_CELLS / 2) * columns + TERRAIN_CELLS / 2
	var near_vertical: int = 0
	var finite: bool = true
	for normal: Vector3 in (mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array):
		finite = finite and normal.is_finite()
		if normal.y < 0.25: near_vertical += 1
	landform_checks["terrain_finite"] = finite
	landform_checks["near_vertical_vertices"] = near_vertical
	# All-giant footing drift against the legacy landform (the ground every giant stood on
	# at bd3fcea); required to be zero within FOOTING_TOLERANCE.
	var footing_drift: float = 0.0
	var bases: Array = []
	for row: Array in GIANTS:
		var now: float = terrain_height(row[0], row[1])
		_legacy_mesa = true
		var before: float = terrain_height(row[0], row[1])
		_legacy_mesa = false
		footing_drift = maxf(footing_drift, absf(now - before))
		bases.append([row[0], snappedf(now, 0.001), row[1]])
	landform_checks["giant_footing_drift_m"] = footing_drift
	landform_checks["giant_bases_xyz"] = bases
	var route_drift: float = 0.0
	for point: Vector3 in _route_points:
		var now: float = terrain_height(point.x, point.z)
		_legacy_mesa = true
		route_drift = maxf(route_drift, absf(now - terrain_height(point.x, point.z)))
		_legacy_mesa = false
	landform_checks["route_terrain_drift_m"] = route_drift
	winding_checks["terrain_centre_normal_y"] = (mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array)[centre].y
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	_terrain_material.set_shader_parameter("moss_tex", MOSS_TEXTURE)
	_terrain_material.set_shader_parameter("rock_tex", ROCK_TEXTURE)
	_terrain_material.set_shader_parameter("moss_mean", _moss_mean)
	_terrain_material.set_shader_parameter("clearing_rect", Vector4(baked_extent.position.x, baked_extent.position.y, baked_extent.end.x, baked_extent.end.y))
	_terrain_material.set_shader_parameter("clearing_gain", Vector3(CLEARING_GAIN.r, CLEARING_GAIN.g, CLEARING_GAIN.b))
	_terrain_material.set_shader_parameter("rock_focus_rect", Vector4(_detail_region.position.x, _detail_region.position.y, _detail_region.end.x, _detail_region.end.y))
	for key: String in ROCK_READABILITY: _terrain_material.set_shader_parameter(key, ROCK_READABILITY[key])
	rock_material = _terrain_material
	var terrain := MeshInstance3D.new()
	terrain.name = "WorldTerrain"
	terrain.mesh = mesh
	terrain.material_override = _terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	_static.append(terrain)
	detail_patch_triangles = _add_detail_patch(coarse, patch, "CliffDetailPatch", "detail_patch")
	slice_patch_triangles = _add_detail_patch(coarse, slice_cells, "SliceDetailPatch", "slice_patch")
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

## Coarse cells under the rim view's central cliff band (520-1150 m out, about +/-20
## degrees around the hero direction), snapped to coarse grid lines.
func _detail_bounds() -> Rect2:
	var rim: Vector2 = _rim_point(5.0)
	var ahead: Vector2 = (HERO - rim).normalized()
	var bounds := Rect2(rim + ahead * 520.0, Vector2.ZERO)
	for distance: float in [520.0, 800.0, 1150.0]:
		for degrees: float in [-20.0, -10.0, 0.0, 10.0, 20.0]:
			bounds = bounds.expand(rim + ahead.rotated(deg_to_rad(degrees)) * distance)
	return bounds

## 1 well inside the detail patch, 0 at and beyond its border.
func _detail_weight(x: float, z: float) -> float:
	var r: Rect2 = _detail_region
	if r.size == Vector2.ZERO: return 0.0
	var inside: float = minf(minf(x - r.position.x, r.end.x - x), minf(z - r.position.y, r.end.y - z))
	return smoothstep(20.0, 80.0, inside)

func _detail_patch_cells(coarse: PackedFloat32Array) -> Rect2i:
	var bounds: Rect2 = _detail_bounds()
	var c0: int = maxi(0, coarse.bsearch(bounds.position.x) - 1)
	var c1: int = mini(coarse.size() - 1, coarse.bsearch(bounds.end.x))
	var r0: int = maxi(0, coarse.bsearch(bounds.position.y) - 1)
	var r1: int = mini(coarse.size() - 1, coarse.bsearch(bounds.end.y))
	return Rect2i(c0, r0, c1 - c0, r1 - r0)

## Detail patch at about DETAIL_CELL spacing. Border vertices lie on the coarse cell
## edges at the coarse edge's straight-line height, so the join is watertight.
## Coarse cells under the connected slice, starting at the cliff patch's last row line so
## the two patches never share a cell (their common border lies on coarse edges).
func _slice_patch_cells(coarse: PackedFloat32Array, cliff: Rect2i) -> Rect2i:
	var c0: int = maxi(0, coarse.bsearch(SLICE_PATCH.position.x) - 1)
	var c1: int = mini(coarse.size() - 1, coarse.bsearch(SLICE_PATCH.end.x))
	var r0: int = cliff.end.y
	var r1: int = mini(coarse.size() - 1, coarse.bsearch(SLICE_PATCH.end.y))
	return Rect2i(c0, r0, c1 - c0, maxi(0, r1 - r0))

func _add_detail_patch(coarse: PackedFloat32Array, cells: Rect2i, label: String, key: String) -> int:
	if cells.get_area() <= 0: return 0
	var px := PackedFloat32Array()
	var pz := PackedFloat32Array()
	for axis: int in 2:
		var line: PackedFloat32Array = px if axis == 0 else pz
		var first: int = cells.position.x if axis == 0 else cells.position.y
		var last: int = cells.end.x if axis == 0 else cells.end.y
		for c: int in range(first, last):
			var parts: int = maxi(1, ceili((coarse[c + 1] - coarse[c]) / DETAIL_CELL))
			for k: int in parts: line.append(lerpf(coarse[c], coarse[c + 1], float(k) / parts))
		line.append(coarse[last])
		if axis == 0: px = line
		else: pz = line
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in pz.size():
		for i: int in px.size():
			var x: float = px[i]
			var z: float = pz[j]
			var h: float
			if i == 0 or i == px.size() - 1:
				var r: int = clampi(coarse.bsearch(z, false) - 1, 0, coarse.size() - 2)
				h = lerpf(terrain_height(x, coarse[r]), terrain_height(x, coarse[r + 1]), inverse_lerp(coarse[r], coarse[r + 1], z))
			elif j == 0 or j == pz.size() - 1:
				var c: int = clampi(coarse.bsearch(x, false) - 1, 0, coarse.size() - 2)
				h = lerpf(terrain_height(coarse[c], z), terrain_height(coarse[c + 1], z), inverse_lerp(coarse[c], coarse[c + 1], x))
			else:
				h = terrain_height(x, z)
			st.set_color(Color(0, 0, 0))
			st.set_uv(Vector2(float(i) / (px.size() - 1), float(j) / (pz.size() - 1)))
			st.add_vertex(Vector3(x, h, z))
	var width: int = px.size()
	for j: int in pz.size() - 1:
		for i: int in width - 1:
			var i0: int = j * width + i
			var i1: int = i0 + 1
			var i2: int = i0 + width
			var i3: int = i2 + 1
			st.add_index(i0); st.add_index(i1); st.add_index(i2)
			st.add_index(i1); st.add_index(i3); st.add_index(i2)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var triangles: int = (px.size() - 1) * (pz.size() - 1) * 2
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var up: bool = true
	for normal: Vector3 in normals: up = up and normal.is_finite()
	landform_checks[key + "_normals_finite"] = up
	landform_checks[key + "_centre_normal_y"] = normals[(pz.size() / 2) * width + width / 2].y
	landform_checks[key + "_world_rect"] = [px[0], pz[0], px[px.size() - 1], pz[pz.size() - 1]]
	landform_checks[key + "_grid"] = [px.size() - 1, pz.size() - 1]
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = _terrain_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_static.append(node)
	return triangles

## Medium-distance review pose on the detailed cliff band (camera only, not walkable):
## about 600 m out on the sun side, raised to clear the terrain along its sightline.
func cliff_detail_pose() -> Dictionary:
	var rim: Vector2 = _rim_point(5.0)
	var ahead: Vector2 = (HERO - rim).normalized()
	var focus2: Vector2 = rim + ahead.rotated(deg_to_rad(14.0)) * 950.0
	var focus := Vector3(focus2.x, terrain_height(focus2.x, focus2.y) + 50.0, focus2.y)
	var sunward := Vector2(0.77, -0.64).normalized()
	var eye2: Vector2 = focus2 + sunward * 600.0
	var eye_y: float = maxf(terrain_height(eye2.x, eye2.y) + 60.0, focus.y + 80.0)
	# Clear the terrain along the first 70% of the sightline only: near the focus the
	# cliff itself rises, and clearing it would push the camera far overhead.
	for k: int in range(1, 15):
		var t: float = float(k) / 20.0
		var probe: Vector2 = eye2.lerp(focus2, t)
		eye_y = maxf(eye_y, (terrain_height(probe.x, probe.y) + 25.0 - focus.y * t) / (1.0 - t))
	eye_y = minf(eye_y, focus.y + 260.0)
	return {"position": Vector3(eye2.x, eye_y, eye2.y), "target": focus, "fov": 40.0}

## Side review pose (camera only): perpendicular to the rim view, looking across the massif
## band so cliff faces, spurs and crag spires read in silhouette against the sky.
func landform_side_pose() -> Dictionary:
	var rim: Vector2 = _rim_point(5.0)
	var ahead: Vector2 = (HERO - rim).normalized()
	var focus2: Vector2 = rim + ahead.rotated(deg_to_rad(8.0)) * 900.0
	var focus := Vector3(focus2.x, terrain_height(focus2.x, focus2.y) + 90.0, focus2.y)
	var side := Vector2(ahead.y, -ahead.x)
	var eye2: Vector2 = focus2 + side * 750.0
	var eye_y: float = maxf(terrain_height(eye2.x, eye2.y) + 50.0, focus.y - 20.0)
	for k: int in range(1, 15):
		var t: float = float(k) / 20.0
		var probe: Vector2 = eye2.lerp(focus2, t)
		eye_y = maxf(eye_y, (terrain_height(probe.x, probe.y) + 25.0 - focus.y * t) / (1.0 - t))
	eye_y = minf(eye_y, focus.y + 220.0)
	return {"position": Vector3(eye2.x, eye_y, eye2.y), "target": focus, "fov": 45.0}

func _giant_specs() -> Array:
	return GIANTS

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
	# Hero stem only (masked around its base; the other six stems keep their exact look).
	stem_material = _art[_art.size() - 1]
	if not hero.is_empty():
		stem_material.set_shader_parameter("stem_focus", Vector4(hero.base.x, hero.base.z, STEM_FOCUS_RADIUS, 0.0))
		stem_material.set_shader_parameter("stem_organic", STEM_ORGANIC)

func _add_pillars(rng: RandomNumberGenerator) -> void:
	# Fused clusters of slender, jagged needle crags replace the fat stacked pillar.
	# Same three sites and draw call; rng draw count per site unchanged.
	var crag: ArrayMesh = _crag_mesh()
	var xs: Array[Transform3D] = []
	var tints: Array[Color] = []
	for spot: Vector3 in [Vector3(540.0, 190.0, -980.0), Vector3(120.0, 160.0, -930.0), Vector3(-520.0, 140.0, -520.0)]:
		var ground: float = terrain_height(spot.x, spot.z)
		var height: float = spot.y * 1.25
		var width: float = height * lerpf(0.2, 0.26, inverse_lerp(0.38, 0.5, rng.randf_range(0.38, 0.5)))
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis.from_scale(Vector3(width, height, width)), Vector3(spot.x, ground - 15.0, spot.z)))
		tints.append(Color(rng.randf(), 0, 0))
	rock_count += xs.size()
	rock_triangles = _triangle_count(crag) * xs.size()
	_add(crag, xs, tints, 2, "RockPillars")

## Four fused needles of different height, girth and lean; each has an angular cross-section
## that twists with height, sharp columnar flutes, irregular ledge notches and a jagged tip.
func _crag_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# offset x, offset z, height, radius, lean x, lean z, phase seed
	for needle: Array in [[0.0, 0.0, 1.0, 1.0, 0.10, -0.05, 0.3], [0.62, 0.18, 0.74, 0.62, 0.22, 0.06, 1.9], [-0.42, 0.48, 0.58, 0.52, -0.16, 0.14, 3.4], [0.12, -0.6, 0.44, 0.58, 0.04, -0.2, 5.1]]:
		var profile: Array[Vector3] = []
		var rows := 36
		for i: int in rows + 1:
			var t: float = float(i) / rows
			var radius: float = pow(1.0 - t, 0.78) * (1.0 + 0.25 * pow(1.0 - t, 6.0))
			for notch: Vector2 in [Vector2(0.22, 0.07), Vector2(0.47, 0.05), Vector2(0.69, 0.06)]:
				radius *= 1.0 - notch.y * (1.0 - smoothstep(0.0, 0.035, absf(t - notch.x - 0.08 * sin(needle[6] * 3.0))))
			# Uneven ledges up the height (incommensurate frequencies), so edges are not straight.
			radius *= 1.0 + 0.06 * sin(t * 31.0 + needle[6]) + 0.035 * sin(t * 53.0 + needle[6] * 2.0)
			profile.append(Vector3(radius, t, t))
		var seed: float = needle[6]
		var phases := PackedFloat32Array([seed, seed * 1.7 + 0.4, seed * 2.3 + 1.1, needle[4] / needle[3], needle[5] / needle[3]])
		var part: ArrayMesh = _lathe(profile, 28, "crag", false, phases)
		st.append_from(part, 0, Transform3D(Basis.from_scale(Vector3(needle[3], needle[2], needle[3])), Vector3(needle[0], -0.02, needle[1])))
	st.generate_normals()
	return st.commit()

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

## Denser existing leaf-cluster mesh for near trees. Every candidate canopy mesh is
## recorded first; the choice is the densest distinct mesh up to NEAR_CROWN_MAX_RATIO x the
## ring mesh's triangles (else the least dense one above it), scaled to the ring crown's
## volume, with a softened duplicate material. Originals are never modified.
func _dense_crown(templates: Array) -> Dictionary:
	var small: Mesh = null
	for part: Dictionary in templates[0]:
		if part.kind == "LayeredCanopies":
			small = part.mesh
			break
	var canopies: Variant = _world.get("_m37_canopies")
	var candidates: Array = []
	tree_report["crown_candidates"] = candidates
	if small == null or not canopies is Array:
		tree_report["crown_selection"] = "no ring crown mesh or no canopy list"
		return {}
	var small_tris: int = _triangle_count(small)
	var picks: Array = []
	for entry: Dictionary in canopies:
		var source: MultiMeshInstance3D = entry.get("node")
		if not is_instance_valid(source) or source.multimesh == null or source.multimesh.mesh == null: continue
		var mesh: Mesh = source.multimesh.mesh
		var material: Material = source.material_override if source.material_override != null else mesh.surface_get_material(0)
		var row: Dictionary = {"node": String(source.name), "mesh_id": mesh.get_instance_id(), "vertices": (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "triangles": _triangle_count(mesh), "shadow_mode": int(source.cast_shadow), "material": material.get_class() if material != null else "none", "material_source": "override" if source.material_override != null else "surface", "size_m": snappedf(mesh.get_aabb().size.length(), 0.01), "is_ring_mesh": mesh == small}
		candidates.append(row)
		if mesh != small and material != null and source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			picks.append([row.triangles, mesh, material, row])
	picks.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var chosen: Array = []
	for pick: Array in picks:
		if pick[0] > small_tris and pick[0] <= small_tris * NEAR_CROWN_MAX_RATIO: chosen = pick
	if chosen.is_empty():
		for pick: Array in picks:
			if pick[0] > small_tris:
				chosen = pick
				break
	if chosen.is_empty():
		tree_report["crown_selection"] = "no denser distinct canopy mesh"
		return {}
	var mesh: Mesh = chosen[1]
	var original: Material = chosen[2]
	var softs: Array[Material] = []
	# Two darker, lower-contrast palettes (alternated per crown) so backlit leaves do not
	# read as bright yellow sheets.
	for variant: Array in [[0.22, Color("3f5528"), 0.25], [0.16, Color("55602c"), 0.32]]:
		var soft: Material = original.duplicate()
		_restrain_leaf(soft)
		if original is ShaderMaterial:
			var base: Variant = (original as ShaderMaterial).get_shader_parameter("base_color")
			var accent: Variant = (original as ShaderMaterial).get_shader_parameter("accent_color")
			if base is Color and accent is Color:
				(soft as ShaderMaterial).set_shader_parameter("base_color", (base as Color).darkened(variant[0]).lerp(variant[1], 0.2))
				(soft as ShaderMaterial).set_shader_parameter("accent_color", (base as Color).lerp(accent, variant[2]).darkened(0.1))
			_crown_sync.append([original, soft])
		softs.append(soft)
	var ratio: float = small.get_aabb().size.length() / maxf(mesh.get_aabb().size.length(), 0.001)
	tree_report["crown_selection"] = {"chosen": chosen[3], "ring_triangles": small_tris, "volume_scale": ratio}
	# Far LOD of near trees: the ring crown with the same darker tone as the dense crowns,
	# so the 100 m switch changes leaf density, not colour.
	var ring_material: Material = null
	for part: Dictionary in templates[0]:
		if part.kind == "LayeredCanopies":
			ring_material = part.material
			break
	var far_tone: Material = ring_material
	if ring_material is ShaderMaterial and original is ShaderMaterial:
		far_tone = ring_material.duplicate()
		_restrain_leaf(far_tone)
		for key: String in ["base_color", "accent_color"]:
			var tone: Variant = (softs[0] as ShaderMaterial).get_shader_parameter(key)
			if tone is Color: (far_tone as ShaderMaterial).set_shader_parameter(key, tone)
		_crown_sync.append([ring_material, far_tone])
	return {"mesh": mesh, "materials": softs, "far_material": far_tone, "scale": ratio}

## Duplicate leaf materials only: switch to the prototype copy of the source leaf shader
## and damp backlight transmission and specular glare, so backlit leaves stay green.
func _restrain_leaf(material: Material) -> void:
	if not material is ShaderMaterial or (material as ShaderMaterial).shader != SOURCE_LEAF_SHADER: return
	(material as ShaderMaterial).shader = LEAF_SHADER
	(material as ShaderMaterial).set_shader_parameter("backlight_scale", 0.35)
	(material as ShaderMaterial).set_shader_parameter("leaf_specular", 0.18)
	(material as ShaderMaterial).set_shader_parameter("roughness_value", 0.92)
	leaf_materials_restrained += 1

## One copied-tree MultiMesh node with its LOD role (near: dense crowns within
## NEAR_CROWN_RANGE; far: ring crowns beyond it; all: trunks), added and registered.
func _tree_node(batch: Dictionary, prefix: String) -> MultiMeshInstance3D:
	# Node at the batch centre, so visibility ranges measure from the trees themselves.
	var centre := Vector3.ZERO
	for member: Transform3D in batch.poses: centre += member.origin
	centre /= float(batch.poses.size())
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = batch.mesh
	multi.instance_count = batch.poses.size()
	for i: int in batch.poses.size(): multi.set_instance_transform(i, Transform3D(Basis(), -centre) * batch.poses[i])
	var node := MultiMeshInstance3D.new()
	node.name = prefix + str(batch.kind) + ("_" + str(batch.range) if batch.range != "all" else "")
	# Node names may be uniquified by Godot; the LOD role is carried as metadata.
	node.set_meta("lod_range", batch.range)
	node.multimesh = multi
	node.position = centre
	node.material_override = batch.material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 2.0
	node.visibility_range_end = 700.0
	if batch.range == "near":
		node.visibility_range_end = NEAR_CROWN_RANGE
		node.visibility_range_end_margin = NEAR_CROWN_MARGIN
	elif batch.range == "far":
		node.visibility_range_begin = NEAR_CROWN_RANGE
		node.visibility_range_begin_margin = NEAR_CROWN_MARGIN
	add_child(node, true)
	_static.append(node)
	return node

func _tree_batch(batches: Dictionary, kind: String, mesh: Mesh, material: Material, cell: Vector2i, range_name: String, pose: Transform3D) -> void:
	var key: String = "%s|%d|%d|%d|%d|%s" % [kind, mesh.get_instance_id(), material.get_instance_id(), cell.x, cell.y, range_name]
	if not batches.has(key): batches[key] = {"mesh": mesh, "material": material, "kind": kind, "range": range_name, "poses": []}
	batches[key].poses.append(pose)

func _on_slice(x: float, z: float, margin: float) -> bool:
	if not is_instance_valid(slice_route) or not slice_route.valid: return false
	var y: float = slice_route.surface_height_at(x, z)
	return slice_route.is_in_corridor(Vector3(x, terrain_height(x, z) if is_nan(y) else y, z), margin)

## Triangles in a mesh, for indexed or non-indexed surfaces.
func _triangle_count(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		total += ((index as PackedInt32Array).size() if index is PackedInt32Array else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total

func _add_trees(rng: RandomNumberGenerator) -> void:
	var templates: Array = _forest_templates()
	tree_report = {"templates": templates.size()}
	if templates.is_empty():
		tree_report["error"] = "ForestMiddleLayer templates not found"
		return
	var spots: Array[Vector2] = []
	var groups: Array[int] = []
	# 1. Framing trees beside the rim overlook, kept out of the central view.
	var pose: Dictionary = overlook_pose()
	var eye: Vector3 = pose.position
	var forward := Vector2(pose.target.x - eye.x, pose.target.z - eye.z).normalized()
	var right := Vector2(-forward.y, forward.x)
	for frame: Vector2 in [Vector2(10.0, -9.5), Vector2(14.0, 10.5), Vector2(22.0, -15.5), Vector2(27.0, 17.0), Vector2(7.0, 14.0)]:
		spots.append(Vector2(eye.x, eye.z) + forward * frame.x + right * frame.y)
		groups.append(1)
	var framing: int = spots.size()
	# 2. Terrace shelves, 3. lake-shore groves, 4. route flanks.
	var tries: int = 0
	var shelf: int = 0
	var shore: int = 0
	var flank: int = 0
	_legacy_mesa = true
	_skip_slice_bed = true
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
		groups.append(group)
		if group == 2: shelf += 1
		elif group == 3: shore += 1
		else: flank += 1
	_legacy_mesa = false
	_skip_slice_bed = false
	var near_crown: Dictionary = _dense_crown(templates)
	_tree_templates = templates
	_near_crown = near_crown
	# Separate generator: crown orientation must not shift any seeded placement.
	var crown_rng := RandomNumberGenerator.new()
	crown_rng.seed = 5150
	var near_trees: int = 0
	var near_target: int = 0
	var crowns_replaced: int = 0
	var batches: Dictionary = {}
	for index: int in spots.size():
		var spot: Vector2 = spots[index]
		var template: Array = templates[rng.randi_range(0, templates.size() - 1)]
		var size: float = rng.randf_range(0.9, 1.3) if index >= framing else rng.randf_range(1.05, 1.3)
		var root := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * size), Vector3(spot.x, terrain_height(spot.x, spot.y) - 0.35, spot.y))
		# A tree whose ground the new landform changed, and that now falls on a cliff
		# face, is dropped after its draws; unchanged ground (e.g. the rim) keeps it.
		if _landform_changed(spot.x, spot.y) and terrain_slope(spot.x, spot.y) > 0.6: continue
		# Keep the connected slice walkable and visible (also after the draws).
		if _on_slice(spot.x, spot.y, 6.0): continue
		var cell := Vector2i(floori(spot.x / 160.0), floori(spot.y / 160.0))
		# Near trees (framing and route flanks) get full leaf clusters at their branch ends.
		if groups[index] in [1, 4]: near_target += 1
		var near: bool = not near_crown.is_empty() and groups[index] in [1, 4]
		if near: near_trees += 1
		for part: Dictionary in template:
			if near and part.kind == "LayeredCanopies":
				# Far LOD: the original ring crown, drawn only beyond NEAR_CROWN_RANGE.
				_tree_batch(batches, part.kind, part.mesh, near_crown.far_material, cell, "far", root * part.local)
				# Near: the dense cluster, turned and tilted per crown so leaves do not align.
				var turn := Basis(Vector3.UP, crown_rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, crown_rng.randf_range(-0.35, 0.35)) * Basis(Vector3.FORWARD, crown_rng.randf_range(-0.35, 0.35))
				var dense := Transform3D(part.local.basis * Basis.from_scale(Vector3.ONE * float(near_crown.scale)) * turn, part.local.origin)
				_tree_batch(batches, part.kind, near_crown.mesh, near_crown.materials[crowns_replaced % 2], cell, "near", root * dense)
				crowns_replaced += 1
				continue
			_tree_batch(batches, part.kind, part.mesh, part.material, cell, "all", root * part.local)
	var eye_now: Vector3 = overlook_pose().position
	var lod: Dictionary = {"near_batches": 0, "far_batches": 0, "near_instances": 0, "near_triangles": 0, "rim_view_dense_instances": 0, "rim_view_dense_triangles": 0}
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var node: MultiMeshInstance3D = _tree_node(batch, "CopiedTrees_")
		var multi: MultiMesh = node.multimesh
		var centre: Vector3 = node.position
		var triangles: int = _triangle_count(batch.mesh) * multi.instance_count
		if batch.range == "near":
			lod.near_batches += 1
			lod.near_instances += multi.instance_count
			lod.near_triangles += triangles
			if eye_now.distance_to(centre) < NEAR_CROWN_RANGE:
				lod.rim_view_dense_instances += multi.instance_count
				lod.rim_view_dense_triangles += triangles
		elif batch.range == "far":
			lod.far_batches += 1
		tree_instances += multi.instance_count
	tree_report["lod"] = lod
	tree_count = spots.size()
	var tree_triangles: int = 0
	for key: String in batches:
		tree_triangles += _triangle_count(batches[key].mesh) * batches[key].poses.size()
	tree_report.merge({"trees": tree_count, "near_trees_target": near_target, "near_trees_replaced": near_trees, "crown_instances_replaced": crowns_replaced, "tree_triangles": tree_triangles, "framing": framing, "shelf": shelf, "shore": shore, "flank": flank, "instances": tree_instances, "batches": batches.size()})

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
	_legacy_mesa = true
	_skip_slice_bed = true
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
		# Groves and gaps: sparse where the grove field is low, dense elsewhere.
		if _hill_noise.get_noise_2d(x * 0.6 + 1700.0, z * 0.6) < -0.15 and rng.randf() > 0.15: continue
		# Varied silhouettes from one mesh: spires, rounded crowns and spreading crowns.
		var form: float = rng.randf()
		var width: float = rng.randf_range(6.0, 10.0) if form < 0.3 else (rng.randf_range(11.0, 20.0) if form < 0.8 else rng.randf_range(16.0, 26.0))
		var height: float = rng.randf_range(16.0, 26.0) if form < 0.3 else (rng.randf_range(10.0, 17.0) if form < 0.8 else rng.randf_range(7.0, 11.0))
		_legacy_mesa = false
		_skip_slice_bed = false
		var placed: float = terrain_height(x, z)
		var on_cliff: bool = _landform_changed(x, z) and terrain_slope(x, z) > 0.6
		var on_slice: bool = _on_slice(x, z, 3.0)
		_legacy_mesa = true
		_skip_slice_bed = true
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis.from_scale(Vector3(width, height, width)), Vector3(x, placed - 1.0, z)))
		var shade: float = rng.randf_range(0.8, 1.05)
		var tone: Color = FOREST_HUES[rng.randi_range(0, FOREST_HUES.size() - 1)].lerp(base_color.lerp(accent_color, rng.randf_range(0.0, 0.4)), 0.25) * shade
		# Damp valley floors lean blue-green.
		tone = tone.lerp(Color("35603a"), smoothstep(-40.0, -70.0, placed) * 0.25)
		# Leave the hero's rooted base open; filtered after every draw, so the random
		# stream (and every other clump) is unchanged.
		if on_cliff or on_slice or (not hero.is_empty() and Vector2(x, z).distance_to(Vector2(hero.base.x, hero.base.z)) < float(hero.radius) * 0.75):
			xs.pop_back()
			continue
		colors.append(tone)
	_legacy_mesa = false
	_skip_slice_bed = false
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

## Foreground corridor understory (prototype art pass; visual only). On one limited stretch of
## the walked east shore and lower root approach (UNDERSTORY_Z), the large low-poly forest clumps
## whose bodies come within UNDERSTORY_CLEAR of the path are set aside (kept, hidden, in
## CorridorReplacedCarpet) and replaced by composed groups built from the clearing's own
## understory meshes: fern crowns (scoped darker duplicates of the clearing leaf materials) with
## fairy-mushroom clusters and moss at their foot, mushroom-and-moss rings, and flower drifts,
## with open ground between groups. Each plant's mesh floor is anchored just below the lowest
## rendered surface under its footprint (ribbon shoulder, or the higher of the rendered terrain
## and the embankment skirt); nothing is placed on the tread. Creature/human-scale target
## heights. No colliders, no shadows, own random stream; startup only.
func _add_corridor_understory() -> void:
	understory_report = {"built": false}
	if not is_instance_valid(slice_route) or not slice_route.valid: return
	var sources: Dictionary = _understory_sources()
	understory_report["sources"] = sources.keys()
	if sources.size() < 8:
		understory_report["error"] = "clearing understory meshes not found"
		return
	var hero_xz := Vector2(hero.base.x, hero.base.z) if not hero.is_empty() else Vector2(INF, INF)
	var section := PackedVector3Array()
	for p: Vector3 in slice_route._p:
		if p.z < UNDERSTORY_Z.x and p.z > UNDERSTORY_Z.y: section.append(p)
	if section.size() < 10: return
	var arc := PackedFloat32Array([0.0])
	for i: int in range(1, section.size()): arc.append(arc[i - 1] + Vector2(section[i].x - section[i - 1].x, section[i].z - section[i - 1].z).length())
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector3 in section:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var bounds := Rect2(lo, hi - lo)
	# 1. Set aside the conspicuous clumps beside the path (non-destructive: kept, hidden).
	var replaced: Array[Transform3D] = []
	var replaced_colors: Array[Color] = []
	var clump_mesh: Mesh = null
	var clump_material: Material = null
	var near_kept: Array = []
	for node: GeometryInstance3D in _static:
		if not String(node.name).begins_with("ForestCarpet_"): continue
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		var keep: Array[Transform3D] = []
		var keep_colors: Array[Color] = []
		for i: int in multi.instance_count:
			var pose: Transform3D = multi.get_instance_transform(i)
			var at := Vector2(pose.origin.x, pose.origin.z)
			var width: float = pose.basis.x.length()
			if bounds.grow(UNDERSTORY_CLEAR + width).has_point(at) and _section_distance(section, at) - width * 0.45 < UNDERSTORY_CLEAR:
				replaced.append(pose)
				replaced_colors.append(multi.get_instance_color(i))
				continue
			keep.append(pose)
			keep_colors.append(multi.get_instance_color(i))
			if bounds.grow(60.0 + width).has_point(at):
				var body: float = _section_distance(section, at) - width * 0.45
				if body < 60.0: near_kept.append([snappedf(pose.origin.x, 0.1), snappedf(pose.origin.z, 0.1), snappedf(width, 0.1), snappedf(pose.basis.y.length(), 0.1), snappedf(body, 0.1)])
		if keep.size() == multi.instance_count: continue
		clump_mesh = multi.mesh
		clump_material = (node as MultiMeshInstance3D).material_override
		multi.instance_count = keep.size()
		for i: int in keep.size():
			multi.set_instance_transform(i, keep[i])
			multi.set_instance_color(i, keep_colors[i])
	# 1b. The larger clumps that still stood beside the stretch (centres within
	# CORRIDOR_TREE_REACH of the path) become layered groups of copied native trees.
	var tree_targets: Array = []
	for node: GeometryInstance3D in _static:
		if not String(node.name).begins_with("ForestCarpet_"): continue
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		var keep: Array[Transform3D] = []
		var keep_colors: Array[Color] = []
		for i: int in multi.instance_count:
			var pose: Transform3D = multi.get_instance_transform(i)
			var at := Vector2(pose.origin.x, pose.origin.z)
			if bounds.grow(CORRIDOR_TREE_REACH).has_point(at) and _section_distance(section, at) <= CORRIDOR_TREE_REACH:
				replaced.append(pose)
				replaced_colors.append(multi.get_instance_color(i))
				var rendered: AABB = pose * multi.mesh.get_aabb()
				tree_targets.append({"owner": String(node.name), "index": i, "position": [snappedf(pose.origin.x, 0.1), snappedf(pose.origin.y, 0.1), snappedf(pose.origin.z, 0.1)], "width": snappedf(maxf(rendered.size.x, rendered.size.z), 0.1), "height": snappedf(rendered.size.y, 0.1), "path_distance_m": snappedf(_section_distance(section, at), 0.1)})
				continue
			keep.append(pose)
			keep_colors.append(multi.get_instance_color(i))
		if keep.size() == multi.instance_count: continue
		clump_mesh = multi.mesh
		clump_material = (node as MultiMeshInstance3D).material_override
		multi.instance_count = keep.size()
		for i: int in keep.size():
			multi.set_instance_transform(i, keep[i])
			multi.set_instance_color(i, keep_colors[i])
	var tree_report_corridor: Dictionary = _add_corridor_trees(tree_targets)
	if not replaced.is_empty():
		var hidden := MultiMesh.new()
		hidden.transform_format = MultiMesh.TRANSFORM_3D
		hidden.use_colors = true
		hidden.mesh = clump_mesh
		hidden.instance_count = replaced.size()
		for i: int in replaced.size():
			hidden.set_instance_transform(i, replaced[i])
			hidden.set_instance_color(i, replaced_colors[i])
		replaced_carpet = MultiMeshInstance3D.new()
		replaced_carpet.name = "CorridorReplacedCarpet"
		replaced_carpet.multimesh = hidden
		replaced_carpet.material_override = clump_material
		replaced_carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		replaced_carpet.visible = false
		add_child(replaced_carpet)
	# 2. Composed groups along both verges of the limited stretch (open ground between them):
	# fern-and-fungus groups (2-3 fern crowns, a fairy-mushroom cluster at their foot, moss),
	# mushroom-and-moss groups, and flower drifts. Where the shore strip is narrow a group
	# slides toward the path (never past its clearance) instead of into the water.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261027
	var plants: Array = []
	var banks: Dictionary = {"groups": 0, "open_gaps": 0, "fern_crowns": 0, "fungal_clusters": 0, "flower_drifts": 0}
	var s: float = rng.randf_range(2.0, 5.0)
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	while s < arc[arc.size() - 1]:
		if rng.randf() < 0.12:
			banks.open_gaps += 1
			s += rng.randf_range(4.0, 7.0)
			continue
		var frame: Array = _section_frame(section, arc, s)
		var out: Vector2 = frame[2] * side
		var dry := func(lateral: float, least: float) -> float:
			var l: float = lateral
			while l > least:
				var at: Vector2 = frame[0] + out * l
				var g: float = rendered_terrain_height(at.x, at.y)
				if (g if not is_nan(g) else terrain_height(at.x, at.y)) > LAKE_Y + 0.3: return l
				l -= 0.5
			return least
		var centre: Vector2 = frame[0] + out * dry.call(rng.randf_range(4.4, 6.5) if rng.randf() < 0.7 else rng.randf_range(6.5, 10.0), 4.4)
		var scatter := func(radius: float) -> Vector2: return frame[1] * rng.randf_range(-radius, radius) * 1.4 + out * rng.randf_range(-radius, radius)
		banks.groups += 1
		var roll: float = rng.randf()
		if roll < 0.4:
			var leaf: String = "fern_dark" if rng.randf() < 0.5 else "fern_mid"
			for c: int in 2:
				banks.fern_crowns += 1
				var base: Vector2 = centre + scatter.call(1.1) + out * 0.4
				var turn: float = rng.randf_range(0.0, TAU)
				var size: float = rng.randf_range(0.55, 0.8)
				for f: int in 3:
					var angle: float = turn + TAU * f / 3.0 + rng.randf_range(-0.35, 0.35)
					var radial := Vector2(cos(angle), sin(angle))
					plants.append(["fern_a" if rng.randf() < 0.7 else "fern_c", base + radial * rng.randf_range(0.08, 0.2),
						{"height": [size * 0.85, size * 1.1], "yaw": -angle + PI * 0.5, "tilt_axis": Vector3(radial.y, 0.0, -radial.x), "tilt": deg_to_rad(rng.randf_range(4.0, 10.0)), "material": leaf}])
			banks.fungal_clusters += 1
			var foot: Vector2 = centre - out * 0.7 + scatter.call(0.4)
			for m: int in rng.randi_range(4, 7): plants.append(["fairy", foot + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 0.4, {}])
			for m: int in rng.randi_range(3, 5): plants.append(["moss", centre + scatter.call(1.4), {}])
			if rng.randf() < 0.4:
				banks.flower_drifts += 1
				var drift: Vector2 = centre - out * 1.1 + scatter.call(0.8)
				var colour: String = ["flower_pink", "flower_white", "flower_blue"][rng.randi_range(0, 2)]
				for g: int in rng.randi_range(4, 6): plants.append([colour, drift + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 0.35, {}])
		elif roll < 0.8:
			banks.fungal_clusters += 1
			var ring: float = rng.randf_range(0.6, 1.1)
			for m: int in rng.randi_range(4, 7):
				var angle: float = rng.randf_range(0.0, TAU)
				plants.append(["fairy", centre + Vector2(cos(angle), sin(angle)) * ring * rng.randf_range(0.8, 1.15), {}])
			for m: int in rng.randi_range(4, 6): plants.append(["moss", centre + scatter.call(1.0), {}])
			banks.fern_crowns += 1
			var base: Vector2 = centre + out * (ring + 0.5)
			var turn: float = rng.randf_range(0.0, TAU)
			for f: int in 3:
				var angle: float = turn + TAU * f / 3.0
				var radial := Vector2(cos(angle), sin(angle))
				plants.append(["fern_a", base + radial * 0.12, {"height": [0.4, 0.55], "yaw": -angle + PI * 0.5, "tilt_axis": Vector3(radial.y, 0.0, -radial.x), "tilt": deg_to_rad(6.0), "material": "fern_dark"}])
		else:
			banks.flower_drifts += 1
			var colour: String = ["flower_pink", "flower_white", "flower_blue"][rng.randi_range(0, 2)]
			for g: int in rng.randi_range(6, 10): plants.append([colour, centre + scatter.call(0.7), {}])
			for m: int in rng.randi_range(2, 3): plants.append(["moss", centre + scatter.call(1.0), {}])
			var tuft: Vector2 = centre + out * 0.9
			for g: int in rng.randi_range(6, 9): plants.append(["grass", tuft + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (0.07 if g > 0 else 0.0), {"height": [0.25, 0.4]}])
		s += rng.randf_range(3.0, 5.5)
		if rng.randf() < 0.6: side = -side
	# 3. Clearance, attachment and scale; then chunked multimeshes.
	var min_lateral: Dictionary = {"moss": 2.7, "cushion": 2.7, "grass": 3.0, "broadleaf": 3.0, "flower_white": 3.0, "flower_pink": 3.0, "flower_blue": 3.0, "fern_a": 3.6, "fern_b": 3.6, "fern_c": 3.6, "fairy": 3.6}
	# Target heights (m) at creature/human scale; the clearing authors these meshes as low
	# ground cover (0.07-0.34 m), which vanishes at path distances. Moss and cushions are
	# flattened into mounds (width factor).
	var heights: Dictionary = {"moss": [0.08, 0.16], "cushion": [0.12, 0.25], "grass": [0.3, 0.55], "broadleaf": [0.25, 0.45], "flower_white": [0.3, 0.5], "flower_pink": [0.3, 0.5], "flower_blue": [0.3, 0.5], "fern_a": [0.7, 1.2], "fern_b": [0.7, 1.2], "fern_c": [0.65, 1.1], "fairy": [0.25, 0.7]}
	var widen: Dictionary = {"moss": 2.6, "cushion": 2.0}
	var batches: Dictionary = {}
	var dropped: Dictionary = {}
	var closest: Dictionary = {}
	# Scoped fern materials: duplicates of the clearing's leaf materials (the originals are
	# untouched), darker for open sun because the clearing's canopy dapple does not reach the
	# corridor; their night state follows the originals (apply_look).
	var leaf_variants: Array = []
	var materials: Variant = _world.get("_materials")
	if materials is Dictionary:
		for pair: Array in [["fern_dark", "leaf_dark", Color("1d3b24"), Color("344f22")], ["fern_mid", "leaf", Color("34572a"), Color("66853a")]]:
			if not materials.has(pair[1]) or not materials[pair[1]] is ShaderMaterial: continue
			var copy: ShaderMaterial = (materials[pair[1]] as ShaderMaterial).duplicate()
			copy.set_shader_parameter("base_color", pair[2])
			copy.set_shader_parameter("accent_color", pair[3])
			copy.set_shader_parameter("roughness_value", 0.94)
			leaf_variants.append([pair[0], copy])
			_understory_sync.append([materials[pair[1]], copy])
	var attach := {"max_base_above_surface_m": -INF, "max_sink_m": 0.0, "max_bottom_corner_lift_m": 0.0, "corners_over_10cm": 0, "corners_checked": 0}
	for plant: Array in plants:
		var asset: String = plant[0]
		if not sources.has(asset): continue
		var at: Vector2 = plant[1]
		var near: Array = _section_nearest(section, arc, at)
		var off: float = near[1]
		var reason: String = ""
		if off < min_lateral[asset]: reason = "clearance"
		elif at.distance_to(hero_xz) < 47.0: reason = "root"
		var ground: float = NAN
		if reason.is_empty():
			ground = _understory_ground(section, arc, at)
			if off > 3.95:
				var rendered: float = rendered_terrain_height(at.x, at.y)
				var terrain: float = rendered if not is_nan(rendered) else terrain_height(at.x, at.y)
				if terrain < LAKE_Y + 0.25 and ground == terrain: reason = "water"
				elif terrain_slope(at.x, at.y) > 0.75 and ground == terrain: reason = "steep"
			if is_nan(ground): reason = "no ground"
		if not reason.is_empty():
			dropped[reason] = int(dropped.get(reason, 0)) + 1
			continue
		closest[asset] = minf(float(closest.get(asset, INF)), off)
		var opts: Dictionary = plant[2]
		var target: Array = opts.get("height", heights[asset])
		var k: float = rng.randf_range(target[0], target[1]) / maxf(sources[asset].mesh.get_aabb().size.y, 0.01)
		var w: float = k * float(widen.get(asset, 1.0))
		var tilt := Basis(opts.get("tilt_axis", Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()), opts.get("tilt", deg_to_rad(rng.randf_range(0.0, 5.0))))
		var basis: Basis = tilt * Basis(Vector3.UP, opts.get("yaw", rng.randf_range(0.0, TAU))) * Basis.from_scale(Vector3(w, k, w))
		var chunk: int = floori(float(near[0]) / UNDERSTORY_CHUNK)
		var variant: Array = ["", null]
		for candidate: Array in leaf_variants:
			if candidate[0] == opts.get("material", ""): variant = candidate
		var key: String = "%s%s_%d" % [asset, ("_" + variant[0]) if variant[1] != null else "", chunk]
		if not batches.has(key): batches[key] = {"asset": asset, "poses": [], "material": variant[1]}
		# Root anchor: the mesh floor (its AABB bottom, scaled) sits 2 cm below the lowest rendered
		# surface under the plant's footprint, so no side floats on a slope.
		var box: AABB = sources[asset].mesh.get_aabb()
		var reach: float = minf(0.5 * maxf(box.size.x, box.size.z) * w, 0.6)
		var lowest: float = ground
		for corner: Vector2 in [Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)]:
			var under: float = _understory_ground(section, arc, at + corner)
			if not is_nan(under): lowest = minf(lowest, under)
		var base: float = lowest - 0.02
		var pose := Transform3D(basis, Vector3(at.x, base - box.position.y * k, at.y))
		attach.max_base_above_surface_m = maxf(attach.max_base_above_surface_m, base - ground)
		attach.max_sink_m = maxf(attach.max_sink_m, ground - base)
		# Independent check: the transformed bottom corners of the mesh box against the rendered
		# surface beneath each of them (includes yaw, tilt and the mesh's own offsets).
		for cx: float in [box.position.x, box.end.x]:
			for cz: float in [box.position.z, box.end.z]:
				var corner_world: Vector3 = pose * Vector3(cx, box.position.y, cz)
				var below: float = _understory_ground(section, arc, Vector2(corner_world.x, corner_world.z))
				if is_nan(below): continue
				attach.corners_checked += 1
				attach.max_bottom_corner_lift_m = maxf(attach.max_bottom_corner_lift_m, corner_world.y - below)
				if corner_world.y - below > 0.10: attach.corners_over_10cm += 1
		batches[key].poses.append(pose)
	understory = Node3D.new()
	understory.name = "CorridorUnderstory"
	add_child(understory)
	var per_asset: Dictionary = {}
	var triangles: int = 0
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var source: Dictionary = sources[batch.asset]
		var centre := Vector3.ZERO
		for pose: Transform3D in batch.poses: centre += pose.origin
		centre /= float(batch.poses.size())
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = source.mesh
		multi.instance_count = batch.poses.size()
		for i: int in batch.poses.size(): multi.set_instance_transform(i, Transform3D(Basis(), -centre) * batch.poses[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Understory_" + key
		node.set_meta("asset", batch.asset)
		node.multimesh = multi
		node.position = centre
		node.material_override = batch.material if batch.material != null else source.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = UNDERSTORY_RANGE
		node.visibility_range_end_margin = 10.0
		understory.add_child(node)
		_static.append(node)
		per_asset[batch.asset] = int(per_asset.get(batch.asset, 0)) + batch.poses.size()
		triangles += int(source.triangles) * batch.poses.size()
	var instances: int = 0
	for asset: String in per_asset: instances += per_asset[asset]
	understory_report = {"built": true, "section_samples": section.size(), "section_length_m": arc[arc.size() - 1],
		"carpet_clumps_replaced": replaced.size(), "carpet_triangles_hidden": _triangle_count(clump_mesh) * replaced.size() if clump_mesh else 0,
		"stretch_z": [UNDERSTORY_Z.x, UNDERSTORY_Z.y], "banks": banks, "attachment": attach,
		"tree_targets": tree_targets, "corridor_trees": tree_report_corridor,
		"source_aabb": sources.keys().map(func(asset: String) -> Array: return [asset, snappedf(sources[asset].mesh.get_aabb().position.y, 0.001), snappedf(sources[asset].mesh.get_aabb().size.y, 0.001)]), "fern_materials": leaf_variants.map(func(v: Array) -> String: return v[0]), "instances": instances, "per_asset": per_asset, "triangles": triangles, "nodes": batches.size(),
		"dropped": dropped, "min_lateral_m": closest, "min_lateral_required_m": min_lateral, "draw_range_m": UNDERSTORY_RANGE,
		"sources": sources.keys(), "colliders": 0, "shadow_casters": 0,
		"source_scale": sources.keys().map(func(asset: String) -> Array: return [asset, snappedf(sources[asset].scale.x, 0.01), snappedf(sources[asset].scale.y, 0.01)]),
		"near_kept_clumps": near_kept, "target_height_m": heights,
		"source_height_m": sources.keys().map(func(asset: String) -> Array: return [asset, snappedf(sources[asset].mesh.get_aabb().size.y * sources[asset].scale.y, 0.01)])}

## Layered copied-tree groups in place of the targeted clumps (rendered size): one tree for a
## narrow clump, two for a medium one, three lower ones for a wide flat one; the main tree is
## scaled toward the clump's height, companions to 55-80 % of it. Trunks root 0.35 m into the
## rendered ground. Crowns keep the native ring crown (restrained far tone) at every distance:
## the dense near crowns would add ~7,400 triangles per crown for trees 70-115 m off the path.
func _add_corridor_trees(targets: Array) -> Dictionary:
	if targets.is_empty() or _tree_templates.is_empty(): return {"trees": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261028
	var heights: Array = []
	for template: Array in _tree_templates:
		var top: float = 0.0
		for part: Dictionary in template: top = maxf(top, (part.local * (part.mesh as Mesh).get_aabb()).end.y)
		heights.append(maxf(top, 1.0))
	var batches: Dictionary = {}
	var trees: int = 0
	var crowns: int = 0
	for target: Dictionary in targets:
		var width: float = target.width
		var count: int = 1 if width < 25.0 else (2 if width < 40.0 else 3)
		var centre := Vector2(target.position[0], target.position[2])
		for n: int in count:
			var pick: int = rng.randi_range(0, _tree_templates.size() - 1)
			var template: Array = _tree_templates[pick]
			var want: float = float(target.height) * (rng.randf_range(0.85, 1.05) if n == 0 else rng.randf_range(0.55, 0.8))
			if count == 3: want = minf(want, 12.0)
			var size: float = clampf(want / float(heights[pick]), 0.7, 2.6)
			var spot: Vector2 = centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * (0.0 if n == 0 else rng.randf_range(0.2, 0.35) * width)
			var ground: float = rendered_terrain_height(spot.x, spot.y)
			if is_nan(ground): ground = terrain_height(spot.x, spot.y)
			if ground < LAKE_Y + 1.0 or terrain_slope(spot.x, spot.y) > 0.6: continue
			var root := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * size), Vector3(spot.x, ground - 0.35, spot.y))
			var cell := Vector2i(floori(spot.x / 160.0), floori(spot.y / 160.0))
			trees += 1
			for part: Dictionary in template:
				var tone: Material = _near_crown.far_material if part.kind == "LayeredCanopies" and not _near_crown.is_empty() else part.material
				if part.kind == "LayeredCanopies": crowns += 1
				_tree_batch(batches, part.kind, part.mesh, tone, cell, "all", root * part.local)
	var built: Dictionary = {"all": 0, "far": 0, "near": 0}
	for key: String in batches:
		var node: MultiMeshInstance3D = _tree_node(batches[key], "CorridorTrees_")
		corridor_trees.append(node)
		built[batches[key].range] += _triangle_count(batches[key].mesh) * node.multimesh.instance_count
	return {"trees": trees, "targets": targets.size(), "ring_crowns": crowns, "nodes": batches.size(), "triangles": built.all + built.far + built.near}

## The clearing's own understory meshes and materials (SpatiallyChunkedFoliage), with each
## asset's median authored scale so the corridor plants match the clearing's scale.
func _understory_sources() -> Dictionary:
	var foliage: Node = _world.get_node_or_null("SpatiallyChunkedFoliage")
	if foliage == null: return {}
	# asset: [node-name prefix, mesh resource name, triangles] (empty / 0 = not used to match)
	var wanted: Dictionary = {"fern_a": ["", "Review09Understory_fern_a", 0], "fern_b": ["", "Review09Understory_fern_b", 0],
		"fern_c": ["leaf_dark_-", "", 780], "grass": ["leaf_-", "", 18], "cushion": ["", "Review09Understory_cushion_b", 0],
		"moss": ["", "Review18Clump_cushion_a", 0], "broadleaf": ["", "Review09Understory_broadleaf_a", 0],
		"flower_white": ["flower_white_-", "", 94], "flower_pink": ["flower_pink_-", "", 94],
		"flower_blue": ["flower_blue_-", "", 94], "fairy": ["fairy_-", "", 120]}
	var found: Dictionary = {}
	var scales: Dictionary = {}
	for node: Node in foliage.get_children():
		var instance: MultiMeshInstance3D = node as MultiMeshInstance3D
		if instance == null or instance.multimesh == null or instance.multimesh.mesh == null: continue
		var mesh: Mesh = instance.multimesh.mesh
		for asset: String in wanted:
			var rule: Array = wanted[asset]
			if not String(rule[0]).is_empty() and not String(instance.name).begins_with(rule[0]): continue
			if not String(rule[1]).is_empty() and mesh.resource_name != rule[1]: continue
			var tris: int = _triangle_count(mesh)
			if int(rule[2]) > 0 and tris != int(rule[2]): continue
			if not found.has(asset): found[asset] = {"mesh": mesh, "material": instance.material_override, "triangles": tris}
			if found[asset].mesh != mesh: continue
			if not scales.has(asset): scales[asset] = []
			for i: int in mini(instance.multimesh.instance_count, 24): scales[asset].append(instance.multimesh.get_instance_transform(i).basis.get_scale())
	for asset: String in found:
		var list: Array = scales.get(asset, [])
		list.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
		found[asset]["scale"] = list[list.size() / 2] if not list.is_empty() else Vector3.ONE
	return found

func _section_distance(section: PackedVector3Array, at: Vector2) -> float:
	var best: float = INF
	for i: int in range(1, section.size()):
		best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, Vector2(section[i - 1].x, section[i - 1].z), Vector2(section[i].x, section[i].z))))
	return best

## Visible ground under a corridor plant: the ribbon surface on the shoulders, beyond them the
## higher of the rendered terrain and the embankment skirt.
func _understory_ground(section: PackedVector3Array, arc: PackedFloat32Array, at: Vector2) -> float:
	var near: Array = _section_nearest(section, arc, at)
	if float(near[1]) <= 3.95:
		var shoulder: float = slice_route.surface_height_at(at.x, at.y)
		if not is_nan(shoulder): return shoulder
	var rendered: float = rendered_terrain_height(at.x, at.y)
	var terrain: float = rendered if not is_nan(rendered) else terrain_height(at.x, at.y)
	return maxf(terrain, float(near[2]) - 2.2 * tan(deg_to_rad(18.0)) - (float(near[1]) - 4.0) / 0.7)

## [arc length, lateral distance, centreline height] of the nearest point on the section.
func _section_nearest(section: PackedVector3Array, arc: PackedFloat32Array, at: Vector2) -> Array:
	var best: Array = [0.0, INF, 0.0]
	for i: int in range(1, section.size()):
		var a := Vector2(section[i - 1].x, section[i - 1].z)
		var b := Vector2(section[i].x, section[i].z)
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(at, a, b)
		var d: float = at.distance_to(q)
		if d < best[1]:
			var t: float = a.distance_to(q) / maxf(a.distance_to(b), 0.001)
			best = [lerpf(arc[i - 1], arc[i], t), d, lerpf(section[i - 1].y, section[i].y, t)]
	return best

## [point, tangent, right] on the section at arc length s (XZ).
func _section_frame(section: PackedVector3Array, arc: PackedFloat32Array, s: float) -> Array:
	var i: int = 1
	while i < arc.size() - 1 and arc[i] < s: i += 1
	var a := Vector2(section[i - 1].x, section[i - 1].z)
	var b := Vector2(section[i].x, section[i].z)
	var t: float = clampf((s - arc[i - 1]) / maxf(arc[i] - arc[i - 1], 0.001), 0.0, 1.0)
	var tangent: Vector2 = (b - a).normalized()
	return [a.lerp(b, t), tangent, Vector2(-tangent.y, tangent.x)]

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
# Eroded rock stack: a few uneven lips at irregular heights, a cross-section that shifts
# with height (lathe "pillar" style), a slight lean and a rounded, uneven crown.
func _pillar_mesh() -> ArrayMesh:
	var profile: Array[Vector3] = []
	var lips: Array[Vector2] = [Vector2(0.16, 0.07), Vector2(0.33, 0.04), Vector2(0.41, 0.08), Vector2(0.58, 0.05), Vector2(0.74, 0.06), Vector2(0.87, 0.04)]
	var rows := 40
	for i: int in rows + 1:
		var t: float = float(i) / rows
		var radius: float = lerpf(1.0, 0.56, pow(t, 0.9))
		for lip: Vector2 in lips:
			radius += lip.y * smoothstep(lip.x - 0.06, lip.x - 0.008, t) * (1.0 - smoothstep(lip.x - 0.008, lip.x + 0.004, t))
		radius *= sqrt(1.0 - smoothstep(0.93, 1.0, t) * 0.85)
		profile.append(Vector3(radius, t, t))
	profile.append(Vector3(0.0, 1.015, 1.0))
	return _lathe(profile, 32, "pillar", false)

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
					# Cross-section drifts with height, so faces are not repeated bands.
					radius *= 1.0 + 0.12 * sin(3.0 * a + 2.3 * p.z + 0.4) + 0.08 * sin(5.0 * a - 1.7 * p.z + 1.1) + 0.05 * sin(8.0 * a + 3.1 * p.z)
				"crag":
					var f: PackedFloat32Array = phases
					radius *= 1.0 + 0.2 * sin(3.0 * a + f[0] + 2.1 * p.z) + 0.11 * sin(5.0 * a + f[1] - 1.4 * p.z) + 0.15 * (absf(sin(7.0 * a + f[2] + 0.6 * p.z)) - 0.64) + 0.06 * sin(13.0 * a + f[0] * 2.0)
					height += smoothstep(0.82, 1.0, p.z) * 0.035 * sin(5.0 * a + f[2])
				"boulder":
					radius *= 1.0 + 0.14 * sin(3.0 * a + 0.4) + 0.07 * sin(7.0 * a + 1.9)
				"blob":
					radius *= 1.0 + 0.16 * sin(3.0 * a + 0.8)
			st.set_uv(Vector2(u, p.z))
			# Godot multiplies vertex colour into the MultiMesh instance colour: keep it white,
			# except the stem's green channel, which carries groove depth for shading.
			st.set_color(Color(1, cavity, 1))
			var bend: float = STEM_BEND * p.z * p.z if style == "stem" else (0.15 * p.z * p.z if style == "pillar" else 0.0)
			var bend_z: float = 0.0
			if style == "crag":
				bend = phases[3] * p.z * p.z
				bend_z = phases[4] * p.z * p.z
			st.add_vertex(Vector3(cos(a) * radius + bend, height, sin(a) * radius + bend_z))
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
	# Worn-earth track on the tread fading into the far terrain's moss on the shoulders and
	# skirts (shared by the slice). Visual only: geometry and collision are unchanged.
	var earth := ShaderMaterial.new()
	earth.shader = PATH_SHADER
	earth.set_shader_parameter("moss_tex", MOSS_TEXTURE)
	earth.set_shader_parameter("rock_tex", ROCK_TEXTURE)
	earth.set_shader_parameter("moss_mean", _moss_mean)
	earth.set_shader_parameter("clearing_rect", Vector4(baked_extent.position.x, baked_extent.position.y, baked_extent.end.x, baked_extent.end.y))
	earth.set_shader_parameter("clearing_gain", Vector3(CLEARING_GAIN.r, CLEARING_GAIN.g, CLEARING_GAIN.b))
	earth.set_shader_parameter("total_width", 3.6 + 2.0 * 2.2)
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

## Slice centreline: Catmull-Rom through the waypoints every 6.5 m, from the existing
## route's end; tread heights follow natural ground within SLICE_GRADE using a backward
## then forward clamp (start pinned to the junction height, so the join is flush).
func _plan_slice(start: Vector3) -> PackedVector3Array:
	var heading: Vector3 = route.get_end_direction()
	# Two collinear points keep the first stretch straight, so the slice's first ring has
	# exactly the existing route's end heading (no wedge gap or overlap at the seam).
	var way: Array[Vector2] = [Vector2(start.x, start.z), Vector2(start.x + heading.x * 5.0, start.z + heading.z * 5.0), Vector2(start.x + heading.x * 11.0, start.z + heading.z * 11.0)]
	way.append_array(SLICE_WAYPOINTS)
	var curve := Curve2D.new()
	for i: int in way.size():
		var tangent: Vector2 = (way[mini(i + 1, way.size() - 1)] - way[maxi(i - 1, 0)]) * 0.5
		curve.add_point(way[i], -tangent / 3.0, tangent / 3.0)
	curve.bake_interval = 0.5
	var length: float = curve.get_baked_length()
	var count: int = int(ceil(length / 6.5))
	var flat := PackedVector2Array()
	for k: int in count + 1: flat.append(curve.sample_baked(minf(length, float(k) * length / count)))
	var heights := PackedFloat32Array()
	heights.resize(flat.size())
	for k: int in flat.size(): heights[k] = terrain_height(flat[k].x, flat[k].y) + 0.06
	heights[0] = start.y
	var caps := PackedFloat32Array()
	caps.resize(flat.size())
	caps.fill(SLICE_GRADE)
	var turns: int = 0
	for k: int in range(1, flat.size() - 1):
		var turn: float = absf((flat[k] - flat[k - 1]).angle_to(flat[k + 1] - flat[k]))
		if turn > 0.0001 and flat[k - 1].distance_to(flat[k + 1]) * 0.5 / turn < SLICE_TURN_RADIUS:
			caps[k] = SLICE_TURN_GRADE
			turns += 1
	for k: int in range(flat.size() - 2, 0, -1):
		var run: float = flat[k].distance_to(flat[k + 1])
		var grade: float = minf(caps[k], caps[k + 1])
		heights[k] = clampf(heights[k], heights[k + 1] - grade * run, heights[k + 1] + grade * run)
	for k: int in range(1, flat.size()):
		var run: float = flat[k].distance_to(flat[k - 1])
		var grade: float = minf(caps[k], caps[k - 1])
		heights[k] = clampf(heights[k], heights[k - 1] - grade * run, heights[k - 1] + grade * run)
	slice_report["turn_capped_points"] = turns
	var points := PackedVector3Array()
	var cut: float = 0.0
	var fill: float = 0.0
	for k: int in flat.size():
		points.append(Vector3(flat[k].x, heights[k], flat[k].y))
		var natural: float = terrain_height(flat[k].x, flat[k].y) + 0.06
		cut = maxf(cut, natural - heights[k])
		fill = maxf(fill, heights[k] - natural)
	slice_report["planned_points"] = points.size()
	slice_report["planned_length_m"] = length
	slice_report["planned_max_cut_m"] = cut
	slice_report["planned_max_fill_m"] = fill
	return points

func _add_slice_route() -> void:
	if not is_instance_valid(route) or not route.valid:
		slice_report["error"] = "existing route missing; slice not built"
		return
	var start: Vector3 = route.get_end_point()
	var points: PackedVector3Array = _plan_slice(start)
	slice_route = Route.new()
	slice_route.name = "SliceRoute"
	add_child(slice_route)
	var earth: Material = route._mesh_instance.material_override if is_instance_valid(route._mesh_instance) else null
	# 2.5 m samples keep the ~1.45 km ribbon under the module's 1,200-sample limit.
	# The slice's first ring coincides with the existing route's last ring: same point, height,
	# heading and falling-shoulder profile (taper_length 0). join_overlap 0: a flat overlap
	# on the existing route's 11 degree climb left a 4-6 cm lip that stopped the walker.
	# start_direction squares the first ring to the existing route's end; without it the
	# curve's first segment bent ~1.8 deg toward the summit loop and left a 12 cm wedge.
	var built: bool = slice_route.configure({"centerline": points, "tread_width": 3.6, "shoulder_width": 2.2, "max_grade_deg": 14.0, "sample_spacing": 2.5, "taper_length": 0.0, "join_overlap": 0.0, "start_direction": route.get_end_direction(),
		"exclusion_rects": [Rect2(-24.0, -24.0, 49.0, 53.0)], "ground_height": Callable(self, "terrain_height"), "material": earth})
	var report: Dictionary = slice_route.get_report()
	report.merge(slice_report, true)
	report.erase("profile_x_z_raw_soil_tread")
	slice_report = report
	if not built: return
	# The trail bed follows the ribbon's own samples, so the ground meets what is drawn.
	_slice_bed = slice_route._p.duplicate()
	_slice_box = Rect2(Vector2(_slice_bed[0].x, _slice_bed[0].z), Vector2.ZERO)
	for point: Vector3 in _slice_bed: _slice_box = _slice_box.expand(Vector2(point.x, point.z))
	_slice_box = _slice_box.grow(SLICE_BED_BLEND + 2.0)
	for i: int in _slice_bed.size() - 1:
		var seg := Rect2(Vector2(_slice_bed[i].x, _slice_bed[i].z), Vector2.ZERO).expand(Vector2(_slice_bed[i + 1].x, _slice_bed[i + 1].z)).grow(SLICE_BED_BLEND)
		for bx: int in range(floori(seg.position.x / SLICE_BUCKET), floori(seg.end.x / SLICE_BUCKET) + 1):
			for bz: int in range(floori(seg.position.y / SLICE_BUCKET), floori(seg.end.y / SLICE_BUCKET) + 1):
				var key := Vector2i(bx, bz)
				if not _slice_buckets.has(key): _slice_buckets[key] = PackedInt32Array()
				var list: PackedInt32Array = _slice_buckets[key]
				list.append(i)
				_slice_buckets[key] = list

## Natural boundary at the slice's end: the hero stem's own rendered triangles around
## ground level become one static concave collider, so the walker stops at the root.
func _add_root_collision() -> void:
	var stems: MultiMeshInstance3D = null
	for node: MultiMeshInstance3D in _nodes:
		if String(node.name) == "CanopyStems": stems = node
	if stems == null or hero.is_empty(): return
	var pose: Transform3D = stems.global_transform * stems.multimesh.get_instance_transform(0)
	var ground: float = float(hero.ground)
	var faces: PackedVector3Array = stems.multimesh.mesh.get_faces()
	var band := PackedVector3Array()
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = pose * faces[i]
		var b: Vector3 = pose * faces[i + 1]
		var c: Vector3 = pose * faces[i + 2]
		if minf(a.y, minf(b.y, c.y)) > ground + 12.0 or maxf(a.y, maxf(b.y, c.y)) < ground - 6.0: continue
		band.append(a); band.append(b); band.append(c)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(band)
	root_body = StaticBody3D.new()
	root_body.name = "HeroRootCollision"
	root_body.collision_layer = 1
	root_body.collision_mask = 0
	root_body.set_meta("unsafe_support", true)
	var holder := CollisionShape3D.new()
	holder.shape = shape
	root_body.add_child(holder)
	add_child(root_body)
	root_collision_triangles = band.size() / 3

## Rendered terrain height at x,z from the actual terrain/patch mesh triangles near the
## routes (lazy, for verification only; not used by gameplay).
func rendered_terrain_height(x: float, z: float) -> float:
	if _rendered_faces.is_empty():
		var region: Rect2 = _slice_box.merge(_route_box) if _slice_box.size != Vector2.ZERO else _route_box
		for name: String in ["WorldTerrain", "CliffDetailPatch", "SliceDetailPatch"]:
			var node: MeshInstance3D = get_node_or_null(name)
			if node == null: continue
			var faces: PackedVector3Array = node.mesh.get_faces()
			for i: int in range(0, faces.size(), 3):
				var tri := Rect2(Vector2(faces[i].x, faces[i].z), Vector2.ZERO).expand(Vector2(faces[i + 1].x, faces[i + 1].z)).expand(Vector2(faces[i + 2].x, faces[i + 2].z))
				if not tri.intersects(region.grow(40.0)): continue
				var index: int = _rendered_faces.size() / 3
				_rendered_faces.append(faces[i]); _rendered_faces.append(faces[i + 1]); _rendered_faces.append(faces[i + 2])
				for bx: int in range(floori(tri.position.x / 8.0), floori(tri.end.x / 8.0) + 1):
					for bz: int in range(floori(tri.position.y / 8.0), floori(tri.end.y / 8.0) + 1):
						var key := Vector2i(bx, bz)
						if not _rendered_buckets.has(key): _rendered_buckets[key] = PackedInt32Array()
						var list: PackedInt32Array = _rendered_buckets[key]
						list.append(index)
						_rendered_buckets[key] = list
	var best: float = NAN
	var key := Vector2i(floori(x / 8.0), floori(z / 8.0))
	if not _rendered_buckets.has(key): return best
	for t: int in _rendered_buckets[key]:
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(x, 1000.0, z), Vector3.DOWN, _rendered_faces[t * 3], _rendered_faces[t * 3 + 1], _rendered_faces[t * 3 + 2])
		if hit is Vector3 and (is_nan(best) or (hit as Vector3).y > best): best = (hit as Vector3).y
	return best

## Movement-only extension used by the player: the exact route corridor, or the short
## approach strip over baked collider ground between the old movement box (z 26) and the
## seam (z 29). Saves and teleports do NOT use this; they keep the original box.
func allows_movement(point: Vector3) -> bool:
	if not is_instance_valid(route) or not route.valid or not point.is_finite(): return false
	if _approach.has_point(Vector2(point.x, point.z)) and point.y > -1.0 and point.y < 4.0: return true
	if is_instance_valid(slice_route) and slice_route.valid and slice_route.is_in_corridor(point): return true
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
	for pair: Array in _crown_sync:
		for key: String in ["wind_time", "wind_displacement_m", "night_amount"]:
			(pair[1] as ShaderMaterial).set_shader_parameter(key, (pair[0] as ShaderMaterial).get_shader_parameter(key))
	for pair: Array in _understory_sync:
		(pair[1] as ShaderMaterial).set_shader_parameter("night_amount", (pair[0] as ShaderMaterial).get_shader_parameter("night_amount"))
	var day: Dictionary = DEPTH_LOOK if look_depth else {"sun": DAY_SUN, "ambient": Color("d2d0ca"), "fog": Color("a2b3d4"), "sky_top": Color("41529f"), "sky_horizon": Color("f4c49a"), "lake_horizon": Color("f2b08e")}
	_lake_material.set_shader_parameter("horizon", (day.lake_horizon as Color).lerp(Color("3a3466"), night))
	for material: ShaderMaterial in _art + [_terrain_material, _lake_material]:
		material.set_shader_parameter("night", night)
		material.set_shader_parameter("rain", rain)
		material.set_shader_parameter("sun_dir", toward_sun)
	sun.light_color = (day.sun as Color).lerp(NIGHT_SUN, night).lerp(Color("ffa86a"), sunset * 0.5)
	sun.light_energy = lerpf(1.55, 0.60, night) * lerpf(1.0, 0.65, rain)
	sun.rotation_degrees.x = lerpf(-22.0, -27.45, night)
	sun.rotation_degrees.y = lerpf(130.0, 153.79, night)
	sun.light_angular_distance = 2.2
	# Tonal hierarchy: neutral-cool ambient and haze; the warm sun keeps the foreground warm.
	environment.ambient_light_color = (day.ambient as Color).lerp(Color("8f90c8"), night)
	environment.ambient_light_energy = 0.32
	environment.fog_enabled = not _debug_colors
	environment.fog_light_color = (day.fog as Color).lerp(Color("2f2b5a"), night).lerp(Color("9c97b4"), rain * 0.5)
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	# Middle distance keeps contrast; fog rises steeply toward the far horizon.
	environment.fog_depth_begin = 200.0
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.8
	environment.fog_density = (0.14 if _overview else lerpf(0.5, 0.8, rain))
	environment.fog_aerial_perspective = 0.15
	environment.fog_sun_scatter = 0.1
	environment.fog_sky_affect = 0.0
	var sky: ShaderMaterial = _world.get("_cloud_sky_material")
	if sky != null:
		# Less pink: a bluer top and a golden (not peach-pink) horizon, so their blend
		# reads violet-to-gold rather than one pink wash.
		sky.set_shader_parameter("top_color", (day.sky_top as Color).lerp(Color("141a44"), night).lerp(Color("5d5f86"), rain * 0.4))
		sky.set_shader_parameter("horizon_color", (day.sky_horizon as Color).lerp(Color("3a3466"), night).lerp(Color("a79aa8"), rain * 0.4))

func get_report() -> Dictionary:
	# Owned colliders: the two walking ribbons and the hero root; the far layer itself has none.
	var owned: int = int(route_report.get("colliders", 0)) + int(slice_report.get("colliders", 0)) + (1 if is_instance_valid(root_body) else 0)
	var colliders: int = find_children("*", "CollisionObject3D", true, false).size() - owned
	var shadows: int = 0
	for node: GeometryInstance3D in _nodes + _static:
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadows += 1
	var winding_ok: bool = float(winding_checks.get("terrain_centre_normal_y", -1.0)) > 0.0 and float(winding_checks.get("cap_top_normal_y", -1.0)) > 0.0 and bool(winding_checks.get("stem_side_normal_outward", false))
	var footing_ok: bool = float(landform_checks.get("giant_footing_drift_m", INF)) <= FOOTING_TOLERANCE
	return {"passed": colliders == 0 and shadows == 0 and winding_ok and footing_ok, "footing_ok": footing_ok, "trees": tree_report, "moss_mean": _moss_mean.to_html(false), "winding_checks": winding_checks, "winding_ok": winding_ok, "colliders": colliders, "shadow_casters": shadows, "canopies": canopy_count, "grounded_stems": grounded_stems, "rocks": rock_count, "forest_clumps": carpet_count, "forest_chunks": carpet_chunks, "rock_spire_triangles": rock_triangles, "depth_look": {"enabled": look_depth, "day_endpoints": DEPTH_LOOK, "scope": "prototype apply_look only; night/rain endpoints, fog density and distances unchanged"}, "stem_finish": {"focus_radius_m": STEM_FOCUS_RADIUS, "strength": STEM_ORGANIC, "owner": "CanopyStems (shared far_canopy mode 1, hero-masked)"}, "rock_readability": {"region_xz": [_detail_region.position.x, _detail_region.position.y, _detail_region.end.x, _detail_region.end.y], "values": ROCK_READABILITY, "owner": "CliffDetailPatch (shared terrain shader, region-masked)"}, "leaf_materials_restrained": leaf_materials_restrained, "stem_buttresses": "5 lobes integrated into the stem surface", "slice": slice_report, "slice_patch_triangles": slice_patch_triangles, "root_collision_triangles": root_collision_triangles, "owned_colliders": owned, "detail_patch_triangles": detail_patch_triangles, "coarse_cells_replaced": detail_cells_replaced, "landform_checks": landform_checks, "diagnostic_skips": diagnostic_skips, "terrain_triangles": terrain_triangles, "carpet_triangles": carpet_triangles, "understory": understory_report, "draw_nodes": _nodes.size() + _static.size(), "baked_extent_xz": [baked_extent.position.x, baked_extent.position.y, baked_extent.end.x, baked_extent.end.y], "far_plane": FAR_PLANE, "fog_end": FOG_END, "built_at_startup_only": true, "route": route_report, "traversable": "existing route + connected slice corridors only", "scope": "Far terrain, giants, pillars and carpet are a non-colliding visual blockout. Collision: the NaturalRoute and SliceRoute ribbons and the hero root band."}
