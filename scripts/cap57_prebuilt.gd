extends RefCounted
## Runtime reader only: no geometry constructor, scene simulation or material edit.
const ARTIFACT := "res://baked/cap57-prebuilt.res"
const PROOF := "res://baked/cap57-prebuilt-proof.json"
const SELF := "res://scripts/cap57_prebuilt.gd"
const ORIGINAL := "res://baked/clearing.res"
const ORIGINAL_SHA := "7d9455f72f63636f1adcce198ba9a03a73568d7224c04ddbcdcdcaefbc8bda37"
const NEUTRAL := "res://baked/clearing-renderer-neutral.res"
const NEUTRAL_SHA := "e35b74ff3adf5f0e77dcca84ffb2ed4f73a0d08c7119b42957a44ae8c0ea36ac"
const NEUTRAL_PROOF := "res://baked/renderer-neutral-proof.json"
const NEUTRAL_PROOF_SHA := "9aa70d569e8813a09d42675dc44d89e8310c9c61f4ac5165318ebff04414b833"
const HELPER56_SHA := "61dc8c644d3cf5b78f98ba6e542967909d4a393399be00e08b68ccb590876fe7"
const HELPER57_SHA := "cb0c9b82709b58c7f0a86f66e096f7f69930db5f69f0212490353755ab596d84"
const RETURN_HELPER_SHA := "c63af018d81567c081606700595f2a5efe055b4eff5432cc288dd70208b8e615"
const RETURN_AUTHORING_SHA := "3ab85b2498285e7a2b2b70eab9cabadc11f9bf834c70e3b9bcdb7448251bce34"
const FACTORY_SHA := "c8b4bae88dc60c5fb14e8df8263adf0d98db86f79990dd91cfa757a3764099a4"
const PATHS := ["BatchedStaticWorld/Static_-9223371840544561210_0_0","BatchedStaticWorld/Static_-9223371979929679639_0_0"]
const STUBS := ["MushroomHome/FoldedPeachUmbrella","MushroomHome/ContinuousPleatedCreamUnderbody"]
const OLD_ARRAYS := ["024b029881da7a1bcad5bd6e6863dcf72e47c9993f80fe8423a9cb237085394b","004c73bd32106bcba2e0693fafaedb6a56d475e9ecfe06c8a4f1d94e49cc7cda"]
const COUNTS := [46080,182016]

static func install(world: Node3D,expected_proof_sha: String) -> Dictionary:
	var report := {"schema":"mush-cap57-prebuilt-runtime/1","passed":false,"installed":false,"geometry_generated":false,"simulation_run":false,"artifact":ARTIFACT,"proof":PROOF,"proof_sha256":""}
	if world==null or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or expected_proof_sha.length()!=64:
		return _fail(report,"Exact ready world and installed proof pin required")
	var handle := FileAccess.open(PROOF,FileAccess.READ)
	if handle==null: return _fail(report,"Pinned proof cannot be opened")
	var length: int = handle.get_length()
	if length<=0 or length>2097152:
		handle.close()
		return _fail(report,"Proof exceeds its finite bound")
	var text: String = handle.get_as_text()
	handle.close()
	report.proof_sha256 = FileAccess.get_sha256(PROOF)
	if report.proof_sha256!=expected_proof_sha: return _fail(report,"Installed proof hash differs from its fixed pin")
	var decoded: Variant = JSON.parse_string(text)
	if not decoded is Dictionary: return _fail(report,"Proof is not a dictionary")
	var proof: Dictionary = decoded
	if proof.get("schema","")!="mush-cap-return016-prebuilt-native-proof/1" or not proof.get("passed",false) or not proof.get("native_library_roundtrip_exact",false) or not proof.get("parent_native_loader_core_test_passed",false) or not proof.get("baseline_030_reconstruction_native_exact",false) or not proof.get("current_relative_scope_seam_quality_passed",false) or not proof.get("current043_candidate_install_and_rollback_verified",false) or not proof.get("other_native_resources_exact",false) or proof.get("shape_crest",-1.0)!=0.16 or proof.get("retained_grain",-1.0)!=0.12:
		return _fail(report,"Positive .16 authoring/roundtrip/current043 preservation and parent seed-loader provenance required")
	if proof.get("original_sha256","")!=ORIGINAL_SHA or proof.get("neutral_sha256","")!=NEUTRAL_SHA or proof.get("neutral_proof_sha256","")!=NEUTRAL_PROOF_SHA or FileAccess.get_sha256(ORIGINAL)!=ORIGINAL_SHA or FileAccess.get_sha256(NEUTRAL)!=NEUTRAL_SHA or FileAccess.get_sha256(NEUTRAL_PROOF)!=NEUTRAL_PROOF_SHA:
		return _fail(report,"Retained original/neutral snapshots and neutral proof must remain exact")
	if proof.get("helper56_sha256","")!=HELPER56_SHA or proof.get("helper57_sha256","")!=HELPER57_SHA or proof.get("factory_sha256","")!=FACTORY_SHA or proof.get("return_helper_sha256","")!=RETURN_HELPER_SHA or proof.get("authoring_report_sha256","")!=RETURN_AUTHORING_SHA or proof.get("runtime_loader_sha256","")!=FileAccess.get_sha256(SELF):
		return _fail(report,"Exact baseline helpers/factory, .16 authoring provenance and runtime reader required")
	if proof.get("artifact","")!=ARTIFACT or not proof.get("meshes",null) is Array:
		return _fail(report,"Artifact path/hash and exactly two native mesh records required")
	var file := FileAccess.open(ARTIFACT,FileAccess.READ)
	if file==null: return _fail(report,"Artifact cannot be opened")
	var bytes: int = file.get_length()
	file.close()
	if bytes<=0 or bytes>67108864: return _fail(report,"Artifact exceeds its finite bound")
	if FileAccess.get_sha256(ARTIFACT)!=proof.get("artifact_sha256",""): return _fail(report,"Native artifact file differs from its pinned proof")
	var library := ResourceLoader.load(ARTIFACT,"MeshLibrary") as MeshLibrary
	var installed := _install_verified_meshes(world,library,proof.meshes)
	report.merge(installed,true)
	report["artifact_sha256"] = proof.artifact_sha256
	report["runtime_loader_sha256"] = FileAccess.get_sha256(SELF)
	report["native_arrays_verified"] = bool(installed.get("passed",false))
	report["shape_crest"] = proof.shape_crest
	report["retained_grain"] = proof.retained_grain
	report["direct_seed_to_016_native_install_observed"] = bool(installed.get("passed",false))
	report["source_authoring_scope"] = "Two native prebuilt mesh resources only; unchanged original/neutral snapshot and original override material ownership. No constructor/coordinator/gameplay is executed by this reader."
	return report

static func _install_verified_meshes(world: Node3D,library: MeshLibrary,rows: Array) -> Dictionary:
	var report := {"passed":false,"installed":false,"selected_nodes":[],"geometry_generated":false}
	if world==null or library==null or rows.size()!=2 or library.get_script()!=null or not library.get_meta_list().is_empty() or library.get_item_list()!=PackedInt32Array([0,1]): return _fail(report,"Exactly two unscripted MeshLibrary items required")
	var selected: Array[MeshInstance3D] = []
	var originals: Array[ArrayMesh] = []
	var candidates: Array[ArrayMesh] = []
	var before: Array[Dictionary] = []
	for index: int in range(2):
		if not rows[index] is Dictionary: return _fail(report,"Two ordered dictionary records required")
		var row: Dictionary = rows[index]
		var node := world.get_node_or_null(PATHS[index]) as MeshInstance3D
		var stub := world.get_node_or_null(STUBS[index]) as MeshInstance3D
		var candidate := library.get_item_mesh(index) as ArrayMesh
		var label: String = "skin" if index==0 else "cream"
		if row.get("path","")!=PATHS[index] or row.get("stub","")!=STUBS[index] or row.get("label","")!=label or row.get("item",-1)!=index or not _owned(world,node,stub): return _fail(report,"Exact selected batch paths and original stub/material ownership required")
		if library.get_item_name(index)!=label or library.get_item_mesh_transform(index)!=Transform3D.IDENTITY or not library.get_item_shapes(index).is_empty() or library.get_item_navigation_mesh(index)!=null or library.get_item_preview(index)!=null: return _fail(report,"Library may contain meshes only, without transforms/collision/navigation/previews")
		var original := node.mesh as ArrayMesh
		var old_record := mesh_record(original)
		var candidate_record := mesh_record(candidate)
		if not old_record.get("eligible",false) or not candidate_record.get("eligible",false) or old_record.arrays_sha256!=OLD_ARRAYS[index] or old_record.corners!=COUNTS[index] or candidate_record.corners!=COUNTS[index] or not _wire_descriptor_matches(old_record,row.get("original",{})) or not _wire_descriptor_matches(candidate_record,row.get("candidate",{})): return _fail(report,"Exact old/candidate native arrays and complete bounded mesh configuration required")
		if candidate_record.arrays_sha256==old_record.arrays_sha256 or candidate==original or candidate_record.configuration!=old_record.configuration or not _wire_descriptor_matches(node_record(node),row.get("node",{})): return _fail(report,"A distinct prebuilt candidate, unchanged mesh configuration and exact node metadata required")
		selected.append(node); originals.append(original); candidates.append(candidate); before.append(node_record(node))
	if originals[0]==originals[1] or candidates[0]==candidates[1] or candidates[0] in originals or candidates[1] in originals: return _fail(report,"Two distinct original and artifact resources required")
	if _sha(var_to_bytes(originals[0].get_aabb().merge(originals[1].get_aabb())))!=_sha(var_to_bytes(candidates[0].get_aabb().merge(candidates[1].get_aabb()))) or _sha(var_to_bytes(originals[0].get_aabb()))!=_sha(var_to_bytes(candidates[0].get_aabb())): return _fail(report,"Exact combined cap envelope and skin AABB required")
	for index: int in range(2): selected[index].mesh = candidates[index]
	var passed := true
	for index: int in range(2):
		passed = passed and selected[index].mesh==candidates[index] and node_record(selected[index])==before[index] and _owned(world,selected[index],world.get_node(STUBS[index]) as MeshInstance3D)
		report.selected_nodes.append({"path":PATHS[index],"item":index,"old_arrays_sha256":OLD_ARRAYS[index],"installed_arrays_sha256":mesh_record(candidates[index]).arrays_sha256,"material_ownership_preserved":_owned(world,selected[index],world.get_node(STUBS[index]) as MeshInstance3D)})
	if not passed:
		for index: int in range(2): selected[index].mesh = originals[index]
		report["rolled_back"] = true
		return _fail(report,"Post-assignment node/material preservation refused; original meshes restored")
	report.passed = true; report.installed = true
	return report

static func _wire_descriptor_matches(native: Variant,encoded: Variant) -> bool:
	# Only three native descriptor-vs-JSON comparisons use this adapter. JSON
	# loses Array[Dictionary] typing and decodes integer labels/counts as float.
	# Keep exact keys/order/scalar types/hash strings. Native float bytes stay
	# exact; numeric integer representation is admitted only within JSON's
	# exact integer domain and only when its value is unchanged. Native packed
	# mesh arrays are never passed here: all13 typed-channel/full/AABB hashes,
	# native-to-native roundtrip/configuration and post-install gates stay raw.
	var kind: int = typeof(native)
	if kind==TYPE_INT:
		if typeof(encoded) not in [TYPE_INT,TYPE_FLOAT] or absi(int(native))>9007199254740991: return false
		return is_finite(float(encoded)) and float(encoded)==float(native)
	if kind==TYPE_FLOAT:
		return typeof(encoded)==TYPE_FLOAT and is_finite(float(native)) and is_finite(float(encoded)) and var_to_bytes(native)==var_to_bytes(encoded)
	if kind in [TYPE_NIL,TYPE_BOOL,TYPE_STRING]: return typeof(encoded)==kind and native==encoded
	if kind==TYPE_ARRAY:
		if typeof(encoded)!=TYPE_ARRAY or native.size()!=encoded.size(): return false
		for index: int in range(native.size()):
			if not _wire_descriptor_matches(native[index],encoded[index]): return false
		return true
	if kind==TYPE_DICTIONARY:
		if typeof(encoded)!=TYPE_DICTIONARY or native.size()!=encoded.size(): return false
		for key: String in native:
			if not encoded.has(key) or not _wire_descriptor_matches(native[key],encoded[key]): return false
		return true
	return false

static func _owned(world: Node3D,node: MeshInstance3D,stub: MeshInstance3D) -> bool:
	if node==null or stub==null or not node.mesh is ArrayMesh or stub.mesh!=null or stub.material_override==null or node.material_override!=stub.material_override or node.material_overlay!=null or stub.transform!=Transform3D(Basis.IDENTITY,Vector3(0,6.5,0)) or node.get_parent()!=world.get_node_or_null("BatchedStaticWorld") or node.transform!=Transform3D.IDENTITY or not node.visible or not node.is_visible_in_tree(): return false
	var matches := 0
	var mesh_users := 0
	for possible: Node in world.find_children("*","GeometryInstance3D",true,false):
		if possible is MeshInstance3D:
			if possible.mesh!=null and possible.material_override==stub.material_override: matches+=1
			if possible.mesh==node.mesh: mesh_users+=1
		elif possible is MultiMeshInstance3D and possible.multimesh!=null and possible.multimesh.mesh==node.mesh: mesh_users+=1
	return matches==1 and mesh_users==1 and node.get_active_material(0)==stub.material_override

static func mesh_record(mesh: ArrayMesh) -> Dictionary:
	if mesh==null or mesh.get_surface_count()!=1: return {"eligible":false}
	var arrays: Array = mesh.surface_get_arrays(0)
	var native: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(),0)
	var corners: int = arrays[Mesh.ARRAY_VERTEX].size() if arrays.size()==Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array else 0
	var channels: Array[Dictionary] = []
	for index: int in range(arrays.size()): channels.append({"slot":index,"native_type":typeof(arrays[index]),"sha256":_sha(var_to_bytes(arrays[index]))})
	var metadata: Dictionary = {}
	for name: StringName in mesh.get_meta_list(): metadata[str(name)] = mesh.get_meta(name)
	var config := {"format":str(mesh.surface_get_format(0)),"primitive":mesh.surface_get_primitive_type(0),"surface_name":mesh.surface_get_name(0),"surface_material_null":mesh.surface_get_material(0)==null,"blend_shapes":mesh.get_blend_shape_count(),"blend_shape_mode":mesh.blend_shape_mode,"custom_aabb_sha256":_sha(var_to_bytes(mesh.custom_aabb)),"shadow_mesh_null":mesh.shadow_mesh==null,"resource_name":mesh.resource_name,"resource_local_to_scene":mesh.resource_local_to_scene,"metadata_sha256":_sha(var_to_bytes(metadata)),"metadata_empty":metadata.is_empty(),"script_null":mesh.get_script()==null,"lods_empty":native.get("lods",[]).is_empty()}
	var eligible: bool = corners>0 and corners%3==0 and arrays.size()==Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array and arrays[Mesh.ARRAY_NORMAL].size()==corners and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array and arrays[Mesh.ARRAY_TEX_UV].size()==corners and arrays[Mesh.ARRAY_COLOR] is PackedColorArray and arrays[Mesh.ARRAY_COLOR].size()==corners and arrays[Mesh.ARRAY_INDEX]==null and arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null and config.primitive==Mesh.PRIMITIVE_TRIANGLES and config.surface_material_null and config.blend_shapes==0 and config.shadow_mesh_null and config.metadata_empty and config.script_null and config.lods_empty
	return {"eligible":eligible,"corners":corners,"arrays_sha256":_sha(var_to_bytes(arrays)),"channels":channels,"aabb_sha256":_sha(var_to_bytes(mesh.get_aabb())),"configuration":config}

static func node_record(node: MeshInstance3D) -> Dictionary:
	var overrides: Array = []
	for index: int in range(node.get_surface_override_material_count()): overrides.append(node.get_surface_override_material(index)==null)
	var material := node.material_override as ShaderMaterial
	return {"transform_sha256":_sha(var_to_bytes(node.transform)),"global_transform_sha256":_sha(var_to_bytes(node.global_transform)),"visible":node.visible,"cast_shadow":node.cast_shadow,"layers":node.layers,"extra_cull_margin":node.extra_cull_margin,"top_level":node.top_level,"surface_overrides_null":overrides,"overlay_null":node.material_overlay==null,"material_class":node.material_override.get_class() if node.material_override!=null else "","shader_sha256":_sha(material.shader.code.to_utf8_buffer()) if material!=null and material.shader!=null else ""}

static func _fail(report: Dictionary,reason: String) -> Dictionary:
	report.passed = false; report["failure"] = reason
	return report

static func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hash.update(bytes)
	return hash.finish().hex_encode()
