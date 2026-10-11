extends RefCounted
## Three offline-authored annex roof meshes; one startup swap, no clipping/physics.
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ARTIFACT: String = "res://baked/annex-roof.res"
const ARTIFACT_SHA: String = "5dde4fa1d6a7826fc580339b970bff75396b34a5b9abc6312666f2d6183a58f1"
const PROOF: String = "res://baked/annex-roof-proof.json"
const SELF: String = "res://scripts/annex_roof_prebuilt.gd"
const READER_SHA: String = "35661bb43a42722eadc24018af8b25bb08b5d4959b117c13aaa3174f85784694"
const PATHS: Array = ["BatchedStaticWorld/Static_-9223371995566045738_-1_-1","BatchedStaticWorld/Static_-9223371994592967159_-1_-1","BatchedStaticWorld/Static_-9223371994626521592_-1_-1"]
const STUBS: Array = ["MushroomHome/OpenLeftAnnex/FoldedPeachUmbrella","MushroomHome/OpenLeftAnnex/CreamGillUnderside","MushroomHome/OpenLeftAnnex/ForkedCurvedLamellae"]
const ROLES: Array = ["peach_skin","gill_backing","radial_gills"]

static func install(world: Node3D,expected_proof_sha: String) -> Dictionary:
	var report: Dictionary={"schema":"mush-annex-roof-prebuilt-runtime/1","passed":false,"installed":false,"native_records_verified":false,"selected_nodes":[],"delta_triangles":-1170,"added_draws":0,"collision_changed":false,"geometry_generated":false,"perframe_work":false,"performance_measured":false}
	if world==null or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or expected_proof_sha.length()!=64:
		return _fail(report,"Exact ready world and fixed proof pin required")
	var file: FileAccess=FileAccess.open(PROOF,FileAccess.READ)
	if file==null: return _fail(report,"Roof proof missing")
	var length: int=file.get_length()
	if length<=0 or length>131072:
		file.close();return _fail(report,"Roof proof exceeds bounded size")
	var text: String=file.get_as_text();file.close()
	if FileAccess.get_sha256(PROOF)!=expected_proof_sha: return _fail(report,"Roof proof hash differs from fixed pin")
	var decoded: Variant=JSON.parse_string(text)
	if not decoded is Dictionary: return _fail(report,"Roof proof dictionary required")
	var proof: Dictionary=decoded
	if proof.get("schema","")!="mush-annex-roof-prebuilt-proof/1" or not proof.get("passed",false) or not proof.get("native_candidate_passed",false) or not proof.get("native_library_roundtrip_exact",false) or not proof.get("original_world_restored",false) or not proof.get("root_selected_for_next_isolated_source_checkpoint",false):
		return _fail(report,"Passed native authoring/roundtrip/rollback and root selection required")
	if proof.get("artifact","")!=ARTIFACT or proof.get("artifact_sha256","")!=ARTIFACT_SHA or proof.get("loader_sha256","")!=FileAccess.get_sha256(SELF) or proof.get("native_reader_sha256","")!=READER_SHA or FileAccess.get_sha256("res://scripts/cap57_prebuilt.gd")!=READER_SHA:
		return _fail(report,"Exact artifact/reader/loader provenance required")
	var artifact: FileAccess=FileAccess.open(ARTIFACT,FileAccess.READ)
	if artifact==null: return _fail(report,"Roof artifact missing")
	var bytes: int=artifact.get_length();artifact.close()
	if bytes!=2255664 or bytes!=proof.get("artifact_bytes",-1) or FileAccess.get_sha256(ARTIFACT)!=ARTIFACT_SHA:
		return _fail(report,"Exact bounded roof artifact required")
	var library: MeshLibrary=ResourceLoader.load(ARTIFACT,"MeshLibrary") as MeshLibrary
	if library==null or library.get_script()!=null or not library.get_meta_list().is_empty() or library.get_item_list()!=PackedInt32Array([0,1,2]) or not proof.get("meshes",null) is Array or proof.meshes.size()!=3:
		return _fail(report,"Exactly three unscripted material-free mesh items required")
	var nodes: Array[MeshInstance3D]=[];var stubs: Array[MeshInstance3D]=[]
	var originals: Array[ArrayMesh]=[];var candidates: Array[ArrayMesh]=[]
	var materials: Array[Material]=[];var before: Array[Dictionary]=[]
	# Admit all three original owners and resources before any pointer assignment.
	for index in range(3):
		if not proof.meshes[index] is Dictionary: return _fail(report,"Three ordered proof dictionaries required")
		var row: Dictionary=proof.meshes[index]
		var node: MeshInstance3D=world.get_node_or_null(PATHS[index]) as MeshInstance3D
		var stub: MeshInstance3D=world.get_node_or_null(STUBS[index]) as MeshInstance3D
		var candidate: ArrayMesh=library.get_item_mesh(index) as ArrayMesh
		if row.get("item",-1)!=index or row.get("role","")!=ROLES[index] or row.get("path","")!=PATHS[index] or row.get("stub","")!=STUBS[index] or not _owned(world,node,stub) or candidate==null:
			return _fail(report,"Exact three batch/stub/material owners required")
		if library.get_item_name(index)!=ROLES[index] or library.get_item_mesh_transform(index)!=Transform3D.IDENTITY or not library.get_item_shapes(index).is_empty() or library.get_item_navigation_mesh(index)!=null or library.get_item_preview(index)!=null:
			return _fail(report,"Meshes only: no transform/contact/navigation/preview payload")
		var original: ArrayMesh=node.mesh as ArrayMesh
		var old_record: Dictionary=NativeReader.mesh_record(original);var new_record: Dictionary=NativeReader.mesh_record(candidate)
		var node_record: Dictionary=NativeReader.node_record(node)
		if candidate==original or originals.has(original) or candidates.has(candidate) or not old_record.eligible or not new_record.eligible or not NativeReader._wire_descriptor_matches(old_record,row.get("original",{})) or not NativeReader._wire_descriptor_matches(new_record,row.get("candidate",{})) or not NativeReader._wire_descriptor_matches(node_record,row.get("node",{})) or var_to_bytes(old_record.configuration)!=var_to_bytes(new_record.configuration):
			return _fail(report,"Exact native all13/count/AABB/config/node descriptors required")
		if _native_sha(original)!=row.get("original_native_surface_sha256","") or _native_sha(candidate)!=row.get("candidate_native_surface_sha256",""):
			return _fail(report,"Exact original and candidate raw native surface bytes required")
		nodes.append(node);stubs.append(stub);originals.append(original);candidates.append(candidate);materials.append(node.material_override);before.append(node_record)
	for index in range(3): nodes[index].mesh=candidates[index]
	var installed: bool=true
	for index in range(3):
		installed=installed and nodes[index].mesh==candidates[index] and nodes[index].material_override==materials[index] and stubs[index].material_override==materials[index] and _owned(world,nodes[index],stubs[index]) and var_to_bytes(NativeReader.node_record(nodes[index]))==var_to_bytes(before[index]) and NativeReader._wire_descriptor_matches(NativeReader.mesh_record(candidates[index]),proof.meshes[index].candidate) and _native_sha(candidates[index])==proof.meshes[index].candidate_native_surface_sha256
	if not installed:
		for index in range(3): nodes[index].mesh=originals[index]
		var restored: bool=true
		for index in range(3):
			restored=restored and nodes[index].mesh==originals[index] and nodes[index].material_override==materials[index] and stubs[index].material_override==materials[index] and _owned(world,nodes[index],stubs[index]) and var_to_bytes(NativeReader.node_record(nodes[index]))==var_to_bytes(before[index]) and NativeReader._wire_descriptor_matches(NativeReader.mesh_record(originals[index]),proof.meshes[index].original) and _native_sha(originals[index])==proof.meshes[index].original_native_surface_sha256
		report["rolled_back"]=true;report["rollback_exact"]=restored
		return _fail(report,"Post-assignment readback refused; all three originals restored")
	for index in range(3):
		report.selected_nodes.append({"item":index,"role":ROLES[index],"path":PATHS[index],"old_arrays_sha256":proof.meshes[index].original.arrays_sha256,"installed_arrays_sha256":proof.meshes[index].candidate.arrays_sha256,"old_corners":int(proof.meshes[index].original.corners),"installed_corners":int(proof.meshes[index].candidate.corners),"original_material_pointer_preserved":true})
	report.merge({"passed":true,"installed":true,"native_records_verified":true,"artifact_sha256":ARTIFACT_SHA,"proof_sha256":expected_proof_sha,"old_triangles":24640,"installed_triangles":23470},true)
	return report

static func _owned(world: Node3D,node: MeshInstance3D,stub: MeshInstance3D) -> bool:
	return node!=null and stub!=null and node.mesh is ArrayMesh and stub.mesh==null and node.get_parent()==world.get_node_or_null("BatchedStaticWorld") and node.transform==Transform3D.IDENTITY and node.visible and node.is_visible_in_tree() and stub.position==Vector3(0,3.1,0) and node.material_override is ShaderMaterial and node.material_override==stub.material_override and node.get_active_material(0)==node.material_override and node.material_overlay==null

static func _native_sha(mesh: ArrayMesh) -> String:
	return NativeReader._sha(var_to_bytes(RenderingServer.mesh_get_surface(mesh.get_rid(),0)))

static func _fail(report: Dictionary,reason: String) -> Dictionary:
	report["failure"]=reason;return report
