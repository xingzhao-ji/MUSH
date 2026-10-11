class_name ClearingWorld
extends Node3D

## One authored, canonical clearing. Units are the provisional handoff meters.
## Authored procedural geometry with two proposed generated albedo textures.
## Approved anchor pixels are never used as a scenery backdrop.
var environment: Environment
var _stars: MultiMeshInstance3D
var _moon: MeshInstance3D
var sun: DirectionalLight3D
var _sky_fill: DirectionalLight3D
var door_hinge: Node3D
var door_body: StaticBody3D
var wall_plug: Node3D
var right_room: Node3D
var _rain_process: ShaderMaterial
var rain_particles: GPUParticles3D
var night_amount: float = 0.0
var rain_amount: float = 0.0
var _night_target: float = 0.0
var _rain_target: float = 0.0
var _reduced_effects: bool = false
var _room_ready: bool = false
var _room_growth: float = 0.0
var _materials: Dictionary = {}
var _practical_lights: Array[OmniLight3D] = []
var _night_lights: Array[OmniLight3D] = []
var _gill_materials: Array[ShaderMaterial] = []
var _room_colliders: Array[CollisionShape3D] = []
var _plug_colliders: Array[CollisionShape3D] = []
var _sky_material: ProceduralSkyMaterial
var _cloud_sky_material: ShaderMaterial
var _water_material: ShaderMaterial
var _fall_material: ShaderMaterial
var _fireflies: GPUParticles3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _foliage_chunks: Dictionary = {}
var _canopy_far_mesh: ArrayMesh
var _canopy_shadow_mesh: ArrayMesh
var _canopy_far_shadow_mesh: ArrayMesh
var _canopy_mesh: ArrayMesh
var _leaf_mesh: ArrayMesh
var _broadleaf_mesh: ArrayMesh
var _fern_mesh: ArrayMesh
var _flower_mesh: ArrayMesh
var _vine_blossom_mesh: ArrayMesh
var _grass_mesh: ArrayMesh
var _glow_mesh: ArrayMesh
var _main_stem_wall_sectors: Array[PackedVector3Array] = []
var _foreground_understory_meshes: Dictionary = {}
var _rooted_foreground_group_records: Array[Dictionary] = []
var _rooted_foreground_group_stats: Dictionary = {}
var _rooted_foreground_group_load_status: Dictionary = {}
const _FOREGROUND_UNDERSTORY_SHADOW_LABEL: String = "broadleaf_b"
var _foreground_bank_top_faces: Array[PackedVector3Array] = []
var _foreground_bank_original_faces: Array[PackedVector3Array] = []
var _foreground_bank_support_rows: Array[PackedVector3Array] = []
var _time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 483902
	_create_materials()
	_create_lighting()
	_create_terrain()
	_create_home()
	_create_bridge()
	_create_stream()
	_create_forest()
	_create_distant_scenery()
	_create_foliage()
	_create_weather()
	if not bool(get_meta("portable_export", false)):
		_batch_static_meshes()
	_apply_appearance()

func set_appearance(night: bool, rain: bool, reduced_effects: bool) -> void:
	_night_target = 1.0 if night else 0.0
	_rain_target = 1.0 if rain else 0.0
	_reduced_effects = reduced_effects

func _process(delta: float) -> void:
	_time += delta
	var old_night: float = night_amount
	var old_rain: float = rain_amount
	night_amount = move_toward(night_amount, _night_target, delta / 2.0)
	rain_amount = move_toward(rain_amount, _rain_target, delta / 2.0)
	if old_night != night_amount or old_rain != rain_amount:
		_apply_appearance()
	if is_instance_valid(rain_particles):
		rain_particles.emitting = rain_amount > 0.1 and not _reduced_effects
		rain_particles.speed_scale = 0.0 if get_tree().paused else 1.0
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			rain_particles.global_position = camera.global_position + Vector3(0, 6.0, 0)
	if is_instance_valid(_fireflies):
		_fireflies.emitting = night_amount > 0.45 and not _reduced_effects

## Quit-only resource detachment; not called by pause or appearance changes.
func shutdown_visuals() -> void:
	set_process(false)
	for particles: GPUParticles3D in [rain_particles, _fireflies]:
		if is_instance_valid(particles):
			particles.emitting = false
			particles.visible = false
			particles.speed_scale = 0.0
			particles.process_material = null
			particles.draw_pass_1 = null
	_rain_process = null

func set_room_ready(ready: bool) -> void:
	_room_ready = ready
	right_room.visible = ready
	right_room.scale = Vector3.ONE
	wall_plug.visible = not ready
	if _rain_process != null:
		_rain_process.set_shader_parameter("room_enabled", ready)
	for shape: CollisionShape3D in _room_colliders:
		shape.set_deferred("disabled", not ready)
	for shape: CollisionShape3D in _plug_colliders:
		shape.set_deferred("disabled", ready)

func set_room_growth(progress: float) -> void:
	_room_growth = clampf(progress, 0.0, 1.0)
	right_room.visible = _room_ready or _room_growth > 0.0
	var amount: float = maxf(0.025, smoothstep(0.0, 1.0, _room_growth))
	if not _room_ready:
		right_room.scale = Vector3(amount, amount, amount)

func _material(id: String, base: Color, accent: Color, roughness: float = 0.85, scale_value: float = 4.0, grain_value: float = 0.18, kind: float = 0.0) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/world/tactile.gdshader") as Shader
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("accent_color", accent)
	material.set_shader_parameter("roughness_value", roughness)
	material.set_shader_parameter("texture_scale", scale_value)
	material.set_shader_parameter("grain", grain_value)
	material.set_shader_parameter("grain_kind", kind)
	_materials[id] = material
	return material

func _create_materials() -> void:
	_material("cap", Color("ed9b7c"), Color("b56e59"), 0.83, 3.0, 0.30, 2.0)
	_material("cap_rim", Color("efab84"), Color("ba785b"), 0.86, 4.0, 0.25, 2.0)
	_material("plaster", Color("eee2bd"), Color("c3b082"), 0.92, 3.0, 0.35, 1.0)
	_material("wood", Color("825136"), Color("3e2519"), 0.89, 7.0, 0.58, 1.0)
	_material("wood_light", Color("b58550"), Color("79503b"), 0.90, 5.0, 0.47, 1.0)
	_material("floor", Color("c4a276"), Color("8b6548"), 0.90, 4.0, 0.32, 1.0)
	_material("stone", Color("858675"), Color("414b40"), 0.97, 4.0, 0.36)
	_material("stone_light", Color("afa78b"), Color("657060"), 0.95, 4.0, 0.32)
	_material("moss", Color("5a772e"), Color("244c26"), 0.96, 6.0, 0.40)
	_material("soil", Color("575336"), Color("2e3e26"), 0.97, 4.0, 0.30)
	_material("path", Color("b7a181"), Color("7c7760"), 0.98, 6.0, 0.40)
	_material("leaf", Color("48752e"), Color("a3ac49"), 0.88, 3.0, 0.22)
	_material("leaf_gold", Color("718b33"), Color("c0b74d"), 0.88, 3.0, 0.24)
	_material("leaf_dark", Color("2f5b39"), Color("577731"), 0.90, 3.0, 0.26)
	_material("bark", Color("66563c"), Color("322d24"), 0.95, 7.0, 0.55, 1.0)
	_material("flower_white", Color("eee9c8"), Color("d0c9a9"), 0.78, 3.0, 0.16)
	_material("flower_pink", Color("d8a7bd"), Color("99558e"), 0.78, 3.0, 0.20)
	_material("flower_blue", Color("ad9cce"), Color("6561b7"), 0.78, 3.0, 0.20)
	_material("gold", Color("d6a14a"), Color("94632b"), 0.50, 7.0, 0.16)
	_material("iron", Color("343227"), Color("756749"), 0.45, 3.0, 0.12)
	_material("pot", Color("b1774d"), Color("734933"), 0.93, 5.0, 0.32)
	var gill: ShaderMaterial = _material("gill", Color("ebd9b2"), Color("bdae81"), 0.93, 3.0, 0.12, 0.0)
	gill.set_shader_parameter("emission_color", Color("584df1"))
	_gill_materials.append(gill)
	gill.set_meta("emission_scale", 0.45)
	gill.set_shader_parameter("lamella_emission",1.0)
	gill.set_shader_parameter("lamella_recess",0.28)
	var gill_back: ShaderMaterial = _material("gill_back", Color("dfd0ac"), Color("b5a578"), 0.95, 3.0, 0.12, 0.0)
	gill_back.set_shader_parameter("emission_color", Color("584df1"))
	gill_back.set_meta("emission_scale", 0.0)
	_gill_materials.append(gill_back)
	var glow: ShaderMaterial = _material("glow", Color("ffcf7b"), Color("ffd589"), 0.50, 1.0, 0.0)
	glow.set_shader_parameter("emission_color", Color("ffb95b"))
	glow.set_shader_parameter("emission_strength", 1.4)
	for id: String in ["leaf", "leaf_gold", "leaf_dark"]:
		(_materials[id] as ShaderMaterial).set_shader_parameter("foliage", 1.0)
		(_materials[id] as ShaderMaterial).shader = load("res://assets/world/foliage.gdshader") as Shader
	var bark_texture: Texture2D = load("res://assets/world/textures/bark-albedo-proposal-v1.png") as Texture2D
	var moss_texture: Texture2D = load("res://assets/world/textures/moss-albedo-proposal-v1.png") as Texture2D
	(_materials["bark"] as ShaderMaterial).set_shader_parameter("surface_albedo",bark_texture)
	(_materials["bark"] as ShaderMaterial).set_shader_parameter("surface_blend",.94)
	for id: String in ["moss","soil"]:
		var mat: ShaderMaterial = _materials[id] as ShaderMaterial
		mat.set_shader_parameter("surface_albedo",moss_texture)
		mat.set_shader_parameter("surface_blend",.90 if id=="moss" else .78)
		mat.set_shader_parameter("surface_triplanar",true)
		mat.set_shader_parameter("surface_scale",1.20 if id=="moss" else .60)
	_materials["leaf_shadow"] = _materials["leaf"]
	var fairy: ShaderMaterial = _material("fairy", Color("9c9ee8"), Color("c4d0fc"), 0.55, 2.0, 0.06)
	fairy.set_shader_parameter("emission_color", Color("898bf4"))
	fairy.set_shader_parameter("emission_strength", 0.12)

func _create_lighting() -> void:
	var world_env: WorldEnvironment = WorldEnvironment.new()
	add_child(world_env)
	environment = Environment.new()
	world_env.environment = environment
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("527d91")
	_sky_material.sky_horizon_color = Color("d3d5b2")
	_sky_material.ground_bottom_color = Color("344535")
	_sky_material.ground_horizon_color = Color("b3ba91")
	_sky_material.sun_angle_max = 9.0
	_sky_material.sun_curve = 0.12
	_cloud_sky_material = ShaderMaterial.new()
	_cloud_sky_material.shader = load("res://assets/world/clearing_sky.gdshader") as Shader
	sky.sky_material = _cloud_sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c3d4bc")
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = 2
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 1.25
	environment.ssao_intensity = 1.20
	environment.ssao_sharpness = 0.78
	environment.ssr_enabled = true
	environment.ssr_max_steps = 48
	environment.ssr_depth_tolerance = 0.32
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_strength = 0.65
	environment.fog_enabled = true
	environment.fog_light_color = Color("b0c09b")
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.16
	sun = DirectionalLight3D.new()
	sun.name = "SunMoon"
	add_child(sun)
	sun.rotation_degrees = Vector3(-47.0, -38.0, 0.0)
	sun.light_color = Color("ffe6b0")
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.65
	sun.directional_shadow_max_distance = 68.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 0.8
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	_sky_fill = fill
	fill.name = "SoftSkyFill"
	add_child(fill)
	fill.rotation_degrees = Vector3(-28.0, 148.0, 0.0)
	fill.light_color = Color("bdccd8")
	fill.light_energy = 0.10
	_moon = _sphere(Vector3(22.1, 26.0, -44.9), Vector3(2.85, 2.85, 2.85), _materials["flower_white"] as Material, self, 32, 20)
	_moon.name = "Moon"
	var moon_material: ShaderMaterial = ShaderMaterial.new()
	moon_material.shader = load("res://assets/world/moon.gdshader") as Shader
	_moon.material_override = moon_material
	_stars = MultiMeshInstance3D.new()
	_stars.name = "QuietSkyStars"
	add_child(_stars)
	var star_sphere: SphereMesh = SphereMesh.new()
	star_sphere.radius = 0.031
	star_sphere.height = 0.062
	star_sphere.radial_segments = 5
	star_sphere.rings = 3
	var star_material: StandardMaterial3D = StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.albedo_color = Color("a8c5fa")
	star_material.emission_enabled = true
	star_material.emission = Color("a8c5fa")
	star_material.emission_energy_multiplier = 1.1
	star_sphere.material = star_material
	var stars_mm: MultiMesh = MultiMesh.new()
	stars_mm.transform_format = MultiMesh.TRANSFORM_3D
	stars_mm.mesh = star_sphere
	stars_mm.instance_count = 180
	var portable_capture: bool = bool(get_meta("portable_export", false))
	var authored_stars: Array[Transform3D] = []
	for i: int in range(180):
		var p: Vector3 = Vector3(_rng.randf_range(-90, 90), _rng.randf_range(20, 60), _rng.randf_range(-100, -60))
		var authored: Transform3D = Transform3D(Basis().scaled(Vector3.ONE * _rng.randf_range(0.55, 1.8)), p)
		stars_mm.set_instance_transform(i, authored)
		if portable_capture:
			authored_stars.append(authored)
	if portable_capture:
		stars_mm.set_meta("portable_authored_instance_transforms", authored_stars)
	_stars.multimesh = stars_mm


func _apply_appearance() -> void:
	if environment == null:
		return
	_moon.visible = night_amount > 0.6
	_stars.visible = night_amount > 0.6 and rain_amount < 0.4
	sun.rotation_degrees = Vector3(lerpf(-55.0, -27.45, night_amount), lerpf(75.0, 153.79, night_amount), 0.0)
	sun.light_energy = lerpf(1.55, 0.92, night_amount) * lerpf(1.0, 0.63, rain_amount)
	sun.light_color = Color("ffddb0").lerp(Color("9bb3ed"), night_amount)
	environment.ambient_light_color = Color("d9d5c7").lerp(Color("899cca"), night_amount)
	environment.ambient_light_energy = lerpf(0.23, 0.40, night_amount)
	_sky_fill.light_energy = lerpf(0.08, 0.14, night_amount)
	_sky_fill.light_color = Color("c5d4df").lerp(Color("8ca8e9"), night_amount)
	environment.fog_light_color = Color("d0d6c2").lerp(Color("22324c"), night_amount).lerp(Color("647787"), rain_amount * 0.34)
	environment.fog_density = lerpf(0.0024, 0.007, rain_amount)
	_sky_material.sky_top_color = Color("6c9ec1").lerp(Color("0a1236"), night_amount).lerp(Color("3d5366"), rain_amount * 0.35)
	_sky_material.sky_horizon_color = Color("b7c6c5").lerp(Color("172844"), night_amount).lerp(Color("8b9b9e"), rain_amount * 0.32)
	_sky_material.ground_horizon_color = Color("b4c4a0").lerp(Color("29354f"), night_amount)
	_cloud_sky_material.set_shader_parameter("top_color",_sky_material.sky_top_color)
	_cloud_sky_material.set_shader_parameter("horizon_color",_sky_material.sky_horizon_color)
	_cloud_sky_material.set_shader_parameter("ground_color",_sky_material.ground_bottom_color)
	_cloud_sky_material.set_shader_parameter("night_amount",night_amount)
	_cloud_sky_material.set_shader_parameter("rain_amount",rain_amount)
	for practical: OmniLight3D in _practical_lights:
		practical.light_energy = lerpf(0.25, 1.03, night_amount)
	for cool: OmniLight3D in _night_lights:
		cool.light_energy = night_amount * 0.90
	for id: String in ["leaf","leaf_gold","leaf_dark"]:
		(_materials[id] as ShaderMaterial).set_shader_parameter("night_amount",night_amount)
	for gill: ShaderMaterial in _gill_materials:
		gill.set_shader_parameter("emission_strength", night_amount * float(gill.get_meta("emission_scale", 0.72)))
	(_materials["fairy"] as ShaderMaterial).set_shader_parameter("emission_strength", lerpf(0.07, 1.55, night_amount))
	(_materials["glow"] as ShaderMaterial).set_shader_parameter("emission_strength", lerpf(0.30, 0.90, night_amount))
	if _water_material != null:
		_water_material.set_shader_parameter("night_amount", night_amount)
		_water_material.set_shader_parameter("rain_amount", rain_amount)
	if _fall_material != null:
		_fall_material.set_shader_parameter("night_amount", night_amount)

func _create_terrain() -> void:
	var terrain: Node3D = Node3D.new()
	terrain.name = "GroundAndPaths"
	add_child(terrain)
	var west_ground: CollisionShape3D = _ground_piece(-24.0, 7.8, -24.0, 29.0, terrain)
	var east_ground: CollisionShape3D = _ground_piece(10.2, 25.0, -24.0, 29.0, terrain)
	var main_path: Array[Vector3] = [Vector3(-2, 0.028, 23), Vector3(-2, 0.028, 18), Vector3(-1, 0.028, 11), Vector3(0, 0.028, 5.5), Vector3(0, 0.028, 3.0)]
	_path_ribbon(main_path, 1.90, terrain, true)
	var loop: Array[Vector3] = [Vector3(-1, 0.02, 11), Vector3(4, 0.02, 9), Vector3(6.7, 0.02, 7.5)]
	_path_ribbon(loop, 1.80, terrain, true)
	var east_loop: Array[Vector3] = [Vector3(11.3, 0.02, 7.5), Vector3(14, 0.02, 2), Vector3(12, 0.02, -6), Vector3(10.3, 0.02, -7.2)]
	_path_ribbon(east_loop, 1.80, terrain)
	var west_loop: Array[Vector3] = [Vector3(7.7, 0.02, -8), Vector3(5, 0.02, -9), Vector3(-5, 0.02, -7), Vector3(-7, 0.02, 5), Vector3(-1, 0.02, 11)]
	_path_ribbon(west_loop, 1.80, terrain)
	# The stream remains genuinely open beneath the crossing; there is no water floor.
	for i: int in range(80):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z: float = -22.0 + float(i / 2) * 1.24
		var x: float = 9.0 + side * _rng.randf_range(1.22, 1.65)
		var rock: MeshInstance3D = _rock(Vector3(x, -0.06, z), Vector3(_rng.randf_range(0.22, 0.66), _rng.randf_range(0.25, 0.55), _rng.randf_range(0.28, 0.7)), terrain)
		rock.rotation.y = _rng.randf_range(0, TAU)
		if i in [54, 56, 58, 60]:
			_sculpt_foreground_boulder(rock, "WestShoreline_%d" % i)
	for i: int in range(44):
		var p: Vector3 = Vector3(_rng.randf_range(-17, 20), -0.04, _rng.randf_range(-18, 24))
		if _near_route(p, 1.6) or _house_reserved(p):
			continue
		var scale_value: float = _rng.randf_range(0.30, 1.10)
		var scatter_rock: MeshInstance3D = _rock(p, Vector3(scale_value, scale_value * 0.65, scale_value * 0.82), terrain)
		if p.distance_to(Vector3(5.73137, -0.04, 10.61566)) < 0.002:
			_sculpt_foreground_boulder(scatter_rock, "HeroLandwardShoulder")
	_create_foreground_bank_transitions(terrain, west_ground, east_ground)

func _ground_piece(x0: float, x1: float, z0: float, z1: float, parent: Node3D) -> CollisionShape3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var xs: int = int(ceil(x1 - x0))
	var zs: int = int(ceil(z1 - z0))
	for x_index: int in range(xs):
		for z_index: int in range(zs):
			var xa: float = lerpf(x0, x1, float(x_index) / float(xs))
			var xb: float = lerpf(x0, x1, float(x_index + 1) / float(xs))
			var za: float = lerpf(z0, z1, float(z_index) / float(zs))
			var zb: float = lerpf(z0, z1, float(z_index + 1) / float(zs))
			var a: Vector3 = Vector3(xa, _ground_height(xa, za), za)
			var b: Vector3 = Vector3(xb, _ground_height(xb, za), za)
			var c: Vector3 = Vector3(xb, _ground_height(xb, zb), zb)
			var d: Vector3 = Vector3(xa, _ground_height(xa, zb), zb)
			_quad(vertices, normals, uvs, colors, a, d, c, b, Color(0.92, 1.0, 0.82))
	var mesh: ArrayMesh = _array_mesh(vertices, normals, uvs, colors)
	var ground: MeshInstance3D = _instance(mesh, _materials["soil"] as Material, parent)
	ground.name = "ContinuousGround"
	return _mesh_collision(mesh, parent)

# Unapproved revision07 candidate: clipped original floor planes plus low mounds.
func _foreground_bank_relief(point: Vector3, side: int) -> float:
	var t: float = clampf((absf(point.x - 9.0) - 1.20) / 1.60, 0.0, 1.0)
	var across: float = smoothstep(0.0, 0.52, t) * (1.0 - smoothstep(0.52, 1.0, t))
	var centers: PackedFloat64Array = PackedFloat64Array([12.9, 16.6, 21.2]) if side < 0 else PackedFloat64Array([13.8, 18.0, 22.2])
	var radii: PackedFloat64Array = PackedFloat64Array([2.5, 2.1, 2.6]) if side < 0 else PackedFloat64Array([2.8, 2.5, 1.8])
	var heights: PackedFloat64Array = PackedFloat64Array([0.19, 0.24, 0.215]) if side < 0 else PackedFloat64Array([0.18, 0.23, 0.19])
	var along: float = 0.0
	for i: int in range(3):
		var q: float = (point.z - centers[i]) / radii[i]
		along += heights[i] * pow(maxf(0.0, 1.0 - q * q), 3.0)
	var ends: float = smoothstep(10.5, 11.2, point.z) * (1.0 - smoothstep(23.4, 24.0, point.z))
	return across * along * ends

func _foreground_bank_clip(polygon: Array[Vector3], axis: int, limit: float, keep_greater: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if polygon.is_empty():
		return result
	var previous: Vector3 = polygon[polygon.size() - 1]
	var previous_distance: float = (previous.x if axis == 0 else previous.z) - limit
	var previous_inside: bool = previous_distance >= -0.000001 if keep_greater else previous_distance <= 0.000001
	for current: Vector3 in polygon:
		var distance: float = (current.x if axis == 0 else current.z) - limit
		var inside: bool = distance >= -0.000001 if keep_greater else distance <= 0.000001
		if inside != previous_inside:
			var ratio: float = previous_distance / (previous_distance - distance)
			var hit: Vector3 = previous.lerp(current, clampf(ratio, 0.0, 1.0))
			if axis == 0:
				hit.x = limit
			else:
				hit.z = limit
			if result.is_empty() or result[result.size() - 1].distance_squared_to(hit) > 0.000000000001:
				result.append(hit)
		if inside and (result.is_empty() or result[result.size() - 1].distance_squared_to(current) > 0.000000000001):
			result.append(current)
		previous = current
		previous_distance = distance
		previous_inside = inside
	if result.size() > 1 and result[0].distance_squared_to(result[result.size() - 1]) < 0.000000000001:
		result.remove_at(result.size() - 1)
	return result

func _foreground_bank_emit_top(a: Vector3, b: Vector3, c: Vector3, side_index: int, top: PackedVector3Array, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, moss_v: PackedVector3Array, moss_n: PackedVector3Array, moss_u: PackedVector2Array, moss_c: PackedColorArray) -> void:
	var side: int = -1 if side_index == 0 else 1
	var ha: float = _foreground_bank_relief(a, side)
	var hb: float = _foreground_bank_relief(b, side)
	var hc: float = _foreground_bank_relief(c, side)
	if maxf(ha, maxf(hb, hc)) <= 0.000001:
		return
	var pa: Vector3 = a + Vector3.UP * ha
	var pb: Vector3 = b + Vector3.UP * hb
	var pc: Vector3 = c + Vector3.UP * hc
	var cross_value: Vector3 = (pc - pa).cross(pb - pa)
	if cross_value.y <= 0.000000001:
		return
	var normal: Vector3 = cross_value.normalized()
	var face: PackedVector3Array = PackedVector3Array([pa, pb, pc])
	top.append_array(face)
	vertices.append_array(face)
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	for p: Vector3 in face:
		uvs.append(Vector2(p.x, p.z))
		var t: float = clampf((absf(p.x - 9.0) - 1.20) / 1.60, 0.0, 1.0)
		colors.append(Color(0.88, 0.77, 0.57).lerp(Color(0.84, 0.98, 0.73), t))
	var middle: Vector3 = (pa + pb + pc) / 3.0
	var middle_t: float = (absf(middle.x - 9.0) - 1.20) / 1.60
	if middle_t > 0.24 and middle_t < 0.88 and _foreground_bank_relief(middle, side) > 0.025 and sin(middle.z * 1.09 + middle.x * 2.17) + 0.30 * cos(middle.z * 2.71) > -0.10:
		for p: Vector3 in face:
			moss_v.append(p + Vector3.UP * 0.003)
			moss_n.append(normal)
			moss_u.append(Vector2(p.x, p.z))
			moss_c.append(Color(0.91, 1.0, 0.77))

func _foreground_bank_clip_top(a: Vector3, b: Vector3, c: Vector3, side_index: int, top: PackedVector3Array, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, moss_v: PackedVector3Array, moss_n: PackedVector3Array, moss_u: PackedVector2Array, moss_c: PackedColorArray) -> void:
	var x0: float = 6.2 if side_index == 0 else 10.2
	var x1: float = 7.8 if side_index == 0 else 11.8
	var polygon: Array[Vector3] = [a, b, c]
	polygon = _foreground_bank_clip(polygon, 0, x0, true)
	polygon = _foreground_bank_clip(polygon, 0, x1, false)
	polygon = _foreground_bank_clip(polygon, 2, 10.5, true)
	polygon = _foreground_bank_clip(polygon, 2, 24.0, false)
	for i: int in range(1, polygon.size() - 1):
		_foreground_bank_emit_top(polygon[0], polygon[i], polygon[i + 1], side_index, top, vertices, normals, uvs, colors, moss_v, moss_n, moss_u, moss_c)

func _create_foreground_bank_transitions(parent: Node3D, west_collision: CollisionShape3D, east_collision: CollisionShape3D) -> void:
	var soil_v: PackedVector3Array = PackedVector3Array()
	var soil_n: PackedVector3Array = PackedVector3Array()
	var soil_u: PackedVector2Array = PackedVector2Array()
	var soil_c: PackedColorArray = PackedColorArray()
	var moss_v: PackedVector3Array = PackedVector3Array()
	var moss_n: PackedVector3Array = PackedVector3Array()
	var moss_u: PackedVector2Array = PackedVector2Array()
	var moss_c: PackedColorArray = PackedColorArray()
	_foreground_bank_top_faces.clear()
	_foreground_bank_original_faces.clear()
	_foreground_bank_support_rows.clear()
	for _row: int in range(54):
		_foreground_bank_support_rows.append(PackedVector3Array())
	var colliders: Array[CollisionShape3D] = [west_collision, east_collision]
	for side_index: int in range(2):
		var shape: ConcavePolygonShape3D = colliders[side_index].shape as ConcavePolygonShape3D
		var original: PackedVector3Array = shape.get_faces()
		_foreground_bank_original_faces.append(original.duplicate())
		var top: PackedVector3Array = PackedVector3Array()
		var x0: float = 6.2 if side_index == 0 else 10.2
		var x1: float = 7.8 if side_index == 0 else 11.8
		for index: int in range(0, original.size(), 3):
			var a: Vector3 = original[index]
			var b: Vector3 = original[index + 1]
			var c: Vector3 = original[index + 2]
			if maxf(a.x, maxf(b.x, c.x)) < x0 or minf(a.x, minf(b.x, c.x)) > x1 or maxf(a.z, maxf(b.z, c.z)) < 10.5 or minf(a.z, minf(b.z, c.z)) > 24.0:
				continue
			# Sixteen triangles within each original base plane preserve its seams.
			for i: int in range(4):
				for j: int in range(4 - i):
					var p0: Vector3 = a + (b - a) * (float(i) / 4.0) + (c - a) * (float(j) / 4.0)
					var p1: Vector3 = a + (b - a) * (float(i + 1) / 4.0) + (c - a) * (float(j) / 4.0)
					var p2: Vector3 = a + (b - a) * (float(i) / 4.0) + (c - a) * (float(j + 1) / 4.0)
					_foreground_bank_clip_top(p0, p1, p2, side_index, top, soil_v, soil_n, soil_u, soil_c, moss_v, moss_n, moss_u, moss_c)
					if i + j < 3:
						var p3: Vector3 = a + (b - a) * (float(i + 1) / 4.0) + (c - a) * (float(j + 1) / 4.0)
						_foreground_bank_clip_top(p1, p3, p2, side_index, top, soil_v, soil_n, soil_u, soil_c, moss_v, moss_n, moss_u, moss_c)
		_foreground_bank_top_faces.append(top)
		var combined: PackedVector3Array = original.duplicate()
		combined.append_array(top)
		shape.set_faces(combined)
		for index: int in range(0, top.size(), 3):
			var a: Vector3 = top[index]
			var b: Vector3 = top[index + 1]
			var c: Vector3 = top[index + 2]
			var first_row: int = clampi(int(floor((minf(a.z, minf(b.z, c.z)) - 10.5) / 0.5)), 0, 26)
			var last_row: int = clampi(int(floor((maxf(a.z, maxf(b.z, c.z)) - 10.5) / 0.5)), 0, 26)
			for row: int in range(first_row, last_row + 1):
				var faces: PackedVector3Array = _foreground_bank_support_rows[side_index * 27 + row]
				faces.append_array(PackedVector3Array([a, b, c]))
				_foreground_bank_support_rows[side_index * 27 + row] = faces
		# Underwater cut face is visual only: no new river/end collision wall.
		var edge_x: float = 7.8 if side_index == 0 else 10.2
		for row: int in range(27):
			var z0: float = 10.5 + float(row) * 0.5
			var z1: float = z0 + 0.5
			var a: Vector3 = Vector3(edge_x, -0.24, z0)
			var b: Vector3 = Vector3(edge_x, -0.24, z1)
			var c: Vector3 = Vector3(edge_x, 0.0, z1)
			var d: Vector3 = Vector3(edge_x, 0.0, z0)
			if side_index == 0:
				_quad(soil_v, soil_n, soil_u, soil_c, a, d, c, b, Color(0.65, 0.49, 0.34), Vector2(z0, -0.24), Vector2(z0, 0), Vector2(z1, 0), Vector2(z1, -0.24))
			else:
				_quad(soil_v, soil_n, soil_u, soil_c, a, b, c, d, Color(0.65, 0.49, 0.34), Vector2(z0, -0.24), Vector2(z1, -0.24), Vector2(z1, 0), Vector2(z0, 0))
	var soil: MeshInstance3D = _instance(_array_mesh(soil_v, soil_n, soil_u, soil_c), _materials["soil"] as Material, parent)
	soil.name = "CoherentForegroundSoilBanksProposal"
	var moss: MeshInstance3D = _instance(_array_mesh(moss_v, moss_n, moss_u, moss_c), _materials["moss"] as Material, parent)
	moss.name = "BrokenBankMossProposal"

func _foreground_bank_triangle_support(point: Vector3, a: Vector3, b: Vector3, c: Vector3, side: int, raised: bool) -> Dictionary:
	var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
	var ac: Vector2 = Vector2(c.x - a.x, c.z - a.z)
	var ap: Vector2 = Vector2(point.x - a.x, point.z - a.z)
	var determinant: float = ab.cross(ac)
	if absf(determinant) < 0.000000001:
		return {}
	var u: float = ap.cross(ac) / determinant
	var v: float = ab.cross(ap) / determinant
	if u < -0.00001 or v < -0.00001 or u + v > 1.00001:
		return {}
	return {"height": a.y + u * (b.y - a.y) + v * (c.y - a.y), "normal": (c - a).cross(b - a).normalized(), "side": side, "raised": raised}

func _foreground_bank_original_support(point: Vector3, side_index: int) -> Dictionary:
	var x0: float = -24.0 if side_index == 0 else 10.2
	var x1: float = 7.8 if side_index == 0 else 25.0
	var xs: int = 32 if side_index == 0 else 15
	var xi: int = clampi(int(floor((point.x - x0) / (x1 - x0) * float(xs))), 0, xs - 1)
	var zi: int = clampi(int(floor(point.z + 24.0)), 0, 52)
	var first: int = (xi * 53 + zi) * 6
	var faces: PackedVector3Array = _foreground_bank_original_faces[side_index]
	for index: int in [first, first + 3]:
		var hit: Dictionary = _foreground_bank_triangle_support(point, faces[index], faces[index + 1], faces[index + 2], -1 if side_index == 0 else 1, false)
		if not hit.is_empty():
			return hit
	return {}

func _foreground_bank_support(point: Vector3) -> Dictionary:
	if _foreground_bank_support_rows.size() != 54 or point.z < 10.49998 or point.z > 24.00002:
		return {}
	var side_index: int = -1
	if point.x >= 6.19998 and point.x <= 7.80002:
		side_index = 0
	elif point.x >= 10.19998 and point.x <= 11.80002:
		side_index = 1
	if side_index < 0:
		return {}
	var row: int = clampi(int(floor((point.z - 10.5) / 0.5)), 0, 26)
	var faces: PackedVector3Array = _foreground_bank_support_rows[side_index * 27 + row]
	var best: Dictionary = {}
	var best_y: float = -1000.0
	for index: int in range(0, faces.size(), 3):
		var hit: Dictionary = _foreground_bank_triangle_support(point, faces[index], faces[index + 1], faces[index + 2], -1 if side_index == 0 else 1, true)
		if not hit.is_empty() and float(hit["height"]) > best_y:
			best = hit
			best_y = float(hit["height"])
	return best if not best.is_empty() else _foreground_bank_original_support(point, side_index)

func _foreground_bank_surface_height(point: Vector3) -> float:
	# Delta relative to the old analytic helper; adding it yields actual top Y.
	var support: Dictionary = _foreground_bank_support(point)
	return float(support["height"]) - _ground_height(point.x, point.z) if not support.is_empty() else 0.0

func _add_clustered_ground_foliage(id: String, mesh: ArrayMesh, origin: Vector3, rotation_value: Vector3, scale_value: Vector3, reach: float) -> void:
	var point: Vector3 = origin
	var size_value: Vector3 = scale_value
	var turn: Vector3 = rotation_value
	if point.x >= -10.0 and point.x <= 14.0 and point.z >= 8.8 and point.z <= 24.0:
		var cell: Vector2 = Vector2(floor(point.x / 2.6), floor(point.z / 2.6))
		var center: Vector2 = (cell + Vector2(0.5, 0.5)) * 2.6
		center += Vector2(sin(cell.x * 2.31 + cell.y * 5.17), sin(cell.x * 6.73 - cell.y * 1.91)) * 0.58
		var delta: Vector2 = (center - Vector2(point.x, point.z)) * 0.72
		if delta.length() > 0.90:
			delta = delta.normalized() * 0.90
		var proposed: Vector3 = Vector3(clampf(point.x + delta.x, -10.0, 14.0), 0.0, clampf(point.z + delta.y, 8.8, 24.0))
		if _ground_foliage_allowed(proposed, reach):
			point = proposed
		var variation: float = 0.5 + 0.5 * sin(origin.x * 13.71 + origin.z * 8.39 + rotation_value.y * 0.63)
		if mesh == _flower_mesh:
			size_value.y *= lerpf(0.55, 0.90, variation)
		elif mesh == _grass_mesh:
			size_value.y *= lerpf(0.75, 1.05, variation)
		elif mesh == _fern_mesh:
			size_value.y *= lerpf(0.85, 1.0, variation)
		point.y = _ground_height(point.x, point.z)
		var support: Dictionary = _foreground_bank_support(point)
		if not support.is_empty():
			point.y = float(support["height"])
			if bool(support["raised"]) and (mesh == _fern_mesh or mesh == _broadleaf_mesh):
				var up: Vector3 = support["normal"] as Vector3
				var forward: Vector3 = Vector3(sin(turn.y), 0, cos(turn.y))
				forward = (forward - up * up.dot(forward)).normalized()
				var aligned: Basis = Basis(up.cross(forward).normalized(), up, forward)
				var safe: bool = true
				var arrays: Array = mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var scaled: Basis = aligned.scaled(size_value)
				for vertex: Vector3 in vertices:
					var world_point: Vector3 = point + scaled * vertex
					var vertex_support: Dictionary = _foreground_bank_support(world_point)
					if not _ground_foliage_allowed(world_point, 0.0) or (not vertex_support.is_empty() and world_point.y < float(vertex_support["height"]) - 0.002):
						safe = false
						break
				if safe:
					turn = aligned.get_euler()
	if origin.x >= -10.0 and origin.x <= 14.0 and origin.z >= 8.8 and origin.z <= 24.0:
		var choice: Dictionary = _foreground_understory_choice(id, mesh, origin, point, turn, size_value, reach)
		_add_foliage(choice["id"] as String, choice["mesh"] as ArrayMesh, point, turn, size_value)
		return
	_add_foliage(id, mesh, point, turn, size_value)

func _foreground_bank_shrub_lift(point: Vector3) -> float:
	var support: Dictionary = _foreground_bank_support(point)
	return float(support["height"]) - point.y if not support.is_empty() else 0.0

func _add_bank_shrub_leaf(id: String, mesh: ArrayMesh, origin: Vector3, rotation_value: Vector3, scale_value: Vector3, group_lift: float) -> void:
	var point: Vector3 = origin + Vector3.UP * group_lift
	var basis: Basis = Basis.from_euler(rotation_value).scaled(scale_value)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var additional_lift: float = 0.0
	for vertex: Vector3 in vertices:
		var world_point: Vector3 = point + basis * vertex
		var support: Dictionary = _foreground_bank_support(world_point)
		if not support.is_empty() and bool(support["raised"]):
			additional_lift = maxf(additional_lift, float(support["height"]) + 0.002 - world_point.y)
	point.y += additional_lift
	_add_foliage(id, mesh, point, rotation_value, scale_value)

func _ground_height(x: float, z: float) -> float:
	var p: Vector3 = Vector3(x, 0, z)
	if _near_route(p, 2.0) or _house_reserved(p) or absf(x - 9.0) < 2.8:
		return 0.0
	return sin(x * 0.33) * cos(z * 0.24) * 0.11 + 0.045

func _path_ribbon(points: Array[Vector3], width: float, parent: Node3D, authored_paving: bool = false) -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for index: int in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var direction: Vector3 = (b - a).normalized()
		var side: Vector3 = Vector3(-direction.z, 0, direction.x) * width * 0.5
		_quad(vertices, normals, uvs, colors, a - side, b - side, b + side, a + side, Color.WHITE)
		var length_value: float = a.distance_to(b)
		var count: int = int(length_value / 0.55)
		for stone_index: int in range(count):
			var p: Vector3 = a.lerp(b, (float(stone_index) + 0.35) / float(maxi(count, 1)))
			p.y = 0.04
			p += side * _rng.randf_range(-0.65, 0.65)
			var size_value: Vector3 = Vector3(_rng.randf_range(0.40, 0.70), 0.065, _rng.randf_range(0.25, 0.46))
			var stone: MeshInstance3D = _paving_stone(p, size_value, parent) if authored_paving else _rock(p, size_value, parent, false, true)
			stone.rotation.y = _rng.randf_range(-0.25, 0.25)
	_instance(_array_mesh(vertices, normals, uvs, colors), _materials["path"] as Material, parent)

# Unapproved review06 paving geometry proposal. These helpers are not runtime code.
# _paving_stone consumes exactly the same two RNG draws as _rock. The caller
# preserves the other four draws, placement, scale, final yaw and visual count.
func _paving_stone(origin: Vector3, size_value: Vector3, parent: Node3D) -> MeshInstance3D:
	var seed_value: float = _rng.randf_range(0.0, 8.0)
	var mesh: ArrayMesh = _paving_stone_mesh(seed_value)
	var instance: MeshInstance3D = _instance(mesh, _materials["stone_light"] as Material, parent)
	instance.position = origin
	instance.scale = size_value
	instance.rotation.y = _rng.randf_range(0.0, TAU)
	return instance

func _paving_source_range(seed_value: float) -> Vector2:
	# Bounds only: the old ellipsoid vertices are not used to construct the slab.
	var minimum_y: float = 1.0e9
	var maximum_y: float = -1.0e9
	for j: int in range(11):
		for i: int in range(17):
			var point: Vector3 = _rock_point(TAU * float(i) / 16.0, PI * float(j) / 10.0, seed_value)
			minimum_y = minf(minimum_y, point.y)
			maximum_y = maxf(maximum_y, point.y)
	return Vector2(minimum_y, maximum_y)

func _paving_hinge(seed_value: float) -> Vector2:
	var angle: float = 0.65 + sin(seed_value * 0.73) * 0.48
	return Vector2(cos(angle), sin(angle))

func _paving_outline(seed_value: float) -> PackedVector2Array:
	# An authored unequal octagon, with quadratically rounded corners. It is
	# fitted inside every old equatorial edge half-plane, preserving the footprint.
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2(-0.82, -0.46), Vector2(-0.46, -0.78),
		Vector2(0.48, -0.74), Vector2(0.86, -0.39),
		Vector2(0.78, 0.50), Vector2(0.40, 0.80),
		Vector2(-0.48, 0.75), Vector2(-0.88, 0.30)])
	for i: int in range(corners.size()):
		corners[i] += Vector2(sin(seed_value * 1.31 + float(i) * 1.73), cos(seed_value * 0.91 + float(i) * 2.11)) * 0.020
	var fit: float = 1.0
	for i: int in range(16):
		var pa: Vector3 = _rock_point(TAU * float(i) / 16.0, PI * 0.5, seed_value)
		var pb: Vector3 = _rock_point(TAU * float(i + 1) / 16.0, PI * 0.5, seed_value)
		var a: Vector2 = Vector2(pa.x, pa.z)
		var b: Vector2 = Vector2(pb.x, pb.z)
		var edge: Vector2 = b - a
		var outward: Vector2 = Vector2(-edge.y, edge.x).normalized()
		var extent: float = 0.0
		for corner: Vector2 in corners:
			extent = maxf(extent, outward.dot(corner))
		if extent > 0.000001:
			fit = minf(fit, outward.dot(a) * 0.98 / extent)
	for i: int in range(corners.size()):
		corners[i] *= fit
	var rounded: PackedVector2Array = PackedVector2Array()
	for i: int in range(corners.size()):
		var corner: Vector2 = corners[i]
		var amount: float = 0.12 + sin(seed_value + float(i) * 1.70) * 0.02
		var before: Vector2 = corner.lerp(corners[(i + corners.size() - 1) % corners.size()], amount)
		var after: Vector2 = corner.lerp(corners[(i + 1) % corners.size()], amount)
		for j: int in range(5):
			var t: float = float(j) / 4.0
			rounded.append(before * (1.0 - t) * (1.0 - t) + corner * 2.0 * (1.0 - t) * t + after * t * t)
	# Split the perimeter at the two broad top-plane intersections. Tiny cuts
	# near an existing endpoint are omitted to avoid numerical sliver triangles.
	var result: PackedVector2Array = PackedVector2Array()
	var hinge: Vector2 = _paving_hinge(seed_value)
	for i: int in range(rounded.size()):
		var a: Vector2 = rounded[i]
		var b: Vector2 = rounded[(i + 1) % rounded.size()]
		result.append(a)
		var da: float = hinge.dot(a)
		var db: float = hinge.dot(b)
		if da * db < -0.00000001:
			var t: float = da / (da - db)
			if t > 0.01 and t < 0.99:
				result.append(a.lerp(b, t))
	return result

func _paving_top_height(point: Vector2, seed_value: float) -> float:
	# Two gently inclined planar fracture faces, rather than a domed rock top.
	return 0.88 + sin(seed_value * 0.87) * 0.024 * point.x + cos(seed_value * 0.61) * 0.022 * point.y - maxf(0.0, _paving_hinge(seed_value).dot(point)) * 0.040

func _paving_top_normal(point: Vector2, seed_value: float) -> Vector3:
	var hinge: Vector2 = _paving_hinge(seed_value)
	var signed_distance: float = hinge.dot(point)
	var weight: float = 1.0 if signed_distance > 0.000001 else (0.0 if signed_distance < -0.000001 else 0.5)
	return Vector3(-sin(seed_value * 0.87) * 0.024 + hinge.x * weight * 0.040, 1.0, -cos(seed_value * 0.61) * 0.022 + hinge.y * weight * 0.040).normalized()

func _paving_stone_mesh(seed_value: float) -> ArrayMesh:
	var limits: Vector2 = _paving_source_range(seed_value)
	var outline: PackedVector2Array = _paving_outline(seed_value)
	var highest_top: float = _paving_top_height(Vector2.ZERO, seed_value)
	for point: Vector2 in outline:
		highest_top = maxf(highest_top, _paving_top_height(point * 0.90, seed_value))
	var height_offset: float = limits.y - highest_top
	var widths: Array[float] = [0.88, 1.0, 1.0, 0.90]
	var rings: Array[PackedVector3Array] = []
	for row: int in range(4):
		var ring: PackedVector3Array = PackedVector3Array()
		for point: Vector2 in outline:
			var p: Vector2 = point * widths[row]
			var y: float = limits.x
			if row == 1:
				y = limits.x + (limits.y - limits.x) * 0.22
			elif row == 2:
				y = _paving_top_height(p, seed_value) + height_offset - 0.18
			elif row == 3:
				y = _paving_top_height(p, seed_value) + height_offset
			ring.append(Vector3(p.x, y, p.y))
		rings.append(ring)
	var ring_normals: Array[PackedVector3Array] = []
	for row: int in range(4):
		var ns: PackedVector3Array = PackedVector3Array()
		for i: int in range(outline.size()):
			var normal: Vector3 = Vector3.DOWN
			if row == 3:
				normal = _paving_top_normal(Vector2(rings[row][i].x, rings[row][i].z), seed_value)
			elif row > 0:
				var tangent: Vector3 = rings[row][(i + 1) % outline.size()] - rings[row][(i + outline.size() - 1) % outline.size()]
				var rise: Vector3 = rings[row + 1][i] - rings[row - 1][i]
				normal = rise.cross(tangent).normalized()
			ns.append(normal)
		ring_normals.append(ns)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for row: int in range(3):
		for i: int in range(outline.size()):
			var j: int = (i + 1) % outline.size()
			var u0: float = float(i) / float(outline.size())
			var u1: float = float(i + 1) / float(outline.size())
			_smooth_quad(vertices, normals, uvs, colors, rings[row][i], rings[row + 1][i], rings[row + 1][j], rings[row][j], ring_normals[row][i], ring_normals[row + 1][i], ring_normals[row + 1][j], ring_normals[row][j], Color.WHITE, Vector2(u0, float(row) / 3.0), Vector2(u0, float(row + 1) / 3.0), Vector2(u1, float(row + 1) / 3.0), Vector2(u1, float(row) / 3.0))
	var top: Vector3 = Vector3(0.0, _paving_top_height(Vector2.ZERO, seed_value) + height_offset, 0.0)
	var bottom: Vector3 = Vector3(0.0, limits.x, 0.0)
	for i: int in range(outline.size()):
		var j: int = (i + 1) % outline.size()
		var ui: Vector2 = Vector2(rings[3][i].x, rings[3][i].z) * 0.5 + Vector2(0.5, 0.5)
		var uj: Vector2 = Vector2(rings[3][j].x, rings[3][j].z) * 0.5 + Vector2(0.5, 0.5)
		_triangle(vertices, normals, uvs, colors, top, rings[3][j], rings[3][i], Color.WHITE, Vector2(0.5, 0.5), uj, ui)
		_triangle(vertices, normals, uvs, colors, bottom, rings[0][i], rings[0][j], Color.WHITE)
	return _array_mesh(vertices, normals, uvs, colors)

func _create_home() -> void:
	var house: Node3D = Node3D.new()
	house.name = "MushroomHome"
	add_child(house)
	_floor(Vector3(0, 0.48, 0), 3.0, 0.24, house)
	_shell(3.0, 6.30, house, true, false)
	_cap(Vector3(0, 6.50, 0), 5.25, 2.30, house)
	# A ceiling encloses the small downstairs; the balcony is intentionally scenic.
	_cylinder(Vector3(0, 3.13, 0), 2.66, 2.66, 0.15, _materials["floor"] as Material, house, true)
	_create_entry(house)
	_create_stairs(house)
	_create_balcony(house)
	_create_annex(house)
	_create_right_room(house)
	_window(Vector3(0, 5.00, 2.66), 0.45, 0.60, 0.0, house, true)
	_window(Vector3(2.43, 4.92, 1.12), 0.35, 0.48, 1.13, house, true)
	_window(Vector3(-1.91, 4.92, -1.84), 0.35, 0.44, -2.34, house, true)
	_create_chimney(house)
	# Warm wall lanterns and hanging balcony lamps.
	_lantern(Vector3(-1.08, 1.92, 3.02), 0.30, house, true)
	_lantern(Vector3(1.06, 1.86, 3.01), 0.25, house, true)
	_lantern(Vector3(3.56, 3.57, 2.48), 0.29, house, true)
	_lantern(Vector3(4.23, 3.55, 1.29), 0.29, house, true)
	_lantern(Vector3(3.45, 2.35, 2.39), 0.26, house, true)
	for vine_index: int in range(9):
		var vine_angles: Array[float] = [-1.10, -0.94, -0.78, -0.62, -0.44, 0.43, 0.59, 0.76, 0.93]
		var theta: float = vine_angles[vine_index]
		var r: float = 3.04
		var points: Array[Vector3] = []
		for j: int in range(14):
			var y: float = 0.3 + float(j) * 0.38
			var angle: float = theta + sin(float(j) * 0.6 + float(vine_index)) * 0.085
			var vine_r: float = r + sin(float(j)*0.47+float(vine_index))*0.10
			points.append(Vector3(sin(angle) * vine_r, y, cos(angle) * vine_r))
		_vine(points, house, vine_index % 3 == 0, true)
	for side: int in [-1, 1]:
		for pot_index: int in range(3):
			var p: Vector3 = Vector3(float(side) * (1.25 + float(pot_index) * 0.38), 0.16, 3.55 + float(pot_index % 2) * 0.26)
			_pot(p, 0.23 + float(pot_index) * 0.03, house)
			_flower_bouquet(p + Vector3(0, 0.36, 0), house, 9, 0.7)
	# Interior static detailing leaves every specified furniture socket and route open.
	for i: int in range(19):
		var z: float = -2.55 + float(i) * 0.28
		var half: float = sqrt(maxf(0.0, 2.61 * 2.61 - z * z))
		_box(Vector3(0, 0.604, z), Vector3(half * 2.0, 0.017, 0.019), _materials["wood"] as Material, house)
	var shelf: Node3D = Node3D.new()
	shelf.position = Vector3(-0.45, 0.60, -2.2)
	house.add_child(shelf)
	_box(Vector3(0, 0.5, 0), Vector3(1.7, 0.10, 0.35), _materials["wood_light"] as Material, shelf)
	for i: int in range(5):
		_pot(Vector3(-0.70 + i * 0.33, 0.56, 0), 0.09, shelf)
	_practical_light(Vector3(0, 2.35, 0), 5.0, house)

func _shell(radius: float, height_value: float, parent: Node3D, main: bool, room: bool) -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var sides: int = 144 if main else 80
	for side_index: int in range(sides):
		var a: float = -PI + TAU * float(side_index) / float(sides)
		var b: float = -PI + TAU * float(side_index + 1) / float(sides)
		var bottom_a: float = _opening_top(a, radius, main, room)
		var bottom_b: float = _opening_top(b, radius, main, room)
		for vertical_index: int in range(12):
			var ta: float = float(vertical_index) / 12.0
			var tb: float = float(vertical_index + 1) / 12.0
			var ya0: float = lerpf(bottom_a, height_value, ta)
			var ya1: float = lerpf(bottom_a, height_value, tb)
			var yb0: float = lerpf(bottom_b, height_value, ta)
			var yb1: float = lerpf(bottom_b, height_value, tb)
			var pa: Vector3 = _stem_point(a, ya0, radius, height_value)
			var pb: Vector3 = _stem_point(b, yb0, radius, height_value)
			var pc: Vector3 = _stem_point(b, yb1, radius, height_value)
			var pd: Vector3 = _stem_point(a, ya1, radius, height_value)
			_quad(vertices, normals, uvs, colors, pa, pb, pc, pd, Color.WHITE)
	var mesh: ArrayMesh = _main_stem_taper_shell_mesh(vertices,normals,uvs,colors) if main else _array_mesh(vertices,normals,uvs,colors)
	var shell: MeshInstance3D = _instance(mesh, _materials["plaster"] as Material, parent)
	shell.name = "OrganicStemShell"
	_mesh_collision(mesh, parent, room)
	# Thin inner plaster follows the same real holes, giving the shell believable thickness.
	var inner: MeshInstance3D = _instance(mesh, _materials["plaster"] as Material, parent)
	inner.scale = Vector3(0.887, 1, 0.887)
	inner.name = "InnerPlaster"
	_mesh_collision(mesh, inner, room)

func _stem_point(theta: float, y: float, radius: float, top: float) -> Vector3:
	# Extending the scenic upper stem preserves the original wall/arch shape below5.52m.
	var taper_top: float = minf(top, 5.52)
	var shrink: float = 1.0 - smoothstep(1.8, taper_top, y) * 0.17
	var variation: float = 1.0 + sin(theta * 7.0 + y * 0.60) * 0.009 + sin(theta * 13.0) * 0.007
	return Vector3(sin(theta) * radius * shrink * variation, y, cos(theta) * radius * shrink * variation)

func _main_stem_point(theta: float, y: float, radius: float, top: float) -> Vector3:
	# Main-only trial. Lower source positions are unchanged; upper attachments
	# read the actual clipped/tapered mesh that also generates both wall colliders.
	var ideal: Vector3 = _main_stem_taper_position(_stem_point(theta,y,radius,top))
	if y <= 3.35 or _main_stem_wall_sectors.size() != 144 or not is_equal_approx(radius,3.0) or not is_equal_approx(top,6.30):
		return ideal
	var side_index: int = clampi(int(floor((wrapf(theta,-PI,PI)+PI)/TAU*144.0)),0,143)
	var triangles: PackedVector3Array = _main_stem_wall_sectors[side_index]
	var radial: Vector3 = Vector3(sin(theta),0.0,cos(theta))
	var start: Vector3 = radial*(radius*2.0)+Vector3(0.0,y,0.0)
	var direction: Vector3 = -radial
	var surface_radius: float = -1.0
	for offset: int in range(0,triangles.size(),3):
		var a: Vector3 = triangles[offset]
		var b: Vector3 = triangles[offset+1]
		var c: Vector3 = triangles[offset+2]
		if y < minf(a.y,minf(b.y,c.y))-0.000001 or y > maxf(a.y,maxf(b.y,c.y))+0.000001:
			continue
		var e1: Vector3 = b-a
		var e2: Vector3 = c-a
		var h: Vector3 = direction.cross(e2)
		var determinant: float = e1.dot(h)
		if absf(determinant) < 0.00000001:
			continue
		var inverse: float = 1.0/determinant
		var displacement: Vector3 = start-a
		var u: float = inverse*displacement.dot(h)
		var q: Vector3 = displacement.cross(e1)
		var v: float = inverse*direction.dot(q)
		var distance: float = inverse*e2.dot(q)
		if u >= -0.00001 and v >= -0.00001 and u+v <= 1.00001 and distance >= 0.0:
			surface_radius = maxf(surface_radius,radius*2.0-distance)
	if surface_radius > 0.0:
		return radial*surface_radius+Vector3(0.0,y,0.0)
	return ideal

func _main_stem_taper_position(point: Vector3) -> Vector3:
	# Main-only tissue trial: retain the selected lower taper, then recover a
	# small smooth upper flare. The protected lower wall remains exact.
	var narrowing: float = 1.0-0.20*smoothstep(3.35,4.90,point.y)
	var upper: float = smoothstep(4.95,6.30,point.y)
	var theta: float = atan2(point.x,point.z)
	var flesh: float = 0.0065*sin(theta*5.0+0.35)+0.0035*sin(theta*9.0-0.70)
	var envelope: float = narrowing*(1.0+0.09*upper+flesh*upper)
	return Vector3(point.x*envelope,point.y,point.z*envelope)

func _main_stem_clip_triangle(points: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, lower: bool) -> Array:
	var result_points: PackedVector3Array = PackedVector3Array()
	var result_uvs: PackedVector2Array = PackedVector2Array()
	var result_colors: PackedColorArray = PackedColorArray()
	var cut: float = 3.35
	for index: int in range(3):
		var next: int = (index+1)%3
		var inside: bool = points[index].y <= cut if lower else points[index].y >= cut
		var next_inside: bool = points[next].y <= cut if lower else points[next].y >= cut
		if inside:
			result_points.append(points[index])
			result_uvs.append(uvs[index])
			result_colors.append(colors[index])
		if inside != next_inside:
			# Canonical low->high evaluation gives neighbouring faces exactly the
			# same cut position regardless of their opposite edge directions.
			var low: int = index if points[index].y < points[next].y else next
			var high: int = next if low == index else index
			var t: float = (cut-points[low].y)/(points[high].y-points[low].y)
			var intersection: Vector3 = points[low].lerp(points[high],t)
			intersection.y = cut
			result_points.append(intersection)
			result_uvs.append(uvs[low].lerp(uvs[high],t))
			result_colors.append(colors[low].lerp(colors[high],t))
	return [result_points,result_uvs,result_colors]

func _main_stem_taper_shell_mesh(source_vertices: PackedVector3Array, source_normals: PackedVector3Array, source_uvs: PackedVector2Array, source_colors: PackedColorArray) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	_main_stem_wall_sectors.clear()
	var side_start: int = 0
	var last_side: int = 0
	for offset: int in range(0,source_vertices.size(),3):
		var side_index: int = int(float(offset)/72.0)
		if side_index != last_side:
			_main_stem_wall_sectors.append(vertices.slice(side_start,vertices.size()))
			side_start = vertices.size()
			last_side = side_index
		var points: PackedVector3Array = PackedVector3Array([source_vertices[offset],source_vertices[offset+1],source_vertices[offset+2]])
		var triangle_uvs: PackedVector2Array = PackedVector2Array([source_uvs[offset],source_uvs[offset+1],source_uvs[offset+2]])
		var triangle_colors: PackedColorArray = PackedColorArray([source_colors[offset],source_colors[offset+1],source_colors[offset+2]])
		if points[0].y <= 3.35 and points[1].y <= 3.35 and points[2].y <= 3.35:
			# Do not reconstruct any complete lower triangle: retain its exact bytes.
			vertices.append_array(points)
			normals.append_array(PackedVector3Array([source_normals[offset],source_normals[offset+1],source_normals[offset+2]]))
			uvs.append_array(triangle_uvs)
			colors.append_array(triangle_colors)
			continue
		for lower: bool in [true,false]:
			var clipped: Array = _main_stem_clip_triangle(points,triangle_uvs,triangle_colors,lower)
			var polygon: PackedVector3Array = clipped[0] as PackedVector3Array
			var polygon_uvs: PackedVector2Array = clipped[1] as PackedVector2Array
			var polygon_colors: PackedColorArray = clipped[2] as PackedColorArray
			for index: int in range(1,polygon.size()-1):
				var a: Vector3 = polygon[0] if lower else _main_stem_taper_position(polygon[0])
				var b: Vector3 = polygon[index] if lower else _main_stem_taper_position(polygon[index])
				var c: Vector3 = polygon[index+1] if lower else _main_stem_taper_position(polygon[index+1])
				# Input polygon is already GodotCW. Preserve the original lower face
				# normal; recompute flat upper normals after changing their geometry.
				var normal: Vector3 = source_normals[offset] if lower else -(b-a).cross(c-a).normalized()
				vertices.append_array(PackedVector3Array([a,b,c]))
				normals.append_array(PackedVector3Array([normal,normal,normal]))
				uvs.append_array(PackedVector2Array([polygon_uvs[0],polygon_uvs[index],polygon_uvs[index+1]]))
				colors.append_array(PackedColorArray([polygon_colors[0],polygon_colors[index],polygon_colors[index+1]]))
	_main_stem_wall_sectors.append(vertices.slice(side_start,vertices.size()))
	return _array_mesh(vertices,normals,uvs,colors)

func _main_stem_window_point(point: Vector3, center: Vector3, yaw: float, clearance: float) -> Vector3:
	# Point is in the original flat window's coordinates. Use the new wall radius
	# at each vertexY plus its shallow depth for tangent width, not an old radius.
	# This keeps original width to first order while bending every component.
	var center_theta: float = atan2(center.x,center.z)
	var vertex_surface: Vector3 = _main_stem_point(center_theta,center.y+point.y,3.0,6.30)
	var vertex_radius: float = Vector2(vertex_surface.x,vertex_surface.z).length()+clearance+point.z
	var theta: float = center_theta+point.x/vertex_radius
	var surface: Vector3 = _main_stem_point(theta,center.y+point.y,3.0,6.30)
	var radial: Vector3 = Vector3(sin(theta),0.0,cos(theta))
	var attached: Vector3 = surface+radial*(clearance+point.z)
	return Basis(Vector3.UP,yaw).transposed()*(attached-center)

func _main_stem_ivy_point(point: Vector3) -> Vector3:
	if point.y <= 3.35:
		return point
	var old_radius: float = Vector2(point.x,point.z).length()
	var theta: float = atan2(point.x,point.z)
	var surface: Vector3 = _main_stem_point(theta,point.y,3.0,6.30)
	var surface_radius: float = Vector2(surface.x,surface.z).length()
	# Existing source paths were centred at3.04m. Keep their angular/y detail,
	# compress radial waviness and offsets into a shallow0.10m surface cushion.
	var attached_radius: float = surface_radius+0.10+(old_radius-3.04)*0.35
	var blend: float = smoothstep(3.35,4.45,point.y)
	var radius: float = lerpf(old_radius,attached_radius,blend)
	return Vector3(sin(theta)*radius,point.y,cos(theta)*radius)

func _main_stem_attachment_basis(point: Vector3, center: Vector3, yaw: float, clearance: float, window: bool) -> Basis:
	# Positive local Jacobian; use inverse-transpose for deformed mesh normals.
	# Ivy uses its first-order transform to retain the existing shared leaf meshes.
	var epsilon: float = 0.0005
	var x: Vector3 = Vector3(epsilon,0.0,0.0)
	var y: Vector3 = Vector3(0.0,epsilon,0.0)
	var z: Vector3 = Vector3(0.0,0.0,epsilon)
	if window:
		return Basis((_main_stem_window_point(point+x,center,yaw,clearance)-_main_stem_window_point(point-x,center,yaw,clearance))/(2.0*epsilon),(_main_stem_window_point(point+y,center,yaw,clearance)-_main_stem_window_point(point-y,center,yaw,clearance))/(2.0*epsilon),(_main_stem_window_point(point+z,center,yaw,clearance)-_main_stem_window_point(point-z,center,yaw,clearance))/(2.0*epsilon))
	return Basis((_main_stem_ivy_point(point+x)-_main_stem_ivy_point(point-x))/(2.0*epsilon),(_main_stem_ivy_point(point+y)-_main_stem_ivy_point(point-y))/(2.0*epsilon),(_main_stem_ivy_point(point+z)-_main_stem_ivy_point(point-z))/(2.0*epsilon))

func _main_stem_conform_window_mesh(instance: MeshInstance3D, center: Vector3, yaw: float, clearance: float) -> void:
	# Reuse each existing node/material/index/UV stream; replace its resource with
	# a same-topology ArrayMesh because primitive meshes cannot bend vertex-wise.
	var source: Mesh = instance.mesh
	var source_transform: Transform3D = instance.transform
	var result: ArrayMesh = ArrayMesh.new()
	var point_samples: Dictionary = {}
	for surface_index: int in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var tangents: PackedFloat32Array = PackedFloat32Array()
		if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
			tangents = arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
		var changed_vertices: PackedVector3Array = PackedVector3Array()
		var changed_normals: PackedVector3Array = PackedVector3Array()
		var changed_tangents: PackedFloat32Array = PackedFloat32Array()
		for vertex_index: int in range(vertices.size()):
			var point: Vector3 = source_transform*vertices[vertex_index]
			var sample: Transform3D
			if point_samples.has(point):
				sample = point_samples[point] as Transform3D
			else:
				sample = Transform3D(_main_stem_attachment_basis(point,center,yaw,clearance,true),_main_stem_window_point(point,center,yaw,clearance))
				point_samples[point] = sample
			var jacobian: Basis = sample.basis*source_transform.basis
			if not (jacobian.determinant() > 0.0):
				push_error("Main window mapping has a non-positive vertex Jacobian.")
			var normal: Vector3 = (jacobian.inverse().transposed()*normals[vertex_index]).normalized()
			changed_vertices.append(sample.origin)
			changed_normals.append(normal)
			if tangents.size() == vertices.size()*4:
				var tangent: Vector3 = jacobian*Vector3(tangents[vertex_index*4],tangents[vertex_index*4+1],tangents[vertex_index*4+2])
				tangent = (tangent-normal*normal.dot(tangent)).normalized()
				changed_tangents.append(tangent.x)
				changed_tangents.append(tangent.y)
				changed_tangents.append(tangent.z)
				changed_tangents.append(tangents[vertex_index*4+3])
		var repaired: Array = _main_stem_window_reconcile_frames(changed_vertices,changed_normals,changed_tangents,arrays[Mesh.ARRAY_INDEX])
		changed_normals = repaired[0] as PackedVector3Array
		changed_tangents = repaired[1] as PackedFloat32Array
		arrays[Mesh.ARRAY_VERTEX] = changed_vertices
		arrays[Mesh.ARRAY_NORMAL] = changed_normals
		if tangents.size() == vertices.size()*4:
			arrays[Mesh.ARRAY_TANGENT] = changed_tangents
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface_index,source.surface_get_material(surface_index))
	instance.mesh = result
	instance.transform = Transform3D.IDENTITY

func _main_stem_window_normal_score(value: Vector3, faces: PackedVector3Array) -> float:
	var score: float = 1.0
	for face: Vector3 in faces:
		score = minf(score,value.dot(face))
	return score

func _main_stem_window_front_normal(value: Vector3, faces: PackedVector3Array) -> Vector3:
	# Smooth-map normals must also face every final incident CW chord triangle.
	# Solve the unit-sphere max-min hemisphere using its one/two/three active
	# constraints. No index splitting or welding across existing UV/normal seams.
	var margin: float = 0.01
	if faces.is_empty() or _main_stem_window_normal_score(value,faces) >= margin:
		return value
	var candidates: PackedVector3Array = PackedVector3Array()
	var sum: Vector3 = Vector3.ZERO
	for face: Vector3 in faces:
		candidates.append(face)
		sum += face
	if sum.length_squared() > 0.0:
		candidates.append(sum.normalized())
	for a: int in range(faces.size()):
		for b: int in range(a+1,faces.size()):
			var bisector: Vector3 = faces[a]+faces[b]
			if bisector.length_squared() > 0.0:
				candidates.append(bisector.normalized())
			for c: int in range(b+1,faces.size()):
				var axis: Vector3 = (faces[a]-faces[b]).cross(faces[a]-faces[c])
				if axis.length_squared() > 0.0:
					axis = axis.normalized()
					candidates.append(axis)
					candidates.append(-axis)
	var best: Vector3 = Vector3.ZERO
	var best_score: float = -2.0
	for direction: Vector3 in candidates:
		var score: float = _main_stem_window_normal_score(direction,faces)
		if score > best_score:
			best_score = score
			best = direction
	if best_score <= margin:
		push_error("Main window final faces have no robust common normal hemisphere; geometry refinement required.")
		return value
	# Smallest convex blend toward the feasible direction satisfying all planes.
	# Both endpoints are unit, so normalization cannot lower positive raw dots.
	var blend: float = 0.0
	for face: Vector3 in faces:
		var start: float = value.dot(face)
		if start < margin:
			blend = maxf(blend,(margin-start)/(best.dot(face)-start))
	var repaired: Vector3 = value.lerp(best,clampf(blend,0.0,1.0)).normalized()
	if _main_stem_window_normal_score(repaired,faces) < margin*0.99:
		push_error("Main window final normal hemisphere reconciliation failed.")
	return repaired

func _main_stem_window_reconcile_frames(vertices: PackedVector3Array, normals: PackedVector3Array, tangents: PackedFloat32Array, index_data: Variant) -> Array:
	var order: PackedInt32Array = PackedInt32Array()
	if index_data is PackedInt32Array:
		order = index_data as PackedInt32Array
	if order.is_empty():
		for i: int in range(vertices.size()):
			order.append(i)
	var incident: Array[PackedVector3Array] = []
	for i: int in range(vertices.size()):
		incident.append(PackedVector3Array())
	for offset: int in range(0,order.size(),3):
		var a: int = order[offset]
		var b: int = order[offset+1]
		var c: int = order[offset+2]
		var face: Vector3 = (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		if face.length_squared() == 0.0:
			continue # Inherited exactly collapsed primitive poles, not a waiver.
		face = face.normalized()
		for index: int in [a,b,c]:
			var faces: PackedVector3Array = incident[index]
			faces.append(face)
			incident[index] = faces
	var repaired_normals: PackedVector3Array = PackedVector3Array()
	var repaired_tangents: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(vertices.size()):
		var normal: Vector3 = _main_stem_window_front_normal(normals[i],incident[i])
		repaired_normals.append(normal)
		if tangents.size() == vertices.size()*4:
			var tangent: Vector3 = Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			tangent -= normal*normal.dot(tangent)
			if tangent.length_squared() < 0.000000000001:
				var axis: Vector3 = Vector3.RIGHT if absf(normal.x) < 0.8 else Vector3.UP
				tangent = axis-normal*normal.dot(axis)
			tangent = tangent.normalized()
			repaired_tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,tangents[i*4+3]]))
	return [repaired_normals,repaired_tangents]

func _main_stem_conform_window(window: Node3D) -> void:
	var center: Vector3 = window.position
	var yaw: float = window.rotation.y
	var mesh_index: int = 0
	for child: Node in window.get_children():
		if child is MeshInstance3D:
			# Glow min depth36mm; frame min40mm; sill min35mm. Keep sill's
			# original0.30m depth rather than flattening its authored structure.
			var clearance: float = 0.085 if mesh_index == 0 else (0.185 if mesh_index == 4 else 0.045)
			_main_stem_conform_window_mesh(child as MeshInstance3D,center,yaw,clearance)
			mesh_index += 1
		elif child is OmniLight3D:
			var light: OmniLight3D = child as OmniLight3D
			light.position = _main_stem_window_point(light.position,center,yaw,0.0)

func _main_stem_attach_ivy_instance(instance: MeshInstance3D) -> void:
	var source: Transform3D = instance.transform
	if source.origin.y <= 3.35:
		return
	var jacobian: Basis = _main_stem_attachment_basis(source.origin,Vector3.ZERO,0.0,0.0,false)
	var fitted: Transform3D = Transform3D(jacobian*source.basis,_main_stem_ivy_point(source.origin))
	var theta: float = atan2(source.origin.x,source.origin.z)
	var outward: Vector3 = Vector3(sin(theta),0.0,cos(theta))
	# The shared leaf/blossom meshes remain shared. Check their actual vertices
	# because a valid mapped origin does not guarantee corner clearance on a
	# changing polygonal wall. Three bounded passes make only a minimal origin
	# correction, retaining all RNG calls, instance counts and source geometry.
	for pass_index: int in range(3):
		var correction: float = 0.0
		for surface_index: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface_index)
			var mesh_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex: Vector3 in mesh_vertices:
				var point: Vector3 = fitted*vertex
				if point.y <= 3.35:
					continue
				var point_theta: float = atan2(point.x,point.z)
				var surface: Vector3 = _main_stem_point(point_theta,point.y,3.0,6.30)
				var surface_radius: float = Vector2(surface.x,surface.z).length()
				var point_radius: float = Vector2(point.x,point.z).length()
				var alignment: float = maxf(0.85,cos(point_theta-theta))
				correction = maxf(correction,(surface_radius+0.004-point_radius)/alignment)
		if correction <= 0.0:
			break
		fitted.origin += outward*correction
	instance.transform = fitted

func _opening_top(theta: float, radius: float, main: bool, room: bool) -> float:
	var x: float = sin(theta) * radius
	var z: float = cos(theta) * radius
	if main:
		if z > 2.5 and absf(x) < 0.84:
			return 1.825 + sqrt(maxf(0.0, 0.84 * 0.84 - x * x))
		if x < -2.3 and absf(z + 0.40) < 0.82:
			return 1.82 + sqrt(maxf(0.0, 0.82 * 0.82 - (z + 0.40) * (z + 0.40)))
		if x > 2.3 and absf(z - 0.60) < 0.76:
			return 1.82 + sqrt(maxf(0.0, 0.76 * 0.76 - (z - 0.60) * (z - 0.60)))
	elif room:
		if x < -1.10 and absf(z) < 0.76:
			return 1.82 + sqrt(maxf(0.0, 0.76 * 0.76 - z * z))
	else:
		if x > 0.9 and absf(z) < 0.82:
			return 1.82 + sqrt(maxf(0.0, 0.82 * 0.82 - z * z))
	return 0.60

func _cap_dome_height(fraction: float, crown: float) -> float:
	return crown * pow(maxf(0.0, 1.0 - fraction * fraction), 0.52)

func _cap_underside_height(fraction: float, radius: float) -> float:
	var t: float = clampf((fraction - 0.355) / 0.617, 0.0, 1.0)
	return radius * (-0.055 - 0.100 * pow(1.0-t,2.0) - sin(t*PI)*0.015)

func _cap_wave(theta: float, fraction: float, radius: float) -> float:
	# The underside, lip and folds share the same low-frequency deformation.
	return (sin(theta*5.0+0.7)*0.14 + sin(theta*11.0-0.3)*0.025) * radius/5.5 * pow(fraction,3.0)

func _cap_radial_scale(theta: float) -> float:
	return 1.0 + sin(theta*7.0)*0.010 + sin(theta*13.0+0.7)*0.005

func _cap_surface_point(profile_point: Vector2, theta: float, radius: float, skin: bool) -> Vector3:
	var fraction: float = profile_point.x/radius
	var r: float = profile_point.x*_cap_radial_scale(theta)
	var y: float = profile_point.y + _cap_wave(theta,fraction,radius)
	if skin:
		var envelope: float = smoothstep(0.07,0.30,fraction)*pow(fraction,1.2)
		var phase: float = theta*36.0 + sin(theta*7.0)*0.30 + sin(fraction*3.1+theta*3.0)*0.65
		if radius > 4.0:
			# Unequal fleshy valleys flow from crown toward the rounded peach rim.
			# These are continuous surface displacements, not seam tubes.
			var crease_phase: float = theta*24.0+sin(theta*5.0)*0.58+sin(fraction*3.1+theta*3.0)*0.78
			var crease: float = pow(0.5+0.5*sin(crease_phase),4.0)
			var strength: float = 0.58+0.42*(0.5+0.5*sin(theta*3.0+0.37))
			var short_gate: float = smoothstep(0.26,0.54,fraction)*(1.0-smoothstep(0.88,0.98,fraction))
			var short_phase: float = theta*43.0+sin(theta*7.0)*0.32+sin(fraction*5.1+theta*3.0)*0.45
			var short_crease: float = pow(0.5+0.5*sin(short_phase),6.0)*short_gate
			var return_height: float = _cap_underside_height(fraction,radius)
			envelope *= smoothstep(return_height+0.02,return_height+0.15,profile_point.y)
			y += radius*(0.0026*sin(theta*11.0+fraction*2.2)-0.0110*strength*crease-0.0025*short_crease)*envelope
			# Low irregular flesh within the turn, fading with zero derivative at
			# both ends. It neither moves the exact lip nor changes XZ footprint.
			var flesh_t: float = clampf((profile_point.y-return_height)/(radius*0.190),0.0,1.0)
			var flesh_bell: float = pow(sin(flesh_t*PI),2.0)*smoothstep(0.94,0.98,fraction)
			y += radius*0.0075*(0.55*sin(theta*5.0+0.15)+0.30*sin(theta*9.0-0.42))*flesh_bell
		else:
			y += radius*0.0036*sin(phase)*envelope
			y += radius*0.0020*sin(theta*18.0+fraction*1.8)*envelope
	return Vector3(sin(theta)*r,y,cos(theta)*r)

func _cap_surface_mesh(profile: Array[Vector2], radius: float, skin: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var sides: int = 192 if radius>4.0 else 112
	var rings: Array[PackedVector3Array] = []
	var ns: Array[PackedVector3Array] = []
	for j: int in range(profile.size()):
		var ring: PackedVector3Array = PackedVector3Array()
		var normal_ring: PackedVector3Array = PackedVector3Array()
		for i: int in range(sides+1):
			var theta: float = TAU*float(i)/float(sides)
			var point: Vector3 = _cap_surface_point(profile[j],theta,radius,skin)
			var du: Vector3 = _cap_surface_point(profile[j],theta+0.002,radius,skin)-_cap_surface_point(profile[j],theta-0.002,radius,skin)
			var dv: Vector3 = _cap_surface_point(profile[mini(j+1,profile.size()-1)],theta,radius,skin)-_cap_surface_point(profile[maxi(0,j-1)],theta,radius,skin)
			var normal: Vector3 = dv.cross(du).normalized()*(1.0 if skin else -1.0)
			if profile[j].x<0.001: normal=Vector3.UP
			ring.append(point)
			normal_ring.append(normal)
		rings.append(ring)
		ns.append(normal_ring)
	for j: int in range(profile.size()-1):
		var va: float = float(j)/float(profile.size()-1)
		var vb: float = float(j+1)/float(profile.size()-1)
		for i: int in range(sides):
			var ua: float = float(i)/float(sides)
			var ub: float = float(i+1)/float(sides)
			if skin:
				# Godot clockwise front faces must agree with the stored up/outward skin normals.
				_smooth_quad(vertices,normals,uvs,colors,rings[j][i],rings[j+1][i],rings[j+1][i+1],rings[j][i+1],ns[j][i],ns[j+1][i],ns[j+1][i+1],ns[j][i+1],Color.WHITE,Vector2(ua,va),Vector2(ua,vb),Vector2(ub,vb),Vector2(ub,va))
			else:
				_smooth_quad(vertices,normals,uvs,colors,rings[j][i],rings[j][i+1],rings[j+1][i+1],rings[j+1][i],ns[j][i],ns[j][i+1],ns[j+1][i+1],ns[j+1][i],Color.WHITE,Vector2(ua,va),Vector2(ub,va),Vector2(ub,vb),Vector2(ua,vb))
	return _array_mesh(vertices,normals,uvs,colors)

func _cap_gill_depth(fraction: float, radius: float, theta: float) -> float:
	var t: float = clampf((fraction-0.355)/0.613,0.0,1.0)
	var depth: float = radius*0.033*(0.5+sin(t*PI)*0.5)*(1.0-0.60*t)*(0.92+sin(theta*5.0)*0.08)
	if radius > 4.0:
		depth *= 1.32*(0.10+0.90*smoothstep(0.455,0.590,fraction))*(0.84+sin(theta*4.0+0.8)*0.12+sin(theta*11.0-0.2)*0.07)
	return depth

func _cap_lamella_mesh(radius: float) -> ArrayMesh:
	if radius > 4.0:
		return _cap_main_lamella_mesh(radius)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var count: int = int(clampf(radius*23.3,52.0,128.0))
	var spacing: float = TAU/float(count)
	var sections: int = 24
	# Long folds fork into shorter outer folds, increasing detail toward the lip.
	# All lamellae remain one mesh/material per mushroom; no extra lights or particles.
	for family: int in range(2):
		for i: int in range(count):
			var theta: float = float(i)*spacing
			var begin: float = 0.355 if family==0 else 0.59+sin(theta*7.0+0.8)*0.035
			var tops_left: Array[Vector3] = []
			var tops_right: Array[Vector3] = []
			var edges: Array[Vector3] = []
			for j: int in range(sections+1):
				var t: float = float(j)/float(sections)
				var fraction: float = lerpf(begin,0.968,t)
				var global_t: float = clampf((fraction-0.355)/0.613,0.0,1.0)
				var angle: float = theta+sin(global_t*PI)*sin(theta*3.0+0.2)*0.032
				if family==1: angle+=spacing*0.5*smoothstep(0.0,0.55,t)
				angle+=sin(global_t*PI)*sin(theta*13.0+global_t*3.0)*0.004
				var r: float = radius*fraction*_cap_radial_scale(angle)
				var y: float = _cap_underside_height(fraction,radius)+_cap_wave(angle,fraction,radius)
				var half_angle: float = spacing*lerpf(0.31,0.21,global_t)
				if family==1: half_angle=spacing*0.21*smoothstep(0.0,0.15,t)
				var depth: float = _cap_gill_depth(fraction,radius,theta)
				if family==1: depth*=lerpf(1.0,0.84,smoothstep(0.0,0.30,t))
				tops_left.append(Vector3(sin(angle-half_angle)*r,y,cos(angle-half_angle)*r))
				tops_right.append(Vector3(sin(angle+half_angle)*r,y,cos(angle+half_angle)*r))
				edges.append(Vector3(sin(angle)*r,y-depth,cos(angle)*r))
			var shade: float = 0.94+sin(theta*9.0+float(family))*0.045
			var color_value: Color = Color(shade,shade,shade)
			for j: int in range(sections):
				var ta: float = float(j)/float(sections)
				var tb: float = float(j+1)/float(sections)
				_quad(vertices,normals,uvs,colors,tops_left[j],edges[j],edges[j+1],tops_left[j+1],color_value,Vector2(0,ta),Vector2(1,ta),Vector2(1,tb),Vector2(0,tb))
				_quad(vertices,normals,uvs,colors,tops_right[j],tops_right[j+1],edges[j+1],edges[j],color_value,Vector2(0,ta),Vector2(0,tb),Vector2(1,tb),Vector2(1,ta))
			_triangle(vertices,normals,uvs,colors,tops_left[0],tops_right[0],edges[0],color_value)
			_triangle(vertices,normals,uvs,colors,tops_right[sections],tops_left[sections],edges[sections],color_value)
	return _array_mesh(vertices,normals,uvs,colors)

func _cap(origin: Vector3, radius: float, crown: float, parent: Node3D) -> void:
	var rim_depth: float = radius*0.061
	var profile: Array[Vector2] = []
	for i: int in range(33):
		var fraction: float = 0.975*sin(float(i)/32.0*PI*0.5)
		profile.append(Vector2(radius*fraction,_cap_dome_height(fraction,crown)))
	profile.append(Vector2(radius*0.989,rim_depth*0.55))
	profile.append(Vector2(radius,rim_depth*0.08))
	profile.append(Vector2(radius*0.997,-rim_depth*0.48))
	profile.append(Vector2(radius*0.984,-rim_depth*0.90))
	profile.append(Vector2(radius*0.963,-rim_depth*1.03))
	if radius > 4.0:
		profile = _cap_rolled_profile(radius,crown)
	var cap: MeshInstance3D = _instance(_cap_surface_mesh(profile,radius,true),_materials["cap"] as Material,parent)
	cap.position=origin
	cap.name="FoldedPeachUmbrella"
	if radius > 4.0:
		var main_gill: ShaderMaterial = (_materials["gill"] as ShaderMaterial).duplicate() as ShaderMaterial
		main_gill.set_shader_parameter("lamella_root_fade",1.0)
		_gill_materials.append(main_gill)
		var underbody: MeshInstance3D = _instance(_cap_main_pleated_underbody_mesh(radius),main_gill,parent)
		underbody.position = origin
		underbody.name = "ContinuousPleatedCreamUnderbody"
		return
	var underside_profile: Array[Vector2] = []
	for i: int in range(25):
		var fraction: float = lerpf(0.355,0.972,float(i)/24.0)
		underside_profile.append(Vector2(radius*fraction,_cap_underside_height(fraction,radius)))
	var underside: MeshInstance3D = _instance(_cap_surface_mesh(underside_profile,radius,false),_materials["gill_back"] as Material,parent)
	underside.position=origin
	underside.name="CreamGillUnderside"
	var gills: MeshInstance3D = _instance(_cap_lamella_mesh(radius),_materials["gill"] as Material,parent)
	gills.position=origin
	gills.name="ForkedCurvedLamellae"

func _cap_rolled_profile(radius: float, crown: float) -> Array[Vector2]:
	# Main-only flesh trial. Keep every radial sample and the exact cream lip.
	var profile: Array[Vector2] = []
	var start_fraction: float = 0.955
	var dome_exponent: float = 0.49
	for i: int in range(33):
		var fraction: float = start_fraction*sin(float(i)/32.0*PI*0.5)
		var shoulder: float = smoothstep(0.45,0.70,fraction)*(1.0-smoothstep(0.88,start_fraction,fraction))
		var height: float = crown*pow(maxf(0.0,1.0-fraction*fraction),dome_exponent)+radius*0.009*shoulder
		profile.append(Vector2(radius*fraction,height))
	var start: Vector2 = profile[profile.size()-1]
	var finish: Vector2 = Vector2(radius*0.972,_cap_underside_height(0.972,radius))
	var dome_slope: float = -2.0*crown*dome_exponent*start_fraction*pow(1.0-start_fraction*start_fraction,dome_exponent-1.0)
	var outer_slope: float = radius*0.015*PI/0.617
	var control_a: Vector2 = Vector2(radius*1.006,start.y+dome_slope*(1.006-start_fraction))
	var control_b: Vector2 = Vector2(radius*1.014,finish.y+outer_slope*(1.014-0.972))
	for i: int in range(1,9):
		var t: float = float(i)/8.0
		var u: float = 1.0-t
		var point: Vector2 = start*u*u*u+control_a*3.0*u*u*t+control_b*3.0*u*t*t+finish*t*t*t
		if i < 8:
			# A rounded vertical flesh turn; no radial growth or moved seam.
			point.y += radius*0.012*pow(sin(t*PI),2.0)
		profile.append(point)
	return profile

func _cap_main_lamella_mesh(radius: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var count: int = int(clampf(radius*13.72,64.0,80.0))
	var spacing: float = TAU/float(count)
	var sections: int = 20
	# Broad primary folds and a dispersed shorter tier, with a five-point rounded section.
	# The deterministic phase changes no world RNG draw or downstream plant placement.
	for family: int in range(2):
		for i: int in range(count):
			if family == 1 and sin(float(i)*2.399963+0.8) > 0.10:
				continue
			var theta: float = spacing*(float(i)+sin(float(i)*1.7)*0.12+sin(float(i)*0.63)*0.06)
			var begin: float = 0.355+sin(theta*5.0+0.4)*0.015 if family == 0 else 0.59+sin(theta*7.0+0.8)*0.050+sin(theta*3.0)*0.020
			var finish: float = 0.968+sin(theta*7.0)*0.004+sin(theta*17.0+0.3)*0.003
			var rows: Array[PackedVector3Array] = []
			var row_normals: Array[PackedVector3Array] = []
			for j: int in range(sections+1):
				var t: float = float(j)/float(sections)
				var fraction: float = lerpf(begin,finish,t)
				var global_t: float = clampf((fraction-0.355)/0.613,0.0,1.0)
				var angle: float = theta+sin(global_t*PI)*(sin(theta*3.0+0.2)*0.035+sin(theta*7.0-0.4)*0.009)
				if family == 1:
					angle += spacing*(0.46+sin(theta*5.0)*0.07)*smoothstep(0.0,0.55,t)
				var half_angle: float = spacing*lerpf(0.28,0.20,global_t)
				if family == 1:
					half_angle = spacing*0.14*(0.18+0.82*smoothstep(0.0,0.15,t))
				var depth: float = _cap_gill_depth(fraction,radius,theta)
				if family == 1:
					depth *= (0.76+sin(theta*7.0+0.6)*0.10)*(0.28+0.72*smoothstep(0.0,0.16,t))
				var row: PackedVector3Array = PackedVector3Array()
				var cross_offsets: Array[float] = [-1.0,-0.55,0.0,0.55,1.0]
				var cross_depths: Array[float] = [0.0,0.75,1.0,0.75,0.0]
				for k: int in range(5):
					var sample_angle: float = angle+half_angle*cross_offsets[k]
					var r: float = radius*fraction*_cap_radial_scale(sample_angle)
					var y: float = _cap_underside_height(fraction,radius)+_cap_wave(sample_angle,fraction,radius)-depth*cross_depths[k]
					row.append(Vector3(sin(sample_angle)*r,y,cos(sample_angle)*r))
				rows.append(row)
			for j: int in range(rows.size()):
				var ns: PackedVector3Array = PackedVector3Array()
				for k: int in range(5):
					var across: Vector3 = rows[j][mini(k+1,4)]-rows[j][maxi(k-1,0)]
					var along: Vector3 = rows[mini(j+1,rows.size()-1)][k]-rows[maxi(j-1,0)][k]
					ns.append(across.cross(along).normalized())
				row_normals.append(ns)
			var shade: float = 0.94+sin(theta*9.0+float(family))*0.045
			var color_value: Color = Color(shade,shade,shade)
			var ridge_uvs: Array[float] = [0.0,0.66,1.0,0.66,0.0]
			for j: int in range(sections):
				var ta: float = float(j)/float(sections)
				var tb: float = float(j+1)/float(sections)
				for k: int in range(4):
					_smooth_quad(vertices,normals,uvs,colors,rows[j][k],rows[j][k+1],rows[j+1][k+1],rows[j+1][k],row_normals[j][k],row_normals[j][k+1],row_normals[j+1][k+1],row_normals[j+1][k],color_value,Vector2(ridge_uvs[k],ta),Vector2(ridge_uvs[k+1],ta),Vector2(ridge_uvs[k+1],tb),Vector2(ridge_uvs[k],tb))
			for k: int in range(1,4):
				_triangle(vertices,normals,uvs,colors,rows[0][0],rows[0][k+1],rows[0][k],color_value,Vector2(ridge_uvs[0],0),Vector2(ridge_uvs[k+1],0),Vector2(ridge_uvs[k],0))
				_triangle(vertices,normals,uvs,colors,rows[sections][0],rows[sections][k],rows[sections][k+1],color_value,Vector2(ridge_uvs[0],1),Vector2(ridge_uvs[k],1),Vector2(ridge_uvs[k+1],1))
	return _array_mesh(vertices,normals,uvs,colors)

func _cap_neck_mesh(radius: float) -> ArrayMesh:
	# Visual-only flared collar above max5.695m front-window trim; no shell/collider edit.
	var profile: Array[Vector2] = [Vector2(radius*0.468,-0.760),Vector2(radius*0.480,-0.720),Vector2(radius*0.505,-0.690),Vector2(radius*0.540,-0.650),Vector2(radius*0.575,_cap_underside_height(0.575,radius)),Vector2(radius*0.600,_cap_underside_height(0.600,radius))]
	return _cap_surface_mesh(profile,radius,false)

func _cap_main_tissue_height(fraction: float, radius: float) -> float:
	# A curved physical underside, not a different ridge frequency/emission.
	# Zero value and derivative at the protected root/lip parameters.
	var t: float = clampf((fraction-0.450)/0.522,0.0,1.0)
	return _cap_underside_height(fraction,radius)+radius*0.054*pow(sin(t*PI),2.0)

func _cap_main_pleat_profile(fraction: float, radius: float, theta: float) -> Vector2:
	# The actual reshaped wall supplies the hidden35mm root inset. The neck
	# turns continuously into the same curved tissue used by all lamellae.
	var neck_start: float = 0.450
	var neck_finish: float = 0.625
	var radial_scale: float = _cap_radial_scale(theta)
	if fraction >= neck_finish:
		return Vector2(radius*fraction*radial_scale,_cap_main_tissue_height(fraction,radius))
	var t: float = clampf((fraction-neck_start)/(neck_finish-neck_start),0.0,1.0)
	var u: float = 1.0-t
	var start_height: float = -radius*(0.740/5.25)
	var retained_stem: Vector3 = _main_stem_point(theta,6.50+start_height+_cap_wave(theta,neck_start,radius),3.0,6.30)
	var stem_radius: float = Vector2(retained_stem.x,retained_stem.z).length()
	var start: Vector2 = Vector2(stem_radius-0.035,start_height)
	var control_a: Vector2 = start+Vector2(0.0,0.130)
	var finish: Vector2 = Vector2(radius*neck_finish*radial_scale,_cap_main_tissue_height(neck_finish,radius))
	var finish_t: float = (neck_finish-0.355)/0.617
	var finish_slope: float = radius*(0.200*(1.0-finish_t)-0.015*PI*cos(finish_t*PI))/0.617
	var tissue_t: float = (neck_finish-neck_start)/0.522
	finish_slope += radius*0.054*PI/0.522*sin(tissue_t*TAU)
	var span: float = neck_finish-neck_start
	var control_b: Vector2 = finish-Vector2(radius*radial_scale,finish_slope)*span/3.0
	return start*u*u*u+control_a*3.0*u*u*t+control_b*3.0*u*t*t+finish*t*t*t

func _cap_main_pleat_fields(fraction: float, radius: float, theta: float) -> Vector2:
	# Return (downward tissue relief in metres, crest mask for existing UV shading).
	# Sixty primary folds curve continuously through the flared neck. A shallower
	# interrupted tier grows out of the same tissue; no ribbons or root end caps.
	var t: float = clampf((fraction-0.450)/0.522,0.0,1.0)
	var bend: float = (sin(theta*3.0)*0.017+sin(theta*7.0)*0.006)*sin(t*PI)
	var phase: float = (theta+bend)*60.0+sin(theta*5.0)*0.42+sin(theta*11.0)*0.16
	var primary: float = pow(maxf(0.0,0.5+0.5*cos(phase)),2.2)
	var primary_strength: float = 0.85+sin(theta*4.0)*0.10+sin(theta*11.0)*0.05
	var branch_begin: float = 0.585+sin(theta*5.0)*0.030+sin(theta*13.0)*0.014
	var branch_gate: float = smoothstep(branch_begin,branch_begin+0.105,fraction)
	var branch_weight: float = 0.18+0.82*smoothstep(-0.40,0.60,sin(theta*11.0)+sin(theta*5.0)*0.30)
	var branch_phase: float = phase+PI+sin(theta*7.0)*0.40*sin(t*PI)
	var secondary: float = pow(maxf(0.0,0.5+0.5*cos(branch_phase)),2.2)
	var crest: float = primary*primary_strength+secondary*0.34*branch_gate*branch_weight
	var root_gate: float = smoothstep(0.450,0.600,fraction)
	var lip_gate: float = 1.0-smoothstep(0.915,0.972,fraction)
	var envelope: float = radius*0.041*(0.65+sin(t*PI)*0.35)*(1.0-0.56*t)*root_gate*lip_gate
	return Vector2(envelope*crest,clampf(crest,0.0,1.0))

func _cap_main_pleat_point(fraction: float, radius: float, theta: float) -> Vector3:
	var section: Vector2 = _cap_main_pleat_profile(fraction,radius,theta)
	var before_fraction: float = maxf(0.450,fraction-0.0002)
	var after_fraction: float = minf(0.972,fraction+0.0002)
	var before: Vector2 = _cap_main_pleat_profile(before_fraction,radius,theta)
	var after: Vector2 = _cap_main_pleat_profile(after_fraction,radius,theta)
	before.y += _cap_wave(theta,before_fraction,radius)
	after.y += _cap_wave(theta,after_fraction,radius)
	var tangent: Vector2 = after-before
	var tissue_normal: Vector2 = Vector2(tangent.y,-tangent.x).normalized()
	var relief: Vector2 = _cap_main_pleat_fields(fraction,radius,theta)
	# Relief turns from outward neck fluting into downward umbrella pleats.
	var radial_distance: float = section.x+relief.x*tissue_normal.x
	var y: float = section.y+_cap_wave(theta,fraction,radius)+relief.x*tissue_normal.y
	return Vector3(sin(theta)*radial_distance,y,cos(theta)*radial_distance)

func _cap_main_lamella_sector_frame(sector: int) -> Vector2:
	# Deterministic positive spans: unequal spacing without crossing or new RNG.
	var total: float = 0.0
	var before: float = 0.0
	var selected: float = 0.0
	for index: int in range(72):
		var index_value: float = float(index)
		var width: float = 1.0+0.20*sin(index_value*2.399963+0.43)+0.15*sin(index_value*0.731+1.80)
		if index < sector:
			before += width
		if index == sector:
			selected = width
		total += width
	return Vector2(TAU*before/total,TAU*selected/total)

func _cap_main_lamella_bend(theta: float, fraction: float) -> Vector2:
	# A shared smooth angular warp gives long folds a visibly curved course.
	# Positive derivative keeps their order; zero at root/lip and the seam.
	var t: float = clampf((fraction-0.450)/0.522,0.0,1.0)
	var curve: float = sin(t*PI)*(0.75+0.25*cos(t*PI))
	var angle: float = theta+curve*(0.062*sin(theta*3.0)+0.032*sin(theta*5.0))
	var derivative: float = 1.0+curve*(0.186*cos(theta*3.0)+0.160*cos(theta*5.0))
	return Vector2(angle,derivative)

func _cap_main_lamella_cross_height(distance: float, tip_half_width: float, base_half_width: float) -> float:
	var d: float = absf(distance)
	if d >= base_half_width:
		return 0.0
	if d <= tip_half_width:
		var edge_t: float = d/tip_half_width
		return 1.0-0.03*edge_t*edge_t
	# Curved flesh shoulder, then a slender edge; sampled shoulder knots below
	# resolve this section rather than connecting a flat interval to one V tip.
	var flank: float = (base_half_width-d)/(base_half_width-tip_half_width)
	return 0.97*(0.55*flank+0.45*flank*flank)

func _cap_main_lamella_controls(sector: int, fraction: float, radius: float) -> PackedVector3Array:
	# Ten ordered knots per unequal sector, one continuous tissue surface.
	# Primary shoulder/edge and a short interleaved fold both have physical
	# widths; the shorter fold grows out of the same primary shoulder.
	var frame: Vector2 = _cap_main_lamella_sector_frame(sector)
	var index_value: float = float(sector)
	var t: float = clampf((fraction-0.450)/0.522,0.0,1.0)
	var center: float = 0.300+sin(index_value*2.399963+0.37)*0.030
	center += sin(index_value*1.13+0.30)*sin(t*PI)*0.120+sin(index_value*0.41+1.20)*sin(t*TAU)*0.030
	var bend_center: Vector2 = _cap_main_lamella_bend(frame.x+frame.y*center,fraction)
	var arc_metric: float = maxf(frame.y*radius*fraction*bend_center.y,0.0001)
	var flesh_half_width: float = lerpf(0.035,0.023,t)*(0.82+0.36*(0.5+0.5*sin(index_value*1.67+1.10)))
	var edge_half_width: float = lerpf(0.0065,0.0028,t)*(0.85+0.30*(0.5+0.5*sin(index_value*0.91+0.60)))
	var base_width: float = clampf(flesh_half_width/arc_metric,0.040,0.100)
	var tip_width: float = minf(base_width*0.34,clampf(edge_half_width/arc_metric,0.004,0.030))
	var shoulder_width: float = base_width*0.53
	var primary_strength: float = 0.68+(0.5+0.5*sin(index_value*1.37+0.20))*0.30
	var branch_start: float = 0.548+(0.5+0.5*sin(index_value*1.91+0.50))*0.148
	var branch_gate: float = smoothstep(branch_start,branch_start+0.100,fraction)
	var shoulder_span: float = base_width-shoulder_width
	var branch_goal: float = 0.730+sin(index_value*0.87+0.40)*0.045+sin(index_value*0.63+0.20)*sin(t*PI)*0.035
	var branch_center: float = lerpf(center+shoulder_width+shoulder_span*0.56,branch_goal,branch_gate)
	var branch_tip_goal: float = clampf(lerpf(0.0046,0.0026,t)/arc_metric,0.006,0.024)
	var branch_base_goal: float = clampf(lerpf(0.021,0.015,t)*(0.85+0.30*(0.5+0.5*sin(index_value*1.57+0.20)))/arc_metric,0.025,0.070)
	var branch_tip: float = lerpf(shoulder_span*0.10,branch_tip_goal,branch_gate)
	var branch_base: float = lerpf(shoulder_span*0.42,branch_base_goal,branch_gate)
	var trough: float = lerpf(center+shoulder_width+shoulder_span*0.18,branch_center-branch_base,branch_gate)
	var offsets: PackedFloat64Array = PackedFloat64Array([0.0,center-base_width,center-shoulder_width,center-tip_width,center+tip_width,center+shoulder_width,trough,branch_center-branch_tip,branch_center+branch_tip,branch_center+branch_base])
	var primary_finish: float = 0.963+sin(index_value*0.83+0.40)*0.006
	var primary_lip_gate: float = 1.0-smoothstep(primary_finish-0.045,primary_finish,fraction)
	var branch_finish: float = 0.942+sin(index_value*1.07+1.30)*0.020
	var branch_lip_gate: float = 1.0-smoothstep(branch_finish-0.045,branch_finish,fraction)
	var branch_strength: float = 0.48+(0.5+0.5*sin(index_value*1.90+0.60))*0.28
	var root_gate: float = smoothstep(0.450,0.600,fraction)
	var envelope: float = radius*0.043*(0.65+sin(t*PI)*0.35)*(1.0-0.56*t)*root_gate*primary_strength
	var result: PackedVector3Array = PackedVector3Array()
	for offset: float in offsets:
		var primary: float = _cap_main_lamella_cross_height(offset-center,tip_width,base_width)*primary_lip_gate
		var branch: float = _cap_main_lamella_cross_height(offset-branch_center,branch_tip,branch_base)*branch_gate*branch_strength*branch_lip_gate
		var crest: float = primary+branch-primary*branch
		# Shallow soft tissue between unequal blades: no broad planar interval.
		# It vanishes with the root/lip envelope and carries no extra emission.
		var interval_fold: float = 0.18*pow(sin(offset*PI),2.0)*(1.0-crest)*primary_lip_gate
		var bent: Vector2 = _cap_main_lamella_bend(frame.x+frame.y*offset,fraction)
		result.append(Vector3(bent.x,envelope*(crest+interval_fold),clampf(crest,0.0,1.0)))
	return result

func _cap_main_lamella_position(fraction: float, radius: float, theta: float, relief: float) -> Vector3:
	# Use the selected05 neck/profile unchanged; only the corrugation section changes.
	var section: Vector2 = _cap_main_pleat_profile(fraction,radius,theta)
	var before_fraction: float = maxf(0.450,fraction-0.0002)
	var after_fraction: float = minf(0.972,fraction+0.0002)
	var before: Vector2 = _cap_main_pleat_profile(before_fraction,radius,theta)
	var after: Vector2 = _cap_main_pleat_profile(after_fraction,radius,theta)
	before.y += _cap_wave(theta,before_fraction,radius)
	after.y += _cap_wave(theta,after_fraction,radius)
	var tangent: Vector2 = after-before
	var tissue_normal: Vector2 = Vector2(tangent.y,-tangent.x).normalized()
	var radial_distance: float = section.x+relief*tissue_normal.x
	var y: float = section.y+_cap_wave(theta,fraction,radius)+relief*tissue_normal.y
	return Vector3(sin(theta)*radial_distance,y,cos(theta)*radial_distance)

func _cap_main_lamella_soft_normal(rings: Array[PackedVector3Array], row: int, index: int) -> Vector3:
	var angular_sections: int = 720
	var wrapped: int = posmod(index,angular_sections)
	var previous: int = posmod(wrapped-1,angular_sections)
	var following: int = (wrapped+1)%angular_sections
	var along: Vector3 = rings[mini(row+1,31)][wrapped]-rings[maxi(row-1,0)][wrapped]
	var left: Vector3 = (rings[row][wrapped]-rings[row][previous]).cross(along).normalized()
	var right: Vector3 = (rings[row][following]-rings[row][wrapped]).cross(along).normalized()
	return (left+right).normalized()

func _cap_main_lamella_front_normal(value: Vector3, face_a: Vector3, face_b: Vector3) -> Vector3:
	# A bent fork may make a nonplanar quad. Keep each corner in the positive
	# front hemisphere of both adjacent CW triangles before material shading.
	if value.dot(face_a) <= 0.025 or value.dot(face_b) <= 0.025:
		return (face_a+face_b).normalized()
	return value

func _cap_main_pleated_underbody_mesh(radius: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var angular_sections: int = 720
	var radial_sections: int = 32
	var lip_sections: int = 192
	var rings: Array[PackedVector3Array] = []
	var ring_uvs: Array[PackedVector2Array] = []
	var ring_angles: Array[PackedFloat64Array] = []
	for j: int in range(radial_sections+1):
		var along: float = float(j)/float(radial_sections)
		var fraction: float = lerpf(0.450,0.972,along)
		var row: PackedVector3Array = PackedVector3Array()
		var uv_row: PackedVector2Array = PackedVector2Array()
		var angles: PackedFloat64Array = PackedFloat64Array()
		if j == radial_sections:
			var lip_profile: Vector2 = Vector2(radius*0.972,_cap_underside_height(0.972,radius))
			for i: int in range(lip_sections):
				var theta: float = TAU*float(i)/float(lip_sections)
				row.append(_cap_surface_point(lip_profile,theta,radius,true))
				uv_row.append(Vector2(0.0,1.0))
				angles.append(theta)
		else:
			for sector: int in range(72):
				var controls: PackedVector3Array = _cap_main_lamella_controls(sector,fraction,radius)
				for control: Vector3 in controls:
					row.append(_cap_main_lamella_position(fraction,radius,control.x,control.y))
					uv_row.append(Vector2(control.z,along))
					angles.append(float(control.x))
		row.append(row[0])
		uv_row.append(uv_row[0])
		angles.append(TAU)
		rings.append(row)
		ring_uvs.append(uv_row)
		ring_angles.append(angles)
	# Smooth tissue/shoulders across sectors while keeping the thin edge faces.
	# Main profile retained; the outer192 boundary is exact, inner720 angles resampled.
	var soft_normals: Array[PackedVector3Array] = []
	for row_index: int in range(radial_sections):
		var normal_row: PackedVector3Array = PackedVector3Array()
		for angular_index: int in range(angular_sections):
			normal_row.append(_cap_main_lamella_soft_normal(rings,row_index,angular_index))
		normal_row.append(normal_row[0])
		soft_normals.append(normal_row)
	for j: int in range(radial_sections-1):
		for i: int in range(angular_sections):
			var across_a: Vector3 = rings[j][i+1]-rings[j][i]
			var across_b: Vector3 = rings[j+1][i+1]-rings[j+1][i]
			var previous_row: int = maxi(j-1,0)
			var next_row: int = mini(j+2,radial_sections-1)
			var na: Vector3 = across_a.cross(rings[j+1][i]-rings[previous_row][i]).normalized()
			var nb: Vector3 = across_a.cross(rings[j+1][i+1]-rings[previous_row][i+1]).normalized()
			var nc: Vector3 = across_b.cross(rings[next_row][i+1]-rings[j][i+1]).normalized()
			var nd: Vector3 = across_b.cross(rings[next_row][i]-rings[j][i]).normalized()
			var blend_a: float = 0.10 if i%10 == 3 or i%10 == 4 else 0.62
			var blend_b: float = 0.10 if (i+1)%10 == 3 or (i+1)%10 == 4 else 0.62
			na = na.lerp(soft_normals[j][i],blend_a).normalized()
			nb = nb.lerp(soft_normals[j][i+1],blend_b).normalized()
			nc = nc.lerp(soft_normals[j+1][i+1],blend_b).normalized()
			nd = nd.lerp(soft_normals[j+1][i],blend_a).normalized()
			var front_a: Vector3 = across_a.cross(rings[j+1][i+1]-rings[j][i]).normalized()
			var front_b: Vector3 = (rings[j+1][i+1]-rings[j][i]).cross(rings[j+1][i]-rings[j][i]).normalized()
			na = _cap_main_lamella_front_normal(na,front_a,front_b)
			nb = _cap_main_lamella_front_normal(nb,front_a,front_a)
			nc = _cap_main_lamella_front_normal(nc,front_a,front_b)
			nd = _cap_main_lamella_front_normal(nd,front_b,front_b)
			_smooth_quad(vertices,normals,uvs,colors,rings[j][i],rings[j][i+1],rings[j+1][i+1],rings[j+1][i],na,nb,nc,nd,Color.WHITE,ring_uvs[j][i],ring_uvs[j][i+1],ring_uvs[j+1][i+1],ring_uvs[j+1][i])
	# Monotone zipper joins720 irregular inner knots to192 exact skin vertices.
	# Each advance emits one CW triangle; counts=N+M, with no T-junctions.
	var inner_row: int = radial_sections-1
	var inner_index: int = 0
	var outer_index: int = 0
	while inner_index < angular_sections or outer_index < lip_sections:
		var a: Vector3 = rings[inner_row][inner_index]
		var ua: Vector2 = ring_uvs[inner_row][inner_index]
		var b: Vector3 = rings[inner_row+1][outer_index]
		var ub: Vector2 = ring_uvs[inner_row+1][outer_index]
		var c: Vector3
		var uc: Vector2
		if inner_index < angular_sections and (outer_index >= lip_sections or ring_angles[inner_row][inner_index+1] <= ring_angles[inner_row+1][outer_index+1]):
			c = rings[inner_row][inner_index+1]
			uc = ring_uvs[inner_row][inner_index+1]
			inner_index += 1
		else:
			c = rings[inner_row+1][outer_index+1]
			uc = ring_uvs[inner_row+1][outer_index+1]
			outer_index += 1
		var face_normal: Vector3 = -(b-a).cross(c-a).normalized()
		vertices.append_array(PackedVector3Array([a,b,c]))
		normals.append_array(PackedVector3Array([face_normal,face_normal,face_normal]))
		uvs.append_array(PackedVector2Array([ua,ub,uc]))
		colors.append_array(PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE]))
	return _array_mesh(vertices,normals,uvs,colors)

func _create_entry(parent: Node3D) -> void:
	var arch_points: Array[Vector3] = [Vector3(-0.91, 0.58, 3.00), Vector3(-0.91, 1.825, 3.00)]
	for i: int in range(25):
		var a: float = PI - PI * float(i) / 24.0
		arch_points.append(Vector3(cos(a) * 0.91, 1.825 + sin(a) * 0.91, 3.00))
	arch_points.append(Vector3(0.91, 0.58, 3.00))
	var cream_arch: MeshInstance3D = _tube(arch_points, 0.12, 0.12, _materials["stone_light"] as Material, parent, 8)
	cream_arch.name = "EntryCreamArchShoulders"
	cream_arch.mesh = _entry_worn_arch_mesh(cream_arch.mesh as ArrayMesh, 3.00, 0.12, false)
	var timber_arch: Array[Vector3] = []
	for p: Vector3 in arch_points:
		timber_arch.append(p + Vector3(0, 0, 0.055))
	var timber_reveal: MeshInstance3D = _tube(timber_arch, 0.057, 0.057, _materials["wood"] as Material, parent, 6)
	timber_reveal.name = "EntryDarkTimberReveal"
	timber_reveal.mesh = _entry_worn_arch_mesh(timber_reveal.mesh as ArrayMesh, 3.055, 0.057, true)
	door_hinge = Node3D.new()
	door_hinge.name = "RightInwardHinge"
	door_hinge.position = Vector3(0.775, 0.60, 3.005)
	parent.add_child(door_hinge)
	var mesh: ArrayMesh = _arch_panel(1.55, 2.0, 0.11, -0.775)
	var leaf: MeshInstance3D = _instance(mesh, _materials["wood_light"] as Material, door_hinge)
	leaf.name = "RoundToppedTimberDoor"
	leaf.mesh = _entry_door_relief_mesh(mesh)
	door_body = StaticBody3D.new()
	door_body.name = "DoorSolid"
	door_body.collision_layer = 4
	door_body.collision_mask = 2
	door_hinge.add_child(door_body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = mesh.create_convex_shape()
	door_body.add_child(shape)
	for plank: int in range(9):
		var x: float = -1.48 + float(plank) * 0.173
		var dx: float = x + 0.775
		var top: float = 1.225 + sqrt(maxf(0.0, 0.775 * 0.775 - dx * dx))
		_box(Vector3(x, top * 0.5, 0.067), Vector3(0.014, top - 0.035, 0.012), _materials["wood"] as Material, door_hinge)
	_ring(Vector3(-0.775, 1.23, 0.090), 0.18, 0.032, _materials["iron"] as Material, door_hinge)
	_ring(Vector3(-0.22, 0.88, 0.12), 0.075, 0.017, _materials["iron"] as Material, door_hinge)
	for y: float in [0.36, 1.25]:
		_box(Vector3(-0.15, y, 0.071), Vector3(0.30, 0.05, 0.02), _materials["iron"] as Material, door_hinge)
		_sphere(Vector3(-0.03, y, 0.095), Vector3(0.035, 0.035, 0.035), _materials["iron"] as Material, door_hinge, 10, 5)

# Source13 entrance-only proposal. These helpers are not used by other arches or doors.
func _entry_arch_depth_point(point: Vector3, center_z: float, radius: float) -> Vector3:
	var path_s: float = 0.0
	if point.y <= 1.825:
		if point.x < 0.0:
			path_s = point.y - 0.58
		else:
			path_s = 1.245 + PI * 0.91 + 1.825 - point.y
	else:
		path_s = 1.245 + 0.91 * (PI - atan2(point.y - 1.825, point.x))
	var offset: float = point.z - center_z
	var front: float = clampf(offset / radius, 0.0, 1.0)
	var joint_wave: float = 0.5 + 0.5 * cos(path_s * TAU / 0.48 + 0.5 * sin(path_s * 2.1))
	var wear: float = (0.004 * sin(path_s * 4.1 + 0.6) - 0.006 * pow(joint_wave, 6.0)) * (radius / 0.12)
	var delta: float = clampf(wear * front * front, -0.008, 0.008)
	return Vector3(point.x, point.y, point.z + delta)

func _entry_arch_depth_normal(point: Vector3, normal: Vector3, center_z: float, radius: float) -> Vector3:
	var epsilon: float = 0.0002
	var dz_dx: float = (_entry_arch_depth_point(point + Vector3(epsilon, 0, 0), center_z, radius).z - _entry_arch_depth_point(point - Vector3(epsilon, 0, 0), center_z, radius).z) / (2.0 * epsilon)
	var dz_dy: float = (_entry_arch_depth_point(point + Vector3(0, epsilon, 0), center_z, radius).z - _entry_arch_depth_point(point - Vector3(0, epsilon, 0), center_z, radius).z) / (2.0 * epsilon)
	var dz_dz: float = (_entry_arch_depth_point(point + Vector3(0, 0, epsilon), center_z, radius).z - _entry_arch_depth_point(point - Vector3(0, 0, epsilon), center_z, radius).z) / (2.0 * epsilon)
	# The positive depth derivative keeps the original front/back orientation.
	return Vector3(normal.x - normal.z * dz_dx / dz_dz, normal.y - normal.z * dz_dy / dz_dz, normal.z / dz_dz).normalized()

func _entry_worn_arch_mesh(source: ArrayMesh, center_z: float, radius: float, timber: bool) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var old_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var old_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var old_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(0, old_vertices.size(), 3):
		var old_a: Vector3 = old_vertices[i]
		var old_b: Vector3 = old_vertices[i + 1]
		var old_c: Vector3 = old_vertices[i + 2]
		if (old_c - old_a).cross(old_b - old_a).length_squared() <= 1.0e-14:
			continue
		for j: int in range(3):
			var p: Vector3 = old_vertices[i + j]
			var q: Vector3 = _entry_arch_depth_point(p, center_z, radius)
			var front: float = clampf((p.z - center_z) / radius, 0.0, 1.0)
			var amount: float = 0.5 + 0.5 * sin(p.y * 5.4 + p.x * 3.1)
			var tint: Color = Color(0.84 + amount * 0.06, 0.77 + amount * 0.07, 0.69 + amount * 0.08) if timber else Color(0.94 + amount * 0.05, 0.91 + amount * 0.06, 0.85 + amount * 0.08)
			vertices.append(q)
			normals.append(_entry_arch_depth_normal(p, old_normals[i + j], center_z, radius))
			uvs.append(old_uvs[i + j])
			colors.append(Color.WHITE.lerp(tint, front))
	return _array_mesh(vertices, normals, uvs, colors)

func _entry_door_chord_top(x: float) -> float:
	# Match the actual 24 straight edges of the preserved panel, not an ideal circle.
	for i: int in range(24):
		var a: float = PI - PI * float(i) / 24.0
		var b: float = PI - PI * float(i + 1) / 24.0
		var xa: float = -0.775 + cos(a) * 0.775
		var xb: float = -0.775 + cos(b) * 0.775
		if x <= xb or i == 23:
			var ya: float = 1.225 + sin(a) * 0.775
			var yb: float = 1.225 + sin(b) * 0.775
			return lerpf(ya, yb, clampf((x - xa) / (xb - xa), 0.0, 1.0))
	return 1.225

func _entry_stave_point(board: int, left: float, right: float, u: float, v: float) -> Vector3:
	var x: float = lerpf(left, right, u)
	var bottom: float = 0.028 + 0.006 * (0.5 + 0.5 * sin(float(board) * 1.7))
	var top: float = _entry_door_chord_top(x) - 0.018
	var y: float = lerpf(bottom, top, v)
	var bevel: float = smoothstep(0.0, 0.20, u) * smoothstep(0.0, 0.20, 1.0 - u) * smoothstep(0.0, 0.13, v) * smoothstep(0.0, 0.13, 1.0 - v)
	var depth: float = 0.0105 + 0.0012 * sin(float(board) * 1.91 + 0.2)
	var shoulder: float = 0.86 + 0.10 * sin(y * 3.1 + float(board) * 0.8) + 0.04 * cos(u * 8.4 + float(board))
	return Vector3(x, y, 0.057 + depth * bevel * shoulder)

func _entry_stave_normal(board: int, left: float, right: float, u: float, v: float) -> Vector3:
	var epsilon: float = 0.001
	var across: Vector3 = _entry_stave_point(board, left, right, minf(1.0, u + epsilon), v) - _entry_stave_point(board, left, right, maxf(0.0, u - epsilon), v)
	var along: Vector3 = _entry_stave_point(board, left, right, u, minf(1.0, v + epsilon)) - _entry_stave_point(board, left, right, u, maxf(0.0, v - epsilon))
	return across.cross(along).normalized()

func _entry_door_relief_mesh(source: ArrayMesh) -> ArrayMesh:
	# Preserve the original encoded core surface; DoorSolid still uses source.
	var result: ArrayMesh = source.duplicate() as ArrayMesh
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var boundaries: PackedFloat64Array = PackedFloat64Array([-1.55])
	for i: int in range(9):
		boundaries.append(-1.48 + float(i) * 0.173)
	boundaries.append(0.0)
	for board: int in range(10):
		var left: float = boundaries[board] + (0.012 if board == 0 else 0.008)
		var right: float = boundaries[board + 1] - (0.012 if board == 9 else 0.008)
		var tone: float = 0.72 + 0.06 * sin(float(board) * 1.7 + 0.3)
		var color_value: Color = Color(tone, tone * 0.92, tone * 0.84, 1.0)
		for i: int in range(6):
			for j: int in range(8):
				var u0: float = float(i) / 6.0
				var u1: float = float(i + 1) / 6.0
				var v0: float = float(j) / 8.0
				var v1: float = float(j + 1) / 8.0
				var a: Vector3 = _entry_stave_point(board, left, right, u0, v0)
				var b: Vector3 = _entry_stave_point(board, left, right, u1, v0)
				var c: Vector3 = _entry_stave_point(board, left, right, u1, v1)
				var d: Vector3 = _entry_stave_point(board, left, right, u0, v1)
				_smooth_quad(vertices, normals, uvs, colors, a, b, c, d, _entry_stave_normal(board, left, right, u0, v0), _entry_stave_normal(board, left, right, u1, v0), _entry_stave_normal(board, left, right, u1, v1), _entry_stave_normal(board, left, right, u0, v1), color_value, Vector2(a.x + 1.55, a.y), Vector2(b.x + 1.55, b.y), Vector2(c.x + 1.55, c.y), Vector2(d.x + 1.55, d.y))
	var relief: ArrayMesh = _array_mesh(vertices, normals, uvs, colors)
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, relief.surface_get_arrays(0))
	return result

func _create_stairs(parent: Node3D) -> void:
	for index: int in range(4):
		var top: float = 0.60 - float(index) * 0.15
		var z: float = 3.4 + float(index) * 0.60
		_box(Vector3(0, top * 0.5, z), Vector3(2.06 + float(index) * 0.09, top, 0.62), _materials["stone_light"] as Material, parent)
		for detail: int in range(5):
			var x: float = -0.85 + float(detail) * 0.43
			_rock(Vector3(x, top + 0.005, z + 0.11), Vector3(0.23, 0.035, 0.28), parent, false, true)
			if detail % 2 == 0:
				_sphere(Vector3(x, top + 0.016, z + 0.33), Vector3(0.19, 0.026, 0.10), _materials["moss"] as Material, parent, 12, 6)
	var vertices: PackedVector3Array = PackedVector3Array([Vector3(-1.08, 0.60, 3.10), Vector3(-1.08, 0.0, 5.70), Vector3(1.08, 0.0, 5.70), Vector3(1.08, 0.60, 3.10)])
	var ramp_mesh: ArrayMesh = _simple_quad(vertices)
	_mesh_collision(ramp_mesh, parent)

func _create_balcony(parent: Node3D) -> void:
	var y: float = 3.25
	var begin: float = -0.72
	var finish: float = 1.44
	for i: int in range(36):
		var a: float = lerpf(begin, finish, float(i) / 36.0)
		var b: float = lerpf(begin, finish, float(i + 1) / 36.0)
		var vertices: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		var colors: PackedColorArray = PackedColorArray()
		var pa: Vector3 = Vector3(sin(a) * 2.68, y, cos(a) * 2.68)
		var pb: Vector3 = Vector3(sin(b) * 2.68, y, cos(b) * 2.68)
		var pc: Vector3 = Vector3(sin(b) * 4.25, y, cos(b) * 4.25)
		var pd: Vector3 = Vector3(sin(a) * 4.25, y, cos(a) * 4.25)
		_quad(vertices, normals, uvs, colors, pa, pb, pc, pd, Color.WHITE)
		_quad(vertices, normals, uvs, colors, pd, pc, pc - Vector3(0, 0.16, 0), pd - Vector3(0, 0.16, 0), Color.WHITE)
		_instance(_array_mesh(vertices, normals, uvs, colors), _materials["wood_light"] as Material, parent)
	var rail_top: Array[Vector3] = []
	var rail_low: Array[Vector3] = []
	var fascia: Array[Vector3] = []
	for i: int in range(44):
		var a: float = lerpf(begin, finish, float(i) / 43.0)
		rail_top.append(Vector3(sin(a) * 4.20, y + 0.74 + sin(float(i)*0.31)*0.045, cos(a) * 4.20))
		rail_low.append(Vector3(sin(a) * 4.20, y + 0.33 - sin(float(i) * 0.62) * 0.035, cos(a) * 4.20))
		fascia.append(Vector3(sin(a) * 4.21, y - 0.15, cos(a) * 4.21))
	_tube(rail_top, 0.080, 0.062, _materials["wood"] as Material, parent, 7)
	_tube(rail_low, 0.035, 0.035, _materials["wood_light"] as Material, parent, 6)
	_tube(fascia, 0.15, 0.15, _materials["wood"] as Material, parent, 8)
	for i: int in range(9):
		var a: float = lerpf(begin, finish, float(i) / 8.0) + sin(float(i)*1.3)*0.014
		var p: Vector3 = Vector3(sin(a) * 4.21, y, cos(a) * 4.21)
		_tube([p - Vector3(0, 0.17, 0), p + Vector3(-0.035*sin(float(i)),0.40,0.03), p + Vector3(0.03, 0.89, -0.02)], 0.11, 0.070, _materials["wood"] as Material, parent, 8)
		_sphere(p + Vector3(0.03, 0.89, -0.02), Vector3(0.12, 0.10, 0.12), _materials["wood_light"] as Material, parent, 12, 6)
		var support: Vector3 = Vector3(sin(a) * 2.9, y - 1.03, cos(a) * 2.9)
		_tube([support, support.lerp(p, 0.52) + Vector3(0.08, 0.07, 0.04), p - Vector3(0, 0.22, 0)], 0.12, 0.09, _materials["wood"] as Material, parent, 8)
		if i % 2 == 0:
			_pot(p * Vector3(0.83, 1, 0.83) + Vector3(0, 0.02, 0), 0.19, parent)
			_flower_bouquet(p * Vector3(0.83, 1, 0.83) + Vector3(0, 0.30, 0), parent, 7, 0.55)
	for index: int in range(7):
		var a: float = 0.1 + float(index) * 0.17
		var r: float = 4.28
		var points: Array[Vector3] = []
		for j: int in range(9):
			var phase: float = float(j)*0.63 + float(index)*1.37
			var angle: float = a + sin(phase)*0.047
			var radius: float = r + sin(phase*0.72)*0.10
			var drop: float = float(j)*(.19 + float(index%3)*.025)
			points.append(Vector3(sin(angle)*radius, 3.36-drop, cos(angle)*radius))
		_vine(points, parent, index % 2 == 0)
	# Three curved flowering swags sit behind the front rail, leaving the door clear.
	var scenery_rng_state: int = _rng.state
	for index: int in range(3):
		var points: Array[Vector3] = []
		for j: int in range(13):
			var t: float = float(j)/12.0
			var angle: float = -.58+float(index)*.56+t*.57
			points.append(Vector3(sin(angle)*4.27,3.80-sin(t*PI)*.32,cos(angle)*4.27))
		_vine(points,parent,true)
	_rng.state = scenery_rng_state

func _create_annex(parent: Node3D) -> void:
	var annex: Node3D = Node3D.new()
	annex.name = "OpenLeftAnnex"
	annex.position = Vector3(-4.10, 0, -0.40)
	parent.add_child(annex)
	_floor(Vector3(0, 0.48, 0), 1.83, 0.24, annex)
	_shell(1.84, 3.10, annex, false, false)
	_cap(Vector3(0, 3.10, 0), 2.42, 0.98, annex)
	_window(Vector3(0, 1.80, 1.82), 0.35, 0.60, 0.0, annex)
	_lantern(Vector3(-0.65, 2.03, 1.64), 0.21, annex, true)
	_box(Vector3(-0.85, 1.03, -0.60), Vector3(0.54, 0.86, 1.24), _materials["wood_light"] as Material, annex)
	_box(Vector3(-0.85, 1.51, -0.60), Vector3(0.69, 0.09, 1.39), _materials["stone_light"] as Material, annex)
	_pot(Vector3(-0.85, 1.57, -0.86), 0.14, annex)
	# This floor reaches both wall holes; side lintels do not block the actual arch.
	_box(Vector3(-2.67, 0.47, -0.40), Vector3(1.1, 0.26, 1.65), _materials["floor"] as Material, parent, true)
	_arch_trim(Vector3(-2.87, 0.60, -0.40), PI * 0.5, 1.64, 2.04, parent)
	_practical_light(Vector3(0, 2.20, 0), 3.0, annex)

func _create_right_room(parent: Node3D) -> void:
	wall_plug = Node3D.new()
	wall_plug.name = "GrowthWallPlug"
	wall_plug.position = Vector3(2.88, 0.60, 0.60)
	wall_plug.rotation.y = PI * 0.5
	parent.add_child(wall_plug)
	var plug_mesh: ArrayMesh = _arch_panel(1.55, 2.05, 0.20, 0.0)
	_instance(plug_mesh, _materials["plaster"] as Material, wall_plug)
	var plug_shape: CollisionShape3D = _mesh_collision(plug_mesh, wall_plug)
	_plug_colliders.append(plug_shape)
	_arch_trim(Vector3(2.88, 0.60, 0.60), PI * 0.5, 1.58, 2.05, parent)
	right_room = Node3D.new()
	right_room.name = "GrowableRightRoom"
	right_room.position = Vector3(4.95, 0, 0.60)
	parent.add_child(right_room)
	_floor(Vector3(0, 0.48, 0), 1.70, 0.24, right_room, true)
	_shell(1.70, 3.15, right_room, false, true)
	_cap(Vector3(0, 3.15, 0), 2.10, 0.99, right_room)
	_window(Vector3(0, 1.87, 1.68), 0.33, 0.49, 0.0, right_room)
	_box(Vector3(-1.62, 0.47, 0), Vector3(1.88, 0.26, 1.42), _materials["floor"] as Material, right_room, true, true)
	# Solid neck sides and a lintel make the room attachment read as an actual structure.
	_box(Vector3(-1.88, 1.40, -0.86), Vector3(1.50, 1.60, 0.23), _materials["plaster"] as Material, right_room, true, true)
	_box(Vector3(-1.88, 1.40, 0.86), Vector3(1.50, 1.60, 0.23), _materials["plaster"] as Material, right_room, true, true)
	_box(Vector3(-1.88, 2.62, 0), Vector3(1.50, 0.62, 1.95), _materials["plaster"] as Material, right_room, true, true)
	_lantern(Vector3(0.65, 2.0, 1.62), 0.22, right_room, true)
	_practical_light(Vector3(0, 2.12, 0), 3.5, right_room)
	set_room_ready(false)

func _create_chimney(parent: Node3D) -> void:
	var chimney: Node3D = Node3D.new()
	chimney.name = "MushroomLanternChimney"
	chimney.position = Vector3(-0.50, 8.73, -0.55)
	chimney.scale = Vector3(1.08,1.18,1.08)
	parent.add_child(chimney)
	# The visible cream shaft rises above the peach crown before its lantern collar.
	var shaft_profile: Array[Vector2] = [Vector2(0.34, 0.0), Vector2(0.35, 0.07), Vector2(0.29, 0.16), Vector2(0.255, 0.35), Vector2(0.235, 0.65), Vector2(0.255, 0.91), Vector2(0.29, 1.03), Vector2(0.33, 1.07)]
	var shaft: MeshInstance3D = _lathe(shaft_profile, 48, _materials["stone_light"] as Material, chimney, 0.020)
	shaft.name = "CreamChimneyShaft"
	var collar: MeshInstance3D = _lathe([Vector2(0.32, 1.025), Vector2(0.35, 1.05), Vector2(0.35, 1.11), Vector2(0.30, 1.14)], 48, _materials["wood"] as Material, chimney)
	collar.name = "LanternCollar"
	var roof_profile: Array[Vector2] = [Vector2(0.0, 1.78), Vector2(0.13, 1.78), Vector2(0.32, 1.71), Vector2(0.46, 1.62), Vector2(0.54, 1.53), Vector2(0.565, 1.47), Vector2(0.55, 1.41), Vector2(0.50, 1.39)]
	var roof: MeshInstance3D = _lathe(roof_profile, 64, _materials["wood_light"] as Material, chimney, 0.012)
	roof.name = "SmallUmbrellaLanternHood"
	for i: int in range(6):
		var angle: float = float(i) * TAU / 6.0
		var posts: Array[Vector3] = [Vector3(sin(angle) * 0.27, 1.10, cos(angle) * 0.27), Vector3(sin(angle) * 0.32, 1.43, cos(angle) * 0.32)]
		_tube(posts, 0.026, 0.025, _materials["wood"] as Material, chimney, 6)
	var core: MeshInstance3D = _sphere(Vector3(0, 1.285, 0), Vector3(0.16, 0.14, 0.16), _materials["glow"] as Material, chimney, 16, 8)
	core.name = "WarmLanternCore"
	var finial: MeshInstance3D = _lathe([Vector2(0.07, 1.76), Vector2(0.08, 1.81), Vector2(0.06, 1.86), Vector2(0.045, 1.94), Vector2(0.0, 1.97)], 24, _materials["stone_light"] as Material, chimney)
	finial.name = "SoftChimneyFinial"

func _create_bridge() -> void:
	var bridge: Node3D = Node3D.new()
	bridge.name = "ArchedTimberBridge"
	add_child(bridge)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(24):
		var xa: float = 6.7 + 4.6 * float(i) / 24.0
		var xb: float = 6.7 + 4.6 * float(i + 1) / 24.0
		var ya: float = _bridge_height(xa)
		var yb: float = _bridge_height(xb)
		_quad(vertices, normals, uvs, colors, Vector3(xa, ya, 6.57), Vector3(xa, ya, 8.43), Vector3(xb, yb, 8.43), Vector3(xb, yb, 6.57), Color.WHITE)
		var plank: MeshInstance3D = _box(Vector3((xa + xb) * 0.5, (ya + yb) * 0.5 - 0.064, 7.5), Vector3(0.178, 0.13, 1.96), _materials["wood_light"] as Material, bridge)
		plank.rotation.z = atan2(yb - ya, xb - xa)
		for z: float in [6.68, 8.32]:
			_sphere(Vector3((xa + xb) * 0.5, (ya + yb) * 0.5 + 0.007, z), Vector3(0.014, 0.008, 0.014), _materials["iron"] as Material, bridge, 6, 4)
	_mesh_collision(_array_mesh(vertices, normals, uvs, colors), bridge)
	for z: float in [6.45, 8.55]:
		var lower: Array[Vector3] = []
		var upper: Array[Vector3] = []
		for i: int in range(33):
			var x: float = 6.60 + 4.80 * float(i) / 32.0
			var y: float = _bridge_height(clampf(x, 6.7, 11.3))
			lower.append(Vector3(x, y - 0.16, z))
			upper.append(Vector3(x, y + 0.77 - absf(sin(float(i) * PI / 8.0)) * 0.045, z))
		_tube(lower, 0.14, 0.14, _materials["wood"] as Material, bridge, 8)
		_tube(upper, 0.055, 0.055, _materials["wood_light"] as Material, bridge, 7)
		var rope: Array[Vector3] = []
		for i: int in range(33):
			var x: float = 6.60 + 4.80 * float(i) / 32.0
			rope.append(Vector3(x, _bridge_height(clampf(x, 6.7, 11.3)) + 0.45 - absf(sin(float(i) * PI / 8.0)) * 0.07, z))
		_tube(rope, 0.025, 0.025, _materials["wood_light"] as Material, bridge, 6)
		for i: int in range(5):
			var x: float = 6.7 + float(i) * 1.15
			var y: float = _bridge_height(x)
			var post_points: Array[Vector3] = [Vector3(x, y - 0.30, z), Vector3(x + _rng.randf_range(-0.05, 0.05), y + 0.99, z)]
			_tube(post_points, 0.15, 0.10, _materials["wood"] as Material, bridge, 8)
			_sphere(Vector3(x, y + 0.99, z), Vector3(0.14, 0.08, 0.14), _materials["wood_light"] as Material, bridge, 10, 5)
			_box(Vector3(x, y + 0.50, z), Vector3(0.22, 1.30, 0.22), null, bridge, true)
		for i: int in range(16):
			var xa: float = 6.70 + float(i) * 4.6 / 16.0
			var xb: float = 6.70 + float(i + 1) * 4.6 / 16.0
			_box(Vector3((xa + xb) * 0.5, (_bridge_height(xa) + _bridge_height(xb)) * 0.5 + 0.55, z), Vector3(xb - xa + 0.02, 0.48, 0.15), null, bridge, true)
	# A distant stone ford completes the specified loop where it returns across the stream.
	var ford: MeshInstance3D = _box(Vector3(9, -0.025, -7.65), Vector3(2.62, 0.10, 1.90), _materials["stone"] as Material, bridge, true)
	ford.name = "MossyLoopFord"
	for i: int in range(5):
		_rock(Vector3(7.93 + float(i) * 0.53, 0.04, -7.65), Vector3(0.38, 0.06, 0.96), bridge, false, true)
	_lantern(Vector3(6.62, 1.20, 6.45), 0.20, bridge, true)
	_lantern(Vector3(11.39, 1.20, 8.55), 0.20, bridge, true)

func _bridge_height(x: float) -> float:
	return sin(clampf((x - 6.7) / 4.6, 0.0, 1.0) * PI) * 0.35

func _create_stream() -> void:
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://assets/world/water.gdshader") as Shader
	_fall_material = ShaderMaterial.new()
	_fall_material.shader = load("res://assets/world/waterfall.gdshader") as Shader
	var stream: Node3D = Node3D.new()
	stream.name = "UnbrokenStream"
	add_child(stream)
	var river: PlaneMesh = PlaneMesh.new()
	river.size = Vector2(2.38, 50)
	river.subdivide_width = 5
	river.subdivide_depth = 160
	var water: MeshInstance3D = _instance(river, _water_material, stream)
	water.position = Vector3(9, -0.16, 1)
	for i: int in range(8):
		var z: float = -21.0 + float(i) * 0.31
		var foam: Array[Vector3] = []
		for j: int in range(7):
			foam.append(Vector3(8.08 + float(j) * 0.30, -0.125 + sin(float(j)) * 0.008, z + sin(float(j) * 0.9) * 0.08))
		_tube(foam, 0.008, 0.008, _materials["flower_white"] as Material, stream, 4)
	# Authored shelves and two-stage flow replace only the existing scenic backdrop.
	_create_waterfall_shelves_and_cascade(stream)
	# A few floating broad lily leaves provide fine-scale foreground water detail.
	for i: int in range(20):
		var leaf: MeshInstance3D = _instance(_make_lily_mesh(), _materials["leaf_gold"] as Material, stream)
		leaf.position = Vector3(_rng.randf_range(8.20, 9.90), -0.11, _rng.randf_range(9, 24))
		leaf.rotation.y = _rng.randf_range(0, TAU)


func _create_waterfall_shelves_and_cascade(parent: Node3D) -> void:
	# Preserve exactly the old11_rock sequence: pos3,size3,seed1,rotation1 per rock.
	for _legacy_index: int in range(11):
		_rng.randf_range(-5.0, 5.0)
		_rng.randf_range(-1.0, 1.0)
		_rng.randf_range(-1.5, 1.4)
		_rng.randf_range(1.6, 2.8)
		_rng.randf_range(2.1, 4.1)
		_rng.randf_range(1.4, 2.5)
		_rng.randf_range(0.0, 8.0)
		_rng.randf_range(0.0, TAU)
	var shelves: Array[Dictionary] = [
		{"id":"LeftFoundation", "center":Vector3(5.8,0.55,-22.1), "size":Vector3(4.5,2.0,3.0), "yaw":-12.0},
		{"id":"RightFoundation", "center":Vector3(12.4,0.7,-22.4), "size":Vector3(4.2,2.2,3.0), "yaw":13.0},
		{"id":"LeftMiddleShelf", "center":Vector3(6.4,2.45,-22.4), "size":Vector3(3.9,1.9,2.7), "yaw":6.0},
		{"id":"RightMiddleShelf", "center":Vector3(11.9,2.55,-22.5), "size":Vector3(3.9,2.0,2.65), "yaw":-8.0},
		{"id":"LeftHeadShelf", "center":Vector3(6.8,4.05,-22.9), "size":Vector3(3.6,1.5,2.5), "yaw":-5.0},
		{"id":"RightHeadShelf", "center":Vector3(11.8,4.2,-23.0), "size":Vector3(3.7,1.5,2.65), "yaw":9.0},
		{"id":"TopOutletSeat", "center":Vector3(9.1,5.1,-23.2), "size":Vector3(3.9,1.1,2.0), "yaw":-3.0},
		{"id":"CenterDrySpur", "center":Vector3(9.0,3.0,-21.9), "size":Vector3(0.6,1.4,1.4), "yaw":11.0},
		{"id":"LeftLedgeTip", "center":Vector3(7.2,2.8,-21.1), "size":Vector3(1.9,0.7,1.4), "yaw":-14.0},
		{"id":"RightLedgeTip", "center":Vector3(10.9,2.9,-21.2), "size":Vector3(1.7,0.65,1.5), "yaw":7.0},
		{"id":"BasinShoulder", "center":Vector3(11.4,0.05,-19.7), "size":Vector3(2.0,0.7,1.5), "yaw":-9.0}
	]
	for i: int in range(shelves.size()):
		var item: Dictionary = shelves[i]
		var size_value: Vector3 = item["size"] as Vector3
		var shelf: MeshInstance3D = _instance(_waterfall_shelf_mesh(size_value, float(i) * 1.73), _materials["stone"] as Material, parent)
		shelf.name = str(item["id"])
		shelf.position = item["center"] as Vector3
		shelf.rotation.y = deg_to_rad(float(item["yaw"]))
	# Thin broken moss sits on existing shelves; no foliage assets required this early.
	var moss_patches: Array[Dictionary] = [
		{"center":Vector3(6.4,3.425,-22.35), "size":Vector3(2.2,0.08,1.4), "yaw":6.0},
		{"center":Vector3(11.8,4.98,-23.0), "size":Vector3(2.0,0.08,1.4), "yaw":9.0},
		{"center":Vector3(11.9,3.58,-22.5), "size":Vector3(2.4,0.08,1.5), "yaw":-8.0}
	]
	for i: int in range(moss_patches.size()):
		var item: Dictionary = moss_patches[i]
		var size_value: Vector3 = item["size"] as Vector3
		var moss: MeshInstance3D = _instance(_waterfall_shelf_mesh(size_value, 7.0 + float(i)), _materials["moss"] as Material, parent)
		moss.name = "BrokenShelfMoss%d" % i
		moss.position = item["center"] as Vector3
		moss.rotation.y = deg_to_rad(float(item["yaw"]))
		moss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_create_staged_waterfall_mesh(parent)

func _waterfall_shelf_mesh(full_size: Vector3, phase: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var outline: Array[Vector2] = [Vector2(-0.75,-1.0),Vector2(0.52,-1.0),Vector2(1.0,-0.65),Vector2(1.0,0.50),Vector2(0.68,1.0),Vector2(-0.60,1.0),Vector2(-1.0,0.60),Vector2(-1.0,-0.55)]
	# Clipped corners plus broad face/bevel bands, not an ellipsoid or a box primitive.
	var bands: Array[Vector2] = [Vector2(0.68,-1.0),Vector2(0.90,-0.72),Vector2(1.0,-0.35),Vector2(1.0,0.26),Vector2(0.88,0.72),Vector2(0.73,1.0)]
	var rings: Array[PackedVector3Array] = []
	var half_size: Vector3 = full_size * 0.5
	var perimeter: Array[float] = [0.0]
	for i: int in range(outline.size()):
		var next: int = (i + 1) % outline.size()
		var a: Vector2 = outline[i] * Vector2(half_size.x,half_size.z)
		var b: Vector2 = outline[next] * Vector2(half_size.x,half_size.z)
		perimeter.append(perimeter[i] + a.distance_to(b))
	for band: Vector2 in bands:
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in range(outline.size()):
			var variation: float = sin(float(i) * 1.7 + phase) * 0.055 * (1.0 - absf(band.y))
			var y: float = (band.y + variation) * half_size.y
			ring.append(Vector3(outline[i].x * band.x * half_size.x, y, outline[i].y * band.x * half_size.z))
		rings.append(ring)
	for band_index: int in range(bands.size() - 1):
		var shade: float = 0.82 if band_index == 2 else 0.93
		var color_value: Color = Color(shade,shade,shade)
		for i: int in range(outline.size()):
			var next: int = (i + 1) % outline.size()
			var va: float = (bands[band_index].y + 1.0) * half_size.y
			var vb: float = (bands[band_index + 1].y + 1.0) * half_size.y
			# _quad computes exact geometric normals; its helper emits Godot-clockwise faces.
			_quad(vertices,normals,uvs,colors,rings[band_index][i],rings[band_index + 1][i],rings[band_index + 1][next],rings[band_index][next],color_value,Vector2(perimeter[i],va),Vector2(perimeter[i],vb),Vector2(perimeter[i + 1],vb),Vector2(perimeter[i + 1],va))
	var top: PackedVector3Array = rings[rings.size() - 1]
	var bottom: PackedVector3Array = rings[0]
	for i: int in range(outline.size()):
		var next: int = (i + 1) % outline.size()
		var uv_a: Vector2 = Vector2(top[i].x,top[i].z)
		var uv_b: Vector2 = Vector2(top[next].x,top[next].z)
		_triangle(vertices,normals,uvs,colors,Vector3(0,half_size.y,0),top[next],top[i],Color.WHITE,Vector2.ZERO,uv_b,uv_a)
		_triangle(vertices,normals,uvs,colors,Vector3(0,-half_size.y,0),bottom[i],bottom[next],Color(0.80,0.80,0.80),Vector2.ZERO,Vector2(bottom[i].x,bottom[i].z),Vector2(bottom[next].x,bottom[next].z))
	return _array_mesh(vertices,normals,uvs,colors)

func _create_staged_waterfall_mesh(parent: Node3D) -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var curtains: Array[Dictionary] = [
		{"points":[Vector3(8.05,5.35,-22.16),Vector3(8.10,4.90,-21.98),Vector3(8.17,3.90,-21.57),Vector3(8.20,3.24,-21.19)], "widths":[1.10,1.20,1.18,1.30]},
		{"points":[Vector3(9.65,5.20,-22.19),Vector3(9.62,4.75,-21.96),Vector3(9.69,3.90,-21.56),Vector3(9.70,3.24,-21.19)], "widths":[1.45,1.35,1.42,1.40]},
		{"points":[Vector3(8.02,3.10,-20.79),Vector3(8.11,2.40,-20.54),Vector3(8.21,1.0,-19.94),Vector3(8.25,-0.10,-19.2)], "widths":[0.68,0.67,0.57,0.60]},
		{"points":[Vector3(9.0,3.10,-20.80),Vector3(8.95,2.30,-20.53),Vector3(9.05,1.05,-19.95),Vector3(9.0,-0.10,-19.2)], "widths":[0.76,0.70,0.76,0.67]},
		{"points":[Vector3(9.96,3.10,-20.79),Vector3(9.91,2.50,-20.56),Vector3(9.75,1.0,-19.94),Vector3(9.77,-0.10,-19.2)], "widths":[0.65,0.63,0.62,0.56]}
	]
	for curtain_index: int in range(curtains.size()):
		var points: Array = curtains[curtain_index]["points"] as Array
		var widths: Array = curtains[curtain_index]["widths"] as Array
		for segment: int in range(points.size() - 1):
			var a: Vector3 = points[segment] as Vector3
			var b: Vector3 = points[segment + 1] as Vector3
			for j: int in range(8):
				var ta: float = float(j) / 8.0
				var tb: float = float(j + 1) / 8.0
				var pa: Vector3 = a.lerp(b,ta) + Vector3(0,0,sin(ta * PI) * 0.05)
				var pb: Vector3 = a.lerp(b,tb) + Vector3(0,0,sin(tb * PI) * 0.05)
				var wa: float = lerpf(float(widths[segment]),float(widths[segment + 1]),ta) * (1.0 + sin(ta * PI) * sin(float(curtain_index) * 1.7 + ta * 5.0) * 0.035) * 0.5
				var wb: float = lerpf(float(widths[segment]),float(widths[segment + 1]),tb) * (1.0 + sin(tb * PI) * sin(float(curtain_index) * 1.7 + tb * 5.0) * 0.035) * 0.5
				var va: float = (5.35 - pa.y) / 5.45
				var vb: float = (5.35 - pb.y) / 5.45
				_quad(vertices,normals,uvs,colors,pa + Vector3(-wa,0,0),pb + Vector3(-wb,0,0),pb + Vector3(wb,0,0),pa + Vector3(wa,0,0),Color.WHITE,Vector2(0,va),Vector2(0,vb),Vector2(1,vb),Vector2(1,va))
	# Short shelf runoff bridges the upper/lower stages; no wider river surface is added.
	_quad(vertices,normals,uvs,colors,Vector3(7.55,3.235,-21.19),Vector3(7.68,3.15,-20.78),Vector3(10.28,3.15,-20.78),Vector3(10.40,3.235,-21.19),Color.WHITE,Vector2(0,0.388),Vector2(0,0.404),Vector2(1,0.404),Vector2(1,0.388))
	var waterfall: MeshInstance3D = _instance(_array_mesh(vertices,normals,uvs,colors),_fall_material,parent)
	waterfall.name = "SteppedShelfCascade"
	waterfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foam_paths: Array[Array] = [
		[Vector3(7.58,3.25,-21.17),Vector3(8.08,3.26,-21.12),Vector3(8.57,3.25,-21.17)],
		[Vector3(9.06,3.25,-21.17),Vector3(9.66,3.26,-21.11),Vector3(10.35,3.25,-21.17)],
		[Vector3(7.98,-0.085,-19.12),Vector3(8.46,-0.08,-19.01),Vector3(9.04,-0.085,-19.08)],
		[Vector3(9.05,-0.085,-19.08),Vector3(9.61,-0.08,-19.00),Vector3(10.02,-0.085,-19.11)]
	]
	for values: Array in foam_paths:
		var path: Array[Vector3] = []
		for point: Vector3 in values:
			path.append(point)
		var foam: MeshInstance3D = _tube(path,0.022,0.015,_materials["flower_white"] as Material,parent,5)
		foam.name = "BrokenCascadeFoam"
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _create_forest() -> void:
	_leaf_mesh = _make_leaf_mesh()
	_canopy_mesh = _make_canopy_mesh(620, 1.0)
	_canopy_far_mesh = _make_canopy_mesh(235, 1.20)
	_canopy_shadow_mesh = _make_canopy_mesh(160, 1.24)
	_canopy_far_shadow_mesh = _make_canopy_mesh(75, 1.50)
	var forest: Node3D = Node3D.new()
	forest.name = "OldGrowthForest"
	add_child(forest)
	var positions: Array[Vector3] = [Vector3(-10, 0, 6), Vector3(-11, 0, -4), Vector3(14.8, 0, -5), Vector3(16.7, 0, 9), Vector3(-14, 0, 17), Vector3(20, 0, 18), Vector3(-8, 0, -15), Vector3(3, 0, -17), Vector3(19, 0, -13)]
	for i: int in range(34):
		var angle: float = TAU * float(i) / 34.0
		var distance_value: float = _rng.randf_range(22.0, 32.0)
		positions.append(Vector3(sin(angle) * distance_value, 0, cos(angle) * distance_value + 2.0))
	for index: int in range(positions.size()):
		var p: Vector3 = positions[index]
		var scale_value: float = _rng.randf_range(0.85, 1.30)
		_tree(p, scale_value, forest, index < 9)
	# The existing left tree carries the proposed curved framing limb.
	_create_framing_bough(forest)

func _create_framing_bough(parent: Node3D) -> void:
	var branch: Array[Vector3] = []
	for index: int in range(49):
		branch.append(_framing_bough_point(float(index) / 48.0))
	var main_bough: MeshInstance3D = _instance(_weathered_framing_bough_mesh(branch, 1.05, 0.16, 16, 0.0), _materials["bark"] as Material, parent)
	main_bough.name = "CurvedForegroundBough"
	# One substantial fork sits below the rising main limb, rather than twelve identical ribs.
	var fork_base: Vector3 = _framing_bough_point(0.61)
	var fork_tip: Vector3 = Vector3(2.1,9.4,7.3)
	var fork: Array[Vector3] = _framing_curve_points(fork_base,fork_base+Vector3(0.75,0.20,-0.10),fork_tip+Vector3(-1.20,-0.35,0.50),fork_tip,24)
	var fork_mesh: MeshInstance3D = _instance(_weathered_framing_bough_mesh(fork,0.38,0.035,12,1.3),_materials["bark"] as Material,parent)
	fork_mesh.name = "ForegroundBoughFork"
	var anchors: Array[Vector3] = [
		Vector3(-2.2,7.8,10.0),Vector3(0.5,8.8,8.5),Vector3(3.25,9.9,6.4),Vector3(6.3,10.7,4.7),
		Vector3(-2.5,7.4,9.8),Vector3(-0.1,8.2,8.5),Vector3(2.1,9.4,7.3),Vector3(5.2,10.0,5.6)
	]
	var scales: Array[Vector3] = [
		Vector3(1.50,0.85,1.15),Vector3(1.15,0.65,1.15),Vector3(1.35,0.80,1.10),Vector3(1.05,0.60,1.10),
		Vector3(0.75,0.50,0.85),Vector3(0.85,0.55,0.85),Vector3(0.75,0.50,0.80),Vector3(0.85,0.50,0.95)
	]
	var leaf_ids: Array[String] = ["leaf_gold","leaf","leaf_gold","leaf","leaf_dark","leaf_gold","leaf_gold","leaf_dark"]
	for index: int in range(anchors.size()):
		var mesh: ArrayMesh = _canopy_mesh if index < 4 else _canopy_far_mesh
		var rotation: Vector3 = Vector3(-0.18+float(index%3)*0.13,float(index)*0.91,0.12-float(index%2)*0.23)
		_add_foliage(leaf_ids[index],mesh,anchors[index],rotation,scales[index])
	# Two existing low-leaf shadow proxies add local canopy shade, not new lights.
	for index: int in [0,1]:
		_add_foliage("leaf_shadow",_canopy_shadow_mesh,anchors[index],Vector3(0,float(index)*0.91,0),scales[index]*Vector3(0.96,0.92,0.96))
	var bases: Array[Vector3] = [_framing_bough_point(0.55),_framing_bough_point(0.66),_framing_bough_point(0.76),_framing_bough_point(0.87),fork[6]]
	var tips: Array[Vector3] = [anchors[0],anchors[1],anchors[2],anchors[3],anchors[5]]
	var base_radii: Array[float] = [0.29,0.23,0.17,0.14,0.13]
	for index: int in range(bases.size()):
		var base: Vector3 = bases[index]
		var tip: Vector3 = tips[index]
		var bend: Vector3 = base.lerp(tip,0.42)+Vector3(0.08,0.20,-0.22)
		var side_branch: Array[Vector3] = _framing_curve_points(base,bend,base.lerp(tip,0.78)+Vector3(-0.10,-0.08,0.15),tip,10)
		var side_mesh: MeshInstance3D = _instance(_weathered_framing_bough_mesh(side_branch,base_radii[index],0.018,8,float(index)*0.83+2.0),_materials["bark"] as Material,parent)
		side_mesh.name = "FramingSideBranch%d" % index
		for side: int in [-1,1]:
			var twig_base: Vector3 = side_branch[7]
			var twig_tip: Vector3 = tip+Vector3(float(side)*0.44,0.15+float(index%2)*0.13,-0.34)
			var twig: Array[Vector3] = _framing_curve_points(twig_base,twig_base.lerp(twig_tip,0.35)+Vector3(0,0.12,0),twig_base.lerp(twig_tip,0.76),twig_tip,4)
			var twig_mesh: MeshInstance3D = _instance(_weathered_framing_bough_mesh(twig,0.045,0.006,6,float(index+side)*0.71),_materials["bark"] as Material,parent)
			twig_mesh.name = "FramingTerminalTwig"
	# Consume EXACTLY the old12*22*7 global draws, in the same order and ranges.
	# Re-map them to clustered leaves without moving downstream forest/ground instances.
	var leaf_anchor_indices: Array[int] = [0,0,1,1,2,2,3,3,4,5,6,7]
	for group: int in range(12):
		var anchor_index: int = leaf_anchor_indices[group]
		var anchor: Vector3 = anchors[anchor_index]
		var cluster_size: Vector3 = scales[anchor_index]
		for leaf_index: int in range(22):
			var legacy_x: float = _rng.randf_range(-0.6,1.7)
			var legacy_y: float = _rng.randf_range(-0.6,0.4)
			var legacy_z: float = _rng.randf_range(-2.1,-0.2)
			var rx: float = _rng.randf_range(-1.0,1.0)
			var ry: float = _rng.randf_range(0.0,TAU)
			var rz: float = _rng.randf_range(-1.0,1.0)
			var leaf_scale: float = _rng.randf_range(0.42,0.85)
			var offset: Vector3 = Vector3((legacy_x+0.6)/2.3*2.0-1.0,(legacy_y+0.6)*2.0-1.0,(legacy_z+2.1)/1.9*2.0-1.0)
			offset *= Vector3(cluster_size.x*0.78,cluster_size.y*0.72,cluster_size.z*0.78)
			var material_id: String = "leaf_gold" if leaf_index%5 == 0 else ("leaf_dark" if leaf_index%7 == 0 else "leaf")
			_add_foliage(material_id,_leaf_mesh,anchor+offset,Vector3(rx-0.18,ry,rz*0.75),Vector3.ONE*leaf_scale*0.92)

func _framing_curve_points(a: Vector3, b: Vector3, c: Vector3, d: Vector3, segments: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index: int in range(segments+1):
		var t: float = float(index)/float(segments)
		var s: float = 1.0-t
		points.append(a*s*s*s+b*3.0*s*s*t+c*3.0*s*t*t+d*t*t*t)
	return points

func _weathered_framing_bough_mesh(points: Array[Vector3], start_radius: float, end_radius: float, sides: int = 16, phase: float = 0.0) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var distances: Array[float] = [0.0]
	var frame_u: Vector3 = Vector3.ZERO
	for index: int in range(1,points.size()):
		distances.append(distances[index-1]+points[index-1].distance_to(points[index]))
	for index: int in range(points.size()):
		var t: float = float(index)/float(points.size()-1)
		var tangent: Vector3 = (points[mini(index+1,points.size()-1)]-points[maxi(0,index-1)]).normalized()
		if index == 0:
			var reference: Vector3 = Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.98 else Vector3.UP
			frame_u = tangent.cross(reference).normalized()
		else:
			frame_u = (frame_u-tangent*frame_u.dot(tangent)).normalized()
		var frame_v: Vector3 = tangent.cross(frame_u).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		var radius: float = lerpf(end_radius,start_radius,pow(1.0-t,0.78))
		var knot_strength: float = 0.20 if start_radius > 0.60 else (0.085 if start_radius > 0.18 else 0.035)
		var knot: float = (exp(-pow((t-0.60)/0.052,2.0))+exp(-pow((t-0.75)/0.047,2.0))*0.70)*knot_strength
		for side: int in range(sides):
			var angle: float = float(side)*TAU/float(sides)
			var radial: Vector3 = frame_u*cos(angle)*1.07+frame_v*sin(angle)*0.93
			var variation: float = 1.0+sin(angle*3.0+t*2.3+phase)*0.085+sin(angle*7.0-t*4.0+phase)*0.028+knot*(0.62+cos(angle-0.7+phase)*0.38)
			ring.append(points[index]+radial*radius*variation)
		rings.append(ring)
	# Derive smooth normals from the actual displaced rings and longitudinal tangent.
	for index: int in range(points.size()):
		var ns: PackedVector3Array = PackedVector3Array()
		for side: int in range(sides):
			var previous: int = (side+sides-1)%sides
			var next: int = (side+1)%sides
			var around: Vector3 = rings[index][next]-rings[index][previous]
			var along: Vector3 = rings[mini(index+1,rings.size()-1)][side]-rings[maxi(0,index-1)][side]
			ns.append(around.cross(along).normalized())
		ring_normals.append(ns)
	for index: int in range(points.size()-1):
		for side: int in range(sides):
			var next: int = (side+1)%sides
			var ua: float = float(side)/float(sides)
			var ub: float = float(side+1)/float(sides)
			_smooth_quad(vertices,normals,uvs,colors,rings[index][side],rings[index][next],rings[index+1][next],rings[index+1][side],ring_normals[index][side],ring_normals[index][next],ring_normals[index+1][next],ring_normals[index+1][side],Color.WHITE,Vector2(ua,distances[index]*0.5),Vector2(ub,distances[index]*0.5),Vector2(ub,distances[index+1]*0.5),Vector2(ua,distances[index+1]*0.5))
	for side: int in range(sides):
		var next: int = (side+1)%sides
		_triangle(vertices,normals,uvs,colors,points[0],rings[0][next],rings[0][side],Color.WHITE)
		_triangle(vertices,normals,uvs,colors,points[points.size()-1],rings[rings.size()-1][side],rings[rings.size()-1][next],Color.WHITE)
	return _array_mesh(vertices,normals,uvs,colors)

func _framing_bough_point(t: float) -> Vector3:
	# Existing left-tree attachment retained; curvature rises through the left/top frame.
	var controls: Array[Vector3] = [Vector3(-13.8,4.2,17.0),Vector3(-11.0,4.6,15.9),Vector3(-8.4,4.9,13.8),Vector3(-5.8,5.3,11.5),Vector3(-3.2,6.0,9.6),Vector3(-0.1,8.1,8.2),Vector3(3.1,9.75,6.8),Vector3(7.1,11.15,4.5)]
	var scaled: float = clampf(t,0.0,1.0)*float(controls.size()-1)
	var index: int = mini(controls.size()-2,int(scaled))
	var f: float = scaled-float(index)
	var a: Vector3 = controls[maxi(0,index-1)]
	var b: Vector3 = controls[index]
	var c: Vector3 = controls[index+1]
	var d: Vector3 = controls[mini(controls.size()-1,index+2)]
	return 0.5*(2.0*b+(-a+c)*f+(2.0*a-5.0*b+4.0*c-d)*f*f+(-a+3.0*b-3.0*c+d)*f*f*f)

func _tree(origin: Vector3, size_value: float, parent: Node3D, collidable: bool) -> void:
	var tree: Node3D = Node3D.new()
	parent.add_child(tree)
	tree.position = origin
	# Sculpt only the existing near right tree; trunk/root/body and every draw stay fixed.
	var right_crown: bool = collidable and origin.distance_squared_to(Vector3(14.8,0,-5)) < 0.001
	# The existing distant ring tree 22 crosses the moon in the fixed comparison view.
	# Reshape its upper visual crown only; no roots, body, RNG draws or instance counts change.
	var far_right_crown: bool = not collidable and origin.distance_squared_to(Vector3(15.965662,0,-15.513497)) < 0.001
	var height_value: float = _rng.randf_range(10.4, 15.3) * size_value
	var lean: Vector3 = Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.8, 0.8))
	var trunk: Array[Vector3] = [Vector3.ZERO, Vector3(lean.x * 0.15, height_value * 0.35, lean.z * 0.15), Vector3(lean.x * 0.55, height_value * 0.65, lean.z * 0.55), Vector3(lean.x, height_value, lean.z)]
	if far_right_crown:
		for point_index: int in range(trunk.size()):
			trunk[point_index] = _compressed_right_crown_point(trunk[point_index], true)
	_tube(trunk, 0.63 * size_value, 0.17 * size_value, _materials["bark"] as Material, tree, 12)
	if collidable:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		tree.add_child(body)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
		cylinder_shape.radius = 0.54 * size_value
		cylinder_shape.height = height_value * 0.73
		shape.shape = cylinder_shape
		shape.position.y = cylinder_shape.height * 0.5
		body.add_child(shape)
	for i: int in range(7):
		var angle: float = float(i) * TAU / 7.0 + _rng.randf_range(-0.2, 0.2)
		var root: Array[Vector3] = [Vector3(sin(angle) * 0.30, 0.50, cos(angle) * 0.30), Vector3(sin(angle) * 0.90, 0.15, cos(angle) * 0.90), Vector3(sin(angle) * 1.65, 0.0, cos(angle) * 1.65)]
		_tube(root, 0.19 * size_value, 0.035, _materials["bark"] as Material, tree, 8)
	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0 + _rng.randf_range(-0.4, 0.4)
		var height_start: float = height_value * _rng.randf_range(0.53, 0.85)
		var span: float = _rng.randf_range(2.4, 4.3) * size_value
		var endpoint: Vector3 = Vector3(sin(angle) * span + lean.x, height_start + _rng.randf_range(1.7, 3.1), cos(angle) * span + lean.z)
		var crown_lowered: bool = right_crown and (i == 0 or i >= 5)
		var crown_profile: Vector3 = Vector3(0.78,0.66,0.82) if crown_lowered else Vector3.ONE
		if far_right_crown:
			crown_profile *= Vector3(1.0,0.52,1.0)
		if crown_lowered:
			endpoint.y -= 3.10 if i == 7 else 2.65
		endpoint = _compressed_right_crown_point(endpoint, far_right_crown)
		var start: Vector3 = Vector3(lean.x * 0.5, height_start, lean.z * 0.5)
		if crown_lowered:
			start.y -= 1.25
		start = _compressed_right_crown_point(start, far_right_crown)
		_tube([start, start.lerp(endpoint, 0.45) + Vector3(0, -0.2, 0), endpoint], 0.26 * size_value, 0.045, _materials["bark"] as Material, tree, 8)
		for twig: int in range(2):
			var twig_offset: Vector3 = Vector3(_rng.randf_range(-1.3, 1.3), _rng.randf_range(-0.2, 0.8), _rng.randf_range(-1.3, 1.3))
			var tip: Vector3 = endpoint + twig_offset * crown_profile
			_tube([endpoint - Vector3(0, 0.30 * (0.52 if far_right_crown else 1.0), 0), tip], 0.06, 0.009, _materials["bark"] as Material, tree, 6)
		var canopy_id: String = "leaf_dark" if i % 3 == 0 else "leaf"
		var visible_canopy: ArrayMesh = _canopy_mesh if collidable else _canopy_far_mesh
		var shadow_canopy: ArrayMesh = _canopy_shadow_mesh if collidable else _canopy_far_shadow_mesh
		_add_foliage(canopy_id, visible_canopy, origin + endpoint, Vector3(0, angle, 0), Vector3(2.05, 1.55, 2.05) * size_value * crown_profile)
		_add_foliage("leaf_gold", visible_canopy, origin + endpoint + Vector3(0.9, 0.65 * (0.52 if far_right_crown else 1.0), 0.15), Vector3(0, angle + 0.9, 0), Vector3(1.05, 0.85, 1.20) * size_value * crown_profile)
		_add_foliage("leaf_shadow", shadow_canopy, origin + endpoint, Vector3(0, angle, 0), Vector3(2.05, 1.55, 2.05) * size_value * crown_profile)
		for leaf_index: int in range(18):
			var offset: Vector3 = Vector3(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-1.15, 1.45), _rng.randf_range(-2.0, 2.0)) * size_value
			if offset.length() > 2.5 * size_value:
				continue
			var lp: Vector3 = origin + endpoint + offset * crown_profile
			var mat_id: String = "leaf_gold" if _rng.randf() < 0.26 else "leaf"
			_add_foliage(mat_id, _leaf_mesh, lp, Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0, TAU), _rng.randf_range(-1.2, 1.2)), Vector3.ONE * _rng.randf_range(0.45, 0.88) * (0.86 if crown_lowered else 1.0))
	for line: int in range(10):
		var a: float = float(line) * TAU / 10.0
		var bark_line: Array[Vector3] = []
		for i: int in range(8):
			var t: float = float(i) / 7.0
			var r: float = lerpf(0.64, 0.30, t) * size_value
			bark_line.append(_compressed_right_crown_point(Vector3(sin(a + sin(t * 9.0) * 0.03) * r, t * height_value * 0.70, cos(a) * r) + lean * t * 0.4, far_right_crown))
		_tube(bark_line, 0.023, 0.014, _materials["wood"] as Material, tree, 4)
	# Cover this existing near tree's exposed apical tip, clear of the fixed moon aperture.
	if right_crown:
		var apical_anchor: Vector3 = origin + trunk[trunk.size()-1] + Vector3(0.10,-0.40,0.0)
		var apical_scale: Vector3 = Vector3(0.64,0.94,0.66)
		_add_foliage("leaf",_canopy_far_mesh,apical_anchor,Vector3(0,2.0,0),apical_scale)
		_add_foliage("leaf_shadow",_canopy_far_shadow_mesh,apical_anchor,Vector3(0,2.0,0),apical_scale)

func _compressed_right_crown_point(point: Vector3, enabled: bool) -> Vector3:
	# Keep the lower 9m unchanged; compress the existing upper silhouette coherently.
	if not enabled or point.y <= 9.0:
		return point
	return Vector3(point.x, 9.0 + (point.y - 9.0) * 0.52, point.z)

func _create_distant_scenery() -> void:
	var distant: Node3D = Node3D.new()
	distant.name = "ForestBeyondTheClearing"
	add_child(distant)
	for i: int in range(15):
		var x: float = -26.0 + float(i) * 4.0
		var rock_origin: Vector3 = Vector3(x, 0.7, -27.0 + _rng.randf_range(-3.0, 2.0))
		var rock_size: Vector3 = Vector3(_rng.randf_range(3.0, 5.2), _rng.randf_range(3.0, 5.5), _rng.randf_range(3.5, 5.2))
		_rock(rock_origin, rock_size, distant, false)
		var moss: MeshInstance3D = _rock(rock_origin + Vector3(0, rock_size.y * 0.48, 0.15), rock_size * Vector3(0.90, 0.48, 0.90), distant, false)
		moss.material_override = _materials["moss"] as Material
		_add_foliage("leaf_dark", _canopy_far_mesh, rock_origin + Vector3(0, rock_size.y, 0), Vector3(0, _rng.randf_range(0, TAU), 0), Vector3(2.0, 0.90, 1.7))
	var homes: Array[Vector3] = [Vector3(16.5, 2.0, -18.5), Vector3(22, 4.7, -22), Vector3(-15, 1.5, -24)]
	for p: Vector3 in homes:
		var home: Node3D = Node3D.new()
		distant.add_child(home)
		home.position = p
		_cylinder(Vector3(0, 0.9, 0), 0.72, 0.57, 1.80, _materials["plaster"] as Material, home)
		_cap(Vector3(0, 1.70, 0), 1.40, 0.65, home)
		_window(Vector3(0, 0.98, 0.73), 0.21, 0.26, 0, home)
		_lantern(Vector3(0.75, 0.6, 0.48), 0.17, home, false)

func _ground_foliage_allowed(point: Vector3, reach: float) -> bool:
	# Include the entire plant footprint, rather than only its center.
	if absf(point.x - 9.0) < 1.24 + reach or _near_route(point, 1.10 + reach):
		return false
	if Vector2(point.x, point.z).length() < 3.3 + reach:
		return false
	if Vector2(point.x + 4.1, point.z + 0.4).length() < 2.0 + reach:
		return false
	if point.x > 2.3 - reach and point.x < 7.3 + reach and point.z > -1.7 - reach and point.z < 2.9 + reach:
		return false
	if point.x > -6.0 - reach and point.x < -3.6 + reach and point.z > 2.3 - reach and point.z < 4.8 + reach:
		return false
	return true

func _append_ground_leaf(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, start: Vector3, finish: Vector3, width: float, color_value: Color) -> void:
	# Rounded outline with a gently raised midrib; twelve triangles per blade.
	var direction: Vector3 = (finish - start).normalized()
	var side: Vector3 = Vector3(direction.z, 0, -direction.x).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var up: Vector3 = direction.cross(side).normalized()
	var times: Array[float] = [0.0, 0.22, 0.50, 0.78, 1.0]
	var centers: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for t: float in times:
		var shape: float = pow(maxf(0.0, sin(t * PI)), 0.70)
		var center: Vector3 = start.lerp(finish, t) + up * sin(t * PI) * width * 0.20
		centers.append(center)
		left.append(center + side * width * shape - up * width * shape * 0.12)
		right.append(center - side * width * shape - up * width * shape * 0.12)
	var left_normal: Vector3 = (up + side * 0.30).normalized()
	var right_normal: Vector3 = (up - side * 0.30).normalized()
	for index: int in range(4):
		var ca: Vector3 = centers[index]
		var cb: Vector3 = centers[index + 1]
		var ua: Vector2 = Vector2(0.5, times[index])
		var ub: Vector2 = Vector2(0.5, times[index + 1])
		var la: Vector2 = Vector2(0.0, times[index])
		var lb: Vector2 = Vector2(0.0, times[index + 1])
		var ra: Vector2 = Vector2(1.0, times[index])
		var rb: Vector2 = Vector2(1.0, times[index + 1])
		if index == 0:
			_triangle(vertices, normals, uvs, colors, ca, cb, left[index + 1], color_value, ua, ub, lb)
			_triangle(vertices, normals, uvs, colors, right[index + 1], cb, ca, color_value, rb, ub, ua)
		elif index == 3:
			_triangle(vertices, normals, uvs, colors, ca, cb, left[index], color_value, ua, ub, la)
			_triangle(vertices, normals, uvs, colors, right[index], cb, ca, color_value, ra, ub, ua)
		else:
			_smooth_quad(vertices, normals, uvs, colors, ca, cb, left[index + 1], left[index], up, up, left_normal, left_normal, color_value, ua, ub, lb, la)
			_smooth_quad(vertices, normals, uvs, colors, right[index], right[index + 1], cb, ca, right_normal, right_normal, up, up, color_value * Color(0.96, 0.99, 0.94), ra, rb, ub, ua)


func _create_foliage() -> void:
	_fern_mesh = _make_fern_mesh()
	_broadleaf_mesh = _make_broadleaf_mesh()
	_flower_mesh = _make_flower_mesh()
	_grass_mesh = _make_grass_mesh()
	_glow_mesh = _make_tiny_mushroom_mesh()
	_create_foreground_understory_meshes()
	for i: int in range(6300):
		var p: Vector3 = Vector3(_rng.randf_range(-22, 23), 0, _rng.randf_range(-21, 27))
		var choice: float = _rng.randf()
		var fern: bool = choice >= 0.58 and choice < 0.70
		var reach: float = 0.45 if fern else 0.17
		if not _ground_foliage_allowed(p, reach):
			continue
		p.y = _ground_height(p.x, p.z)
		if choice < 0.58:
			_add_clustered_ground_foliage("leaf", _grass_mesh, p, Vector3(0, _rng.randf_range(0, TAU), 0), Vector3.ONE * _rng.randf_range(0.48, 0.90), 0.17)
		elif fern:
			_add_clustered_ground_foliage("leaf_dark", _fern_mesh, p, Vector3(0, _rng.randf_range(0, TAU), 0), Vector3.ONE * _rng.randf_range(0.55, 0.90), 0.45)
		elif choice < 0.96:
			var mat_id: String = "flower_white" if choice < 0.81 else ("flower_pink" if choice < 0.89 else "flower_blue")
			_add_clustered_ground_foliage(mat_id, _flower_mesh, p, Vector3(0, _rng.randf_range(0, TAU), 0), Vector3.ONE * _rng.randf_range(0.65, 1.05), 0.17)
		else:
			_add_clustered_ground_foliage("fairy", _glow_mesh, p, Vector3(0, _rng.randf_range(0, TAU), 0), Vector3.ONE * _rng.randf_range(0.60, 0.95), 0.17)
	# Smaller entry clusters, with clear stair/path and garden boundaries.
	for i: int in range(96):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var p: Vector3 = Vector3(side * _rng.randf_range(1.45, 3.55), 0.0, _rng.randf_range(3.3, 6.4))
		if not _ground_foliage_allowed(p, 0.17):
			continue
		p.y = _ground_height(p.x, p.z)
		_add_foliage("flower_pink" if i % 3 == 0 else "flower_white", _flower_mesh, p, Vector3(0, _rng.randf_range(0, TAU), 0), Vector3.ONE * _rng.randf_range(0.70, 1.05))
	for i: int in range(35):
		var p: Vector3 = Vector3(_rng.randf_range(-10, 18), 0, _rng.randf_range(-13, 21))
		if not _ground_foliage_allowed(p, 1.20):
			continue
		p.y = _ground_height(p.x, p.z)
		var size_value: float = _rng.randf_range(0.38, 0.70)
		var shrub: MeshInstance3D = _rock(p + Vector3(0, size_value * 0.25, 0), Vector3(size_value, size_value * 0.55, size_value), self, false)
		var bank_lift: float = _foreground_bank_shrub_lift(p)
		shrub.position.y += bank_lift
		shrub.material_override = _materials["moss"] as Material
		for j: int in range(24):
			var lp: Vector3 = p + Vector3(_rng.randf_range(-size_value, size_value), _rng.randf_range(0.12, size_value * 0.65), _rng.randf_range(-size_value, size_value))
			_add_bank_shrub_leaf("leaf_gold", _leaf_mesh, lp, Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0, TAU), _rng.randf_range(-0.8, 0.8)), Vector3.ONE * 0.34, bank_lift)
	# Retain broad-leaf pockets, rather than a continuous oversized blanket.
	for i: int in range(2600):
		var p: Vector3 = Vector3(_rng.randf_range(-18, 22), 0, _rng.randf_range(-18, 27))
		if not _ground_foliage_allowed(p, 0.39):
			continue
		p.y = _ground_height(p.x, p.z)
		_add_clustered_ground_foliage("leaf_gold" if i % 4 == 0 else "leaf", _broadleaf_mesh, p, Vector3(0, _rng.randf_range(0, TAU), 0), Vector3.ONE * _rng.randf_range(0.50, 0.85), 0.39)
	for i: int in range(1200):
		var p: Vector3 = Vector3(_rng.randf_range(-8, 13), 0, _rng.randf_range(4, 24))
		if not _ground_foliage_allowed(p, 0.17):
			continue
		p.y = _ground_height(p.x, p.z)
		_add_clustered_ground_foliage("flower_white" if i % 3 == 0 else "flower_blue", _flower_mesh, p, Vector3(0, _rng.randf_range(0, TAU), 0), Vector3.ONE * _rng.randf_range(0.70, 1.10), 0.17)
	_create_rooted_ground_groups()
	_flush_foliage()
	for p: Vector3 in [Vector3(-4, 0.35, 10), Vector3(6, 0.3, 10), Vector3(11, 0.3, 14), Vector3(-6, 0.3, 4)]:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = p
		light.omni_range = 2.6
		light.light_color = Color("797ee8")
		light.light_energy = 0.0
		add_child(light)
		_night_lights.append(light)

func _near_route(point: Vector3, radius: float) -> bool:
	var points: Array[Vector2] = [Vector2(-2, 23), Vector2(-2, 18), Vector2(-1, 11), Vector2(0, 5.5), Vector2(0, 3)]
	var loops: Array[Vector2] = [Vector2(-1, 11), Vector2(4, 9), Vector2(9, 7.5), Vector2(11.3, 7.5), Vector2(14, 2), Vector2(12, -6), Vector2(5, -9), Vector2(-5, -7), Vector2(-7, 5), Vector2(-1, 11)]
	var q: Vector2 = Vector2(point.x, point.z)
	for route: Array[Vector2] in [points, loops]:
		for index: int in range(route.size() - 1):
			var a: Vector2 = route[index]
			var b: Vector2 = route[index + 1]
			var t: float = clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if q.distance_to(a.lerp(b, t)) < radius:
				return true
	return false

func _house_reserved(point: Vector3) -> bool:
	return Vector2(point.x, point.z).length() < 3.3 or Vector2(point.x + 4.1, point.z + 0.4).length() < 2.0 or (point.x > 2.3 and point.x < 7.3 and point.z > -1.7 and point.z < 2.9) or (point.x > -6.0 and point.x < -3.6 and point.z > 2.3 and point.z < 4.8)

func _create_weather() -> void:
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "OutsideRain"
	add_child(rain_particles)
	rain_particles.position = Vector3(0, 8, 14)
	rain_particles.amount = 1600
	rain_particles.lifetime = 1.15
	rain_particles.visibility_aabb = AABB(Vector3(-20, -10, -11), Vector3(40, 20, 22))
	_rain_process = ShaderMaterial.new()
	_rain_process.shader = load("res://assets/world/rain.gdshader") as Shader
	_rain_process.set_shader_parameter("room_enabled", _room_ready)
	rain_particles.process_material = _rain_process
	rain_particles.local_coords = false
	var rain_mesh: CylinderMesh = CylinderMesh.new()
	rain_mesh.top_radius = 0.006
	rain_mesh.bottom_radius = 0.004
	rain_mesh.height = 0.19
	rain_mesh.radial_segments = 3
	var rain_mat: StandardMaterial3D = StandardMaterial3D.new()
	rain_mat.albedo_color = Color(0.68, 0.80, 0.88, 0.55)
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mesh.material = rain_mat
	rain_particles.draw_pass_1 = rain_mesh
	rain_particles.emitting = false
	_fireflies = GPUParticles3D.new()
	_fireflies.name = "ForestFireflies"
	add_child(_fireflies)
	_fireflies.position = Vector3(1, 1.2, 7)
	_fireflies.amount = 90
	_fireflies.lifetime = 8.0
	_fireflies.visibility_aabb = AABB(Vector3(-18, -2, -18), Vector3(36, 6, 36))
	var fire_process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	fire_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fire_process.emission_box_extents = Vector3(15, 0.8, 15)
	fire_process.direction = Vector3.UP
	fire_process.spread = 180.0
	fire_process.initial_velocity_min = 0.08
	fire_process.initial_velocity_max = 0.30
	fire_process.gravity = Vector3.ZERO
	fire_process.scale_min = 0.6
	fire_process.scale_max = 1.3
	_fireflies.process_material = fire_process
	var fire_mesh: SphereMesh = SphereMesh.new()
	fire_mesh.radius = 0.022
	fire_mesh.height = 0.044
	fire_mesh.radial_segments = 6
	fire_mesh.rings = 4
	var fire_material: StandardMaterial3D = StandardMaterial3D.new()
	fire_material.albedo_color = Color("f5cb74")
	fire_material.emission_enabled = true
	fire_material.emission = Color("ffcf67")
	fire_material.emission_energy_multiplier = 2.2
	fire_mesh.material = fire_material
	_fireflies.draw_pass_1 = fire_mesh
	_fireflies.emitting = false

func _window(origin: Vector3, half_width: float, half_height: float, yaw: float, parent: Node3D, main_surface: bool = false) -> void:
	var window: Node3D = Node3D.new()
	window.position = _main_stem_point(atan2(origin.x,origin.z),origin.y,3.0,6.30) if main_surface else origin
	window.rotation.y = yaw
	parent.add_child(window)
	_sphere(Vector3(0, 0, 0), Vector3(half_width, half_height, 0.049), _materials["glow"] as Material, window, 24, 12)
	var ring_points: Array[Vector3] = []
	for i: int in range(49):
		var a: float = TAU * float(i) / 48.0
		ring_points.append(Vector3(sin(a) * (half_width + 0.03), cos(a) * (half_height + 0.03), 0.06))
	_tube(ring_points, 0.065, 0.065, _materials["wood"] as Material, window, 8)
	var vertical_bar: MeshInstance3D = _box(Vector3(0, 0, 0.075), Vector3(0.055, half_height * 1.93, 0.046), _materials["wood"] as Material, window)
	var horizontal_bar: MeshInstance3D = _box(Vector3(0, 0, 0.078), Vector3(half_width * 1.93, 0.045, 0.046), _materials["wood"] as Material, window)
	_box(Vector3(0, -half_height - 0.06, 0), Vector3(half_width * 2.6, 0.13, 0.30), _materials["wood_light"] as Material, window)
	_practical_light(Vector3(0, 0, 0.30), 2.8, window)
	if main_surface:
		# Extra seven edge loops make eight long sections on each existing bar.
		# Its front face can follow the glowing oval instead of spanning one chord.
		var vertical_mesh: BoxMesh = vertical_bar.mesh as BoxMesh
		vertical_mesh.subdivide_height = 7
		var horizontal_mesh: BoxMesh = horizontal_bar.mesh as BoxMesh
		horizontal_mesh.subdivide_width = 7
		_main_stem_conform_window(window)

func _lantern(origin: Vector3, size_value: float, parent: Node3D, light: bool) -> void:
	var lantern: Node3D = Node3D.new()
	lantern.position = origin
	parent.add_child(lantern)
	var profile: Array[Vector2] = [Vector2(size_value * 0.24, -size_value * 0.48), Vector2(size_value * 0.35, -size_value * 0.31), Vector2(size_value * 0.31, size_value * 0.22), Vector2(size_value * 0.18, size_value * 0.48)]
	_lathe(profile, 8, _materials["glow"] as Material, lantern)
	_lathe([Vector2(size_value * 0.43, size_value * 0.22), Vector2(size_value * 0.30, size_value * 0.40), Vector2(0, size_value * 0.51)], 8, _materials["iron"] as Material, lantern)
	_lathe([Vector2(0, -size_value * 0.60), Vector2(size_value * 0.34, -size_value * 0.41), Vector2(size_value * 0.43, -size_value * 0.32)], 8, _materials["iron"] as Material, lantern)
	for i: int in range(4):
		var a: float = float(i) * TAU / 4.0 + PI * 0.25
		var r: float = size_value * 0.30
		_tube([Vector3(sin(a) * r, -size_value * 0.38, cos(a) * r), Vector3(sin(a) * r, size_value * 0.33, cos(a) * r)], size_value * 0.04, size_value * 0.04, _materials["iron"] as Material, lantern, 5)
	_ring(Vector3(0, size_value * 0.61, 0), size_value * 0.13, size_value * 0.025, _materials["iron"] as Material, lantern)
	_tube([Vector3(0, size_value * 0.77, 0), Vector3(0, size_value * 1.80, 0)], 0.012, 0.012, _materials["iron"] as Material, lantern, 5)
	if light:
		_practical_light(Vector3.ZERO, 3.1, lantern)

func _practical_light(origin: Vector3, radius: float, parent: Node3D) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = origin
	light.light_color = Color("ffc26a")
	light.omni_range = radius
	light.omni_attenuation = 1.5
	light.light_energy = 0.30
	light.shadow_enabled = false
	parent.add_child(light)
	_practical_lights.append(light)

func _pot(origin: Vector3, radius: float, parent: Node3D) -> void:
	var profile: Array[Vector2] = [Vector2(radius * 0.62, 0), Vector2(radius * 0.67, radius * 0.16), Vector2(radius * 0.98, radius * 1.15), Vector2(radius * 1.07, radius * 1.18), Vector2(radius * 1.07, radius * 1.36), Vector2(radius * 0.98, radius * 1.39), Vector2(radius * 0.91, radius * 1.28)]
	var pot: MeshInstance3D = _lathe(profile, 20, _materials["pot"] as Material, parent, 0.025)
	pot.position = origin
	_cylinder(origin + Vector3(0, radius * 1.27, 0), radius * 0.91, radius * 0.91, 0.03, _materials["soil"] as Material, parent)

func _flower_bouquet(origin: Vector3, parent: Node3D, count: int, scale_value: float) -> void:
	if _flower_mesh == null:
		_flower_mesh = _make_flower_mesh()
	if _leaf_mesh == null:
		_leaf_mesh = _make_leaf_mesh()
	for i: int in range(count):
		var offset: Vector3 = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.10, 0.12), _rng.randf_range(-0.15, 0.15)) * scale_value
		var flower: MeshInstance3D = _instance(_flower_mesh, _materials["flower_pink"] as Material if i % 3 == 0 else _materials["flower_white"] as Material, parent)
		flower.position = origin + offset
		flower.scale = Vector3.ONE * scale_value
		flower.rotation.y = _rng.randf_range(0, TAU)
		var leaf: MeshInstance3D = _instance(_leaf_mesh, _materials["leaf"] as Material, parent)
		leaf.position = origin + offset - Vector3(0, 0.09, 0)
		leaf.scale = Vector3.ONE * scale_value * 0.75
		leaf.rotation = Vector3(-0.5, _rng.randf_range(0, TAU), 0.0)

func _vine(points: Array[Vector3], parent: Node3D, flowers: bool, main_surface: bool = false) -> void:
	var fitted_points: Array[Vector3] = points
	if main_surface:
		fitted_points = []
		for point: Vector3 in points:
			fitted_points.append(_main_stem_ivy_point(point))
	_tube(fitted_points, 0.024, 0.014, _materials["leaf_dark"] as Material, parent, 5)
	if _leaf_mesh == null:
		_leaf_mesh = _make_leaf_mesh()
	if _flower_mesh == null:
		_flower_mesh = _make_flower_mesh()
	if _vine_blossom_mesh == null:
		_vine_blossom_mesh = _make_blossom_mesh()
	for index: int in range(points.size()):
		for side: int in [-1, 1]:
			var leaf: MeshInstance3D = _instance(_leaf_mesh, _materials["leaf"] as Material, parent)
			leaf.position = points[index] + Vector3(float(side) * _rng.randf_range(0.04, 0.13), _rng.randf_range(-0.08, 0.10), 0.085)
			leaf.scale = Vector3(1.15, 1, 0.57) * _rng.randf_range(0.65, 0.95)
			leaf.rotation = Vector3(_rng.randf_range(1.05, 1.70), _rng.randf_range(-0.25, 0.25), float(side) * _rng.randf_range(0.28, 1.18))
			if main_surface:
				_main_stem_attach_ivy_instance(leaf)
		if flowers and index % 2 == 0:
			var origin: Vector3 = points[index] + Vector3(_rng.randf_range(-0.13, 0.13), -0.10, 0.16)
			for blossom: int in range(4):
				var flower: MeshInstance3D = _instance(_vine_blossom_mesh, _materials["flower_pink"] as Material if blossom%3!=0 else _materials["flower_white"] as Material,parent)
				var phase: float = float(blossom)*2.4+float(index)*.73
				flower.position = origin+Vector3(sin(phase)*.105,cos(phase)*.09,.03*float(blossom))
				flower.rotation = Vector3(PI*.37+sin(phase)*.16,phase,0)
				flower.scale = Vector3.ONE*(.68+.11*float(blossom%3))
				if main_surface:
					_main_stem_attach_ivy_instance(flower)

func _arch_trim(origin: Vector3, yaw: float, width: float, height_value: float, parent: Node3D) -> void:
	var arch: Node3D = Node3D.new()
	arch.position = origin
	arch.rotation.y = yaw
	parent.add_child(arch)
	var radius: float = width * 0.5
	var spring: float = height_value - radius
	var points: Array[Vector3] = [Vector3(-radius, 0, 0), Vector3(-radius, spring, 0)]
	for i: int in range(23):
		var a: float = PI - float(i) * PI / 22.0
		points.append(Vector3(cos(a) * radius, spring + sin(a) * radius, 0))
	points.append(Vector3(radius, 0, 0))
	_tube(points, 0.055, 0.055, _materials["wood_light"] as Material, arch, 6)

func _arch_panel(width: float, height_value: float, thickness: float, center_x: float) -> ArrayMesh:
	var radius: float = width * 0.5
	var spring: float = height_value - radius
	var outline: Array[Vector2] = [Vector2(center_x - radius, 0), Vector2(center_x + radius, 0), Vector2(center_x + radius, spring)]
	for i: int in range(25):
		var a: float = float(i) * PI / 24.0
		outline.append(Vector2(center_x + cos(a) * radius, spring + sin(a) * radius))
	outline.append(Vector2(center_x - radius, spring))
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var middle: Vector2 = Vector2(center_x, height_value * 0.45)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		_triangle(vertices, normals, uvs, colors, Vector3(middle.x, middle.y, thickness * 0.5), Vector3(a.x, a.y, thickness * 0.5), Vector3(b.x, b.y, thickness * 0.5), Color.WHITE)
		_triangle(vertices, normals, uvs, colors, Vector3(middle.x, middle.y, -thickness * 0.5), Vector3(b.x, b.y, -thickness * 0.5), Vector3(a.x, a.y, -thickness * 0.5), Color.WHITE)
		_quad(vertices, normals, uvs, colors, Vector3(a.x, a.y, thickness * 0.5), Vector3(a.x, a.y, -thickness * 0.5), Vector3(b.x, b.y, -thickness * 0.5), Vector3(b.x, b.y, thickness * 0.5), Color.WHITE)
	return _array_mesh(vertices, normals, uvs, colors)

func _floor(origin: Vector3, radius: float, height_value: float, parent: Node3D, room: bool = false) -> void:
	_cylinder(origin, radius, radius, height_value, _materials["floor"] as Material, parent, true, room)

func _box(origin: Vector3, size_value: Vector3, material: Material, parent: Node3D, collision: bool = false, room: bool = false) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	var instance: MeshInstance3D = _instance(mesh, material, parent)
	instance.position = origin
	if material == null:
		instance.visible = false
	if collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		parent.add_child(body)
		body.position = origin
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size_value
		shape.shape = box
		body.add_child(shape)
		if room:
			_room_colliders.append(shape)
	return instance

func _cylinder(origin: Vector3, bottom_radius: float, top_radius: float, height_value: float, material: Material, parent: Node3D, collision: bool = false, room: bool = false) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height_value
	mesh.radial_segments = 64
	mesh.rings = 2
	var instance: MeshInstance3D = _instance(mesh, material, parent)
	instance.position = origin
	if collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.position = origin
		body.collision_layer = 1
		body.collision_mask = 2
		parent.add_child(body)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
		cylinder_shape.radius = maxf(bottom_radius, top_radius)
		cylinder_shape.height = height_value
		shape.shape = cylinder_shape
		body.add_child(shape)
		if room:
			_room_colliders.append(shape)
	return instance

func _sphere(origin: Vector3, size_value: Vector3, material: Material, parent: Node3D, sides: int = 20, rings: int = 12) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = sides
	sphere.rings = rings
	var instance: MeshInstance3D = _instance(sphere, material, parent)
	instance.position = origin
	instance.scale = size_value
	return instance

func _rock(origin: Vector3, size_value: Vector3, parent: Node3D, collision: bool = false, light: bool = false) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var sides: int = 16
	var rings: int = 10
	var seed_value: float = _rng.randf_range(0, 8)
	for j: int in range(rings):
		for i: int in range(sides):
			var a: float = TAU * float(i) / float(sides)
			var b: float = TAU * float(i + 1) / float(sides)
			var c: float = PI * float(j) / float(rings)
			var d: float = PI * float(j + 1) / float(rings)
			var pa: Vector3 = _rock_point(a, c, seed_value)
			var pb: Vector3 = _rock_point(b, c, seed_value)
			var pc: Vector3 = _rock_point(b, d, seed_value)
			var pd: Vector3 = _rock_point(a, d, seed_value)
			_smooth_quad(vertices, normals, uvs, colors, pa, pd, pc, pb, pa.normalized(), pd.normalized(), pc.normalized(), pb.normalized(), Color.WHITE)
	var mesh: ArrayMesh = _array_mesh(vertices, normals, uvs, colors)
	var instance: MeshInstance3D = _instance(mesh, _materials["stone_light"] as Material if light else _materials["stone"] as Material, parent)
	instance.position = origin
	instance.scale = size_value
	instance.rotation.y = _rng.randf_range(0, TAU)
	if collision:
		_mesh_collision(mesh, instance)
	return instance

# Unapproved five-site review08 sculpt; existing rock constructors/RNG stay intact.
func _foreground_boulder_point(point: Vector3, phase: float) -> Vector3:
	# Radial inward half-plane cuts keep every vertex in the original convex hull.
	var planes: Array[Vector3] = [Vector3(-0.18, 1.0, 0.11), Vector3(0.91, 0.43, -0.18), Vector3(-0.16, 0.48, 0.92)]
	var limits: PackedFloat64Array = PackedFloat64Array([0.80 + 0.04 * sin(phase), 0.96 + 0.025 * cos(phase), 1.01])
	var contraction: float = 1.0
	for i: int in range(3):
		var depth: float = planes[i].dot(point)
		if depth > limits[i]:
			contraction = minf(contraction, limits[i] / depth)
	var theta: float = atan2(point.x, point.z)
	var upper_cut: float = 1.0 - smoothstep(0.035, 0.125, absf(point.y - (0.27 + 0.04 * sin(theta * 2.0 + phase))))
	var lower_cut: float = 1.0 - smoothstep(0.025, 0.105, absf(point.y - (-0.16 + 0.035 * cos(theta * 3.0 - phase))))
	contraction *= 1.0 - 0.085 * upper_cut * (0.50 + 0.50 * smoothstep(-0.5, 0.7, cos(theta + phase)))
	contraction *= 1.0 - 0.055 * lower_cut * (0.35 + 0.65 * smoothstep(-0.6, 0.8, sin(theta * 2.0 - phase)))
	return point * clampf(contraction, 0.66, 1.0)

func _foreground_boulder_vertex_key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 100000.0), roundi(point.y * 100000.0), roundi(point.z * 100000.0))

func _sculpt_foreground_boulder(rock: MeshInstance3D, site_id: String) -> void:
	var old_arrays: Array = rock.mesh.surface_get_arrays(0)
	var old_v: PackedVector3Array = old_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var old_u: PackedVector2Array = old_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var old_c: PackedColorArray = old_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var upper_sum: float = 0.0
	var lower_sum: float = 0.0
	var upper_count: int = 0
	var lower_count: int = 0
	for point: Vector3 in old_v:
		if Vector2(point.x, point.z).length_squared() < 0.000000000001:
			if point.y > 0.0:
				upper_sum += point.y
				upper_count += 1
			else:
				lower_sum += point.y
				lower_count += 1
	var upper_pole: Vector3 = Vector3(0, upper_sum / float(maxi(upper_count, 1)), 0)
	var lower_pole: Vector3 = Vector3(0, lower_sum / float(maxi(lower_count, 1)), 0)
	var phase: float = rock.position.x * 0.37 + rock.position.z * 0.19
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var face_normals: PackedVector3Array = PackedVector3Array()
	var face_areas: PackedFloat64Array = PackedFloat64Array()
	var adjacency: Dictionary = {}
	var maximum_y: float = -1000.0
	for index: int in range(0, old_v.size(), 3):
		var original_a: Vector3 = old_v[index]
		var original_b: Vector3 = old_v[index + 1]
		var original_c: Vector3 = old_v[index + 2]
		if Vector2(original_a.x, original_a.z).length_squared() < 0.000000000001:
			original_a = upper_pole if original_a.y > 0.0 else lower_pole
		if Vector2(original_b.x, original_b.z).length_squared() < 0.000000000001:
			original_b = upper_pole if original_b.y > 0.0 else lower_pole
		if Vector2(original_c.x, original_c.z).length_squared() < 0.000000000001:
			original_c = upper_pole if original_c.y > 0.0 else lower_pole
		var a: Vector3 = _foreground_boulder_point(original_a, phase)
		var b: Vector3 = _foreground_boulder_point(original_b, phase)
		var c: Vector3 = _foreground_boulder_point(original_c, phase)
		var cross_value: Vector3 = (c - a).cross(b - a)
		var area: float = cross_value.length()
		if area <= 0.00000001:
			continue
		var face_index: int = face_normals.size()
		face_normals.append(cross_value / area)
		face_areas.append(area)
		for offset: int in range(3):
			var point: Vector3 = a if offset == 0 else (b if offset == 1 else c)
			vertices.append(point)
			uvs.append(old_u[index + offset])
			colors.append(old_c[index + offset])
			maximum_y = maxf(maximum_y, point.y)
			var key: Vector3i = _foreground_boulder_vertex_key(point)
			if not adjacency.has(key):
				adjacency[key] = []
			var faces: Array = adjacency[key] as Array
			faces.append(face_index)
	var normals: PackedVector3Array = PackedVector3Array()
	for index: int in range(vertices.size()):
		var face_index: int = int(index / 3)
		var normal: Vector3 = face_normals[face_index]
		var sum_value: Vector3 = Vector3.ZERO
		var faces: Array = adjacency[_foreground_boulder_vertex_key(vertices[index])] as Array
		for other_value: Variant in faces:
			var other: int = int(other_value)
			if normal.dot(face_normals[other]) >= 0.82:
				sum_value += face_normals[other] * face_areas[other]
		normals.append(sum_value.normalized())
	rock.mesh = _array_mesh(vertices, normals, uvs, colors)
	rock.set_meta("review08_sculpt_site", site_id)
	_apply_foreground_boulder_moss(rock)

func _apply_foreground_boulder_moss(rock: MeshInstance3D) -> void:
	# Distinct selected-only material identities survive the existing static batcher.
	var stone_source: ShaderMaterial = rock.material_override as ShaderMaterial
	var moss_source: ShaderMaterial = _materials["moss"] as ShaderMaterial
	var mixed_material: ShaderMaterial = stone_source.duplicate(false) as ShaderMaterial
	mixed_material.shader = load("res://assets/world/foreground_stone_moss_proposal_v1.gdshader") as Shader
	# Reapply original getter values explicitly after changing shaders, including defaults.
	for uniform: Dictionary in stone_source.shader.get_shader_uniform_list():
		var uniform_name: String = str(uniform["name"])
		mixed_material.set_shader_parameter(uniform_name, stone_source.get_shader_parameter(uniform_name))
	mixed_material.set_shader_parameter("shoulder_moss_texture", moss_source.get_shader_parameter("surface_albedo"))
	mixed_material.set_shader_parameter("shoulder_moss_base_color", moss_source.get_shader_parameter("base_color"))
	mixed_material.set_shader_parameter("shoulder_moss_accent_color", moss_source.get_shader_parameter("accent_color"))
	mixed_material.set_shader_parameter("shoulder_moss_texture_scale", moss_source.get_shader_parameter("surface_scale"))
	mixed_material.set_shader_parameter("shoulder_moss_local_from_world", Projection(rock.global_transform.affine_inverse()))
	mixed_material.set_shader_parameter("shoulder_moss_phase", rock.position.x * 0.37 + rock.position.z * 0.19)
	mixed_material.set_shader_parameter("shoulder_moss_strength", 0.62)
	mixed_material.set_shader_parameter("shoulder_moss_saturation", 0.68)
	mixed_material.set_shader_parameter("shoulder_moss_texture_blend", 0.70)
	rock.material_override = mixed_material

func _rock_point(theta: float, phi: float, seed_value: float) -> Vector3:
	var point: Vector3 = Vector3(sin(theta) * sin(phi), cos(phi), cos(theta) * sin(phi))
	var variation: float = 1.0 + sin(theta * 3.0 + seed_value) * sin(phi * 4.0 + seed_value) * 0.085 + cos(theta * 7.0 + phi * 5.0) * 0.037
	point = Vector3(signf(point.x) * pow(absf(point.x), 0.76), signf(point.y) * pow(absf(point.y), 0.90), signf(point.z) * pow(absf(point.z), 0.76))
	variation += sin(theta * 5.0 + seed_value * 1.9) * sin(phi * 3.0) * 0.085
	return point * variation

func _ring(origin: Vector3, radius: float, thickness: float, material: Material, parent: Node3D) -> void:
	var points: Array[Vector3] = []
	for i: int in range(25):
		var a: float = float(i) * TAU / 24.0
		points.append(origin + Vector3(sin(a) * radius, cos(a) * radius, 0))
	_tube(points, thickness, thickness, material, parent, 6)

func _tube(points: Array[Vector3], radius_start: float, radius_end: float, material: Material, parent: Node3D, sides: int = 8) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var arc_length: float = 0.0
	for i: int in range(points.size() - 1):
		var next_length: float = arc_length+points[i].distance_to(points[i+1])
		var direction: Vector3 = (points[i + 1] - points[i]).normalized()
		var cross_axis: Vector3 = Vector3.UP
		if absf(direction.dot(cross_axis)) > 0.97:
			cross_axis = Vector3.RIGHT
		var u: Vector3 = direction.cross(cross_axis).normalized()
		var v: Vector3 = direction.cross(u).normalized()
		var radius_a: float = lerpf(radius_start, radius_end, float(i) / float(points.size() - 1))
		var radius_b: float = lerpf(radius_start, radius_end, float(i + 1) / float(points.size() - 1))
		for j: int in range(sides):
			var a: float = TAU * float(j) / float(sides)
			var b: float = TAU * float(j + 1) / float(sides)
			var na: Vector3 = u * cos(a) + v * sin(a)
			var nb: Vector3 = u * cos(b) + v * sin(b)
			_smooth_quad(vertices, normals, uvs, colors, points[i] + na * radius_a, points[i] + nb * radius_a, points[i + 1] + nb * radius_b, points[i + 1] + na * radius_b, na, nb, nb, na, Color.WHITE,Vector2(float(j)/float(sides),arc_length*.5),Vector2(float(j+1)/float(sides),arc_length*.5),Vector2(float(j+1)/float(sides),next_length*.5),Vector2(float(j)/float(sides),next_length*.5))
		arc_length = next_length
	var instance: MeshInstance3D = _instance(_array_mesh(vertices, normals, uvs, colors), material, parent)
	return instance

func _lathe(profile: Array[Vector2], sides: int, material: Material, parent: Node3D, irregularity: float = 0.0, vertical_irregularity: float = 0.0) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var sign_value: float = -1.0 if profile[profile.size() - 1].y < profile[0].y else 1.0
	var max_radius: float = 0.001
	for point: Vector2 in profile:
		max_radius = maxf(max_radius,point.x)
	for j: int in range(profile.size() - 1):
		var slope: Vector2 = (profile[mini(j + 1, profile.size() - 1)] - profile[maxi(0, j - 1)]).normalized()
		var next_slope: Vector2 = (profile[mini(j + 2, profile.size() - 1)] - profile[j]).normalized()
		for i: int in range(sides):
			var a: float = TAU * float(i) / float(sides)
			var b: float = TAU * float(i + 1) / float(sides)
			var ra0: float = profile[j].x * (1.0 + sin(a * 7.0) * irregularity + sin(a * 13.0 + 0.7) * irregularity * 0.5)
			var rb0: float = profile[j].x * (1.0 + sin(b * 7.0) * irregularity + sin(b * 13.0 + 0.7) * irregularity * 0.5)
			var ra1: float = profile[j + 1].x * (1.0 + sin(a * 7.0) * irregularity + sin(a * 13.0 + 0.7) * irregularity * 0.5)
			var rb1: float = profile[j + 1].x * (1.0 + sin(b * 7.0) * irregularity + sin(b * 13.0 + 0.7) * irregularity * 0.5)
			var pa: Vector3 = Vector3(sin(a) * ra0, profile[j].y, cos(a) * ra0)
			var pb: Vector3 = Vector3(sin(b) * rb0, profile[j].y, cos(b) * rb0)
			var pc: Vector3 = Vector3(sin(b) * rb1, profile[j + 1].y, cos(b) * rb1)
			var pd: Vector3 = Vector3(sin(a) * ra1, profile[j + 1].y, cos(a) * ra1)
			pa.y += sin(a*5.0+0.7)*vertical_irregularity*pow(profile[j].x/max_radius,3.0)
			pb.y += sin(b*5.0+0.7)*vertical_irregularity*pow(profile[j].x/max_radius,3.0)
			pc.y += sin(b*5.0+0.7)*vertical_irregularity*pow(profile[j+1].x/max_radius,3.0)
			pd.y += sin(a*5.0+0.7)*vertical_irregularity*pow(profile[j+1].x/max_radius,3.0)
			var na: Vector3 = Vector3(sin(a) * slope.y, -slope.x, cos(a) * slope.y) * sign_value
			var nb: Vector3 = Vector3(sin(b) * slope.y, -slope.x, cos(b) * slope.y) * sign_value
			var nc: Vector3 = Vector3(sin(b) * next_slope.y, -next_slope.x, cos(b) * next_slope.y) * sign_value
			var nd: Vector3 = Vector3(sin(a) * next_slope.y, -next_slope.x, cos(a) * next_slope.y) * sign_value
			_smooth_quad(vertices, normals, uvs, colors, pa, pb, pc, pd, na, nb, nc, nd, Color.WHITE, Vector2(float(i) / float(sides), float(j) / float(profile.size())), Vector2(float(i + 1) / float(sides), float(j) / float(profile.size())), Vector2(float(i + 1) / float(sides), float(j + 1) / float(profile.size())), Vector2(float(i) / float(sides), float(j + 1) / float(profile.size())))
	return _instance(_array_mesh(vertices, normals, uvs, colors), material, parent)

func _instance(mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _mesh_collision(mesh: Mesh, parent: Node3D, room: bool = false) -> CollisionShape3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	parent.add_child(body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	if room:
		_room_colliders.append(shape)
	return shape

func _array_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, color_value: Color, ua: Vector2 = Vector2.ZERO, ub: Vector2 = Vector2.RIGHT, uc: Vector2 = Vector2.ONE) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	vertices.append_array(PackedVector3Array([a, c, b]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	uvs.append_array(PackedVector2Array([ua, uc, ub]))
	colors.append_array(PackedColorArray([color_value, color_value, color_value]))

func _quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color_value: Color, ua: Vector2 = Vector2.ZERO, ub: Vector2 = Vector2.RIGHT, uc: Vector2 = Vector2.ONE, ud: Vector2 = Vector2.DOWN) -> void:
	_triangle(vertices, normals, uvs, colors, a, b, c, color_value, ua, ub, uc)
	_triangle(vertices, normals, uvs, colors, a, c, d, color_value, ua, uc, ud)

func _smooth_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, color_value: Color, ua: Vector2 = Vector2.ZERO, ub: Vector2 = Vector2.RIGHT, uc: Vector2 = Vector2.ONE, ud: Vector2 = Vector2.DOWN) -> void:
	vertices.append_array(PackedVector3Array([a, c, b, a, d, c]))
	normals.append_array(PackedVector3Array([na, nc, nb, na, nd, nc]))
	uvs.append_array(PackedVector2Array([ua, uc, ub, ua, ud, uc]))
	colors.append_array(PackedColorArray([color_value, color_value, color_value, color_value, color_value, color_value]))

func _simple_quad(points: PackedVector3Array) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	_quad(vertices, normals, uvs, colors, points[0], points[1], points[2], points[3], Color.WHITE)
	return _array_mesh(vertices, normals, uvs, colors)

func _make_leaf_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	_append_ground_leaf(vertices, normals, uvs, colors, Vector3.ZERO, Vector3(0, 0.035, 0.52), 0.13, Color.WHITE)
	return _array_mesh(vertices, normals, uvs, colors)

func _append_leaf(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, start: Vector3, finish: Vector3, width: float, color_value: Color) -> void:
	var direction: Vector3 = finish - start
	var side: Vector3 = Vector3(direction.z, 0, -direction.x).normalized() * width
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT * width
	var middle: Vector3 = start.lerp(finish, 0.47) + Vector3(0, width * 0.16, 0)
	var quarter: Vector3 = start.lerp(finish, 0.24)
	var three_quarter: Vector3 = start.lerp(finish, 0.78)
	_triangle(vertices, normals, uvs, colors, start, quarter + side * 0.65, middle, color_value)
	_triangle(vertices, normals, uvs, colors, quarter + side * 0.65, middle + side, middle, color_value)
	_triangle(vertices, normals, uvs, colors, middle + side, three_quarter + side * 0.60, middle, color_value)
	_triangle(vertices, normals, uvs, colors, three_quarter + side * 0.60, finish, middle, color_value)
	_triangle(vertices, normals, uvs, colors, start, middle, quarter - side * 0.65, color_value * Color(0.93, 0.98, 0.90))
	_triangle(vertices, normals, uvs, colors, quarter - side * 0.65, middle, middle - side, color_value * Color(0.93, 0.98, 0.90))
	_triangle(vertices, normals, uvs, colors, middle - side, middle, three_quarter - side * 0.60, color_value)
	_triangle(vertices, normals, uvs, colors, three_quarter - side * 0.60, middle, finish, color_value)

func _make_fern_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for frond: int in range(5):
		var angle: float = float(frond) * TAU / 5.0
		var outward: Vector3 = Vector3(sin(angle), 0, cos(angle))
		var side: Vector3 = Vector3(cos(angle), 0, -sin(angle))
		var length_value: float = 0.38 + float(frond % 3) * 0.05
		var last: Vector3 = Vector3(0, 0.02, 0)
		for pinna: int in range(6):
			var t: float = float(pinna + 1) / 7.0
			var p: Vector3 = outward * length_value * t + Vector3(0, sin(t * PI * 0.90) * 0.26, 0)
			_quad(vertices, normals, uvs, colors, last - side * 0.004, p - side * 0.003, p + side * 0.003, last + side * 0.004, Color(0.86, 0.90, 0.72))
			var leaf_length: float = sin(t * PI) * 0.105 + 0.020
			_append_ground_leaf(vertices, normals, uvs, colors, p, p + side * leaf_length + outward * 0.022 + Vector3(0, 0.015, 0), leaf_length * 0.30, Color.WHITE)
			_append_ground_leaf(vertices, normals, uvs, colors, p, p - side * leaf_length + outward * 0.022 + Vector3(0, 0.015, 0), leaf_length * 0.30, Color(0.95, 0.99, 0.93))
			last = p
	return _array_mesh(vertices, normals, uvs, colors)

func _make_flower_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var center: Vector3 = Vector3(0.025, 0.34, 0)
	_quad(vertices, normals, uvs, colors, Vector3(-0.008, 0, 0), center - Vector3(0.007, 0, 0), center + Vector3(0.007, 0, 0), Vector3(0.008, 0, 0), Color(0.25, 0.49, 0.22))
	_quad(vertices, normals, uvs, colors, Vector3(0, 0, -0.008), center - Vector3(0, 0, 0.007), center + Vector3(0, 0, 0.007), Vector3(0, 0, 0.008), Color(0.25, 0.49, 0.22))
	_append_leaf(vertices, normals, uvs, colors, Vector3(0, 0.12, 0), Vector3(0.10, 0.19, 0.08), 0.029, Color(0.38, 0.66, 0.25))
	for petal: int in range(6):
		var angle: float = TAU * float(petal) / 6.0
		var radial: Vector3 = Vector3(sin(angle), 0, cos(angle))
		_append_ground_leaf(vertices, normals, uvs, colors, center + radial * 0.019, center + radial * 0.112 + Vector3(0, 0.008, 0), 0.036, Color.WHITE)
	for i: int in range(10):
		var a: float = float(i) * TAU / 10.0
		var b: float = float(i + 1) * TAU / 10.0
		_triangle(vertices, normals, uvs, colors, center + Vector3(0, 0.020, 0), center + Vector3(sin(a) * 0.034, 0.012, cos(a) * 0.034), center + Vector3(sin(b) * 0.034, 0.012, cos(b) * 0.034), Color(0.95, 0.71, 0.17))
	return _array_mesh(vertices, normals, uvs, colors)

func _make_blossom_mesh() -> ArrayMesh:
	# A blossom head for vines; no sideways ground-flower stem.
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for petal: int in range(5):
		var angle: float = TAU*float(petal)/5.0
		var radial: Vector3 = Vector3(sin(angle),0,cos(angle))
		_append_ground_leaf(vertices,normals,uvs,colors,radial*.012,radial*.095+Vector3(0,.008,0),.035,Color.WHITE)
	for index: int in range(8):
		var a: float = float(index)*TAU/8.0
		var b: float = float(index+1)*TAU/8.0
		_triangle(vertices,normals,uvs,colors,Vector3(0,.013,0),Vector3(sin(a)*.023,.01,cos(a)*.023),Vector3(sin(b)*.023,.01,cos(b)*.023),Color(.95,.72,.24))
	return _array_mesh(vertices,normals,uvs,colors)

func _make_grass_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for blade: int in range(6):
		var a: float = float(blade) * TAU / 6.0
		var radial: Vector3 = Vector3(sin(a), 0, cos(a))
		var side: Vector3 = Vector3(cos(a), 0, -sin(a)) * 0.012
		var base: Vector3 = radial * 0.055
		var middle: Vector3 = radial * 0.075 + Vector3(0, 0.20 + float(blade % 3) * 0.035, 0)
		var tip: Vector3 = radial * 0.12 + Vector3(0, 0.31 + float(blade % 3) * 0.035, 0)
		_quad(vertices, normals, uvs, colors, base - side, middle - side * 0.6, middle + side * 0.6, base + side, Color(0.86, 0.94, 0.70))
		_triangle(vertices, normals, uvs, colors, middle - side * 0.6, tip, middle + side * 0.6, Color(1.04, 1.03, 0.87))
	return _array_mesh(vertices, normals, uvs, colors)

func _make_tiny_mushroom_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(12):
		var a: float = TAU * float(i) / 12.0
		var b: float = TAU * float(i + 1) / 12.0
		var pa: Vector3 = Vector3(sin(a) * 0.018, 0, cos(a) * 0.018)
		var pb: Vector3 = Vector3(sin(b) * 0.018, 0, cos(b) * 0.018)
		_quad(vertices, normals, uvs, colors, pa, pb, pb + Vector3(0, 0.30, 0), pa + Vector3(0, 0.30, 0), Color(0.65, 0.69, 0.95))
		for j: int in range(4):
			var r0: float = 0.14 * float(j) / 4.0
			var r1: float = 0.14 * float(j + 1) / 4.0
			var y0: float = 0.34 + sqrt(maxf(0.0, 1.0 - pow(r0 / 0.14, 2.0))) * 0.10
			var y1: float = 0.34 + sqrt(maxf(0.0, 1.0 - pow(r1 / 0.14, 2.0))) * 0.10
			_quad(vertices, normals, uvs, colors, Vector3(sin(a) * r0, y0, cos(a) * r0), Vector3(sin(b) * r0, y0, cos(b) * r0), Vector3(sin(b) * r1, y1, cos(b) * r1), Vector3(sin(a) * r1, y1, cos(a) * r1), Color.WHITE)
	return _array_mesh(vertices, normals, uvs, colors)

func _add_foliage(id: String, mesh: ArrayMesh, origin: Vector3, rotation_value: Vector3, scale_value: Vector3) -> void:
	var key: String = "%s_%s_%d_%d" % [id, mesh.get_instance_id(), int(floor(origin.x / 8.0)), int(floor(origin.z / 8.0))]
	if not _foliage_chunks.has(key):
		_foliage_chunks[key] = {"mesh": mesh, "id": id, "transforms": []}
	var entry: Dictionary = _foliage_chunks[key] as Dictionary
	var transforms: Array = entry["transforms"] as Array
	var basis: Basis = Basis.from_euler(rotation_value).scaled(scale_value)
	transforms.append(Transform3D(basis, origin))

func _flush_foliage() -> void:
	var foliage: Node3D = Node3D.new()
	foliage.name = "SpatiallyChunkedFoliage"
	add_child(foliage)
	for key: String in _foliage_chunks.keys():
		var entry: Dictionary = _foliage_chunks[key] as Dictionary
		var transforms: Array = entry["transforms"] as Array
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = entry["mesh"] as Mesh
		multimesh.instance_count = transforms.size()
		for index: int in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index] as Transform3D)
		if bool(get_meta("portable_export", false)):
			# Keep authored CPU values before dummy-renderer readback loses their placement.
			multimesh.set_meta("portable_authored_instance_transforms", transforms.duplicate())
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _materials[entry["id"] as String] as Material
		instance.name = key
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if entry["id"] == "leaf_shadow" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if bool(multimesh.mesh.get_meta("review09_understory_shadow", false)):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		foliage.add_child(instance)
	_foliage_chunks.clear()

func _make_canopy_mesh(leaf_count: int = 620, leaf_scale: float = 1.0) -> ArrayMesh:
	# Hundreds of curved leaves make a foliage volume; no inflated sphere is visible.
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var source_leaf: ArrayMesh = _leaf_mesh if leaf_count >= 620 else _make_low_leaf_mesh()
	var leaf_arrays: Array = source_leaf.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = leaf_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var source_normals: PackedVector3Array = leaf_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var source_uvs: PackedVector2Array = leaf_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	for i: int in range(leaf_count):
		var theta: float = _rng.randf_range(0, TAU)
		var phi: float = acos(_rng.randf_range(-1, 1))
		var radius: float = _rng.randf_range(0.60, 1.02)
		var p: Vector3 = Vector3(sin(theta) * sin(phi), cos(phi), cos(theta) * sin(phi)) * radius
		p *= 1.0 + sin(theta * 5.0 + phi * 3.0) * 0.08
		var leaf_basis: Basis = Basis.from_euler(Vector3(_rng.randf_range(-1.25, 1.25), theta + _rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.9, 0.9)))
		var scale_value: float = _rng.randf_range(0.36, 0.58) * leaf_scale
		var color_value: Color = Color(0.82, 0.93, 0.65).lerp(Color(1.04, 1.0, 0.94), _rng.randf())
		for j: int in range(source_vertices.size()):
			vertices.append(p + leaf_basis * source_vertices[j] * scale_value)
			normals.append(leaf_basis * source_normals[j])
			uvs.append(source_uvs[j])
			colors.append(color_value)
	return _array_mesh(vertices, normals, uvs, colors)

func _make_broadleaf_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(5):
		var angle: float = float(i) * TAU / 5.0
		var radius: float = 0.34 + float(i % 3) * 0.035
		var finish: Vector3 = Vector3(sin(angle) * radius, 0.16 + float(i % 2) * 0.035, cos(angle) * radius)
		_append_ground_leaf(vertices, normals, uvs, colors, Vector3(0, 0.025, 0), finish, 0.105 + float(i % 2) * 0.015, Color(0.89, 0.97, 0.82).lerp(Color.WHITE, float(i % 3) / 3.0))
	return _array_mesh(vertices, normals, uvs, colors)

func _make_lily_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(28):
		var a: float = 0.13 + float(i) * (TAU - 0.26) / 28.0
		var b: float = 0.13 + float(i + 1) * (TAU - 0.26) / 28.0
		var ra: float = 0.17 + sin(a * 4.0) * 0.008
		var rb: float = 0.17 + sin(b * 4.0) * 0.008
		_triangle(vertices, normals, uvs, colors, Vector3(0, 0.008, 0), Vector3(sin(a) * ra, 0, cos(a) * ra * 1.16), Vector3(sin(b) * rb, 0, cos(b) * rb * 1.16), Color(0.78, 0.92, 0.65))
	return _array_mesh(vertices, normals, uvs, colors)

func _batch_static_meshes() -> void:
	# Static authored pieces share one material submission per 8m spatial bucket.
	# Interactive/growable geometry retains its own independently controlled nodes.
	var buckets: Dictionary = {}
	var sources: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	var world_inverse: Transform3D = global_transform.affine_inverse()
	for source: Node in sources:
		var instance: MeshInstance3D = source as MeshInstance3D
		if instance.mesh == null or not instance.visible or instance == _moon:
			continue
		if door_hinge.is_ancestor_of(instance) or wall_plug.is_ancestor_of(instance) or right_room.is_ancestor_of(instance):
			continue
		var material: Material = instance.material_override
		if material == null or material == _water_material or material == _fall_material:
			continue
		var xf: Transform3D = world_inverse * instance.global_transform
		var center: Vector3 = xf.origin
		var key: String = "%s_%d_%d" % [material.get_instance_id(), int(floor(center.x / 8.0)), int(floor(center.z / 8.0))]
		if not buckets.has(key):
			buckets[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray(), "material": material}
		var entry: Dictionary = buckets[key] as Dictionary
		var vertices: PackedVector3Array = entry["v"] as PackedVector3Array
		var normals: PackedVector3Array = entry["n"] as PackedVector3Array
		var uvs: PackedVector2Array = entry["u"] as PackedVector2Array
		var colors: PackedColorArray = entry["c"] as PackedColorArray
		var normal_transform: Basis = xf.basis.inverse().transposed()
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			var u: PackedVector2Array = PackedVector2Array()
			var c: PackedColorArray = PackedColorArray()
			var indices: PackedInt32Array = PackedInt32Array()
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				u = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			if arrays[Mesh.ARRAY_COLOR] != null:
				c = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var count: int = indices.size() if not indices.is_empty() else v.size()
			for j: int in range(count):
				var i: int = indices[j] if not indices.is_empty() else j
				vertices.append(xf * v[i])
				normals.append((normal_transform * n[i]).normalized())
				uvs.append(u[i] if not u.is_empty() else Vector2.ZERO)
				colors.append(c[i] if not c.is_empty() else Color.WHITE)
		entry["v"] = vertices
		entry["n"] = normals
		entry["u"] = uvs
		entry["c"] = colors
		instance.mesh = null
	var batches: Node3D = Node3D.new()
	batches.name = "BatchedStaticWorld"
	add_child(batches)
	for key: String in buckets.keys():
		var entry: Dictionary = buckets[key] as Dictionary
		var merged: MeshInstance3D = _instance(_array_mesh(entry["v"] as PackedVector3Array, entry["n"] as PackedVector3Array, entry["u"] as PackedVector2Array, entry["c"] as PackedColorArray), entry["material"] as Material, batches)
		merged.name = "Static_%s" % key

func _append_pinna(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, start: Vector3, finish: Vector3, width: float, color_value: Color) -> void:
	var direction: Vector3 = finish - start
	var side: Vector3 = Vector3(direction.z, 0, -direction.x).normalized() * width
	var middle: Vector3 = start.lerp(finish, 0.47) + Vector3(0, width * 0.14, 0)
	_triangle(vertices, normals, uvs, colors, start, middle + side, middle, color_value)
	_triangle(vertices, normals, uvs, colors, middle + side, finish, middle, color_value)
	_triangle(vertices, normals, uvs, colors, start, middle, middle - side, color_value)
	_triangle(vertices, normals, uvs, colors, middle - side, middle, finish, color_value)

func _make_low_leaf_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	_append_pinna(vertices, normals, uvs, colors, Vector3.ZERO, Vector3(0, 0.035, 0.52), 0.105, Color.WHITE)
	return _array_mesh(vertices, normals, uvs, colors)

# Proposed source09 foreground-only understory. No global RNG calls.
func _create_foreground_understory_meshes() -> void:
	_foreground_understory_meshes.clear()
	for variant: int in range(2):
		var suffix: String = "a" if variant == 0 else "b"
		_foreground_understory_meshes["cushion_" + suffix] = _make_understory_leaf_pocket(variant, false)
		_foreground_understory_meshes["broadleaf_" + suffix] = _make_understory_leaf_pocket(variant, true)
		_foreground_understory_meshes["fern_" + suffix] = _make_understory_fern(variant)
		_foreground_understory_meshes["flower_" + suffix] = _make_understory_flower(variant)
	for label: String in _foreground_understory_meshes.keys():
		var mesh: ArrayMesh = _foreground_understory_meshes[label] as ArrayMesh
		mesh.resource_name = "Review09Understory_" + label
		mesh.set_meta("review09_understory_label", label)
		mesh.set_meta("review09_understory_shadow", label == _FOREGROUND_UNDERSTORY_SHADOW_LABEL)
		var unique: Dictionary = {}
		var guard_vertices: PackedVector3Array = PackedVector3Array()
		var arrays: Array = mesh.surface_get_arrays(0)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex: Vector3 in source_vertices:
			if not unique.has(vertex):
				unique[vertex] = true
				guard_vertices.append(vertex)
		mesh.set_meta("review09_understory_guard_vertices", guard_vertices)

func _foreground_understory_choice(id: String, old_mesh: ArrayMesh, source_origin: Vector3, point: Vector3, turn: Vector3, size_value: Vector3, reach: float) -> Dictionary:
	var result: Dictionary = {"id": id, "mesh": old_mesh, "substituted": false, "family": "protected", "label": "", "reason": "protected_original"}
	if source_origin.x < -10.0 or source_origin.x > 14.0 or source_origin.z < 8.8 or source_origin.z > 24.0:
		result["reason"] = "outside_origin_domain"
		return result
	var phase: float = fposmod(sin(source_origin.x * 17.13 + source_origin.z * 9.97 + turn.y * 0.61) * 43758.5453, 1.0)
	var variant_phase: float = fposmod(sin(source_origin.x * 5.41 - source_origin.z * 11.73 + turn.y * 0.37) * 15731.743, 1.0)
	var suffix: String = "a" if variant_phase < 0.5 else "b"
	var label: String = ""
	var new_id: String = id
	if old_mesh == _grass_mesh:
		result["family"] = "grass"
		label = "cushion_" + suffix
	elif old_mesh == _broadleaf_mesh:
		result["family"] = "broadleaf"
		label = "broadleaf_" + suffix
	elif old_mesh == _fern_mesh:
		result["family"] = "fern"
		label = "fern_" + suffix
	elif old_mesh == _flower_mesh:
		result["family"] = "flower"
		var pocket: float = 0.5 + 0.5 * sin(point.x * 0.85 + sin(point.z * 0.63) * 1.65 + point.z * 0.31)
		if phase < 0.12 + 0.32 * pocket:
			label = "flower_" + suffix
		else:
			label = "cushion_" + suffix
			new_id = "leaf_dark" if phase > 0.78 else "leaf"
	else:
		return result
	result["label"] = label
	var mesh: ArrayMesh = _foreground_understory_meshes[label] as ArrayMesh
	var reason: String = _foreground_understory_guard(mesh, point, turn, size_value, reach)
	if not reason.is_empty():
		result["reason"] = reason
		return result
	result["id"] = new_id
	result["mesh"] = mesh
	result["substituted"] = true
	result["reason"] = "substituted"
	return result

func _foreground_understory_guard(mesh: ArrayMesh, point: Vector3, turn: Vector3, size_value: Vector3, reach: float) -> String:
	# Unique exact positions give the same vertex guard without repeated triangle corners.
	var vertices: PackedVector3Array = mesh.get_meta("review09_understory_guard_vertices") as PackedVector3Array
	var basis: Basis = Basis.from_euler(turn).scaled(size_value)
	for vertex: Vector3 in vertices:
		var q: Vector3 = point + basis * vertex
		if not q.is_finite():
			return "nonfinite_vertex"
		if Vector2(q.x - point.x, q.z - point.z).length() > reach + 0.000001:
			return "caller_reach"
		if q.x < -10.0 or q.x > 14.0 or q.z < 8.8 or q.z > 24.0:
			return "foreground_footprint_boundary"
		if not _ground_foliage_allowed(q, 0.0):
			return "route_reservation_water"
		var support: Dictionary = _foreground_bank_support(q)
		if not support.is_empty() and q.y < float(support["height"]) - 0.002:
			return "bank_vertex_below_2mm"
	return ""

func _make_understory_leaf_pocket(variant: int, broad: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var count: int = (6 + variant) if broad else (5 + variant * 2)
	for index: int in range(count):
		var phase: float = float(index) * 1.73 + float(variant) * 1.19
		var angle: float = float(index) * TAU / float(count) + sin(phase) * 0.30 + float(variant) * 0.36
		var radial: Vector3 = Vector3(sin(angle), 0, cos(angle))
		var lateral: Vector3 = Vector3(cos(angle), 0, -sin(angle))
		var length_value: float = (0.235 + 0.035 * sin(phase + 0.4)) if broad else (0.111 + 0.014 * sin(phase + 0.4))
		var width: float = (0.110 + 0.016 * cos(phase)) if broad else (0.050 + 0.008 * cos(phase))
		var finish_y: float = (0.092 + 0.036 * cos(phase * 0.8)) if broad else (0.067 + 0.013 * cos(phase * 0.8))
		var bend_y: float = (0.290 + 0.035 * sin(phase * 0.7)) if broad else (0.200 + 0.020 * sin(phase * 0.7))
		var finish: Vector3 = radial * length_value + lateral * length_value * 0.10 * sin(phase * 1.4) + Vector3(0, finish_y, 0)
		var control: Vector3 = radial * length_value * 0.38 + lateral * length_value * 0.22 * sin(phase + 0.9) + Vector3(0, bend_y, 0)
		var color_value: Color = Color(0.74, 0.88, 0.65).lerp(Color(1.01, 0.99, 0.89), 0.5 + 0.5 * sin(phase + 0.5))
		_append_understory_rounded_leaf(vertices, normals, uvs, colors, Vector3.ZERO, control, finish, width, 0.18 * sin(phase * 1.3), color_value)
	_understory_smooth_normals(vertices, normals)
	return _array_mesh(vertices, normals, uvs, colors)

func _make_understory_fern(variant: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var count: int = 3 + variant
	for frond: int in range(count):
		var phase: float = float(frond) * 2.17 + float(variant) * 0.81
		var angle: float = float(frond) * TAU / float(count) + 0.32 * sin(phase) + float(variant) * 0.28
		var radial: Vector3 = Vector3(sin(angle), 0, cos(angle))
		var side: Vector3 = Vector3(cos(angle), 0, -sin(angle))
		var length_value: float = 0.335 + 0.045 * sin(phase + 0.4)
		var control: Vector3 = radial * length_value * 0.31 + side * 0.033 * sin(phase) + Vector3(0, 0.53 + 0.04 * sin(phase), 0)
		var finish: Vector3 = radial * length_value + side * 0.022 * sin(phase * 0.7) + Vector3(0, 0.13 + 0.035 * cos(phase), 0)
		var stalk: PackedVector3Array = PackedVector3Array()
		for row: int in range(7):
			stalk.append(_understory_bezier(Vector3.ZERO, control, finish, float(row) / 6.0))
		_append_understory_stalk(vertices, normals, uvs, colors, stalk, 0.0045, 0.0016, Color(0.72, 0.86, 0.61))
		for pinna: int in range(5):
			var t: float = 0.18 + float(pinna) * 0.15
			var start: Vector3 = _understory_bezier(Vector3.ZERO, control, finish, t)
			var length_pinna: float = (0.071 + 0.018 * sin(phase + float(pinna))) * sin(t * PI) + 0.012
			for direction: int in [-1, 1]:
				var spread: Vector3 = side * float(direction)
				var unequal: float = 1.0 + 0.16 * sin(phase * 1.9 + float(pinna) + float(direction))
				var end: Vector3 = start + spread * length_pinna * unequal + radial * 0.028 + Vector3(0, 0.015 + 0.012 * sin(phase + float(pinna)), 0)
				var bend: Vector3 = start.lerp(end, 0.46) + radial * 0.008 + Vector3(0, 0.035, 0)
				_append_understory_blade(vertices, normals, uvs, colors, start, bend, end, length_pinna * 0.23, 0.13 * float(direction), Color(0.92, 0.99, 0.84))
	_understory_smooth_normals(vertices, normals)
	return _array_mesh(vertices, normals, uvs, colors)

func _make_understory_flower(variant: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var center: Vector3 = Vector3(0.029 if variant == 0 else -0.039, 0.235 if variant == 0 else 0.175, 0.012 if variant == 0 else 0.024)
	var control: Vector3 = Vector3(-0.021 if variant == 0 else 0.026, center.y * 0.72, -0.014)
	var stalk: PackedVector3Array = PackedVector3Array()
	for row: int in range(6):
		stalk.append(_understory_bezier(Vector3.ZERO, control, center, float(row) / 5.0))
	_append_understory_stalk(vertices, normals, uvs, colors, stalk, 0.0042, 0.0022, Color(0.25, 0.49, 0.22))
	for leaf: int in range(2):
		var start: Vector3 = stalk[2 + leaf]
		var side: float = -1.0 if leaf == 0 else 1.0
		var end: Vector3 = start + Vector3(side * 0.067, 0.027, 0.031)
		_append_understory_blade(vertices, normals, uvs, colors, start, start.lerp(end, 0.46) + Vector3(0, 0.038, 0), end, 0.022, side * 0.18, Color(0.31, 0.58, 0.26))
	var petals: int = 6 if variant == 0 else 5
	for petal: int in range(petals):
		var angle: float = TAU * float(petal) / float(petals) + float(variant) * 0.38
		var radial: Vector3 = Vector3(sin(angle), 0, cos(angle))
		var radius: float = (0.066 if variant == 0 else 0.050) * (1.0 + 0.09 * sin(float(petal) * 2.31))
		var start: Vector3 = center + radial * 0.014
		var end: Vector3 = center + radial * radius + Vector3(0, 0.010 + 0.010 * sin(angle + 0.8), 0)
		var bend: Vector3 = start.lerp(end, 0.48) + Vector3(0, -0.006, 0)
		_append_understory_blade(vertices, normals, uvs, colors, start, bend, end, 0.025 if variant == 0 else 0.020, 0.12 * sin(angle), Color.WHITE)
	for index: int in range(8):
		var a: float = TAU * float(index) / 8.0
		var b: float = TAU * float(index + 1) / 8.0
		var pa: Vector3 = center + Vector3(sin(a) * 0.019, 0.007, cos(a) * 0.019)
		var pb: Vector3 = center + Vector3(sin(b) * 0.019, 0.007, cos(b) * 0.019)
		_triangle(vertices, normals, uvs, colors, center + Vector3(0, 0.015, 0), pa, pb, Color(0.95, 0.71, 0.17))
	# One small asymmetric folded bud, not another full-size flower disc.
	var bud_start: Vector3 = stalk[3]
	var bud_end: Vector3 = bud_start + Vector3(-0.041, 0.027, 0.021)
	var bud_stalk: PackedVector3Array = PackedVector3Array([bud_start, bud_start.lerp(bud_end, 0.45) + Vector3(0, 0.014, 0), bud_end])
	_append_understory_stalk(vertices, normals, uvs, colors, bud_stalk, 0.0025, 0.0015, Color(0.25, 0.49, 0.22))
	for fold: int in range(3):
		var angle: float = TAU * float(fold) / 3.0
		var radial: Vector3 = Vector3(sin(angle), 0, cos(angle))
		_append_understory_blade(vertices, normals, uvs, colors, bud_end, bud_end + radial * 0.025 + Vector3(0, 0.014, 0), bud_end + radial * 0.007 + Vector3(0, 0.036, 0), 0.010, 0.05, Color(0.94, 0.97, 0.91))
	_understory_smooth_normals(vertices, normals)
	return _array_mesh(vertices, normals, uvs, colors)

func _understory_bezier(start: Vector3, control: Vector3, finish: Vector3, t: float) -> Vector3:
	return start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t

func _append_understory_blade(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, start: Vector3, control: Vector3, finish: Vector3, width: float, twist: float, color_value: Color) -> void:
	var first_vertex: int = vertices.size()
	var times: PackedFloat64Array = PackedFloat64Array([0.0, 0.17, 0.36, 0.57, 0.80, 1.0])
	var centers: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for t: float in times:
		var center: Vector3 = _understory_bezier(start, control, finish, t)
		var tangent: Vector3 = (control - start) * (2.0 * (1.0 - t)) + (finish - control) * (2.0 * t)
		tangent = tangent.normalized()
		var side: Vector3 = Vector3(tangent.z, 0, -tangent.x).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		side = side.rotated(tangent, twist * sin(t * PI))
		var up: Vector3 = tangent.cross(side).normalized()
		var shape: float = pow(maxf(0.0, sin(t * PI)), 0.78)
		if t < 0.22:
			shape *= 0.38
		var left_width: float = width * shape * (1.0 + 0.10 * sin(t * PI * 1.6))
		var right_width: float = width * shape * (0.86 + 0.10 * sin(t * PI * 1.3 + 0.8))
		centers.append(center + up * width * shape * 0.035)
		left.append(center + side * left_width + up * left_width * 0.14)
		right.append(center - side * right_width + up * right_width * 0.22)
	for index: int in range(5):
		var ca: Vector3 = centers[index]
		var cb: Vector3 = centers[index + 1]
		var ua: Vector2 = Vector2(0.5, float(times[index]))
		var ub: Vector2 = Vector2(0.5, float(times[index + 1]))
		var la: Vector2 = Vector2(0.0, float(times[index]))
		var lb: Vector2 = Vector2(0.0, float(times[index + 1]))
		var ra: Vector2 = Vector2(1.0, float(times[index]))
		var rb: Vector2 = Vector2(1.0, float(times[index + 1]))
		if index == 0:
			_triangle(vertices, normals, uvs, colors, ca, cb, left[index + 1], color_value, ua, ub, lb)
			_triangle(vertices, normals, uvs, colors, right[index + 1], cb, ca, color_value, rb, ub, ua)
		elif index == 4:
			_triangle(vertices, normals, uvs, colors, ca, cb, left[index], color_value, ua, ub, la)
			_triangle(vertices, normals, uvs, colors, right[index], cb, ca, color_value, ra, ub, ua)
		else:
			_quad(vertices, normals, uvs, colors, ca, cb, left[index + 1], left[index], color_value, ua, ub, lb, la)
			_quad(vertices, normals, uvs, colors, right[index], right[index + 1], cb, ca, color_value * Color(0.96, 0.99, 0.94), ra, rb, ub, ua)

	for index: int in range(first_vertex, vertices.size()):
		var t: float = clampf(uvs[index].y / 0.45, 0.0, 1.0)
		var shade: float = 0.72 + 0.28 * t * t * (3.0 - 2.0 * t)
		colors[index] = colors[index] * Color(shade, shade, shade, 1.0)

func _append_understory_stalk(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, path: PackedVector3Array, start_radius: float, end_radius: float, color_value: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	for index: int in range(path.size()):
		var before: Vector3 = path[maxi(0, index - 1)]
		var after: Vector3 = path[mini(path.size() - 1, index + 1)]
		var direction: Vector3 = (after - before).normalized()
		var side: Vector3 = direction.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		var other: Vector3 = side.cross(direction).normalized()
		var radius: float = lerpf(start_radius, end_radius, float(index) / float(path.size() - 1))
		var ring: PackedVector3Array = PackedVector3Array()
		for corner: int in range(4):
			var angle: float = TAU * float(corner) / 4.0
			var offset: Vector3 = (side * cos(angle) + other * sin(angle)) * radius
			if index == 0 and path[0].length_squared() < 0.000001:
				offset.y = 0.0
			ring.append(path[index] + offset)
		rings.append(ring)
	for index: int in range(path.size() - 1):
		for corner: int in range(4):
			var next: int = (corner + 1) % 4
			var t0: float = float(index) / float(path.size() - 1)
			var t1: float = float(index + 1) / float(path.size() - 1)
			var u0: float = float(corner) / 4.0
			var u1: float = float(corner + 1) / 4.0
			_quad(vertices, normals, uvs, colors, rings[index][corner], rings[index + 1][corner], rings[index + 1][next], rings[index][next], color_value, Vector2(u0, t0), Vector2(u0, t1), Vector2(u1, t1), Vector2(u1, t0))
	# Open ends attach to soil/leaf tissue; no collapsed pole or coincident fan.

func _understory_smooth_normals(vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
	var sums: Dictionary = {}
	for index: int in range(0, vertices.size(), 3):
		# Emitted buffers are Godot CW: outward normal uses c-a cross b-a.
		var face: Vector3 = (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index])
		for corner: int in range(3):
			var point: Vector3 = vertices[index + corner]
			var sum: Vector3 = sums.get(point, Vector3.ZERO) as Vector3
			sums[point] = sum + face
	for index: int in range(vertices.size()):
		var sum: Vector3 = sums[vertices[index]] as Vector3
		if sum.length_squared() > 0.000000000000000001:
			normals[index] = sum.normalized()

# Proposed rounded pocket blade; existing fern/flower blade builder remains unchanged.
func _append_understory_rounded_leaf(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, start: Vector3, control: Vector3, finish: Vector3, width: float, twist: float, color_value: Color) -> void:
	var first_vertex: int = vertices.size()
	var times: PackedFloat64Array = PackedFloat64Array([0.0, 0.16, 0.39, 0.64, 0.94, 1.0])
	var centers: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for t: float in times:
		var center: Vector3 = _understory_bezier(start, control, finish, t)
		var tangent: Vector3 = (control - start) * (2.0 * (1.0 - t)) + (finish - control) * (2.0 * t)
		tangent = tangent.normalized()
		var side: Vector3 = Vector3(tangent.z, 0, -tangent.x).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		side = side.rotated(tangent, twist * sin(t * PI))
		var up: Vector3 = tangent.cross(side).normalized()
		var shape: float = pow(maxf(0.0, sin(t * PI)), 0.50) if t < 1.0 else 0.0
		if t < 0.20:
			shape *= 0.70
		# Broad final shoulder at t=.94, then a short curled end rather than a long spear.
		var curl: float = width * 0.20 * pow(clampf((t - 0.68) / 0.32, 0.0, 1.0), 2.0)
		center += up * curl
		var left_width: float = width * shape * (1.0 + 0.10 * sin(t * PI * 1.6))
		var right_width: float = width * shape * (0.86 + 0.10 * sin(t * PI * 1.3 + 0.8))
		centers.append(center + up * width * shape * 0.035)
		left.append(center + side * left_width + up * left_width * 0.14)
		right.append(center - side * right_width + up * right_width * 0.22)
	for index: int in range(5):
		var ca: Vector3 = centers[index]
		var cb: Vector3 = centers[index + 1]
		var ua: Vector2 = Vector2(0.5, float(times[index]))
		var ub: Vector2 = Vector2(0.5, float(times[index + 1]))
		var la: Vector2 = Vector2(0.0, float(times[index]))
		var lb: Vector2 = Vector2(0.0, float(times[index + 1]))
		var ra: Vector2 = Vector2(1.0, float(times[index]))
		var rb: Vector2 = Vector2(1.0, float(times[index + 1]))
		if index == 0:
			_triangle(vertices, normals, uvs, colors, ca, cb, left[index + 1], color_value, ua, ub, lb)
			_triangle(vertices, normals, uvs, colors, right[index + 1], cb, ca, color_value, rb, ub, ua)
		elif index == 4:
			_triangle(vertices, normals, uvs, colors, ca, cb, left[index], color_value, ua, ub, la)
			_triangle(vertices, normals, uvs, colors, right[index], cb, ca, color_value, ra, ub, ua)
		else:
			_quad(vertices, normals, uvs, colors, ca, cb, left[index + 1], left[index], color_value, ua, ub, lb, la)
			_quad(vertices, normals, uvs, colors, right[index], right[index + 1], cb, ca, color_value * Color(0.96, 0.99, 0.94), ra, rb, ub, ua)

	for index: int in range(first_vertex, vertices.size()):
		var t: float = clampf(uvs[index].y / 0.45, 0.0, 1.0)
		var shade: float = 0.72 + 0.28 * t * t * (3.0 - 2.0 * t)
		colors[index] = colors[index] * Color(shade, shade, shade, 1.0)


# Proposed revision10 rooted foreground groups: existing resources, no RNG.
func _rooted_ground_support(point: Vector3) -> Dictionary:
	if _foreground_bank_original_faces.size() != 2 or point.x < -10.0 or point.x > 14.0 or point.z < 8.8 or point.z > 24.0:
		return {}
	var bank: Dictionary = _foreground_bank_support(point)
	if not bank.is_empty():
		return bank
	if point.x <= 7.8:
		return _foreground_bank_original_support(point, 0)
	if point.x >= 10.2:
		return _foreground_bank_original_support(point, 1)
	return {}

func _rooted_ground_stone_cache() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var terrain: Node3D = get_node_or_null("GroundAndPaths") as Node3D
	if terrain == null:
		return result
	for child: Node in terrain.get_children():
		var rock: MeshInstance3D = child as MeshInstance3D
		if rock == null or rock.mesh == null:
			continue
		var source_mesh: ArrayMesh = rock.mesh as ArrayMesh
		if source_mesh == null:
			continue
		var selected: bool = rock.has_meta("review08_sculpt_site")
		if not selected and rock.material_override != (_materials["stone"] as Material):
			continue
		var faces: PackedVector3Array = PackedVector3Array()
		var transform_value: Transform3D = global_transform.affine_inverse() * rock.global_transform
		for surface: int in range(source_mesh.get_surface_count()):
			if source_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = source_mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
				for index: int in indices:
					faces.append(transform_value * vertices[index])
			else:
				for vertex: Vector3 in vertices:
					faces.append(transform_value * vertex)
		if faces.is_empty():
			continue
		var bounds: AABB = AABB(faces[0], Vector3.ZERO)
		for point: Vector3 in faces:
			bounds = bounds.expand(point)
		if bounds.end.x < -10.0 or bounds.position.x > 14.0 or bounds.end.z < 8.8 or bounds.position.z > 24.0:
			continue
		result.append({"site": String(rock.get_meta("review08_sculpt_site", "")), "selected": selected, "bounds": bounds, "faces": faces, "origin": transform_value.origin})
	return result

func _rooted_ground_stone_top(point: Vector3, stones: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_y: float = -1000.0
	for stone: Dictionary in stones:
		var bounds: AABB = stone["bounds"] as AABB
		if point.x < bounds.position.x - 0.00001 or point.x > bounds.end.x + 0.00001 or point.z < bounds.position.z - 0.00001 or point.z > bounds.end.z + 0.00001:
			continue
		var faces: PackedVector3Array = stone["faces"] as PackedVector3Array
		for index: int in range(0, faces.size(), 3):
			var hit: Dictionary = _foreground_bank_triangle_support(point, faces[index], faces[index + 1], faces[index + 2], 0, false)
			if not hit.is_empty() and float(hit["height"]) > best_y:
				best_y = float(hit["height"])
				best = {"height": best_y, "site": stone["site"]}
	return best

func _rooted_group_samples(mesh: ArrayMesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var points: PackedVector3Array = PackedVector3Array()
	var unique: Dictionary = {}
	for index: int in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var samples: PackedVector3Array = PackedVector3Array([a, b, c, (a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5, (a + b + c) / 3.0])
		for point: Vector3 in samples:
			if not unique.has(point):
				unique[point] = true
				points.append(point)
	return points

func _rooted_group_guard(origin: Vector3, basis_value: Basis, reach: float, samples: PackedVector3Array, stones: Array[Dictionary]) -> String:
	# The .06m root footprint margin is a static proposal, not measured wind proof.
	if reach > 0.55 or not _ground_foliage_allowed(origin, reach + 0.06):
		return "protected_root_footprint"
	var root_stone: Dictionary = _rooted_ground_stone_top(origin, stones)
	if not root_stone.is_empty() and float(root_stone["height"]) > origin.y + 0.002:
		return "root_under_stone"
	for local_point: Vector3 in samples:
		var point: Vector3 = origin + basis_value * local_point
		if not point.is_finite():
			return "nonfinite"
		if Vector2(point.x - origin.x, point.z - origin.z).length() > reach + 0.000001:
			return "reach"
		if point.x < -10.0 or point.x > 14.0 or point.z < 8.8 or point.z > 24.0 or not _ground_foliage_allowed(point, 0.0):
			return "protected_sample"
		var support: Dictionary = _rooted_ground_support(point)
		if support.is_empty():
			return "missing_sample_support"
		if point.y < float(support["height"]) - 0.002:
			return "soil_penetration"
		var stone: Dictionary = _rooted_ground_stone_top(point, stones)
		if not stone.is_empty() and point.y < float(stone["height"]) - 0.002:
			return "stone_penetration"
	return ""

func _add_rooted_ground_instance(site: String, label: String, material_id: String, xz: Vector2, yaw: float, size_value: Vector3, tilt: Vector2, samples: PackedVector3Array, stones: Array[Dictionary]) -> Dictionary:
	var point: Vector3 = Vector3(xz.x, 0.0, xz.y)
	var record: Dictionary = {"accepted": false, "reason": "missing_root_support", "site": site, "label": label, "id": material_id, "origin": point, "turn": Vector3.ZERO, "scale": size_value, "reach": 0.0, "root_margin": 0.06, "shadow": label == "broadleaf_b", "orientation_retry": false}
	var support: Dictionary = _rooted_ground_support(point)
	if support.is_empty():
		return record
	point.y = float(support["height"])
	record["origin"] = point
	var up: Vector3 = support["normal"] as Vector3
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	forward = (forward - up * up.dot(forward)).normalized()
	var aligned: Basis = Basis(up.cross(forward).normalized(), up, forward)
	var turn: Vector3 = (aligned * Basis.from_euler(Vector3(tilt.x, 0.0, tilt.y))).get_euler()
	var basis_value: Basis = Basis.from_euler(turn).scaled(size_value)
	var reach: float = 0.0
	for sample: Vector3 in samples:
		var offset: Vector3 = basis_value * sample
		reach = maxf(reach, Vector2(offset.x, offset.z).length())
	var reason: String = _rooted_group_guard(point, basis_value, reach, samples, stones)
	if not reason.is_empty():
		# Retry only the orientation, at the identical canonical rooted origin/scale.
		record["orientation_retry"] = true
		turn = aligned.get_euler()
		basis_value = Basis.from_euler(turn).scaled(size_value)
		reach = 0.0
		for sample: Vector3 in samples:
			var offset: Vector3 = basis_value * sample
			reach = maxf(reach, Vector2(offset.x, offset.z).length())
		reason = _rooted_group_guard(point, basis_value, reach, samples, stones)
	record["turn"] = turn
	record["reach"] = reach
	record["reason"] = reason if not reason.is_empty() else "accepted"
	if reason.is_empty():
		var mesh: ArrayMesh = _foreground_understory_meshes[label] as ArrayMesh
		_add_foliage(material_id, mesh, point, turn, size_value)
		record["accepted"] = true
	return record

func _generate_rooted_ground_groups() -> void:
	_rooted_foreground_group_records.clear()
	_rooted_foreground_group_stats.clear()
	var stones: Array[Dictionary] = _rooted_ground_stone_cache()
	var sample_cache: Dictionary = {}
	for label: String in _foreground_understory_meshes.keys():
		sample_cache[label] = _rooted_group_samples(_foreground_understory_meshes[label] as ArrayMesh)
	var sites: Array[Dictionary] = []
	for stone: Dictionary in stones:
		if bool(stone["selected"]):
			sites.append(stone)
	for point: Vector2 in [Vector2(1.6, 11.2), Vector2(2.8, 14.9), Vector2(4.9, 16.2)]:
		sites.append({"site": "PathEdge_%d" % sites.size(), "selected": false, "origin": Vector3(point.x, 0.0, point.y)})
	var shadows: int = 0
	var accepted: int = 0
	var rejected: Dictionary = {}
	var accepted_labels: Dictionary = {}
	var site_counts: Dictionary = {}
	for site_index: int in range(sites.size()):
		var site: Dictionary = sites[site_index]
		var center: Vector3 = site["origin"] as Vector3
		var site_name: String = site["site"] as String
		var selected: bool = bool(site["selected"])
		var hero: bool = site_name == "HeroLandwardShoulder"
		var attempts: int = 72 if hero else (48 if selected else 70)
		var accepted_site: int = 0
		for index: int in range(attempts):
			if _rooted_foreground_group_records.size() >= 474:
				break
			var phase: float = float(index) * 1.917 + float(site_index) * 2.31
			var xz: Vector2 = Vector2.ZERO
			if selected:
				var per_band: int = 24 if hero else 16
				var band: int = int(index / per_band)
				var along: int = index % per_band
				var angle: float = (TAU * (float(along) + 0.35) / float(per_band)) if hero else (-PI + PI * (float(along) + 0.35) / float(per_band))
				angle += float(band) * 0.13 + sin(phase) * 0.065
				var bounds: AABB = site["bounds"] as AABB
				var radii: Vector2 = Vector2(bounds.size.x, bounds.size.z) * 0.5 + Vector2.ONE * (0.08 + float(band) * 0.17)
				xz = Vector2(center.x, center.z) + Vector2(sin(angle) * radii.x, cos(angle) * radii.y)
			else:
				var angle: float = float(index) * 2.399963229728653 + float(site_index) * 0.61
				var radius: float = sqrt((float(index) + 0.45) / float(attempts))
				xz = Vector2(center.x, center.z) + Vector2(sin(angle) * 1.10, cos(angle) * 0.78) * radius
				xz += Vector2(sin(phase * 1.7), cos(phase * 0.9)) * 0.085
			var suffix: String = "a" if (index + site_index) % 2 == 0 else "b"
			var label: String = ""
			var material_id: String = "leaf"
			var scale_value: float = 1.0
			if index % 13 == 0:
				label = "flower_" + suffix
				material_id = "flower_pink" if index % 3 == 0 else "flower_white"
				scale_value = 0.68 + 0.20 * (0.5 + 0.5 * sin(phase))
			elif index % 6 == 0:
				label = "fern_" + suffix
				material_id = "leaf_dark"
				scale_value = 0.80 + 0.33 * (0.5 + 0.5 * sin(phase))
			elif index % 3 == 0:
				label = "cushion_" + suffix
				material_id = "leaf_dark" if index % 7 == 0 else "leaf"
				scale_value = 1.02 + 0.58 * (0.5 + 0.5 * sin(phase))
			else:
				label = "broadleaf_b" if (index + site_index) % 9 == 0 and shadows < 24 else "broadleaf_a"
				material_id = "leaf_gold" if index % 7 == 0 else ("leaf_dark" if index % 4 == 0 else "leaf")
				scale_value = 0.87 + 0.46 * (0.5 + 0.5 * sin(phase))
			var anisotropic: Vector3 = Vector3(scale_value * (0.94 + 0.08 * sin(phase * 1.2)), scale_value * (0.90 + 0.16 * cos(phase * 0.8)), scale_value * (1.03 + 0.06 * cos(phase * 1.1)))
			var tilt: Vector2 = Vector2(sin(phase * 1.4), cos(phase * 0.7)) * 0.085
			var samples: PackedVector3Array = sample_cache[label] as PackedVector3Array
			var record: Dictionary = _add_rooted_ground_instance(site_name, label, material_id, xz, phase * 0.73, anisotropic, tilt, samples, stones)
			record["attempt_index"] = _rooted_foreground_group_records.size()
			_rooted_foreground_group_records.append(record)
			if bool(record["accepted"]):
				accepted += 1
				accepted_site += 1
				accepted_labels[label] = int(accepted_labels.get(label, 0)) + 1
				if bool(record["shadow"]):
					shadows += 1
			else:
				var reason: String = record["reason"] as String
				rejected[reason] = int(rejected.get(reason, 0)) + 1
		site_counts[site_name] = {"attempts": attempts, "accepted": accepted_site}
	_rooted_foreground_group_stats = {"attempts": _rooted_foreground_group_records.size(), "accepted": accepted, "rejected": rejected, "accepted_labels": accepted_labels, "sites": site_counts, "shadow_instances": shadows, "maximum_attempts": 474, "maximum_shadow_instances": 24, "root_margin": 0.06, "sample_penetration_tolerance": 0.002}

# Rooted-group bake v2: fixed authored input, validated in full before any append.
# Changing placement/protection rules requires a new authoring_revision and bake.
const _ROOTED_GROUPS_BAKE_PATH: String = "res://assets/world/rooted_foreground_groups_baked_v2.json"
const _ROOTED_GROUPS_BAKE_LIMIT: int = 131072
const _ROOTED_GROUPS_BAKE_SHA: String = "1f3db84e38cbcc97eb6a8314af4d013c42d3d2b053f597b386db02a85cbf1f12"
const _ROOTED_GROUPS_AUTHORING_REVISION: String = "rooted-groups-01-v1"
const _ROOTED_GROUPS_CODEC_REVISION: String = "json-f32-and-zero-signs-v2"
const _ROOTED_GROUPS_LABELS: Array[String] = ["cushion_a", "cushion_b", "broadleaf_a", "broadleaf_b", "fern_a", "fern_b", "flower_a", "flower_b"]
const _ROOTED_GROUPS_IDS: Array[String] = ["leaf", "leaf_dark", "leaf_gold", "flower_pink", "flower_white"]
const _ROOTED_GROUPS_SITES: Array[String] = ["WestShoreline_54", "WestShoreline_56", "WestShoreline_58", "WestShoreline_60", "HeroLandwardShoulder", "PathEdge_5", "PathEdge_6", "PathEdge_7"]
const _ROOTED_GROUPS_REASONS: Array[String] = ["accepted", "missing_root_support", "protected_root_footprint", "root_under_stone", "nonfinite", "reach", "protected_sample", "missing_sample_support", "soil_penetration", "stone_penetration"]

func _rooted_groups_fingerprint() -> String:
	# Packed actual inputs; this is a Godot-authored fingerprint, not a neutral codec.
	var libraries: Array = []
	for label: String in _ROOTED_GROUPS_LABELS:
		var mesh: ArrayMesh = _foreground_understory_meshes.get(label) as ArrayMesh
		if mesh == null:
			return ""
		var surfaces: Array = []
		for surface: int in range(mesh.get_surface_count()):
			surfaces.append([mesh.surface_get_primitive_type(surface), mesh.surface_get_format(surface), mesh.surface_get_arrays(surface)])
		libraries.append([label, surfaces, bool(mesh.get_meta("review09_understory_shadow", false))])
	var stones: Array = []
	for stone: Dictionary in _rooted_ground_stone_cache():
		stones.append([stone["site"], stone["selected"], stone["bounds"], stone["faces"], stone["origin"]])
	var data: PackedByteArray = var_to_bytes([_ROOTED_GROUPS_AUTHORING_REVISION, _foreground_bank_original_faces, _foreground_bank_top_faces, libraries, stones])
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if not data.is_empty() and context.update(data) != OK:
		return ""
	return context.finish().hex_encode()

func _rooted_groups_numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _rooted_groups_integer(value: Variant, low: int, high: int) -> bool:
	return _rooted_groups_numeric(value) and float(value) == floor(float(value)) and float(value) >= float(low) and float(value) <= float(high)

func _rooted_groups_vector(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != 3:
		return false
	for component: Variant in value:
		if not _rooted_groups_numeric(component) or absf(float(component)) > 1000.0:
			return false
	return true

func _rooted_groups_stats_from_records(records: Array[Dictionary]) -> Dictionary:
	var accepted: int = 0
	var shadows: int = 0
	var rejected: Dictionary = {}
	var labels: Dictionary = {}
	var sites: Dictionary = {}
	for record: Dictionary in records:
		var site: String = record["site"] as String
		if not sites.has(site):
			sites[site] = {"attempts": 0, "accepted": 0}
		var site_count: Dictionary = sites[site] as Dictionary
		site_count["attempts"] = int(site_count["attempts"]) + 1
		if bool(record["accepted"]):
			accepted += 1
			site_count["accepted"] = int(site_count["accepted"]) + 1
			var label: String = record["label"] as String
			labels[label] = int(labels.get(label, 0)) + 1
			if bool(record["shadow"]):
				shadows += 1
		else:
			var reason: String = record["reason"] as String
			rejected[reason] = int(rejected.get(reason, 0)) + 1
	return {"attempts": records.size(), "accepted": accepted, "rejected": rejected, "accepted_labels": labels, "sites": sites, "shadow_instances": shadows, "maximum_attempts": 474, "maximum_shadow_instances": 24, "root_margin": 0.06, "sample_penetration_tolerance": 0.002}

func _rooted_groups_normalize_stats(value: Variant) -> Variant:
	# JSON has one number type. Counts are restored strictly; no tolerance widening.
	if not value is Dictionary:
		return null
	var source: Dictionary = value as Dictionary
	var required: Array[String] = ["attempts", "accepted", "rejected", "accepted_labels", "sites", "shadow_instances", "maximum_attempts", "maximum_shadow_instances", "root_margin", "sample_penetration_tolerance"]
	if source.size() != required.size():
		return null
	for key: String in required:
		if not source.has(key):
			return null
	var result: Dictionary = {}
	for key: String in ["attempts", "accepted", "shadow_instances", "maximum_attempts", "maximum_shadow_instances"]:
		if not _rooted_groups_integer(source[key], 0, 474):
			return null
		result[key] = int(source[key])
	for key: String in ["rejected", "accepted_labels"]:
		if not source[key] is Dictionary:
			return null
		var counts: Dictionary = {}
		for name: Variant in source[key]:
			if not name is String or not _rooted_groups_integer(source[key][name], 1, 474):
				return null
			counts[name] = int(source[key][name])
		result[key] = counts
	if not source["sites"] is Dictionary:
		return null
	var sites: Dictionary = {}
	for site: Variant in source["sites"]:
		var counts: Variant = source["sites"][site]
		if not site is String or not counts is Dictionary or (counts as Dictionary).size() != 2 or not counts.has("attempts") or not counts.has("accepted"):
			return null
		if not _rooted_groups_integer(counts["attempts"], 0, 474) or not _rooted_groups_integer(counts["accepted"], 0, 474):
			return null
		sites[site] = {"attempts": int(counts["attempts"]), "accepted": int(counts["accepted"])}
	result["sites"] = sites
	for key: String in ["root_margin", "sample_penetration_tolerance"]:
		if not _rooted_groups_numeric(source[key]):
			return null
		result[key] = float(source[key])
	return result

func _rooted_groups_zero_mask(origin: Vector3, turn: Vector3, size_value: Vector3) -> int:
	# Explicit IEEE754 sign-of-zero bits; ordinary numeric JSON stays readable.
	var packed: PackedByteArray = PackedVector3Array([origin, turn, size_value]).to_byte_array()
	var mask: int = 0
	for component: int in range(9):
		if packed.decode_u32(component * 4) == 0x80000000:
			mask |= 1 << component
	return mask

func _rooted_groups_restore_zero_vector(value: Vector3, mask: int, start: int) -> Vector3:
	var negative_zero: float = PackedByteArray([0, 0, 0, 128]).decode_float(0)
	for component: int in range(3):
		if (mask & (1 << (start + component))) != 0:
			value[component] = negative_zero
	return value

func _rooted_groups_bake_document() -> Dictionary:
	var rows: Array = []
	for record: Dictionary in _rooted_foreground_group_records:
		var origin: Vector3 = record["origin"] as Vector3
		var turn: Vector3 = record["turn"] as Vector3
		var size_value: Vector3 = record["scale"] as Vector3
		rows.append([record["accepted"], _ROOTED_GROUPS_REASONS.find(record["reason"]), _ROOTED_GROUPS_SITES.find(record["site"]), _ROOTED_GROUPS_LABELS.find(record["label"]), _ROOTED_GROUPS_IDS.find(record["id"]), [origin.x, origin.y, origin.z], [turn.x, turn.y, turn.z], [size_value.x, size_value.y, size_value.z], record["reach"], record["shadow"], record["orientation_retry"], _rooted_groups_zero_mask(origin, turn, size_value)])
	return {"schema": "rooted-foreground-groups-v2", "authoring_revision": _ROOTED_GROUPS_AUTHORING_REVISION, "codec_revision": _ROOTED_GROUPS_CODEC_REVISION, "fingerprint": _rooted_groups_fingerprint(), "tables": {"reasons": _ROOTED_GROUPS_REASONS, "sites": _ROOTED_GROUPS_SITES, "labels": _ROOTED_GROUPS_LABELS, "materials": _ROOTED_GROUPS_IDS}, "rows": rows, "stats": _rooted_foreground_group_stats, "coordinate_system": "Godot metres, X right, Y up, Z toward comparison camera; turn is Godot Euler YXZ"}

func _rooted_groups_decode_bake(document: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false, "error": "bake schema/header differs"}
	var expected_keys: Array[String] = ["schema", "authoring_revision", "codec_revision", "fingerprint", "tables", "rows", "stats", "coordinate_system"]
	if document.size() != expected_keys.size():
		return failed
	for key: String in expected_keys:
		if not document.has(key):
			return failed
	if document["schema"] != "rooted-foreground-groups-v2" or document["authoring_revision"] != _ROOTED_GROUPS_AUTHORING_REVISION or document["codec_revision"] != _ROOTED_GROUPS_CODEC_REVISION:
		return failed
	if document["coordinate_system"] != "Godot metres, X right, Y up, Z toward comparison camera; turn is Godot Euler YXZ":
		return failed
	var fingerprint: String = _rooted_groups_fingerprint()
	if fingerprint.is_empty() or not document["fingerprint"] is String or document["fingerprint"] != fingerprint:
		return {"ok": false, "error": "actual support/library/stone fingerprint differs"}
	if not document["tables"] is Dictionary or (document["tables"] as Dictionary).size() != 4:
		return failed
	var tables: Dictionary = document["tables"] as Dictionary
	for pair: Array in [["reasons", _ROOTED_GROUPS_REASONS], ["sites", _ROOTED_GROUPS_SITES], ["labels", _ROOTED_GROUPS_LABELS], ["materials", _ROOTED_GROUPS_IDS]]:
		if not tables.has(pair[0]) or not tables[pair[0]] is Array or tables[pair[0]] != pair[1]:
			return failed
	if not document["rows"] is Array or (document["rows"] as Array).size() != 474:
		return {"ok": false, "error": "bake must preserve all 474 authoring attempts"}
	var records: Array[Dictionary] = []
	for row_value: Variant in document["rows"]:
		if not row_value is Array or (row_value as Array).size() != 12:
			return {"ok": false, "error": "bake row cardinality differs"}
		var row: Array = row_value as Array
		if not row[0] is bool or not row[9] is bool or not row[10] is bool:
			return {"ok": false, "error": "bake boolean type differs"}
		if not _rooted_groups_integer(row[1], 0, _ROOTED_GROUPS_REASONS.size() - 1) or not _rooted_groups_integer(row[2], 0, _ROOTED_GROUPS_SITES.size() - 1) or not _rooted_groups_integer(row[3], 0, _ROOTED_GROUPS_LABELS.size() - 1) or not _rooted_groups_integer(row[4], 0, _ROOTED_GROUPS_IDS.size() - 1):
			return {"ok": false, "error": "bake identifier differs"}
		if not _rooted_groups_vector(row[5]) or not _rooted_groups_vector(row[6]) or not _rooted_groups_vector(row[7]) or not _rooted_groups_numeric(row[8]) or float(row[8]) < 0.0 or float(row[8]) > 0.55:
			return {"ok": false, "error": "bake pose/reach invalid"}
		if not _rooted_groups_integer(row[11], 0, 511):
			return {"ok": false, "error": "bake zero-sign mask invalid"}
		var zero_mask: int = int(row[11])
		for vector_index: int in range(3):
			for component: int in range(3):
				if (zero_mask & (1 << (vector_index * 3 + component))) != 0 and float(row[5 + vector_index][component]) != 0.0:
					return {"ok": false, "error": "bake zero-sign bit set on nonzero component"}
		var origin: Vector3 = Vector3(float(row[5][0]), float(row[5][1]), float(row[5][2]))
		var turn: Vector3 = Vector3(float(row[6][0]), float(row[6][1]), float(row[6][2]))
		var size_value: Vector3 = Vector3(float(row[7][0]), float(row[7][1]), float(row[7][2]))
		origin = _rooted_groups_restore_zero_vector(origin, zero_mask, 0)
		turn = _rooted_groups_restore_zero_vector(turn, zero_mask, 3)
		size_value = _rooted_groups_restore_zero_vector(size_value, zero_mask, 6)
		# Producer reach is Vector2.length/maxf over float32 offsets. Restore that
		# declared precision exactly; do not accept an equality tolerance.
		var reach_value: float = PackedFloat32Array([float(row[8])])[0]
		if not origin.is_finite() or not turn.is_finite() or not size_value.is_finite() or size_value.x <= 0.0 or size_value.y <= 0.0 or size_value.z <= 0.0 or size_value.x > 3.0 or size_value.y > 3.0 or size_value.z > 3.0:
			return {"ok": false, "error": "bake finite/positive pose guard differs"}
		var reason: String = _ROOTED_GROUPS_REASONS[int(row[1])]
		var label: String = _ROOTED_GROUPS_LABELS[int(row[3])]
		var material_id: String = _ROOTED_GROUPS_IDS[int(row[4])]
		if bool(row[0]) != (reason == "accepted") or bool(row[9]) != (label == "broadleaf_b") or not _materials.has(material_id) or not _foreground_understory_meshes.has(label):
			return {"ok": false, "error": "bake acceptance/resource semantics differ"}
		# This inexpensive root-domain gate supplements the matching authored fingerprint.
		if bool(row[0]) and (origin.x < -10.0 or origin.x > 14.0 or origin.z < 8.8 or origin.z > 24.0 or not _ground_foliage_allowed(origin, reach_value + 0.06)):
			return {"ok": false, "error": "bake accepted root protection differs"}
		records.append({"accepted": bool(row[0]), "reason": reason, "site": _ROOTED_GROUPS_SITES[int(row[2])], "label": label, "id": material_id, "origin": origin, "turn": turn, "scale": size_value, "reach": reach_value, "root_margin": 0.06, "shadow": bool(row[9]), "orientation_retry": bool(row[10]), "attempt_index": records.size()})
	var stats: Dictionary = _rooted_groups_stats_from_records(records)
	var normalized_stats: Variant = _rooted_groups_normalize_stats(document["stats"])
	if not normalized_stats is Dictionary or normalized_stats != stats or int(stats["shadow_instances"]) > 24 or (stats["sites"] as Dictionary).size() != 8:
		return {"ok": false, "error": "bake statistics/limits differ from ordered attempts"}
	return {"ok": true, "error": "", "records": records, "stats": stats, "fingerprint": fingerprint}

func _create_rooted_ground_groups() -> void:
	var reason: String = "authoring mode requested"
	if not bool(get_meta("portable_export", false)) and not bool(get_meta("rooted_groups_authoring", false)):
		reason = "bake asset missing"
		if FileAccess.file_exists(_ROOTED_GROUPS_BAKE_PATH):
			var file: FileAccess = FileAccess.open(_ROOTED_GROUPS_BAKE_PATH, FileAccess.READ)
			if file == null:
				reason = "bake asset unreadable"
			elif file.get_length() <= 0 or file.get_length() >= _ROOTED_GROUPS_BAKE_LIMIT:
				reason = "bake asset size outside bound"
				file.close()
			else:
				var text: String = file.get_as_text()
				file.close()
				if text.sha256_text() != _ROOTED_GROUPS_BAKE_SHA:
					reason = "bake asset differs from exact authored payload SHA"
				else:
					var json: JSON = JSON.new()
					if json.parse(text) != OK or not json.data is Dictionary:
						reason = "bake asset JSON invalid"
					else:
						var decoded: Dictionary = _rooted_groups_decode_bake(json.data as Dictionary)
						if bool(decoded["ok"]):
							var records: Array[Dictionary] = decoded["records"] as Array[Dictionary]
							# All rows and totals have passed before the first append.
							for record: Dictionary in records:
								if bool(record["accepted"]):
									_add_foliage(record["id"] as String, _foreground_understory_meshes[record["label"]] as ArrayMesh, record["origin"] as Vector3, record["turn"] as Vector3, record["scale"] as Vector3)
							_rooted_foreground_group_records = records
							_rooted_foreground_group_stats = decoded["stats"] as Dictionary
							_rooted_foreground_group_load_status = {"mode": "baked", "reason": "all authored rows validated before replay", "fingerprint": decoded["fingerprint"]}
							return
							reason = decoded["error"] as String
	# Optional bake failure always executes the complete original routine once.
	_generate_rooted_ground_groups()
	_rooted_foreground_group_load_status = {"mode": "generated", "reason": reason, "fingerprint": ""}
