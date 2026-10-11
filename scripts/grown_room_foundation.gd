extends RefCounted
## Released for isolated native testing: once-only native child; existing room owns visibility and scale.
const DRAFT_ACCEPTED: bool = true
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ARTIFACT: String = "res://baked/foundation-grown-right.res"
const PROOF: String = "res://baked/grown-room-foundation-proof.json"
const ARTIFACT_SHA: String = "7fc5b92b7e6e334434c7cf4d23f1e00a0280947fde7a61ef7e1c8d615e855524"
const PROOF_SHA: String = "08cef5e7a28bf583817d53488ec2c9889816fdd80df2e79142a93ec3cf891614"
const SOIL_PATH: String = "BatchedStaticWorld/Static_-9223371995029174788_0_0"
const SOIL_ARRAYS: String = "d7db053201c76ef0fc9e0de38e936d84b90b6a7ebc9aa4280c5bb295346b7bbc"
const CHILD_NAME: String = "GrownRoomSoilContact"
const FLOOR: Dictionary = {"class":"CylinderMesh","origin":Vector3(0,.48,0),"count":392,"local_transform":"62d474c82df75def8532241d0bd62260fcf2200d7ad114ada9904ee084140209","arrays":"ec62ed7fe44dbad088b9b00afd7d702ba7385bd796da1c0c889723e29002a84d","native_surface":"884d1f1872671213bf5c1d8be18451788f7f97f8826e7939a2644acda657e621"}
const NECK: Dictionary = {"class":"BoxMesh","origin":Vector3(-1.62,.47,0),"count":24,"local_transform":"bf10b1bcc4589fae2e09659a9f9c08571101cf85d00a22b6b76eace9d8fbd2c5","arrays":"bfacca91f8abe4a2db489b1730cdbe9694c3f0d56b92c1d57f44cd29d94ff728","native_surface":"27210e0858aea6051bae19080941d4b8311a6716235978f0d42277e0b57cb86f"}
var _world: Node3D
var _room: Node3D
var _child: MeshInstance3D
var _mesh: ArrayMesh
var _soil_node: MeshInstance3D
var _soil_mesh: ArrayMesh
var _soil: ShaderMaterial
var _soil_record: Dictionary = {}
var _soil_surface: String
var _original_aliases: Array = []
var _sources: Array = []
var _expected: Dictionary = {}
var _surface: String
var _report: Dictionary = {"schema":"mush-grown-room-foundation-runtime/1","passed":false,"installed":false,"rolled_back":false,"geometry_generated":false,"perframe_work":false,"new_draw_nodes":1,"new_materials":0,"new_colliders":0,"corners":696,"triangles":232,"material_free_resource":true,"performance_measured":false,"art_approved":false,"merged_soil_excludes_dynamic_right":true}

func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()

func _fail(reason: String) -> Dictionary:
	_report["passed"]=false;_report["failure"]=reason;return get_report()

func get_report() -> Dictionary:
	return _report.duplicate(true)

func _aliases() -> Array:
	var result: Array = []
	for node: Node in _world.find_children("*","GeometryInstance3D",true,false):
		if node.material_override==_soil: result.append(str(_world.get_path_to(node)))
	return result

func _local_matches(node: MeshInstance3D,spec: Dictionary) -> bool:
	if not is_instance_valid(node) or node.get_parent()!=_room or node.mesh==null or node.mesh.get_class()!=spec["class"] or node.mesh.get_surface_count()!=1: return false
	var arrays: Array = node.mesh.surface_get_arrays(0)
	return arrays.size()==Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array and arrays[Mesh.ARRAY_VERTEX].size()==int(spec.count) and _sha(var_to_bytes(node.transform))==spec.local_transform and _sha(var_to_bytes(arrays))==spec.arrays and _sha(var_to_bytes(RenderingServer.mesh_get_surface(node.mesh.get_rid(),0)))==spec.native_surface and node.material_override==_world._materials["floor"] and node.get_active_material(0)==node.material_override

func _original_matches() -> bool:
	if not is_instance_valid(_world) or not is_instance_valid(_room) or _world.right_room!=_room or _room.name!="GrowableRightRoom" or _room.position!=Vector3(4.95,0,.60): return false
	if not is_instance_valid(_soil_node) or _soil_node.mesh!=_soil_mesh or _soil_node.material_override!=_soil or _soil!=_world._materials["soil"] or _soil_node.get_active_material(0)!=_soil: return false
	if _sha(var_to_bytes(NativeReader.mesh_record(_soil_mesh)))!=_sha(var_to_bytes(_soil_record)) or _sha(var_to_bytes(RenderingServer.mesh_get_surface(_soil_mesh.get_rid(),0)))!=_soil_surface: return false
	for row: Dictionary in _sources:
		if not is_instance_valid(row.node) or row.node.mesh!=row.mesh or not _local_matches(row.node,row.spec): return false
	return true

func install(world: Node3D,expected_proof_sha: String=PROOF_SHA,artifact_path: String=ARTIFACT,proof_path: String=PROOF) -> Dictionary:
	if not DRAFT_ACCEPTED: return _fail("Disabled pending root loader verification/release")
	if world==null or expected_proof_sha!=PROOF_SHA or FileAccess.get_sha256(proof_path)!=PROOF_SHA or FileAccess.get_sha256(artifact_path)!=ARTIFACT_SHA: return _fail("Pinned native artifact/proof missing or changed")
	if _report.installed:
		if artifact_path!=_report.get("artifact_path","") or proof_path!=_report.get("proof_path",""): return _fail("Idempotent input paths differ")
		if world!=_world or not verify(world): return _fail("Idempotent installed ownership refused")
		_report["idempotent_install"]=true;_report["passed"]=true;_report.erase("failure");return get_report()
	if _world!=null: return _fail("One reader instance owns one installation")
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(proof_path))
	if not proof is Dictionary or proof.get("schema","")!="mush053-grown-foundation/1" or not proof.get("passed",false) or not proof.get("scene_restored",false) or not proof.get("actual_added_node_removal",false): return _fail("Closed native author/restoration required")
	for field: String in ["passed","material_free","complete_all13_config_aabb_exact","complete_native_buffers_exact","held_original_resource_exact","saved_after_all_capture_lifecycle_removal_checks"]:
		if not proof.artifact.get(field,false): return _fail("Native serialization field refused: "+field)
	if proof.artifact.sha256!=ARTIFACT_SHA or int(proof.artifact.bytes)!=22861 or int(proof.geometry.corners)!=696 or int(proof.geometry.triangles)!=232: return _fail("Exact authored cost/identity refused")
	var loaded: ArrayMesh = ResourceLoader.load(artifact_path,"ArrayMesh") as ArrayMesh
	if loaded==null: return _fail("Native ArrayMesh load refused")
	var actual: Dictionary = NativeReader.mesh_record(loaded)
	var surface: String = _sha(var_to_bytes(RenderingServer.mesh_get_surface(loaded.get_rid(),0)))
	if not actual.get("eligible",false) or not NativeReader._wire_descriptor_matches(actual,proof.artifact.loaded_native_record) or surface!=proof.geometry.native_surface_sha256: return _fail("Native all13/config/AABB/buffers refused")
	var room: Node3D = world.right_room as Node3D
	var source: MeshInstance3D = world.get_node_or_null(SOIL_PATH) as MeshInstance3D
	if room==null or room.get_node_or_null(CHILD_NAME)!=null or source==null or not source.mesh is ArrayMesh or not source.material_override is ShaderMaterial or source.material_override!=world._materials["soil"] or source.get_active_material(0)!=source.material_override: return _fail("Existing room/soil ownership refused")
	var soil_record: Dictionary = NativeReader.mesh_record(source.mesh as ArrayMesh)
	if not soil_record.get("eligible",false) or soil_record.corners!=33249 or soil_record.arrays_sha256!=SOIL_ARRAYS: return _fail("Actual existing merged soil required")
	_world=world;_room=room;_soil_node=source;_soil_mesh=source.mesh;_soil=source.material_override;_soil_record=soil_record;_soil_surface=_sha(var_to_bytes(RenderingServer.mesh_get_surface(_soil_mesh.get_rid(),0)))
	for spec: Dictionary in [FLOOR,NECK]:
		var matched: Array = []
		for node: Node in room.find_children("*","MeshInstance3D",true,false):
			if node.position==spec.origin and _local_matches(node,spec): matched.append(node)
		if matched.size()!=1: return _fail("Unique fixed local floor/neck packet refused")
		_sources.append({"node":matched[0],"mesh":matched[0].mesh,"spec":spec})
	if not _original_matches(): return _fail("Original local resources refused")
	_original_aliases=_aliases();_mesh=loaded;_expected=actual;_surface=surface
	_child=MeshInstance3D.new();_child.name=CHILD_NAME;_child.mesh=_mesh;_child.material_override=_soil
	_room.add_child(_child)
	_report["installed"]=true
	if not verify(world):
		_room.remove_child(_child);_child.free();_child=null;_report["installed"]=false
		return _fail("Actual new-child verification refused; child removed")
	_report.merge({"passed":true,"artifact_path":artifact_path,"proof_path":proof_path,"artifact_sha256":ARTIFACT_SHA,"proof_sha256":PROOF_SHA,"owner_path":str(world.get_path_to(room)),"child_path":str(world.get_path_to(_child)),"native_arrays_sha256":actual.arrays_sha256,"local_floor_admission_independent_of_parent_scale":true,"parent_owns_visibility_scale":true,"shared_soil_material":true,"original_refs_retained":true},true)
	return get_report()

func verify(world: Node3D) -> bool:
	var valid: bool = world==_world and _report.installed and _original_matches() and is_instance_valid(_child)
	if valid:
		valid=_child.get_parent()==_room and _child.name==CHILD_NAME and _child.transform==Transform3D.IDENTITY and not _child.top_level and _child.visible and _child.is_visible_in_tree()==_room.is_visible_in_tree() and var_to_bytes(_child.global_transform)==var_to_bytes(_room.global_transform) and _child.get_script()==null and _child.material_overlay==null and _child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON and _child.layers==1 and _child.extra_cull_margin==0.0 and _child.mesh==_mesh and _child.material_override==_soil and _child.get_active_material(0)==_soil and _child.get_children().is_empty() and var_to_bytes(NativeReader.mesh_record(_mesh))==var_to_bytes(_expected) and _sha(var_to_bytes(RenderingServer.mesh_get_surface(_mesh.get_rid(),0)))==_surface
	if valid:
		for index in range(_child.get_surface_override_material_count()): valid=valid and _child.get_surface_override_material(index)==null
	if valid:
		var current: Array = _aliases();var path: String = str(world.get_path_to(_child))
		valid=current.count(path)==1;current.erase(path);valid=valid and current==_original_aliases
	_report["last_fresh_verification_passed"]=valid
	return valid

func rollback(world: Node3D) -> bool:
	if not verify(world): _fail("Positive owned installation required for rollback");return false
	_room.remove_child(_child);_child.free();_child=null
	var valid: bool = _original_matches() and _aliases()==_original_aliases
	_report.merge({"passed":valid,"installed":false,"rolled_back":valid,"actual_owned_child_removed":true,"original_refs_retained":valid},true)
	if valid: _report.erase("failure")
	return valid
