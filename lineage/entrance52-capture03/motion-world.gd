extends "res://lineage/entrance52-capture03/sky-world.gd"

# Detached, tunable living-scenery proposal. No Ready override or bake changes.
const _M37_CLOUD_SHADER: Shader = preload("res://lineage/living-scenery37-proposal01/drifting-clouds37.gdshader")
const _M37_WIND_SHADER: Shader = preload("res://lineage/living-scenery37-proposal01/canopy-wind37.gdshader")
const _M37_LEAF_KEYS: Array[String] = ["base_color","accent_color","roughness_value","emission_strength","night_amount","emission_color"]
const _M37_CLOUD_KEYS: Array[String] = ["top_color","horizon_color","ground_color","night_amount","rain_amount"]
const _M37_WIND_BOUND: float = 0.025
const _M37_ORBIT_RATE: float = 0.03
var _m37_initialized: bool = false
var _m37_enabled: bool = true
var _m37_reduced: bool = false
var _m37_elapsed: float = 0.0
var _m37_errors: Array[String] = []
var _m37_canopies: Array[Dictionary] = []
var _m37_materials: Array[Dictionary] = []
var _m37_other_bindings: Array[Dictionary] = []
var _m37_links: Array[Dictionary] = []
var _m37_registry: Dictionary = {}
var _m37_star_pose_sha: String = ""
var _m37_star_mesh_sha: String = ""
var _m37_moon_mesh_sha: String = ""
var _m37_sun_mesh_sha: String = ""
var _m37_original_cloud: ShaderMaterial
var _m37_cloud: ShaderMaterial
var _m37_cloud_realization: Dictionary = {}
var _m37_anchor_sun_basis: Basis = Basis.IDENTITY
var _m37_anchor_sun_position: Vector3 = Vector3.ZERO
var _m37_anchor_moon_position: Vector3 = Vector3.ZERO
var _m37_rng: String = ""
var _m37_source_sha: String = ""
var _m37_cloud_shader_sha: String = ""
var _m37_wind_shader_sha: String = ""
var _m37_jacobian_lower_bound: float = 1.0
var _m37_preservation: Dictionary = {"passed":false,"observed_elapsed_seconds":0.0,"performed":false}

func _m37_parameters(material: ShaderMaterial, keys: Array[String]) -> Dictionary:
	var values: Dictionary = {}
	for key: String in keys: values[key] = material.get_shader_parameter(key)
	return values

func _m37_prime(material: ShaderMaterial, keys: Array[String]) -> Dictionary:
	var before: Dictionary = _m37_parameters(material,keys)
	material.get_property_list()
	var passed: bool = true
	for key: String in keys:
		var current: Variant = material.get_shader_parameter(key)
		if before[key] != null:
			passed = passed and var_to_bytes(before[key]) == var_to_bytes(current)
		else:
			passed = passed and var_to_bytes(current) == var_to_bytes(RenderingServer.shader_get_parameter_default(material.shader.get_rid(),key))
	return {"passed":passed,"scope":"Only native default realization; every prior nonNIL value remains variant-byte exact and priorNIL becomes its exact shader default."}

func _m37_mesh_sha(mesh: Mesh) -> String:
	var rows: Array = []
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if mesh is ArrayMesh:
			var array_mesh: ArrayMesh = mesh as ArrayMesh
			rows.append([array_mesh.surface_get_primitive_type(surface),array_mesh.surface_get_format(surface),arrays])
		else:
			# The retained Sun/Moon are PrimitiveMesh. Mesh's public API exposes
			# their native arrays, but primitive/format getters belong to ArrayMesh.
			rows.append([mesh.get_class(),arrays])
	return _cap_preview_sha(var_to_bytes(rows))

func _m37_poses_sha(mm: MultiMesh) -> String:
	var rows: Array[Transform3D] = []
	for i: int in range(mm.instance_count): rows.append(mm.get_instance_transform(i))
	return _cap_preview_sha(var_to_bytes(rows))

func _m37_jacobian_bound(node: MultiMeshInstance3D) -> float:
	# ||grad(weight)|| <= 1.5/1.25. The inverse basis Frobenius norm
	# conservatively bounds every local displacement for a 25mm world shift.
	var lower: float = 1.0
	for i: int in range(node.multimesh.instance_count):
		var basis: Basis = node.global_basis*node.multimesh.get_instance_transform(i).basis
		if not basis.is_finite() or absf(basis.determinant()) <= .000001: return -1.0
		var inverse_basis: Basis = basis.inverse()
		var inverse_norm: float = sqrt(inverse_basis.x.length_squared()+inverse_basis.y.length_squared()+inverse_basis.z.length_squared())
		if not is_finite(inverse_norm): return -1.0
		lower = minf(lower,1.0-1.2*_M37_WIND_BOUND*inverse_norm)
	return lower

func initialize_living_motion() -> Dictionary:
	if _m37_initialized:
		_m37_errors.append("Living motion initialization called twice")
		return get_living_motion_report()
	var terrain: Dictionary = get_landform35_report()
	if not terrain.get("passed",false) or terrain.get("author_mode",true) or not terrain.get("actual_current_final_render_batch_exact",false) or not terrain.get("existing_entry_foliage",{}).get("actual_live_multimesh_transforms_exact",false):
		_m37_errors.append("Current Q09 rest replay/render/foliage admission must pass before motion")
		return get_living_motion_report()
	if not get_sky36_report().get("passed",false):
		_m37_errors.append("Current native Sky05 rest admission must pass before motion")
		return get_living_motion_report()
	_m37_source_sha = FileAccess.get_sha256(get_script().resource_path)
	_m37_cloud_shader_sha = FileAccess.get_sha256(_M37_CLOUD_SHADER.resource_path)
	_m37_wind_shader_sha = FileAccess.get_sha256(_M37_WIND_SHADER.resource_path)
	_m37_rng = str(_rng.state)
	for key: String in _materials: _m37_registry[key] = _materials[key]
	_m37_anchor_sun_basis = sun.basis
	_m37_anchor_sun_position = _r36_sun.position
	# Preserve the exact current camera-relative direction at clock zero.
	# The fixture/product waits one original Sky follow frame before this call.
	_m37_anchor_moon_position = _moon.global_position-_r36_root.global_position
	_m37_star_pose_sha = _m37_poses_sha(_stars.multimesh)
	_m37_star_mesh_sha = _m37_mesh_sha(_stars.multimesh.mesh)
	_m37_sun_mesh_sha = _m37_mesh_sha(_r36_sun.mesh)
	_m37_moon_mesh_sha = _m37_mesh_sha(_moon.mesh)
	for child: MeshInstance3D in _r36_lines.get_children():
		_m37_links.append({"node":child,"mesh":child.mesh,"mesh_sha256":_m37_mesh_sha(child.mesh),"transform":child.transform,"material":child.material_override,"cast_shadow":child.cast_shadow})
	_m37_original_cloud = _cloud_sky_material
	_m37_cloud_realization = _m37_prime(_m37_original_cloud,_M37_CLOUD_KEYS)
	if not _m37_cloud_realization.passed:
		_m37_errors.append("Original cloud default realization failed")
		return get_living_motion_report()
	_m37_cloud = _m37_original_cloud.duplicate(false) as ShaderMaterial
	_m37_cloud.shader = _M37_CLOUD_SHADER
	if var_to_bytes(_m37_parameters(_m37_cloud,_M37_CLOUD_KEYS)) != var_to_bytes(_m37_parameters(_m37_original_cloud,_M37_CLOUD_KEYS)):
		_m37_errors.append("Cloud fork changed an original declared parameter")
		return get_living_motion_report()
	_cloud_sky_material = _m37_cloud
	environment.sky.sky_material = _m37_cloud
	var selected_meshes: Array = [_canopy_mesh,_canopy_far_mesh,_canopy_shadow_mesh,_canopy_far_shadow_mesh]
	var material_map: Dictionary = {}
	var mesh_hashes: Dictionary = {}
	var targets: Dictionary = {}
	var foliage: Node = get_node_or_null("SpatiallyChunkedFoliage")
	if foliage == null:
		_m37_errors.append("Native foliage scene unavailable")
		return get_living_motion_report()
	for child: Node in foliage.get_children():
		var node: MultiMeshInstance3D = child as MultiMeshInstance3D
		if node == null or node.multimesh == null or not selected_meshes.has(node.multimesh.mesh): continue
		var original: ShaderMaterial = node.material_override as ShaderMaterial
		if original == null or original.shader.resource_path != "res://assets/world/foliage.gdshader":
			_m37_errors.append("Canopy original shader/material is not the pinned foliage source")
			continue
		var key: int = original.get_instance_id()
		if not material_map.has(key):
			var realized: Dictionary = _m37_prime(original,_M37_LEAF_KEYS)
			var selected: ShaderMaterial = original.duplicate(false) as ShaderMaterial
			selected.shader = _M37_WIND_SHADER
			var exact: bool = realized.passed and selected != original and selected.render_priority == original.render_priority and selected.next_pass == original.next_pass and var_to_bytes(_m37_parameters(selected,_M37_LEAF_KEYS)) == var_to_bytes(_m37_parameters(original,_M37_LEAF_KEYS))
			if not exact: _m37_errors.append("Canopy fork changed original declared material parameters")
			material_map[key] = selected
			_m37_materials.append({"original":original,"selected":selected,"realization":realized,"initial_exact":exact})
		var fork: ShaderMaterial = material_map[key] as ShaderMaterial
		var mesh_key: int = node.multimesh.mesh.get_instance_id()
		if not mesh_hashes.has(mesh_key): mesh_hashes[mesh_key] = _m37_mesh_sha(node.multimesh.mesh)
		var jacobian_lower: float = _m37_jacobian_bound(node)
		_m37_jacobian_lower_bound = minf(_m37_jacobian_lower_bound,jacobian_lower)
		if jacobian_lower <= .5:
			_m37_errors.append("Native canopy transform does not certify a positive wind Jacobian")
			continue
		var inverse_node_basis: Basis = node.global_basis.inverse()
		var local_cull_margin: float = _M37_WIND_BOUND*sqrt(inverse_node_basis.x.length_squared()+inverse_node_basis.y.length_squared()+inverse_node_basis.z.length_squared())
		var original_cull_margin: float = node.extra_cull_margin
		# Native geometry stores a float margin. Round upward in that exact
		# positive FP32 domain before setter/readback; no epsilon comparison.
		var requested_cull_margin: float = original_cull_margin+local_cull_margin
		var margin_storage: PackedByteArray = PackedFloat32Array([requested_cull_margin]).to_byte_array()
		var selected_cull_margin: float = margin_storage.decode_float(0)
		if selected_cull_margin < requested_cull_margin:
			margin_storage.encode_u32(0,margin_storage.decode_u32(0)+1)
			selected_cull_margin = margin_storage.decode_float(0)
		_m37_canopies.append({"node":node,"mesh":node.multimesh.mesh,"mm":node.multimesh,"poses_sha256":_m37_poses_sha(node.multimesh),"buffer_sha256":_cap_preview_sha(node.multimesh.buffer.to_byte_array()),"transform_format":node.multimesh.transform_format,"use_colors":node.multimesh.use_colors,"use_custom_data":node.multimesh.use_custom_data,"mesh_sha256":mesh_hashes[mesh_key],"transform":node.transform,"global_transform":node.global_transform,"cast_shadow":node.cast_shadow,"original":original,"selected":fork,"instance_count":node.multimesh.instance_count,"jacobian_lower_bound":jacobian_lower,"native_AABB":node.multimesh.get_aabb(),"custom_AABB":node.custom_aabb,"original_cull_margin":original_cull_margin,"selected_cull_margin":selected_cull_margin,"added_local_cull_margin":local_cull_margin})
		node.material_override = fork
		# Expand only selected visible/shadow node cull boxes. Native meshes,
		# MM buffers/AABB and all noncanopy culling settings remain unchanged.
		node.extra_cull_margin = selected_cull_margin
		targets[node.get_instance_id()] = true
	for type_name: String in ["MeshInstance3D","MultiMeshInstance3D"]:
		for child: Node in find_children("*",type_name,true,false):
			if not targets.has(child.get_instance_id()): _m37_other_bindings.append({"node":child,"material":child.material_override})
	if _m37_canopies.is_empty(): _m37_errors.append("No actual visible/shadow canopy targets")
	_m37_initialized = true
	_m37_apply_state()
	validate_living_motion_preservation()
	return get_living_motion_report()

func set_living_motion_enabled(value: bool) -> void:
	_m37_enabled = value
	if _m37_initialized: _m37_apply_state()

func set_living_motion_reduced(value: bool) -> void:
	_m37_reduced = value
	if _m37_initialized: _m37_apply_state()

func _m37_active() -> bool:
	return _m37_initialized and _m37_enabled and not _m37_reduced and not _reduced_effects

func _m37_apply_state() -> void:
	var active: bool = _m37_active()
	var angle: float = deg_to_rad(_m37_elapsed*_M37_ORBIT_RATE) if active else 0.0
	var orbit: Basis = Basis(Vector3.UP,angle)
	_r36_root.basis = orbit
	# Sky05 parent computes the local Sun from its original appearance light.
	# Apply orbit once to both world light and local sky anchor, never twice.
	sun.basis = orbit*_m37_anchor_sun_basis
	_r36_sun.position = _m37_anchor_sun_position
	_moon.global_position = _r36_root.global_position+orbit*_m37_anchor_moon_position
	_m37_cloud.set_shader_parameter("cloud_offset",Vector3(_m37_elapsed*.010,0,_m37_elapsed*.006) if active else Vector3.ZERO)
	for row: Dictionary in _m37_materials:
		var original: ShaderMaterial = row.original as ShaderMaterial
		var selected: ShaderMaterial = row.selected as ShaderMaterial
		selected.set_shader_parameter("night_amount",original.get_shader_parameter("night_amount"))
		selected.set_shader_parameter("wind_time",_m37_elapsed)
		selected.set_shader_parameter("wind_displacement_m",_M37_WIND_BOUND*lerpf(.72,1.0,rain_amount) if active else 0.0)

func _apply_appearance() -> void:
	super._apply_appearance()
	if _m37_initialized:
		_m37_anchor_sun_basis = sun.basis
		_m37_anchor_sun_position = _r36_sun.position
		_m37_apply_state()

func _process(delta: float) -> void:
	super._process(delta)
	if not _m37_initialized: return
	# Parent World is ALWAYS; explicitly freeze the own delta clock on pause.
	if _m37_active() and not get_tree().paused: _m37_elapsed += delta
	_m37_apply_state()

func validate_living_motion_preservation() -> Dictionary:
	var passed: bool = _m37_initialized and _m37_errors.is_empty() and str(_rng.state) == _m37_rng
	var mesh_hashes: Dictionary = {}
	for key: String in _m37_registry: passed = passed and _materials[key] == _m37_registry[key]
	for row: Dictionary in _m37_canopies:
		var node: MultiMeshInstance3D = row.node as MultiMeshInstance3D
		var mesh_key: int = node.multimesh.mesh.get_instance_id()
		if not mesh_hashes.has(mesh_key): mesh_hashes[mesh_key] = _m37_mesh_sha(node.multimesh.mesh)
		passed = passed and node.multimesh == row.mm and node.multimesh.mesh == row.mesh and node.multimesh.instance_count == row.instance_count and node.transform == row.transform and node.global_transform == row.global_transform and node.cast_shadow == row.cast_shadow and node.material_override == row.selected and _m37_poses_sha(node.multimesh) == row.poses_sha256 and mesh_hashes[mesh_key] == row.mesh_sha256 and float(row.jacobian_lower_bound) > .5
		passed = passed and node.multimesh.transform_format == row.transform_format and node.multimesh.use_colors == row.use_colors and node.multimesh.use_custom_data == row.use_custom_data and _cap_preview_sha(node.multimesh.buffer.to_byte_array()) == row.buffer_sha256
		passed = passed and var_to_bytes(node.multimesh.get_aabb()) == var_to_bytes(row.native_AABB) and var_to_bytes(node.custom_aabb) == var_to_bytes(row.custom_AABB) and var_to_bytes(node.extra_cull_margin) == var_to_bytes(row.selected_cull_margin) and float(row.added_local_cull_margin) > 0.0
	for row: Dictionary in _m37_other_bindings: passed = passed and row.node.material_override == row.material
	for row: Dictionary in _m37_materials:
		var original: ShaderMaterial = row.original as ShaderMaterial
		var selected: ShaderMaterial = row.selected as ShaderMaterial
		passed = passed and row.initial_exact and selected.shader == _M37_WIND_SHADER and selected.render_priority == original.render_priority and selected.next_pass == original.next_pass and var_to_bytes(_m37_parameters(selected,_M37_LEAF_KEYS)) == var_to_bytes(_m37_parameters(original,_M37_LEAF_KEYS))
	for row: Dictionary in _m37_links:
		var node: MeshInstance3D = row.node as MeshInstance3D
		passed = passed and node.mesh == row.mesh and node.transform == row.transform and node.material_override == row.material and node.cast_shadow == row.cast_shadow and _m37_mesh_sha(node.mesh) == row.mesh_sha256
	passed = passed and _cloud_sky_material == _m37_cloud and environment.sky.sky_material == _m37_cloud and _m37_cloud.shader == _M37_CLOUD_SHADER
	var expected_cloud: Dictionary = {"top_color":_sky_material.sky_top_color,"horizon_color":_sky_material.sky_horizon_color,"ground_color":_sky_material.ground_bottom_color,"night_amount":night_amount,"rain_amount":rain_amount}
	passed = passed and var_to_bytes(_m37_parameters(_m37_cloud,_M37_CLOUD_KEYS)) == var_to_bytes(expected_cloud) and _m37_cloud.render_priority == _m37_original_cloud.render_priority and _m37_cloud.next_pass == _m37_original_cloud.next_pass
	passed = passed and _m37_poses_sha(_stars.multimesh) == _m37_star_pose_sha and _m37_mesh_sha(_stars.multimesh.mesh) == _m37_star_mesh_sha and _m37_mesh_sha(_r36_sun.mesh) == _m37_sun_mesh_sha and _m37_mesh_sha(_moon.mesh) == _m37_moon_mesh_sha
	_m37_preservation = {"passed":passed,"performed":true,"observed_elapsed_seconds":_m37_elapsed,"mesh_and_MultiMesh_rest_arrays_exact":passed,"original_registry_and_other_binding_resources_exact":passed,"selected_material_forks_are_intentional":true,"scope":"Actual rest arrays/poses/resources reread only at this explicit boundary, not every sampled frame. Shader-deformed vertex positions are not GPU readback."}
	return _m37_preservation.duplicate(true)

func get_living_motion_report() -> Dictionary:
	var visible: int = 0
	var shadows: int = 0
	var instances: int = 0
	var cull_bounds_exact: bool = not _m37_canopies.is_empty()
	var added_local_cull_margin_min: float = INF
	var added_local_cull_margin_max: float = 0.0
	var wind_uniforms_exact: bool = not _m37_materials.is_empty()
	var wind_time: float = 0.0
	var wind_bound: float = 0.0
	var expected_wind_bound: float = _M37_WIND_BOUND*lerpf(.72,1.0,rain_amount) if _m37_active() else 0.0
	for row: Dictionary in _m37_materials:
		var selected: ShaderMaterial = row.selected as ShaderMaterial
		wind_time = float(selected.get_shader_parameter("wind_time"))
		wind_bound = float(selected.get_shader_parameter("wind_displacement_m"))
		wind_uniforms_exact = wind_uniforms_exact and var_to_bytes(wind_time) == var_to_bytes(_m37_elapsed) and var_to_bytes(wind_bound) == var_to_bytes(expected_wind_bound) and selected.shader == _M37_WIND_SHADER
	for row: Dictionary in _m37_canopies:
		instances += int(row.instance_count)
		cull_bounds_exact = cull_bounds_exact and var_to_bytes(row.node.extra_cull_margin) == var_to_bytes(row.selected_cull_margin)
		added_local_cull_margin_min = minf(added_local_cull_margin_min,float(row.added_local_cull_margin))
		added_local_cull_margin_max = maxf(added_local_cull_margin_max,float(row.added_local_cull_margin))
		if int(row.cast_shadow) == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: shadows += 1
		else: visible += 1
	var light_direction: Vector3 = sun.global_basis.z.normalized() if is_instance_valid(sun) else Vector3.ZERO
	var sun_direction: Vector3 = (_r36_sun.global_position-_r36_root.global_position).normalized() if is_instance_valid(_r36_sun) and is_instance_valid(_r36_root) else Vector3.ZERO
	var moon_direction: Vector3 = (_moon.global_position-_r36_root.global_position).normalized() if is_instance_valid(_moon) and is_instance_valid(_r36_root) else Vector3.ZERO
	var cloud_offset: Vector3 = Vector3.ZERO
	if _m37_cloud != null:
		var offset_value: Variant = _m37_cloud.get_shader_parameter("cloud_offset")
		if offset_value is Vector3: cloud_offset = offset_value as Vector3
	return {"schema":"mush-living-scenery37/1","passed":_m37_initialized and _m37_errors.is_empty() and _m37_preservation.get("passed",false),"status":"complete" if _m37_initialized and _m37_errors.is_empty() else "refused","errors":_m37_errors.duplicate(),"initialized":_m37_initialized,"source_path":get_script().resource_path,"source_sha256":_m37_source_sha,"cloud_shader_sha256":_m37_cloud_shader_sha,"wind_shader_sha256":_m37_wind_shader_sha,"enabled":_m37_enabled,"paused":get_tree().paused,"reduced":_m37_reduced,"reduced_effects":_reduced_effects,"clock_running":_m37_active() and not get_tree().paused,"elapsed_seconds":_m37_elapsed,"manual_day_night_target":_night_target,"manual_rain_target":_rain_target,"night_amount":night_amount,"rain_amount":rain_amount,"orbit_rate_deg_per_sec":_M37_ORBIT_RATE,"orbit_degrees":_m37_elapsed*_M37_ORBIT_RATE if _m37_active() else 0.0,"sun_world_direction":[light_direction.x,light_direction.y,light_direction.z],"visible_sun_world_direction":[sun_direction.x,sun_direction.y,sun_direction.z],"moon_world_direction":[moon_direction.x,moon_direction.y,moon_direction.z],"sun_light_alignment_dot":light_direction.dot(sun_direction),"stars_world_basis_sha256":_cap_preview_sha(var_to_bytes(_r36_root.global_basis)) if _m37_initialized else "","cloud_offset":[cloud_offset.x,cloud_offset.y,cloud_offset.z],"wind_time":wind_time,"wind_uniforms_exact":wind_uniforms_exact,"max_world_displacement_m":wind_bound,"maximum_proposed_wind_bound_m":_M37_WIND_BOUND,"wind_jacobian_lower_bound":_m37_jacobian_lower_bound,"wind_bound_kind":"analytic shader bound; no GPU vertex readback","canopy_visible_nodes":visible,"canopy_shadow_nodes":shadows,"canopy_instances":instances,"material_fork_count":_m37_materials.size(),"canopy_cull_margin_exact":cull_bounds_exact,"added_canopy_local_cull_margin_min":added_local_cull_margin_min if not _m37_canopies.is_empty() else 0.0,"added_canopy_local_cull_margin_max":added_local_cull_margin_max,"cull_scope":"Selected node extra_cull_margin conservatively expands by inverse-node-basis Frobenius norm times25mm; actual native MM AABB/customAABB/buffers remain exact.","rest_preservation":_m37_preservation.duplicate(true),"perframe_rest_validation":false,"private_rng_exact":str(_rng.state)==_m37_rng if _m37_initialized else false,"cloud_default_realization":_m37_cloud_realization.duplicate(),"cloud_night_amount":_m37_cloud.get_shader_parameter("night_amount") if _m37_cloud != null else night_amount,"cloud_rain_amount":_m37_cloud.get_shader_parameter("rain_amount") if _m37_cloud != null else rain_amount,"art_approved":false,"source_adopted":false,"native_adopted":false,"performance_measured":false,"scope":"Provisional .03deg/s coherent upper-sky yaw, explicitly timed clouds and 18mm sunny / 25mm rain maximum canopy-only root-anchored wind. Original sky local star poses, terrain/bake/rest meshes and all ground plants remain static. Visible/shadow canopy materials are isolated intentional forks with conservatively expanded selected node cull margins, not a claim of unchanged rendered shaders or all node properties. Clock0 Moon placement is preserved relative to the actual initialization camera; it then stays distant while the camera walks. Disable/reduced restore a static reference state; pause holds the running state without clock jump. No autonomous day/night cycle, gameplay/manual/UI/hardware/clearance/performance or art admission."}

func get_sky36_report() -> Dictionary:
	var report: Dictionary = super.get_sky36_report()
	report["scope"] = "Inherited Sky36 local star/constellation/native-rest construction proof only. Living37 world transforms/cloud and selected canopy shaders are declared separately by get_living_motion_report; this inherited report is not full material/light invariance or proof of rendered motion."
	return report
