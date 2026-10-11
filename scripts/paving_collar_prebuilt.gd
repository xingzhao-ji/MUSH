extends RefCounted
## Once-only native resource reader. Materials and authoring code are untouched.
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ARTIFACT := "res://baked/paving-collar.res"
const PROOF := "res://baked/paving-collar-proof.json"
const SELF := "res://scripts/paving_collar_prebuilt.gd"
const ARTIFACT_SHA := "78896f84b340e02e1301069f50017a49ff287cedb0487bdd1bb42892f5719a7a"
const ARTIFACT_BYTES := 682394
const AUTHOR_SHA := "e61f4546db82a7defe6c9e6fa750a24ed5c4b33c2d3325e9cb02da1f83da0f4d"
const SHADER_SHA := "30bcdcc8b07f0ced97bb088e04afa0d9d1799b9530554aebbab0309849f0bc32"
const PATHS := ["BatchedStaticWorld/Static_-9223371981221525344_0_0","BatchedStaticWorld/Static_-9223371981288634209_0_0","BatchedStaticWorld/Static_-9223371981355743074_0_0"]
const OLD_ARRAYS := ["2cc6d15cf8c6b2cd798276f465a720505d2fd4c774ea0feeb00cd0139bacdc44","7e06d53314929139b09eddfebd5a7ac082a0627a557866bd4faa5c3106075f5b","a09e12d13bce24b94e607cfc8d7fb190b99c5f31791e35d8feefb446c7c567fa"]
const OLD_COUNTS := [972,2526,8445]
const NEW_COUNTS := [5112,3246,9885]
const BODY_PATH := "MushroomHome/@StaticBody3D@339"
const COLLIDER_PATH := BODY_PATH+"/@CollisionShape3D@340"
const OLD_CONTACT_SHA := "19ac6ebf1e819cd9fa370724670abdfd2ab2f15210dde71f8332aa6cd92b78cb"
const NEW_CONTACT_SHA := "1d312ca39437fc262996c999b5eabf0e95d1598d4344e304b3563d5beb49e915"
const SHAPE_CONFIG_SHA := "970e21c18f9ae8a7129b463fdcf6421e03df87f004881456174dde2444ca45b5"
var _entries: Array[Dictionary]=[]
var _world_id: int=0
var _prepared: bool=false
var _installed: bool=false
var _body: StaticBody3D
var _collision: CollisionShape3D
var _shape_old: ConcavePolygonShape3D
var _shape_new: ConcavePolygonShape3D
var _shape_owner_id: int=0
var _shape_index: int=0
var _body_state: Dictionary={}
var _collision_state: Dictionary={}
var _proof: Dictionary={}
var _report: Dictionary={"schema":"mush-paving-collar-prebuilt-runtime/1","passed":false,"prepared":false,"installed":false,"rolled_back":false,"geometry_generated":false,"perframe_work":false,"material_assignments":0,"mesh_reference_assignments":0,"shape_reference_assignments":0,"visual_soil_contact_faces":0}

func get_report() -> Dictionary:
	return _report.duplicate(true)

func _fail(reason: String) -> Dictionary:
	_report["passed"]=false;_report["failure"]=reason
	return get_report()

func install(world: Node3D,expected_proof_sha: String) -> Dictionary:
	var engine: Dictionary=Engine.get_version_info()
	if _prepared or _world_id!=0 or world==null or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or [engine.major,engine.minor,engine.patch]!=[4,7,2]:return _fail("Fresh identity world/exact Godot4.7.2 required")
	if not world.get("cap57_prebuilt_report") is Dictionary or not world.cap57_prebuilt_report.get("passed",false) or not world.cap57_prebuilt_report.get("installed",false) or not world.get("plaster_arch_prebuilt_report") is Dictionary or not world.plaster_arch_prebuilt_report.get("passed",false) or not world.plaster_arch_prebuilt_report.get("installed",false) or world.get("_r25_ready_top")!=false:return _fail("Pinned cap/plaster startup and original native contact authority required")
	var handle: FileAccess=FileAccess.open(PROOF,FileAccess.READ)
	if handle==null:return _fail("Pinned paving proof cannot be opened")
	var length: int=handle.get_length()
	if length<=0 or length>1048576:handle.close();return _fail("Bounded paving proof length refused")
	var text: String=handle.get_as_text();handle.close()
	if expected_proof_sha.length()!=64 or FileAccess.get_sha256(PROOF)!=expected_proof_sha:return _fail("Exact paving proof hash refused")
	var decoded: Variant=JSON.parse_string(text)
	if not decoded is Dictionary:return _fail("Paving proof dictionary required")
	_proof=decoded
	if _proof.get("schema","")!="mush-paving-collar-native-resource-proof/1" or not _proof.get("native_authoring_save_reload_exact",false) or _proof.get("author_result_sha256","")!=AUTHOR_SHA or _proof.get("runtime_loader_sha256","")!=FileAccess.get_sha256(SELF) or _proof.get("native_mesh_reader_sha256","")!=FileAccess.get_sha256(NativeReader.SELF) or _proof.get("artifact_sha256","")!=ARTIFACT_SHA or _proof.get("artifact_bytes",0)!=ARTIFACT_BYTES or not _proof.get("expected_native_items") is Array or _proof.expected_native_items.size()!=3:return _fail("Exact native resource/reader provenance refused")
	if FileAccess.get_sha256(NativeReader.ORIGINAL)!=NativeReader.ORIGINAL_SHA or FileAccess.get_sha256(NativeReader.NEUTRAL)!=NativeReader.NEUTRAL_SHA or FileAccess.get_sha256(NativeReader.NEUTRAL_PROOF)!=NativeReader.NEUTRAL_PROOF_SHA:return _fail("Retained original/neutral snapshot pins refused")
	var file: FileAccess=FileAccess.open(ARTIFACT,FileAccess.READ)
	if file==null:return _fail("Native paving MeshLibrary missing")
	var size: int=file.get_length();file.close()
	if size!=ARTIFACT_BYTES or FileAccess.get_sha256(ARTIFACT)!=ARTIFACT_SHA:return _fail("Exact paving artifact bytes/hash refused")
	var library: MeshLibrary=ResourceLoader.load(ARTIFACT,"MeshLibrary",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	if not _library_exact(library):return _fail("Three material-free meshes/one contact shape required")
	for i: int in range(3):
		var node: MeshInstance3D=world.get_node_or_null(PATHS[i]) as MeshInstance3D
		if node==null or node.get_parent()!=world.get_node_or_null("BatchedStaticWorld") or not node.mesh is ArrayMesh or node.transform!=Transform3D.IDENTITY or node.global_transform!=Transform3D.IDENTITY or not node.visible or not node.is_visible_in_tree() or node.material_overlay!=null or not node.material_override is ShaderMaterial:return _fail("Exact native selected batch/material ownership refused")
		var material: ShaderMaterial=node.material_override as ShaderMaterial
		if material.shader==null or material.shader.resource_path!="res://assets/world/tactile.gdshader" or _sha(material.shader.code.to_utf8_buffer())!=SHADER_SHA:return _fail("Original paving shader required")
		for surface: int in range(node.get_surface_override_material_count()):
			if node.get_surface_override_material(surface)!=null:return _fail("Unexpected surface override")
		var old: ArrayMesh=node.mesh as ArrayMesh;var candidate: ArrayMesh=library.get_item_mesh(i) as ArrayMesh
		var old_record: Dictionary=NativeReader.mesh_record(old);var candidate_record: Dictionary=NativeReader.mesh_record(candidate)
		if not old_record.get("eligible",false) or old_record.arrays_sha256!=OLD_ARRAYS[i] or old_record.corners!=OLD_COUNTS[i] or candidate==old or not candidate_record.get("eligible",false) or candidate_record.corners!=NEW_COUNTS[i]:return _fail("Exact original/candidate native layout required")
		var native: Dictionary=_native_prebuilt_record(candidate)
		if not NativeReader._wire_descriptor_matches(native,_proof.expected_native_items[i]) or var_to_bytes(_mesh_configuration(old))!=var_to_bytes(_mesh_configuration(candidate)):return _fail("All13/native storage/config/buffers/own bounds differ")
		_entries.append({"node":node,"old":old,"candidate":candidate,"material":material,"shader":material.shader,"state":_node_state(node,["mesh"]),"old_record":old_record,"candidate_record":candidate_record,"old_native":_native_prebuilt_record(old),"candidate_native":native})
	_body=world.get_node_or_null(BODY_PATH) as StaticBody3D;_collision=world.get_node_or_null(COLLIDER_PATH) as CollisionShape3D
	if _body==null or _collision==null or _collision.get_parent()!=_body or not _collision.shape is ConcavePolygonShape3D or _collision.disabled or _collision.global_transform!=Transform3D.IDENTITY or _body.collision_layer!=1 or _body.collision_mask!=2 or _body.get_meta("entrance48_step_surface",false)!=true or not _body.get_meta("entrance48_step_bounds",null) is Rect2:return _fail("Exact original tagged contact source/node/body required")
	_shape_old=_collision.shape as ConcavePolygonShape3D;_shape_new=library.get_item_shapes(0)[0] as ConcavePolygonShape3D
	if _shape_old==_shape_new or _shape_old.get_faces().size()!=3129 or _sha(_shape_old.get_faces().to_byte_array())!=OLD_CONTACT_SHA or _shape_new.get_faces().size()!=7989 or _sha(_shape_new.get_faces().to_byte_array())!=NEW_CONTACT_SHA or _sha(var_to_bytes(_shape_configuration(_shape_old)))!=SHAPE_CONFIG_SHA or var_to_bytes(_shape_configuration(_shape_new))!=var_to_bytes(_shape_configuration(_shape_old)) or not _body_binding_exact(_shape_old) or PhysicsServer3D.body_get_shape(_body.get_rid(),_shape_index)!=_shape_old.get_rid():return _fail("Exact original/contact faces/config/registered physics RID required")
	_body_state=_body_native_state();_collision_state=_node_state(_collision,["shape"])
	_world_id=world.get_instance_id()
	if not _aliases(world,false):return _fail("Unique selected mesh/contact resource users required")
	_prepared=true;library=null
	_report.merge({"passed":true,"prepared":true,"artifact_sha256":ARTIFACT_SHA,"proof_sha256":expected_proof_sha,"runtime_loader_sha256":FileAccess.get_sha256(SELF),"original_refs_retained":true,"rounded_slab_count":18,"added_render_triangles":2100,"added_contact_triangles":1620,"visual_collar_triangles":480,"added_encoded_mesh_bytes":201600,"old_contact_faces_sha256":OLD_CONTACT_SHA,"installed_contact_faces_sha256":NEW_CONTACT_SHA,"cost_scope":"Encoded mesh delta only; excludes retained originals/objects/scratch/physics/driver/RSS/GPU costs. No timing or performance acceptance."},true)
	if not install_prepared(world):return get_report()
	return get_report()

func _library_exact(library: MeshLibrary) -> bool:
	if library==null or library.get_script()!=null or not library.get_meta_list().is_empty() or library.resource_name!="" or library.resource_local_to_scene or library.get_item_list()!=PackedInt32Array([0,1,2]):return false
	for i: int in range(3):
		if library.get_item_name(i)!=["top","front","soil"][i] or library.get_item_mesh_transform(i)!=Transform3D.IDENTITY or library.get_item_navigation_mesh(i)!=null or library.get_item_navigation_mesh_transform(i)!=Transform3D.IDENTITY or library.get_item_preview(i)!=null or library.get_item_navigation_layers(i)!=1 or library.get_item_mesh_cast_shadow(i)!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON:return false
		var shapes: Array=library.get_item_shapes(i)
		if i==0:
			if shapes.size()!=2 or not shapes[0] is ConcavePolygonShape3D or not shapes[1] is Transform3D or shapes[1]!=Transform3D.IDENTITY:return false
		elif not shapes.is_empty():return false
	return true

func _node_state(node: Node3D,omit: Array[String]) -> Dictionary:
	return {"stored":_stored(node,omit),"metadata":_metadata(node),"global_transform":node.global_transform,"script":node.get_script()}

func _body_native_state() -> Dictionary:
	var shapes: Array=[]
	for i: int in range(PhysicsServer3D.body_get_shape_count(_body.get_rid())):shapes.append("selected" if i==_shape_index else str(PhysicsServer3D.body_get_shape(_body.get_rid(),i).get_id()))
	return {"node":_node_state(_body,[]),"physics_mode":PhysicsServer3D.body_get_mode(_body.get_rid()),"shape_rids_except_selected":shapes,"owners":_body.get_shape_owners(),"owner_transform":_body.shape_owner_get_transform(_shape_owner_id),"owner_disabled":_body.is_shape_owner_disabled(_shape_owner_id),"selected_owner_index":_body.shape_owner_get_shape_index(_shape_owner_id,0)}

func _material_maps() -> Dictionary:
	var rows: Dictionary={}
	for entry: Dictionary in _entries:
		var material: ShaderMaterial=entry.material
		# Read live defaults first, then stored fields. No snapshot-default typing.
		var uniforms: Dictionary={}
		for property: Dictionary in material.get_property_list():
			var name: String=str(property.name)
			if name.begins_with("shader_parameter/"):uniforms[name]=material.get(name)
		rows[str(material.get_instance_id())]={"stored":_stored(material,[]),"uniforms":uniforms,"metadata":_metadata(material),"shader":material.shader,"shader_stored":_stored(material.shader,[]),"shader_metadata":_metadata(material.shader)}
	return rows

func _aliases(world: Node3D,installed: bool) -> bool:
	var uses: Array[int]=[0,0,0];var shape_uses: int=0
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh=null
		if node is MeshInstance3D:mesh=node.mesh
		elif node is MultiMeshInstance3D and node.multimesh!=null:mesh=node.multimesh.mesh
		if mesh==null:continue
		for i: int in range(3):
			var active: ArrayMesh=_entries[i].candidate if installed else _entries[i].old
			var inactive: ArrayMesh=_entries[i].old if installed else _entries[i].candidate
			if mesh==active:
				if node!=_entries[i].node:return false
				uses[i]+=1
			if mesh==inactive or mesh is ArrayMesh and (mesh.shadow_mesh==active or mesh.shadow_mesh==inactive):return false
	for node: Node in world.find_children("*","CollisionShape3D",true,false):
		var active: ConcavePolygonShape3D=_shape_new if installed else _shape_old
		var inactive: ConcavePolygonShape3D=_shape_old if installed else _shape_new
		if node.shape==active:
			if node!=_collision:return false
			shape_uses+=1
		if node.shape==inactive:return false
	return uses==[1,1,1] and shape_uses==1

func verify(world: Node3D,installed: bool) -> bool:
	if not _prepared or world==null or not world.is_inside_tree() or world.get_instance_id()!=_world_id:return false
	for entry: Dictionary in _entries:
		var selected: ArrayMesh=entry.candidate if installed else entry.old
		var expected: Dictionary=entry.candidate_native if installed else entry.old_native
		if not is_instance_valid(entry.node) or entry.node.mesh!=selected or entry.node.material_override!=entry.material or entry.material.shader!=entry.shader or var_to_bytes(_node_state(entry.node,["mesh"]))!=var_to_bytes(entry.state) or var_to_bytes(_native_prebuilt_record(selected))!=var_to_bytes(expected) or var_to_bytes(_native_prebuilt_record(entry.old))!=var_to_bytes(entry.old_native) or var_to_bytes(_native_prebuilt_record(entry.candidate))!=var_to_bytes(entry.candidate_native):return false
	var shape: ConcavePolygonShape3D=_shape_new if installed else _shape_old
	if not is_instance_valid(_collision) or _collision.shape!=shape or not _body_binding_exact(shape) or PhysicsServer3D.body_get_shape(_body.get_rid(),_shape_index)!=shape.get_rid() or var_to_bytes(_body_native_state())!=var_to_bytes(_body_state) or var_to_bytes(_node_state(_collision,["shape"]))!=var_to_bytes(_collision_state):return false
	if _sha(_shape_old.get_faces().to_byte_array())!=OLD_CONTACT_SHA or _sha(_shape_new.get_faces().to_byte_array())!=NEW_CONTACT_SHA or _sha(var_to_bytes(_shape_configuration(_shape_old)))!=SHAPE_CONFIG_SHA or var_to_bytes(_shape_configuration(_shape_old))!=var_to_bytes(_shape_configuration(_shape_new)):return false
	return _aliases(world,installed)

func _restore(world: Node3D,materials_before: Dictionary) -> bool:
	for entry: Dictionary in _entries:entry.node.mesh=entry.old
	_collision.shape=_shape_old;_installed=false;_report.installed=false
	var exact: bool=verify(world,false) and var_to_bytes(_material_maps())==var_to_bytes(materials_before)
	_report["rolled_back"]=exact;_report["actual_original_pointer_and_registered_RID_restored"]=exact
	return exact

func install_prepared(world: Node3D) -> bool:
	if _installed or not verify(world,false):_fail("Original resources changed before assignment");return false
	var materials_before: Dictionary=_material_maps()
	for entry: Dictionary in _entries:entry.node.mesh=entry.candidate
	_collision.shape=_shape_new;_installed=true
	_report.mesh_reference_assignments=3;_report.shape_reference_assignments=1
	if not verify(world,true) or var_to_bytes(_material_maps())!=var_to_bytes(materials_before):
		var restored: bool=_restore(world,materials_before)
		_fail("Post-assignment native readback refused; original references restored="+str(restored));return false
	_report.merge({"passed":true,"installed":true,"same_material_pointers_and_live_maps_exact":true,"selected_mesh_and_contact_RIDs_exact":true,"original_node_body_metadata_transforms_masks_exact":true},true)
	return true

func rollback(world: Node3D) -> bool:
	if not _installed or not verify(world,true):_fail("Installed same-world resources required for rollback");return false
	var materials_before: Dictionary=_material_maps()
	var exact: bool=_restore(world,materials_before);_report.passed=exact
	if not exact:_fail("Actual original resource rollback refused")
	return exact

static func _metadata(resource: Object) -> Dictionary:
	var result: Dictionary={}
	for name: StringName in resource.get_meta_list(): result[str(name)]=resource.get_meta(name)
	return result

static func _stored(resource: Object,omit: Array[String]=[]) -> Dictionary:
	var result: Dictionary={}
	for property: Dictionary in resource.get_property_list():
		var name:=String(property.name)
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)!=0 and not name in omit: result[name]=resource.get(name)
	return result

func _mesh_configuration(mesh: ArrayMesh) -> Dictionary:
	var native: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
	return {"format":str(mesh.surface_get_format(0)),"primitive":mesh.surface_get_primitive_type(0),"surface_name":mesh.surface_get_name(0),"surface_material":mesh.surface_get_material(0),"blend_shapes":mesh.get_blend_shape_count(),"blend_shape_mode":mesh.blend_shape_mode,"custom_aabb":mesh.custom_aabb,"shadow_mesh":mesh.shadow_mesh,"resource_name":mesh.resource_name,"resource_local_to_scene":mesh.resource_local_to_scene,"metadata":_metadata(mesh),"script":mesh.get_script(),"lods":native.get("lods",[])}

func _native_buffer_record(mesh: ArrayMesh) -> Dictionary:
	var native: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
	var buffers: Dictionary={}; var total:=0
	for key: String in ["vertex_data","attribute_data","skin_data","index_data"]:
		var bytes: PackedByteArray=native.get(key,PackedByteArray())
		buffers[key]={"bytes":bytes.size(),"sha256":_sha(bytes)}; total+=bytes.size()
	return {"format":str(mesh.surface_get_format(0)),"native_vertices":mesh.surface_get_array_len(0),"buffers":buffers,"total_native_surface_buffer_bytes":total,"scope":"Encoded surface buffers only; excludes mesh object overhead, CPU scratch copies, retained originals, physics acceleration data and driver allocations. Not RSS or GPU timing."}

func _shape_configuration(shape: ConcavePolygonShape3D) -> Dictionary:
	# ConcavePolygonShape3D's stored data consists of the owned faces and its
	# backface flag. Keep the flag explicit and every other persistent field exact.
	var fields:=_stored(shape,["data"])
	fields["backface_collision"]=shape.backface_collision
	fields["metadata"]=_metadata(shape)
	fields["script"]=shape.get_script()
	return fields

func _body_binding_exact(shape: ConcavePolygonShape3D) -> bool:
	return is_instance_valid(_body) and is_instance_valid(_collision) and _collision.get_parent()==_body and _shape_owner_id in _body.get_shape_owners() and _body.shape_owner_get_owner(_shape_owner_id)==_collision and _body.shape_owner_get_shape_count(_shape_owner_id)==1 and _body.shape_owner_get_shape_index(_shape_owner_id,0)==_shape_index and _body.shape_owner_get_shape(_shape_owner_id,0)==shape

static func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hash.update(bytes)
	return hash.finish().hex_encode()

func _native_prebuilt_record(mesh: ArrayMesh) -> Dictionary:
	return {"all13_sha256":_sha(var_to_bytes(mesh.surface_get_arrays(0))),"native_surface_blob_sha256":_sha(var_to_bytes(mesh.get("_surfaces"))),"rendering_server_surface_sha256":_sha(var_to_bytes(RenderingServer.mesh_get_surface(mesh.get_rid(),0))),"configuration_sha256":_sha(var_to_bytes(_mesh_configuration(mesh))),"native_aabb_variant_hex":var_to_bytes(mesh.get_aabb()).hex_encode(),"native_buffers":_native_buffer_record(mesh)}
