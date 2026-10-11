extends Node
## Coordinates existing visual effects. Never applies gameplay forces or writes
## native mesh arrays, MultiMesh transforms, collision shapes or save state.
const MAX_STEP: float = 0.25
const CANOPY_BOUND: float = 0.025
const GROUND_BOUND: float = 0.020
# This raw source is the inherited deterministic geometry constructor. It is
# instantiated off-tree; _ready/generation, live nodes and collision never run.
const GROUND_FACTORY_SOURCE: String = "res://lineage/scenery-revision-16/proposals/cap-rim-gills-03/detached-world.gd"
const GROUND_FACTORY_SHA256: String = "a758c4d69479fd3ea445efb2fac1a4bd3f0b25ff337b8a76faed0b1516d6afc1"
const GROUND_MATERIAL_SHADERS: Array[String] = ["res://assets/world/foliage.gdshader","res://assets/world/tactile.gdshader"]
var world: Node3D
var player: CharacterBody3D
var game: Node
var quality: String = "balanced"
var reduced_motion: bool = false
var foreground: bool = true
var clock_seconds: float = 0.0
var detail_clock_seconds: float = 0.0
var wind_direction: Vector3 = Vector3(0.924,0.0,0.382).normalized()
var wind_strength: float = 0.24
var cloud_offset: Vector3 = Vector3.ZERO
var wetness: float = 0.0
var inspection_state: String = "calm"
var _sunset: float = 0.0
var _sunset_target: float = 0.0
var _configured: bool = false
var _shutting_down: bool = false
var _materials: Array[Dictionary] = []
var _particles: Array[GPUParticles3D] = []
var _bounds: Array[Dictionary] = []
var _runtime_flora: Array[Dictionary] = []
var _scan_count: int = 0
var _ground_templates: Array[Dictionary] = []
var _ground_matches: Dictionary = {}
# Ordinary material uniforms avoid GLES16-slot-per-geometry instance allocation.
# One shallow variant per actual source-material/root plane, never one per node.
const MAX_GROUND_MATERIAL_VARIANTS: int = 32
var _ground_material_variants: Dictionary = {}
var _ground_factory_proof: Dictionary = {}
var _ground_factory_attempted: bool = false
var _ground_match_scans: int = 0
var _next_refresh: float = 0.0
var _applied_wind_strength: float = 0.0
var _rain_audio: AudioStreamPlayer
var _noise_state: int = 5757
var _noise_lowpass: float = 0.0
# Audio stays within the retained forest WAV and this one filtered-noise stream.
# Native water source is admitted once at startup; no per-frame scene/hash scan.
const WATER_AUDIO_SHADER: String = "res://lineage/scenery-revision-17/proposals/water-rock-01/stream-water-01.gdshader"
var _water_audio_node: MeshInstance3D
var _water_audio_bounds: AABB
var _water_audio_proof: Dictionary = {}
var _water_audio_proximity: float = 0.0

func configure(selected_world: Node3D,selected_player: CharacterBody3D,selected_game: Node=null) -> void:
	world = selected_world
	player = selected_player
	game = selected_game
	_configured = is_instance_valid(world) and is_instance_valid(player)
	if is_instance_valid(game) and game.has_signal("mobile_release_requested"):
		if not game.is_connected("mobile_release_requested",_on_mobile_release):
			game.connect("mobile_release_requested",_on_mobile_release)
		foreground = not bool(game.get("_mobile_suspended"))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	refresh_bindings()
	if is_instance_valid(game):
		_cache_water_audio_source()
		_create_rain_audio()
	set_foreground(foreground)

func _on_mobile_release(reason: String) -> void:
	if reason=="suspend": set_foreground(false)
	elif reason=="resume": set_foreground(true)

func set_quality(value: String) -> void:
	if value in ["low","balanced","high"]: quality = value
	_apply_density()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if is_instance_valid(world) and world.has_method("set_living_motion_reduced"):
		world.call("set_living_motion_reduced",value)

func set_foreground(value: bool) -> void:
	if _shutting_down and value: return
	foreground = value
	if is_instance_valid(world) and world.has_method("set_environment_foreground"):
		world.call("set_environment_foreground",value)
	_freeze_particles(not foreground or get_tree().paused)
	_set_environment_audio_paused(not foreground or get_tree().paused)

func set_inspection_state(value: String) -> void:
	if not value in ["calm","gust","sunrise","sunset","night","rain","indoor","dense"]: return
	inspection_state = value
	_sunset_target = 1.0 if value in ["sunrise","sunset"] else 0.0
	# Inspection only selects existing appearance through its ordinary world API;
	# the caller owns camera/player placement and persistent game sky/weather.
	if is_instance_valid(world) and world.has_method("set_appearance"):
		world.call("set_appearance",value=="night",value=="rain",bool(world.get("_reduced_effects")))

func _process(delta: float) -> void:
	if _shutting_down or not _configured or not is_finite(delta) or delta<0.0: return
	# Settings must reconcile while paused; only accumulated visual motion freezes.
	_reconcile_particle_emission()
	var stopped: bool = not foreground or get_tree().paused
	_freeze_particles(stopped)
	_set_environment_audio_paused(stopped)
	# Gain/settings reconcile during pause without advancing the noise generator.
	var rain: float = clampf(float(world.get("rain_amount")),0.0,1.0)
	if stopped: _reconcile_environment_audio_gain(rain)
	if stopped:
		# Foreground menus may blend an explicitly chosen appearance while all
		# environmental accumulated coordinates/forces stay frozen. Background
		# freezes appearance too. Reapply only selected central lighting values.
		if foreground and get_tree().paused:
			_sync_ground_material_variants()
			_apply_lighting(clampf(float(world.get("rain_amount")),0.0,1.0))
		return
	var step: float = minf(delta,MAX_STEP)
	clock_seconds += step
	var target_strength: float = 0.72 if inspection_state=="gust" else lerpf(0.24,0.56,rain)
	wind_strength = move_toward(wind_strength,target_strength,step*0.18)
	# Gradual shared gust; the shader adds small spatial phase/stiffness differences.
	var gust: float = 0.78+0.14*sin(clock_seconds*0.37)+0.08*sin(clock_seconds*0.73+1.2)
	var strength: float = clampf(wind_strength*gust,0.0,1.0)
	var scale: float = 0.15 if reduced_motion else 1.0
	detail_clock_seconds += step*scale
	_applied_wind_strength = strength*scale
	cloud_offset += wind_direction*step*0.013*strength*scale
	wetness = move_toward(wetness,rain,step*(0.06 if rain>wetness else 0.015))
	_sunset = move_toward(_sunset,_sunset_target,step*0.4)
	if clock_seconds>=_next_refresh:
		refresh_bindings()
		_next_refresh = clock_seconds+2.0
	_sync_ground_material_variants()
	var actor: Vector3 = player.global_position
	for row: Dictionary in _materials:
		var material: ShaderMaterial = row.material
		if not is_instance_valid(material): continue
		_set_environment_uniform(row,"env_enabled",true)
		_set_environment_uniform(row,"env_time",clock_seconds)
		_set_environment_uniform(row,"env_detail_time",detail_clock_seconds)
		_set_environment_uniform(row,"env_wind_direction",wind_direction)
		_set_environment_uniform(row,"env_wind_strength",strength*scale)
		_set_environment_uniform(row,"env_cloud_offset",cloud_offset)
		_set_environment_uniform(row,"env_cloud_shadow",(0.10 if quality!="low" else 0.055)*(1.0-float(world.get("night_amount"))))
		_set_environment_uniform(row,"env_wetness",wetness)
		_set_environment_uniform(row,"env_player_position",actor)
		_set_environment_uniform(row,"env_player_bend",0.35*scale if quality!="low" else 0.15*scale)
		_set_environment_uniform(row,"env_motion_scale",scale)
		_set_environment_uniform(row,"env_room_enabled",bool(world.get("_room_ready")))
		_set_environment_uniform(row,"env_ripple_strength",scale*(0.5 if quality!="low" else 0.2))
	_apply_lighting(rain)
	_apply_density()
	_apply_runtime_flora(strength*scale)
	if player.has_method("apply_environment_wind"):
		player.call("apply_environment_wind",wind_direction,strength,clock_seconds,scale)
	_update_rain_audio(rain)

func refresh_bindings() -> void:
	if not _configured: return
	_scan_count += 1
	var seen: Dictionary = {}
	for row: Dictionary in _materials: seen[row.material.get_instance_id()] = true
	# Startup and at most once per two active seconds catches newly planted meshes
	# and living-motion material forks. No per-frame scene gather/native hashing.
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		if node is GPUParticles3D:
			if not _particles.has(node): _particles.append(node)
			_bind_material(node.process_material as ShaderMaterial,seen)
			continue
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		_bind_material(geometry.material_override as ShaderMaterial,seen)
		# Frozen state omits raw constructor fields. Admit an actual native mesh
		# only after all13 channels/metadata exactly match a known root source.
		if node is MultiMeshInstance3D and node.multimesh!=null:
			var foliage_material: ShaderMaterial = geometry.material_override as ShaderMaterial
			if foliage_material!=null and foliage_material.shader!=null and foliage_material.shader.resource_path in GROUND_MATERIAL_SHADERS:
				var match: Dictionary = _ground_match(node.multimesh.mesh)
				if match.get("passed",false) and not geometry.has_meta("mobile_environment_cull"):
					var admitted: bool = node.multimesh.instance_count>0 and node.multimesh.transform_format==MultiMesh.TRANSFORM_3D
					var lower: float = 1.0
					for i: int in range(node.multimesh.instance_count):
						var basis: Basis = geometry.global_basis*node.multimesh.get_instance_transform(i).basis
						if not basis.is_finite() or absf(basis.determinant())<0.000001:
							admitted = false
							break
						var inverse: Basis = basis.inverse()
						var norm: float = sqrt(inverse.x.length_squared()+inverse.y.length_squared()+inverse.z.length_squared())
						lower = minf(lower,1.0-1.2*GROUND_BOUND*norm)
					admitted = admitted and is_finite(lower) and lower>0.5
					geometry.set_meta("mobile_environment_cull",true)
					var row: Dictionary = {"node":geometry,"motion_admitted":admitted,"jacobian_lower_bound":lower,"world_bound_m":GROUND_BOUND if admitted else 0.0,"family":match.family,"native_mesh_id":str(node.multimesh.mesh.get_instance_id()),"native_channels_exact":match.channels_exact,"native_metadata_exact":match.metadata_exact,"native_format":match.format,"native_primitive":match.primitive,"native_aabb":node.multimesh.mesh.get_aabb(),"native_channels_sha256":match.channels_sha256,"root_y":match.root_y,"native_root_corners":match.root_corners,"native_vertex_count":match.vertex_count,"source_root_plane_exact":match.root_plane_exact,"shader":foliage_material.shader.resource_path,"instances":node.multimesh.instance_count}
					if admitted:
						var inverse_basis: Basis = geometry.global_basis.inverse()
						var margin: float = GROUND_BOUND*sqrt(inverse_basis.x.length_squared()+inverse_basis.y.length_squared()+inverse_basis.z.length_squared())
						var old: float = geometry.extra_cull_margin
						# Round upward in native FP32 before assignment/readback.
						var requested: float = old+margin
						var stored: PackedByteArray = PackedFloat32Array([requested]).to_byte_array()
						var selected: float = stored.decode_float(0)
						if selected<requested:
							stored.encode_u32(0,stored.decode_u32(0)+1)
							selected = stored.decode_float(0)
						geometry.extra_cull_margin = selected
						row["before"] = old
						row["after"] = geometry.extra_cull_margin
						row["added_local_margin"] = margin
						row["cull_readback_exact"] = var_to_bytes(geometry.extra_cull_margin)==var_to_bytes(selected) and float(geometry.extra_cull_margin)>=requested
						admitted = admitted and row.cull_readback_exact

					var selected_material: ShaderMaterial = _ground_material_variant(foliage_material,float(match.root_y)) if admitted else null
					admitted = admitted and selected_material!=null
					if admitted:
						geometry.material_override = selected_material
						_bind_material(selected_material,seen)
					row["motion_admitted"] = admitted
					row["world_bound_m"] = GROUND_BOUND if admitted else 0.0
					row["parameter_storage"] = "ordinary cached ShaderMaterial variant; no instance uniforms"
					row["original_material_id"] = str(foliage_material.get_instance_id())
					row["selected_material_id"] = str(selected_material.get_instance_id()) if admitted else str(foliage_material.get_instance_id())
					row["anchor_readback_exact"] = admitted and geometry.material_override==selected_material and var_to_bytes(selected_material.get_shader_parameter("env_anchor_enabled"))==var_to_bytes(1.0) and var_to_bytes(selected_material.get_shader_parameter("env_root_y"))==var_to_bytes(float(match.root_y))
					if admitted and not row.anchor_readback_exact:
						geometry.material_override = foliage_material
						row["motion_admitted"] = false
						row["world_bound_m"] = 0.0
					_bounds.append(row)
	_bind_material(world.get("_cloud_sky_material") as ShaderMaterial,seen)
	if is_instance_valid(game):
		var flora: Variant = game.get("patch_flora")
		if flora is Array:
			for plant: Node3D in flora:
				if not plant.has_meta("mobile_environment_visual_root"):
					plant.set_meta("mobile_environment_visual_root",true)
					_runtime_flora.append({"node":plant,"rest_rotation":plant.rotation})

func _ground_material_variant(original: ShaderMaterial,root_y: float) -> ShaderMaterial:
	var key: String = str(original.get_instance_id())+":"+var_to_bytes(root_y).hex_encode()
	if _ground_material_variants.has(key): return _ground_material_variants[key].selected as ShaderMaterial
	if _ground_material_variants.size()>=MAX_GROUND_MATERIAL_VARIANTS: return null
	# Static users keep the same original material resource with root motion off.
	original.set_shader_parameter("env_anchor_enabled",0.0)
	original.set_shader_parameter("env_root_y",0.0)
	var selected: ShaderMaterial = original.duplicate(false) as ShaderMaterial
	if selected==null or selected.shader!=original.shader or selected.next_pass!=original.next_pass or selected.render_priority!=original.render_priority: return null
	var parameters: Array[String] = []
	for uniform: Dictionary in original.shader.get_shader_uniform_list():
		var name: String = str(uniform.name)
		if not name.begins_with("env_"):
			parameters.append(name)
			var value: Variant = original.get_shader_parameter(name)
			var copied: Variant = selected.get_shader_parameter(name)
			if value is Object:
				if value!=copied: return null
			elif var_to_bytes(value)!=var_to_bytes(copied): return null
	selected.set_shader_parameter("env_anchor_enabled",1.0)
	selected.set_shader_parameter("env_root_y",root_y)
	_ground_material_variants[key] = {"original":original,"selected":selected,"root_y":root_y,"parameters":parameters}
	return selected

func _sync_ground_material_variants() -> void:
	# Existing appearance setters own the originals. Forward their ordinary art
	# parameters (including night/emission) to variants; textures remain aliases.
	# Cached parameter names only: no scene/native-array gather per frame.
	for entry: Dictionary in _ground_material_variants.values():
		for name: String in entry.parameters:
			entry.selected.set_shader_parameter(name,entry.original.get_shader_parameter(name))

func _ground_material_variant_report() -> Array:
	var rows: Array = []
	for key: String in _ground_material_variants:
		var entry: Dictionary = _ground_material_variants[key]
		var exact: bool = entry.original.shader==entry.selected.shader and entry.original.next_pass==entry.selected.next_pass and entry.original.render_priority==entry.selected.render_priority
		for name: String in entry.parameters:
			var source: Variant = entry.original.get_shader_parameter(name)
			var selected: Variant = entry.selected.get_shader_parameter(name)
			exact = exact and (source==selected if source is Object else var_to_bytes(source)==var_to_bytes(selected))
		rows.append({"key":key,"original_material_id":str(entry.original.get_instance_id()),"selected_material_id":str(entry.selected.get_instance_id()),"shader":entry.original.shader.resource_path,"root_y":entry.root_y,"protected_art_parameters_exact":exact,"shader_and_texture_aliases_exact":exact,"original_root_motion_disabled":var_to_bytes(entry.original.get_shader_parameter("env_anchor_enabled"))==var_to_bytes(0.0),"selected_root_readback_exact":var_to_bytes(entry.selected.get_shader_parameter("env_anchor_enabled"))==var_to_bytes(1.0) and var_to_bytes(entry.selected.get_shader_parameter("env_root_y"))==var_to_bytes(float(entry.root_y)),"parameter_count":entry.parameters.size()})
	return rows

func _prepare_ground_templates() -> void:
	if _ground_factory_attempted: return
	_ground_factory_attempted = true
	var live_rng: RandomNumberGenerator = world.get("_rng") as RandomNumberGenerator
	var live_before: String = str(live_rng.state) if live_rng!=null else "unavailable"
	_ground_factory_proof = {"source":GROUND_FACTORY_SOURCE,"required_source_sha256":GROUND_FACTORY_SHA256,"actual_source_sha256":FileAccess.get_sha256(GROUND_FACTORY_SOURCE),"off_tree":true,"ready_or_generation_called":false,"live_rng_before":live_before,"families":[]}
	if _ground_factory_proof.actual_source_sha256!=GROUND_FACTORY_SHA256 or live_rng==null:
		_ground_factory_proof["passed"] = false
		_ground_factory_proof["reason"] = "Pinned deterministic source/live RNG unavailable"
		return
	var factory: Node3D = load(GROUND_FACTORY_SOURCE).new()
	_ground_factory_proof["off_tree"] = not factory.is_inside_tree()
	var factory_rng: RandomNumberGenerator = factory.get("_rng") as RandomNumberGenerator
	var scratch_before: String = str(factory_rng.state)
	var specs: Array[Dictionary] = [
		{"family":"fern","method":"_make_fern_mesh","root_y":Vector3(0,0.02,0).y,"line":3300},
		{"family":"broadleaf","method":"_make_broadleaf_mesh","root_y":Vector3(0,0.025,0).y,"line":3453},
		{"family":"flower","method":"_make_flower_mesh","root_y":0.0,"line":3321},
		{"family":"grass","method":"_make_grass_mesh","root_y":0.0,"line":3356},
		{"family":"glow","method":"_make_tiny_mushroom_mesh","root_y":0.0,"line":3372}]
	var valid: bool = not factory.is_inside_tree()
	for spec: Dictionary in specs:
		var mesh: ArrayMesh = factory.call(spec.method) as ArrayMesh
		if mesh==null or mesh.get_surface_count()!=1:
			valid = false
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var root_y: float = spec.root_y
		var root_corners: int = 0
		var above_corners: int = 0
		var finite: bool = not vertices.is_empty()
		for vertex: Vector3 in vertices:
			finite = finite and vertex.is_finite() and vertex.y>=root_y
			if var_to_bytes(float(vertex.y))==var_to_bytes(root_y): root_corners += 1
			if vertex.y>root_y: above_corners += 1
		var root_proof: bool = finite and root_corners>0 and above_corners>0 and arrays.size()==Mesh.ARRAY_MAX
		valid = valid and root_proof
		var channel_bytes: Array[PackedByteArray] = []
		var hashes: Array[String] = []
		for channel: Variant in arrays:
			var encoded: PackedByteArray = var_to_bytes(channel)
			channel_bytes.append(encoded)
			hashes.append(_environment_sha(encoded))
		var template: Dictionary = {"family":spec.family,"constructor":spec.method,"source_line":spec.line,"root_y":root_y,"root_corners":root_corners,"vertex_count":vertices.size(),"root_plane_exact":root_proof,"channel_bytes":channel_bytes,"channels_sha256":hashes,"format":mesh.surface_get_format(0),"primitive":mesh.surface_get_primitive_type(0),"aabb_bytes":var_to_bytes(mesh.get_aabb())}
		_ground_templates.append(template)
		_ground_factory_proof.families.append({"family":spec.family,"constructor":spec.method,"source_line":spec.line,"root_y":root_y,"root_corners":root_corners,"vertex_count":vertices.size(),"root_plane_exact":root_proof,"native_channels_sha256":hashes})
	var scratch_after: String = str(factory_rng.state)
	factory.free()
	var live_after: String = str(live_rng.state)
	_ground_factory_proof["live_rng_after"] = live_after
	_ground_factory_proof["live_rng_exact"] = live_before==live_after
	_ground_factory_proof["scratch_rng_before"] = scratch_before
	_ground_factory_proof["scratch_rng_after"] = scratch_after
	_ground_factory_proof["scratch_rng_exact"] = scratch_before==scratch_after
	_ground_factory_proof["passed"] = valid and _ground_templates.size()==5 and live_before==live_after and scratch_before==scratch_after
	if not _ground_factory_proof.passed: _ground_templates.clear()

func _ground_match(mesh: Mesh) -> Dictionary:
	if mesh==null: return {"passed":false,"reason":"No native mesh"}
	var key: int = mesh.get_instance_id()
	if _ground_matches.has(key): return _ground_matches[key]
	_prepare_ground_templates()
	_ground_match_scans += 1
	var matched: Dictionary = {"passed":false,"reason":"No byte-exact known root family"}
	_ground_matches[key] = matched
	if not _ground_factory_proof.get("passed",false) or not mesh is ArrayMesh or mesh.get_surface_count()!=1: return matched
	var native_mesh: ArrayMesh = mesh as ArrayMesh
	var arrays: Array = native_mesh.surface_get_arrays(0)
	if arrays.size()!=Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return matched
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var actual: Array[PackedByteArray] = []
	var encoded: bool = false
	for template: Dictionary in _ground_templates:
		if vertices.size()!=int(template.vertex_count): continue
		var metadata: bool = native_mesh.surface_get_format(0)==template.format and native_mesh.surface_get_primitive_type(0)==template.primitive and var_to_bytes(native_mesh.get_aabb())==template.aabb_bytes
		if not metadata: continue
		if not encoded:
			for channel: Variant in arrays: actual.append(var_to_bytes(channel))
			encoded = true
		var exact: bool = true
		var flags: Array[bool] = []
		for slot: int in range(Mesh.ARRAY_MAX):
			var equal: bool = actual[slot]==template.channel_bytes[slot]
			flags.append(equal)
			exact = exact and equal
		if exact and template.root_plane_exact:
			matched = {"passed":true,"family":template.family,"channels_exact":flags,"metadata_exact":metadata,"channels_sha256":template.channels_sha256,"root_y":template.root_y,"root_corners":template.root_corners,"root_plane_exact":template.root_plane_exact,"vertex_count":vertices.size(),"format":native_mesh.surface_get_format(0),"primitive":native_mesh.surface_get_primitive_type(0)}
			_ground_matches[key] = matched
			return matched
	return matched

func _environment_sha(bytes: PackedByteArray) -> String:
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): digest.update(bytes)
	return digest.finish().hex_encode()

func _bind_material(material: ShaderMaterial,seen: Dictionary) -> void:
	if material==null or material.shader==null or seen.has(material.get_instance_id()): return
	var keys: Dictionary = {}
	for uniform: Dictionary in material.shader.get_shader_uniform_list(): keys[str(uniform.name)] = true
	if not keys.has("env_enabled"): return
	seen[material.get_instance_id()] = true
	_materials.append({"material":material,"keys":keys,"shader_path":material.shader.resource_path})

func _set_environment_uniform(row: Dictionary,key: String,value: Variant) -> void:
	if row["keys"].has(key): row.material.set_shader_parameter(key,value)

func _reconcile_particle_emission() -> void:
	# Preserve the inherited World emission contract even when its visual clock
	# is paused. Reduced effects disables particles without changing rain/night.
	var reduced: bool = bool(world.get("_reduced_effects"))
	var rain: GPUParticles3D = world.get("rain_particles") as GPUParticles3D
	var fireflies: GPUParticles3D = world.get("_fireflies") as GPUParticles3D
	if is_instance_valid(rain): rain.emitting = float(world.get("rain_amount"))>0.1 and not reduced
	if is_instance_valid(fireflies): fireflies.emitting = float(world.get("night_amount"))>0.45 and not reduced

func _apply_density() -> void:
	var density: float = 0.35 if quality=="low" else 0.65 if quality=="balanced" else 1.0
	for particles: GPUParticles3D in _particles:
		if is_instance_valid(particles): particles.amount_ratio = density
	# amount_ratio reduces visible emission; it does not reduce allocated capacity.

func _freeze_particles(stopped: bool) -> void:
	for particles: GPUParticles3D in _particles:
		if is_instance_valid(particles): particles.speed_scale = 0.0 if stopped else 1.0

func _apply_runtime_flora(strength: float) -> void:
	for row: Dictionary in _runtime_flora:
		var plant: Node3D = row.node
		if not is_instance_valid(plant): continue
		var phase: float = plant.position.x*0.19+plant.position.z*0.13
		var angle: float = sin(clock_seconds*0.8+phase)*strength*0.025
		plant.rotation = row.rest_rotation+Vector3(wind_direction.z*angle,0.0,-wind_direction.x*angle)

func _apply_lighting(rain: float) -> void:
	var environment: Environment = world.get("environment")
	var light: DirectionalLight3D = world.get("sun")
	if environment==null or not is_instance_valid(light): return
	var night: float = clampf(float(world.get("night_amount")),0.0,1.0)
	# Preserve the current day/night art endpoints; only an explicit sunset/sunrise
	# inspection blends a warm low sun. No compulsory game-time progression.
	var color: Color = Color("ffdaa2").lerp(Color("9bb3ed"),night)
	light.light_color = color.lerp(Color("ffb575"),_sunset*0.65)
	light.light_energy = lerpf(1.65,0.65,night)*lerpf(1.0,0.63,rain)*lerpf(1.0,0.82,_sunset)
	light.rotation_degrees = Vector3(lerpf(lerpf(-55.0,-27.45,night),-14.0,_sunset),lerpf(75.0,153.79,night),0.0)
	# Rotate the retained fill with the same day/night blend; its energy/color stay inherited.
	var fill: DirectionalLight3D = world.get("_sky_fill")
	if is_instance_valid(fill):
		fill.rotation_degrees = Vector3(-28.0,lerpf(148.0,328.0,night),0.0)
	environment.ambient_light_color = Color("d9d5c7").lerp(Color("95a0c7"),night).lerp(Color("dfc2aa"),_sunset*0.30)
	environment.ambient_light_energy = lerpf(0.18,0.30,night)
	environment.fog_light_color = Color("d0d6c2").lerp(Color("22324c"),night).lerp(Color("647787"),rain*0.34).lerp(Color("bfa79b"),_sunset*0.35)
	environment.fog_density = lerpf(0.0016,0.007,rain)
	environment.tonemap_exposure = 1.0
	var sky: ShaderMaterial = world.get("_cloud_sky_material")
	if sky!=null:
		sky.set_shader_parameter("top_color",Color("6c9ec1").lerp(Color("0a1236"),night).lerp(Color("3d5366"),rain*0.35).lerp(Color("667b9e"),_sunset*0.45))
		sky.set_shader_parameter("horizon_color",Color("b7c6c5").lerp(Color("172844"),night).lerp(Color("8b9b9e"),rain*0.32).lerp(Color("e9b48c"),_sunset*0.65))
	var visible_sun: Node3D = world.get("_r36_sun")
	var sky_root: Node3D = world.get("_r36_root")
	if is_instance_valid(visible_sun) and is_instance_valid(sky_root):
		visible_sun.position = sky_root.to_local(sky_root.global_position+light.global_basis.z.normalized()*120.0)

func is_sheltered(point: Vector3) -> bool:
	return (Vector2(point.x,point.z).length_squared()<28.95 and point.y<6.75) or (Vector2(point.x+4.10,point.z+0.40).length_squared()<6.35 and point.y<3.42) or (bool(world.get("_room_ready")) and Vector2(point.x-4.95,point.z-0.60).length_squared()<4.71 and point.y<3.40)

func _create_rain_audio() -> void:
	_rain_audio = AudioStreamPlayer.new()
	_rain_audio.name = "ProceduralRainApproximation"
	_rain_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = 8000.0
	generator.buffer_length = 0.25
	_rain_audio.stream = generator
	_rain_audio.volume_db = -60.0
	add_child(_rain_audio)
	_rain_audio.play()

func _cache_water_audio_source() -> void:
	var material: ShaderMaterial = world.get("_water_material") as ShaderMaterial
	if material==null or material.shader==null or material.shader.resource_path!=WATER_AUDIO_SHADER: return
	var owned: Array[MeshInstance3D] = []
	for child: Node in world.find_children("*","MeshInstance3D",true,false):
		var geometry: MeshInstance3D = child as MeshInstance3D
		if geometry!=null and geometry.material_override==material and geometry.is_visible_in_tree(): owned.append(geometry)
	# The authored stream is one unique actual material alias, not a node-name or
	# terrain-coordinate guess. Waterfall/foam/collider classes are not invented.
	if owned.size()!=1 or owned[0].mesh==null or owned[0].mesh.get_surface_count()!=1: return
	var node: MeshInstance3D = owned[0]
	var arrays: Array = node.mesh.surface_get_arrays(0)
	if arrays.size()!=Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or arrays[Mesh.ARRAY_VERTEX].size()<3: return
	var local: AABB = node.mesh.get_aabb()
	if not local.position.is_finite() or not local.size.is_finite() or local.size.x<=0.0 or local.size.z<=0.0 or local.size.y<0.0 or not node.global_transform.is_finite(): return
	var bounds: AABB = node.global_transform*local
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<=0.0 or bounds.size.z<=0.0: return
	_water_audio_node = node
	_water_audio_bounds = bounds
	_water_audio_proof = {"node":str(world.get_path_to(node)),"node_id":str(node.get_instance_id()),"native_mesh_id":str(node.mesh.get_instance_id()),"material_id":str(material.get_instance_id()),"shader":material.shader.resource_path,"native_channel_count":arrays.size(),"native_vertex_count":arrays[Mesh.ARRAY_VERTEX].size(),"all_native_channels_sha256":_environment_sha(var_to_bytes(arrays)),"local_aabb":local,"global_aabb":bounds,"native_transform":node.global_transform,"admission":"One visible actual World._water_material alias with positive native vertex/AABB readback; cached startup only."}

func _set_environment_audio_paused(stopped: bool) -> void:
	if is_instance_valid(_rain_audio): _rain_audio.stream_paused = stopped
	if is_instance_valid(game):
		var forest: AudioStreamPlayer = game.get("ambience") as AudioStreamPlayer
		if is_instance_valid(forest): forest.stream_paused = stopped

func _reconcile_environment_audio_gain(rain: float) -> void:
	var volume: float = 1.0
	if is_instance_valid(game):
		var settings: Variant = game.get("settings")
		if settings is Dictionary: volume = clampf(float(settings.get("ambience_volume",1.0)),0.0,1.0)
	var sheltered: bool = is_sheltered(player.global_position)
	var shelter_gain: float = 0.25 if sheltered else 1.0
	if is_instance_valid(game):
		var forest: AudioStreamPlayer = game.get("ambience") as AudioStreamPlayer
		if is_instance_valid(forest):
			# Retained bed contains wind/insects/birds together; all are attenuated.
			forest.volume_db = linear_to_db(maxf(0.000001,volume*shelter_gain*(0.55+0.25*_applied_wind_strength)))
	_water_audio_proximity = 0.0
	if is_instance_valid(_water_audio_node):
		# Conservative distance to native transformed rest bounds, not shoreline
		# acoustics, occlusion, surface classification or a distinct water recording.
		var closest: Vector3 = player.global_position.clamp(_water_audio_bounds.position,_water_audio_bounds.end)
		_water_audio_proximity = clampf(1.0-player.global_position.distance_to(closest)/6.0,0.0,1.0)
	if is_instance_valid(_rain_audio):
		var gain: float = volume*((0.045*rain*(0.20 if sheltered else 1.0))+0.010*_water_audio_proximity*shelter_gain)
		_rain_audio.volume_db = linear_to_db(maxf(0.000001,gain))

func get_environment_audio_report() -> Dictionary:
	var forest: AudioStreamPlayer = game.get("ambience") as AudioStreamPlayer if is_instance_valid(game) else null
	return {"schema":"mush-environment-audio/1","water_admitted":is_instance_valid(_water_audio_node) and not _water_audio_proof.is_empty(),"water_source":_water_audio_proof.duplicate(true),"water_proximity":_water_audio_proximity,"generator_count":1 if is_instance_valid(_rain_audio) and _rain_audio.stream is AudioStreamGenerator else 0,"generator_count_scope":"this controller; no new audio node or stream","forest_volume_db":forest.volume_db if is_instance_valid(forest) else null,"forest_paused":forest.stream_paused if is_instance_valid(forest) else null,"wash_volume_db":_rain_audio.volume_db if is_instance_valid(_rain_audio) else null,"wash_paused":_rain_audio.stream_paused if is_instance_valid(_rain_audio) else null,"shared_applied_wind":_applied_wind_strength,"sheltered":is_sheltered(player.global_position) if is_instance_valid(player) else false,"surface_precision_claimed":false,"scope":"Existing mixed forest WAV gain follows applied shared wind and authored shelter. Same retained8kHz filtered-noise generator adds restrained rain+native-rest-AABB proximity wash; not a separate real-water recording. Generic footsteps unchanged; no acoustic occlusion, new stream/bus/DSP, waveform/listening/device-cost proof."}

func _update_rain_audio(rain: float) -> void:
	_reconcile_environment_audio_gain(rain)
	if not is_instance_valid(_rain_audio): return
	var playback: AudioStreamGeneratorPlayback = _rain_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback==null: return
	var count: int = mini(1024,playback.get_frames_available())
	for i: int in range(count):
		_noise_state = (_noise_state*1664525+1013904223)&0x7fffffff
		var noise: float = float(_noise_state)/1073741824.0-1.0
		_noise_lowpass = lerpf(_noise_lowpass,noise,0.22)
		playback.push_frame(Vector2.ONE*_noise_lowpass)

func get_report() -> Dictionary:
	var rows: Array = []
	for row: Dictionary in _materials:
		rows.append({"material_id":str(row.material.get_instance_id()),"shader":row.shader_path,"enabled":row.material.get_shader_parameter("env_enabled"),"clock":row.material.get_shader_parameter("env_time"),"wind_direction":row.material.get_shader_parameter("env_wind_direction"),"wind_strength":row.material.get_shader_parameter("env_wind_strength"),"cloud_offset":row.material.get_shader_parameter("env_cloud_offset")})
	return {"schema":"mush-mobile-environment/1","configured":_configured,"shutting_down":_shutting_down,"rain_audio_active":_rain_audio.playing if is_instance_valid(_rain_audio) else false,"rain_audio_stream_attached":_rain_audio.stream!=null if is_instance_valid(_rain_audio) else false,"clock_seconds":clock_seconds,"detail_clock_seconds":detail_clock_seconds,"quality":quality,"reduced_motion":reduced_motion,"foreground":foreground,"wind_direction":wind_direction,"wind_strength":wind_strength,"applied_wind_strength":_applied_wind_strength,"cloud_offset":cloud_offset,"wetness":wetness,"motion_scale":0.15 if reduced_motion else 1.0,"vegetation_displacement_bound_m":CANOPY_BOUND,"ground_displacement_bound_m":GROUND_BOUND,"rain_density_ratio":0.35 if quality=="low" else 0.65 if quality=="balanced" else 1.0,"sunset_blend":_sunset,"inspection_state":inspection_state,"bound_materials":rows,"binding_scans":_scan_count,"ground_motion_admission":_bound_report(),"ground_factory_proof":_ground_factory_proof.duplicate(true),"ground_unique_native_meshes_scanned":_ground_match_scans,"ground_match_cache_size":_ground_matches.size(),"ground_material_variants":_ground_material_variant_report(),"ground_material_variant_count":_ground_material_variants.size(),"ground_material_variant_limit":MAX_GROUND_MATERIAL_VARIANTS,"ground_instance_uniforms_requested":false,"renderer_capabilities":world.call("get_renderer_capabilities_report") if is_instance_valid(world) and world.has_method("get_renderer_capabilities_report") else {},"ground_root_weight":"smoothstep((local_y-source_root_y)/1.25); every exact source-root-plane corner has zero displacement and derivative","runtime_flora_visual_roots":_runtime_flora.size(),"provisional_character_wind_adapter":player.has_method("apply_environment_wind") if is_instance_valid(player) else false,"rain_audio":"8000Hz procedural filtered noise; no new recording" if is_instance_valid(_rain_audio) else "not installed in standalone contract","device_verified":false,"motion_quality_verified":false,"GPU_deformed_vertex_readback":false,"approximation_limits":["Cloud shadows are shader albedo modulation, not physical cloud occlusion.","Rain shelter is the existing authored radial mask, not per-drop world collision.","Baked mixed batches without proven roots stay static.","Hanging architecture is combined baked geometry and stays static.","18 restoration flora use small visual root rotation; their gameplay/material bloom state remains owned by game.","Emission alone does not light nearby objects; existing Light3D nodes do.","amount_ratio does not reduce particle allocation.","Physical-device sustained cost and rendered consistency remain unverified."]}

func _bound_report() -> Array:
	var rows: Array = []
	for row: Dictionary in _bounds:
		var item: Dictionary = row.duplicate()
		item["node"] = str(row.node.get_path())
		rows.append(item)
	return rows

func get_environment_report() -> Dictionary:
	return get_report()

func shutdown_visuals() -> void:
	# Normal game quit calls this before world shutdown. The controller owns this
	# procedural stream. It pauses the retained forest bed but leaves its final
	# stop/detach to the game's existing audio shutdown; music remains untouched.
	_shutting_down = true
	set_process(false)
	set_foreground(false)
	if is_instance_valid(_rain_audio):
		_rain_audio.stop()
		_rain_audio.stream = null
	_materials.clear()
	_ground_material_variants.clear()
	_particles.clear()
	_runtime_flora.clear()
	_water_audio_node = null
	_water_audio_proof.clear()
