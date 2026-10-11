extends "res://lineage/entrance52-capture03/midstory-world.gd"
## Same native scene and runtime values; the authoring pipeline runs before export.
var snapshot_loaded: bool = false
var paving_preview_prebuilt: RefCounted
var paving_preview_prebuilt_report: Dictionary = {}
var paving_surface_original: ShaderMaterial
var paving_surface_report: Dictionary = {"passed":false}
const PAVING_STONE: Texture2D = preload("res://assets/world/textures/rock_01_diff_1k.jpg")
var snapshot_load_seconds: float = 0.0
var forest_enclosure: Dictionary = {}
var _environment_foreground: bool = true
const RENDERER_SNAPSHOT: String = "res://baked/clearing-renderer-neutral.res"
const RENDERER_PROOF: String = "res://baked/renderer-neutral-proof.json"
var renderer_capabilities: Dictionary = {}
const Cap57Prebuilt = preload("res://scripts/cap57_prebuilt.gd")
# Filled only from a clean root-owned native builder proof; never guessed.
const CAP57_PROOF_SHA := "4127056a401e13bd5096f6e74f87773ce34f285e15ce039e511f6889f8d1bf7d"
var cap57_prebuilt_report: Dictionary = {"schema":"mush-cap57-prebuilt-runtime/1","passed":false,"installed":false}
var effective_foliage_shader_provenance: Dictionary = {}
const PlasterArchPrebuilt = preload("res://scripts/plaster_arch_prebuilt.gd")
const PLASTER_ARCH_PROOF_SHA: String = "9e4c5b77a7b0fa1e2b16958e98b77d4eedff228b483bbaf7e361d45899839d78"
var plaster_arch_prebuilt: RefCounted
var plaster_arch_prebuilt_report: Dictionary = {"schema":"mush-plaster-arch-prebuilt-runtime/1","passed":false,"installed":false}

const PavingCollarPrebuilt = preload("res://scripts/paving_collar_prebuilt.gd")
const PAVING_COLLAR_PROOF_SHA: String = "6e006ca6f902a3f28b6d3909f8a1799cc57f6a197f59c378b0b7f49502915e51"
var paving_collar_prebuilt: RefCounted
var paving_collar_prebuilt_report: Dictionary = {"schema":"mush-paving-collar-prebuilt-runtime/1","passed":false,"installed":false}
var path_backing_report: Dictionary = {"passed":false}
const FloorPrebuilt = preload("res://scripts/floor_prebuilt.gd")
var floor_prebuilt_report: Dictionary = {"passed":false,"installed":false}
var stream_bank_report: Dictionary = {"passed":false,"installed":false}
const SoilContactPrebuilt = preload("res://scripts/soil_contact_prebuilt.gd")
var soil_contact_report: Dictionary = {"passed":false,"installed":false}
const GrownRoomFoundation = preload("res://scripts/grown_room_foundation.gd")
const GROWN_ROOM_FOUNDATION_PROOF_SHA: String = "08cef5e7a28bf583817d53488ec2c9889816fdd80df2e79142a93ec3cf891614"
var grown_room_foundation: RefCounted
var grown_room_foundation_report: Dictionary = {"schema":"mush-grown-room-foundation-runtime/1","passed":false,"installed":false}
var annex_counter_report: Dictionary = {"passed":false,"installed":false}
const AnnexRoofPrebuilt = preload("res://scripts/annex_roof_prebuilt.gd")
const ANNEX_ROOF_PROOF_SHA: String = "e32310b1768d34ec781ec175b14be5a786dab18c18b1dcbc8cf617c1f645b6d1"
var annex_roof_prebuilt_report: Dictionary = {"schema":"mush-annex-roof-prebuilt-runtime/1","passed":false,"installed":false}
const HeroStonePrebuilt = preload("res://scripts/hero_stone_prebuilt.gd")
const HERO_STONE_PROOF_SHA := "bc0752f38cd1496990b5e1489bbe1d14dd691898314e87b957bccba9ba8bea43"
var hero_stone_prebuilt_report: Dictionary = {"schema":"mush-hero-stone-normal-prebuilt-runtime/1","passed":false,"installed":false}

func _ready() -> void:
	var started := Time.get_ticks_usec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(RENDERER_PROOF)) if FileAccess.file_exists(RENDERER_PROOF) else null
	if not proof is Dictionary or not proof.get("passed",false) or proof.get("original_sha256","")!=FileAccess.get_sha256("res://baked/clearing.res") or proof.get("derived_sha256","")!=FileAccess.get_sha256(RENDERER_SNAPSHOT):
		push_error("Renderer-neutral snapshot/proof missing or does not bind the retained source")
		get_tree().quit(2)
		return
	var state: Resource = load(RENDERER_SNAPSHOT)
	if state == null or state.scene == null:
		push_error("The clearing's baked scene or runtime state is missing")
		get_tree().quit(2)
		return
	var baked: Node3D = state.scene.instantiate()
	_release_scene_owners(baked)
	for child: Node in baked.get_children():
		baked.remove_child(child)
		add_child(child)
	baked.free()
	state.restore(self)
	if not _cache_effective_foliage_shader_provenance():
		push_error("Effective foliage palette source/code provenance refused")
		get_tree().quit(2)
		return
	# Runtime nodes now own these resources. Release the deserialized template's
	# particle materials too, so they do not retain renderer allocations at quit.
	state.values.clear()
	state.scene = null
	state = null
	cap57_prebuilt_report = Cap57Prebuilt.install(self,CAP57_PROOF_SHA)
	if not cap57_prebuilt_report.get("passed",false):
		push_error("Prebuilt cap proof/native ownership refused: "+str(cap57_prebuilt_report.get("failure","")))
		get_tree().quit(2)
		return
	plaster_arch_prebuilt = PlasterArchPrebuilt.new()
	plaster_arch_prebuilt_report = plaster_arch_prebuilt.install(self,PLASTER_ARCH_PROOF_SHA)
	if not plaster_arch_prebuilt_report.get("passed",false) or not _apply_plaster_grain042():
		push_error("Combined plaster cache/grain native ownership refused: "+str(plaster_arch_prebuilt_report.get("failure","")))
		get_tree().quit(2)
		return
	# Install the single surface fork before geometry owners capture material
	# pointers. Shared environment discovery later binds the installed material.
	if not _apply_paving_surface():
		push_error("Paving stone surface binding refused")
		get_tree().quit(2)
		return
	paving_collar_prebuilt = PavingCollarPrebuilt.new()
	paving_collar_prebuilt_report = paving_collar_prebuilt.install(self,PAVING_COLLAR_PROOF_SHA)
	if not paving_collar_prebuilt_report.get("passed",false) or not paving_collar_prebuilt_report.get("installed",false):
		push_error("Paving collar prebuilt native ownership refused: "+str(paving_collar_prebuilt_report.get("failure","")))
		get_tree().quit(2)
		return
	if not _hide_path_backing049():
		push_error("Known decorative path backing was not found")
		get_tree().quit(2)
		return
	floor_prebuilt_report = FloorPrebuilt.install(self)
	if not floor_prebuilt_report.get("passed",false) or not floor_prebuilt_report.get("installed",false):
		push_error("Prebuilt floor joins/native ownership refused")
		get_tree().quit(2)
		return
	if not _install_stream_bank_closure():
		push_error("Prebuilt stream bank closure is missing or changed")
		get_tree().quit(2)
		return
	soil_contact_report = SoilContactPrebuilt.install(self)
	if not soil_contact_report.get("passed",false) or not soil_contact_report.get("installed",false):
		push_error("Merged native soil contact ownership refused")
		get_tree().quit(2)
		return
	stream_bank_report["node_retained"] = true
	stream_bank_report["node_visible"] = false
	stream_bank_report["rendered_in_merged_soil"] = true
	stream_bank_report["additional_active_draw_nodes"] = 0
	grown_room_foundation = GrownRoomFoundation.new()
	grown_room_foundation_report = grown_room_foundation.install(self,GROWN_ROOM_FOUNDATION_PROOF_SHA)
	if not grown_room_foundation_report.get("passed",false) or not grown_room_foundation_report.get("installed",false):
		push_error("Grown room native soil contact refused: "+str(grown_room_foundation_report.get("failure","")))
		get_tree().quit(2)
		return
	if not _install_annex_counter_collision():
		push_error("Permanent annex counter collision could not be installed")
		get_tree().quit(2)
		return
	annex_roof_prebuilt_report = AnnexRoofPrebuilt.install(self,ANNEX_ROOF_PROOF_SHA)
	if not annex_roof_prebuilt_report.get("passed",false) or not annex_roof_prebuilt_report.get("installed",false):
		push_error("Prebuilt annex roof native ownership refused: "+str(annex_roof_prebuilt_report.get("failure","")))
		get_tree().quit(2)
		return
	hero_stone_prebuilt_report = HeroStonePrebuilt.install(self,HERO_STONE_PROOF_SHA)
	if not hero_stone_prebuilt_report.get("passed",false) or not hero_stone_prebuilt_report.get("installed",false):
		push_error("Prebuilt hero stone native ownership refused: "+str(hero_stone_prebuilt_report.get("failure","")))
		get_tree().quit(2)
		return
	forest_enclosure = preload("res://scripts/forest_enclosure.gd").build(self)
	# Keep the retained wind/shelter particle system. Native alpha fade removes
	# distracting close-camera streaks without changing capacity or physics.
	var rain_material: BaseMaterial3D = rain_particles.draw_pass_1.surface_get_material(0) as BaseMaterial3D
	if rain_material==null:
		push_error("The retained rain draw material is missing")
		get_tree().quit(2)
		return
	rain_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	rain_material.distance_fade_min_distance = 0.8
	rain_material.distance_fade_max_distance = 2.5
	# Broader penumbra on the existing framing branch, with the same light pose.
	_apply_renderer_capabilities()
	get_window().size_changed.connect(_apply_render_resolution_policy)
	_apply_render_resolution_policy()
	_time = 0.0
	_m37_elapsed = 0.0
	set_living_motion_enabled(true)
	set_process(true)
	paving_preview_prebuilt = preload("res://scripts/paving_preview_prebuilt.gd").new()
	paving_preview_prebuilt_report = paving_preview_prebuilt.install(self,"e79a3726db329ac6de071966504b5271a584042f1a2aafb73c33228e3d460cd6")
	if not paving_preview_prebuilt_report.get("passed",false) or not paving_preview_prebuilt_report.get("installed",false):
		push_error("Private paving preview refused: "+str(paving_preview_prebuilt_report.get("failure","")))
		get_tree().quit(2)
		return
	snapshot_loaded = true
	snapshot_load_seconds = float(Time.get_ticks_usec()-started)/1000000.0
	print("CLEARING_READY ", JSON.stringify({"baked":true,"world_load_seconds":snapshot_load_seconds}))


func _install_annex_counter_collision() -> bool:
	var annex := get_node_or_null("MushroomHome/OpenLeftAnnex") as Node3D
	if annex == null or has_node("AnnexCounterCollision") or global_transform != Transform3D.IDENTITY:
		return false
	if not annex.global_position.is_equal_approx(Vector3(-4.1,0,-.4)):
		return false
	# This union includes the countertop overhang. Its actual 72 native face
	# corners were admitted in isolation; 1mm pad encloses float rounding.
	var bounds := AABB(Vector3(-5.29500007629395,.599999964237213,-1.6949999332428),Vector3(.690000057220459,.954999983310699,1.38999998569489)).grow(.001)
	var body := StaticBody3D.new()
	body.name = "AnnexCounterCollision"
	body.collision_layer = 16
	body.collision_mask = 2
	body.position = bounds.get_center()
	var box := BoxShape3D.new()
	box.size = bounds.size
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	annex_counter_report = {"passed":true,"installed":true,"layer":16,"mask":2,"shapes":1,"conservative_pad_m":.001,"position":[body.position.x,body.position.y,body.position.z],"size":[box.size.x,box.size.y,box.size.z],"new_draw_nodes":0,"perframe_script_work":false,"camera_controller_changed":false,"close_camera_fade_review_pending":true}
	return true

func _install_stream_bank_closure() -> bool:
	# Eight prebuilt soil triangles close the open sides above the water.
	# The original foreground banks, water, ground tops and colliders stay intact.
	var artifact: String = "res://baked/stream-banks.res"
	if FileAccess.get_sha256(artifact)!="5517e37d84c1e40d942fc49395e7c816833f2bf1a397dce95dce2a6d864222e6" or get_node_or_null("StreamBankClosure")!=null:
		return false
	var mesh := load(artifact) as ArrayMesh
	if mesh==null or mesh.get_surface_count()!=1 or mesh.surface_get_material(0)!=null or mesh.get_faces().size()!=24:
		return false
	var bank := MeshInstance3D.new()
	bank.name = "StreamBankClosure"
	bank.mesh = mesh
	bank.material_override = _materials["soil"]
	add_child(bank)
	stream_bank_report = {"passed":true,"installed":true,"artifact":artifact,"triangles":8,"surfaces":1,"shared_soil_material":true,"new_colliders":0,"perframe_work":false,"water_changed":false,"performance_measured":false}
	return true

func _hide_path_backing049() -> bool:
	# The retained backing is decorative; native terrain provides all support.
	# Expose that moss between the original stones instead of a flat dark band.
	var path: String = "BatchedStaticWorld/Static_-9223371994995620355_0_0"
	var backing: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
	if backing==null or backing.mesh==null or backing.material_override!=_materials["path"] or not backing.visible:
		return false
	var faces: PackedVector3Array = backing.mesh.get_faces()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(faces.to_byte_array())
	var digest: String = hash.finish().hex_encode()
	if faces.size()!=81 or digest!="67b996e4ad91e433b6af0c48ebc311ca732631e9589cd459f1c762eaa867de38":
		return false
	backing.hide()
	path_backing_report = {"passed":not backing.visible,"node":path,"faces_sha256":digest,"retained_triangles":27,"visible":backing.visible,"approximation":"Existing moss terrain exposed between unchanged stones; decorative backing retained but hidden.","collision_changed":false,"new_draws":0,"performance_measured":false}
	return not backing.visible

func _apply_paving_surface() -> bool:
	var node := get_node_or_null(PavingCollarPrebuilt.PATHS[0]) as MeshInstance3D
	if node == null or not node.material_override is ShaderMaterial or PAVING_STONE.get_size() != Vector2(1024,1024): return false
	var original := node.material_override as ShaderMaterial
	if original.shader == null or original.shader.resource_path != "res://assets/world/tactile.gdshader": return false
	var blend: Variant = original.get_shader_parameter("surface_blend")
	if blend != null and float(blend) != 0.0: return false
	var selected := original.duplicate(false) as ShaderMaterial
	if selected == null or selected.shader != original.shader: return false
	selected.set_shader_parameter("surface_albedo",PAVING_STONE)
	selected.set_shader_parameter("surface_blend",0.60)
	selected.set_shader_parameter("surface_scale",2.0/3.0)
	selected.set_shader_parameter("surface_triplanar",false)
	paving_surface_original = original
	node.material_override = selected
	paving_surface_report = {"passed":node.material_override == selected,"texture":PAVING_STONE.resource_path,"blend":0.60,"repeat_meters":1.5,"original_material_retained":true,"added_materials":1,"added_draw_nodes":0,"geometry_changed":false,"collision_changed":false,"perframe_script_work":false,"approximation":"One planar albedo sample and existing albedo-derived shallow shading relief; no geometric displacement.","physical_device_tested":false}
	return bool(paving_surface_report.passed)

func _apply_plaster_grain042() -> bool:
	# One shared material; geometry was admitted at original grain.35 first.
	var node: MeshInstance3D = get_node_or_null(PlasterArchPrebuilt.PATHS[0]) as MeshInstance3D
	if node==null or not node.material_override is ShaderMaterial: return false
	var material: ShaderMaterial = node.material_override as ShaderMaterial
	var saved_grain: Variant = material.get_shader_parameter("grain")
	if var_to_bytes(saved_grain)!=var_to_bytes(.35): return false
	var before_uniforms: Dictionary = plaster_arch_prebuilt.call("_uniforms",material)
	var before_stored: Dictionary = plaster_arch_prebuilt.call("_stored",material)
	var expected_uniforms: Dictionary = before_uniforms.duplicate(true)
	var expected_stored: Dictionary = before_stored.duplicate(true)
	if before_uniforms.size()!=31 or not before_uniforms.has("shader_parameter/grain") or not before_stored.has("shader_parameter/grain"): return false
	expected_uniforms["shader_parameter/grain"] = .08
	expected_stored["shader_parameter/grain"] = .08
	var aliases: Array[String] = ["MushroomHome/OrganicStemShell","MushroomHome/InnerPlaster","MushroomHome/OpenLeftAnnex/OrganicStemShell","MushroomHome/OpenLeftAnnex/InnerPlaster","MushroomHome/GrowthWallPlug/@MeshInstance3D@908","MushroomHome/GrowableRightRoom/OrganicStemShell","MushroomHome/GrowableRightRoom/InnerPlaster","MushroomHome/GrowableRightRoom/@MeshInstance3D@935","MushroomHome/GrowableRightRoom/@MeshInstance3D@938","MushroomHome/GrowableRightRoom/@MeshInstance3D@941","ForestBeyondTheClearing/@Node3D@3758/@MeshInstance3D@3759","ForestBeyondTheClearing/@Node3D@3780/@MeshInstance3D@3781","ForestBeyondTheClearing/@Node3D@3802/@MeshInstance3D@3803","BatchedStaticWorld/Static_-9223371995264055848_0_0","BatchedStaticWorld/Static_-9223371995264055848_-1_-1","BatchedStaticWorld/Static_-9223371995264055848_2_-3","BatchedStaticWorld/Static_-9223371995264055848_-2_-3"]
	for path: String in aliases:
		var alias: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
		if alias==null or alias.material_override!=material: return false
	material.set_shader_parameter("grain",.08)
	var after_uniforms: Dictionary = plaster_arch_prebuilt.call("_uniforms",material)
	var after_stored: Dictionary = plaster_arch_prebuilt.call("_stored",material)
	var valid: bool = var_to_bytes(after_uniforms)==var_to_bytes(expected_uniforms) and var_to_bytes(after_stored)==var_to_bytes(expected_stored)
	for path: String in aliases:
		var alias: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
		valid = valid and alias!=null and alias.material_override==material
	valid = valid and plaster_arch_prebuilt.verify(self,true,.08)
	if not valid:
		material.set_shader_parameter("grain",saved_grain)
		plaster_arch_prebuilt_report = plaster_arch_prebuilt.get_report()
		return false
	plaster_arch_prebuilt_report = plaster_arch_prebuilt.get_report()
	plaster_arch_prebuilt_report["grain_update"] = {"passed":true,"before":saved_grain,"after":material.get_shader_parameter("grain"),"actual_shared_material_id":str(material.get_instance_id()),"verified_material_override_aliases":aliases,"verified_alias_count":aliases.size(),"uniform_count":before_uniforms.size(),"only_grain_uniform_and_stored_property_changed":true,"native_uniform_maps_exact":true,"native_stored_maps_exact":true,"writes":1,"scope":"Single existing shared-material grain setter after native cache admission, then fresh native mesh/owner verification at explicit.08. All shader code, colors and other uniforms remain actual byte-exact."}
	return true

func _cache_effective_foliage_shader_provenance() -> bool:
	# Two bounded startup reads after ordinary restore; historical baked hashes stay intact.
	var paths: Array[String] = ["res://assets/world/foliage.gdshader","res://lineage/living-scenery37-proposal01/canopy-wind37.gdshader"]
	var expected: Array[String] = ["bef3157cee222d2afc23c30c4d28e3f42b9b4c74b7f8af8e7f89c1e1bab5f47a","e097b4d7777b8a7614f32efb99ff2744b359bc0007c98a07b06fac4407a4b9a4"]
	var rows: Array[Dictionary] = []
	var passed: bool = effective_foliage_shader_provenance.is_empty()
	for index: int in range(paths.size()):
		var shader: Shader = load(paths[index]) as Shader
		var source_sha: String = FileAccess.get_sha256(paths[index])
		var code_sha: String = ""
		if shader!=null:
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			if not shader.code.is_empty(): hash.update(shader.code.to_utf8_buffer())
			code_sha = hash.finish().hex_encode()
		var one: bool = shader!=null and shader.resource_path==paths[index] and source_sha==expected[index] and code_sha==expected[index]
		if index==1: one = one and shader==_M37_WIND_SHADER
		passed = passed and one
		rows.append({"path":paths[index],"file_sha256":source_sha,"effective_code_sha256":code_sha,"expected_sha256":expected[index],"passed":one})
	effective_foliage_shader_provenance = {"schema":"mush-mac044-effective-foliage-shaders/1","passed":passed,"cached_after_ordinary_restore":true,"file_hash_reads":2,"perframe_hashing":false,"historical_baked_wind_shader_sha256":_m37_wind_shader_sha,"historical_hash_fields_modified":false,"rows":rows,"palette":"night_leaf_palette041 source_color default(.040,.090,.260,1); intentional sRGB-to-linear night contribution","scope":"Current external file and effective Shader code identities cached once after restore; retained baked authoring hashes describe history. No geometry/material/clock rewrite, GPU uniform-buffer readback or art/performance claim."}
	return passed

func _apply_renderer_capabilities() -> void:
	var method: String = RenderingServer.get_current_rendering_method()
	var forward: bool = method=="forward_plus"
	# Startup AA is disabled in project settings; resolve only after the actual
	# renderer is known, including an engine-selected Compatibility fallback.
	var viewport: Viewport = get_viewport()
	viewport.use_taa = forward
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if method=="mobile" else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X if method=="gl_compatibility" else Viewport.MSAA_DISABLED
	var aa_policy: String = "forward_plus_taa" if forward else ("mobile_fxaa" if method=="mobile" else ("compatibility_msaa2" if method=="gl_compatibility" else "unsupported_renderer_none"))
	# Exact4.7 table: Compatibility supports SSAO/glow; Mobile omits SSAO.
	# Mac budget: the authored water shader retains its inexpensive reflection.
	# Screen-space reflections are omitted in this bounded Mac budget trial.
	environment.ssr_enabled = false
	environment.ssao_enabled = method in ["forward_plus","gl_compatibility"]
	sun.light_angular_distance = 3.0 if forward else 0.0
	# Fixed-width PCF softness reuses the renderer's existing sample budget.
	sun.shadow_blur = 1.5 if method=="mobile" else 1.0
	var omitted: Array[String] = []
	omitted.append("SSR")
	if not forward: omitted.append_array(["TAA","directional PCSS"])
	if method=="mobile": omitted.append("SSAO")
	renderer_capabilities = {"renderer":method,"snapshot":RENDERER_SNAPSHOT,"snapshot_sha256":FileAccess.get_sha256(RENDERER_SNAPSHOT),"proof":RENDERER_PROOF,"proof_sha256":FileAccess.get_sha256(RENDERER_PROOF),"original_snapshot_sha256":FileAccess.get_sha256("res://baked/clearing.res"),"omitted_effects":omitted,"taa_requested":viewport.use_taa,"antialiasing":{"policy":aa_policy,"taa":viewport.use_taa,"screen_space_aa":int(viewport.screen_space_aa),"msaa_3d":int(viewport.msaa_3d),"scaling_3d_scale":viewport.scaling_3d_scale,"quality_scope":"All environment quality tiers","scope":"Actual Viewport API readbacks after resolving the renderer; GPU effectiveness and physical-device cost remain unverified."},"ssr_requested":environment.ssr_enabled,"ssao_requested":environment.ssao_enabled,"directional_angular_distance":sun.light_angular_distance,"shadow_blur":sun.shadow_blur,"directional_filter_setting":ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"),"glow_requested":environment.glow_enabled,"fog_requested":environment.fog_enabled,"tonemap_mode":environment.tonemap_mode,"device_measured":false,"scope":"Renderer capability requests, not visual/performance parity. Glow/fog/tonemapping retain the authored values."}

func _apply_render_resolution_policy() -> void:
	# Keep the UI at the window resolution. Cap only Forward+ 3D shading work.
	# Small windows and the established 960-square views remain full resolution.
	var viewport: Viewport = get_viewport()
	var size: Vector2i = Vector2i(viewport.get_texture().get_size())
	if size.x<=0 or size.y<=0: size = get_window().size
	var pixels: float = float(size.x)*float(size.y)
	if pixels<=0.0: return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = minf(sqrt(_forward_pixel_budget(pixels)/pixels),1.0) if RenderingServer.get_current_rendering_method()=="forward_plus" else 1.0

func _forward_pixel_budget(output_pixels: float) -> float:
	# Full resolution through default720p and the960-square reference views.
	# Smoothly trim at most10% of the previous internal pixel budget by1080p.
	return lerpf(921600.0,829440.0,clampf((output_pixels-921600.0)/1152000.0,0.0,1.0))

func get_renderer_capabilities_report() -> Dictionary:
	var report: Dictionary = renderer_capabilities.duplicate(true)
	report["paving_collar_prebuilt"] = paving_collar_prebuilt_report.duplicate(true)
	report["path_backing"] = path_backing_report.duplicate(true)
	report["floor_prebuilt"] = floor_prebuilt_report.duplicate(true)
	report["stream_bank_closure"] = stream_bank_report.duplicate(true)
	report["soil_contact_prebuilt"] = soil_contact_report.duplicate(true)
	report["grown_room_foundation"] = grown_room_foundation_report.duplicate(true)
	report["annex_counter_collision"] = annex_counter_report.duplicate(true)
	report["annex_roof_prebuilt"] = annex_roof_prebuilt_report.duplicate(true)
	report["hero_stone_prebuilt"] = hero_stone_prebuilt_report.duplicate(true)
	report["effective_foliage_shader_provenance"] = effective_foliage_shader_provenance.duplicate(true)
	var viewport: Viewport = get_viewport()
	var output_size: Vector2i = Vector2i(viewport.get_texture().get_size())
	var scale: float = viewport.scaling_3d_scale
	report.antialiasing.scaling_3d_scale = scale
	report["render_resolution_policy"] = {"forward_plus_target_3d_pixels":_forward_pixel_budget(float(output_size.x)*float(output_size.y)),"small_window_full_resolution_through_pixels":921600,"large_window_target_3d_pixels":829440,"output_size":output_size,"estimated_internal_3d_size":Vector2i(floori(output_size.x*scale),floori(output_size.y*scale)),"requested_scale":scale,"scaling_mode":int(viewport.scaling_3d_mode),"ui_full_resolution":true,"size_scope":"Output texture and scale API readbacks; internal size is calculated, not a GPU buffer measurement.","approximation":"Bilinear 3D upscale in larger windows with a continuous area budget. Resolution policy preserves geometry and gameplay."}
	report["cap57_prebuilt"] = cap57_prebuilt_report.duplicate(true)
	report["plaster_arch_prebuilt"] = plaster_arch_prebuilt_report.duplicate(true)
	var rain_material: BaseMaterial3D = rain_particles.draw_pass_1.surface_get_material(0) as BaseMaterial3D
	report["rain_near_camera_fade"] = {"mode":int(rain_material.distance_fade_mode),"min_distance":rain_material.distance_fade_min_distance,"max_distance":rain_material.distance_fade_max_distance,"alpha":rain_material.albedo_color.a,"allocated_particles":rain_particles.amount,"scope":"Native material API requests; near-camera visual approximation, not particle collision or a measured GPU saving."}
	return report

func _release_scene_owners(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = null
		_release_scene_owners(child)

func set_environment_foreground(value: bool) -> void:
	_environment_foreground = value
	for particles: GPUParticles3D in [rain_particles,_fireflies]:
		if is_instance_valid(particles): particles.speed_scale = 0.0 if not value or get_tree().paused else 1.0

func _process(delta: float) -> void:
	var stopped: bool = not _environment_foreground or get_tree().paused
	for particles: GPUParticles3D in [rain_particles,_fireflies]:
		if is_instance_valid(particles): particles.speed_scale = 0.0 if stopped else 1.0
	if not is_finite(delta) or delta<0.0 or not _environment_foreground: return
	# Appearance menu interpolation is separate from running visual clocks.
	# Parent World historically remained ALWAYS; preserve its foreground-paused
	# night/rain transitions without advancing time, orbit, wind or sky follow.
	var step: float = minf(delta,0.25)
	if get_tree().paused:
		var old_night: float = night_amount
		var old_rain: float = rain_amount
		night_amount = move_toward(night_amount,_night_target,step/2.0)
		rain_amount = move_toward(rain_amount,_rain_target,step/2.0)
		if old_night!=night_amount or old_rain!=rain_amount: _apply_appearance()
		return
	# Discard catch-up from a stalled/resumed frame; physics remains fixed-step.
	super._process(step)

func shutdown_visuals() -> void:
	# Room masking changes compile this particle shader. Detach its shader too
	# before releasing the baked material graph; this is exclusively quit cleanup.
	if _rain_process != null:
		_rain_process.shader = null
	super.shutdown_visuals()
