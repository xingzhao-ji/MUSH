extends RefCounted
## Cached complete-home placement. Admit all bindings before assigning; no frame loop.
const ENABLED: bool = true
const Reader = preload("res://scripts/cap57_prebuilt.gd")
const READER_SHA: String = "35661bb43a42722eadc24018af8b25bb08b5d4959b117c13aaa3174f85784694"
const ARTIFACT: String = "res://baked/distant-home-relocation.res"
const PROOF: String = "res://baked/distant-home-relocation-proof.json"
const ARTIFACT_SHA: String = "9fd28d80133aedc92364afff0afe3aaa255f9ae43638864989731357ce3fd1bf" # Fill only after the closed native bake.
const ARTIFACT_BYTES: int = 1941665
const HOMES: Array[String] = ["ForestBeyondTheClearing/@Node3D@3780", "ForestBeyondTheClearing/@Node3D@3802"]

static func install(world: Node3D, expected_proof_sha: String, artifact_path: String=ARTIFACT, proof_path: String=PROOF) -> Dictionary:
	var report: Dictionary={"schema":"mush-distant-home-relocation-runtime/1","passed":false,"installed":false,"geometry_generated":false,"perframe_work":false,"additional_triangles":0,"additional_draw_nodes":0,"additional_colliders":0,"collision_changed":false,"new_materials":0,"performance_measured":false,"artifact":artifact_path,"proof":proof_path}
	if not ENABLED or ARTIFACT_SHA.length()!=64 or ARTIFACT_BYTES<=0: return _fail(report,"Placement artifact pins are incomplete")
	if world==null or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or expected_proof_sha.length()!=64 or FileAccess.get_sha256("res://scripts/cap57_prebuilt.gd")!=READER_SHA: return _fail(report,"Ready identity world and exact reader/proof pins required")
	var file: FileAccess=FileAccess.open(proof_path,FileAccess.READ)
	if file==null: return _fail(report,"Proof missing")
	if file.get_length()<=0 or file.get_length()>524288: file.close(); return _fail(report,"Proof exceeds finite bound")
	var text: String=file.get_as_text(); file.close()
	if FileAccess.get_sha256(proof_path)!=expected_proof_sha: return _fail(report,"Proof hash mismatch")
	var decoded: Variant=JSON.parse_string(text)
	if not decoded is Dictionary: return _fail(report,"Proof dictionary required")
	var proof: Dictionary=decoded
	if proof.get("schema","")!="mush-distant-home-relocation-proof/1" or not proof.get("passed",false) or not proof.get("native_library_roundtrip_exact",false) or not proof.get("original_world_restored",false) or not proof.get("root_selected_for_source_trial",false) or proof.get("reader_sha256","")!=READER_SHA or proof.get("source_snapshot_sha256","")!=FileAccess.get_sha256("res://baked/clearing-renderer-neutral.res"): return _fail(report,"Pinned native bake/rollback/root selection and source snapshot required")
	if proof.get("artifact","")!=ARTIFACT or proof.get("artifact_sha256","")!=ARTIFACT_SHA or proof.get("artifact_bytes",-1)!=ARTIFACT_BYTES or not proof.get("meshes",null) is Array or proof.meshes.size()!=16 or not proof.get("stubs",null) is Array or proof.stubs.size()!=36 or not proof.get("homes",null) is Array or proof.homes.size()!=2: return _fail(report,"Exact artifact and 16/36/2 records required")
	file=FileAccess.open(artifact_path,FileAccess.READ)
	if file==null: return _fail(report,"Artifact missing")
	var bytes: int=file.get_length(); file.close()
	if bytes!=ARTIFACT_BYTES or bytes>67108864 or FileAccess.get_sha256(artifact_path)!=ARTIFACT_SHA: return _fail(report,"Artifact file differs from its fixed pin")
	var library: MeshLibrary=ResourceLoader.load(artifact_path,"MeshLibrary") as MeshLibrary
	var ids: PackedInt32Array=PackedInt32Array()
	for index: int in range(16): ids.append(index)
	if library==null or library.get_script()!=null or not library.get_meta_list().is_empty() or library.get_item_list()!=ids: return _fail(report,"Exactly 16 unscripted library items required")
	var nodes: Array[MeshInstance3D]=[]; var old: Array[ArrayMesh]=[]; var fresh: Array[ArrayMesh]=[]; var materials: Array[Material]=[]
	var parents: Array[Node3D]=[]; var poses: Array[Transform3D]=[]; var targets: Array[Transform3D]=[]; var lights: Array[OmniLight3D]=[]
	var old_vertices: Array[PackedVector3Array]=[]; var new_vertices: Array[PackedVector3Array]=[]
	var stubs: Array[MeshInstance3D]=[]; var source_paths: Dictionary={}; var stub_paths: Dictionary={}; var counts: Array[int]=[0,0]
	# All resources and semantic bindings are admitted before any assignment.
	for index: int in range(16):
		var row: Dictionary=proof.meshes[index] if proof.meshes[index] is Dictionary else {}
		var path: String=row.get("path",""); var node: MeshInstance3D=world.get_node_or_null(path) as MeshInstance3D
		var mesh: ArrayMesh=library.get_item_mesh(index) as ArrayMesh
		if path.is_empty() or source_paths.has(path) or row.get("item",-1)!=index or node==null or not node.mesh is ArrayMesh or mesh==null or node.get_parent()!=world.get_node_or_null("BatchedStaticWorld") or node.global_transform!=Transform3D.IDENTITY or not node.visible or not node.is_visible_in_tree() or not node.material_override is ShaderMaterial or node.get_active_material(0)!=node.material_override: return _fail(report,"Exact unique batch and material owner required")
		if library.get_item_name(index)!=path or library.get_item_mesh_transform(index)!=Transform3D.IDENTITY or not library.get_item_shapes(index).is_empty() or library.get_item_navigation_mesh(index)!=null or library.get_item_preview(index)!=null: return _fail(report,"Material-free mesh payloads only")
		var original: ArrayMesh=node.mesh; var a: Dictionary=Reader.mesh_record(original); var b: Dictionary=Reader.mesh_record(mesh)
		if old.has(original) or fresh.has(mesh) or mesh==original or not a.get("eligible",false) or not b.get("eligible",false) or a.configuration!=b.configuration or a.corners!=b.corners or not Reader._wire_descriptor_matches(a,row.get("original",{})) or not Reader._wire_descriptor_matches(b,row.get("candidate",{})) or not Reader._wire_descriptor_matches(Reader.node_record(node),row.get("node",{})) or _surface_sha(original)!=row.get("original_native_surface_sha256","") or _surface_sha(mesh)!=row.get("candidate_native_surface_sha256","") or _extras_sha(original)!=row.get("original_extras_sha256","") or _extras_sha(mesh)!=row.get("candidate_extras_sha256","") or _extras_sha(original)!=_extras_sha(mesh): return _fail(report,"Exact original/candidate native arrays/config/buffers/extras and node required")
		var aa: Array=original.surface_get_arrays(0); var bb: Array=mesh.surface_get_arrays(0)
		for slot: int in range(1,Mesh.ARRAY_MAX):
			if var_to_bytes(aa[slot])!=var_to_bytes(bb[slot]): return _fail(report,"Only position channels may change")
		source_paths[path]=index; nodes.append(node); old.append(original); fresh.append(mesh); materials.append(node.material_override)
		old_vertices.append(aa[Mesh.ARRAY_VERTEX]); new_vertices.append(bb[Mesh.ARRAY_VERTEX])
	for index: int in range(2):
		var row: Dictionary=proof.homes[index] if proof.homes[index] is Dictionary else {}
		var parent: Node3D=world.get_node_or_null(HOMES[index]) as Node3D
		var target: Variant=bytes_to_var(str(row.get("candidate_transform_hex","")).hex_decode())
		if row.get("path","")!=HOMES[index] or parent==null or not target is Transform3D or not target.is_finite() or parent.get_parent().global_transform!=Transform3D.IDENTITY or parent.find_children("*","MeshInstance3D",true,false).size()!=18 or parent.find_children("*","OmniLight3D",true,false).size()!=1 or not parent.find_children("*","CollisionObject3D",true,false).is_empty() or var_to_bytes(parent.transform).hex_encode()!=row.get("original_transform_hex","") or target.basis!=parent.transform.basis or target.origin==parent.transform.origin: return _fail(report,"Two exact original parent poses and pure-translation targets required")
		var light: OmniLight3D=world.get_node_or_null(str(row.get("light_path",""))) as OmniLight3D
		if not _light_owned(world,parent,light,row.get("light",{}),false): return _fail(report,"Actual window light and unique practical-list membership required")
		parents.append(parent); poses.append(parent.transform); targets.append(target); lights.append(light)
	for raw: Variant in proof.stubs:
		if not raw is Dictionary: return _fail(report,"36 ordered stub records required")
		var row: Dictionary=raw; var home: int=int(row.get("home",-1)); var item: int=int(row.get("item",-1)); var path: String=row.get("path","")
		var stub: MeshInstance3D=world.get_node_or_null(path) as MeshInstance3D
		var first: int=int(row.get("first_corner",-1)); var count: int=int(row.get("corners",0))
		if home<0 or home>=2 or item<0 or item>=16 or path.is_empty() or stub_paths.has(path) or stub==null or not parents[home].is_ancestor_of(stub) or stub.mesh!=null or stub.material_override!=materials[item] or not Reader._wire_descriptor_matches(Reader.node_record(stub),row.get("original_node",{})) or first<0 or first%3!=0 or count<=0 or count%3!=0 or first+count>old_vertices[item].size(): return _fail(report,"Exact complete stub/material binding and native span required")
		var source: PackedVector3Array=old_vertices[item]; var candidate: PackedVector3Array=new_vertices[item]
		if Reader._sha(source.slice(first,first+count).to_byte_array())!=row.get("source_xyz_sha256","") or Reader._sha(candidate.slice(first,first+count).to_byte_array())!=row.get("candidate_xyz_sha256",""): return _fail(report,"Exact original/candidate packet order required")
		stub_paths[path]=true; counts[home]+=1; stubs.append(stub)
	if counts!=[18,18]: return _fail(report,"Both complete homes required")
	var hold: String=_held(materials,lights,world)
	for index: int in range(16): nodes[index].mesh=fresh[index]
	for index: int in range(2): parents[index].transform=targets[index]
	var installed: bool=_held(materials,lights,world)==hold
	for index: int in range(16): installed=installed and nodes[index].mesh==fresh[index] and nodes[index].material_override==materials[index] and Reader._wire_descriptor_matches(Reader.node_record(nodes[index]),proof.meshes[index].node) and Reader._wire_descriptor_matches(Reader.mesh_record(fresh[index]),proof.meshes[index].candidate) and _extras_sha(fresh[index])==proof.meshes[index].candidate_extras_sha256
	for index: int in range(2): installed=installed and parents[index].transform==targets[index] and _light_owned(world,parents[index],lights[index],proof.homes[index].light,true)
	for index: int in range(36): installed=installed and stubs[index].mesh==null and stubs[index].material_override==materials[int(proof.stubs[index].item)] and Reader._wire_descriptor_matches(Reader.node_record(stubs[index]),proof.stubs[index].candidate_node)
	if not installed:
		for index: int in range(16): nodes[index].mesh=old[index]
		for index: int in range(2): parents[index].transform=poses[index]
		var restored: bool=_held(materials,lights,world)==hold
		for index: int in range(16): restored=restored and nodes[index].mesh==old[index] and Reader._wire_descriptor_matches(Reader.mesh_record(old[index]),proof.meshes[index].original) and _extras_sha(old[index])==proof.meshes[index].original_extras_sha256
		for index: int in range(2): restored=restored and parents[index].transform==poses[index] and _light_owned(world,parents[index],lights[index],proof.homes[index].light,false)
		report["rolled_back"]=true; report["rollback_exact"]=restored
		return _fail(report,"Post-assignment readback refused; original meshes and parents restored")
	report.merge({"passed":true,"installed":true,"native_records_verified":true,"batches":16,"pieces":36,"parents":2,"window_lights":2,"artifact_sha256":ARTIFACT_SHA,"artifact_bytes":ARTIFACT_BYTES,"proof_sha256":expected_proof_sha,"original_material_pointers_preserved":true,"original_references_retained_after_return":false},true)
	return report

static func _light_owned(world: Node3D,parent: Node3D,light: OmniLight3D,row: Dictionary,candidate: bool) -> bool:
	if light==null or not parent.is_ancestor_of(light) or light.get_parent()!=world.get_node_or_null(str(row.get("parent_path",""))) or var_to_bytes(light.transform).hex_encode()!=row.get("local_transform_hex","") or Reader._sha(var_to_bytes(light.global_transform))!=row.get("candidate_global_transform_sha256" if candidate else "original_global_transform_sha256","") or _light_constants_sha(light)!=row.get("constants_sha256",""): return false
	var occurrences: int=0
	for practical: OmniLight3D in world._practical_lights:
		if practical==light: occurrences+=1
	return occurrences==1

static func _held(materials: Array[Material],lights: Array[OmniLight3D],world: Node3D) -> String:
	var rows: Array=[]
	var objects: Array[Object]=[]
	for material: Material in materials: objects.append(material)
	for light: OmniLight3D in lights: objects.append(light)
	for object: Object in objects:
		var fields: Array=[]
		for property: Dictionary in object.get_property_list():
			if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0: continue
			var value: Variant=object.get(property.name); fields.append([str(property.name),typeof(value),value.get_instance_id() if value is Object else value])
		if object is ShaderMaterial:
			for uniform: Dictionary in object.shader.get_shader_uniform_list(): fields.append([str(uniform.name),object.get_shader_parameter(uniform.name)])
		rows.append([object.get_instance_id(),fields])
	var ids: Array=[]
	for light: OmniLight3D in world._practical_lights: ids.append(light.get_instance_id())
	rows.append(ids)
	return Reader._sha(var_to_bytes(rows))

static func _surface_sha(mesh: ArrayMesh) -> String: return Reader._sha(var_to_bytes(RenderingServer.mesh_get_surface(mesh.get_rid(),0)))
static func _extras_sha(mesh: ArrayMesh) -> String: return Reader._sha(var_to_bytes(mesh.lightmap_size_hint))
static func _light_constants_sha(light: OmniLight3D) -> String: return Reader._sha(var_to_bytes([light.omni_range,light.omni_attenuation,light.shadow_enabled]))
static func _fail(report: Dictionary,reason: String) -> Dictionary:
	report["failure"]=reason; return report
