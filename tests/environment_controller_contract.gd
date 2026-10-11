extends SceneTree
## Test first: real baked scenery/player, no game profile and no reference pixels.
## Catches advancing while paused/backgrounded, resume catch-up, independent
## wind clocks, reduced-motion resets, visual forces and geometry mutation.
var checks: Array[Dictionary] = []
var output: String = ""
var world: Node3D
var player: CharacterBody3D
var controller: Node

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output = arg.trim_prefix("--report-dir=")
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://scripts/environment_controller.gd"):
		_check(false,"Shared environmental coordinator exists",{"reason":"Implementation missing; expected first RED"})
		_finish()
		return
	var source: Script = load("res://scripts/environment_controller.gd")
	if source == null or not source.can_instantiate():
		_check(false,"Coordinator can instantiate",{})
		_finish()
		return
	world = load("res://scripts/baked_world.gd").new()
	world.name = "ActualBakedWorld"
	root.add_child(world)
	player = load("res://lineage/entrance48-player-step-proposal02/player.gd").new()
	player.name = "ActualPlayer"
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	world.set_process(false)
	var startup_geometry: Dictionary = _geometry(world)
	var live_rng_before: String = str((world.get("_rng") as RandomNumberGenerator).state)
	controller = source.new()
	controller.configure(world,player,null)
	root.add_child(controller)
	controller.set_process(false)
	_check(var_to_bytes(startup_geometry)==var_to_bytes(_geometry(world)),"Root admission startup preserves all actual world native arrays, poses, node identities and colliders",{})
	# No shared wind factory admission is bypassed. If the controller needs the
	# existing living setup, it must either defer those materials or expose failure.
	controller._process(0.0)
	var before: Dictionary = _geometry(world)
	var player_pose: Transform3D = player.transform
	var velocity: Vector3 = player.velocity
	var initial: Dictionary = controller.get_report()
	_check(initial.get("configured",false),"Actual world/player configured",initial)
	var capabilities: Dictionary = initial.get("renderer_capabilities",{})
	var method: String = RenderingServer.get_current_rendering_method()
	var expected_forward: bool = method=="forward_plus"
	_check(capabilities.get("renderer","")==method and bool(capabilities.get("taa_requested",not expected_forward))==expected_forward and bool(capabilities.get("ssr_requested",not expected_forward))==expected_forward and bool(capabilities.get("ssao_requested",false))==(method in ["forward_plus","gl_compatibility"]) and float(capabilities.get("directional_angular_distance",-1.0))==(3.0 if expected_forward else 0.0),"Only supported renderer effects are requested; Compatibility keeps SSAO",capabilities)
	var neutral_proof: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://baked/renderer-neutral-proof.json"))
	_check(neutral_proof is Dictionary and neutral_proof.get("passed",false) and neutral_proof.get("qualified_resource_graph_exact",false) and neutral_proof.get("original_sha256","")==FileAccess.get_sha256("res://baked/clearing.res") and neutral_proof.get("derived_sha256","")==FileAccess.get_sha256("res://baked/clearing-renderer-neutral.res"),"Effective neutral snapshot binds preserved native geometry/resource graph and retained original bytes",{})
	var admitted_ground: int = 0
	for row: Dictionary in initial.get("ground_motion_admission",[]):
		if bool(row.get("motion_admitted",false)): admitted_ground += 1
	_check(admitted_ground>0,"Actual baked ground contains positively admitted rooted MultiMeshes",{"admitted_nodes":admitted_ground,"admission":initial.get("ground_motion_admission",[]),"scope":"A shader binding alone does not prove rooted ground motion. Native resource/channel and basis/cull admission is required."})
	var factory: Dictionary = initial.get("ground_factory_proof",{})
	_check(factory.get("passed",false) and factory.get("off_tree",false) and not factory.get("ready_or_generation_called",true) and factory.get("families",[]).size()==5 and str((world.get("_rng") as RandomNumberGenerator).state)==live_rng_before and factory.get("scratch_rng_exact",false),"Root constructor proof is off-tree, finite and leaves live/scratch RNG unchanged",factory)
	var source_path: String = "res://lineage/scenery-revision-16/proposals/cap-rim-gills-03/detached-world.gd"
	_check(factory.get("source","")==source_path and factory.get("actual_source_sha256","")==FileAccess.get_sha256(source_path) and factory.get("actual_source_sha256","")==factory.get("required_source_sha256","missing"),"Native root constructor provenance binds the actual source bytes",factory)
	var roots_ok: bool = admitted_ground>0
	var native_roots: int = 0
	var source_planes: Dictionary = {"fern":Vector3(0,0.02,0).y,"broadleaf":Vector3(0,0.025,0).y,"flower":0.0,"grass":0.0,"glow":0.0}
	for row: Dictionary in initial.get("ground_motion_admission",[]):
		if not bool(row.get("motion_admitted",false)): continue
		var node: MultiMeshInstance3D = root.get_node_or_null(NodePath(str(row.node))) as MultiMeshInstance3D
		if node==null or node.multimesh==null or not source_planes.has(str(row.family)):
			roots_ok = false
			continue
		var expected_y: float = source_planes[str(row.family)]
		var actual_vertices: PackedVector3Array = node.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var plane_corners: int = 0
		for vertex: Vector3 in actual_vertices:
			roots_ok = roots_ok and vertex.is_finite() and vertex.y>=expected_y
			if var_to_bytes(float(vertex.y))==var_to_bytes(expected_y): plane_corners += 1
		var channels: Array = row.get("native_channels_exact",[])
		roots_ok = roots_ok and channels.size()==Mesh.ARRAY_MAX and bool(row.get("native_metadata_exact",false))
		for exact: bool in channels: roots_ok = roots_ok and exact
		roots_ok = roots_ok and plane_corners>0 and plane_corners==int(row.native_root_corners) and bool(row.get("source_root_plane_exact",false)) and float(row.jacobian_lower_bound)>0.5 and float(row.world_bound_m)==0.020 and bool(row.get("cull_readback_exact",false)) and bool(row.get("anchor_readback_exact",false))
		roots_ok = roots_ok and node.material_override is ShaderMaterial and var_to_bytes((node.material_override as ShaderMaterial).get_shader_parameter("env_anchor_enabled"))==var_to_bytes(1.0) and var_to_bytes((node.material_override as ShaderMaterial).get_shader_parameter("env_root_y"))==var_to_bytes(expected_y)
		native_roots += plane_corners
	_check(roots_ok,"Actual rooted ground has literal source base-plane corners and exact native channel/uniform/cull admission",{"admitted_nodes":admitted_ground,"native_base_corners_summed_over_nodes":native_roots,"known_literal_planes":source_planes,"GPU_deformed_vertex_readback":false})
	var variants: Array = initial.get("ground_material_variants",[])
	var variants_exact: bool = not variants.is_empty() and variants.size()<admitted_ground and variants.size()<=int(initial.get("ground_material_variant_limit",0)) and not initial.get("ground_instance_uniforms_requested",true)
	for variant: Dictionary in variants:
		variants_exact = variants_exact and variant.protected_art_parameters_exact and variant.shader_and_texture_aliases_exact and variant.original_root_motion_disabled and variant.selected_root_readback_exact and variant.original_material_id!=variant.selected_material_id
	_check(variants_exact,"Root parameters use bounded shared material variants with exact art/resource aliases and static originals",{"variants":variants,"admitted_nodes":admitted_ground,"instance_uniforms_requested":initial.get("ground_instance_uniforms_requested")})
	var before_variant_count: int = variants.size()
	controller.refresh_bindings()
	_check(int(controller.get_report().get("ground_material_variant_count",-1))==before_variant_count,"Repeated binding reuses material variants without per-node duplicates",{})
	var ground_scans: int = int(initial.get("ground_unique_native_meshes_scanned",-1))
	var start: float = float(initial.get("clock_seconds",-1.0))
	for i: int in range(10): controller._process(0.1)
	var running: Dictionary = controller.get_report()
	_check(absf(float(running.get("clock_seconds",-100.0))-start-1.0)<0.000001,"Ten 100ms active updates advance exactly one second",running)
	var shared: bool = not running.get("bound_materials",[]).is_empty()
	for row: Dictionary in running.get("bound_materials",[]):
		shared = shared and row.enabled==true and var_to_bytes(row.clock)==var_to_bytes(running.clock_seconds) and var_to_bytes(row.wind_direction)==var_to_bytes(running.wind_direction) and var_to_bytes(row.wind_strength)==var_to_bytes(running.applied_wind_strength) and var_to_bytes(row.cloud_offset)==var_to_bytes(running.cloud_offset)
	_check(shared,"Actual owned shader materials share the same clock, wind and cloud parameters",running)
	var live_variant_art_exact: bool = true
	for variant: Dictionary in running.get("ground_material_variants",[]): live_variant_art_exact = live_variant_art_exact and bool(variant.protected_art_parameters_exact)
	_check(live_variant_art_exact,"Running variants retain current original appearance parameters and aliases",{})
	# Pause/background must freeze accumulated coordinates rather than resetting
	# them to zero. Literal elapsed expectations are independent of gust formula.
	paused = true
	for i: int in range(30): controller._process(0.1)
	var paused_report: Dictionary = controller.get_report()
	_check(var_to_bytes(_motion_state(running))==var_to_bytes(_motion_state(paused_report)),"Pause freezes clock, wind and cloud state without reset",paused_report)
	paused = false
	controller.set_foreground(false)
	for i: int in range(30): controller._process(0.1)
	var background: Dictionary = controller.get_report()
	_check(var_to_bytes(_motion_state(paused_report))==var_to_bytes(_motion_state(background)),"Background freezes visual state",background)
	controller.set_foreground(true)
	controller._process(10.0)
	var resume: Dictionary = controller.get_report()
	var resume_step: float = float(resume.get("clock_seconds",-100.0))-float(background.get("clock_seconds",-100.0))
	_check(resume_step>=-0.000001 and resume_step<=0.250001,"A long resume frame cannot catch up ten seconds",{"advanced_seconds":resume_step,"step_limit_s":0.25,"elapsed_subtraction_tolerance_s":0.000001})
	controller.set_inspection_state("gust")
	for i: int in range(100):
		controller._process(0.05)
		var gust: Dictionary = controller.get_report()
		var direction: Vector3 = gust.get("wind_direction",Vector3.ZERO)
		_check(direction.is_finite() and absf(direction.length()-1.0)<0.000001 and absf(direction.y)<0.000001 and float(gust.get("wind_strength",-1.0))>=0.0 and float(gust.get("wind_strength",2.0))<=1.0,"Gust stays finite horizontal and bounded",{"sample":i,"wind":gust.get("wind_strength"),"direction":str(direction)})
	_check(int(controller.get_report().get("ground_unique_native_meshes_scanned",-2))==ground_scans,"Native ground channel matching is cached during repeated active updates",{"startup_unique_mesh_scans":ground_scans,"after_scans":controller.get_report().get("ground_unique_native_meshes_scanned")})
	var pre_reduced: Dictionary = controller.get_report()
	controller.set_reduced_motion(true)
	for i: int in range(10): controller._process(0.1)
	var reduced: Dictionary = controller.get_report()
	_check(float(reduced.get("vegetation_displacement_bound_m",10.0))<=0.025 and float(reduced.get("motion_scale",10.0))<=0.2,"Reduced motion uses smaller bounded motion",reduced)
	_check(float(reduced.get("clock_seconds",-100.0))>=float(pre_reduced.get("clock_seconds",0.0)),"Reduced-motion selection does not rewind visual time",reduced)
	controller.set_quality("low")
	var low: Dictionary = controller.get_report()
	_check(low.get("quality","")=="low" and float(low.get("rain_density_ratio",2.0))<=1.0,"Low tier changes bounded effect density",low)
	_check(var_to_bytes(player.transform)==var_to_bytes(player_pose) and var_to_bytes(player.velocity)==var_to_bytes(velocity),"Environmental forces never move the player or change gameplay velocity",{})
	_check(var_to_bytes(before)==var_to_bytes(_geometry(world)),"Native world geometry, transforms and collider resources remain exact",{})
	_check(controller.get_report().get("device_verified",true)==false,"Report distinguishes implementation from physical-device verification",{})
	# Literal existing appearance endpoints: reduced effects is a settings
	# reconciliation, and must work while accumulated environmental time freezes.
	world.night_amount = 1.0
	world.rain_amount = 1.0
	world.set_appearance(true,true,false)
	controller._process(0.0)
	_check(world.rain_particles.emitting and world._fireflies.emitting,"Existing rain/night endpoints enable particles before reduced effects",{})
	paused = true
	var settings_clock: float = float(controller.get_report().clock_seconds)
	world.set_appearance(true,true,true)
	controller._process(0.1)
	_check(not world.rain_particles.emitting and not world._fireflies.emitting and world.night_amount==1.0 and world.rain_amount==1.0 and float(controller.get_report().clock_seconds)==settings_clock,"Paused reduced-effects selection removes particles while retaining night/rain and frozen clock",{})
	world.set_appearance(true,true,false)
	controller._process(0.1)
	_check(world.rain_particles.emitting and world._fireflies.emitting and world.rain_particles.speed_scale==0.0 and world._fireflies.speed_scale==0.0 and float(controller.get_report().clock_seconds)==settings_clock,"Disabling reduced effects restores inherited emission without advancing paused particles",{})
	paused = false
	# Regression starts from a literal cold day/clear fixture, avoiding a prior
	# scenario's night/rain load hiding paused blend failure. Own game menu API
	# selects targets in fresh T14; this standalone fixture invokes World API.
	world.night_amount = 0.0
	world.rain_amount = 0.0
	world.set_appearance(false,false,false)
	world._apply_appearance()
	controller._process(0.0)
	var paused_world_clock: float = float(world.get("_time"))
	var paused_living_clock: float = float(world.get("_m37_elapsed"))
	var paused_controller_state: Array = _motion_state(controller.get_report())
	var paused_player_pose: Transform3D = player.transform
	var paused_player_velocity: Vector3 = player.velocity
	paused = true
	world.set_appearance(true,true,false)
	for i: int in range(22):
		world._process(0.1)
		controller._process(0.1)
	_check(world.night_amount>0.98 and world.rain_amount>0.98,"Cold day/clear reaches selected night/rain after2.2seconds while paused",{"night":world.night_amount,"rain":world.rain_amount,"observed_step_count":22,"step_seconds":0.1})
	_check(var_to_bytes(float(world.get("_time")))==var_to_bytes(paused_world_clock) and var_to_bytes(float(world.get("_m37_elapsed")))==var_to_bytes(paused_living_clock) and var_to_bytes(_motion_state(controller.get_report()))==var_to_bytes(paused_controller_state) and var_to_bytes(player.transform)==var_to_bytes(paused_player_pose) and var_to_bytes(player.velocity)==var_to_bytes(paused_player_velocity),"Paused appearance changes no running world/living/wind/cloud/player clocks or forces",{})
	var endpoint: bool = var_to_bytes(world._cloud_sky_material.get_shader_parameter("night_amount"))==var_to_bytes(1.0) and var_to_bytes(world._cloud_sky_material.get_shader_parameter("rain_amount"))==var_to_bytes(1.0) and world._practical_lights.size()==20 and world._night_lights.size()==4
	for light: OmniLight3D in world._practical_lights: endpoint = endpoint and light.light_energy>=0.9
	for light: OmniLight3D in world._night_lights: endpoint = endpoint and absf(light.light_energy-0.9)<0.000001
	var luminous_gill: bool = false
	for material: ShaderMaterial in world._gill_materials: luminous_gill = luminous_gill or float(material.get_shader_parameter("emission_strength"))>0.0
	_check(endpoint and luminous_gill,"Paused target applies actual cloud/weather/gill and20warm4cool light endpoints",{"luminous_gill":luminous_gill})
	var paused_variants_exact: bool = true
	for variant: Dictionary in controller.get_report().get("ground_material_variants",[]): paused_variants_exact = paused_variants_exact and bool(variant.protected_art_parameters_exact)
	_check(paused_variants_exact,"Paused appearance also reaches shared ground variant art parameters without moving roots",{})
	# Composed background suspension holds appearance, not only wind clocks.
	world.night_amount = 0.0
	world.rain_amount = 0.0
	controller.set_foreground(false)
	for i: int in range(22):
		world._process(0.1)
		controller._process(0.1)
	_check(world.night_amount==0.0 and world.rain_amount==0.0 and var_to_bytes(_motion_state(controller.get_report()))==var_to_bytes(paused_controller_state),"Background holds selected appearance blend and accumulated visual state",{})
	controller.set_foreground(true)
	paused = false
	var final_clock: float = float(controller.get_report().clock_seconds)
	controller.shutdown_visuals()
	controller._process(0.1)
	var closed: Dictionary = controller.get_report()
	_check(closed.get("shutting_down",false) and not controller.is_processing() and float(closed.clock_seconds)==final_clock,"Shutdown freezes the controller even if an update was queued",closed)
	_check(not closed.get("rain_audio_active",true) and not closed.get("rain_audio_stream_attached",true),"Shutdown leaves no procedural rain playback/stream attachment",closed)
	_finish()

func _motion_state(report: Dictionary) -> Array:
	return [report.get("clock_seconds"),report.get("detail_clock_seconds"),report.get("wind_direction"),report.get("wind_strength"),report.get("applied_wind_strength"),report.get("cloud_offset"),report.get("wetness")]

func _geometry(node: Node) -> Dictionary:
	var rows: Dictionary = {}
	for child: Node in node.get_children(): rows[str(child.get_path())] = _geometry(child)
	var result: Dictionary = {"id":node.get_instance_id(),"children":rows}
	if node is Node3D: result["transform"] = node.transform
	if node is MeshInstance3D and node.mesh != null:
		result["mesh_id"] = node.mesh.get_instance_id()
		result["arrays"] = _arrays(node.mesh)
	if node is MultiMeshInstance3D and node.multimesh != null:
		result["mm_id"] = node.multimesh.get_instance_id()
		result["buffer"] = _sha(node.multimesh.buffer.to_byte_array())
		result["mesh_id"] = node.multimesh.mesh.get_instance_id()
		result["arrays"] = _arrays(node.multimesh.mesh)
	if node is CollisionObject3D:
		result["collision"] = [node.get_rid().get_id(),node.collision_layer,node.collision_mask]
	if node is CollisionShape3D and node.shape != null:
		var fields: Dictionary = {}
		for property: Dictionary in node.shape.get_property_list():
			var value: Variant = node.shape.get(property.name)
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not value is Object:
				fields[str(property.name)] = _sha(var_to_bytes(value))
		result["shape"] = [node.shape.get_instance_id(),node.shape.get_rid().get_id(),node.disabled,fields]
	return result

func _arrays(mesh: Mesh) -> Array:
	var result: Array = []
	for i: int in range(mesh.get_surface_count()): result.append(_sha(var_to_bytes(mesh.surface_get_arrays(i))))
	return result

func _sha(bytes: PackedByteArray) -> String:
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): digest.update(bytes)
	return digest.finish().hex_encode()

func _check(passed: bool,label: String,observed: Dictionary) -> void:
	checks.append({"passed":passed,"label":label,"observed":observed})
	if not passed: print("ENVIRONMENT_CONTRACT_FAIL ",label)

func _finish() -> void:
	var failed: int = 0
	for row: Dictionary in checks:
		if not row.passed: failed += 1
	var report: Dictionary = {"schema":"mush-environment-controller-contract/1","passed":failed==0,"assertions":checks.size(),"failed":failed,"checks":checks,"engine":Engine.get_version_info().string,"device_verified":false,"visual_quality_verified":false,"scope":"Behavioral controller/native-rest boundary only. No rendered motion, shader GPU deformation, phone performance, real touch or lifecycle proof."}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file: FileAccess = FileAccess.open(output.path_join("environment-contract.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ENVIRONMENT_CONTRACT ",JSON.stringify({"passed":failed==0,"assertions":checks.size(),"failed":failed}))
	if is_instance_valid(world): world.shutdown_visuals()
	quit(0 if failed==0 else 2)
