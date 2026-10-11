extends RefCounted
## Once-only combined native mesh reader. No SurfaceTool/factory, remesh or frame work.
const ARTIFACT: String = "res://baked/plaster-arch-meshes.res"
const PROOF: String = "res://baked/plaster-arch-proof.json"
const SELF: String = "res://scripts/plaster_arch_prebuilt.gd"
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ORIGIN_PACKAGE_SHA: String = "42d9ae15da73a3201a5a02923d0fadd716a793a41eac9cac26bdb90f41114614"
const BASELINE_WORLD_SHA: String = "a35261b7ce4625eb1f98e1edac81777a4564005fd448359cebb790061475f6fc"
const AUTHOR_ASSET_PACKAGE_SHA: String = "fc2d7bbc33b29fe5642442bde940762ef2fb51967842ac7aa755ceacd661ab0b"
const HELPER_SHA: String = "124274eb99ebbe3dca49eea3ea3a6cde47433a05b15f53ce9483cfebd7d76bd1"
const AUTHOR_PROOF_SHA: String = "9e4c5b77a7b0fa1e2b16958e98b77d4eedff228b483bbaf7e361d45899839d78"
const AUTHOR_SHA: String = "9cc5fd2230be6963354bb019e01b314d178c73f4d584d2aec875e9c7e4bfee30"
const CORE04_SHA: String = "fcdcff4832253f1be11632a60f198a080d293c9047aa93f24ad1079742043811"
const ARTIFACT_SHA: String = "96b7dc8a81a9b80df46755b304e38af316b88ff637aec7336e2d774ba5329cf0"
const ARTIFACT_BYTES: int = 1217929
const NEW_COUNTS: Array[int] = [25956,12048]
const RAW_READER_SHA: String = "071b087ded52c3fa57bf9f0450cb4c4f61e0ba2bcc92be57955079d76e06ccb4"
const OWNERSHIP_SHA: String = "468e49215e5f3869efcd4fd54ce1cbcbc44bba3a3114f80f046d4d8c22d466dd"
const FACTORY_SHA: String = "a758c4d69479fd3ea445efb2fac1a4bd3f0b25ff337b8a76faed0b1516d6afc1"
const TACTILE_SHA: String = "30bcdcc8b07f0ced97bb088e04afa0d9d1799b9530554aebbab0309849f0bc32"
const FORMAT: int = 34359738399
const PATHS: Array[String] = ["BatchedStaticWorld/Static_-9223371995264055848_0_0","BatchedStaticWorld/Static_-9223371995264055848_-1_-1"]
const OWNERS: Array = [["MushroomHome/OrganicStemShell","MushroomHome/InnerPlaster"],["MushroomHome/OpenLeftAnnex/OrganicStemShell","MushroomHome/OpenLeftAnnex/InnerPlaster"]]
const COUNTS: Array[int] = [24480,11520]
const OLD_ARRAYS: Array[String] = ["4b5c48393571dc22a35c9c33780adc6b52ac35cd743015e26c59a8f76e60494a","9c1b93b80833f78ce66e884150ba4c76192c457ddbc96eb4f1137030a140e53c"]
const NEW_ARRAYS: Array[String] = ["45aa6fb98461945c1371ae1c37e320cbd2d18ef01a7aa90c4a421882a8971f6f","93719f55a31ea0397f1978248e2bb676fa57ae6aee07c14394429ed6007ea655"]
var _entries: Array[Dictionary] = []
var _world_id: int = 0
var _prepared: bool = false
var _installed: bool = false
var _report: Dictionary = {"schema":"mush-plaster-arch-prebuilt-runtime/1","passed":false,"prepared":false,"installed":false,"rolled_back":false,"geometry_generated":false,"perframe_work":false,"art_approved":false,"native_surface_buffer_bytes":1216128,"baseline_native_surface_buffer_bytes":1152000,"net_added_triangles":668,"added_encoded_bytes":64128,"grain":0.35,"grain_at_preparation":0.35,"last_verified_expected_grain":0.35,"last_fresh_verification_passed":false,"offline_unaffected_records_proof":true,"collider_changed":false,"runtime_authoring":false,"original_refs_retained":false,"selected_nodes":[]}

func get_report() -> Dictionary:
	return _report.duplicate(true)

func _fail(reason: String) -> Dictionary:
	_report["passed"] = false
	_report["failure"] = reason
	return get_report()

func install(world: Node3D,expected_proof_sha: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if expected_proof_sha!=AUTHOR_PROOF_SHA: return _fail("Exact closed combined author proof pin required")
	var handle: FileAccess = FileAccess.open(PROOF,FileAccess.READ)
	if handle==null: return _fail("Pinned combined proof cannot be opened")
	var length: int = handle.get_length()
	if length<=0 or length>2097152:
		handle.close(); return _fail("Bounded combined proof length refused")
	var text: String = handle.get_as_text(); handle.close()
	if FileAccess.get_sha256(PROOF)!=expected_proof_sha: return _fail("Actual combined proof file hash differs")
	var decoded: Variant = JSON.parse_string(text)
	if not decoded is Dictionary or not _proof_admitted(decoded): return _fail("Exact positive combined author proof refused")
	if FileAccess.get_sha256(NativeReader.ORIGINAL)!=NativeReader.ORIGINAL_SHA or FileAccess.get_sha256(NativeReader.NEUTRAL)!=NativeReader.NEUTRAL_SHA or FileAccess.get_sha256(NativeReader.NEUTRAL_PROOF)!=NativeReader.NEUTRAL_PROOF_SHA: return _fail("Retained original/neutral snapshots must remain exact")
	var artifact_file: FileAccess = FileAccess.open(ARTIFACT,FileAccess.READ)
	if artifact_file==null: return _fail("Native combined MeshLibrary missing")
	var bytes: int = artifact_file.get_length(); artifact_file.close()
	if bytes!=ARTIFACT_BYTES or FileAccess.get_sha256(ARTIFACT)!=ARTIFACT_SHA: return _fail("Exact native combined artifact bytes/hash refused")
	var library: MeshLibrary = ResourceLoader.load(ARTIFACT,"MeshLibrary",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	var prepared: Dictionary = prepare_verified(world,library,decoded)
	library=null
	if not prepared.get("passed",false) or not install_prepared(world): return get_report()
	_report["artifact_sha256"]=ARTIFACT_SHA; _report["proof_sha256"]=expected_proof_sha
	_report["runtime_loader_sha256"]=FileAccess.get_sha256(get_script().resource_path)
	_report["startup_wall_usec"]=Time.get_ticks_usec()-started
	_report["cost_scope"]="Once-only load/read/hash/two assignments. Encoded bytes exclude retained originals, resource objects, scratch, driver/RSS/GPU costs; no performance improvement claim."
	return get_report()

func _proof_admitted(proof: Dictionary) -> bool:
	if proof.get("schema","")!="mush-plaster-arch-combined-prebuilt/1" or proof.get("caller_sha256","")!=AUTHOR_SHA or proof.get("baseline_world_source_sha256","")!=BASELINE_WORLD_SHA or proof.get("package_sha256","")!=AUTHOR_ASSET_PACKAGE_SHA or proof.get("helper_sha256","")!=HELPER_SHA or proof.get("prior_native_core_sha256","")!=CORE04_SHA or proof.get("factory_sha256","")!=FACTORY_SHA or proof.get("raw_reader_sha256","")!=RAW_READER_SHA or proof.get("ownership_reader_sha256","")!=OWNERSHIP_SHA: return false
	for field: String in ["passed","off_tree_prepare_full_world_exact","baseline_installed_fresh_verified","candidate_installed_fresh_verified","native_serialization_roundtrip_exact","loaded_candidate_installed_fresh_verified","loaded_candidate_other_native_exact","actual_rollback_to041_full_exact","actual_rollback_to039_full_exact","all_other_native_resources_exact","no_process_frame_elapsed","all184_source_payloads_exact","known_triangle_and_buffer_cost_exact","material_aliases_and_grain_exact"]:
		if proof.get(field)!=true: return false
	if proof.get("errors",null)!=[] or proof.get("authoring_grain",-1.0)!=.35 or proof.get("grain_uniform_changed")!=false or proof.get("collider_patch_used")!=false or proof.get("controller_changed")!=false or proof.get("ideal_taper_used")!=false: return false
	var artifact: Variant=proof.get("artifact")
	if not artifact is Dictionary or artifact.get("class","")!="MeshLibrary" or artifact.get("items",0)!=2 or artifact.get("material_free")!=true or artifact.get("bytes",0)!=ARTIFACT_BYTES or artifact.get("sha256","")!=ARTIFACT_SHA: return false
	var rows: Variant=proof.get("selected_meshes")
	if not rows is Array or rows.size()!=2: return false
	for index: int in range(2):
		if not rows[index] is Dictionary or rows[index].get("item",-1)!=index or rows[index].get("path","")!=PATHS[index] or rows[index].get("roundtrip_all13_config_blob_AABB_buffers_exact")!=true or not rows[index].get("original039") is Dictionary or not rows[index].get("candidate") is Dictionary or not rows[index].candidate.get("descriptor") is Dictionary: return false
		if rows[index].original039.get("arrays_sha256","")!=OLD_ARRAYS[index] or rows[index].candidate.descriptor.get("arrays_sha256","")!=NEW_ARRAYS[index] or rows[index].candidate.descriptor.get("corners",0)!=NEW_COUNTS[index]: return false
	return true

func _stored(resource: Object) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)!=0: result[str(property.name)]=resource.get(property.name)
	return result

func _uniforms(material: ShaderMaterial) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in material.get_property_list():
		var name: String=String(property.name)
		if name.begins_with("shader_parameter/"): result[name]=material.get(name)
	return result

func _assignment_materials() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		rows.append({"material_id":str(entry.material.get_instance_id()),"stored":_stored(entry.material),"uniforms":_uniforms(entry.material)})
	return rows

func _library_admitted(library: MeshLibrary) -> bool:
	if library==null or library.get_script()!=null or not library.get_meta_list().is_empty() or library.resource_name!="" or library.resource_local_to_scene or library.get_item_list()!=PackedInt32Array([0,1]): return false
	for index: int in range(2):
		if library.get_item_name(index)!=("main" if index==0 else "annex") or library.get_item_mesh_transform(index)!=Transform3D.IDENTITY or library.get_item_mesh_cast_shadow(index)!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON or not library.get_item_shapes(index).is_empty() or library.get_item_navigation_mesh(index)!=null or library.get_item_navigation_mesh_transform(index)!=Transform3D.IDENTITY or library.get_item_navigation_layers(index)!=1 or library.get_item_preview(index)!=null: return false
	return true

func _native_buffers(mesh: ArrayMesh) -> Dictionary:
	var native: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(),0)
	var buffers: Dictionary = {}; var total: int=0
	for key: String in ["vertex_data","attribute_data","skin_data","index_data"]:
		var bytes: PackedByteArray = native.get(key,PackedByteArray())
		buffers[key]={"bytes":bytes.size(),"sha256":_sha(bytes)}; total+=bytes.size()
	return {"format":str(mesh.surface_get_format(0)),"native_vertices":mesh.surface_get_array_len(0),"buffers":buffers,"total_native_surface_buffer_bytes":total,"scope":"Encoded surface buffers only; excludes mesh object overhead, CPU scratch copies, retained originals, physics acceleration data and driver allocations. Not RSS or GPU timing."}

func _owned(world: Node3D,node: MeshInstance3D,index: int,expected_grain: float=.35) -> bool:
	if node==null or not node.mesh is ArrayMesh or node.global_transform!=Transform3D.IDENTITY or node.material_override==null or node.material_overlay!=null: return false
	var material: ShaderMaterial = node.material_override as ShaderMaterial
	if material==null or material.shader!=load("res://assets/world/tactile.gdshader") or material.next_pass!=null or _sha(material.shader.code.to_utf8_buffer())!=TACTILE_SHA: return false
	var expected: Dictionary = {"base_color":Color("eee2bd"),"accent_color":Color("c3b082"),"roughness_value":.92,"texture_scale":3.0,"grain":expected_grain,"grain_kind":1.0}
	for key: String in expected:
		if var_to_bytes(material.get_shader_parameter(key))!=var_to_bytes(expected[key]): return false
	for path: String in OWNERS[index]:
		var stub: MeshInstance3D = world.get_node_or_null(path) as MeshInstance3D
		if stub==null or stub.mesh!=null or stub.material_override!=material: return false
	return true

func _layout(mesh: ArrayMesh,count: int) -> Dictionary:
	if mesh==null or mesh.get_surface_count()!=1 or mesh.surface_get_format(0)!=FORMAT or mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES or mesh.surface_get_array_index_len(0)!=0: return {}
	var stored: Variant = mesh.get("_surfaces")
	if not stored is Array or stored.size()!=1 or not stored[0] is Dictionary: return {}
	var data: Dictionary = stored[0]
	var keys: Array[String] = ["format","primitive","vertex_data","vertex_count","attribute_data","aabb","uv_scale"]
	if data.size()!=keys.size() or not data.has_all(keys) or typeof(data.format)!=TYPE_INT or data.format!=FORMAT or typeof(data.primitive)!=TYPE_INT or data.primitive!=Mesh.PRIMITIVE_TRIANGLES or typeof(data.vertex_count)!=TYPE_INT or data.vertex_count!=count or not data.vertex_data is PackedByteArray or not data.attribute_data is PackedByteArray or not data.aabb is AABB or not data.uv_scale is Vector4: return {}
	if RenderingServer.mesh_surface_get_format_vertex_stride(FORMAT,count)!=12 or RenderingServer.mesh_surface_get_format_normal_tangent_stride(FORMAT,count)!=8 or RenderingServer.mesh_surface_get_format_attribute_stride(FORMAT,count)!=12 or RenderingServer.mesh_surface_get_format_skin_stride(FORMAT,count)!=0 or RenderingServer.mesh_surface_get_format_index_stride(FORMAT,count)!=0: return {}
	if RenderingServer.mesh_surface_get_format_offset(FORMAT,count,Mesh.ARRAY_VERTEX)!=0 or RenderingServer.mesh_surface_get_format_offset(FORMAT,count,Mesh.ARRAY_NORMAL)!=count*12 or RenderingServer.mesh_surface_get_format_offset(FORMAT,count,Mesh.ARRAY_TANGENT)!=count*12+4 or RenderingServer.mesh_surface_get_format_offset(FORMAT,count,Mesh.ARRAY_COLOR)!=0 or RenderingServer.mesh_surface_get_format_offset(FORMAT,count,Mesh.ARRAY_TEX_UV)!=4: return {}
	if data.vertex_data.size()!=count*20 or data.attribute_data.size()!=count*12: return {}
	return data

func _aliases(world: Node3D,installed: bool) -> bool:
	var uses: Dictionary = {}
	for entry: Dictionary in _entries:
		var selected: ArrayMesh = entry.candidate if installed else entry.old
		uses[str(selected.get_instance_id())] = 0
	for node: Node in world.get_tree().root.find_children("*","Node",true,false):
		var mesh: Mesh = null
		if node is MeshInstance3D: mesh=(node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			if mm!=null: mesh=mm.mesh
		if mesh==null: continue
		for entry: Dictionary in _entries:
			var selected: ArrayMesh = entry.candidate if installed else entry.old
			var inactive: ArrayMesh = entry.old if installed else entry.candidate
			if mesh==selected:
				if node!=entry.node: return false
				uses[str(selected.get_instance_id())]+=1
			if mesh==inactive or mesh is ArrayMesh and ((mesh as ArrayMesh).shadow_mesh==selected or (mesh as ArrayMesh).shadow_mesh==inactive): return false
	for amount: int in uses.values():
		if amount!=1: return false
	return true

func prepare_verified(world: Node3D,library: MeshLibrary,proof: Dictionary) -> Dictionary:
	var engine: Dictionary = Engine.get_version_info()
	if _prepared or _world_id!=0 or not _entries.is_empty() or world==null or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or engine.get("major")!=4 or engine.get("minor")!=7 or engine.get("patch")!=2: return _fail("Fresh ready identity world/exact Godot4.7.2 required")
	if not world.get("cap57_prebuilt_report") is Dictionary or not world.cap57_prebuilt_report.get("passed",false) or not world.cap57_prebuilt_report.get("installed",false): return _fail("Ordinary pinned snapshot/cap restore must precede combined plaster")
	if not _proof_admitted(proof) or not _library_admitted(library): return _fail("Exact two-item native MeshLibrary/closed author proof required")
	var result_rows: Array[Dictionary] = []
	for index: int in range(2):
		var row: Dictionary = proof.selected_meshes[index]
		var node: MeshInstance3D = world.get_node_or_null(PATHS[index]) as MeshInstance3D
		if not _owned(world,node,index): return _fail("Exact native original039 batch/stub/material ownership refused")
		var old: ArrayMesh = node.mesh as ArrayMesh
		var candidate: ArrayMesh = library.get_item_mesh(index) as ArrayMesh
		var old_record: Dictionary = NativeReader.mesh_record(old)
		var node_record: Dictionary = NativeReader.node_record(node)
		var old_layout: Dictionary = _layout(old,COUNTS[index])
		if old_layout.is_empty() or not old_record.get("eligible",false) or old_record.arrays_sha256!=OLD_ARRAYS[index] or old_record.corners!=COUNTS[index] or not NativeReader._wire_descriptor_matches(old_record,row.original039) or not NativeReader._wire_descriptor_matches(node_record,row.get("node_configuration",{})): return _fail("Actual original039 all13/config/node admission refused")
		var candidate_record: Dictionary = NativeReader.mesh_record(candidate)
		var new_layout: Dictionary = _layout(candidate,NEW_COUNTS[index])
		if new_layout.is_empty() or candidate==old or not candidate_record.get("eligible",false) or candidate_record.arrays_sha256!=NEW_ARRAYS[index] or candidate_record.corners!=NEW_COUNTS[index] or not NativeReader._wire_descriptor_matches(candidate_record,row.candidate.descriptor) or var_to_bytes(candidate_record.configuration)!=var_to_bytes(old_record.configuration): return _fail("Actual candidate all13/own AABB/config differs from closed native proof")
		var original_blob: String = _sha(var_to_bytes(old.get("_surfaces")))
		var candidate_blob: String = _sha(var_to_bytes(candidate.get("_surfaces")))
		var server_hash: String = _sha(var_to_bytes(RenderingServer.mesh_get_surface(candidate.get_rid(),0)))
		if candidate_blob!=row.candidate.get("raw_surface_sha256","") or server_hash!=row.candidate.get("rendering_server_surface_sha256","") or not NativeReader._wire_descriptor_matches(_native_buffers(candidate),row.candidate.get("buffers",{})): return _fail("Exact candidate blob/native buffers refused")
		var native_box: PackedByteArray = var_to_bytes(candidate.get_aabb())
		if native_box.hex_encode()!=row.candidate.get("aabb",{}).get("native_hex","") or _sha(native_box)!=row.candidate.get("aabb",{}).get("sha256",""): return _fail("Actual candidate own native AABB differs")
		_entries.append({"node":node,"old":old,"candidate":candidate,"material":node.material_override,"node_record":node_record,"original_record":old_record,"candidate_record":candidate_record,"original_blob_sha256":original_blob,"candidate_blob_sha256":candidate_blob,"candidate_server_sha256":server_hash,"candidate_buffers":_native_buffers(candidate)})
		result_rows.append({"path":PATHS[index],"original_corners":COUNTS[index],"candidate_corners":NEW_COUNTS[index],"format":str(FORMAT),"old_all13_sha256":OLD_ARRAYS[index],"candidate_all13_sha256":NEW_ARRAYS[index],"all13_expected_native_exact":true,"native_blob_and_buffer_exact":true,"configuration_exact":true,"original_and_candidate_own_AABB_exact":true,"material_aliases_exact":true,"offline_unaffected_records_proof":row.provenance_core04_costs,"shadow_alias_isolated":true})
	if _entries[0].old==_entries[1].old or _entries[0].candidate==_entries[1].candidate or not _aliases(world,false): return _fail("Two distinct native resources/isolated live aliases required")
	_world_id=world.get_instance_id(); _prepared=true
	_report.merge({"passed":true,"prepared":true,"original_refs_retained":true,"selected_nodes":result_rows,"all13_expected_native_exact":true,"native_blobs_exact":true,"geometry_generated":false,"perframe_work":false,"author_proof_sha256":AUTHOR_PROOF_SHA,"artifact_sha256":ARTIFACT_SHA},true)
	_report["scope"]="Original039 admission directly to offline combined041 directions/arch04 meshes. Existing materials remain grain.35. No runtime geometry authoring, collider/controller/ideal-taper change or per-frame verification. Unaffected-record proof is offline; complete actual loaded native13 bytes are freshly matched."
	return get_report()

func verify(world: Node3D,installed: bool,expected_grain: float=.35) -> bool:
	_report["last_fresh_verification_passed"]=false
	if var_to_bytes(expected_grain)!=var_to_bytes(.35) and var_to_bytes(expected_grain)!=var_to_bytes(.08): return false
	if not _prepared or world==null or not world.is_inside_tree() or world.get_instance_id()!=_world_id: return false
	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		var selected: ArrayMesh = entry.candidate if installed else entry.old
		var expected: Dictionary = entry.candidate_record if installed else entry.original_record
		if not is_instance_valid(entry.node) or entry.node.mesh!=selected or entry.node.material_override!=entry.material or not _owned(world,entry.node,index,expected_grain) or var_to_bytes(NativeReader.node_record(entry.node))!=var_to_bytes(entry.node_record) or var_to_bytes(NativeReader.mesh_record(selected))!=var_to_bytes(expected) or _sha(var_to_bytes(entry.old.get("_surfaces")))!=entry.original_blob_sha256 or _sha(var_to_bytes(entry.candidate.get("_surfaces")))!=entry.candidate_blob_sha256 or _sha(var_to_bytes(RenderingServer.mesh_get_surface(entry.candidate.get_rid(),0)))!=entry.candidate_server_sha256 or var_to_bytes(_native_buffers(entry.candidate))!=var_to_bytes(entry.candidate_buffers): return false
	var valid: bool=_aliases(world,installed)
	_report["last_fresh_verification_passed"]=valid
	if valid:
		_report["last_verified_expected_grain"]=expected_grain; _report["grain"]=expected_grain
	return valid

func install_prepared(world: Node3D) -> bool:
	if _installed or not verify(world,false):
		_fail("Prepared original aliases/native resources changed before assignment"); return false
	var material_before: Array[Dictionary] = _assignment_materials()
	for entry: Dictionary in _entries: entry.node.mesh=entry.candidate
	_installed = true
	if not verify(world,true) or var_to_bytes(_assignment_materials())!=var_to_bytes(material_before):
		for entry: Dictionary in _entries: entry.node.mesh=entry.old
		_installed = false
		_report["rolled_back"] = verify(world,false)
		_fail("Post-assignment native readback refused; original references restored"); return false
	_report.merge({"passed":true,"installed":true,"rolled_back":false,"mesh_reference_assignments":2,"live_verified":true,"retained_originals_unchanged":true,"assignment_material_maps_exact":true},true)
	return true

func rollback(world: Node3D) -> bool:
	if not _installed or not verify(world,true):
		_fail("Installed native ownership required for rollback"); return false
	var material_before: Array[Dictionary] = _assignment_materials()
	for entry: Dictionary in _entries: entry.node.mesh=entry.old
	_installed = false
	var valid: bool = verify(world,false) and var_to_bytes(_assignment_materials())==var_to_bytes(material_before)
	_report.merge({"passed":valid,"installed":false,"rolled_back":valid,"live_verified":valid,"retained_originals_unchanged":valid,"rollback_material_maps_exact":valid},true)
	if not valid: _fail("Original native aliases/readbacks refused after rollback")
	return valid

static func _sha(bytes: PackedByteArray) -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hash.update(bytes)
	return hash.finish().hex_encode()
