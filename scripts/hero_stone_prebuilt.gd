extends RefCounted
## Startup reader for one pinned offline-authored stone shading asset.
## One offline-authored normal/tangent swap; no constructors, physics or frame work.
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ARTIFACT := "res://baked/hero-stone-normals.res"
const PROOF := "res://baked/hero-stone-normals-proof.json"
const SELF := "res://scripts/hero_stone_prebuilt.gd"
const ORIGINAL := "res://baked/clearing.res"
const ORIGINAL_SHA := "7d9455f72f63636f1adcce198ba9a03a73568d7224c04ddbcdcdcaefbc8bda37"
const NEUTRAL := "res://baked/clearing-renderer-neutral.res"
const NEUTRAL_SHA := "e35b74ff3adf5f0e77dcca84ffb2ed4f73a0d08c7119b42957a44ae8c0ea36ac"
const NEUTRAL_PROOF := "res://baked/renderer-neutral-proof.json"
const NEUTRAL_PROOF_SHA := "9aa70d569e8813a09d42675dc44d89e8310c9c61f4ac5165318ebff04414b833"
const READER_SHA := "35661bb43a42722eadc24018af8b25bb08b5d4959b117c13aaa3174f85784694"
const AUTHOR_REPORT_SHA := "e1fc51bd8ea1068cf6e936076759655b9a49a48b57af70e7390a4372d918d469"
const ARTIFACT_SHA := "a265ffebcceff0c2f7654ec22aa8a8cf9ad52c3c2915ee5881c5c4d774298f23"
const ARTIFACT_BYTES := 28772
const PATH := "BatchedStaticWorld/Static_-9223371982194603912_0_1"
const STUB := "GroundAndPaths/@MeshInstance3D@252"
const SITE := "HeroLandwardShoulder"
const STUB_TRANSFORM_SHA := "6d3e2a1b2797ccc5acf9f1f9797924935f389ff1a3cb3acb9063100b235750f0"
const OLD_ARRAYS_SHA := "437c243491d8b86dcb0ce6d526d8abbb8495fa4ad702ba4b0f118469b28315f6"
const NEW_ARRAYS_SHA := "d049a867946993f21d37bb24c99053cea0bc63ac2f2158290d51b150a5853082"
const OLD_SURFACE_SHA := "a41dfc40e28b68b10523f08f442d0f79c5ee7c516272499787b6b5fd4a8560c0"
const NEW_SURFACE_SHA := "41b9aa066f26030c939f77b6b7d224a7cc182e2d391ae5030cb515563ed2963d"
const CORNERS := 864
const RAW_FORMAT := 34359738399

static func install(world: Node3D,expected_proof_sha: String) -> Dictionary:
	var report := {"schema":"mush-hero-stone-normal-prebuilt-runtime/1","passed":false,"installed":false,"geometry_generated":false,"added_triangles":0,"added_draws":0,"new_materials":0,"collision_changed":false,"perframe_work":false,"performance_measured":false}
	if world==null or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or not _sha_string(expected_proof_sha):
		return _fail(report,"Ready identity world and fixed SHA256 proof pin required")
	var file := FileAccess.open(PROOF,FileAccess.READ)
	if file==null: return _fail(report,"Hero stone proof missing")
	var length: int = file.get_length()
	if length<=0 or length>131072:
		file.close();return _fail(report,"Hero stone proof exceeds bounded size")
	var text: String = file.get_as_text();file.close()
	if FileAccess.get_sha256(PROOF)!=expected_proof_sha: return _fail(report,"Proof differs from the fixed pin")
	var decoded: Variant = JSON.parse_string(text)
	if not decoded is Dictionary: return _fail(report,"Pinned proof dictionary required")
	var proof: Dictionary = decoded
	if proof.get("schema","")!="mush-hero-stone-normal-prebuilt-proof/1" or not proof.get("passed",false) or not proof.get("native_candidate_passed",false) or not proof.get("native_library_roundtrip_exact",false) or not proof.get("original_world_restored",false) or not proof.get("root_selected_for_next_isolated_source_checkpoint",false) or proof.get("authoring_report_sha256","")!=AUTHOR_REPORT_SHA or proof.get("authoring_check_count",-1)!=44 or proof.get("crease_dot_original",-1.0)!=0.82 or proof.get("crease_dot_candidate",-1.0)!=0.5:
		return _fail(report,"Positive pinned44-check native authoring, roundtrip, rollback and root selection required")
	var self_sha: String = FileAccess.get_sha256(SELF)
	if not _sha_string(self_sha) or proof.get("artifact","")!=ARTIFACT or proof.get("artifact_sha256","")!=ARTIFACT_SHA or proof.get("artifact_bytes",-1)!=ARTIFACT_BYTES or proof.get("loader_sha256","")!=self_sha or proof.get("native_reader_sha256","")!=READER_SHA or FileAccess.get_sha256("res://scripts/cap57_prebuilt.gd")!=READER_SHA:
		return _fail(report,"Exact artifact, loader self-binding and native reader required")
	if proof.get("original_sha256","")!=ORIGINAL_SHA or proof.get("neutral_sha256","")!=NEUTRAL_SHA or proof.get("neutral_proof_sha256","")!=NEUTRAL_PROOF_SHA or FileAccess.get_sha256(ORIGINAL)!=ORIGINAL_SHA or FileAccess.get_sha256(NEUTRAL)!=NEUTRAL_SHA or FileAccess.get_sha256(NEUTRAL_PROOF)!=NEUTRAL_PROOF_SHA:
		return _fail(report,"Original/neutral source identities and neutral proof must remain exact")
	if not proof.get("mesh",null) is Dictionary: return _fail(report,"One complete native geometry proof row required")
	var row: Dictionary = proof.mesh
	# JSON stores numeric array members as floats; require the exact two slots.
	if row.get("path","")!=PATH or row.get("stub","")!=STUB or row.get("corners",-1)!=CORNERS or row.get("triangles",-1)!=288 or row.get("changed_slots",[])!=[1.0,2.0] or row.get("original_native_surface_sha256","")!=OLD_SURFACE_SHA or row.get("candidate_native_surface_sha256","")!=NEW_SURFACE_SHA or row.get("added_triangles",-1)!=0 or row.get("added_draw_nodes",-1)!=0 or row.get("new_materials",-1)!=0 or row.get("new_colliders",-1)!=0 or row.get("perframe_work_added",true):
		return _fail(report,"Exact one-site normal/tangent-only authoring scope required")
	var artifact := FileAccess.open(ARTIFACT,FileAccess.READ)
	if artifact==null: return _fail(report,"Hero stone artifact missing")
	var bytes: int = artifact.get_length();artifact.close()
	if bytes!=ARTIFACT_BYTES or FileAccess.get_sha256(ARTIFACT)!=ARTIFACT_SHA: return _fail(report,"Exact bounded native artifact required")
	var library := ResourceLoader.load(ARTIFACT,"MeshLibrary") as MeshLibrary
	if not _library_clean(library): return _fail(report,"One unscripted auxiliary-free material-free library item required")
	var node := world.get_node_or_null(PATH) as MeshInstance3D
	var stub := world.get_node_or_null(STUB) as MeshInstance3D
	var candidate := library.get_item_mesh(0) as ArrayMesh
	if not _owned(world,node,stub) or candidate==null: return _fail(report,"Exact current semantic stub, transform and unique material owner required")
	var original := node.mesh as ArrayMesh
	if candidate==original or not _isolated(world,node,original,candidate): return _fail(report,"Distinct original/artifact and isolated live mesh ownership required")
	var old_record := NativeReader.mesh_record(original)
	var new_record := NativeReader.mesh_record(candidate)
	if not old_record.get("eligible",false) or not new_record.get("eligible",false) or old_record.corners!=CORNERS or new_record.corners!=CORNERS or old_record.arrays_sha256!=OLD_ARRAYS_SHA or new_record.arrays_sha256!=NEW_ARRAYS_SHA or not NativeReader._wire_descriptor_matches(old_record,row.get("original",{})) or not NativeReader._wire_descriptor_matches(new_record,row.get("candidate",{})) or var_to_bytes(old_record.configuration)!=var_to_bytes(new_record.configuration) or old_record.aabb_sha256!=new_record.aabb_sha256:
		return _fail(report,"Exact original/candidate all13, configuration and AABB descriptors required")
	if not _direction_scope_exact(original,candidate): return _fail(report,"Only native normal/tangent records may differ; all other channels/raw fields must remain exact")
	var node_before: String = _node_state(node,true)
	var stub_before: String = _node_state(stub,false)
	var material: ShaderMaterial = node.material_override as ShaderMaterial
	var material_before: String = _material_state(material)
	# All admission is complete before this single startup mesh-pointer assignment.
	node.mesh=candidate
	var installed: bool = node.mesh==candidate and _owned(world,node,stub) and _isolated(world,node,candidate,original) and _node_state(node,true)==node_before and _node_state(stub,false)==stub_before and node.material_override==material and stub.material_override==material and _material_state(material)==material_before and var_to_bytes(NativeReader.mesh_record(original))==var_to_bytes(old_record) and var_to_bytes(NativeReader.mesh_record(candidate))==var_to_bytes(new_record) and _direction_scope_exact(original,candidate)
	if not installed:
		node.mesh=original
		var restored: bool = node.mesh==original and _owned(world,node,stub) and _isolated(world,node,original,candidate) and _node_state(node,true)==node_before and _node_state(stub,false)==stub_before and node.material_override==material and stub.material_override==material and _material_state(material)==material_before and var_to_bytes(NativeReader.mesh_record(original))==var_to_bytes(old_record) and _surface_sha(original)==OLD_SURFACE_SHA
		report["rolled_back"]=true;report["rollback_exact"]=restored
		return _fail(report,"Post-assignment readback refused; actual original mesh pointer restored")
	report.merge({"passed":true,"installed":true,"native_records_verified":true,"proof_sha256":expected_proof_sha,"artifact_sha256":ARTIFACT_SHA,"authoring_report_sha256":AUTHOR_REPORT_SHA,"path":PATH,"stub":STUB,"site":SITE,"old_arrays_sha256":OLD_ARRAYS_SHA,"installed_arrays_sha256":NEW_ARRAYS_SHA,"corners":CORNERS,"triangles":288,"original_material_pointer_preserved":true,"node_settings_preserved":true,"changed_slots":[1,2],"coherent_tangent_basis":true},true)
	return report

static func _library_clean(library: MeshLibrary) -> bool:
	return library!=null and library.get_script()==null and library.get_meta_list().is_empty() and library.resource_name=="" and not library.resource_local_to_scene and library.get_item_list()==PackedInt32Array([0]) and library.get_item_name(0)==PATH and library.get_item_mesh_transform(0)==Transform3D.IDENTITY and library.get_item_shapes(0).is_empty() and library.get_item_navigation_mesh(0)==null and library.get_item_navigation_mesh_transform(0)==Transform3D.IDENTITY and library.get_item_navigation_layers(0)==1 and library.get_item_preview(0)==null and library.get_item_mesh_cast_shadow(0)==GeometryInstance3D.SHADOW_CASTING_SETTING_ON

static func _owned(world: Node3D,node: MeshInstance3D,stub: MeshInstance3D) -> bool:
	if node==null or stub==null or not node.mesh is ArrayMesh or stub.mesh!=null or node.get_script()!=null or stub.get_script()!=null or node.get_parent()!=world.get_node_or_null("BatchedStaticWorld") or node.transform!=Transform3D.IDENTITY or node.global_transform!=Transform3D.IDENTITY or not node.visible or not node.is_visible_in_tree() or node.get_child_count()!=0 or stub.get_meta("review08_sculpt_site","")!=SITE or NativeReader._sha(var_to_bytes(stub.transform))!=STUB_TRANSFORM_SHA or NativeReader._sha(var_to_bytes(stub.global_transform))!=STUB_TRANSFORM_SHA or not node.material_override is ShaderMaterial or node.material_override.shader==null or node.material_override!=stub.material_override or node.get_active_material(0)!=node.material_override or node.material_overlay!=null:
		return false
	var material_owners := 0;var site_stubs := 0
	for possible: Node in world.find_children("*","GeometryInstance3D",true,false):
		if possible is MeshInstance3D:
			if possible.get_meta("review08_sculpt_site","")==SITE: site_stubs+=1
			if possible.mesh!=null and possible.material_override==stub.material_override:
				if possible!=node: return false
				material_owners+=1
		elif (possible as GeometryInstance3D).material_override==stub.material_override: return false
	return material_owners==1 and site_stubs==1

static func _isolated(world: Node3D,node: MeshInstance3D,current: ArrayMesh,inactive: ArrayMesh) -> bool:
	var users := 0
	for possible: Node in world.get_tree().root.find_children("*","GeometryInstance3D",true,false):
		var meshes: Array = []
		if possible is MeshInstance3D: meshes.append(possible.mesh)
		elif possible is MultiMeshInstance3D and possible.multimesh!=null: meshes.append(possible.multimesh.mesh)
		elif possible is GPUParticles3D:
			for pass_index in range(possible.draw_passes): meshes.append(possible.get_draw_pass_mesh(pass_index))
		for mesh: Mesh in meshes:
			if mesh==null: continue
			if mesh==current:
				if possible!=node: return false
				users+=1
			if mesh==inactive or mesh is ArrayMesh and (mesh.shadow_mesh==current or mesh.shadow_mesh==inactive): return false
	return users==1

static func _direction_scope_exact(original: ArrayMesh,candidate: ArrayMesh) -> bool:
	var before: Array = original.surface_get_arrays(0)
	var after: Array = candidate.surface_get_arrays(0)
	var changed: Array = []
	for slot in range(Mesh.ARRAY_MAX):
		if var_to_bytes(before[slot])!=var_to_bytes(after[slot]): changed.append(slot)
	if changed!=[Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT] or not after[Mesh.ARRAY_TANGENT] is PackedFloat32Array or after[Mesh.ARRAY_TANGENT].size()!=CORNERS*4: return false
	var old_surfaces: Variant = original.get("_surfaces")
	var new_surfaces: Variant = candidate.get("_surfaces")
	if not old_surfaces is Array or not new_surfaces is Array or old_surfaces.size()!=1 or new_surfaces.size()!=1 or not old_surfaces[0] is Dictionary or not new_surfaces[0] is Dictionary: return false
	var old_data: Dictionary = old_surfaces[0]
	var new_data: Dictionary = new_surfaces[0]
	if old_data.get("format",0)!=RAW_FORMAT or new_data.get("format",0)!=RAW_FORMAT or old_data.get("vertex_count",0)!=CORNERS or new_data.get("vertex_count",0)!=CORNERS or not old_data.get("vertex_data",null) is PackedByteArray or not new_data.get("vertex_data",null) is PackedByteArray or old_data.vertex_data.size()!=17280 or new_data.vertex_data.size()!=17280 or _surface_sha(original)!=OLD_SURFACE_SHA or _surface_sha(candidate)!=NEW_SURFACE_SHA: return false
	if old_data.vertex_data.slice(0,CORNERS*12)!=new_data.vertex_data.slice(0,CORNERS*12): return false
	var protected_old: Dictionary = old_data.duplicate(true);protected_old.erase("vertex_data")
	var protected_new: Dictionary = new_data.duplicate(true);protected_new.erase("vertex_data")
	if var_to_bytes(protected_old)!=var_to_bytes(protected_new): return false
	var normals: PackedVector3Array = after[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = after[Mesh.ARRAY_TANGENT]
	for index in range(CORNERS):
		var normal: Vector3 = normals[index]
		var tangent := Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
		if not normal.is_finite() or not tangent.is_finite() or absf(normal.length()-1.0)>=0.002 or absf(tangent.length()-1.0)>=0.002 or absf(normal.dot(tangent))>=0.002 or absf(tangents[index*4+3])!=1.0: return false
	return true

static func _surface_sha(mesh: ArrayMesh) -> String:
	var surfaces: Variant = mesh.get("_surfaces")
	return NativeReader._sha(var_to_bytes(surfaces[0])) if surfaces is Array and surfaces.size()==1 else ""

static func _node_state(node: MeshInstance3D,omit_mesh: bool) -> String:
	var fields: Array = []
	for property: Dictionary in node.get_property_list():
		var name: String = str(property.name)
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or omit_mesh and name=="mesh": continue
		var value: Variant = node.get(name)
		fields.append([name,typeof(value),value.get_instance_id() if value is Object else value])
	var metadata: Dictionary = {}
	for key: StringName in node.get_meta_list(): metadata[str(key)]=node.get_meta(key)
	return NativeReader._sha(var_to_bytes([node.get_parent().get_instance_id(),node.global_transform,fields,metadata]))

static func _material_state(material: ShaderMaterial) -> String:
	var uniforms: Array = []
	for uniform: Dictionary in material.shader.get_shader_uniform_list(): uniforms.append([str(uniform.name),material.get_shader_parameter(uniform.name)])
	var fields: Array = []
	for property: Dictionary in material.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0: continue
		var value: Variant = material.get(property.name)
		fields.append([str(property.name),typeof(value),value.get_instance_id() if value is Object else value])
	return NativeReader._sha(var_to_bytes([material.get_instance_id(),material.shader.get_instance_id(),material.shader.code,fields,uniforms]))

static func _sha_string(value: String) -> bool:
	if value.length()!=64: return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index,1)): return false
	return true

static func _fail(report: Dictionary,reason: String) -> Dictionary:
	report["passed"]=false;report["failure"]=reason
	return report
