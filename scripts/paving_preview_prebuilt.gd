extends "res://scripts/paving_collar_prebuilt.gd"
## Portable startup owner for the private192/179 preview. The existing043
## owner remains genuine and retains its resources. No authoring or per-frame work.
const PREVIEW_SELF236 := "res://scripts/paving_preview_prebuilt.gd"
const PREVIEW_ARTIFACT236 := "res://baked/paving-preview192.res"
const PREVIEW_MANIFEST236 := "res://baked/paving-preview192.json"
const PREVIEW_ARTIFACT_SHA236 := "6d5d78516898be3099d0496f07f02057b28b8eb944091d4b27b1018592657aa9"
const PREVIEW_CONTACT_SHA236 := "dd340a548d27f0e57de9e40dd01642d8a4068e3a079495bba52fb9e1f72b10ef"
const SOURCE194_SHA236 := "55c1b3266d918c899f77e77097c7e883a1d8e629e756984e1cfc5a96b27d6249"
const BASELINE_LOADER_SHA236 := "b469bece311013c376633b2d31200fcfbdcc3c3d848284de96981981335da337"
const BASELINE_PROOF_SHA236 := "6e006ca6f902a3f28b6d3909f8a1799cc57f6a197f59c378b0b7f49502915e51"
const READER_SHA236 := "35661bb43a42722eadc24018af8b25bb08b5d4959b117c13aaa3174f85784694"
const CURRENT043_ARRAYS236 := ["60f46d69189382a5feac985744db5228b224e058593ec088ea15accd6c0f44da","71047c3099ba56cced5cdb38227f40493a46bdcc04b8753efc21de5fbb98b533","c733d0127f2085cb2493b85209b4ffe7fc2bd0c5843492ae7ca10a49b07008fd"]
const PREVIEW_CORNERS236 := [4638,3078,9501]
var original_owner236: RefCounted

func install(world: Node3D,expected_proof_sha: String) -> Dictionary:
	_report["schema"]="mush-paving-preview-runtime236/1"
	_report.merge({"private_preview":true,"full58_acceptance":false,"near_cut_contact_coverage_verified":false,"visual_fidelity_accepted":false,"sustained_performance_verified":false,"physical_mobile_tested":false,"production_adoption":false},true)
	var engine: Dictionary=Engine.get_version_info()
	if _prepared or _world_id!=0 or world==null or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or [engine.major,engine.minor,engine.patch]!=[4,7,2]: return _fail("Fresh identity World and exact Godot4.7.2 required")
	if FileAccess.get_sha256("res://scripts/paving_collar_prebuilt.gd")!=BASELINE_LOADER_SHA236 or FileAccess.get_sha256(PROOF)!=BASELINE_PROOF_SHA236 or FileAccess.get_sha256(NativeReader.SELF)!=READER_SHA236: return _fail("Retained startup owner/proof/native reader pins refused")
	original_owner236=world.get("paving_collar_prebuilt") as RefCounted
	if original_owner236==null or original_owner236==self or not bool(original_owner236.call("verify",world,true)): return _fail("Actual installed original043 owner required")
	var baseline: Dictionary=original_owner236.call("get_report")
	if not baseline.get("passed",false) or not baseline.get("installed",false) or baseline.get("proof_sha256","")!=BASELINE_PROOF_SHA236 or baseline.get("artifact_sha256","")!=ARTIFACT_SHA: return _fail("Original043 runtime authority refused")
	var handle: FileAccess=FileAccess.open(PREVIEW_MANIFEST236,FileAccess.READ)
	if handle==null: return _fail("Preview manifest missing")
	var length: int=handle.get_length()
	if length<=0 or length>65536: handle.close(); return _fail("Bounded preview manifest refused")
	var text: String=handle.get_as_text(); handle.close()
	if expected_proof_sha.length()!=64 or FileAccess.get_sha256(PREVIEW_MANIFEST236)!=expected_proof_sha: return _fail("Exact preview manifest hash refused")
	var decoded: Variant=JSON.parse_string(text)
	if not decoded is Dictionary: return _fail("Preview manifest dictionary required")
	_proof=decoded
	if _proof.get("schema","")!="mush-paving-preview192/1" or not _proof.get("native_authoring_save_reload_exact",false) or _proof.get("runtime_loader_sha256","")!=FileAccess.get_sha256(PREVIEW_SELF236) or _proof.get("baseline_loader_sha256","")!=BASELINE_LOADER_SHA236 or _proof.get("baseline_proof_sha256","")!=BASELINE_PROOF_SHA236 or _proof.get("native_mesh_reader_sha256","")!=READER_SHA236 or _proof.get("source194_proof_sha256","")!=SOURCE194_SHA236: return _fail("Preview manifest provenance refused")
	if _proof.get("artifact_sha256","")!=PREVIEW_ARTIFACT_SHA236 or _proof.get("artifact_bytes",0)!=641570 or _proof.get("contact_sha256","")!=PREVIEW_CONTACT_SHA236 or _proof.get("contact_corners",0)!=7323 or _proof.get("shape_configuration_sha256","")!=SHAPE_CONFIG_SHA or not _proof.get("expected_native_items",null) is Array or _proof.expected_native_items.size()!=3: return _fail("Exact final192 resource/contact descriptors required")
	for key: String in ["full58_acceptance","visual_fidelity_accepted","sustained_performance_verified","physical_mobile_tested"]:
		if not _proof.has(key) or _proof[key]!=false: return _fail("Private-preview acceptance scope refused: "+key)
	var file: FileAccess=FileAccess.open(PREVIEW_ARTIFACT236,FileAccess.READ)
	if file==null: return _fail("Preview resource missing")
	var bytes: int=file.get_length(); file.close()
	if bytes!=641570 or FileAccess.get_sha256(PREVIEW_ARTIFACT236)!=PREVIEW_ARTIFACT_SHA236: return _fail("Exact final192 artifact refused")
	var library: MeshLibrary=ResourceLoader.load(PREVIEW_ARTIFACT236,"MeshLibrary",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	if not _library_exact(library): return _fail("Three material-free preview meshes and one shape required")
	var baseline_entries: Array=original_owner236.get("_entries")
	if baseline_entries.size()!=3: return _fail("Three original043 resource owners required")
	for item: int in range(3):
		var node: MeshInstance3D=world.get_node_or_null(PATHS[item]) as MeshInstance3D
		var candidate: ArrayMesh=library.get_item_mesh(item) as ArrayMesh
		if node==null or node.get_parent()!=world.get_node_or_null("BatchedStaticWorld") or not node.mesh is ArrayMesh or candidate==null or node.mesh==candidate or node.mesh!=baseline_entries[item].candidate or node.transform!=Transform3D.IDENTITY or node.global_transform!=Transform3D.IDENTITY or not node.visible or not node.is_visible_in_tree() or node.material_overlay!=null or not node.material_override is ShaderMaterial: return _fail("Original selected batch/resource/material ownership refused")
		var old: ArrayMesh=node.mesh as ArrayMesh
		var material: ShaderMaterial=node.material_override as ShaderMaterial
		var native: Dictionary=_native_prebuilt_record(candidate)
		var old_native: Dictionary=_native_prebuilt_record(old)
		if material.shader==null or material.shader.resource_path!="res://assets/world/tactile.gdshader" or _sha(material.shader.code.to_utf8_buffer())!=SHADER_SHA: return _fail("Retained paving shader required")
		for surface: int in range(node.get_surface_override_material_count()):
			if node.get_surface_override_material(surface)!=null: return _fail("Unexpected selected surface override")
		if old_native.all13_sha256!=CURRENT043_ARRAYS236[item] or not NativeReader.mesh_record(candidate).get("eligible",false) or candidate.surface_get_array_len(0)!=PREVIEW_CORNERS236[item] or not NativeReader._wire_descriptor_matches(native,_proof.expected_native_items[item]) or var_to_bytes(_mesh_configuration(old))!=var_to_bytes(_mesh_configuration(candidate)): return _fail("Actual all13/native buffers/config/bounds refused")
		_entries.append({"node":node,"old":old,"candidate":candidate,"material":material,"shader":material.shader,"state":_node_state(node,["mesh"]),"old_native":old_native,"candidate_native":native})
	_body=world.get_node_or_null(BODY_PATH) as StaticBody3D
	_collision=world.get_node_or_null(COLLIDER_PATH) as CollisionShape3D
	if _body==null or _collision==null or _collision.get_parent()!=_body or _body.collision_layer!=1 or _body.collision_mask!=2 or _collision.disabled or _collision.global_transform!=Transform3D.IDENTITY or _body.get_meta("entrance48_step_surface",false)!=true: return _fail("Original registered paving body/configuration required")
	_shape_old=_collision.shape as ConcavePolygonShape3D
	_shape_new=library.get_item_shapes(0)[0] as ConcavePolygonShape3D
	_shape_owner_id=int(original_owner236.get("_shape_owner_id")); _shape_index=int(original_owner236.get("_shape_index"))
	if _shape_old==null or _shape_new==null or _shape_old==_shape_new or _shape_old!=original_owner236.get("_shape_new") or _shape_old.get_faces().size()!=7989 or _sha(_shape_old.get_faces().to_byte_array())!=NEW_CONTACT_SHA or _shape_new.get_faces().size()!=7323 or _sha(_shape_new.get_faces().to_byte_array())!=PREVIEW_CONTACT_SHA236 or _sha(var_to_bytes(_shape_configuration(_shape_old)))!=SHAPE_CONFIG_SHA or var_to_bytes(_shape_configuration(_shape_old))!=var_to_bytes(_shape_configuration(_shape_new)) or not _body_binding_exact(_shape_old) or PhysicsServer3D.body_get_shape(_body.get_rid(),_shape_index)!=_shape_old.get_rid(): return _fail("Original/current contact packet/config/owner/RID refused")
	_body_state=_body_native_state(); _collision_state=_node_state(_collision,["shape"]); _world_id=world.get_instance_id()
	if not _aliases(world,false): return _fail("Unique original mesh/contact aliases required")
	_prepared=true
	_report.merge({"passed":true,"prepared":true,"artifact_sha256":PREVIEW_ARTIFACT_SHA236,"proof_sha256":expected_proof_sha,"runtime_loader_sha256":FileAccess.get_sha256(PREVIEW_SELF236),"original_refs_retained":true,"original043_owner_never_mutated":true,"current_contact_sha256":PREVIEW_CONTACT_SHA236,"contact_corners":7323,"preview_mesh_corners":PREVIEW_CORNERS236,"encoded_render_buffer_bytes":550944,"contact_XYZ_bytes":87876,"geometry_generated":false,"perframe_work":false,"cost_scope":"Static encoded packets only; retained baseline/resources, allocations, loading/frame times and device costs are unmeasured."},true)
	if not verify(world,false): return _fail("Prepared original preview bindings refused")
	if not install_prepared(world): return get_report()
	return get_report()

func verify(world: Node3D,installed: bool) -> bool:
	if not _prepared or world==null or not world.is_inside_tree() or world.get_instance_id()!=_world_id or original_owner236==null or world.get("paving_collar_prebuilt")!=original_owner236: return false
	for entry: Dictionary in _entries:
		var active: ArrayMesh=entry.candidate if installed else entry.old
		var expected: Dictionary=entry.candidate_native if installed else entry.old_native
		if not is_instance_valid(entry.node) or entry.node.mesh!=active or entry.node.material_override!=entry.material or entry.material.shader!=entry.shader or var_to_bytes(_node_state(entry.node,["mesh"]))!=var_to_bytes(entry.state) or var_to_bytes(_native_prebuilt_record(active))!=var_to_bytes(expected) or var_to_bytes(_native_prebuilt_record(entry.old))!=var_to_bytes(entry.old_native) or var_to_bytes(_native_prebuilt_record(entry.candidate))!=var_to_bytes(entry.candidate_native): return false
	var shape: ConcavePolygonShape3D=_shape_new if installed else _shape_old
	if not is_instance_valid(_collision) or _collision.shape!=shape or not _body_binding_exact(shape) or PhysicsServer3D.body_get_shape(_body.get_rid(),_shape_index)!=shape.get_rid() or var_to_bytes(_body_native_state())!=var_to_bytes(_body_state) or var_to_bytes(_node_state(_collision,["shape"]))!=var_to_bytes(_collision_state): return false
	# Live environmental uniforms are legitimate. The inherited assignment and
	# rollback operations compare contemporaneous material maps around mutation.
	if _sha(_shape_old.get_faces().to_byte_array())!=NEW_CONTACT_SHA or _sha(_shape_new.get_faces().to_byte_array())!=PREVIEW_CONTACT_SHA236 or _sha(var_to_bytes(_shape_configuration(_shape_old)))!=SHAPE_CONFIG_SHA or var_to_bytes(_shape_configuration(_shape_old))!=var_to_bytes(_shape_configuration(_shape_new)): return false
	return _aliases(world,installed) and (installed or bool(original_owner236.call("verify",world,true)))

func rollback(world: Node3D) -> bool:
	var restored: bool=super.rollback(world)
	_report["original043_owner_reverified_after_rollback"]=restored and bool(original_owner236.call("verify",world,true))
	return restored and bool(_report.original043_owner_reverified_after_rollback)

func release() -> void:
	if _installed: return
	_entries.clear(); _body=null; _collision=null; _shape_old=null; _shape_new=null
	_body_state.clear(); _collision_state.clear(); _proof.clear()
	original_owner236=null; _prepared=false
