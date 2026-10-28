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
## Lake surface in use (vertical-depth colour, screen-space reflection, soft shore contact);
## WATER_SHADER is kept as the previous look for same-frame before/after evidence.
const LAKE_SHADER := preload("res://assets/world/lake_water.gdshader")
var lake_water: bool = true
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
const FOG_END := 1900.0
## Prototype atmosphere (depth fog, prototype mode only). The previous profile (begin 200, end
## 1400, curve 1.8, density 0.5 / 0.8 in rain) was measured to lift and flatten the West Wall at
## 0.3-1.2 km (docs/VERIFICATION.md). This profile keeps near and mid distance clearer and
## reaches about the same far haze (~0.46-0.55 beyond 1.4 km); fog colour, aerial perspective,
## 2026-10-26 (review 03): end 1900 (was 1600), curve 3.2 (2.6), density 0.45 (0.55), so the walls at
## 1-2 km keep their shadow sides and streaks (vista far block p5-p95 60-70 -> 47-65 L*) while the
## haze still rises toward the far plane; the valley mist carries the depth layering. Rain unchanged.
## night and the overview are unchanged. Rain blends every parameter back to the previous
## profile (full rain = previous rain fog), since the clearer profile removed rain's mid haze.
const FOG_BEGIN := 320.0
const FOG_CURVE := 3.2
const FOG_DENSITY := 0.45
## Capture-only: render the previous fog profile for same-frame evidence.
var atmosphere_previous: bool = false
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
## Dithered per-tree crossfade between the dense near crown and the ring far crown, replacing the
## instant swap at NEAR_CROWN_RANGE +- NEAR_CROWN_MARGIN (seen at 94-96 m approaching, 118-120 m
## retreating). The band brackets the old switch distances.
const LOD_FADE_START := 96.0
const LOD_FADE_END := 116.0
var lod_crossfade: bool = false
var _lod_materials: Dictionary = {"near": [], "far": []}
const FOREST_HUES: Array[Color] = [Color("2f5a2a"), Color("3f6e2e"), Color("5a7a30"), Color("5d6b2c"), Color("2a4a2c")]
const VALLEY_DIR := Vector2(0.447, -0.894)
const LAKE_CENTER := Vector2(190.0, -330.0)
const LAKE_Y := -82.0
## Southern overlook knoll and the walkable route that climbs to it from the baked
## collider seam. The original collision box is x -24..25, z -24..29; the player's
## original movement box ends at z 26, so a short explicit approach strip joins them.
const KNOLL := Vector2(72.0, 215.0)
## Geology landmark: the West Wall and Falls, one continuous granite escarpment. Toe line
## (x, relief above WALL_FLOOR in metres, z) from the western hills north past the lake, then
## east as the valley's headwall; the face looks into the valley (normal = (-dir.z, dir.x)).
## Non-colliding far layer; out of reach of the route.
## Unequal masses: a low southern end, the prow tower, a saddle, the falls notch, and the
## highest, snow-capped headwall to the north.
const WALL_TOE: Array[Vector3] = [Vector3(-520.0, 0.0, 60.0), Vector3(-600.0, 200.0, -180.0), Vector3(-660.0, 520.0, -420.0), Vector3(-660.0, 650.0, -640.0), Vector3(-600.0, 400.0, -860.0), Vector3(-460.0, 540.0, -1060.0), Vector3(-220.0, 700.0, -1220.0), Vector3(80.0, 620.0, -1330.0), Vector3(360.0, 520.0, -1400.0), Vector3(560.0, 120.0, -1420.0), Vector3(700.0, 0.0, -1380.0)]
const WALL_FLOOR := -80.0
const WALL_STEP := 8.0
const WALL_BATTER := 0.10
## Metres along the toe: the prow, the falls' hanging-valley notch (depth, half-width) and the dome.
## The falls sit on the sunlit east face, in clear sight from the east shore and the knoll.
const WALL_PROW_S := 760.0
const WALL_FALLS_S := 520.0
const WALL_NOTCH := Vector2(55.0, 75.0)
## Alpine ice: snow on up-facing rock above this height; the ice peak behind the notch
## (offset behind the toe, summit height, base radius) feeds the ice tongue.
const SNOWLINE := 520.0
const ICE_PEAK := Vector3(-600.0, 950.0, 480.0)
const HANGING_GLACIER := true
const WALL_DOME_S := 1560.0
const GRANITE_SHADER := preload("res://assets/world/prototype_granite.gdshader")
const FALLS_SHADER := preload("res://assets/world/prototype_falls.gdshader")
const ICE_SHADER := preload("res://assets/world/prototype_ice.gdshader")
const Horn := preload("res://scripts/prototype_horn.gd")
const MIST_SHADER := preload("res://assets/world/prototype_mist.gdshader")
const SKYGLOW_SHADER := preload("res://assets/world/prototype_skyglow.gdshader")
const TENDRIL_SHADER := preload("res://assets/world/prototype_tendril.gdshader")
var tendril_report: Dictionary = {}
## Golden-hour sky glow dome (camera-following, additive, inside the far plane).
const SKYGLOW_RADIUS := 2350.0
## Valley mist banks: lowland below this height (m), shader strength.
const VALLEY_MIST_TOP := -45.0
const VALLEY_MIST_STRENGTH := 0.42
var _skyglow: MeshInstance3D
var _skyglow_material: ShaderMaterial
const Erratics := preload("res://scripts/prototype_erratics.gd")
const Forest := preload("res://scripts/prototype_forest.gd")
## Distant forest: tree forms instead of the three-lobe "gumdrop" clump (FOREST_TREES false restores it).
const FOREST_TREES := true
## Glacial erratics: clustered angular granite blocks on the open slopes of the lake basin and the
## vista's near field (the open meadows read as plain lawn). Visual only (no collision, no
## shadows), kept off the walking ribbons, the stream, the lake, the clearing and the giants.
const ERRATIC_REGION := Rect2(-420.0, -720.0, 860.0, 900.0)
const ERRATIC_CELL := 26.0
## Vista review camera (geology "vista" view; off the walking ribbons, ~120 m east of the slice).
const VISTA_EYE := Vector2(350.0, 100.0)
const VISTA_AIM := Vector2(-300.0, -760.0)
## Hand-placed blocks where the vista frame's lower-left sees the ground (the camera stands at
## the top of a steep drop): [screen x, screen y in -1..1 (y up), size m]; vertical FOV 60, 16:9,
## eye 1.7 m above the rendered ground, as in the geology vista view.
const ERRATIC_ANCHORS: Array = [[-0.62, -0.74, 8.0], [-0.84, -0.6, 4.5], [-0.45, -0.88, 3.2], [-0.74, -0.9, 2.4], [-0.3, -0.82, 2.0]]
var erratic_report: Dictionary = {}
## Vista grove: [screen x, screen y (y up), cap radius m], clustered on the plateau in the frame's lower-left.
## Horizon giants (concepts: vast umbrella canopies rising beyond the cliffs): [x, z, cap radius,
## underside height above y = 0]; outside the walkable world, behind the far walls, hazed by the
## depth fog. Visual only; separate from GIANTS (their footings and checks are unchanged).
const HORIZON_GIANTS: Array = [[-260.0, -1820.0, 330.0, 700.0], [330.0, -1960.0, 230.0, 560.0], [-980.0, -1380.0, 270.0, 620.0], [760.0, -1760.0, 190.0, 470.0], [-760.0, -2050.0, 210.0, 520.0]]
var horizon_giants_report: Dictionary = {}
const VISTA_GROVE: Array = [[-0.36, -0.24, 22.0], [-0.27, -0.29, 14.0], [-0.20, -0.21, 18.0], [-0.31, -0.18, 11.0], [-0.46, -0.27, 9.0]]
var vista_grove_report: Dictionary = {}
## Vista refuge (the Gemini goal frame of 2026-10-27): a lived-in foreground in the vista's lower left
## from CC0 Quaternius models (assets/licenses/QUATERNIUS-*.txt). Visual only: shadows off, no collision.
const VISTA_REFUGE := true
const QN := "res://assets/world/models/quaternius_nature/"
const QV := "res://assets/world/models/quaternius_village/"
var vista_refuge_report: Dictionary = {}
var _model_cache: Dictionary = {}
var _refuge_glow: Array[StandardMaterial3D] = []
var _refuge_mats: Array[StandardMaterial3D] = []
var _refuge_mat_cache: Dictionary = {}
var _refuge_lights: Array[OmniLight3D] = []
var _refuge_lamp_material: StandardMaterial3D
var _refuge_props: Array[ShaderMaterial] = []
const TRIPO_SHADER := preload("res://assets/world/tripo_prop.gdshader")
var refuge_home: Vector3 = Vector3.INF
var refuge_facing: float = 0.0
var refuge_lanterns: Array[Vector3] = []
## Image-to-3D cottage and lantern (Tripo Studio, from Gemini references); procedural stand-ins until present.
const COTTAGE_MODEL := "res://assets/world/models/tripo/mush_cottage.glb"
const LANTERN_MODEL := "res://assets/world/models/tripo/lantern_post.glb"
const FLOWER_MODEL := "res://assets/world/models/tripo/glow_flowers.glb"
const COTTAGE_HEIGHT := 11.0
const LANTERN_HEIGHT := 2.6
var far_falls_report: Dictionary = {}
var _ribbon_hash: Dictionary = {}
const PEAK_HORN := true
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
## Key light (2026-10-26): ffbc72 (blue/red 0.45) dominated every hue: grey granite read as
## orange clay and the lavender caps (albedo 0.70, 0.52, 0.72) as burgundy fly agarics. A warm
## but less saturated key plus a stronger cool sky fill keeps the golden light and lets local
## colours (granite grey, lavender caps, greens) survive; shadows go blue instead of brown.
## Review round 2: ffd6a6/c4d0e8 overshot (side-view wall R-B fell 86 -> 43 while L* rose: no
## day frame read warm, shadow sides went lighter and bluer). Middle ground: ffcc90 / c8ccdc.
## Golden hour (2026-10-27, toward the concepts): a low (11 degrees), warm sun BEHIND the valley as
## seen from the hero views (azimuth 200: north-north-west), lavender fill, peach horizon, warm sun
## scatter in the fog and a sky glow dome. The walls go to lavender shade with warm rims, the haze
## between them glows, caps and lake catch the backlight (sweep 114931 az200 vs midday 114603).
## Consult 01 + review 05 (2026-10-27): the dead-astern sun gave N.L <= 0 on every camera-facing face
## (no shadow maps on scenery), so rock lost its form and the golden hour was carried by fog scatter
## (peach curtain, salmon lake). Now a 3/4 back-side key (60 degrees right of the vista axis, 13
## degrees up), a lavender shadowless fill from behind-left at 45 degrees, lower ambient, a darker
## lavender fog below the sky, a darker zenith, and the warm glow dome decoupled from the key (near
## the view axis), as the concepts do. Vista (L*): massif range 39 -> 53, far block 80 (above the
## sky) -> 45 (40 below), lake hue 5 -> 245, mist hue 17 -> 246 (sweeps 123819, 123952).
const DEPTH_LOOK := {"sun": Color("ffcc94"), "ambient": Color("9e94e0"), "fog": Color("b8958c"), "sky_top": Color("3a3c86"), "sky_horizon": Color("c4a7bd"), "lake_horizon": Color("f0b890")}
const GOLDEN_SUN_AZ := 157.0
const GOLDEN_SUN_ELEV := -13.0
const GOLDEN_SUN_ENERGY := 1.6
const GOLDEN_AMBIENT_ENERGY := 0.28
const GOLDEN_FOG_DENSITY := 0.45
const GOLDEN_AERIAL := 0.55
## Scatter 0.5 washed the walls toward the sun to cream (hero/knoll, geology 115105): 0.32.
const GOLDEN_SCATTER := 0.35
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
# Terrain, forest carpet and meadow erratics: the golden-hour soft daylight terms (wrap on the key,
# sky/bounce hemisphere) go to these materials only.
var _soft_materials: Array[ShaderMaterial] = []
var _horizon_cap_material: ShaderMaterial
var _horizon_stem_material: ShaderMaterial
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
## Second corridor stretch (2026-10-26): the slice segment through the vista camera's near
## field, z 40..140 (one contiguous run from about (215, 140) to (238, 40)), where the far-LOD
## forest clumps (6-26 m faceted blobs) otherwise stand at arm's length from the walker.
const UNDERSTORY_VISTA_Z := Vector2(140.0, 40.0)
var extra_understories: Array[Node3D] = []
var extra_replaced_carpets: Array[MultiMeshInstance3D] = []
var understory_report: Dictionary = {}
var _understory_sync: Array = []
## Hero stem organic finish (far_canopy mode 1), masked to this radius around the hero base;
## the nearest other giant stands ~395 m away.
const STEM_FOCUS_RADIUS := 200.0
const STEM_ORGANIC := 1.0
var cap_material: ShaderMaterial
## Hero cap margin lobes (angle rad, angular width rad, radial amplitude): two broad bulges and
## two broad recessions at uneven spacing. Each is made zero-mean, so the mean plan radius is kept.
const HERO_CAP_LOBES: Array[Vector3] = [Vector3(0.6, 0.55, 0.07), Vector3(2.3, 0.45, -0.05), Vector3(3.7, 0.65, 0.05), Vector3(5.1, 0.4, -0.04)]
var _hero_cap_previous: ArrayMesh
var _hero_cap_shaped: ArrayMesh
var hero_cap_mesh_check: Dictionary = {}
var stem_material: ShaderMaterial
## Cliff readability, applied by the shared terrain shader only inside the cliff detail patch's
## region (the near massif whose shaded faces read near-black from the root approach).
## Lift 2.2 -> 4.5 and fill 1.0 -> 3.0 after the clearer fog (ce4cd93) left the overlook cliffs near-black
## (overlook central cliff L*11.5 before the fog change, 4.8 after, 21.9 with these values).
const ROCK_READABILITY := {"rock_breakup": 1.0, "rock_relief": 0.5, "rock_fill": 3.0, "rock_albedo_lift": 4.5}
var rock_material: ShaderMaterial
var _tree_templates: Array = []
var _near_crown: Dictionary = {}
var corridor_trees: Array[MultiMeshInstance3D] = []
## Opposite-shore groves: forest-carpet clumps on the lake's shoreline belt (origin within ~13 m of
## lake level, <= 360 m from the lake centre, west of x 300) become layered groves (low shrub masses
## of the copied trees' ring-crown mesh plus copied trees, selected within SHORE_GROVE_BUDGET at full
## detail, built from simplified crowns); the clumps are kept (hidden) in ShoreBeltClumps.
const SHORE_BELT_Y := Vector2(-82.5, -69.0)
const SHORE_STREAM_CLEAR := 28.0
const SHORE_BELT_RADIUS := 360.0
const SHORE_BELT_MAX_X := 300.0
## Groves draw as far as the carpet they replace; the belt clumps stay hidden while groves are on,
## so there is no far swap. Tree selection uses the full-detail cost against the selection budget
## (unchanged population); crowns and shrubs are built from simplified crown meshes.
const SHORE_GROVE_END := 1700.0
const SHORE_GROVE_BUDGET := 400000
const SHORE_GROVE_BUILT_BUDGET := 150000
## Simplified crown for the groves (never closer than ~210 m to a walkable path): every Nth leaf
## card kept, each scaled about its own centre to keep the crown's coverage and outline.
const SHORE_LEAF_KEEP := 4
const SHORE_LEAF_SCALE := 1.7
var shore_groves: Node3D
var shore_clumps: MultiMeshInstance3D
var shore_groves_report: Dictionary = {}
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
## Foreground leaf craft on the near (dense) crowns: blade fold along the midrib and tip arch as a
## fraction of half-width (linear, quadratic in |lateral|) and of leaf length, the share of the
## angle by which each leaf turns toward the crown's outside, and its random twist (rad).
const LEAF_FOLD := Vector2(0.22, 0.18)
const LEAF_ARCH := 0.10
const LEAF_TURN := 0.3
const LEAF_TWIST := 0.18
var _near_crown_previous: Mesh
## West Wall samples (toe every WALL_STEP m) and a coarse signed-distance mask (cell 25 m) used
## to keep massifs and forest clumps out of the rock; empty when the landmark is skipped.
var _wall: Array = []
var _wall_grid := PackedFloat32Array()
## Facet panels: broad near-planar granite faces between boundaries along the wall, in two
## staggered height tiers. Each boundary: s, offset (m), tilt (offset change across the height),
## fracture depth (a dark recess cut along it, 0 = none) and the tone of the panel that follows
## (0 weathered dark .. 1 freshly spalled pale).
var _facets: Array = [[], []]
## Gullies (seeded, plus the falls' drainage gully): centre s, half-width at the rim, depth into
## the face at the rim, rim notch depth. Bench levels: base height fraction, setback (m), and a
## seed for where along the wall each ledge exists.
var _gullies: Array = []
const WALL_BENCHES: Array[Vector3] = [Vector3(0.22, 16.0, 11.0), Vector3(0.41, 26.0, 23.0), Vector3(0.60, 20.0, 37.0), Vector3(0.78, 30.0, 53.0)]
## Plunge basin at the falls' foot (centre x, z; carved depth): a bounded terrain depression.
var _basin := Vector3(INF, INF, 0.0)
const BASIN_RADIUS := 55.0
const BASIN_DEPTH := 14.0
## Outlet stream from the plunge basin to the lake: centreline points (x, bed height, z) every
## STREAM_STEP m, planned on the terrain without the stream; the valley is carved only downward
## (flat bed of half-width STREAM_BED, banks at STREAM_BANK rise per metre, out to STREAM_VALLEY).
const STREAM_STEP := 10.0
const STREAM_BED := 16.0
const STREAM_BANK := 0.55
const STREAM_VALLEY := 220.0
const STREAM_BUCKET := 40.0
const STREAM_MEANDER := Vector2(26.0, 240.0)
var _stream: Array[Vector3] = []
var _stream_buckets: Dictionary = {}
var _stream_box := Rect2()
var _stream_carving: bool = false
## Precomputed once (8 m cells over the valley's reach): carve target height and distance to the
## centreline, so terrain queries stay constant-time.
const STREAM_CELL := 8.0
var _stream_grid := PackedFloat32Array()
var _stream_grid_d := PackedFloat32Array()
var _stream_grid_cols: int = 0
var stream_report: Dictionary = {"built": false}
var _wall_grid_s := PackedFloat32Array()
var _wall_grid_box := Rect2()
const WALL_GRID_CELL := 25.0
var _geology_materials: Array[ShaderMaterial] = []
var escarpment_report: Dictionary = {"built": false}
## Capture-only geology diagnosis: shader view for the rock and ice materials (0 final) and
## whether depth fog is removed; set_geology_debug(0, false) restores the final rendering.
var geology_debug: int = 0
var _debug_fog_off: bool = false
## Every material switched to LEAF_SHADER (near palettes, far tone, far crossfade copy).
var _prototype_leaf_materials: Array[ShaderMaterial] = []
var leaf_craft: bool = false
var leaf_craft_report: Dictionary = {}
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
	# Plunge basin under the West Falls (only when the landmark is built).
	if _basin.x != INF:
		var to_basin: float = Vector2(x, z).distance_to(Vector2(_basin.x, _basin.y))
		if to_basin < BASIN_RADIUS * 3.0: height -= _basin.z * exp(-pow(to_basin / BASIN_RADIUS, 2.0))
	# Not during seeded placement draws (legacy landform), so placement streams do not shift.
	if _stream_carving and not _legacy_mesa: height = _stream_carve(x, z, height)
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
	# Inside and just in front of the West Wall the massifs give way to the granite.
	return lerpf(_eroded_mesa_height(x, z), legacy, keep) * mask * (1.0 - _wall_suppress(x, z))

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

## The world's camera-following sky (ProposedSky36: stars, constellation lines, visible sun) is a
## 120 m dome, which was fine for the enclosed clearing but sits in front of the prototype's
## 0.6-1.8 km geology, so stars drew over the mountains at night. Scaling the dome root (the world
## only copies the camera position into it each frame) moves it beyond the geology while every
## star keeps its angular size and its own instance transform; the sky's unshaded materials skip
## depth fog so the farther stars are not dimmed. Startup only; prototype mode only.
const SKY_DOME_SCALE := 19.0
const MOON_DISTANCE := 2200.0
var sky_dome_report: Dictionary = {"pushed": false}
func _add_skyglow() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = SKYGLOW_RADIUS
	sphere.height = SKYGLOW_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_skyglow_material = ShaderMaterial.new()
	_skyglow_material.shader = SKYGLOW_SHADER
	_skyglow = MeshInstance3D.new()
	_skyglow.name = "GoldenHourSkyGlow"
	_skyglow.mesh = sphere
	_skyglow.material_override = _skyglow_material
	_skyglow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_skyglow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_skyglow.extra_cull_margin = 16384.0
	add_child(_skyglow)
	_static.append(_skyglow)
	# The world's visible sun is a sphere 120 m from the camera; with the golden-hour sun in front of
	# the hero views it drew over the far walls. Full geometry transparency hides it without touching
	# its visibility, mesh or pose (owned by the world); the dome draws the disc instead. (Render
	# layer 0 was tried and made the engine log "indexing did not unpair geometries from light".)
	var visible_sun: Variant = _world.get("_r36_sun")
	if look_depth and visible_sun is GeometryInstance3D and is_instance_valid(visible_sun):
		(visible_sun as GeometryInstance3D).transparency = 1.0
		sky_dome_report["visible_sun_transparency"] = 1.0

func _push_sky_dome() -> void:
	var root: Variant = _world.get("_r36_root")
	if not (root is Node3D) or not is_instance_valid(root): 
		sky_dome_report = {"pushed": false, "reason": "no ProposedSky36 root"}
		return
	# The root's basis is rewritten every frame by the sky orbit (motion-world), so the star field
	# and constellation lines are scaled in place instead (same parents and names, so the existing
	# sky bindings still hold; instance transforms untouched). The visible sun is repositioned to
	# 120 m by the world each frame and only shows by day; it is left as is.
	var scaled: Array[String] = []
	for key: String in ["_stars", "_r36_lines"]:
		var child: Variant = _world.get(key)
		if child is Node3D and is_instance_valid(child) and (child as Node3D).get_parent() == root:
			(child as Node3D).scale = Vector3.ONE * SKY_DOME_SCALE
			scaled.append(key)
	var materials: int = 0
	for node: Node in (root as Node3D).find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var list: Array[Material] = [geometry.material_override]
		var mesh: Mesh = null
		if geometry is MeshInstance3D: mesh = (geometry as MeshInstance3D).mesh
		elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null: mesh = (geometry as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for s: int in mesh.get_surface_count(): list.append(mesh.surface_get_material(s))
		for material: Material in list:
			if material is BaseMaterial3D and not (material as BaseMaterial3D).disable_fog:
				(material as BaseMaterial3D).disable_fog = true
				materials += 1
	# The world's moon is a 2.85 m sphere that motion-world keeps at a fixed offset (~56 m) from the
	# camera-following sky root, sized for the clearing's sky; in the prototype's valley it drew in
	# front of the giants (overlook night). Its anchor offset and scale are pushed out together to
	# MOON_DISTANCE (same apparent size, just inside the star dome), and its material is a fog-exempt
	# copy (the original shader with fog_disabled added at runtime; the asset is untouched).
	var moon_pushed: float = 0.0
	var moon: Variant = _world.get("_moon")
	var anchor: Variant = _world.get("_m37_anchor_moon_position")
	if moon is MeshInstance3D and is_instance_valid(moon) and anchor is Vector3 and (anchor as Vector3).length() > 1.0:
		var k: float = MOON_DISTANCE / (anchor as Vector3).length()
		_world.set("_m37_anchor_moon_position", (anchor as Vector3) * k)
		(moon as Node3D).scale *= k
		var source: ShaderMaterial = (moon as MeshInstance3D).material_override as ShaderMaterial
		if source != null and source.shader != null and source.shader.code.contains("render_mode unshaded;"):
			var shader := Shader.new()
			shader.code = source.shader.code.replace("render_mode unshaded;", "render_mode unshaded, fog_disabled;")
			var copy: ShaderMaterial = source.duplicate()
			copy.shader = shader
			(moon as MeshInstance3D).material_override = copy
		moon_pushed = MOON_DISTANCE
	sky_dome_report = {"pushed": scaled.size() == 2, "scaled": scaled, "scale": SKY_DOME_SCALE, "dome_radius_m": 120.0 * SKY_DOME_SCALE, "fog_exempt_materials": materials, "far_plane": FAR_PLANE, "moon_distance_m": moon_pushed}
	print("SKY_DOME ", JSON.stringify(sky_dome_report))

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
	var geology_skip: bool = "no_geology" in OS.get_environment("MUSH_SCENERY_DIAG").split(",", false)
	if not geology_skip: _plan_wall()
	_collect_soil(baked_extent.grow(6.0))
	_sample_edges()
	_plan_route()
	# The existing ribbon depends only on its planned points, so building it before the
	# terrain mesh leaves it identical; the slice starts from its measured end.
	_add_route()
	_add_slice_route()
	# Diagnostic-only performance bisection (empty by default; never set by the game).
	var skip: PackedStringArray = OS.get_environment("MUSH_SCENERY_DIAG").split(",", false)
	# The outlet stream is planned on the same terrain state the mesh is built from (after the
	# route and slice beds exist); its carve is 500+ m from both.
	if not geology_skip: _plan_stream()
	_add_terrain()
	if "plain_terrain" in skip: _terrain_material.shader = preload("res://assets/world/far_canopy.gdshader"); _terrain_material.set_shader_parameter("mode", 2)
	if "no_water" in skip: _static[_static.size() - 1].visible = false
	_add_giants(rng)
	_add_root_collision()
	_add_pillars(rng)
	_add_boulders(rng)
	if not "no_trees" in skip: _add_trees(rng)
	if not "no_carpet" in skip: _add_carpet(rng)
	if not "no_understory" in skip:
		_add_corridor_understory()
		# Sparser groups (x2.0 spacing) and a 70 m tree reach keep both stretches inside the shared
		# 4,000-instance / 300,000-triangle understory budget (x1.0 / 125 m measured 379,778).
		if not "no_vista_understory" in skip: _add_corridor_understory(UNDERSTORY_VISTA_Z, "vista", 2.0, 70.0)
	if not "no_shore_groves" in skip: _add_shore_groves()
	if not "no_erratics" in skip: _add_meadow_erratics()
	if not "no_vista_grove" in skip: _add_vista_grove()
	if VISTA_REFUGE and not "no_vista_refuge" in skip: _add_vista_refuge()
	if not "no_horizon_giants" in skip: _add_horizon_giants()
	if not geology_skip:
		_add_wall()
		if not "no_far_falls" in skip: _add_far_ribbon_falls()
		if not "no_wall_mist" in skip: _add_wall_mist()
		if not "no_valley_mist" in skip: _add_valley_mist()
	_push_sky_dome()
	_add_skyglow()
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
			# Riparian band (outlet stream channel and plunge-pool rim) for the terrain shader.
			st.set_color(Color(_riparian(x, z), 0, 0))
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
	_soft_materials.append(_terrain_material)
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
	_lake_material.shader = LAKE_SHADER
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
	var hero_cap: ArrayMesh = _cap_mesh(PackedFloat32Array([0.4, 2.1, 4.0, 1.3, 5.2, 0.7]), "hero_cap")
	# Previous hero cap mesh, kept only for same-frame before/after evidence (set_cap_shape).
	_hero_cap_previous = _cap_mesh(PackedFloat32Array([0.4, 2.1, 4.0, 1.3, 5.2, 0.7]))
	_hero_cap_shaped = hero_cap
	hero_cap_mesh_check = _cap_mesh_check(hero_cap, _hero_cap_previous)
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
	# Cap craft on the hero cap's own material only (the six other caps keep their look).
	cap_material = _art[_art.size() - 1]
	set_cap_craft(true)
	_add(cap, caps, tints, 0, "LuminousCanopies")
	var all_caps: Array[Transform3D] = []
	all_caps.append_array(hero_caps)
	all_caps.append_array(caps)
	_add_cap_tendrils(all_caps, "CapTendrils", 41)
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
	# Grey granite needles: no moss on the ledge rings (they read as banded olive 'termite mounds').
	var pillar_material: ShaderMaterial = (_nodes[_nodes.size() - 1] as MultiMeshInstance3D).material_override
	pillar_material.set_shader_parameter("ledge_moss", 0.08)
	pillar_material.set_shader_parameter("sky_fill", 0.8)

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
	# The far LOD of near trees gets its own duplicate for the crossfade; far_tone itself stays
	# unfaded (corridor trees draw it at every distance).
	var far_fade: Material = far_tone
	if far_tone is ShaderMaterial and far_tone != ring_material:
		far_fade = far_tone.duplicate()
		_prototype_leaf_materials.append(far_fade as ShaderMaterial)
		_crown_sync.append([ring_material, far_fade])
	_lod_materials = {"near": softs, "far": [far_fade]}
	return {"mesh": mesh, "materials": softs, "far_material": far_tone, "far_fade_material": far_fade, "scale": ratio}

## Foreground leaf craft (near crowns only). A copy of the dense crown with the same leaves,
## vertices and triangles: each 36-vertex leaf (world.gd _append_ground_leaf, placed by
## _make_canopy_mesh) is folded gently upward along its midrib, its tip arched down, turned part
## of the way toward the crown's outside and twisted slightly about its own axis, all about its
## base, so the attachment point does not move. Normals are smoothed across each leaf and keep
## each vertex's original side. Returns null (and reports why) for any other layout.
func _craft_crown(source: Mesh) -> ArrayMesh:
	leaf_craft_report = {"crafted": false}
	var arrays: Array = source.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if source.get_surface_count() != 1 or arrays[Mesh.ARRAY_INDEX] != null or v.size() % 36 != 0 or uv.size() != v.size() or n.size() != v.size():
		leaf_craft_report["reason"] = "not the 36-vertex leaf layout"
		return null
	var out_v := PackedVector3Array(v)
	var out_n := PackedVector3Array(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7341
	var base_shift: float = 0.0
	var max_shift: float = 0.0
	var length_sum: float = 0.0
	var flipped: int = 0
	var degenerate: int = 0
	var degenerate_before: int = 0
	var finite := true
	for o: int in range(0, v.size(), 36):
		var base: int = -1
		var tip: int = -1
		var rib: int = -1
		var edge: int = -1
		for i: int in range(o, o + 36):
			if uv[i].is_equal_approx(Vector2(0.5, 0.0)): base = i
			elif uv[i].is_equal_approx(Vector2(0.5, 1.0)): tip = i
			elif uv[i].is_equal_approx(Vector2(0.5, 0.5)): rib = i
			elif uv[i].is_equal_approx(Vector2(0.0, 0.5)): edge = i
		if base < 0 or tip < 0 or rib < 0 or edge < 0:
			leaf_craft_report["reason"] = "leaf %d has no base, tip, midrib or edge vertex" % (o / 36)
			return null
		var root: Vector3 = v[base]
		var length: float = root.distance_to(v[tip])
		length_sum += length
		var axis: Vector3 = (v[tip] - root) / length
		var up: Vector3 = (n[rib] - axis * n[rib].dot(axis)).normalized()
		var lateral: Vector3 = v[edge] - v[rib]
		var half_width: float = (lateral - up * lateral.dot(up) - axis * lateral.dot(axis)).length()
		var outward: Vector3 = root.normalized()
		var facing: Vector3 = up if up.dot(outward) >= 0.0 else -up
		var hinge: Vector3 = facing.cross(outward)
		var turn := Basis.IDENTITY
		if hinge.length() > 1e-5: turn = Basis(hinge.normalized(), LEAF_TURN * facing.angle_to(outward))
		turn = turn * Basis(axis, rng.randf_range(-LEAF_TWIST, LEAF_TWIST))
		for i: int in range(o, o + 36):
			var f: float = absf(uv[i].x - 0.5) * 2.0
			var local: Vector3 = v[i] - root + up * (half_width * (LEAF_FOLD.x * f + LEAF_FOLD.y * f * f) - LEAF_ARCH * length * uv[i].y * uv[i].y)
			out_v[i] = root + turn * local
			finite = finite and out_v[i].is_finite()
			max_shift = maxf(max_shift, out_v[i].distance_to(v[i]) / length)
		base_shift = maxf(base_shift, out_v[base].distance_to(root))
		var up_now: Vector3 = turn * up
		var sums: Dictionary = {}
		for k: int in range(o, o + 36, 3):
			var face: Vector3 = (out_v[k + 1] - out_v[k]).cross(out_v[k + 2] - out_v[k])
			var before: Vector3 = (v[k + 1] - v[k]).cross(v[k + 2] - v[k])
			if before.length() < 1e-12: degenerate_before += 1
			if face.length() < 1e-12:
				degenerate += 1
				continue
			if before.length() >= 1e-12 and face.dot(turn * before) <= 0.0: flipped += 1
			if face.dot(up_now) < 0.0: face = -face
			for m: int in 3: sums[out_v[k + m]] = sums.get(out_v[k + m], Vector3.ZERO) + face
		for i: int in range(o, o + 36):
			var smooth: Vector3 = (sums.get(out_v[i], up_now) as Vector3).normalized()
			out_n[i] = smooth if n[i].dot(up) >= 0.0 else -smooth
	var out: Array = arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = out_v
	out[Mesh.ARRAY_NORMAL] = out_n
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	mesh.surface_set_material(0, source.surface_get_material(0))
	var leaves: int = v.size() / 36
	leaf_craft_report = {"crafted": true, "passed": finite and flipped == 0 and base_shift < 1e-5 and degenerate == degenerate_before and _triangle_count(mesh) == _triangle_count(source),
		"leaves": leaves, "vertices": out_v.size(), "vertices_previous": v.size(), "triangles": _triangle_count(mesh), "triangles_previous": _triangle_count(source),
		"finite": finite, "flipped_faces": flipped, "degenerate_faces": degenerate, "degenerate_faces_previous": degenerate_before, "base_shift_max": base_shift,
		"max_vertex_shift_per_leaf_length": max_shift, "mean_leaf_length": length_sum / leaves, "fold": [LEAF_FOLD.x, LEAF_FOLD.y], "arch": LEAF_ARCH, "turn": LEAF_TURN, "twist_rad": LEAF_TWIST,
		"outline": "shader: 0.919 * sin(pi * v^0.9)^1.2 inside the blade polygon (prototype_leaf.gdshader leaf_craft)"}
	return mesh

## Foreground leaf craft on (current) or the previous look; diagnostic toggle. Off restores the
## previous dense crown and, on every prototype leaf material, the source shader's second
## back-face flip.
func set_leaf_craft(enabled: bool) -> void:
	if _near_crown_previous == null: return
	leaf_craft = enabled
	for material: ShaderMaterial in _prototype_leaf_materials: material.set_shader_parameter("legacy_side_flip", not enabled)
	for node: GeometryInstance3D in _static:
		if node.get_meta("lod_range", "") == "near" and node is MultiMeshInstance3D:
			(node as MultiMeshInstance3D).multimesh.mesh = _near_crown.mesh if enabled else _near_crown_previous
	for material: Variant in _lod_materials.get("near", []):
		if material is ShaderMaterial: (material as ShaderMaterial).set_shader_parameter("leaf_craft", 1.0 if enabled else 0.0)

## Diagnostic: show where prototype leaf shading normals face away from the viewer.
func set_leaf_facing_debug(enabled: bool) -> void:
	for material: ShaderMaterial in _prototype_leaf_materials: material.set_shader_parameter("debug_facing", enabled)

## Duplicate leaf materials only: switch to the prototype copy of the source leaf shader
## and damp backlight transmission and specular glare, so backlit leaves stay green.
func _restrain_leaf(material: Material) -> void:
	if not material is ShaderMaterial or (material as ShaderMaterial).shader != SOURCE_LEAF_SHADER: return
	(material as ShaderMaterial).shader = LEAF_SHADER
	_prototype_leaf_materials.append(material as ShaderMaterial)
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
	# Foreground leaf craft: near crowns draw a crafted copy of the dense crown (same leaves and
	# triangles); the previous mesh is kept only for same-frame evidence (set_leaf_craft).
	if not near_crown.is_empty():
		var crafted: ArrayMesh = _craft_crown(near_crown.mesh)
		if crafted != null:
			_near_crown_previous = near_crown.mesh
			near_crown["mesh"] = crafted
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
				_tree_batch(batches, part.kind, part.mesh, near_crown.far_fade_material, cell, "far", root * part.local)
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
	set_lod_crossfade(true)
	set_leaf_craft(true)
	leaf_craft_report.merge({"near_nodes": lod.near_batches, "near_instances": lod.near_instances, "near_triangles": lod.near_triangles, "rim_view_dense_instances": lod.rim_view_dense_instances, "rim_view_dense_triangles": lod.rim_view_dense_triangles})
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
	# Tree forms (FOREST_TREES): spires -> conifer, crowns -> 70% broadleaf / 30% conifer (by index
	# hash, so the random stream and every position are unchanged), spreading -> umbrella crown.
	var forms: Array[ArrayMesh] = [clump, clump, clump]
	if FOREST_TREES: forms = [Forest.conifer_mesh(), Forest.broadleaf_mesh(), Forest.spreading_mesh()]
	var kinds: Array[int] = []
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
		if on_cliff or on_slice or _inside_wall(x, z) or _stream_distance(x, z).x < STREAM_BED + 24.0 or (_basin.x != INF and Vector2(x, z).distance_to(Vector2(_basin.x, _basin.y)) < BASIN_RADIUS * 1.5) or (not hero.is_empty() and Vector2(x, z).distance_to(Vector2(hero.base.x, hero.base.z)) < float(hero.radius) * 0.75):
			if _inside_wall(x, z): escarpment_report["clumps_in_rock"] = int(escarpment_report.get("clumps_in_rock", 0)) + 1
			xs.pop_back()
			continue
		var kind: int = 0 if form < 0.3 else (2 if form >= 0.8 else (0 if (xs.size() * 2654435761) % 10 < 3 else 1))
		kinds.append(kind)
		# Tree crowns cover less of their box than the solid clump did: crowns 15% wider (density).
		if kind != 0 and FOREST_TREES:
			var last: Transform3D = xs[xs.size() - 1]
			xs[xs.size() - 1] = Transform3D(last.basis * Basis.from_scale(Vector3(1.15, 1.0, 1.15)), last.origin)
		# Conifers lean darker and bluer than the broadleaf stands.
		if kind == 0 and FOREST_TREES: tone = Color(tone.r * 0.82, tone.g * 0.92, tone.b * 0.95)
		colors.append(tone)
	_legacy_mesa = false
	_skip_slice_bed = false
	carpet_count = xs.size()
	carpet_triangles = 0
	for k: int in kinds: carpet_triangles += _triangle_count(forms[k])
	# One shared material; 400 m spatial chunks so off-screen forest is frustum-culled
	# (a single map-wide MultiMesh was always drawn, even from inside the clearing).
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", 5)
	_art.append(material)
	_soft_materials.append(material)
	var chunks: Dictionary = {}
	for index: int in xs.size():
		var cell := Vector3i(floori(xs[index].origin.x / 400.0), floori(xs[index].origin.z / 400.0), kinds[index])
		if not chunks.has(cell): chunks[cell] = []
		chunks[cell].append(index)
	for cell: Vector3i in chunks:
		var members: Array = chunks[cell]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = forms[cell.z]
		multi.instance_count = members.size()
		for k: int in members.size():
			multi.set_instance_transform(k, xs[members[k]])
			multi.set_instance_color(k, colors[members[k]])
		var node := MultiMeshInstance3D.new()
		node.name = "ForestCarpet_%d_%d_%s" % [cell.x, cell.y, ["conifer", "broadleaf", "spreading"][cell.z]]
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
## z_range/tag: the original stretch is the default call (names and report unchanged); further
## contiguous route stretches use a tag, tagged node names and understory_report["extra_<tag>"].
## spacing scales the distance between groups and tree_reach the clump-to-tree conversion reach,
## so an extra stretch can fit the shared budget; the defaults reproduce the original exactly
## (same random draws, results only scaled).
func _add_corridor_understory(z_range: Vector2 = UNDERSTORY_Z, tag: String = "", spacing: float = 1.0, tree_reach: float = CORRIDOR_TREE_REACH) -> void:
	var main: bool = tag.is_empty()
	if main: understory_report = {"built": false}
	if not is_instance_valid(slice_route) or not slice_route.valid: return
	var sources: Dictionary = _understory_sources()
	if main: understory_report["sources"] = sources.keys()
	if sources.size() < 8:
		if main: understory_report["error"] = "clearing understory meshes not found"
		return
	var hero_xz := Vector2(hero.base.x, hero.base.z) if not hero.is_empty() else Vector2(INF, INF)
	var section := PackedVector3Array()
	for p: Vector3 in slice_route._p:
		if p.z < z_range.x and p.z > z_range.y: section.append(p)
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
			if bounds.grow(tree_reach).has_point(at) and _section_distance(section, at) <= tree_reach:
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
		var set_aside := MultiMeshInstance3D.new()
		set_aside.name = "CorridorReplacedCarpet" + ("" if main else "_" + tag)
		set_aside.multimesh = hidden
		set_aside.material_override = clump_material
		set_aside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		set_aside.visible = false
		add_child(set_aside)
		if main: replaced_carpet = set_aside
		else: extra_replaced_carpets.append(set_aside)
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
			s += rng.randf_range(4.0, 7.0) * spacing
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
		s += rng.randf_range(3.0, 5.5) * spacing
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
	var group := Node3D.new()
	group.name = "CorridorUnderstory" + ("" if main else "_" + tag)
	add_child(group)
	if main: understory = group
	else: extra_understories.append(group)
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
		group.add_child(node)
		_static.append(node)
		per_asset[batch.asset] = int(per_asset.get(batch.asset, 0)) + batch.poses.size()
		triangles += int(source.triangles) * batch.poses.size()
	var instances: int = 0
	for asset: String in per_asset: instances += per_asset[asset]
	var report: Dictionary = {"built": true, "section_samples": section.size(), "section_length_m": arc[arc.size() - 1],
		"carpet_clumps_replaced": replaced.size(), "carpet_triangles_hidden": _triangle_count(clump_mesh) * replaced.size() if clump_mesh else 0,
		"stretch_z": [z_range.x, z_range.y], "banks": banks, "attachment": attach,
		"tree_targets": tree_targets, "corridor_trees": tree_report_corridor,
		"source_aabb": sources.keys().map(func(asset: String) -> Array: return [asset, snappedf(sources[asset].mesh.get_aabb().position.y, 0.001), snappedf(sources[asset].mesh.get_aabb().size.y, 0.001)]), "fern_materials": leaf_variants.map(func(v: Array) -> String: return v[0]), "instances": instances, "per_asset": per_asset, "triangles": triangles, "nodes": batches.size(),
		"dropped": dropped, "min_lateral_m": closest, "min_lateral_required_m": min_lateral, "draw_range_m": UNDERSTORY_RANGE,
		"sources": sources.keys(), "colliders": 0, "shadow_casters": 0,
		"source_scale": sources.keys().map(func(asset: String) -> Array: return [asset, snappedf(sources[asset].scale.x, 0.01), snappedf(sources[asset].scale.y, 0.01)]),
		"near_kept_clumps": near_kept, "target_height_m": heights,
		"source_height_m": sources.keys().map(func(asset: String) -> Array: return [asset, snappedf(sources[asset].mesh.get_aabb().size.y * sources[asset].scale.y, 0.01)])}
	if main: understory_report = report
	else: understory_report["extra_" + tag] = report

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

## Luminous drips under the cap rims: crossed ribbons hanging from just inside the rim (cap local
## radius 0.9, rim underside y -0.12), count and length scaled by the cap radius. One MultiMesh draw
## per call, additive, no shadows, no collision.
func _add_cap_tendrils(cap_poses: Array[Transform3D], label: String, seed: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: int in 2:
		var d := Vector3(1, 0, 0) if q == 0 else Vector3(0, 0, 1)
		var c: Array = [[-d * 0.5, Vector2(0, 0)], [d * 0.5, Vector2(1, 0)], [d * 0.5 + Vector3.DOWN, Vector2(1, 1)], [-d * 0.5 + Vector3.DOWN, Vector2(0, 1)]]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(c[k][1])
			st.add_vertex(c[k][0])
	var ribbon: ArrayMesh = st.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var xs: Array[Transform3D] = []
	for pose: Transform3D in cap_poses:
		var r: float = pose.basis.x.length()
		var count: int = clampi(int(r * 0.75), 10, 170)
		for i: int in count:
			var a: float = TAU * (float(i) + rng.randf_range(-0.4, 0.4)) / float(count)
			var hang: Vector3 = pose * Vector3(cos(a) * rng.randf_range(0.82, 0.92), -0.11, sin(a) * rng.randf_range(0.82, 0.92))
			var length: float = r * rng.randf_range(0.03, 0.16) * (1.6 if rng.randf() < 0.12 else 1.0)
			var width: float = maxf(0.25, r * 0.0055) * rng.randf_range(0.7, 1.3)
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(width, length, width)), hang))
	if xs.is_empty(): return
	var material := ShaderMaterial.new()
	material.shader = TENDRIL_SHADER
	_geology_materials.append(material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = ribbon
	multi.instance_count = xs.size()
	for i: int in xs.size(): multi.set_instance_transform(i, xs[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	_static.append(node)
	tendril_report[label] = {"tendrils": xs.size(), "triangles": xs.size() * 4}

## Where a ray through the vista frame (screen x, y in -1..1, y up; vertical FOV 60, 16:9, eye 1.7 m
## above the rendered ground, as in the geology vista view) first meets the rendered ground, or
## Vector3.INF within max_m (2 m steps beyond 200 m).
func _vista_ray_ground(sx: float, sy: float, max_m: float = 400.0) -> Vector3:
	var eye_ground: float = rendered_terrain_height(VISTA_EYE.x, VISTA_EYE.y)
	var eye := Vector3(VISTA_EYE.x, maxf(eye_ground if not is_nan(eye_ground) else terrain_height(VISTA_EYE.x, VISTA_EYE.y), LAKE_Y) + 1.7, VISTA_EYE.y)
	var look: Vector3 = (Vector3(VISTA_AIM.x, 90.0, VISTA_AIM.y) - eye).normalized()
	var right: Vector3 = look.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(look)
	var ray: Vector3 = (look + right * sx * tan(deg_to_rad(30.0)) * 16.0 / 9.0 + up * sy * tan(deg_to_rad(30.0))).normalized()
	var t: float = 2.0
	while t < max_m:
		var q: Vector3 = eye + ray * t
		var g: float = rendered_terrain_height(q.x, q.z)
		if q.y < (g if not is_nan(g) else terrain_height(q.x, q.z)): return q
		t += 1.0 if t < 200.0 else 2.0
	return Vector3.INF

## Luminous grove on the plateau in the vista's lower-left (review 03: only large shapes read at
## that distance): four lavender mushrooms of uneven size clustered
## on the slope east of the clearing (300-900 m out, so cap radii 9-22 m), on the giants' cap and stem
## meshes and shaders; kept 40 m clear of the baked clearing. Visual only:
## no collision, no shadows; every stem stays clear of the walking ribbons.
func _add_vista_grove() -> void:
	vista_grove_report = {"built": false}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	var cap: ArrayMesh = _cap_mesh(PackedFloat32Array([1.7, 4.2, 0.9, 2.8, 5.6, 3.3]))
	var stem: ArrayMesh = _stem_mesh()
	var caps: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	var cap_tints: Array[Color] = []
	var stem_tints: Array[Color] = []
	var placed: Array = []
	var rejected: int = 0
	var min_gap: float = INF
	for spec: Array in VISTA_GROVE:
		var hit: Vector3 = _vista_ray_ground(float(spec[0]), float(spec[1]), 900.0)
		if hit == Vector3.INF or baked_extent.grow(40.0).has_point(Vector2(hit.x, hit.z)):
			rejected += 1
			continue
		var r: float = float(spec[2])
		var stem_r: float = r * 0.15
		var gap: float = _ribbon_gap(Vector2(hit.x, hit.z))
		if gap < 6.0 + stem_r or hit.y < LAKE_Y + 1.0:
			rejected += 1
			continue
		min_gap = minf(min_gap, gap)
		var ground: float = hit.y
		var h: float = r * rng.randf_range(1.3, 1.7)
		var yaw: float = rng.randf_range(0.0, TAU)
		var lean: Vector3 = Basis(Vector3.UP, yaw) * Vector3(STEM_BEND * stem_r, 0.0, 0.0)
		var tilt := Basis(Vector3(1, 0, 0), rng.randf_range(-0.08, 0.08)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.08, 0.08))
		caps.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * tilt * Basis.from_scale(Vector3(r, r * 0.5, r)), Vector3(hit.x + lean.x, ground + h, hit.z + lean.z)))
		var base: float = ground - maxf(2.0, stem_r * 0.9)
		stems.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(stem_r, ground + h + r * 0.5 * 0.22 - base, stem_r)), Vector3(hit.x, base, hit.z)))
		cap_tints.append(Color(rng.randf(), 0, 0))
		stem_tints.append(Color(rng.randf(), 1, 1))
		placed.append([snappedf(hit.x, 0.1), snappedf(hit.z, 0.1), r])
	if caps.is_empty():
		vista_grove_report["reason"] = "no clear ground"
		return
	_add(cap, caps, cap_tints, 0, "VistaGroveCaps")
	_add_cap_tendrils(caps, "VistaGroveTendrils", 43)
	_add(stem, stems, stem_tints, 1, "VistaGroveStems")
	canopy_count += caps.size()
	vista_grove_report = {"built": true, "mushrooms": caps.size(), "rejected": rejected, "placed_x_z_capradius": placed, "min_ribbon_gap_m": snappedf(min_gap, 0.1),
		"triangles": (_triangle_count(cap) + _triangle_count(stem)) * caps.size(), "colliders": 0, "shadow_casters": 0}
	print("VISTA_GROVE ", JSON.stringify(vista_grove_report))

## Coarse WorldTerrain grid coordinate of column/row i (graded grid, see _add_terrain).
func _grid_coord(i: int) -> float:
	var s: float = lerpf(-1.0, 1.0, float(i) / TERRAIN_CELLS)
	return TERRAIN_HALF * signf(s) * pow(absf(s), 1.7)

## Ground under (x, z) as drawn: the detail patches where they exist, else the coarse WorldTerrain
## triangle (vertex heights from terrain_height, diagonal i1-i2), so props sit on the rendered surface.
func _mesh_ground(x: float, z: float) -> float:
	var r: float = rendered_terrain_height(x, z)
	if not is_nan(r): return r
	var c: int = clampi(floori((signf(x) * pow(absf(x) / TERRAIN_HALF, 1.0 / 1.7) + 1.0) * 0.5 * TERRAIN_CELLS), 0, TERRAIN_CELLS - 1)
	var w: int = clampi(floori((signf(z) * pow(absf(z) / TERRAIN_HALF, 1.0 / 1.7) + 1.0) * 0.5 * TERRAIN_CELLS), 0, TERRAIN_CELLS - 1)
	var x0: float = _grid_coord(c)
	var x1: float = _grid_coord(c + 1)
	var z0: float = _grid_coord(w)
	var z1: float = _grid_coord(w + 1)
	var u: float = clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	var v: float = clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	var h0: float = terrain_height(x0, z0)
	var h1: float = terrain_height(x1, z0)
	var h2: float = terrain_height(x0, z1)
	var h3: float = terrain_height(x1, z1)
	if u + v <= 1.0: return h0 + u * (h1 - h0) + v * (h2 - h0)
	return h3 + (1.0 - u) * (h2 - h3) + (1.0 - v) * (h1 - h3)

## [[mesh, transform in the model's root], ...] for an imported glTF scene (cached).
func _model_parts(path: String) -> Array:
	if _model_cache.has(path): return _model_cache[path]
	var parts: Array = []
	var scene: PackedScene = load(path) as PackedScene
	if scene != null:
		var root: Node = scene.instantiate()
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var n: Node = node
			while n != null and n != root:
				if n is Node3D: xf = (n as Node3D).transform * xf
				n = n.get_parent()
			parts.append([(node as MeshInstance3D).mesh, xf])
		root.free()
	_model_cache[path] = parts
	return parts

func _refuge_put(batches: Dictionary, path: String, at: Vector3, size: float, yaw: float, lean: Vector2 = Vector2.ZERO) -> void:
	if not batches.has(path): batches[path] = []
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), lean.x) * Basis(Vector3(0, 0, 1), lean.y) * Basis.from_scale(Vector3.ONE * size)
	(batches[path] as Array).append(Transform3D(basis, at))

## Scene copy of a kit material: a day tint toward the valley palette (darker bark, softer greens,
## lavender petals) that apply_look carries into night and rain; flower petals also glow lavender
## from their own albedo.
func _refuge_material(source: Material) -> Material:
	var base := source as StandardMaterial3D
	if base == null: return source
	var m: StandardMaterial3D = base.duplicate()
	var label: String = base.resource_name.to_lower()
	var tint := Color(1, 1, 1)
	# The kit's twisted-tree leaf card is a red tint mask (meant for engine-side colouring): use the
	# green broadleaf card instead.
	if "twistedtree" in label and "leaves" in label: m.albedo_texture = load(QN + "Leaves_NormalTree_C.png")
	if "bark" in label: tint = Color(0.6, 0.48, 0.44)
	elif "flower" in label: tint = Color(0.8, 0.68, 1.0)
	elif "grass" in label: tint = Color(0.82, 0.9, 0.58)
	elif "leaves" in label: tint = Color(0.84, 0.88, 0.76)
	m.set_meta("day_tint", base.albedo_color * tint)
	if "flower" in label:
		m.emission_enabled = true
		m.emission = Color(0.8, 0.55, 1.0)
		m.emission_texture = base.albedo_texture
		m.emission_energy_multiplier = 0.2
		_refuge_glow.append(m)
	_refuge_mats.append(m)
	return m

func _refuge_flush(batches: Dictionary) -> Dictionary:
	var stats: Dictionary = {"instances": 0, "triangles": 0, "nodes": 0, "models": {}}
	for path: String in batches:
		var list: Array = batches[path]
		var parts: Array = _model_parts(path)
		if parts.is_empty():
			stats["models"][path.get_file()] = "missing"
			continue
		stats["models"][path.get_file()] = list.size()
		for part: Array in parts:
			var mesh: Mesh = (part[0] as Mesh).duplicate()
			var local: Transform3D = part[1]
			for si: int in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(si)
				if mat == null: continue
				if not _refuge_mat_cache.has(mat): _refuge_mat_cache[mat] = _refuge_material(mat)
				(mesh as ArrayMesh).surface_set_material(si, _refuge_mat_cache[mat])
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = list.size()
			for i: int in list.size(): multi.set_instance_transform(i, (list[i] as Transform3D) * local)
			var node := MultiMeshInstance3D.new()
			node.name = "Refuge_" + path.get_file().get_basename()
			node.multimesh = multi
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(node)
			_nodes.append(node)
			stats["instances"] += list.size()
			stats["triangles"] += _triangle_count(mesh) * list.size()
			stats["nodes"] += 1
	return stats

## Screen position (x right, y up, -1..1 at the frame edges) of a world point in the vista view.
func _vista_screen(eye: Vector3, p: Vector3) -> Vector2:
	var look: Vector3 = (Vector3(VISTA_AIM.x, 90.0, VISTA_AIM.y) - eye).normalized()
	var right: Vector3 = look.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(look)
	var v: Vector3 = p - eye
	var depth: float = v.dot(look)
	if depth <= 0.01: return Vector2(INF, INF)
	return Vector2(v.dot(right) / depth / (tan(deg_to_rad(30.0)) * 16.0 / 9.0), v.dot(up) / depth / tan(deg_to_rad(30.0)))

func _vista_eye() -> Vector3:
	var g: float = rendered_terrain_height(VISTA_EYE.x, VISTA_EYE.y)
	return Vector3(VISTA_EYE.x, maxf(g if not is_nan(g) else terrain_height(VISTA_EYE.x, VISTA_EYE.y), LAKE_Y) + 1.7, VISTA_EYE.y)

## Scatter `count` copies of the models in `paths` within `radius` m of the ground hit under screen
## point (sx, sy), on rendered ground no steeper than max_slope, off the ribbons and above the lake
## (or, when `shore` is set, only within 1.5 m above the lake level).
func _refuge_scatter(batches: Dictionary, rng: RandomNumberGenerator, paths: Array, sx: float, sy: float, radius: float, count: int, size: Vector2, max_slope: float = 0.6, shore: bool = false) -> int:
	var hit: Vector3 = _vista_ray_ground(sx, sy, 900.0)
	if hit == Vector3.INF: return 0
	var placed: int = 0
	for attempt: int in count * 4:
		if placed >= count: break
		var a: float = rng.randf() * TAU
		var d: float = radius * sqrt(rng.randf())
		var x: float = hit.x + cos(a) * d
		var z: float = hit.z + sin(a) * d
		var y: float = _mesh_ground(x, z)
		if is_nan(y): continue
		var slope: float = maxf(absf(_mesh_ground(x + 0.7, z) - _mesh_ground(x - 0.7, z)), absf(_mesh_ground(x, z + 0.7) - _mesh_ground(x, z - 0.7))) / 1.4
		if slope > max_slope: continue
		if shore:
			if y < LAKE_Y - 0.4 or y > LAKE_Y + 1.5: continue
		elif y < LAKE_Y + 0.5: continue
		if _ribbon_gap(Vector2(x, z)) < 2.0: continue
		var s: float = rng.randf_range(size.x, size.y)
		_refuge_put(batches, paths[rng.randi() % paths.size()], Vector3(x, y - 0.05 * s, z), s, rng.randf() * TAU, Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06)))
		placed += 1
	return placed

## Scatter on the refuge terrace in the home frame: t m toward the eye, s m to the camera's left.
## Skips the cottage footprint, the path strip, the drop (> 8 m below home) and anything outside the
## frame's left 65%.
func _refuge_cluster(batches: Dictionary, rng: RandomNumberGenerator, paths: Array, home: Vector3, toward: Vector3, side: Vector3, t_range: Vector2, s_range: Vector2, count: int, size: Vector2, eye: Vector3) -> int:
	var placed: int = 0
	for attempt: int in count * 5:
		if placed >= count: break
		var t: float = rng.randf_range(t_range.x, t_range.y)
		var s: float = rng.randf_range(s_range.x, s_range.y)
		if t < 6.5 and absf(s) < 6.0: continue
		if absf(s - sin(t * 0.12) * 3.0) < 1.4 and t > 6.0: continue
		var p: Vector3 = home + toward * t + side * s
		p.y = _mesh_ground(p.x, p.z)
		if is_nan(p.y) or p.y < home.y - 8.0: continue
		var slope: float = maxf(absf(_mesh_ground(p.x + 0.7, p.z) - _mesh_ground(p.x - 0.7, p.z)), absf(_mesh_ground(p.x, p.z + 0.7) - _mesh_ground(p.x, p.z - 0.7))) / 1.4
		if slope > 0.9: continue
		if _vista_screen(eye, p).x > -0.3: continue
		var k: float = rng.randf_range(size.x, size.y)
		_refuge_put(batches, paths[rng.randi() % paths.size()], p - Vector3(0, 0.05 * k, 0), k, rng.randf() * TAU, Vector2(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.07, 0.07)))
		placed += 1
	return placed

func _refuge_mesh(mesh: Mesh, material: Material, xf: Transform3D, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	if material != null: node.material_override = material
	node.transform = xf
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	_static.append(node)
	return node

func _refuge_light(at: Vector3, range_m: float, label: String) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = Color("ffb35c")
	light.omni_range = range_m
	light.omni_attenuation = 1.2
	light.light_energy = 1.2
	light.shadow_enabled = false
	add_child(light)
	_refuge_lights.append(light)

## Places an imported model (all its mesh parts) scaled to `height` m on its base, yaw about Y.
func _refuge_model(path: String, at: Vector3, yaw: float, height: float, label: String, luminous: bool = false) -> bool:
	var parts: Array = _model_parts(path)
	if parts.is_empty(): return false
	var box := AABB()
	for i: int in parts.size():
		var b: AABB = (parts[i][1] as Transform3D) * (parts[i][0] as Mesh).get_aabb()
		box = b if i == 0 else box.merge(b)
	var k: float = height / maxf(box.size.y, 0.001)
	var centre := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var root := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * k), at) * Transform3D(Basis.IDENTITY, -centre)
	for i: int in parts.size():
		var mesh: Mesh = parts[i][0]
		var source := mesh.surface_get_material(0) as StandardMaterial3D if mesh.get_surface_count() > 0 else null
		var material: Material = null
		if source != null and source.albedo_texture != null:
			var prop := ShaderMaterial.new()
			prop.shader = TRIPO_SHADER
			prop.set_shader_parameter("albedo_tex", source.albedo_texture)
			if source.roughness_texture != null: prop.set_shader_parameter("rough_tex", source.roughness_texture)
			if source.normal_texture != null:
				prop.set_shader_parameter("normal_tex", source.normal_texture)
				prop.set_shader_parameter("has_normal", true)
			prop.set_meta("luminous", luminous)
			_refuge_props.append(prop)
			material = prop
		_refuge_mesh(mesh, material, root * (parts[i][1] as Transform3D), "%s_%d" % [label, i])
	return true

## The mushroom cottage: the image-to-3D model when present, else a stand-in on the giants' own cap
## mesh and shader (lavender, freckled, gold underside) over cream walls with two lit windows.
func _add_refuge_cottage() -> Dictionary:
	var at: Vector3 = refuge_home
	var yaw: float = refuge_facing
	var door: Vector3 = at + Vector3(sin(yaw), 0.0, cos(yaw)) * 3.6 + Vector3(0, 1.6, 0)
	_refuge_light(door + Vector3(sin(yaw), 0.0, cos(yaw)) * 1.2, 10.0, "RefugeDoorLight")
	if ResourceLoader.exists(COTTAGE_MODEL) and _refuge_model(COTTAGE_MODEL, at - Vector3(0, 0.3, 0), yaw, COTTAGE_HEIGHT, "RefugeCottage"):
		return {"cottage": COTTAGE_MODEL.get_file(), "height_m": COTTAGE_HEIGHT}
	var walls := CylinderMesh.new()
	walls.top_radius = 2.9
	walls.bottom_radius = 3.5
	walls.height = 5.0
	walls.radial_segments = 24
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color("cdb898")
	plaster.roughness = 0.95
	plaster.set_meta("day_tint", plaster.albedo_color)
	_refuge_mats.append(plaster)
	_refuge_mesh(walls, plaster, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, 2.2, 0)), "RefugeCottageWalls")
	# Unit cap: rim at y -0.075, crown 0.46, underside 0 at the wall radius; origin 4.6 m up.
	var cap: ArrayMesh = _cap_mesh(PackedFloat32Array([1.3, 3.1, 0.7, 2.4, 4.4, 2.0]))
	var cap_xf: Array[Transform3D] = [Transform3D(Basis(Vector3.UP, yaw + 0.4) * Basis.from_scale(Vector3(5.6, 5.0, 5.6)), at + Vector3(0, 4.6, 0))]
	var cap_tint: Array[Color] = [Color(0.35, 0, 0)]
	_add(cap, cap_xf, cap_tint, 0, "RefugeCottageCap")
	_refuge_lamp_material = StandardMaterial3D.new()
	_refuge_lamp_material.albedo_color = Color("ffcf8a")
	_refuge_lamp_material.emission_enabled = true
	_refuge_lamp_material.emission = Color("ffa040")
	_refuge_lamp_material.emission_energy_multiplier = 2.0
	var pane := SphereMesh.new()
	pane.radius = 0.45
	pane.height = 0.9
	for offset: float in [-0.75, 0.75]:
		var dir := Vector3(sin(yaw + offset), 0.0, cos(yaw + offset))
		_refuge_mesh(pane, _refuge_lamp_material, Transform3D(Basis.from_scale(Vector3(1, 1, 0.35)).rotated(Vector3.UP, yaw + offset), at + dir * 3.15 + Vector3(0, 2.6, 0)), "RefugeWindow")
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.3, 2.3, 0.3)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("6b4426")
	wood.roughness = 0.9
	wood.set_meta("day_tint", wood.albedo_color)
	_refuge_mats.append(wood)
	_refuge_mesh(door_mesh, wood, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(sin(yaw), 0.0, cos(yaw)) * 3.3 + Vector3(0, 1.15, 0)), "RefugeDoor")
	return {"cottage": "stand-in (walls + giant cap mesh)", "height_m": 9.8}

func _add_refuge_lanterns() -> int:
	var placed: int = 0
	if _refuge_lamp_material == null:
		_refuge_lamp_material = StandardMaterial3D.new()
		_refuge_lamp_material.albedo_color = Color("ffcf8a")
		_refuge_lamp_material.emission_enabled = true
		_refuge_lamp_material.emission = Color("ffa040")
		_refuge_lamp_material.emission_energy_multiplier = 2.0
	var post := BoxMesh.new()
	post.size = Vector3(0.2, LANTERN_HEIGHT, 0.2)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3a22")
	wood.roughness = 0.9
	wood.set_meta("day_tint", wood.albedo_color)
	_refuge_mats.append(wood)
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.4, 0.5, 0.4)
	for at: Vector3 in refuge_lanterns:
		var yaw: float = refuge_facing + 0.5 * float(placed)
		if not (ResourceLoader.exists(LANTERN_MODEL) and _refuge_model(LANTERN_MODEL, at, yaw, LANTERN_HEIGHT, "RefugeLantern%d" % placed)):
			_refuge_mesh(post, wood, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, LANTERN_HEIGHT * 0.5, 0)), "RefugeLanternPost%d" % placed)
			_refuge_mesh(lamp, _refuge_lamp_material, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, LANTERN_HEIGHT - 0.2, 0)), "RefugeLanternLamp%d" % placed)
		_refuge_light(at + Vector3(0, LANTERN_HEIGHT - 0.3, 0), 8.0, "RefugeLanternLight%d" % placed)
		placed += 1
	return placed

func _add_vista_refuge() -> void:
	vista_refuge_report = {"built": false}
	var eye: Vector3 = _vista_eye()
	if OS.get_environment("MUSH_REFUGE_PROBE") != "":
		var rows: Array = []
		for sy: float in [-0.95, -0.85, -0.7, -0.55, -0.4, -0.3, -0.2, -0.12, -0.05]:
			for sx: float in [-1.0, -0.85, -0.7, -0.55, -0.4, -0.25, -0.1, 0.1, 0.3, 0.5, 0.7, 0.85, 1.0]:
				var h: Vector3 = _vista_ray_ground(sx, sy, 900.0)
				if h == Vector3.INF: rows.append([sx, sy, "sky"]); continue
				rows.append([sx, sy, snappedf(h.x, 0.1), snappedf(h.y, 0.1), snappedf(h.z, 0.1), snappedf(h.distance_to(eye), 1.0)])
		print("REFUGE_PROBE eye=", eye, " ", JSON.stringify(rows))
		# Near ground around the eye: [bearing deg from the view axis, horizontal m, ground y, screen x, y of a point 0.6 m up].
		var near: Array = []
		var look_h: Vector3 = Vector3(VISTA_AIM.x - eye.x, 0.0, VISTA_AIM.y - eye.z).normalized()
		for bearing: float in [-55.0, -45.0, -35.0, -25.0, -15.0, -5.0, 5.0, 15.0, 25.0, 35.0, 45.0, 55.0]:
			for dist: float in [2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 13.0, 16.0, 20.0, 25.0, 32.0, 40.0]:
				var dir: Vector3 = look_h.rotated(Vector3.UP, deg_to_rad(-bearing))
				var p: Vector3 = eye + dir * dist
				p.y = _mesh_ground(p.x, p.z)
				var s: Vector2 = _vista_screen(eye, p + Vector3(0, 0.6, 0))
				near.append([bearing, dist, snappedf(p.y, 0.1), snappedf(s.x, 0.01), snappedf(s.y, 0.01)])
		print("REFUGE_NEAR ", JSON.stringify(near))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261027
	var batches: Dictionary = {}
	var counts: Dictionary = {}
	var trees: Array = [QN + "CommonTree_1.gltf", QN + "CommonTree_2.gltf", QN + "CommonTree_3.gltf", QN + "CommonTree_5.gltf"]
	var flowers: Array = [QN + "Flower_3_Group.gltf", QN + "Flower_4_Group.gltf"]
	var bushes: Array = [QN + "Bush_Common.gltf"]
	var low: Array = [QN + "Fern_1.gltf", QN + "Plant_1_Big.gltf", QN + "Plant_7_Big.gltf", QN + "Clover_1.gltf"]
	# The vista eye stands on a ~55 degree drop: the nearest ground in frame is the terrace 45-80 m out
	# (y 19-25 m) below the lower-left; the lake shore on the right is 290 m+ away. So the refuge sits on
	# that terrace: cottage at its back, a stepping-stone path down toward the eye, flower beds, a
	# fence on the cliff edge, broadleaf trees behind; giant glowing flowers on the drop below the
	# eye frame the corner (goal: luminous flowers at the frame's lower left).
	var home: Vector3 = _vista_ray_ground(-0.80, -0.62, 300.0)
	if home == Vector3.INF:
		vista_refuge_report["reason"] = "no terrace hit"
		return
	var toward: Vector3 = Vector3(eye.x - home.x, 0.0, eye.z - home.z).normalized()
	var side: Vector3 = toward.cross(Vector3.UP).normalized()
	refuge_home = home
	refuge_facing = atan2(toward.x, toward.z)
	# Broadleaf trees behind and left of the cottage (goal: a lush tree wall up the frame's left edge).
	var tree_n: int = 0
	for i: int in 16:
		var off: Vector3 = -toward * rng.randf_range(6.0, 30.0) + side * rng.randf_range(-6.0, 26.0)
		var p: Vector3 = home + off
		p.y = _mesh_ground(p.x, p.z)
		if p.y < home.y - 6.0: continue
		var s: Vector2 = _vista_screen(eye, p)
		if s.x > -0.6: continue
		_refuge_put(batches, trees[rng.randi() % trees.size()], p - Vector3(0, 0.3, 0), rng.randf_range(2.0, 3.2), rng.randf() * TAU, Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04)))
		tree_n += 1
	counts["trees"] = tree_n
	# Timber fence along the terrace's cliff edge (right of the cottage): the edge is traced in screen
	# space as the last terrace hit (< 110 m) before the rays drop past the cliff, then pulled 1.2 m in.
	var edge: Array[Vector3] = []
	for k: int in 9:
		var sy: float = lerpf(-0.6, -0.92, float(k) / 8.0)
		var last: Vector3 = Vector3.INF
		var sx: float = -0.75
		while sx < -0.2:
			var hit: Vector3 = _vista_ray_ground(sx, sy, 160.0)
			if hit == Vector3.INF or hit.distance_to(eye) > 110.0: break
			last = hit
			sx += 0.01
		if last != Vector3.INF: edge.append(last)
	# Stepping-stone path from the door down the terrace to its nearest visible corner (the cliff edge's
	# lowest traced point, 5 m in), lanterns at the door and the path's foot.
	var path_n: int = 0
	var stones: Array = [QN + "RockPath_Round_Small_1.gltf", QN + "RockPath_Round_Small_2.gltf", QN + "RockPath_Round_Small_3.gltf"]
	var path_from: Vector3 = home + toward * 5.5
	var path_end: Vector3 = home + toward * 30.0
	if not edge.is_empty():
		var last_edge: Vector3 = edge[edge.size() - 1]
		path_end = last_edge + Vector3(home.x - last_edge.x, 0.0, home.z - last_edge.z).normalized() * 5.0
	var bow: Vector3 = (path_from + path_end) * 0.5 + side * 4.0
	var path_len: float = path_from.distance_to(path_end)
	var steps: int = clampi(roundi(path_len / 1.2), 6, 40)
	for i: int in steps:
		var t: float = float(i) / float(steps - 1)
		var p: Vector3 = path_from.lerp(bow, t).lerp(bow.lerp(path_end, t), t)
		p += side * rng.randf_range(-0.35, 0.35)
		p.y = _mesh_ground(p.x, p.z)
		_refuge_put(batches, stones[i % stones.size()], p - Vector3(0, 0.02, 0), rng.randf_range(1.3, 1.7), rng.randf() * TAU)
		path_n += 1
	counts["path_stones"] = path_n
	# Luminous lily clumps (image-to-3D) along the path, alternating sides.
	var lily_n: int = 0
	if ResourceLoader.exists(FLOWER_MODEL):
		for i: int in 7:
			var t: float = lerpf(0.12, 0.92, float(i) / 6.0)
			var p: Vector3 = path_from.lerp(bow, t).lerp(bow.lerp(path_end, t), t) + side * (1.7 if i % 2 == 0 else -1.7) * rng.randf_range(0.9, 1.3)
			p.y = _mesh_ground(p.x, p.z)
			if _refuge_model(FLOWER_MODEL, p - Vector3(0, 0.05, 0), rng.randf() * TAU, rng.randf_range(1.2, 1.8), "RefugeLilies%d" % i, true): lily_n += 1
	counts["path_lilies"] = lily_n
	refuge_lanterns = [path_from + side * 2.6, path_end - side * 2.0]
	for i: int in refuge_lanterns.size(): refuge_lanterns[i].y = _mesh_ground(refuge_lanterns[i].x, refuge_lanterns[i].z)
	var fence_n: int = 0
	for k: int in edge.size() - 1:
		var a: Vector3 = edge[k]
		var b: Vector3 = edge[k + 1]
		var inward: Vector3 = Vector3(home.x - a.x, 0.0, home.z - a.z).normalized() * 1.2
		var run: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
		var pieces: int = maxi(1, roundi(run.length() / 2.6))
		for j: int in pieces:
			# The kit's fence runs along its local x (2 m long, 0.81 m tall); scaled 1.3 with the cottage.
			var p: Vector3 = a.lerp(b, (float(j) + 0.5) / pieces) + inward
			p.y = _mesh_ground(p.x, p.z)
			var along: Vector3 = run.normalized()
			_refuge_put(batches, QV + ("Prop_WoodenFence_Single.gltf" if fence_n == 0 else "Prop_WoodenFence_Extension1.gltf"), p, 1.3 * minf(1.0, run.length() / (2.0 * 1.3 * pieces) + 0.15), atan2(-along.z, along.x))
			fence_n += 1
	counts["fence"] = fence_n
	counts["edge_points"] = edge.size()
	# Garden: flowering bushes against the cottage, glowing flower beds and low plants on the terrace.
	counts["bushes"] = _refuge_cluster(batches, rng, bushes, home, toward, side, Vector2(2.0, 9.0), Vector2(-9.0, 9.0), 14, Vector2(1.0, 1.6), eye)
	counts["flower_beds"] = _refuge_cluster(batches, rng, flowers, home, toward, side, Vector2(6.0, 34.0), Vector2(-10.0, 12.0), 70, Vector2(0.6, 1.1), eye)
	counts["low_plants"] = _refuge_cluster(batches, rng, low, home, toward, side, Vector2(4.0, 34.0), Vector2(-12.0, 14.0), 50, Vector2(1.0, 1.8), eye)
	# A meadow sward over the terrace (goal: lush lit grass, not bare ground).
	counts["sward"] = _refuge_cluster(batches, rng, [QN + "Grass_Wispy_Short.gltf"], home, toward, side, Vector2(-4.0, 40.0), Vector2(-16.0, 18.0), 420, Vector2(0.6, 1.0), eye)
	# Giant luminous flowers on the drop just below the eye, sized so their heads enter the frame's lower-left corner.
	var giant_n: int = 0
	# Own generator, so additions elsewhere in the refuge never reshuffle the framing flowers.
	var grng := RandomNumberGenerator.new()
	grng.seed = 20261028
	var look_h: Vector3 = Vector3(VISTA_AIM.x - eye.x, 0.0, VISTA_AIM.y - eye.z).normalized()
	for i: int in 60:
		if giant_n >= 6: break
		var dir: Vector3 = look_h.rotated(Vector3.UP, deg_to_rad(grng.randf_range(30.0, 56.0)))
		var p: Vector3 = eye + dir * grng.randf_range(6.0, 12.0)
		p.y = _mesh_ground(p.x, p.z)
		var h: float = 0.0
		var head: float = grng.randf_range(-0.9, -0.74)
		while h < 9.0:
			h += 0.25
			if _vista_screen(eye, p + Vector3(0, h, 0)).y > head: break
		var size: float = h / 2.3
		if size > 3.2 or size < 1.2: continue
		var s: Vector2 = _vista_screen(eye, p + Vector3(0, h, 0))
		if s.x < -1.1 or s.x > -0.42: continue
		if ResourceLoader.exists(FLOWER_MODEL) and _refuge_model(FLOWER_MODEL, p - Vector3(0, 0.1, 0), grng.randf() * TAU, h * grng.randf_range(1.0, 1.12), "RefugeGlowFlowers%d" % giant_n, true):
			giant_n += 1
			continue
		_refuge_put(batches, flowers[grng.randi() % flowers.size()], p - Vector3(0, 0.1, 0), size * grng.randf_range(1.0, 1.15), grng.randf() * TAU, Vector2(grng.randf_range(-0.12, 0.12), grng.randf_range(-0.12, 0.12)))
		giant_n += 1
	counts["giant_flowers"] = giant_n
	var stats: Dictionary = _refuge_flush(batches)
	var cottage: Dictionary = _add_refuge_cottage()
	counts["lanterns"] = _add_refuge_lanterns()
	vista_refuge_report = {"built": true, "eye": _v3(eye), "home": _v3(home), "cottage": cottage, "counts": counts, "lights": _refuge_lights.size(), "colliders": 0, "shadow_casters": 0}
	vista_refuge_report.merge(stats)
	print("VISTA_REFUGE ", JSON.stringify(vista_refuge_report))

## Ribbon falls on the far granite walls seen from the vista (review 06/07 and the Gemini paintover:
## two or three thin falls on the central walls). Each is placed on the West Wall station whose crest
## projects nearest a vista screen x (1280 px frame) and hangs down that station's own face profile
## (_wall_face_offset, as the West Falls do), 4 m proud of the rock. [px, width m]. Visual only, on the
## West Falls shader; no collision, no shadows.
const FAR_FALLS: Array = [[742.0, 9.0], [818.0, 12.0], [905.0, 8.0]]
func _add_far_ribbon_falls() -> void:
	far_falls_report = {"built": false}
	if _wall.size() < 3: return
	var eye_ground: float = rendered_terrain_height(VISTA_EYE.x, VISTA_EYE.y)
	var eye := Vector3(VISTA_EYE.x, maxf(eye_ground if not is_nan(eye_ground) else terrain_height(VISTA_EYE.x, VISTA_EYE.y), LAKE_Y) + 1.7, VISTA_EYE.y)
	var look: Vector3 = (Vector3(VISTA_AIM.x, 90.0, VISTA_AIM.y) - eye).normalized()
	var right: Vector3 = look.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(look)
	var k_tan: float = tan(deg_to_rad(30.0))
	var project := func(p: Vector3) -> Vector2:
		var v: Vector3 = p - eye
		var z: float = maxf(v.dot(look), 1.0)
		return Vector2(640.0 + v.dot(right) / (z * k_tan * 16.0 / 9.0) * 640.0, 360.0 - v.dot(up) / (z * k_tan) * 360.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var built: Array = []
	var used: Array[int] = []
	for spec: Array in FAR_FALLS:
		var target: float = spec[0]
		var width: float = spec[1]
		var best: int = -1
		var best_dx: float = INF
		for i: int in range(1, _wall.size() - 1):
			var w: Dictionary = _wall[i]
			var h: float = float(w.top) - float(w.base)
			if h < 150.0 or absf(float(w.s) - WALL_FALLS_S) < 120.0: continue
			var toe: Vector2 = w.toe
			var nrm: Vector2 = w.normal
			if Vector2(eye.x - toe.x, eye.z - toe.y).dot(nrm) <= 0.0: continue
			var crest_off: float = _wall_face_offset(w, 1.0, h, float(w.top))
			var crest := Vector3(toe.x + nrm.x * crest_off, float(w.top), toe.y + nrm.y * crest_off)
			var sp: Vector2 = project.call(crest)
			if sp.y < 0.0 or sp.y > 400.0: continue
			var clash: bool = false
			for u: int in used: if absi(u - i) < 4: clash = true
			if clash: continue
			if absf(sp.x - target) < best_dx:
				best_dx = absf(sp.x - target)
				best = i
		if best < 0 or best_dx > 40.0:
			built.append({"px": target, "kept": false, "nearest_dx": best_dx})
			continue
		used.append(best)
		var sample: Dictionary = _wall[best]
		var toe2: Vector2 = sample.toe
		var nrm2: Vector2 = sample.normal
		var dir2: Vector2 = sample.dir
		var base: float = float(sample.base)
		var top: float = float(sample.top)
		var hh: float = top - base
		var rows: int = 40
		for j: int in rows:
			var quad: Array[Vector3] = []
			var quv: Array[Vector2] = []
			for t: float in [float(j) / rows, float(j + 1) / rows]:
				var y: float = top - 3.0 - (hh - 3.0) * t
				var q: float = clampf((y - base) / hh, 0.0, 1.0)
				var off: float = _wall_face_offset(sample, q, hh, y) + 4.0
				# Narrow at the lip, wandering a little across the face and fanning into spray at the foot
				# (dead-straight even lines read as rods, sweep 140558).
				var seed_f: float = float(used.size())
				var wdt: float = width * lerpf(0.55, 1.5, t) * (0.85 + 0.3 * sin(t * 17.0 + seed_f * 2.1)) * (1.0 + 1.6 * smoothstep(0.82, 1.0, t))
				var drift: float = sin(t * 5.3 + seed_f * 1.7) * 3.0 + sin(t * 12.7 + seed_f) * 1.2
				for k: int in 2:
					var across: float = (float(k) - 0.5) * wdt + drift
					quad.append(Vector3(toe2.x + nrm2.x * off + dir2.x * across, y, toe2.y + nrm2.y * off + dir2.y * across))
					quv.append(Vector2(float(k), t))
			for m: int in [0, 2, 1, 1, 2, 3]:
				st.set_uv(quv[m])
				st.add_vertex(quad[m])
		built.append({"px": target, "kept": true, "station_s": snappedf(float(sample.s), 1.0), "screen_dx": snappedf(best_dx, 0.1), "drop_m": snappedf(hh, 1.0), "distance_m": snappedf(eye.distance_to(Vector3(toe2.x, top, toe2.y)), 1.0)})
	var kept: int = built.filter(func(b: Dictionary) -> bool: return b.kept).size()
	far_falls_report = {"built": kept > 0, "falls": built, "colliders": 0, "shadow_casters": 0}
	print("FAR_FALLS ", JSON.stringify(far_falls_report))
	if kept == 0: return
	st.generate_normals()
	var water := ShaderMaterial.new()
	water.shader = FALLS_SHADER
	_geology_materials.append(water)
	var node := MeshInstance3D.new()
	node.name = "FarRibbonFalls"
	node.mesh = st.commit()
	node.material_override = water
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_static.append(node)

func _add_horizon_giants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261033
	var cap: ArrayMesh = _cap_mesh(PackedFloat32Array([2.4, 5.1, 0.3, 3.7, 1.2, 4.6]))
	var stem: ArrayMesh = _stem_mesh()
	var caps: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	var cap_tints: Array[Color] = []
	var stem_tints: Array[Color] = []
	for row: Array in HORIZON_GIANTS:
		var x: float = row[0]; var z: float = row[1]; var r: float = row[2]; var h: float = row[3]
		var yaw: float = rng.randf_range(0.0, TAU)
		var stem_r: float = r * 0.15
		var lean: Vector3 = Basis(Vector3.UP, yaw) * Vector3(STEM_BEND * stem_r, 0.0, 0.0)
		var tilt := Basis(Vector3(1, 0, 0), rng.randf_range(-0.05, 0.05)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.05, 0.05))
		caps.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * tilt * Basis.from_scale(Vector3(r, r * 0.5, r)), Vector3(x + lean.x, h, z + lean.z)))
		var base: float = -260.0
		stems.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(stem_r, h + r * 0.5 * 0.22 - base, stem_r)), Vector3(x, base, z)))
		cap_tints.append(Color(rng.randf(), 0, 0))
		stem_tints.append(Color(rng.randf(), 1, 1))
	# A shader copy that writes FOG (capped haze), for these two materials only.
	var capped := Shader.new()
	capped.code = SHADER.code.replace("// FOG_CAP_HOOK", "if (fog_cap.a >= 0.0) FOG = vec4(fog_cap.rgb, fog_cap.a);\n\t//")
	_add(cap, caps, cap_tints, 0, "HorizonCanopies")
	_horizon_cap_material = (_nodes[_nodes.size() - 1] as MultiMeshInstance3D).material_override
	_horizon_cap_material.shader = capped
	_add(stem, stems, stem_tints, 1, "HorizonStems")
	_horizon_stem_material = (_nodes[_nodes.size() - 1] as MultiMeshInstance3D).material_override
	_horizon_stem_material.shader = capped
	_add_cap_tendrils(caps, "HorizonTendrils", 47)
	horizon_giants_report = {"built": true, "giants": caps.size(), "triangles": (_triangle_count(cap) + _triangle_count(stem)) * caps.size(), "colliders": 0, "shadow_casters": 0, "note": "outside the walkable world; not part of GIANTS"}

## Distance to the nearest walking-ribbon sample (<= 4 m spacing) within 16 m, else INF.
func _ribbon_gap(at: Vector2) -> float:
	if _ribbon_hash.is_empty():
		for path: Variant in [route, slice_route]:
			if not is_instance_valid(path) or not path.valid: continue
			var pts: PackedVector3Array = path._p
			for i: int in range(1, pts.size()):
				var a := Vector2(pts[i - 1].x, pts[i - 1].z)
				var b := Vector2(pts[i].x, pts[i].z)
				var steps: int = maxi(1, ceili(a.distance_to(b) / 4.0))
				for k: int in steps + 1:
					var q: Vector2 = a.lerp(b, float(k) / float(steps))
					var key := Vector2i(floori(q.x / 16.0), floori(q.y / 16.0))
					if not _ribbon_hash.has(key): _ribbon_hash[key] = []
					(_ribbon_hash[key] as Array).append(q)
	var gap: float = INF
	var cell := Vector2i(floori(at.x / 16.0), floori(at.y / 16.0))
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var list: Variant = _ribbon_hash.get(cell + Vector2i(dx, dz))
			if list == null: continue
			for q: Vector2 in list: gap = minf(gap, at.distance_to(q))
	return gap

func _add_meadow_erratics() -> void:
	erratic_report = {"built": false}
	# Walking-ribbon samples every <= 4 m in a 16 m hash, for fast clearance queries.
	var gaps: Dictionary = {}
	for path: Variant in [route, slice_route]:
		if not is_instance_valid(path) or not path.valid: continue
		var pts: PackedVector3Array = path._p
		for i: int in range(1, pts.size()):
			var a := Vector2(pts[i - 1].x, pts[i - 1].z)
			var b := Vector2(pts[i].x, pts[i].z)
			var steps: int = maxi(1, ceili(a.distance_to(b) / 4.0))
			for k: int in steps + 1:
				var q: Vector2 = a.lerp(b, float(k) / float(steps))
				var key := Vector2i(floori(q.x / 16.0), floori(q.y / 16.0))
				if not gaps.has(key): gaps[key] = []
				(gaps[key] as Array).append(q)
	var meshes: Array[ArrayMesh] = [Erratics.erratic_mesh(4101), Erratics.erratic_mesh(4102), Erratics.erratic_mesh(4103)]
	var poses: Array = [[], [], []]
	var tints: Array = [[], [], []]
	var rejected: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var field := FastNoiseLite.new()
	field.seed = 77
	field.frequency = 0.006
	var leads: Array = []
	var eye_ground: float = rendered_terrain_height(VISTA_EYE.x, VISTA_EYE.y)
	var eye := Vector3(VISTA_EYE.x, maxf(eye_ground if not is_nan(eye_ground) else terrain_height(VISTA_EYE.x, VISTA_EYE.y), LAKE_Y) + 1.7, VISTA_EYE.y)
	var look: Vector3 = (Vector3(VISTA_AIM.x, 90.0, VISTA_AIM.y) - eye).normalized()
	var right: Vector3 = look.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(look)
	var anchor_hits: Array = []
	for anchor: Array in ERRATIC_ANCHORS:
		var ray: Vector3 = (look + right * float(anchor[0]) * tan(deg_to_rad(30.0)) * 16.0 / 9.0 + up * float(anchor[1]) * tan(deg_to_rad(30.0))).normalized()
		for step: int in range(2, 400):
			var q: Vector3 = eye + ray * float(step)
			var g: float = rendered_terrain_height(q.x, q.z)
			if q.y < (g if not is_nan(g) else terrain_height(q.x, q.z)):
				leads.append([Vector2(q.x, q.z), float(anchor[2]), false])
				anchor_hits.append([snappedf(q.x, 0.1), snappedf(q.z, 0.1), step])
				break
	var cols: int = ceili(ERRATIC_REGION.size.x / ERRATIC_CELL)
	var rows: int = ceili(ERRATIC_REGION.size.y / ERRATIC_CELL)
	for j: int in rows:
		for i: int in cols:
			var centre: Vector2 = ERRATIC_REGION.position + Vector2(float(i) + rng.randf(), float(j) + rng.randf()) * ERRATIC_CELL
			var density: float = field.get_noise_2dv(centre) * 0.5 + 0.5
			if rng.randf() > smoothstep(0.45, 0.8, density) * 0.55: continue
			leads.append([centre, rng.randf_range(3.0, 8.0), true])
	var clusters: int = 0
	var anchors: int = 0
	var min_gap: float = INF
	for lead: Array in leads:
		var spots: Array = [[lead[0], lead[1]]]
		if lead[2] or float(lead[1]) > 4.0:
			for m: int in rng.randi_range(1, 4) if lead[2] else 4:
				spots.append([lead[0] + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(float(lead[1]) * 1.1, float(lead[1]) * 2.4), float(lead[1]) * rng.randf_range(0.25, 0.6)])
		var placed_lead: bool = false
		for spot: Array in spots:
			var at: Vector2 = spot[0]
			var size: float = spot[1]
			var fit: Vector2 = _erratic_fit(at, size, gaps, 0.5 if lead[2] else 1.2)
			if is_nan(fit.x):
				var why: String = ["clearing", "root", "giant", "ribbon", "stream", "steep", "water"][int(fit.y)]
				rejected[why] = int(rejected.get(why, 0)) + 1
				if spot == spots[0] and lead[2]: break
				continue
			min_gap = minf(min_gap, fit.y)
			var variant: int = rng.randi_range(0, 2)
			var sy: float = size * rng.randf_range(0.7, 1.0)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(size * rng.randf_range(1.0, 1.5), sy, size * rng.randf_range(0.8, 1.15)))
			# Unit base plane at y = -0.4; bury the block a quarter of its height below the lowest ground.
			(poses[variant] as Array).append(Transform3D(basis, Vector3(at.x, fit.x + sy * (0.4 - 0.32), at.y)))
			(tints[variant] as Array).append(Color(rng.randf(), 0.0, 0.0))
			if spot == spots[0]: placed_lead = true
		if placed_lead:
			if lead[2]: clusters += 1
			else: anchors += 1
	var blocks: int = 0
	var triangles: int = 0
	for v: int in 3:
		if (poses[v] as Array).is_empty(): continue
		var xs: Array[Transform3D] = []
		xs.assign(poses[v])
		var cs: Array[Color] = []
		cs.assign(tints[v])
		_add(meshes[v], xs, cs, 2, "MeadowErratics_%d" % v)
		var erratic_material: ShaderMaterial = (_nodes[_nodes.size() - 1] as MultiMeshInstance3D).material_override
		erratic_material.set_shader_parameter("rock_gain", 1.05)
		erratic_material.set_shader_parameter("moss_cover", 1.0)
		_soft_materials.append(erratic_material)
		blocks += xs.size()
		triangles += _triangle_count(meshes[v]) * xs.size()
	rock_count += blocks
	erratic_report = {"built": blocks > 0, "clusters": clusters, "vista_anchor_blocks": anchors, "vista_anchor_hits_x_z_m": anchor_hits, "blocks": blocks, "triangles": triangles,
		"mesh_triangles": meshes.map(func(m: ArrayMesh) -> int: return _triangle_count(m)), "rejected": rejected,
		"min_ribbon_gap_m": snappedf(min_gap, 0.1), "region_xz": [ERRATIC_REGION.position.x, ERRATIC_REGION.position.y, ERRATIC_REGION.end.x, ERRATIC_REGION.end.y],
		"colliders": 0, "shadow_casters": 0}
	print("ERRATICS ", JSON.stringify(erratic_report))

## Lowest rendered ground under an erratic's footprint (x) and its ribbon clearance (y), or NAN
## with the rejection index in y.
func _erratic_fit(at: Vector2, size: float, gaps: Dictionary, max_slope: float = 0.5) -> Vector2:
	if baked_extent.grow(30.0).has_point(at): return Vector2(NAN, 0)
	if at.distance_to(HERO) < 60.0: return Vector2(NAN, 1)
	for g: Array in GIANTS:
		if at.distance_to(Vector2(float(g[0]), float(g[1]))) < 10.0 + float(g[2]) * 0.2 + size: return Vector2(NAN, 2)
	var gap: float = INF
	var cell := Vector2i(floori(at.x / 16.0), floori(at.y / 16.0))
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var list: Variant = gaps.get(cell + Vector2i(dx, dz))
			if list == null: continue
			for q: Vector2 in list: gap = minf(gap, at.distance_to(q))
	if gap < 6.0 + size * 1.6: return Vector2(NAN, 3)
	if _stream_distance(at.x, at.y).x < 16.0 + size: return Vector2(NAN, 4)
	if terrain_slope(at.x, at.y) > max_slope: return Vector2(NAN, 5)
	var lowest: float = INF
	for corner: Vector2 in [Vector2.ZERO, Vector2(size, 0.0), Vector2(-size, 0.0), Vector2(0.0, size), Vector2(0.0, -size)]:
		var r: float = rendered_terrain_height(at.x + corner.x, at.y + corner.y)
		lowest = minf(lowest, r if not is_nan(r) else terrain_height(at.x + corner.x, at.y + corner.y))
	if lowest < LAKE_Y + 1.0: return Vector2(NAN, 6)
	return Vector2(lowest, gap)

func _add_shore_groves() -> void:
	shore_groves_report = {"built": false}
	if _tree_templates.is_empty(): return
	# 1. Belt clumps leave the carpet multimeshes (kept in ShoreBeltClumps as the far LOD).
	var targets: Array[Transform3D] = []
	var target_colors: Array[Color] = []
	var clump_mesh: Mesh = null
	var clump_material: Material = null
	for node: GeometryInstance3D in _static:
		if not String(node.name).begins_with("ForestCarpet_"): continue
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		var keep: Array[Transform3D] = []
		var keep_colors: Array[Color] = []
		for i: int in multi.instance_count:
			var pose: Transform3D = multi.get_instance_transform(i)
			var o: Vector3 = pose.origin
			# The outlet stream's lower reach stays open water: belt clumps standing on it hid the
			# outflow from the vista (review 08). Those clumps are dropped.
			if o.y >= SHORE_BELT_Y.x and o.y <= SHORE_BELT_Y.y and _stream_distance(o.x, o.z).x < SHORE_STREAM_CLEAR:
				continue
			if o.y >= SHORE_BELT_Y.x and o.y <= SHORE_BELT_Y.y and Vector2(o.x, o.z).distance_to(LAKE_CENTER) <= SHORE_BELT_RADIUS and o.x < SHORE_BELT_MAX_X:
				targets.append(pose)
				target_colors.append(multi.get_instance_color(i))
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
	if targets.is_empty(): return
	var far := MultiMesh.new()
	far.transform_format = MultiMesh.TRANSFORM_3D
	far.use_colors = true
	far.mesh = clump_mesh
	far.instance_count = targets.size()
	for i: int in targets.size():
		far.set_instance_transform(i, targets[i])
		far.set_instance_color(i, target_colors[i])
	shore_clumps = MultiMeshInstance3D.new()
	shore_clumps.name = "ShoreBeltClumps"
	shore_clumps.multimesh = far
	shore_clumps.material_override = clump_material
	shore_clumps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shore_clumps.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	shore_clumps.visibility_range_end = 1700.0
	shore_clumps.visible = false
	add_child(shore_clumps)
	_static.append(shore_clumps)
	# 2. Layered groves within SHORE_GROVE_BUDGET: every clump becomes 1-2 low, wide shrub masses of
	# the copied trees' broken ring-crown mesh (60-80 % of its width, keeps the ground-level mass);
	# then, widest clumps first, one tree (two for clumps >= 40 m) rises out of it with its trunk
	# parts and three crowns (the top one and the two widest-reaching), crowns scaled 1.6x.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261029
	var shrub_part: Dictionary = {}
	var tops: Array = []
	for template: Array in _tree_templates:
		var top: float = 0.0
		var crowns: Array = []
		for part: Dictionary in template:
			top = maxf(top, (part.local * (part.mesh as Mesh).get_aabb()).end.y)
			if part.kind == "LayeredCanopies":
				crowns.append(part)
				if shrub_part.is_empty(): shrub_part = part
		crowns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.local.origin.y > b.local.origin.y)
		var chosen: Array = crowns.slice(0, 1)
		var lateral: Array = crowns.slice(1)
		lateral.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.local.origin.x, a.local.origin.z).length() > Vector2(b.local.origin.x, b.local.origin.z).length())
		chosen.append_array(lateral.slice(0, 2))
		tops.append({"height": maxf(top, 1.0), "crowns": chosen})
	var batches: Dictionary = {}
	var simple: Dictionary = {}
	var shrub_box: AABB = (shrub_part.mesh as Mesh).get_aabb()
	var shrub_tris: int = _triangle_count(shrub_part.mesh)
	var shrub_mesh: Mesh = _simplified_crown(shrub_part.mesh, simple)
	var triangles: int = 0
	var shrubs: int = 0
	var order: Array = range(targets.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (targets[a] * clump_mesh.get_aabb()).size.x > (targets[b] * clump_mesh.get_aabb()).size.x)
	for k: int in order:
		var pose: Transform3D = targets[k]
		# Rendered clump size (the transform scale is about half of it).
		var box: AABB = pose * clump_mesh.get_aabb()
		var width: float = maxf(box.size.x, box.size.z)
		var height: float = box.size.y
		var centre := Vector2(pose.origin.x, pose.origin.z)
		for n: int in (1 if width < 28.0 else 2):
			var spot: Vector2 = centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * width * rng.randf_range(0.0, 0.22)
			var ground: float = terrain_height(spot.x, spot.y)
			if ground < LAKE_Y + 0.6: continue
			var w: float = width * rng.randf_range(0.6, 0.8)
			var h: float = height * rng.randf_range(0.4, 0.55)
			var scale := Vector3(w / shrub_box.size.x, h / shrub_box.size.y, w / shrub_box.size.z)
			var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(scale)
			_tree_batch(batches, "LayeredCanopies", shrub_mesh, shrub_part.material, Vector2i.ZERO, "all", Transform3D(basis, Vector3(spot.x, ground - 0.3 - shrub_box.position.y * scale.y, spot.y)))
			shrubs += 1
			triangles += shrub_tris
	var trees: int = 0
	var skipped: int = 0
	var crowns_kept: int = 0
	for k: int in order:
		var pose: Transform3D = targets[k]
		# Rendered clump size (the transform scale is about half of it).
		var box: AABB = pose * clump_mesh.get_aabb()
		var width: float = maxf(box.size.x, box.size.z)
		var height: float = box.size.y
		var centre := Vector2(pose.origin.x, pose.origin.z)
		for n: int in (2 if width >= 40.0 else 1):
			var pick: int = rng.randi_range(0, _tree_templates.size() - 1)
			var cost: int = 0
			for part: Dictionary in _tree_templates[pick]:
				if part.kind != "LayeredCanopies" or part in tops[pick].crowns: cost += _triangle_count(part.mesh)
			if triangles + cost > SHORE_GROVE_BUDGET:
				skipped += 1
				continue
			var want: float = height * (rng.randf_range(1.05, 1.3) if n == 0 else rng.randf_range(0.7, 0.95))
			var size: float = clampf(want / float(tops[pick].height), 0.6, 2.8)
			var spot: Vector2 = centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * width * rng.randf_range(0.05, 0.3)
			var ground: float = terrain_height(spot.x, spot.y)
			if ground < LAKE_Y + 0.6 or terrain_slope(spot.x, spot.y) > 0.6:
				skipped += 1
				continue
			var root := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * size), Vector3(spot.x, ground - 0.35, spot.y))
			# One batch cell for the whole belt (about 330 x 470 m), so the groves stay within the node budget.
			var cell := Vector2i.ZERO
			trees += 1
			triangles += cost
			for part: Dictionary in _tree_templates[pick]:
				if part.kind == "LayeredCanopies":
					if not part in tops[pick].crowns: continue
					crowns_kept += 1
					var fuller := Transform3D(part.local.basis * Basis.from_scale(Vector3.ONE * 1.6), part.local.origin)
					_tree_batch(batches, part.kind, _simplified_crown(part.mesh, simple), part.material, cell, "all", root * fuller)
					continue
				_tree_batch(batches, part.kind, part.mesh, part.material, cell, "all", root * part.local)
	shore_groves = Node3D.new()
	shore_groves.name = "ShoreGroves"
	add_child(shore_groves)
	var built: int = 0
	for key: String in batches:
		var node: MultiMeshInstance3D = _tree_node(batches[key], "ShoreGroves_")
		node.visibility_range_end = SHORE_GROVE_END
		remove_child(node)
		shore_groves.add_child(node)
		built += _triangle_count(batches[key].mesh) * node.multimesh.instance_count
	set_shore_groves(true)
	shore_groves_report = {"built": true, "belt": {"origin_y": [SHORE_BELT_Y.x, SHORE_BELT_Y.y], "lake_radius_m": SHORE_BELT_RADIUS, "max_x": SHORE_BELT_MAX_X},
		"clumps_replaced": targets.size(), "clump_triangles_moved_to_far_lod": _triangle_count(clump_mesh) * targets.size(), "shrubs": shrubs, "trees": trees, "trees_skipped_budget_or_ground": skipped, "crowns": crowns_kept,
		"triangles": built, "selection_triangles_full_detail": triangles, "built_budget_triangles": SHORE_GROVE_BUILT_BUDGET,
		"simplified_crowns": simple.values().map(func(entry: Array) -> Dictionary: return entry[1]), "nodes": batches.size(), "budget_triangles": SHORE_GROVE_BUDGET, "grove_range_end_m": SHORE_GROVE_END, "belt_clumps_hidden_while_groves_on": true, "colliders": 0, "shadow_casters": 0}

## Groves on (belt clumps hidden), or the previous look (belt clumps, groves hidden).
## Diagnostic toggle for same-frame evidence.
func set_shore_groves(enabled: bool) -> void:
	if is_instance_valid(shore_groves): shore_groves.visible = enabled
	if is_instance_valid(shore_clumps): shore_clumps.visible = not enabled

## Leaf-card decimation of a crown mesh, cached per source mesh in `cache` as [mesh, stats]:
## triangles grouped into connected leaf cards (shared vertices), every SHORE_LEAF_KEEP-th card
## kept and scaled by SHORE_LEAF_SCALE about its centre. All vertex channels are carried over;
## the source mesh is never modified.
func _simplified_crown(source: Mesh, cache: Dictionary) -> Mesh:
	var key: int = source.get_instance_id()
	if cache.has(key): return cache[key][0]
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indexed: bool = arrays[Mesh.ARRAY_INDEX] != null
	var indices := PackedInt32Array()
	if indexed: indices = arrays[Mesh.ARRAY_INDEX]
	else:
		indices.resize(vertices.size())
		for i: int in vertices.size(): indices[i] = i
	var parent := PackedInt32Array()
	parent.resize(vertices.size())
	for i: int in vertices.size(): parent[i] = i
	var find := func(start: int) -> int:
		var root: int = start
		while parent[root] != root: root = parent[root]
		return root
	# Non-indexed meshes repeat shared corners: join vertices at the same position (0.1 mm).
	if not indexed:
		var seen: Dictionary = {}
		for v: int in vertices.size():
			var cell := Vector3i(roundi(vertices[v].x * 10000.0), roundi(vertices[v].y * 10000.0), roundi(vertices[v].z * 10000.0))
			if seen.has(cell):
				var a: int = find.call(seen[cell])
				var b: int = find.call(v)
				if a != b: parent[b] = a
			else: seen[cell] = v
	for t: int in range(0, indices.size(), 3):
		var a: int = find.call(indices[t])
		for k: int in [1, 2]:
			var b: int = find.call(indices[t + k])
			if a != b: parent[b] = a
	var cards: Dictionary = {}
	for t: int in range(0, indices.size(), 3):
		var root: int = find.call(indices[t])
		if not cards.has(root): cards[root] = []
		cards[root].append(t)
	var keep_vertices: Dictionary = {}
	var kept_triangles := PackedInt32Array()
	var ordinal: int = 0
	for root: int in cards:
		ordinal += 1
		if ordinal % SHORE_LEAF_KEEP != 0: continue
		var centre := Vector3.ZERO
		var used: Dictionary = {}
		for t: int in cards[root]:
			for k: int in 3: used[indices[t + k]] = true
		for v: int in used: centre += vertices[v]
		centre /= float(used.size())
		for v: int in used: keep_vertices[v] = centre
		for t: int in cards[root]:
			kept_triangles.append_array([indices[t], indices[t + 1], indices[t + 2]])
	var remap: Dictionary = {}
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	var order: Array = keep_vertices.keys()
	order.sort()
	for i: int in order.size(): remap[order[i]] = i
	for channel: int in Mesh.ARRAY_MAX:
		if channel == Mesh.ARRAY_INDEX or arrays[channel] == null: continue
		var src: Variant = arrays[channel]
		var size: int = src.size() / vertices.size()
		if channel == Mesh.ARRAY_VERTEX:
			var out := PackedVector3Array()
			for v: int in order: out.append(keep_vertices[v] + (vertices[v] - keep_vertices[v]) * SHORE_LEAF_SCALE)
			out_arrays[channel] = out
			continue
		var dst: Variant = src.duplicate()
		dst.resize(order.size() * size)
		for i: int in order.size():
			for s: int in size: dst[i * size + s] = src[order[i] * size + s]
		out_arrays[channel] = dst
	var out_indices := PackedInt32Array()
	for i: int in kept_triangles.size(): out_indices.append(remap[kept_triangles[i]])
	if indexed: out_arrays[Mesh.ARRAY_INDEX] = out_indices
	else:
		# Non-indexed source: emit kept corners in triangle order (no index buffer).
		for channel: int in Mesh.ARRAY_MAX:
			if channel == Mesh.ARRAY_INDEX or out_arrays[channel] == null: continue
			var src: Variant = out_arrays[channel]
			var size: int = src.size() / order.size()
			var dst: Variant = src.duplicate()
			dst.resize(out_indices.size() * size)
			for i: int in out_indices.size():
				for s: int in size: dst[i * size + s] = src[out_indices[i] * size + s]
			out_arrays[channel] = dst
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	if source.surface_get_material(0) != null: mesh.surface_set_material(0, source.surface_get_material(0))
	var stats := {"source_triangles": indices.size() / 3, "indexed": indexed, "cards": cards.size(), "kept_cards": cards.size() / SHORE_LEAF_KEEP, "triangles": _triangle_count(mesh), "keep_every": SHORE_LEAF_KEEP, "card_scale": SHORE_LEAF_SCALE}
	cache[key] = [mesh, stats]
	return mesh

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

# --- Geology landmark: the West Wall and Falls ---

## Toe samples every WALL_STEP m along a Catmull-Rom curve through WALL_TOE, and the coarse
## signed-distance mask. Plan geometry only (no terrain heights), so it can run before the
## terrain is built and every terrain query sees the same landform.
func _plan_wall() -> void:
	var dense: Array[Vector3] = []
	for i: int in WALL_TOE.size() - 1:
		var p0: Vector3 = WALL_TOE[maxi(i - 1, 0)]
		var p1: Vector3 = WALL_TOE[i]
		var p2: Vector3 = WALL_TOE[i + 1]
		var p3: Vector3 = WALL_TOE[mini(i + 2, WALL_TOE.size() - 1)]
		for k: int in 24:
			var t: float = float(k) / 24.0
			dense.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	dense.append(WALL_TOE[WALL_TOE.size() - 1])
	var s: float = 0.0
	var next: float = 0.0
	for i: int in dense.size() - 1:
		var a := Vector2(dense[i].x, dense[i].z)
		var b := Vector2(dense[i + 1].x, dense[i + 1].z)
		var piece: float = a.distance_to(b)
		while next <= s + piece:
			var t: float = (next - s) / maxf(piece, 0.001)
			_wall.append({"s": next, "toe": a.lerp(b, t), "relief": maxf(0.0, lerpf(dense[i].y, dense[i + 1].y, t))})
			next += WALL_STEP
		s += piece
	for i: int in _wall.size():
		var d: Vector2 = (_wall[mini(i + 1, _wall.size() - 1)].toe - _wall[maxi(i - 1, 0)].toe).normalized()
		_wall[i]["normal"] = Vector2(-d.y, d.x)
		_wall[i]["dir"] = d
		# The hanging-valley notch the falls leave from.
		_wall[i]["relief"] = float(_wall[i].relief) - WALL_NOTCH.x * exp(-pow((float(_wall[i].s) - WALL_FALLS_S) / WALL_NOTCH.y, 2.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for tier: int in 2:
		var edge_s: float = -rng.randf_range(0.0, 80.0)
		while edge_s < s + 200.0:
			_facets[tier].append([edge_s, rng.randf_range(-14.0, 18.0), rng.randf_range(-0.1, 0.1), rng.randf_range(9.0, 18.0) if rng.randf() < 0.35 else 0.0, rng.randf()])
			edge_s += rng.randf_range(70.0, 190.0)
	# Gullies carve the rim into separate masses; the falls run in their own drainage gully.
	var g: float = rng.randf_range(120.0, 260.0)
	while g < s - 80.0:
		if absf(g - WALL_FALLS_S) > 160.0 and absf(g - WALL_PROW_S) > 140.0:
			_gullies.append([g, rng.randf_range(45.0, 90.0), rng.randf_range(35.0, 80.0), rng.randf_range(40.0, 120.0)])
		g += rng.randf_range(260.0, 520.0)
	_gullies.append([WALL_FALLS_S, 62.0, 70.0, 0.0])
	for i: int in _wall.size():
		var rs: float = float(_wall[i].s)
		for gully: Array in _gullies:
			var ds: float = absf(rs - float(gully[0]))
			var rim: float = float(gully[1]) * 1.4
			if ds < rim: _wall[i]["relief"] = float(_wall[i].relief) - float(gully[3]) * pow(1.0 - ds / rim, 1.4)
	var at: int = clampi(roundi(WALL_FALLS_S / WALL_STEP), 0, _wall.size() - 1)
	var foot: Vector2 = _wall[at].toe + _wall[at].normal * 85.0
	_basin = Vector3(foot.x, foot.y, BASIN_DEPTH)
	# Coarse mask: signed distance along the toe normal (positive toward the valley) and the
	# position along the toe; INF beyond the wall's ends.
	var box := Rect2(_wall[0].toe, Vector2.ZERO)
	for sample: Dictionary in _wall: box = box.expand(sample.toe)
	_wall_grid_box = box.grow(800.0).intersection(Rect2(-TERRAIN_HALF, -TERRAIN_HALF, TERRAIN_HALF * 2.0, TERRAIN_HALF * 2.0))
	var cols: int = ceili(_wall_grid_box.size.x / WALL_GRID_CELL) + 1
	var rows: int = ceili(_wall_grid_box.size.y / WALL_GRID_CELL) + 1
	_wall_grid.resize(cols * rows)
	_wall_grid_s.resize(cols * rows)
	var coarse: Array = []
	for i: int in range(0, _wall.size(), 5): coarse.append(_wall[i])
	for r: int in rows:
		for c2: int in cols:
			var here: Vector2 = _wall_grid_box.position + Vector2(c2, r) * WALL_GRID_CELL
			var best: float = INF
			var n: float = INF
			var along: float = 0.0
			for i: int in coarse.size() - 1:
				var a: Vector2 = coarse[i].toe
				var ab: Vector2 = coarse[i + 1].toe - a
				var raw: float = (here - a).dot(ab) / maxf(ab.length_squared(), 0.0001)
				var t: float = clampf(raw, 0.0, 1.0)
				var gap: float = here.distance_to(a + ab * t)
				if gap < best:
					best = gap
					var ends: bool = (i == 0 and raw < 0.0) or (i == coarse.size() - 2 and raw > 1.0)
					var normal: Vector2 = Vector2(-ab.y, ab.x).normalized()
					n = INF if ends else (here - (a + ab * t)).dot(normal)
					along = lerpf(float(coarse[i].s), float(coarse[i + 1].s), t)
			_wall_grid[r * cols + c2] = n
			_wall_grid_s[r * cols + c2] = along
	escarpment_report = {"built": false, "toe_length_m": s, "samples": _wall.size(), "mask_cells": cols * rows}

## Outlet stream plan: from the basin's lake-facing rim, step downhill toward the lake (look-ahead
## steepest descent within +-40 degrees of a heading pulled toward the lake), smooth, then give it
## a monotonic bed from just under the pool level to below the lake surface.
func _plan_stream() -> void:
	if _basin.x == INF: return
	var basin := Vector2(_basin.x, _basin.y)
	var heading: Vector2 = (LAKE_CENTER - basin).normalized()
	var p: Vector2 = basin + heading * BASIN_RADIUS
	var path: Array[Vector2] = [p]
	for i: int in 220:
		var lake_dir: Vector2 = (LAKE_CENTER - p).normalized()
		var bias: Vector2 = (heading * 0.4 + lake_dir * 0.6).normalized()
		var best: Vector2 = bias
		var best_h: float = INF
		for deg: float in [-40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0]:
			var d: Vector2 = bias.rotated(deg_to_rad(deg))
			var look: float = terrain_height(p.x + d.x * 25.0, p.y + d.y * 25.0) + absf(deg) * 0.04
			if look < best_h:
				best_h = look
				best = d
		heading = best
		p += heading * STREAM_STEP
		path.append(p)
		# End inside the lake's water (the lake surface disc reaches 300 m from its centre).
		if p.distance_to(LAKE_CENTER) < 250.0 and terrain_height(p.x, p.y) < LAKE_Y + 0.5: break
	var smooth: Array[Vector2] = []
	for i: int in path.size():
		var acc := Vector2.ZERO
		var n: int = 0
		for j: int in range(maxi(0, i - 2), mini(path.size(), i + 3)):
			acc += path[j]
			n += 1
		smooth.append(path[i] if i == 0 or i == path.size() - 1 else acc / n)
	# Meanders: the descent-following path ran nearly straight down the ravine and read as a ruled line
	# from the vista (review 03/04). A lateral sine offset (amplitude STREAM_MEANDER.x m, wavelength
	# STREAM_MEANDER.y m), tapered to zero at the pool outlet and at the lake entry.
	var base_path: Array[Vector2] = smooth.duplicate()
	for i: int in range(1, base_path.size() - 1):
		var t: float = float(i) / float(base_path.size() - 1)
		var taper: float = smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.82, 1.0, t))
		var tangent: Vector2 = (base_path[i + 1] - base_path[i - 1]).normalized()
		# Single wave: bend radius A*(2pi/L)^2 -> ~56 m, well above the 11 m sheet half-width (an added
		# 2.3x harmonic made ~12 m bends and the sheet folded into the banks, geology 235108).
		var wave: float = sin(float(i) * STREAM_STEP / STREAM_MEANDER.y * TAU + 0.6)
		smooth[i] = base_path[i] + Vector2(-tangent.y, tangent.x) * STREAM_MEANDER.x * wave * taper
	var basin_ground: float = terrain_height(basin.x, basin.y)
	var pool_y: float = basin_ground + BASIN_DEPTH * 0.62
	var bed: float = pool_y - 1.5
	var ground: PackedFloat32Array = []
	for i: int in smooth.size():
		var g: float = terrain_height(smooth[i].x, smooth[i].y)
		ground.append(g)
		if i > 0: bed = minf(bed - 0.15, g - 3.0)
		bed = maxf(bed, LAKE_Y - 3.0)
		_stream.append(Vector3(smooth[i].x, bed, smooth[i].y))
	_stream_box = Rect2(smooth[0], Vector2.ZERO)
	for q: Vector2 in smooth: _stream_box = _stream_box.expand(q)
	_stream_box = _stream_box.grow(STREAM_VALLEY)
	for i: int in _stream.size() - 1:
		var a := Vector2(_stream[i].x, _stream[i].z)
		var b := Vector2(_stream[i + 1].x, _stream[i + 1].z)
		var lo: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * STREAM_VALLEY
		var hi: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * STREAM_VALLEY
		for bx: int in range(floori(lo.x / STREAM_BUCKET), floori(hi.x / STREAM_BUCKET) + 1):
			for bz: int in range(floori(lo.y / STREAM_BUCKET), floori(hi.y / STREAM_BUCKET) + 1):
				var key := Vector2i(bx, bz)
				if not _stream_buckets.has(key): _stream_buckets[key] = []
				_stream_buckets[key].append(i)
	_stream_grid_cols = ceili(_stream_box.size.x / STREAM_CELL) + 1
	var grid_rows: int = ceili(_stream_box.size.y / STREAM_CELL) + 1
	_stream_grid.resize(_stream_grid_cols * grid_rows)
	_stream_grid_d.resize(_stream_grid_cols * grid_rows)
	for r: int in grid_rows:
		for k: int in _stream_grid_cols:
			var at: Vector2 = _stream_box.position + Vector2(k, r) * STREAM_CELL
			var frame: Vector2 = _stream_segment_distance(at.x, at.y)
			_stream_grid_d[r * _stream_grid_cols + k] = frame.x
			_stream_grid[r * _stream_grid_cols + k] = INF if frame.x > STREAM_VALLEY else frame.y + maxf(0.0, frame.x - STREAM_BED) * STREAM_BANK
	var carve_max: float = 0.0
	for i: int in _stream.size(): carve_max = maxf(carve_max, ground[i] - _stream[i].y)
	stream_report = {"built": false, "length_m": STREAM_STEP * (_stream.size() - 1), "points": _stream.size(), "pool_level_m": pool_y, "basin_ground_at_plan_m": basin_ground, "bed_start_m": _stream[0].y, "bed_end_m": _stream[_stream.size() - 1].y, "ground_profile_m": [ground[0], ground[ground.size() / 2], ground[ground.size() - 1]], "max_centre_carve_m": carve_max, "reached_lake": Vector2(_stream[_stream.size() - 1].x, _stream[_stream.size() - 1].z).distance_to(LAKE_CENTER) < 250.0 and terrain_height(_stream[_stream.size() - 1].x, _stream[_stream.size() - 1].z) < LAKE_Y + 0.5}
	_stream_carving = true

## Distance to the stream centreline (x) and the carve target height (y) from the precomputed
## grid (bilinear); x = INF away from the valley.
func _stream_distance(x: float, z: float) -> Vector2:
	if _stream_grid.is_empty() or not _stream_box.has_point(Vector2(x, z)): return Vector2(INF, 0.0)
	var f: Vector2 = (Vector2(x, z) - _stream_box.position) / STREAM_CELL
	var k: int = mini(floori(f.x), _stream_grid_cols - 2)
	var r: int = mini(floori(f.y), _stream_grid.size() / _stream_grid_cols - 2)
	var w: Vector2 = f - Vector2(k, r)
	var i: int = r * _stream_grid_cols + k
	var d: float = lerpf(lerpf(_stream_grid_d[i], _stream_grid_d[i + 1], w.x), lerpf(_stream_grid_d[i + _stream_grid_cols], _stream_grid_d[i + _stream_grid_cols + 1], w.x), w.y)
	var t4 := [_stream_grid[i], _stream_grid[i + 1], _stream_grid[i + _stream_grid_cols], _stream_grid[i + _stream_grid_cols + 1]]
	for v: float in t4:
		if v == INF: return Vector2(d, INF)
	return Vector2(d, lerpf(lerpf(t4[0], t4[1], w.x), lerpf(t4[2], t4[3], w.x), w.y))

## Exact distance to the stream centreline (x) and the bed height there (y), by segment search.
func _stream_segment_distance(x: float, z: float) -> Vector2:
	if _stream.is_empty() or not _stream_box.has_point(Vector2(x, z)): return Vector2(INF, 0.0)
	var key := Vector2i(floori(x / STREAM_BUCKET), floori(z / STREAM_BUCKET))
	if not _stream_buckets.has(key): return Vector2(INF, 0.0)
	var here := Vector2(x, z)
	var best: float = INF
	var bed: float = 0.0
	for i: int in _stream_buckets[key]:
		var a := Vector2(_stream[i].x, _stream[i].z)
		var ab := Vector2(_stream[i + 1].x, _stream[i + 1].z) - a
		var t: float = clampf((here - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var gap: float = here.distance_to(a + ab * t)
		if gap < best:
			best = gap
			bed = lerpf(_stream[i].y, _stream[i + 1].y, t)
	return Vector2(best, bed)

## The valley the stream has cut: lowers ground to the bed plus banks, never raises it.
func _stream_carve(x: float, z: float, height: float) -> float:
	var frame: Vector2 = _stream_distance(x, z)
	if frame.x > STREAM_VALLEY or frame.y == INF: return height
	return minf(height, frame.y)

## 1 on the stream's channel and the plunge pool's rim, fading out over ~22 m (wet gravel banks).
func _riparian(x: float, z: float) -> float:
	var wet: float = 0.0
	var frame: Vector2 = _stream_distance(x, z)
	if frame.x != INF: wet = 1.0 - smoothstep(STREAM_BED, STREAM_BED + 14.0, frame.x)
	if _basin.x != INF: wet = maxf(wet, 1.0 - smoothstep(BASIN_RADIUS * 1.0, BASIN_RADIUS * 1.6, Vector2(x, z).distance_to(Vector2(_basin.x, _basin.y))))
	return wet

## Water/terrain clearance over the whole ribbon surface, not only its vertices: each ribbon
## triangle is sampled on a barycentric grid (15 points) and compared with the rendered coarse
## terrain triangle beneath it. Clearance is the vertical gap times the terrain normal's y, i.e. the
## separation along the terrain normal (penetration depth when negative, as in Millington 13.2.1).
## Samples over the lake's own water (terrain below LAKE_Y) are counted separately.
func _water_clearance(mesh: ArrayMesh) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var samples: int = 0
	var buried: int = 0
	var worst: float = INF
	var worst_at := Vector3.ZERO
	var over_max: float = -INF
	var over_lake: int = 0
	var gaps := PackedFloat32Array()
	for t: int in range(0, idx.size(), 3):
		var a: Vector3 = v[idx[t]]
		var b: Vector3 = v[idx[t + 1]]
		var c: Vector3 = v[idx[t + 2]]
		for i: int in 5:
			for j: int in 5 - i:
				var w1: float = float(i) / 4.0
				var w2: float = float(j) / 4.0
				var q: Vector3 = a * (1.0 - w1 - w2) + b * w1 + c * w2
				var ground: float = _coarse_height(q.x, q.z)
				if ground < LAKE_Y:
					over_lake += 1
					continue
				var dx: float = _coarse_height(q.x + 0.5, q.z) - ground
				var dz: float = _coarse_height(q.x, q.z + 0.5) - ground
				var ny: float = 1.0 / sqrt(1.0 + (dx * dx + dz * dz) / 0.25)
				var gap: float = (q.y - ground) * ny
				samples += 1
				gaps.append(gap)
				if gap < -0.02: buried += 1
				if gap < worst:
					worst = gap
					worst_at = q
				over_max = maxf(over_max, q.y - ground)
	gaps.sort()
	return {"samples": samples, "samples_over_lake_water": over_lake, "buried_samples": buried, "min_clearance_along_normal_m": worst, "min_at": _v3(worst_at),
		"p05_clearance_m": gaps[int(gaps.size() * 0.05)] if gaps.size() > 0 else 0.0, "median_clearance_m": gaps[gaps.size() / 2] if gaps.size() > 0 else 0.0, "max_over_bed_m": over_max}

## Labelled hero view (a new camera): from the walkable knoll at the route's end, eye height,
## looking north-west across the falls corner of the West Wall, so the existing sun (east-north-
## east, 22 degrees) rakes the wall from the right instead of lighting it head-on.
func hero_view_pose() -> Dictionary:
	if not is_instance_valid(route) or not route.valid: return {}
	var eye: Vector3 = route.get_end_point() + Vector3.UP * 1.7
	return {"position": eye, "target": Vector3(-560.0, 170.0, -560.0), "fov": 55.0}

## Labelled basin view (a new camera): on the stream's vegetation-free valley, 40 m over
## the rendered floor, looking upstream at the basin and the falls' foot. Empty without a stream.
func stream_view_pose() -> Dictionary:
	if _stream.size() < 6: return {}
	var at: Vector3 = _stream[int(_stream.size() * 0.18)]
	var eye := Vector3(at.x, _coarse_height(at.x, at.z) + 40.0, at.z)
	return {"position": eye, "target": Vector3(_basin.x, _stream[0].y + 25.0, _basin.y), "fov": 60.0}

## Height of the rendered coarse terrain mesh (graded grid, triangulated as in _add_terrain).
func _coarse_height(x: float, z: float) -> float:
	var cells: float = float(TERRAIN_CELLS)
	var to_s := func(v: float) -> float: return signf(v) * pow(absf(v) / TERRAIN_HALF, 1.0 / 1.7)
	var fx: float = (to_s.call(x) + 1.0) * 0.5 * cells
	var fz: float = (to_s.call(z) + 1.0) * 0.5 * cells
	var c0: int = clampi(floori(fx), 0, TERRAIN_CELLS - 1)
	var r0: int = clampi(floori(fz), 0, TERRAIN_CELLS - 1)
	var grid := func(i: int) -> float: var s: float = lerpf(-1.0, 1.0, float(i) / cells); return TERRAIN_HALF * signf(s) * pow(absf(s), 1.7)
	var x0: float = grid.call(c0)
	var x1: float = grid.call(c0 + 1)
	var z0: float = grid.call(r0)
	var z1: float = grid.call(r0 + 1)
	var u: float = clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	var v: float = clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	var h0: float = terrain_height(x0, z0)
	var h1: float = terrain_height(x1, z0)
	var h2: float = terrain_height(x0, z1)
	var h3: float = terrain_height(x1, z1)
	if u + v <= 1.0: return h0 + u * (h1 - h0) + v * (h2 - h0)
	return h3 + (1.0 - u) * (h2 - h3) + (1.0 - v) * (h1 - h3)

## Signed distance from the West Wall's toe (positive toward the valley) and position along it,
## from the coarse mask; x = INF away from the wall.
func _wall_frame(x: float, z: float) -> Vector2:
	if _wall_grid.is_empty() or not _wall_grid_box.has_point(Vector2(x, z)): return Vector2(INF, 0.0)
	var cols: int = ceili(_wall_grid_box.size.x / WALL_GRID_CELL) + 1
	var f: Vector2 = (Vector2(x, z) - _wall_grid_box.position) / WALL_GRID_CELL
	var c0: int = mini(floori(f.x), cols - 2)
	var r0: int = mini(floori(f.y), _wall_grid.size() / cols - 2)
	var w: Vector2 = f - Vector2(c0, r0)
	var i: int = r0 * cols + c0
	var n4 := [_wall_grid[i], _wall_grid[i + 1], _wall_grid[i + cols], _wall_grid[i + cols + 1]]
	for v: float in n4:
		if v == INF: return Vector2(INF, 0.0)
	var n: float = lerpf(lerpf(n4[0], n4[1], w.x), lerpf(n4[2], n4[3], w.x), w.y)
	var s: float = lerpf(lerpf(_wall_grid_s[i], _wall_grid_s[i + 1], w.x), lerpf(_wall_grid_s[i + cols], _wall_grid_s[i + cols + 1], w.x), w.y)
	return Vector2(n, s)

## Wall height above the valley-floor reference at a position along the toe.
func _wall_relief(s: float) -> float:
	if _wall.is_empty(): return 0.0
	return float(_wall[clampi(roundi(s / WALL_STEP), 0, _wall.size() - 1)].relief)

## 1 inside and just in front of the wall where it stands, 0 from 160 m in front of the toe.
func _wall_suppress(x: float, z: float) -> float:
	var frame: Vector2 = _wall_frame(x, z)
	if frame.x == INF: return 0.0
	return (1.0 - smoothstep(40.0, 160.0, frame.x)) * smoothstep(60.0, 200.0, _wall_relief(frame.y))

## True for a point inside or behind the standing rock.
func _inside_wall(x: float, z: float) -> bool:
	var frame: Vector2 = _wall_frame(x, z)
	return frame.x != INF and frame.x < 15.0 and frame.x > -900.0 and _wall_relief(frame.y) > 120.0

## Face offset along the normal (negative = set back) at height q (0 toe .. 1 crest) of a
## wall of height h: batter, a sheer prow, a recessed falls channel, slow exfoliation bulges,
## sparse vertical joints and a rounded shoulder.
func _wall_face_offset(sample: Dictionary, q: float, h: float, y: float) -> float:
	var s: float = sample.s
	var prow: float = exp(-pow((s - WALL_PROW_S) / 90.0, 2.0))
	var falls: float = exp(-pow((s - WALL_FALLS_S) / 34.0, 2.0))
	var n: float = -WALL_BATTER * 0.6 * (1.0 - 0.8 * prow) * h * q
	n += 34.0 * prow * (1.0 - 0.4 * q)
	# Talus flare at the foot (kept low under the falls, where the plunge basin is).
	n += 55.0 * pow(1.0 - smoothstep(0.0, 0.16, q), 2.0) * (1.0 - 0.7 * falls)
	# Strata benches: each ledge sets the face back above it, undulating along the wall and
	# ending where its seed says it is absent, so horizontal breaks cut the vertical faces.
	for bench: Vector3 in WALL_BENCHES:
		var level: float = bench.x + _terrace_noise.get_noise_2d(s * 0.6, bench.z * 10.0) * 0.05
		var present: float = smoothstep(-0.15, 0.15, _hill_noise.get_noise_2d(s * 0.45, bench.z * 13.0))
		n -= present * bench.y * (0.6 + 0.4 * _hill_noise.get_noise_2d(s * 1.1, bench.z)) * smoothstep(level, level + 0.025, q)
	# Gullies: V-notches carved into the face, deepest at the rim, narrowing downward, with a
	# talus cone spilling out at the foot.
	for gully: Array in _gullies:
		var ds: float = absf(s - float(gully[0]))
		var half: float = float(gully[1]) * (0.45 + 0.55 * q)
		if ds < half: n -= float(gully[2]) * (0.25 + 0.75 * q) * pow(1.0 - ds / half, 1.6)
		var cone: float = float(gully[1]) * 1.6
		if ds < cone and float(gully[3]) > 0.0: n += 30.0 * pow(1.0 - ds / cone, 2.0) * (1.0 - smoothstep(0.0, 0.2, q))
	var calm: float = 1.0 - exp(-pow((s - WALL_FALLS_S) / 80.0, 2.0))
	n += _hill_noise.get_noise_2d(s * 1.6, y * 1.4) * 3.0 * calm * smoothstep(0.0, 0.08, q)
	# Broad granite planes meeting at aretes and dihedrals, with dark fracture recesses.
	n += _wall_facet(s, q, h).x * calm * smoothstep(0.0, 0.1, q)
	n -= h * 0.06 * pow(maxf(0.0, (q - 0.8) / 0.2), 2.0)
	return n

## Facet field at (s, q) on a face of height h: x = offset (m), y = panel tone, z = recess
## (1 at a fracture's floor). Linear between boundaries, so each panel is a near-planar face with
## its own yaw and tilt; the two tiers blend across q 0.42-0.56 so panels do not stack.
func _wall_facet(s: float, q: float, h: float) -> Vector3:
	var out := Vector3.ZERO
	for tier: int in 2:
		var edges: Array = _facets[tier]
		var k: int = 0
		while k < edges.size() - 2 and float(edges[k + 1][0]) <= s: k += 1
		var a: Array = edges[k]
		var b: Array = edges[k + 1]
		var t: float = clampf((s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1.0), 0.0, 1.0)
		var offset: float = lerpf(float(a[1]) + float(a[2]) * h * (q - 0.5), float(b[1]) + float(b[2]) * h * (q - 0.5), t)
		var recess: float = 0.0
		for edge: Array in [a, b]:
			var gap: float = absf(s - float(edge[0]))
			if float(edge[3]) > 0.0 and gap < 14.0:
				var cut: float = pow(1.0 - gap / 14.0, 1.2)
				offset -= float(edge[3]) * cut
				recess = maxf(recess, cut)
		var here := Vector3(offset, float(a[4]), recess)
		out = here if tier == 0 else out.lerp(here, smoothstep(0.42, 0.56, q))
	return out

func _add_wall() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Crest rows behind the shoulder (set back, rise) and one back row below ground.
	var crest: Array[Vector2] = [Vector2(-18.0, 4.0), Vector2(-60.0, 9.0), Vector2(-130.0, 10.0), Vector2(-220.0, 2.0), Vector2(-320.0, -24.0)]
	var face_rows: int = 64
	var rows: int = 1 + face_rows + 1 + crest.size() + 1
	var outward_ok: int = 0
	var outward_checked: int = 0
	var tallest: float = 0.0
	var finite := true
	for sample: Dictionary in _wall:
		var toe: Vector2 = sample.toe
		var nrm: Vector2 = sample.normal
		var base: float = terrain_height(toe.x, toe.y)
		# Irregular crest: slow domes and saddles along the top.
		var top: float = maxf(base, WALL_FLOOR + float(sample.relief) + _hill_noise.get_noise_2d(float(sample.s) * 1.2, 900.0) * 28.0 * smoothstep(100.0, 300.0, float(sample.relief)))
		var h: float = top - base
		tallest = maxf(tallest, h)
		sample["base"] = base
		sample["top"] = top
		var dome: float = exp(-pow((float(sample.s) - WALL_DOME_S) / 140.0, 2.0))
		var wet: float = exp(-pow((float(sample.s) - WALL_FALLS_S) / 70.0, 2.0))
		var points: Array = [[0.0, base - 45.0, 1.0, 0.0, 0.0, 0.5, 0.0]]
		for j: int in face_rows + 1:
			var q: float = float(j) / face_rows
			var y: float = base + h * q
			# Drip: wet streaks hang just below each ledge lip that exists here.
			var drip: float = 0.0
			for bench: Vector3 in WALL_BENCHES:
				var level: float = bench.x + _terrace_noise.get_noise_2d(float(sample.s) * 0.6, bench.z * 10.0) * 0.05
				var present: float = smoothstep(-0.15, 0.15, _hill_noise.get_noise_2d(float(sample.s) * 0.45, bench.z * 13.0))
				if q < level: drip = maxf(drip, present * (1.0 - smoothstep(0.0, 0.14, level - q)))
			var facet: Vector3 = _wall_facet(float(sample.s), q, h)
			var here: float = _wall_face_offset(sample, q, h, y)
			# Occlusion from the actual geometry: how far this point sits behind the mean of its
			# neighbours along the wall (+-24 m) and up/down the face (+-6% of height), i.e. inside
			# a gully, recess, dihedral or under a bench overhang. Normalised to 0..1 at 12 m.
			var i_s: int = _wall.find(sample)
			var left: Dictionary = _wall[maxi(i_s - 3, 0)]
			var right: Dictionary = _wall[mini(i_s + 3, _wall.size() - 1)]
			var around: float = (_wall_face_offset(left, q, h, y) + _wall_face_offset(right, q, h, y) + _wall_face_offset(sample, clampf(q - 0.06, 0.0, 1.0), h, y - 0.06 * h) + _wall_face_offset(sample, clampf(q + 0.06, 0.0, 1.0), h, y + 0.06 * h)) * 0.25
			var occlusion: float = clampf((around - here) / 12.0, 0.0, 1.0)
			points.append([here, y, 1.0 - smoothstep(0.9, 1.0, q), q, drip, facet.y, maxf(facet.z, occlusion)])
		var shoulder: float = points[points.size() - 1][0]
		# Crest: setbacks and heights vary along the wall, so the rows behind the shoulder form an
		# irregular rounded upland instead of parallel terraces running the whole length.
		for r: int in crest.size():
			var row: Vector2 = crest[r]
			var setback: float = row.x * (0.4 + 0.6 * smoothstep(0.0, 200.0, h)) * (1.0 + 0.35 * _terrace_noise.get_noise_2d(float(sample.s) * 1.3, float(r) * 40.0))
			var rise: float = row.y + 38.0 * dome * (1.0 - absf(row.x + 120.0) / 200.0) + 24.0 * _hill_noise.get_noise_2d(float(sample.s) * 1.7, float(r) * 55.0)
			points.append([shoulder + setback, top + rise * smoothstep(0.0, 120.0, h), 0.0, 1.0, 0.0, 0.5, 0.0])
		points.append([shoulder - 420.0, base - 60.0, 0.0, 1.0, 0.0, 0.5, 0.0])
		for point: Array in points:
			var at := Vector3(toe.x + nrm.x * float(point[0]), float(point[1]), toe.y + nrm.y * float(point[0]))
			finite = finite and at.is_finite()
			st.set_color(Color(float(point[2]), wet, float(point[3]), float(point[4])))
			st.set_uv(Vector2(float(sample.s), float(point[1]) - base))
			st.set_uv2(Vector2(float(point[5]), float(point[6])))
			st.add_vertex(at)
	for i: int in _wall.size() - 1:
		for j: int in rows - 1:
			var a: int = i * rows + j
			var b: int = a + rows
			var c: int = a + 1
			var d: int = b + 1
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(d)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	# Winding: the face's mid-height normal must look into the valley wherever the wall stands.
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for i: int in range(0, _wall.size(), 10):
		if float(_wall[i].top) - float(_wall[i].base) < 120.0: continue
		var nv: Vector3 = normals[i * rows + 1 + face_rows / 2]
		outward_checked += 1
		if Vector2(nv.x, nv.z).dot(_wall[i].normal) > 0.0: outward_ok += 1
	var granite := ShaderMaterial.new()
	granite.shader = GRANITE_SHADER
	granite.set_shader_parameter("snowline", SNOWLINE)
	_geology_materials.append(granite)
	var node := MeshInstance3D.new()
	node.name = "WestWall"
	node.mesh = mesh
	node.material_override = granite
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	_static.append(node)
	var falls: Dictionary = _add_falls()
	var ice: Dictionary = _add_ice(granite)
	# Clearances: route and slice points, and giant caps, all well away from the toe.
	var route_gap: float = INF
	for path: Variant in [route, slice_route]:
		if not is_instance_valid(path) or not path.valid: continue
		for point: Vector3 in path._p:
			for i: int in range(0, _wall.size(), 4): route_gap = minf(route_gap, Vector2(point.x, point.z).distance_to(_wall[i].toe))
	var giant_gap: float = INF
	for row: Array in GIANTS:
		for i: int in range(0, _wall.size(), 2): giant_gap = minf(giant_gap, Vector2(row[0], row[1]).distance_to(_wall[i].toe) - float(row[2]))
	escarpment_report.merge({"built": true, "vertices": _wall.size() * rows, "triangles": (_wall.size() - 1) * (rows - 1) * 2, "rows_per_sample": rows, "finite": finite,
		"face_outward": [outward_ok, outward_checked], "tallest_face_m": tallest, "falls": falls, "ice": ice, "gullies": _gullies.size(), "benches": WALL_BENCHES.size(), "facet_edges": [_facets[0].size(), _facets[1].size()], "route_clearance_m": route_gap, "giant_cap_clearance_m": giant_gap,
		"collision": "none (far layer)", "shadows": "off"}, true)
	escarpment_report["passed"] = finite and outward_checked > 0 and outward_ok == outward_checked and route_gap > 250.0 and giant_gap > 40.0 and bool(falls.get("built", false)) and bool(ice.get("built", false))

## Valley mist pooled at the feet of the West Wall (review: the middle distance had no layers and
## no height mist). Two staggered rows of soft vertical sheets stand in front of the face (40-90 m
## and 150-200 m out), dense at their base and feathered everywhere else; the shader softens them
## against the scene through the depth buffer and fades them near the camera. One mesh, one
## draw call, no collider, no shadow; built once at startup.
const MIST_STEP := 10
var wall_mist_report: Dictionary = {"built": false}
func _add_wall_mist() -> void:
	if _wall.size() < 20: return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sheets: int = 0
	for row: Array in [[0, 40.0, 50.0, 150.0, 150.0, -15.0], [MIST_STEP / 2, 150.0, 50.0, 230.0, 95.0, -10.0]]:
		for i: int in range(int(row[0]), _wall.size(), MIST_STEP):
			var sample: Dictionary = _wall[i]
			if not sample.has("top") or float(sample.top) - float(sample.base) < 120.0: continue
			var nrm: Vector2 = sample.normal
			var along := Vector2(-nrm.y, nrm.x)
			var jitter: float = _hill_noise.get_noise_2d(float(sample.s) * 2.3, float(row[1]))
			var centre: Vector2 = sample.toe + nrm * (float(row[1]) + float(row[2]) * (0.5 + 0.5 * jitter))
			var ground: float = terrain_height(centre.x, centre.y)
			var half_w: float = float(row[3]) * (0.5 + 0.1 * jitter)
			var height: float = float(row[4]) * (0.85 + 0.3 * absf(jitter))
			var y0: float = ground + float(row[5])
			var a: Vector2 = centre - along * half_w
			var b: Vector2 = centre + along * half_w
			var corners: Array = [[Vector3(a.x, y0, a.y), Vector2(0, 0)], [Vector3(b.x, y0, b.y), Vector2(1, 0)], [Vector3(b.x, y0 + height, b.y), Vector2(1, 1)], [Vector3(a.x, y0 + height, a.y), Vector2(0, 1)]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(corners[k][1])
				st.add_vertex(corners[k][0])
			sheets += 1
	if sheets == 0: return
	var material := ShaderMaterial.new()
	material.shader = MIST_SHADER
	_geology_materials.append(material)
	var node := MeshInstance3D.new()
	node.name = "WallMist"
	node.mesh = st.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	_static.append(node)
	wall_mist_report = {"built": true, "sheets": sheets, "triangles": sheets * 2, "draw_calls": 1, "colliders": 0, "shadows": "off"}

## Valley mist banks (concepts: layered mist lying in the valley between the landmarks). Soft
## vertical sheets on the valley-mist shader, low over the lowland around the lake and the outlet
## ravine, each turned toward the valley's main viewpoints (vista/knoll side) so it reads as a bank,
## not a card; depth-softened against terrain and faded near the camera. One draw, no shadows.
func _add_valley_mist() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sheets: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261027
	var look_from := Vector2(300.0, 40.0)
	var z: float = -980.0
	while z < -120.0:
		var x: float = -560.0 + rng.randf_range(0.0, 50.0)
		while x < 380.0:
			var at := Vector2(x + rng.randf_range(-25.0, 25.0), z + rng.randf_range(-25.0, 25.0))
			x += rng.randf_range(80.0, 120.0)
			var ground: float = terrain_height(at.x, at.y)
			if ground > VALLEY_MIST_TOP or _inside_wall(at.x, at.y) or at.distance_to(look_from) < 260.0: continue
			if not hero.is_empty() and at.distance_to(Vector2(hero.base.x, hero.base.z)) < 70.0: continue
			var face: Vector2 = (look_from - at).normalized()
			var along := Vector2(-face.y, face.x).rotated(rng.randf_range(-0.35, 0.35))
			var half_w: float = rng.randf_range(80.0, 140.0)
			var height: float = rng.randf_range(28.0, 55.0)
			var y0: float = maxf(ground, LAKE_Y) - 6.0
			var a: Vector2 = at - along * half_w
			var b: Vector2 = at + along * half_w
			var corners: Array = [[Vector3(a.x, y0, a.y), Vector2(0, 0)], [Vector3(b.x, y0, b.y), Vector2(1, 0)], [Vector3(b.x, y0 + height, b.y), Vector2(1, 1)], [Vector3(a.x, y0 + height, a.y), Vector2(0, 1)]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(corners[k][1])
				st.add_vertex(corners[k][0])
			sheets += 1
		z += rng.randf_range(70.0, 100.0)
	if sheets == 0: return
	var material := ShaderMaterial.new()
	material.shader = MIST_SHADER
	material.set_shader_parameter("strength", VALLEY_MIST_STRENGTH)
	material.set_shader_parameter("holes", 0.6)
	_geology_materials.append(material)
	var node := MeshInstance3D.new()
	node.name = "ValleyMist"
	node.mesh = st.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	_static.append(node)
	wall_mist_report["valley_sheets"] = sheets

## The falls: a free-falling ribbon leaving the notch lip just clear of the recessed channel,
## bowing outward as it drops and spreading, plus three crossed soft mist sheets at its foot.
func _add_falls() -> Dictionary:
	var at: int = clampi(roundi(WALL_FALLS_S / WALL_STEP), 1, _wall.size() - 2)
	var sample: Dictionary = _wall[at]
	var toe: Vector2 = sample.toe
	var nrm: Vector2 = sample.normal
	var dir: Vector2 = sample.dir
	var base: float = sample.base
	var top: float = sample.top
	var h: float = top - base
	if h < 150.0: return {"built": false, "reason": "no wall height at the falls"}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 56
	var min_clear: float = INF
	var pool_y: float = terrain_height(_basin.x, _basin.y) + BASIN_DEPTH * 0.62
	stream_report["basin_ground_at_build_m"] = terrain_height(_basin.x, _basin.y)
	# The pool spills through its outlet: its surface is no higher than the outlet's floor allows.
	if not _stream.is_empty(): pool_y = minf(pool_y, _coarse_height(_stream[0].x, _stream[0].z) + 0.6)
	for j: int in rows + 1:
		var t: float = float(j) / rows
		var y: float = top - 2.0 - (top - 2.0 - pool_y) * t
		var q: float = clampf((y - base) / h, 0.0, 1.0)
		var face: float = _wall_face_offset(sample, q, h, y)
		# Source: meltwater slides on the gully floor for the first stretch (rock contact),
		# then leaves the rock and free-falls, bowing out toward the plunge basin.
		var free: float = smoothstep(0.12, 0.24, t)
		var out: float = face + lerpf(1.5, 6.0 + 60.0 * pow(maxf(0.0, t - 0.18) / 0.82, 1.4), free)
		min_clear = minf(min_clear, out - face)
		var width: float = lerpf(12.0, 22.0, smoothstep(0.0, 0.2, t)) + 52.0 * pow(t, 1.3)
		for k: int in 3:
			var across: float = (float(k) / 2.0 - 0.5) * width
			st.set_uv(Vector2(float(k) / 2.0, t))
			st.add_vertex(Vector3(toe.x + nrm.x * out + dir.x * across, y, toe.y + nrm.y * out + dir.y * across))
	for j: int in rows:
		for k: int in 2:
			var a: int = j * 3 + k
			st.add_index(a); st.add_index(a + 3); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(a + 3); st.add_index(a + 4)
	st.generate_normals()
	var water := ShaderMaterial.new()
	water.shader = FALLS_SHADER
	_geology_materials.append(water)
	var ribbon := MeshInstance3D.new()
	ribbon.name = "WestFalls"
	ribbon.mesh = st.commit()
	ribbon.material_override = water
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)
	_static.append(ribbon)
	# Receiving basin: water in the carved depression at the foot.
	var pool := MeshInstance3D.new()
	pool.name = "WestFallsPool"
	var disc := CylinderMesh.new()
	disc.top_radius = BASIN_RADIUS * 1.25
	disc.bottom_radius = BASIN_RADIUS * 1.25
	disc.height = 0.2
	disc.radial_segments = 32
	disc.rings = 1
	pool.mesh = disc
	var pool_water := ShaderMaterial.new()
	pool_water.shader = LAKE_SHADER
	pool_water.set_shader_parameter("shallow", Color(0.20, 0.50, 0.52))
	_geology_materials.append(pool_water)
	pool.material_override = pool_water
	pool.position = Vector3(_basin.x, pool_y, _basin.y)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	_static.append(pool)
	_add_stream_water(pool_y)
	# Spray: soft sheets over the basin, taller where the water lands.
	var mist_st := SurfaceTool.new()
	mist_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foot := Vector3(_basin.x - nrm.x * 20.0, pool_y + 40.0, _basin.y - nrm.y * 20.0)
	for k: int in 3:
		var side: Vector2 = dir.rotated(float(k) * PI / 3.0)
		var half := Vector3(side.x, 0.0, side.y) * 95.0
		var quad: Array[Vector3] = [foot - half - Vector3.UP * 40.0, foot + half - Vector3.UP * 40.0, foot + half + Vector3.UP * 90.0, foot - half + Vector3.UP * 90.0]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for m: int in [0, 1, 2, 0, 2, 3]:
			mist_st.set_uv(uvs[m])
			mist_st.add_vertex(quad[m])
	mist_st.generate_normals()
	var mist := ShaderMaterial.new()
	mist.shader = FALLS_SHADER
	mist.set_shader_parameter("mist", true)
	_geology_materials.append(mist)
	var veil := MeshInstance3D.new()
	veil.name = "WestFallsMist"
	veil.mesh = mist_st.commit()
	veil.material_override = mist
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(veil)
	_static.append(veil)
	# Rising spray plume over the plunge (review 03: the foot is hidden from the vista behind the bush
	# hill, and the spray read as a flat lens): four crossed sheets on the valley-mist shader, dense at
	# the base and feathered upward, standing ~220 m so it shows above the hill. One draw, no shadows.
	var plume_st := SurfaceTool.new()
	plume_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plume_base := Vector3(_basin.x - nrm.x * 10.0, pool_y - 8.0, _basin.y - nrm.y * 10.0)
	for k: int in 4:
		var side: Vector2 = dir.rotated(float(k) * PI / 4.0)
		var half := Vector3(side.x, 0.0, side.y) * 55.0
		var quad: Array[Vector3] = [plume_base - half, plume_base + half, plume_base + half + Vector3.UP * 220.0, plume_base - half + Vector3.UP * 220.0]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for m: int in [0, 1, 2, 0, 2, 3]:
			plume_st.set_uv(uvs[m])
			plume_st.add_vertex(quad[m])
	var plume_material := ShaderMaterial.new()
	plume_material.shader = MIST_SHADER
	plume_material.set_shader_parameter("strength", 0.95)
	plume_material.set_shader_parameter("billow", 1.0)
	_geology_materials.append(plume_material)
	var plume := MeshInstance3D.new()
	plume.name = "WestFallsPlume"
	plume.mesh = plume_st.commit()
	plume.material_override = plume_material
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plume)
	_static.append(plume)
	return {"built": true, "width_m": [12.0, 86.0], "contact_fraction": 0.18, "pool": _v3(pool.position), "pool_radius_m": BASIN_RADIUS * 1.25, "lip": _v3(Vector3(toe.x + nrm.x * (_wall_face_offset(sample, 1.0, h, top) + 6.0), top, toe.y + nrm.y * (_wall_face_offset(sample, 1.0, h, top) + 6.0))), "foot": _v3(foot), "drop_m": top - pool_y, "min_face_clearance_m": min_clear, "ribbon_triangles": rows * 4, "mist_triangles": 6, "plume": {"sheets": 4, "height_m": 220.0, "width_m": 110.0, "shader": "prototype_mist"}}

## Stream water: a ribbon laid on the rendered (coarse) valley floor along the carved channel,
## from the pool's outlet to the lake surface, flowing downstream; plus clearance and sightline
## evidence in stream_report.
func _add_stream_water(pool_y: float) -> void:
	if _stream.size() < 3: return
	# Water sheet draped on the rendered bed: rows every 2 m along the channel, 7 columns 2 m
	# apart across it, each vertex WATER_DEPTH above the rendered coarse terrain (lake level over
	# the lake's own water). The sheet's planar facets are 2 m across, so the terrain's creases
	# beneath them deviate far less than the offset; _water_clearance verifies the whole surface.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 0.42 m (was 0.35): with meanders the sheet crosses one terrain crease near (-353, -478) where
	# 0.35 left 2-4 samples 5 cm under the bed (geology 235213, 235346).
	var depth: float = 0.42
	# 22 m wide (was 12 m) inside the 32 m flat bed: from the vista the stream was a 2-4 px thread
	# (review 03/04); 12 columns keep the draped facets 2 m across, as before (9 columns at 2.75 m
	# buried 4 of 62,710 clearance samples by 2 cm, geology 210127).
	var columns: int = 12
	var half: float = 11.0
	var spacing: float = 2.0
	var length: float = STREAM_STEP * float(_stream.size() - 1)
	var rows: int = int(length / spacing) + 1
	var steep_max: float = 0.0
	var floating: float = 0.0
	var above_banks: float = -INF
	var worst: Array = []
	var last_mid: float = pool_y
	for r: int in rows:
		var d: float = minf(float(r) * spacing, length)
		var seg: int = mini(int(d / STREAM_STEP), _stream.size() - 2)
		var f: float = (d - float(seg) * STREAM_STEP) / STREAM_STEP
		var a := Vector2(_stream[seg].x, _stream[seg].z)
		var b := Vector2(_stream[seg + 1].x, _stream[seg + 1].z)
		var centre: Vector2 = a.lerp(b, f)
		# Tangent blended across segment joints (the meandering centreline turns at every joint; a
		# per-segment perpendicular made the sheet's outer columns jump there).
		var t_here: Vector2 = (b - a).normalized()
		var t_prev: Vector2 = t_here if seg == 0 else (a - Vector2(_stream[seg - 1].x, _stream[seg - 1].z)).normalized()
		var t_next: Vector2 = t_here if seg + 2 >= _stream.size() else (Vector2(_stream[seg + 2].x, _stream[seg + 2].z) - b).normalized()
		var tangent: Vector2 = (t_prev.lerp(t_here, 0.5 + 0.5 * f) if f < 0.5 else t_here.lerp(t_next, f - 0.5)).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var mid_ground: float = _coarse_height(centre.x, centre.y)
		var mid: float = maxf(mid_ground + depth, LAKE_Y + 0.05)
		var steep: float = clampf((last_mid - mid) / spacing * 1.2, 0.0, 1.0)
		steep_max = maxf(steep_max, steep)
		last_mid = mid
		var bank_low: float = minf(_coarse_height(centre.x + side.x * (half + 4.0), centre.y + side.y * (half + 4.0)), _coarse_height(centre.x - side.x * (half + 4.0), centre.y - side.y * (half + 4.0)))
		if mid_ground >= LAKE_Y and mid - bank_low > above_banks:
			above_banks = mid - bank_low
			worst = [snappedf(centre.x, 0.1), snappedf(centre.y, 0.1), snappedf(mid, 0.01), snappedf(bank_low, 0.01)]
		for k: int in columns:
			var off: float = (float(k) / float(columns - 1) * 2.0 - 1.0) * half
			var at: Vector2 = centre + side * off
			var ground: float = _coarse_height(at.x, at.y)
			# Outer columns sit a little higher (0.42 m at the centre, 0.54 m at the edges): the widened
			# sheet's edges cross local creases where a flat 0.35 m offset dipped 2 cm under the bed.
			var y: float = maxf(ground + depth + 0.12 * absf(off) / half, LAKE_Y + 0.05)
			floating = maxf(floating, y - ground if ground >= LAKE_Y else 0.0)
			st.set_uv(Vector2(float(k) / float(columns - 1), d / 40.0))
			# COLOR.g: 1 where the sheet lies on the lake itself (it fades out there; the lake's inflow fan takes over).
			st.set_color(Color(steep, 1.0 if ground < LAKE_Y else 0.0, 0.0))
			st.add_vertex(Vector3(at.x, y, at.y))
	for r: int in rows - 1:
		for k: int in columns - 1:
			var i: int = r * columns + k
			st.add_index(i); st.add_index(i + columns); st.add_index(i + 1)
			st.add_index(i + 1); st.add_index(i + columns); st.add_index(i + columns + 1)
	st.generate_normals()
	st.generate_tangents()
	var water := ShaderMaterial.new()
	water.shader = FALLS_SHADER
	water.set_shader_parameter("stream", true)
	_geology_materials.append(water)
	var ribbon_mesh: ArrayMesh = st.commit()
	stream_report["clearance"] = _water_clearance(ribbon_mesh)
	var node := MeshInstance3D.new()
	node.name = "WestFallsOutlet"
	node.mesh = ribbon_mesh
	node.material_override = water
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_static.append(node)
	# Inflow fan on the lake (lake shader only, visual): where the channel floor first drops below
	# the lake level, a silty plume with foam streaks spreads out into the lake.
	for i: int in range(1, _stream.size()):
		var h0: float = _coarse_height(_stream[i - 1].x, _stream[i - 1].z)
		var h1: float = _coarse_height(_stream[i].x, _stream[i].z)
		if h1 >= LAKE_Y or h0 < LAKE_Y: continue
		var p0 := Vector2(_stream[i - 1].x, _stream[i - 1].z)
		var p1 := Vector2(_stream[i].x, _stream[i].z)
		var entry: Vector2 = p0.lerp(p1, clampf((h0 - LAKE_Y) / maxf(h0 - h1, 0.01), 0.0, 1.0))
		var flow: Vector2 = (p1 - p0).normalized().lerp((LAKE_CENTER - entry).normalized(), 0.3).normalized()
		if _lake_material != null:
			_lake_material.set_shader_parameter("inflow", Vector4(entry.x, entry.y, flow.x, flow.y))
			_lake_material.set_shader_parameter("inflow_size", Vector2(70.0, 1.0))
		stream_report["inflow"] = {"entry": [snappedf(entry.x, 0.1), snappedf(entry.y, 0.1)], "dir": [snappedf(flow.x, 0.01), snappedf(flow.y, 0.01)], "reach_m": 70.0}
		break
	# Clearances: route and slice points to the carved valley's reach; carve depth at the needle
	# crag's base; the shore camera's sightline to the pool over the rendered terrain.
	var route_gap: float = INF
	for path: Variant in [route, slice_route]:
		if not is_instance_valid(path) or not path.valid: continue
		for point: Vector3 in path._p:
			var frame: Vector2 = _stream_distance(point.x, point.z)
			route_gap = minf(route_gap, frame.x)
	var crag := Vector2(-520.0, -520.0)
	_stream_carving = false
	var crag_before: float = terrain_height(crag.x, crag.y)
	_stream_carving = true
	var crag_carve: float = crag_before - terrain_height(crag.x, crag.y)
	var eye := Vector3(387.12, -78.01 + 1.7, -300.14)
	var target := Vector3(_basin.x, pool_y + 4.0, _basin.y)
	var blocked: float = -INF
	for k: int in range(1, 120):
		var q: Vector3 = eye.lerp(target, float(k) / 120.0)
		blocked = maxf(blocked, _coarse_height(q.x, q.z) - q.y)
	var mouth: Vector3 = _stream[_stream.size() - 1]
	var joins: bool = Vector2(mouth.x, mouth.z).distance_to(LAKE_CENTER) < 290.0 and _coarse_height(mouth.x, mouth.z) < LAKE_Y
	stream_report.merge({"built": true, "ribbon_triangles": (rows - 1) * (columns - 1) * 2, "sheet": {"rows": rows, "columns": columns, "spacing_m": spacing, "depth_over_rendered_bed_m": depth}, "water_depth_over_rendered_floor_max_m": floating, "water_above_banks_max_m": above_banks, "worst_bank_point_x_z_water_bank_floor_lakedist_index": worst, "joins_lake_water": joins, "steepest_reach": steep_max, "route_slice_min_distance_m": route_gap, "crag_base_carve_m": crag_carve, "shore_sightline_max_terrain_above_m": blocked, "pool_visible_from_shore_eye": blocked < 0.0, "mouth": _v3(mouth), "collision": "none (far layer)"}, true)
	var clear: Dictionary = stream_report["clearance"]
	stream_report["passed"] = route_gap > 60.0 and absf(crag_carve) < 5.0 and joins and bool(stream_report.get("reached_lake", false)) and int(clear.buried_samples) == 0 and float(clear.max_over_bed_m) < 1.0

## Alpine ice behind the falls: a snow peak standing behind the notch and a steep, fractured
## ice tongue descending from its flank through the widened notch to an ice cliff just above
## the rock lip, where the falls emerge. Far layer, no collision.
## Glacier surface profile along the flow (0 at the cirque, 1 at the lip): mostly even, easing slightly
## at both ends. Shared by the tongue and the upland bed so they stay matched.
func _glacier_profile(u: float) -> float:
	return lerpf(u, 1.0 - pow(1.0 - u, 1.6), 0.25)

func _add_ice(granite: ShaderMaterial) -> Dictionary:
	var at: int = clampi(roundi(WALL_FALLS_S / WALL_STEP), 1, _wall.size() - 2)
	var sample: Dictionary = _wall[at]
	var toe: Vector2 = sample.toe
	var nrm: Vector2 = sample.normal
	var dir: Vector2 = sample.dir
	var h: float = float(sample.top) - float(sample.base)
	if h < 150.0: return {"built": false, "reason": "no wall height at the falls"}
	# The peak: an alpine pyramid of uneven ridges, rock where steep and snow where it faces up.
	var centre: Vector2 = toe + nrm * ICE_PEAK.x
	var ground: float = terrain_height(centre.x, centre.y) - 40.0
	var profile: Array[Vector3] = []
	for i: int in 41:
		var t: float = float(i) / 40.0
		profile.append(Vector3(pow(1.0 - t, 0.85) * (1.0 + 0.12 * pow(1.0 - t, 4.0)), t, t))
	profile.append(Vector3(0.0, 1.0, 1.0))
	# PEAK_HORN: a ridged glacial horn (aretes, cirque faces, couloirs) in the same unit space and
	# transform; false restores the original lathe cone.
	var peak_mesh: ArrayMesh = Horn.ridged_horn_mesh() if PEAK_HORN else _lathe(profile, 48, "crag", false, PackedFloat32Array([0.7, 2.2, 4.1, 0.06, -0.04]))
	var rock := granite.duplicate() as ShaderMaterial
	rock.set_shader_parameter("world_mapped", true)
	_geology_materials.append(rock)
	var peak := MeshInstance3D.new()
	peak.name = "IcePeak"
	peak.mesh = peak_mesh
	peak.material_override = rock
	peak.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)).scaled(Vector3(ICE_PEAK.z, ICE_PEAK.y - ground, ICE_PEAK.z)), Vector3(centre.x, ground, centre.y))
	peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(peak)
	_static.append(peak)
	# The tongue: from inside the peak's flank down to the ice cliff above the lip.
	var lip_n: float = _wall_face_offset(sample, 1.0, h, float(sample.top))
	# Ice cliff 30 m (was 70 m: a tall white panel from the vista, review 04).
	var lip_top: float = float(sample.top) + 30.0
	var start_n: float = ICE_PEAK.x + 160.0
	# Head at the horn's cirque floor (0.42 of its height; 0.58 was set for the old cone, whose flank
	# was higher there, so on the horn the tongue head stood out of the cirque face, review 04).
	var start_y: float = ground + (ICE_PEAK.y - ground) * 0.42
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flat shading: serac blocks and moraine ridges read as broken facets, not a smooth capsule.
	st.set_smooth_group(-1)
	var flow_rows: int = 56
	# 21 columns (was 13) with irregular serac offsets: the alternating odd/even columns read as a
	# regular comb of white teeth from the vista (review 01/02).
	var across: int = 21
	var grid: Array = []
	for j: int in flow_rows + 1:
		var u: float = float(j) / flow_rows
		var n_at: float = lerpf(start_n, lip_n - 2.0, u)
		# Even descent (was steep-then-flat): the lower tongue keeps a slope the vista can see from below.
		var y_at: float = lerpf(start_y, lip_top, _glacier_profile(u))
		var half: float = lerpf(100.0, 56.0, u)
		var row: Array = []
		for k: int in across:
			var v: float = float(k) / (across - 1) * 2.0 - 1.0
			# Flat-topped tongue; lateral moraine ridges at the margins.
			# Low crown (1.5 m, was 4 m): with flat shading and a low sun the far half of a high crown
			# faced away and read as a dark band from the vista. Moraine ridges 4 m (was 9 m).
			var lift: float = 1.5 * (1.0 - v * v) + 4.0 * smoothstep(0.7, 0.9, absf(v)) * (1.0 - smoothstep(0.92, 1.0, absf(v))) - 16.0 * smoothstep(0.92, 1.0, absf(v))
			# Icefall: stepped serac blocks where the tongue steepens, phase broken across the ice.
			var steep: float = smoothstep(0.3, 0.45, u) * (1.0 - smoothstep(0.88, 0.97, u))
			# Broken serac field, not a staircase: step phase varies strongly across the ice, step
			# heights vary, and each block gets its own heave.
			var phase: float = u * 11.0 + _terrace_noise.get_noise_2d(v * 400.0, 7.0) * 1.4 + _terrace_noise.get_noise_2d(v * 1500.0, u * 900.0) * 0.9
			# Seracs only in the middle of the ice: the margins stay smooth against the moraines, so the
			# tongue's silhouette is not a staircase (review 03).
			var core: float = 1.0 - smoothstep(0.45, 0.8, absf(v))
			lift += steep * core * ((fposmod(phase, 1.0) - 0.5) * lerpf(6.0, 15.0, 0.5 + 0.5 * _terrace_noise.get_noise_2d(v * 700.0, u * 300.0 + 31.0)) + _terrace_noise.get_noise_2d(v * 900.0, u * 1300.0) * 6.0)
			# Rounded, uneven shoulders where the tongue spills over the lip (the snout's straight top edge
			# read as a box from the vista, review 08).
			if HANGING_GLACIER: lift -= (22.0 * v * v + 7.0 * (_terrace_noise.get_noise_2d(v * 520.0, 91.0) + 0.5)) * smoothstep(0.8, 1.0, u)
			var p: Vector2 = toe + nrm * n_at + dir * (v * half)
			# Narrower lateral moraine (0.72-0.9 read as a dark slab edge from the vista, review 04).
			row.append([Vector3(p.x, y_at + lift, p.y), Vector2(u, v), smoothstep(0.82, 0.96, absf(v))])
		grid.append(row)
	# Ice cliff at the snout: ragged blue front in three rows down to the rock lip.
	var cliff_drops: Array = [0.33, 0.66, 1.0] if HANGING_GLACIER else [0.2, 0.4, 0.6, 0.8, 1.0]
	for drop: float in cliff_drops:
		var row: Array = []
		for k: int in across:
			var v: float = float(k) / (across - 1) * 2.0 - 1.0
			# Serac columns: alternate columns stand proud of the cliff, ragged down its height.
			var ragged: float = _terrace_noise.get_noise_2d(v * 300.0, 11.0 + drop * 50.0) * 9.0 + _terrace_noise.get_noise_2d(v * 1900.0, 53.0) * 6.0
			var p: Vector2 = toe + nrm * (lip_n - 1.0 + ragged * (0.5 + drop)) + dir * (v * 56.0)
			# With the hanging glacier the snout cliff takes the drape's pale ice (one continuous ice
			# body; the dark blue cliff band above it drew a straight edge across the notch).
			var shoulder: float = (22.0 * v * v + 7.0 * (_terrace_noise.get_noise_2d(v * 520.0, 91.0) + 0.5)) if HANGING_GLACIER else 0.0
			var cliff_top: float = maxf(lip_top - shoulder, float(sample.top) - 2.0)
			row.append([Vector3(p.x, lerpf(cliff_top, float(sample.top) - 4.0, drop) + ragged * (1.0 - drop), p.y), Vector2(1.0 - 0.06 * (1.0 - drop) if HANGING_GLACIER else 1.0, v), -2.0 if HANGING_GLACIER else -1.0])
		grid.append(row)
	# Hanging glacier (review 08: from the vista the source read as a rectangular white slot, the
	# tongue itself being hidden behind the crest): the ice spills over the lip and drapes down the
	# gully to a ragged lower edge, longest in the middle (~115 m) and short at the margins, each
	# column following its own wall station's face 3-7 m proud of the rock. The falls start under it
	# and emerge below its edge. COLOR.b = 1 marks the drape (transverse crevasse bands in the shader).
	if HANGING_GLACIER:
		var drape_rows: int = 14
		var reach: Array[float] = []
		for k: int in across:
			var v: float = float(k) / (across - 1) * 2.0 - 1.0
			reach.append(lerpf(118.0, 14.0, smoothstep(0.15, 1.0, absf(v))) + _terrace_noise.get_noise_2d(v * 260.0, 77.0) * 26.0 * (1.0 - 0.6 * absf(v)))
		for j: int in range(1, drape_rows + 1):
			var d: float = float(j) / drape_rows
			var row: Array = []
			for k: int in across:
				var v: float = float(k) / (across - 1) * 2.0 - 1.0
				var col: int = clampi(at + roundi(v * 56.0 / WALL_STEP), 0, _wall.size() - 1)
				var w: Dictionary = _wall[col]
				var wh: float = float(w.top) - float(w.base)
				var y: float = float(sample.top) - 4.0 - maxf(reach[k], 6.0) * d
				var q: float = clampf((y - float(w.base)) / wh, 0.0, 1.0)
				var heave: float = _terrace_noise.get_noise_2d(v * 700.0, d * 400.0 + 19.0) * 2.5
				var off: float = _wall_face_offset(w, q, wh, y) + lerpf(7.0, 3.0, d) + heave
				var wt: Vector2 = w.toe
				var wn: Vector2 = w.normal
				var p: Vector2 = wt + wn * off
				row.append([Vector3(p.x, y, p.y), Vector2(1.0 + d, v), -2.0])
			grid.append(row)
	for j: int in grid.size() - 1:
		for k: int in across - 1:
			var quad: Array = [grid[j][k], grid[j][k + 1], grid[j + 1][k], grid[j + 1][k + 1]]
			for m: int in [0, 1, 2, 1, 3, 2]:
				var vertex: Array = quad[m]
				st.set_uv(vertex[1])
				var cliff: float = 1.0 if float(vertex[2]) == -1.0 else 0.0
				var drape: float = 1.0 if float(vertex[2]) == -2.0 else 0.0
				st.set_color(Color(cliff, maxf(0.0, float(vertex[2])), drape))
				st.add_vertex(vertex[0])
	st.generate_normals()
	var upland: Dictionary = _add_upland(sample, start_n, start_y, lip_n, lip_top, rock)
	var ice_material := ShaderMaterial.new()
	ice_material.shader = ICE_SHADER
	_geology_materials.append(ice_material)
	var tongue := MeshInstance3D.new()
	tongue.name = "IceTongue"
	tongue.mesh = st.commit()
	tongue.material_override = ice_material
	tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tongue)
	_static.append(tongue)
	var summit: Vector3 = peak.transform * Vector3(0.0, 1.0, 0.0)
	return {"built": bool(upland.get("built", false)), "peak_summit": _v3(summit), "peak_triangles": _triangle_count(peak_mesh), "tongue_triangles": (grid.size() - 1) * (across - 1) * 2, "serac_steps": "icefall u 0.3-0.97", "upland": upland, "moraines": "lateral, |v| > 0.72", "tongue_drop_m": start_y - lip_top, "ice_cliff_m": lip_top - (float(sample.top) - 4.0)}

## Capture-only: 1 unlit albedo, 2 world normal, 3 uniform grey lit by the scene, 4 flat mask
## (rock magenta, ice cyan); fog_off removes depth fog. (0, false) is the final rendering.
func set_geology_debug(view: int, fog_off: bool) -> void:
	geology_debug = view
	_debug_fog_off = fog_off
	for material: ShaderMaterial in _geology_materials: material.set_shader_parameter("debug_view", view)

## High ground around the upper glacier valley: one connected massif heightfield behind the
## falls, in a frame anchored on the falls sample (a along the wall, b back from the toe). Two
## unequal, broken ridges climb from the wall crest toward the snow peak (the valley head); a
## U-shaped glacier valley between them carries the ice tongue on its floor; outer slopes descend
## with gullies; the front meets the wall crest and the sides and back sink into the terrain.
## Far layer: no collision, no shadows; the terrain heightfield is unchanged.
func _add_upland(sample: Dictionary, start_n: float, start_y: float, lip_n: float, lip_top: float, rock: ShaderMaterial) -> Dictionary:
	var toe: Vector2 = sample.toe
	var nrm: Vector2 = sample.normal
	var dir: Vector2 = sample.dir
	var step: float = 15.0
	var a_half: float = 660.0
	var b0: float = 140.0
	var b1: float = minf(840.0, (toe.x + TERRAIN_HALF - 10.0) / maxf(nrm.x, 0.1))
	var cols: int = int(a_half * 2.0 / step) + 1
	var rows: int = int((b1 - b0) / step) + 2
	var heights := PackedFloat32Array()
	heights.resize(cols * rows)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var highest: float = -INF
	var finite := true
	for r: int in rows:
		# Row 0 is a short skirt just in front of the first row, tucked down against the crest.
		var b: float = b0 - 12.0 if r == 0 else b0 + float(r - 1) * step
		for k: int in cols:
			var a: float = -a_half + float(k) * step
			var at: Vector2 = toe + dir * a - nrm * b
			# Wall crest height at this position along the wall.
			var crest_i: int = clampi(roundi((WALL_FALLS_S + a) / WALL_STEP), 0, _wall.size() - 1)
			var crest: float = float(_wall[crest_i].get("top", WALL_FLOOR))
			# Glacier bed along the valley (matches the tongue), rising into the cirque behind it.
			var u: float = clampf((-b - start_n) / ((lip_n - 2.0) - start_n), 0.0, 1.0)
			# Bed just under the ice surface (was 12 m below): the tongue sits flush in its valley, so its
			# margins are buried and the vista does not see a slab with a dark side face (review 04).
			var bed: float = lerpf(start_y, lip_top, _glacier_profile(u)) - 3.0
			if -b < start_n: bed += (start_n + b) * 1.1
			var hw: float = lerpf(100.0, 56.0, u) * 1.08
			# Two unequal ridges, widening toward the cirque, crests rising toward the peak and
			# broken by notches.
			var side: float = 1.0 if a >= 0.0 else -1.0
			var reach: float = (125.0 + 0.42 * (b - b0)) * (1.0 if side > 0.0 else 0.82) * (1.0 + 0.18 * _hill_noise.get_noise_2d(b * 2.2, side * 300.0))
			var ridge: float = minf(820.0, crest + 55.0 + (b - b0) * (0.62 if side > 0.0 else 0.5)) + 45.0 * _ridge_noise.get_noise_2d(b * 3.0, side * 500.0) - 35.0 * pow(maxf(0.0, _terrace_noise.get_noise_2d(b * 5.0, side * 70.0)), 2.0)
			var d: float = absf(a)
			var h: float
			if d <= hw:
				h = bed
			elif d <= reach:
				# Glacial U: flat floor, walls steepening toward the ridge.
				var t: float = (d - hw) / maxf(reach - hw, 1.0)
				h = bed + (ridge - bed) * (1.0 - pow(1.0 - t, 1.8))
			else:
				# Outer slope with gullies, descending away from the ridge.
				var out: float = d - reach
				var gully: float = pow(1.0 - absf(_ridge_noise.get_noise_2d(a * 2.5, b * 0.8)), 4.0) * 55.0
				h = ridge - out * (0.85 + 0.25 * _hill_noise.get_noise_2d(a * 1.7, b * 1.7)) - gully
			# Front: meet the wall crest (the valley floor at the lip stays at the glacier bed).
			var front: float = smoothstep(b0, b0 + 130.0, b)
			var front_h: float = crest + 4.0 if d > hw else bed
			h = lerpf(front_h, maxf(h, crest - 20.0), front)
			# Sides and back sink into the terrain.
			var ground: float = terrain_height(clampf(at.x, -TERRAIN_HALF, TERRAIN_HALF), clampf(at.y, -TERRAIN_HALF, TERRAIN_HALF))
			var edge: float = minf(smoothstep(a_half, a_half - 140.0, d), smoothstep(b1, b1 - 120.0, b))
			h = lerpf(ground - 25.0, h, edge)
			if r == 0: h -= 40.0
			heights[r * cols + k] = h
			highest = maxf(highest, h)
			finite = finite and is_finite(h)
			st.set_uv(Vector2(a, h))
			st.add_vertex(Vector3(at.x, h, at.y))
	for r: int in rows - 1:
		for k: int in cols - 1:
			var i: int = r * cols + k
			# Same winding rule as the wall: front = along (k) x back (r), which faces up here.
			st.add_index(i); st.add_index(i + cols); st.add_index(i + 1)
			st.add_index(i + 1); st.add_index(i + cols); st.add_index(i + cols + 1)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var up_count: int = 0
	for n: Vector3 in normals: up_count += 1 if n.y > 0.0 else 0
	var node := MeshInstance3D.new()
	node.name = "IceUpland"
	node.mesh = mesh
	node.material_override = rock
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_static.append(node)
	var route_gap: float = INF
	for path: Variant in [route, slice_route]:
		if not is_instance_valid(path) or not path.valid: continue
		for point: Vector3 in path._p:
			var rel := Vector2(point.x, point.z) - toe
			var a2: float = clampf(rel.dot(dir), -a_half, a_half)
			var b2: float = clampf(-rel.dot(nrm), b0, b1)
			route_gap = minf(route_gap, Vector2(point.x, point.z).distance_to(toe + dir * a2 - nrm * b2))
	var up_share: float = float(up_count) / float(normals.size())
	return {"built": finite and up_share > 0.98 and route_gap > 300.0, "triangles": (rows - 1) * (cols - 1) * 2, "grid": [cols, rows], "cell_m": step, "extent_along_back_m": [a_half * 2.0, b1 - b0], "highest_m": highest, "finite": finite, "normals_facing_up": up_share, "route_clearance_m": route_gap, "collision": "none (far layer)"}

func _v3(value: Vector3) -> Array:
	return [snappedf(value.x, 0.1), snappedf(value.y, 0.1), snappedf(value.z, 0.1)]

# --- Meshes (profile x = radius, y = height, z = v parameter) ---

# Parasol cap: radius 1, drooping fleshy rim (a rounded bulb, not a knife edge) and a
# gill underside. `phases` drive mixed integer-frequency rim variation with random
# phase, so no two caps share a mechanical 360-degree symmetry. The profile runs from the
# top centre outward then back under, so the front face needs the flipped index order.
func _cap_mesh(phases: PackedFloat32Array, style: String = "cap") -> ArrayMesh:
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
	var mesh: ArrayMesh = _lathe(profile, 72, style, true, phases)
	if style == "cap":
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
				"cap", "hero_cap":
					if style == "hero_cap":
						# Hero only: the rim curl's cross-section thickens and thins slowly around the
						# margin (scaled about the curl centre, before the shared modulation).
						var curl: float = smoothstep(0.9, 0.97, p.x)
						var thick: float = 1.0 + 0.3 * (0.6 * sin(2.0 * a + 0.9) + 0.4 * sin(3.0 * a + 2.6))
						radius = 0.97 + (p.x - 0.97) * lerpf(1.0, thick, curl)
						height = -0.075 + (p.y + 0.075) * lerpf(1.0, thick, curl)
					var edge: float = pow(smoothstep(0.3, 1.0, p.x), 1.5)
					var f: PackedFloat32Array = phases if phases.size() >= 6 else PackedFloat32Array([0, 0, 0, 0, 0, 0])
					radius *= 1.0 + edge * (0.055 * sin(2.0 * a + f[0]) + 0.035 * sin(3.0 * a + f[1]) + 0.02 * sin(5.0 * a + f[2]) + 0.01 * sin(11.0 * a + f[3]))
					height += edge * (0.07 * sin(a + f[4]) + 0.025 * sin(4.0 * a + f[5]))
					if style == "hero_cap":
						# Organic margin: broad asymmetric lobes, and a margin that droops more where it
						# reaches further. All terms are periodic in the angle, so the seam stays closed.
						var margin: float = smoothstep(0.55, 1.0, p.x)
						var lobe: float = 0.0
						for spec: Vector3 in HERO_CAP_LOBES:
							var gap: float = fposmod(a - spec.x + PI, TAU) - PI
							lobe += spec.z * (exp(-gap * gap / (2.0 * spec.y * spec.y)) - spec.y / sqrt(TAU))
						var wave: float = 0.035 * sin(3.0 * a + 1.3) + 0.02 * sin(5.0 * a + 4.1)
						radius *= 1.0 + margin * lobe
						height += margin * (wave - 0.35 * maxf(lobe, 0.0))
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
	if is_instance_valid(_skyglow) and is_inside_tree():
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null: _skyglow.global_position = camera.global_position
	if frozen or _reduced_motion or (is_inside_tree() and get_tree().paused): return
	_time += delta
	for material: ShaderMaterial in _art + [_lake_material] + _geology_materials:
		material.set_shader_parameter("shimmer_time", _time)

## Switches the copied-tree near/far LOD between the original instant swap (enabled false:
## NEAR_CROWN_RANGE with NEAR_CROWN_MARGIN hysteresis, shader fade off) and the dithered
## crossfade. Godot culls a node by the distance to its AABB centre, so for the crossfade each
## near node stays drawn up to LOD_FADE_END + its radius and each far node from LOD_FADE_START -
## its radius (radius = farthest crown origin from that centre); the shader decides per tree.
func set_lod_crossfade(enabled: bool) -> void:
	lod_crossfade = enabled
	var radii: Array = []
	for node: GeometryInstance3D in _static:
		var lod: String = node.get_meta("lod_range", "")
		if not lod in ["near", "far"] or not node is MultiMeshInstance3D: continue
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		var centre: Vector3 = node.global_transform * node.get_aabb().get_center()
		var radius: float = 0.0
		for i: int in multi.instance_count: radius = maxf(radius, (node.global_transform * multi.get_instance_transform(i)).origin.distance_to(centre))
		radii.append(snappedf(radius, 0.1))
		if lod == "near":
			node.visibility_range_end = LOD_FADE_END + radius + 1.0 if enabled else NEAR_CROWN_RANGE
			node.visibility_range_end_margin = 0.0 if enabled else NEAR_CROWN_MARGIN
		else:
			node.visibility_range_begin = maxf(0.0, LOD_FADE_START - radius - 1.0) if enabled else NEAR_CROWN_RANGE
			node.visibility_range_begin_margin = 0.0 if enabled else NEAR_CROWN_MARGIN
	for role: String in ["near", "far"]:
		for material: Variant in _lod_materials[role]:
			if not material is ShaderMaterial: continue
			(material as ShaderMaterial).set_shader_parameter("lod_fade_start", LOD_FADE_START if enabled else 0.0)
			(material as ShaderMaterial).set_shader_parameter("lod_fade_end", LOD_FADE_END if enabled else 0.0)
			(material as ShaderMaterial).set_shader_parameter("lod_fade_role", (1.0 if role == "near" else 2.0) if enabled else 0.0)
	if tree_report.has("lod"):
		tree_report.lod["crossfade"] = {"enabled": enabled, "band_m": [LOD_FADE_START, LOD_FADE_END], "node_radii_m": radii, "materials": {"near": _lod_materials.near.size(), "far": _lod_materials.far.size()}}

## The lake surface in use (enabled) or the previous far_water look; diagnostic toggle for
## same-frame evidence and the cost comparison (only the new shader reads the screen texture).
func set_lake_water(enabled: bool) -> void:
	lake_water = enabled
	_lake_material.shader = LAKE_SHADER if enabled else WATER_SHADER

## Hero cap organic margin shape (current) or the previous lathe shape; diagnostic toggle.
func set_cap_shape(enabled: bool) -> void:
	for node: MultiMeshInstance3D in _nodes:
		if String(node.name) == "HeroCanopy": node.multimesh.mesh = _hero_cap_shaped if enabled else _hero_cap_previous

## Mesh validity of the shaped hero cap against the previous one. SurfaceTool re-indexes the
## lathe into triangle order, so nothing here assumes row-major vertices: same index buffer,
## finite vertices, closed seam (each u = 0 vertex has a coincident u = 1 vertex), top centre
## facing up, underside centre (v = 1) facing down, no face whose normal flips against the
## previous (validated) cap, and degenerate triangles only in the existing centre fan.
func _cap_mesh_check(shaped: ArrayMesh, previous: ArrayMesh) -> Dictionary:
	var arrays: Array = shaped.surface_get_arrays(0)
	var old_arrays: Array = previous.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ov: PackedVector3Array = old_arrays[Mesh.ARRAY_VERTEX]
	var old_idx: PackedInt32Array = old_arrays[Mesh.ARRAY_INDEX]
	var same_topology: bool = v.size() == ov.size() and idx == old_idx
	var finite := true
	for p: Vector3 in v: finite = finite and p.is_finite()
	var seam: float = 0.0
	var seam_pairs: int = 0
	var closing: PackedVector3Array = []
	for j: int in v.size():
		if uv[j].x > 1.0 - 1e-6: closing.append(v[j])
	for i: int in v.size():
		if uv[i].x > 1e-6: continue
		var nearest: float = INF
		for q: Vector3 in closing: nearest = minf(nearest, v[i].distance_to(q))
		seam = maxf(seam, nearest)
		seam_pairs += 1
	var top_up: float = INF
	var under_down: float = -INF
	for i: int in v.size():
		if Vector2(v[i].x, v[i].z).length() < 1e-4 and v[i].y > 0.0: top_up = minf(top_up, n[i].y)
		if uv[i].y > 1.0 - 1e-6: under_down = maxf(under_down, n[i].y)
	var flipped: int = 0
	var min_face_dot: float = 1.0
	var degenerate: int = 0
	var degenerate_off_centre: int = 0
	if same_topology:
		for t: int in range(0, idx.size(), 3):
			var a: int = idx[t]; var b: int = idx[t + 1]; var c: int = idx[t + 2]
			var fn: Vector3 = (v[b] - v[a]).cross(v[c] - v[a])
			var fo: Vector3 = (ov[b] - ov[a]).cross(ov[c] - ov[a])
			if fn.length() < 1e-9 or fo.length() < 1e-9:
				degenerate += 1
				var centre: int = 0
				for k: int in [a, b, c]: if Vector2(v[k].x, v[k].z).length() < 1e-4: centre += 1
				if centre < 2: degenerate_off_centre += 1
				continue
			var d: float = fn.normalized().dot(fo.normalized())
			min_face_dot = minf(min_face_dot, d)
			if d <= 0.0: flipped += 1
	var max_radius_change: float = 0.0
	var max_height_change: float = 0.0
	var centre_change: float = 0.0
	if same_topology:
		for i: int in v.size():
			max_radius_change = maxf(max_radius_change, absf(Vector2(v[i].x, v[i].z).length() - Vector2(ov[i].x, ov[i].z).length()))
			max_height_change = maxf(max_height_change, absf(v[i].y - ov[i].y))
			if Vector2(ov[i].x, ov[i].z).length() < 0.5: centre_change = maxf(centre_change, v[i].distance_to(ov[i]))
	var ok: bool = same_topology and finite and seam_pairs > 0 and seam < 1e-4 and top_up > 0.0 and under_down < 0.0 and flipped == 0 and degenerate_off_centre == 0 and centre_change < 1e-5
	return {"passed": ok, "same_topology": same_topology, "vertices": v.size(), "vertices_previous": ov.size(), "triangles": idx.size() / 3, "triangles_previous": old_idx.size() / 3,
		"finite": finite, "seam_gap": seam, "seam_pairs": seam_pairs, "top_centre_normal_y_min": top_up, "underside_centre_normal_y_max": under_down,
		"flipped_faces": flipped, "min_face_normal_dot_vs_previous": min_face_dot, "degenerate_triangles": degenerate, "degenerate_off_centre": degenerate_off_centre,
		"centre_change_inside_half_radius": centre_change, "max_plan_radius_change": max_radius_change, "max_height_change": max_height_change, "units": "cap-local (x scale = cap radius 220 m, y scale = thickness 110 m)"}

## Hero cap craft on (current) or the previous cap look; diagnostic toggle for same-frame evidence.
func set_cap_craft(enabled: bool) -> void:
	if cap_material != null: cap_material.set_shader_parameter("cap_craft", 1.0 if enabled else 0.0)

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

## Capture-only: paint just the giant caps and stems magenta for coverage metrics. The lake's
## screen-space reflection is suspended meanwhile, so it cannot mirror the mask into the count.
func set_debug_mask(enabled: bool) -> void:
	for node: MultiMeshInstance3D in _nodes:
		if not String(node.name) in ["HeroCanopy", "LuminousCanopies", "CanopyStems"]: continue
		node.material_override = _mask if enabled else _art[_nodes.find(node)]
	_lake_material.set_shader_parameter("screen_reflection", not enabled)

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	for material: ShaderMaterial in _art + _geology_materials:
		material.set_shader_parameter("shimmer_amount", 0.0 if value else 1.0)

## Capture-only look exploration (camera sweep): day endpoint colours by DEPTH_LOOK key plus
## sun_energy, sun_elev, ambient_energy. Empty in play.
var look_override: Dictionary = {}
const GOLDEN_GLOW := 0.35
const GOLDEN_FILL_ENERGY := 0.5
const GOLDEN_FILL_COLOR := "9499ff"
const GOLDEN_FILL_AZ := 337.0
const GOLDEN_FILL_ELEV := -45.0
## Sky glow direction (degrees; same azimuth convention as the sun's rotation_degrees.y).
const GOLDEN_GLOW_AZ := 208.0
const GOLDEN_GLOW_ELEV := 10.0
const GOLDEN_HALO_POWER := 28.0
const GOLDEN_HALO_GAIN := 0.7
const GOLDEN_CAP_GLOW := 1.0
## Bold gill plates on the lit cap undersides (Gemini goal frame: gold radial gills with dark gaps
## readable at vista distance; review 09 asked for gills >= 2 px). 0 = previous underside.
const GOLDEN_GILL_BOLD := 1.0
const GOLDEN_CLOUD_GLOW := 1.0
const GOLDEN_CLOUD_GLOW_POWER := 4.0
const GOLDEN_CLOUD_GLOW_COLOR := "ff9f50"
const GOLDEN_HORIZON_GLOW := 0.9
const GOLDEN_HORIZON_GLOW_POWER := 16.0
const GOLDEN_REFLECT_FLOOR := 0.5
const GOLDEN_GLOW_BAND := 0.0
const GOLDEN_FAR_DOME := 0.5
const GOLDEN_FAR_UNDER := 1.5
const GOLDEN_MIST_WARM := "f4c09c"
const GOLDEN_FAR_FOG := 0.45
const GOLDEN_FOG_BEGIN := 550.0
const GOLDEN_STREAM_SHEEN := 0.7
# Soft daylight on terrain, forest carpet and erratics (consult 01 step 4): wrap on the key, a
# lavender sky hemisphere (energy) and a warm ground bounce (fraction of the key), day only.
const SOFT_WRAP := 0.7
const SOFT_HEMI := 0.3
const SOFT_HEMI_COLOR := "9e94e0"
const SOFT_BOUNCE := 0.3

## Amber/lavender grade, written after the shared lighting owner's endpoints.
func apply_look(environment: Environment, sun: DirectionalLight3D, night: float, rain: float, sunset: float) -> void:
	var toward_sun: Vector3 = sun.global_basis.z.normalized()
	for pair: Array in _crown_sync:
		for key: String in ["wind_time", "wind_displacement_m", "night_amount"]:
			(pair[1] as ShaderMaterial).set_shader_parameter(key, (pair[0] as ShaderMaterial).get_shader_parameter(key))
	for pair: Array in _understory_sync:
		(pair[1] as ShaderMaterial).set_shader_parameter("night_amount", (pair[0] as ShaderMaterial).get_shader_parameter("night_amount"))
	var day: Dictionary = DEPTH_LOOK if look_depth else {"sun": DAY_SUN, "ambient": Color("d2d0ca"), "fog": Color("a2b3d4"), "sky_top": Color("41529f"), "sky_horizon": Color("f4c49a"), "lake_horizon": Color("f2b08e")}
	if not look_override.is_empty():
		day = day.duplicate()
		for key: String in look_override:
			if key in day: day[key] = Color(str(look_override[key]))
	_lake_material.set_shader_parameter("horizon", (day.lake_horizon as Color).lerp(Color("3a3466"), night))
	# Painterly reflectance floor by day (review 06 item 4: the vista lake read as a hole).
	_lake_material.set_shader_parameter("reflect_floor", float(look_override.get("reflect_floor", GOLDEN_REFLECT_FLOOR)) * (1.0 - night) * (1.0 - 0.5 * rain) if look_depth else 0.0)
	if _skyglow_material != null:
		_skyglow_material.set_shader_parameter("sun_dir", toward_sun)
		# The glow is decoupled from the key (consult 01): it sits near the hero view axis while the
		# key comes from the side, as the concepts do.
		var g_az: float = deg_to_rad(float(look_override.get("glow_az", GOLDEN_GLOW_AZ)))
		var g_el: float = deg_to_rad(float(look_override.get("glow_elev", GOLDEN_GLOW_ELEV)))
		_skyglow_material.set_shader_parameter("glow_dir", Vector3(sin(g_az) * cos(g_el), sin(g_el), cos(g_az) * cos(g_el)))
		_skyglow_material.set_shader_parameter("night", night)
		_skyglow_material.set_shader_parameter("rain", rain)
		_skyglow_material.set_shader_parameter("strength", float(look_override.get("glow", GOLDEN_GLOW)))
		_skyglow_material.set_shader_parameter("glow_color", Color(str(look_override.get("glow_color", "ffb873"))))
		_skyglow_material.set_shader_parameter("halo_power", float(look_override.get("halo_power", GOLDEN_HALO_POWER)))
		_skyglow_material.set_shader_parameter("halo_gain", float(look_override.get("halo_gain", GOLDEN_HALO_GAIN)))
	for material: ShaderMaterial in _art + [_terrain_material, _lake_material] + _geology_materials:
		material.set_shader_parameter("night", night)
		material.set_shader_parameter("rain", rain)
		material.set_shader_parameter("sun_dir", toward_sun)
	# Mist warms toward the glow by day (golden hour only; other shaders ignore these).
	var m_az: float = deg_to_rad(float(look_override.get("glow_az", GOLDEN_GLOW_AZ)))
	var mist_warm: Color = Color(str(look_override.get("mist_warm", GOLDEN_MIST_WARM))) if look_depth else Color(0.80, 0.78, 0.93)
	var sheen_lin: Color = (day.lake_horizon as Color).srgb_to_linear() * float(look_override.get("stream_sheen", GOLDEN_STREAM_SHEEN)) * (1.0 - night) * (1.0 - 0.6 * rain) if look_depth else Color(0, 0, 0)
	for material: ShaderMaterial in _geology_materials:
		material.set_shader_parameter("glow_tint", mist_warm)
		material.set_shader_parameter("glow_dir", Vector3(sin(m_az), 0.0, cos(m_az)))
		material.set_shader_parameter("day_sheen", Vector3(sheen_lin.r, sheen_lin.g, sheen_lin.b))
	# Daytime cap luminosity (golden hour only; far_canopy mode 0 reads it, other modes ignore it).
	var cap_day_glow: float = float(look_override.get("cap_glow", GOLDEN_CAP_GLOW)) * (1.0 - 0.5 * rain) if look_depth else 0.0
	var gill_bold: float = float(look_override.get("gill_bold", GOLDEN_GILL_BOLD)) if look_depth else 0.0
	for material: ShaderMaterial in _art:
		material.set_shader_parameter("day_glow", cap_day_glow)
		material.set_shader_parameter("gill_bold", gill_bold)
	if cap_material != null and not cap_material in _art:
		cap_material.set_shader_parameter("day_glow", cap_day_glow)
		cap_material.set_shader_parameter("gill_bold", gill_bold)
	if _horizon_cap_material != null: _horizon_cap_material.set_shader_parameter("gill_bold", gill_bold)
	if _horizon_cap_material != null:
		_horizon_cap_material.set_shader_parameter("dome_value", float(look_override.get("far_dome", GOLDEN_FAR_DOME)) if look_depth else 1.0)
		_horizon_cap_material.set_shader_parameter("under_gain", float(look_override.get("far_under", GOLDEN_FAR_UNDER)) if look_depth else 1.0)
	sun.light_color = (day.sun as Color).lerp(NIGHT_SUN, night).lerp(Color("ffa86a"), sunset * 0.5)
	sun.light_energy = lerpf(float(look_override.get("sun_energy", GOLDEN_SUN_ENERGY if look_depth else 1.55)), 0.60, night) * lerpf(1.0, 0.65, rain)
	sun.rotation_degrees.x = lerpf(float(look_override.get("sun_elev", GOLDEN_SUN_ELEV if look_depth else -22.0)), -27.45, night)
	sun.rotation_degrees.y = lerpf(float(look_override.get("sun_az", GOLDEN_SUN_AZ if look_depth else 130.0)), 153.79, night)
	sun.light_angular_distance = 2.2
	# Soft daylight: by day, golden hour only; night and rain keep their previous lighting exactly.
	var soft_k: float = (1.0 - night) * (1.0 - rain) if look_depth else 0.0
	var key_lin: Color = sun.light_color.srgb_to_linear() * sun.light_energy * soft_k
	var sky_lin: Color = Color(str(look_override.get("hemi_color", SOFT_HEMI_COLOR))).srgb_to_linear() * float(look_override.get("hemi", SOFT_HEMI)) * soft_k
	var bounce_lin: Color = key_lin * float(look_override.get("bounce", SOFT_BOUNCE))
	for material: ShaderMaterial in _soft_materials:
		material.set_shader_parameter("key_light", Vector3(key_lin.r, key_lin.g, key_lin.b))
		material.set_shader_parameter("wrap_light", float(look_override.get("wrap", SOFT_WRAP)) * soft_k)
		material.set_shader_parameter("hemi_sky", Vector3(sky_lin.r, sky_lin.g, sky_lin.b))
		material.set_shader_parameter("hemi_ground", Vector3(bounce_lin.r, bounce_lin.g, bounce_lin.b))
		material.set_shader_parameter("soft_range", float(look_override.get("soft_range", 900.0)))
	# Tonal hierarchy: neutral-cool ambient and haze; the warm sun keeps the foreground warm.
	environment.ambient_light_color = (day.ambient as Color).lerp(Color("8f90c8"), night)
	# Fill energy stays at 0.32: a stronger fill (0.42 tried, sweep 173032) lifted the shadow
	# sides and flattened the walls into pale curtains; only the fill colour turns cooler.
	environment.ambient_light_energy = lerpf(float(look_override.get("ambient_energy", GOLDEN_AMBIENT_ENERGY if look_depth else 0.32)), 0.32, night)
	# Front fill (golden hour): the key sits behind the valley, so faces toward the cameras would be
	# all shadow side; the world's shadowless sky-fill light is turned to face away from the sun
	# (azimuth + 180, low) in a cool lavender, by day only. It gives front faces N.L form.
	var fill: Variant = _world.get("_sky_fill")
	var fill_energy: float = float(look_override.get("fill_energy", GOLDEN_FILL_ENERGY if look_depth else 0.0))
	if fill is DirectionalLight3D and is_instance_valid(fill) and fill_energy > 0.0 and night < 1.0:
		var day_w: float = (1.0 - night) * (1.0 - 0.6 * rain)
		var fill_az: float = float(look_override.get("fill_az", GOLDEN_FILL_AZ if GOLDEN_FILL_AZ >= 0.0 else sun.rotation_degrees.y + 180.0))
		(fill as DirectionalLight3D).rotation_degrees = Vector3(float(look_override.get("fill_elev", GOLDEN_FILL_ELEV)), fill_az, 0.0).lerp((fill as DirectionalLight3D).rotation_degrees, night)
		(fill as DirectionalLight3D).light_energy = lerpf((fill as DirectionalLight3D).light_energy, fill_energy, day_w)
		(fill as DirectionalLight3D).light_color = (fill as DirectionalLight3D).light_color.lerp(Color(str(look_override.get("fill_color", GOLDEN_FILL_COLOR))), day_w)
	environment.fog_enabled = not _debug_colors
	# Rain haze is a darker slate (9c97b4 at 0.5 lifted the walls above the overcast sky: vista rain
	# massif 75.9 vs sky 74.6, review 03); the rain fog density is 0.7 instead of the previous 0.8.
	# The golden-hour haze is warm (Gemini paintover target); rain still reads slate (0.85 of the way).
	environment.fog_light_color = (day.fog as Color).lerp(Color("2f2b5a"), night).lerp(Color("77738c"), rain * (0.85 if look_depth else 0.6))
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	# Middle distance keeps contrast; fog rises steeply toward the far horizon.
	# Golden hour starts the haze further out so the warm haze does not lift mid-distance shadow
	# (review 08: vista massif p5 21 -> 28 after the warm haze).
	var fog_begin_day: float = lerpf(float(look_override.get("fog_begin", GOLDEN_FOG_BEGIN if look_depth else FOG_BEGIN)), FOG_BEGIN, night)
	environment.fog_depth_begin = 200.0 if atmosphere_previous else lerpf(fog_begin_day, 200.0, rain)
	environment.fog_depth_end = 1400.0 if atmosphere_previous else lerpf(FOG_END, 1400.0, rain)
	environment.fog_depth_curve = 1.8 if atmosphere_previous else lerpf(FOG_CURVE, 1.8, rain)
	environment.fog_density = 0.0 if _debug_fog_off else (0.14 if _overview else (lerpf(0.5, 0.8, rain) if atmosphere_previous else lerpf(lerpf(float(look_override.get("fog_density", GOLDEN_FOG_DENSITY if look_depth else FOG_DENSITY)), FOG_DENSITY, night), 0.7, rain)))
	environment.fog_aerial_perspective = lerpf(float(look_override.get("aerial", GOLDEN_AERIAL if look_depth else 0.15)), 0.15, night)
	# Overcast rain has no sun to scatter: the golden-hour scatter lit the rain haze pink (vista rain).
	environment.fog_sun_scatter = float(look_override.get("scatter", GOLDEN_SCATTER if look_depth else 0.1)) * (1.0 - night) * (1.0 - rain)
	environment.fog_sky_affect = 0.0
	# Horizon giants: the depth fog is capped on them so they stay opaque against the sky (review 08).
	# Their shader copy always writes FOG (a material that writes FOG never gets the engine fog), so
	# night and rain get their own amounts: 0.55 at night keeps the warm night glow seen before
	# (0.88-0.95 of the plain fog colour in rain left dark mauve silhouettes, geology 143308).
	# The engine's aerial perspective pulls far haze toward the sky colour; the cap follows it.
	var horizon_now: Color = (day.sky_horizon as Color).lerp(Color("3a3466"), night).lerp(Color("a79aa8"), rain * 0.4)
	# Rain: c9c0d8 at full strength made the left giant a flat cutout 13 above the overcast behind it
	# (review 09); the sky there measures ~L*60, so rain blends toward 968eaa at 0.93 (0.85 left the underside 16 below the sky, geology 144833).
	var cap_fog: Color = environment.fog_light_color.lerp(horizon_now, environment.fog_aerial_perspective).lerp(Color("968eaa"), rain).srgb_to_linear()
	var cap_amount: float = lerpf(lerpf(float(look_override.get("far_fog", GOLDEN_FAR_FOG)) if look_depth else 0.9, 0.55, night), 0.93, rain)
	for material: ShaderMaterial in [_horizon_cap_material, _horizon_stem_material]:
		if material != null: material.set_shader_parameter("fog_cap", Color(cap_fog.r, cap_fog.g, cap_fog.b, cap_amount))
	var sky: ShaderMaterial = _world.get("_cloud_sky_material")
	if sky != null:
		# Less pink: a bluer top and a golden (not peach-pink) horizon, so their blend
		# reads violet-to-gold rather than one pink wash.
		sky.set_shader_parameter("top_color", (day.sky_top as Color).lerp(Color("141a44"), night).lerp(Color("5d5f86"), rain * 0.4))
		sky.set_shader_parameter("horizon_color", (day.sky_horizon as Color).lerp(Color("3a3466"), night).lerp(Color("a79aa8"), rain * 0.4))
		# Gold cloud light toward the glow (review 06: the concepts' amber is mostly in the sky). Day,
		# golden hour only.
		var c_az: float = deg_to_rad(float(look_override.get("glow_az", GOLDEN_GLOW_AZ)))
		var c_el: float = deg_to_rad(float(look_override.get("glow_elev", GOLDEN_GLOW_ELEV)))
		sky.set_shader_parameter("cloud_glow_dir", Vector3(sin(c_az) * cos(c_el), sin(c_el), cos(c_az) * cos(c_el)))
		sky.set_shader_parameter("cloud_glow_color", Color(str(look_override.get("cloud_glow_color", GOLDEN_CLOUD_GLOW_COLOR))))
		sky.set_shader_parameter("cloud_glow", float(look_override.get("cloud_glow", GOLDEN_CLOUD_GLOW)) * (1.0 - night) * (1.0 - rain) if look_depth else 0.0)
		sky.set_shader_parameter("cloud_glow_power", float(look_override.get("cloud_glow_power", GOLDEN_CLOUD_GLOW_POWER)))
		sky.set_shader_parameter("horizon_glow", float(look_override.get("horizon_glow", GOLDEN_HORIZON_GLOW)) * (1.0 - night) * (1.0 - rain) if look_depth else 0.0)
		sky.set_shader_parameter("horizon_glow_power", float(look_override.get("horizon_glow_power", GOLDEN_HORIZON_GLOW_POWER)))
		sky.set_shader_parameter("glow_band", float(look_override.get("glow_band", GOLDEN_GLOW_BAND)) if look_depth else 0.0)
	# The lake's sky-gradient fallback follows the same sky colours.
	_lake_material.set_shader_parameter("sky_top", (day.sky_top as Color).lerp(Color("141a44"), night).lerp(Color("5d5f86"), rain * 0.4))
	_lake_material.set_shader_parameter("sky_horizon", (day.sky_horizon as Color).lerp(Color("3a3466"), night).lerp(Color("a79aa8"), rain * 0.4))
	# Vista refuge: flower petals and lanterns glow softly by day and carry the night.
	var refuge_tint: Color = Color(1, 1, 1).lerp(Color(0.3, 0.32, 0.52), night).lerp(Color(0.5, 0.53, 0.62), rain * (1.0 - night))
	for m: StandardMaterial3D in _refuge_mats: m.albedo_color = (m.get_meta("day_tint", Color.WHITE) as Color) * refuge_tint
	for glow: StandardMaterial3D in _refuge_glow: glow.emission_energy_multiplier = lerpf(0.12, 0.28, night) * (1.0 - 0.3 * rain)
	if _refuge_lamp_material != null: _refuge_lamp_material.emission_energy_multiplier = lerpf(2.0, 4.0, night)
	for prop: ShaderMaterial in _refuge_props:
		prop.set_shader_parameter("tint", Vector3(refuge_tint.r, refuge_tint.g, refuge_tint.b))
		prop.set_shader_parameter("glow", lerpf(1.2, 3.0, maxf(night, rain * 0.5)))
		if prop.get_meta("luminous", false): prop.set_shader_parameter("cool_glow", lerpf(0.25, 0.7, night))
	for light: OmniLight3D in _refuge_lights: light.light_energy = lerpf(0.9, 2.6, maxf(night, rain * 0.6))

func get_report() -> Dictionary:
	# Owned colliders: the two walking ribbons and the hero root; the far layer itself has none.
	var owned: int = int(route_report.get("colliders", 0)) + int(slice_report.get("colliders", 0)) + (1 if is_instance_valid(root_body) else 0)
	var colliders: int = find_children("*", "CollisionObject3D", true, false).size() - owned
	var shadows: int = 0
	for node: GeometryInstance3D in _nodes + _static:
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadows += 1
	var winding_ok: bool = float(winding_checks.get("terrain_centre_normal_y", -1.0)) > 0.0 and float(winding_checks.get("cap_top_normal_y", -1.0)) > 0.0 and bool(winding_checks.get("stem_side_normal_outward", false))
	var footing_ok: bool = float(landform_checks.get("giant_footing_drift_m", INF)) <= FOOTING_TOLERANCE
	return {"passed": colliders == 0 and shadows == 0 and winding_ok and footing_ok, "footing_ok": footing_ok, "trees": tree_report, "moss_mean": _moss_mean.to_html(false), "winding_checks": winding_checks, "winding_ok": winding_ok, "colliders": colliders, "shadow_casters": shadows, "canopies": canopy_count, "grounded_stems": grounded_stems, "rocks": rock_count, "erratics": erratic_report, "vista_grove": vista_grove_report, "vista_refuge": vista_refuge_report, "horizon_giants": horizon_giants_report, "cap_tendrils": tendril_report, "forest_clumps": carpet_count, "forest_chunks": carpet_chunks, "rock_spire_triangles": rock_triangles, "depth_look": {"enabled": look_depth, "day_endpoints": DEPTH_LOOK, "scope": "prototype apply_look only; day key/fill endpoints here; fog profile under atmosphere"}, "hero_cap_shape": hero_cap_mesh_check, "escarpment": escarpment_report, "stream": stream_report, "leaf_craft": leaf_craft_report.merged({"enabled": leaf_craft, "side_flip_corrected_materials": _prototype_leaf_materials.size()}), "cap_craft": {"enabled": cap_material != null and float(cap_material.get_shader_parameter("cap_craft")) > 0.0, "owner": "HeroCanopy material only (far_canopy mode 0)"}, "stem_finish": {"focus_radius_m": STEM_FOCUS_RADIUS, "strength": STEM_ORGANIC, "owner": "CanopyStems (shared far_canopy mode 1, hero-masked)"}, "rock_readability": {"region_xz": [_detail_region.position.x, _detail_region.position.y, _detail_region.end.x, _detail_region.end.y], "values": ROCK_READABILITY, "owner": "CliffDetailPatch (shared terrain shader, region-masked)"}, "leaf_materials_restrained": leaf_materials_restrained, "stem_buttresses": "5 lobes integrated into the stem surface", "slice": slice_report, "slice_patch_triangles": slice_patch_triangles, "root_collision_triangles": root_collision_triangles, "owned_colliders": owned, "detail_patch_triangles": detail_patch_triangles, "coarse_cells_replaced": detail_cells_replaced, "landform_checks": landform_checks, "diagnostic_skips": diagnostic_skips, "terrain_triangles": terrain_triangles, "carpet_triangles": carpet_triangles, "understory": understory_report, "shore_groves": shore_groves_report, "lake_water": {"enabled": lake_water, "shader": (LAKE_SHADER if lake_water else WATER_SHADER).resource_path}, "draw_nodes": _nodes.size() + _static.size(), "baked_extent_xz": [baked_extent.position.x, baked_extent.position.y, baked_extent.end.x, baked_extent.end.y], "far_plane": FAR_PLANE, "fog_end": FOG_END, "atmosphere": {"fog_begin": FOG_BEGIN, "fog_end": FOG_END, "fog_curve": FOG_CURVE, "fog_density_day_rain": [FOG_DENSITY, 0.7], "rain": "blends to the previous begin/end/curve; rain density 0.7, darker slate rain haze", "previous": {"begin": 200.0, "end": 1400.0, "curve": 1.8, "density_day_rain": [0.5, 0.8]}, "scope": "prototype apply_look only"}, "built_at_startup_only": true, "route": route_report, "traversable": "existing route + connected slice corridors only", "scope": "Far terrain, giants, pillars and carpet are a non-colliding visual blockout. Collision: the NaturalRoute and SliceRoute ribbons and the hero root band."}
