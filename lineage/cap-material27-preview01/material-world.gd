# Material-only playable wrapper. No CapScope rerun at startup.
# Immutable actual144 + trial04/capture/PNG prerequisites are enforced by launcher.
extends "res://lineage/scenery-revision-27/proposals/hero-crown-02/crown-world.gd"
var _cap_preview: Dictionary = {"schema":"mush-r27-main-cap-material-preview/1","passed":false,"status":"pending","errors":[],"runtime_full_cap_scope_rerun":false}
var _cap_preview_material: ShaderMaterial
const _CAP_PREVIEW_UNIFORMS: Array[String] = ["base_color","accent_color","roughness_value","texture_scale","grain","grain_kind","foliage","emission_strength","lamella_emission","lamella_recess","lamella_root_fade","emission_color","surface_albedo","surface_blend","surface_scale","surface_triplanar"]

func _cap_preview_uniforms(material: ShaderMaterial) -> Dictionary:
	var values: Dictionary = {}
	for key: String in _CAP_PREVIEW_UNIFORMS:
		values[key] = material.get_shader_parameter(key)
	return values

func _cap_preview_json_uniforms(material: ShaderMaterial) -> Dictionary:
	var values: Dictionary = _cap_preview_uniforms(material)
	for key: String in values.keys():
		var value: Variant = values[key]
		if value is Color: values[key] = [value.r,value.g,value.b,value.a]
		elif value is Resource: values[key] = {"class":value.get_class(),"path":value.resource_path,"instance_id":value.get_instance_id()}
	return values

func _cap_preview_fail(reason: String) -> void:
	(_cap_preview["errors"] as Array).append(reason)
	_cap_preview["passed"] = false
	_cap_preview["status"] = "refused"

func _cap_preview_install(skin: MeshInstance3D) -> Dictionary:
	if skin == null or skin.mesh == null or not skin.mesh is ArrayMesh:
		_cap_preview_fail("Selected main skin missing ArrayMesh")
		return {}
	var original: ShaderMaterial = skin.material_override as ShaderMaterial
	if original == null or original != _materials["cap"] or original.shader == null:
		_cap_preview_fail("Selected original cap registry binding missing")
		return {}
	if original.shader.resource_path != "res://assets/world/tactile.gdshader" or FileAccess.get_sha256(original.shader.resource_path) != "06821be1eabdd98daf11a0c8e48a5a1926e2604e75b3d563104d292a6e25fe36":
		_cap_preview_fail("Original tactile shader differs")
		return {}
	# This pure property-list getter populates only declared Shader defaults in
	# ShaderMaterial's lazy parameter cache at the pinned installed4.7.2 version.
	var preprime: Dictionary = _cap_preview_uniforms(original)
	var properties: Array = original.get_property_list()
	var resolved: Dictionary = _cap_preview_uniforms(original)
	var resolution_rows: Array = []
	var resolution_exact: bool = true
	for key: String in _CAP_PREVIEW_UNIFORMS:
		var declared_default: Variant = RenderingServer.shader_get_parameter_default(original.shader.get_rid(),key)
		var preserved_explicit: bool = preprime[key] != null
		var expected_value: Variant = preprime[key] if preserved_explicit else declared_default
		var exact: bool = typeof(resolved[key]) == typeof(expected_value) and var_to_bytes(resolved[key]) == var_to_bytes(expected_value)
		resolution_exact = resolution_exact and exact
		resolution_rows.append({"name":key,"preprime_value":_cap_preview_diag_value(preprime[key]),"preprime_type":typeof(preprime[key]),"previously_non_nil":preserved_explicit,"declared_shader_default":_cap_preview_diag_value(declared_default),"resolved_value":_cap_preview_diag_value(resolved[key]),"exact_explicit_or_declared_default":exact})
	_cap_preview["default_resolution_receipt"] = {"getter":"original.get_property_list()","property_count":properties.size(),"passed":resolution_exact,"rows":resolution_rows,"no_setter_invoked":true,"scope":"Only shader-declared defaults may replace prior NIL getter values; every prior non-NIL value remains exact. This getter cache realization precedes the strict duplication snapshot."}
	if not resolution_exact:
		_cap_preview_fail("Shader default realization differs from explicit values or native declared defaults")
		return {}
	var before: Dictionary = resolved
	_cap_preview["diagnostic_phase"] = "initial_uniform_check"
	_cap_preview["observed_original_uniforms"] = _cap_preview_json_uniforms(original)
	_cap_preview["observed_grain_variant_hex"] = var_to_bytes(before["grain"]).hex_encode()
	_cap_preview["observed_roughness_variant_hex"] = var_to_bytes(before["roughness_value"]).hex_encode()
	if before["grain"] != 0.30 or before["roughness_value"] != 0.83:
		_cap_preview_fail("Original cap grain/roughness is not .30/.83")
		return {}
	_cap_preview["diagnostic_phase"] = "duplicate_and_prebatch_parity"
	var bindings: Array = []
	for item: Node in find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = item as MeshInstance3D
		if node != skin: bindings.append([node,node.material_override])
	var old_mesh: Mesh = skin.mesh
	var old_transform: Transform3D = skin.transform
	var old_channels: Dictionary = _cap_preview_channels(skin)
	var rng_before: String = str(_rng.state)
	_cap_preview_material = original.duplicate(false) as ShaderMaterial
	if _cap_preview_material == null or _cap_preview_material == original:
		_cap_preview_fail("Selected material duplication failed")
		return {}
	_cap_preview_material.set_shader_parameter("grain",0.12)
	_cap_preview_material.set_shader_parameter("roughness_value",0.70)
	skin.material_override = _cap_preview_material
	var after: Dictionary = _cap_preview_uniforms(_cap_preview_material)
	var invariant_uniforms: bool = true
	for key: String in _CAP_PREVIEW_UNIFORMS:
		if key != "grain" and key != "roughness_value" and after[key] != before[key]: invariant_uniforms = false
	var other_bindings: bool = true
	for row: Array in bindings:
		if (row[0] as MeshInstance3D).material_override != row[1]: other_bindings = false
	var geometry_exact: bool = skin.mesh == old_mesh and skin.transform == old_transform and var_to_bytes(old_channels) == var_to_bytes(_cap_preview_channels(skin))
	var material_state_exact: bool = _cap_preview_material.shader == original.shader and _cap_preview_material.render_priority == original.render_priority and _cap_preview_material.next_pass == original.next_pass
	var original_unchanged: bool = original == _materials["cap"] and _cap_preview_uniforms(original) == before
	var passed: bool = invariant_uniforms and other_bindings and geometry_exact and material_state_exact and original_unchanged and rng_before == str(_rng.state) and after["grain"] == 0.12 and after["roughness_value"] == 0.70
	_cap_preview.merge({"target":"MushroomHome/FoldedPeachUmbrella","before":_cap_preview_json_uniforms(original),"after":_cap_preview_json_uniforms(_cap_preview_material),"shader_path":original.shader.resource_path,"shader_sha256":FileAccess.get_sha256(original.shader.resource_path),"other_original_bindings_count":bindings.size(),"other_original_material_bindings_exact":other_bindings,"native_skin_channels_and_local_transform_exact":geometry_exact,"same_shader_render_priority_next_pass":material_state_exact,"all_other_uniforms_exact":invariant_uniforms,"original_registry_material_exact":original_unchanged,"rng_unchanged_during_install":rng_before == str(_rng.state)},true)
	if not passed:
		_cap_preview_fail("Prebatch material-only parity failed")
		return {}
	var arrays: Array = old_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
	var expected_v: PackedVector3Array = PackedVector3Array()
	var expected_u: PackedVector2Array = PackedVector2Array()
	var expected_c: PackedColorArray = PackedColorArray()
	var xf: Transform3D = global_transform.affine_inverse() * skin.global_transform
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	for j: int in range(count):
		var i: int = indices[j] if not indices.is_empty() else j
		expected_v.append(xf * vertices[i])
		expected_u.append(uvs[i])
		expected_c.append(colors[i])
	return {"vertices":expected_v,"uvs":expected_u,"colors":expected_c}

func _cap_preview_batch_check(expected: Dictionary) -> void:
	_cap_preview["diagnostic_phase"] = "actual_batch_strict_comparison"
	_cap_preview["expected_render_stream"] = {"vertices":(expected["vertices"] as PackedVector3Array).size(),"position_sha256":_cap_preview_sha((expected["vertices"] as PackedVector3Array).to_byte_array()),"uv_sha256":_cap_preview_sha((expected["uvs"] as PackedVector2Array).to_byte_array()),"color_sha256":_cap_preview_sha((expected["colors"] as PackedColorArray).to_byte_array())}
	var batches: Array = []
	var matched: bool = true
	for item: Node in find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = item as MeshInstance3D
		if node.mesh == null or node.material_override != _cap_preview_material: continue
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var u: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var v_exact: bool = v.to_byte_array() == (expected["vertices"] as PackedVector3Array).to_byte_array()
		var uv_exact: bool = u.to_byte_array() == (expected["uvs"] as PackedVector2Array).to_byte_array()
		var color_exact: bool = c.to_byte_array() == (expected["colors"] as PackedColorArray).to_byte_array()
		matched = matched and v_exact and uv_exact and color_exact and v.size() == 46080 and node.mesh.get_surface_count() == 1
		batches.append({"path":str(get_path_to(node)),"vertices":v.size(),"positions_exact":v_exact,"uv_exact":uv_exact,"color_exact":color_exact,"position_sha256":_cap_preview_sha(v.to_byte_array()),"uv_sha256":_cap_preview_sha(u.to_byte_array()),"color_sha256":_cap_preview_sha(c.to_byte_array()),"format":(node.mesh as ArrayMesh).surface_get_format(0),"index_slot_null":arrays[Mesh.ARRAY_INDEX] == null,"first_position_difference":_cap_preview_first_difference(v,expected["vertices"]),"first_uv_difference":_cap_preview_first_difference(u,expected["uvs"]),"first_color_difference":_cap_preview_first_difference(c,expected["colors"])})
	_cap_preview["render_batches"] = batches
	if batches.size() != 1 or not matched:
		_cap_preview_fail("Selected actual batch positions/UV/color/cardinality differ")
		return
	_cap_preview["passed"] = true
	_cap_preview["status"] = "complete"
	_cap_preview["scope"] = "Immutable prior native144/capture04 proof prerequisite; runtime main-only material duplication; actual selected batch positions/UV/color exact. Original batching reencodes normals/tangents; no raw13-channel batch parity, performance, art approval or adoption claim."

func _cap_preview_diag_value(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2: return [value.x,value.y]
	if value is Color: return [value.r,value.g,value.b,value.a]
	return value

func _cap_preview_first_difference(actual: Variant, expected: Variant) -> Dictionary:
	if actual.size() != expected.size(): return {"reason":"cardinality","actual":actual.size(),"expected":expected.size()}
	for i: int in range(actual.size()):
		var actual_bytes: PackedByteArray = var_to_bytes(actual[i])
		var expected_bytes: PackedByteArray = var_to_bytes(expected[i])
		if actual_bytes != expected_bytes:
			return {"index":i,"actual":_cap_preview_diag_value(actual[i]),"expected":_cap_preview_diag_value(expected[i]),"actual_variant_hex":actual_bytes.hex_encode(),"expected_variant_hex":expected_bytes.hex_encode()}
	return {}

func get_cap_material_preview_report() -> Dictionary:
	var result: Dictionary = _cap_preview.duplicate(true)
	if _cap_preview_material != null:
		result["actual_current_parameters"] = _cap_preview_json_uniforms(_cap_preview_material)
		result["world_night_amount"] = night_amount
	return result

func _cap_preview_sha(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()

func _cap_preview_channels(node: MeshInstance3D) -> Dictionary:
	if node == null or node.mesh == null: return {"missing_mesh": true}
	var mesh: ArrayMesh = node.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1: return {"invalid_surface_count": true}
	var arrays: Array = mesh.surface_get_arrays(0)
	var channels: Array = []
	for slot: int in range(arrays.size()):
		var value: Variant = arrays[slot]
		var bytes: PackedByteArray = PackedByteArray()
		if value != null:
			bytes = value if value is PackedByteArray else value.to_byte_array()
		channels.append({"slot": slot, "type": typeof(value), "null": value == null, "sha256": _cap_preview_sha(bytes)})
	return {"channels": channels, "vertices": arrays[Mesh.ARRAY_VERTEX].size(), "primitive": mesh.surface_get_primitive_type(0), "format": mesh.surface_get_format(0), "local_position": [node.position.x,node.position.y,node.position.z]}

func _batch_static_meshes() -> void:
	var skin: MeshInstance3D = get_node_or_null("MushroomHome/FoldedPeachUmbrella") as MeshInstance3D
	var expected: Dictionary = _cap_preview_install(skin)
	if expected.is_empty(): return
	var rng_before: String = str(_rng.state)
	super._batch_static_meshes()
	_cap_preview_batch_check(expected)
	if str(_rng.state) != rng_before:
		_cap_preview_fail("Original batching changed RNG during material install")
