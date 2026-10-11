extends "res://lineage/entrance52-appearance-proposal02/texture-world.gd"
# Disposable same-camera lighting proposal. Geometry, shaders and cleanup are inherited.
const _L49_SOURCE: String = "res://lineage/entrance52-appearance-proposal02/lighting-world.gd"
var _l49_performed: bool = false
var _l49_controls_applied: bool = false
var _l49_protected_exact: bool = false
var _l49_requested_controls: Dictionary = {}
var _l49_expected_native: Dictionary = {}
var _l49_protected_after: Dictionary = {}
var _l49_expected_direction: Vector3 = Vector3.ZERO
var _l49_rng_after: String = ""

func _l49_fp32(value: float) -> float:
	return float(PackedFloat32Array([value])[0])

func _l49_requested(n: float,r: float) -> Dictionary:
	return {"sun_rotation_degrees":Vector3(lerpf(-55.0,-27.45,n),lerpf(75.0,153.79,n),0.0),
		"sun_energy":lerpf(1.65,1.05,n)*lerpf(1.0,.63,r),"sun_color":Color("ffdaa2").lerp(Color("9bb3ed"),n),
		"ambient_energy":lerpf(.18,.50,n),"ambient_color":Color("d9d5c7").lerp(Color("b8bed0"),n),
		"fill_energy":lerpf(.05,.18,n),"fill_color":Color("c5d4df").lerp(Color("a5b7db"),n),
		"fog_density":lerpf(.0016,.007,r),"exposure":1.0}

func _l49_native_expected(requested: Dictionary) -> Dictionary:
	# Scalar property storage is independently encoded into FP32 before comparison.
	# Color and Vector3 constructors already use their native packed component domain.
	var expected: Dictionary = requested.duplicate()
	expected.erase("sun_rotation_degrees")
	for key: String in ["sun_energy","ambient_energy","fill_energy","fog_density","exposure"]:
		expected[key] = _l49_fp32(float(requested[key]))
	return expected

func _l49_actual_controls() -> Dictionary:
	if environment == null or not is_instance_valid(sun) or not is_instance_valid(_sky_fill): return {}
	return {"sun_energy":sun.light_energy,"sun_color":sun.light_color,
		"ambient_energy":environment.ambient_light_energy,"ambient_color":environment.ambient_light_color,
		"fill_energy":_sky_fill.light_energy,"fill_color":_sky_fill.light_color,
		"fog_density":environment.fog_density,"exposure":environment.tonemap_exposure}

func _l49_sha(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _l49_material(material: Material,details: bool=false) -> Dictionary:
	if material == null: return {"present":false}
	var result: Dictionary = {"present":true,"resource_id":str(material.get_instance_id()),"resource_path":material.resource_path,
		"render_priority":material.render_priority,"next_pass_id":str(material.next_pass.get_instance_id()) if material.next_pass != null else ""}
	var shader_material: ShaderMaterial = material as ShaderMaterial
	if shader_material != null and shader_material.shader != null:
		var uniforms: Dictionary = {}
		for uniform: Dictionary in shader_material.shader.get_shader_uniform_list():
			var key: String = str(uniform["name"])
			var value: Variant = shader_material.get_shader_parameter(key)
			uniforms[key] = {"type":typeof(value),"varhex":var_to_bytes(value).hex_encode()}
			if details: uniforms[key]["value"] = _l49_json(value)
		result["shader_id"] = str(shader_material.shader.get_instance_id())
		result["shader_path"] = shader_material.shader.resource_path
		result["declared_uniforms_sha256"] = _l49_sha(uniforms)
		if details: result["declared_uniforms"] = uniforms
	return result

func _l49_light(light: OmniLight3D) -> Dictionary:
	if not is_instance_valid(light): return {"present":false}
	return {"present":true,"node_path":str(light.get_path()),"instance_id":str(light.get_instance_id()),
		"color":light.light_color,"energy":light.light_energy,"range":light.omni_range,
		"attenuation":light.omni_attenuation,"shadow_enabled":light.shadow_enabled,"transform":light.transform}

func _l49_protected() -> Dictionary:
	var practicals: Array = []
	var cool_lights: Array = []
	var gills: Array = []
	var registry: Dictionary = {}
	for light: OmniLight3D in _practical_lights: practicals.append(_l49_light(light))
	for light: OmniLight3D in _night_lights: cool_lights.append(_l49_light(light))
	for material: ShaderMaterial in _gill_materials: gills.append(_l49_material(material,true))
	for key: String in _materials: registry[key] = _l49_material(_materials[key] as Material)
	return {"practical_lights":practicals,"cool_night_lights":cool_lights,"gill_materials":gills,"original_registry":registry,
		"water_material":_l49_material(_water_material),"fall_material":_l49_material(_fall_material),
		"moon_material":_l49_material(_moon.material_override if is_instance_valid(_moon) else null),
		"unchanged_environment":{"fog_color":environment.fog_light_color,"fog_enabled":environment.fog_enabled,
			"fog_sky_affect":environment.fog_sky_affect,"exposure":environment.tonemap_exposure,"tonemap_mode":environment.tonemap_mode,
			"ssao_enabled":environment.ssao_enabled,"ssao_radius":environment.ssao_radius,"ssao_intensity":environment.ssao_intensity,
			"ssr_enabled":environment.ssr_enabled,"ssr_max_steps":environment.ssr_max_steps,"ssr_depth_tolerance":environment.ssr_depth_tolerance,
			"glow_enabled":environment.glow_enabled,"glow_intensity":environment.glow_intensity,"glow_strength":environment.glow_strength},
		"unchanged_sun":{"shadow_enabled":sun.shadow_enabled,"angular_distance":sun.light_angular_distance,
			"shadow_max_distance":sun.directional_shadow_max_distance,"shadow_bias":sun.shadow_bias,"shadow_normal_bias":sun.shadow_normal_bias},
		"unchanged_fill":{"rotation":_sky_fill.rotation_degrees,"shadow_enabled":_sky_fill.shadow_enabled},"rng_state":str(_rng.state)}

func _apply_appearance() -> void:
	super._apply_appearance()
	if environment == null or not is_instance_valid(sun) or not is_instance_valid(_sky_fill): return
	# Run after inherited appearances, before child Sky and Motion anchor the Sun.
	var before: Dictionary = _l49_protected()
	_l49_requested_controls = _l49_requested(night_amount,rain_amount)
	_l49_expected_native = _l49_native_expected(_l49_requested_controls)
	sun.rotation_degrees = _l49_requested_controls["sun_rotation_degrees"]
	sun.light_energy = float(_l49_requested_controls["sun_energy"])
	sun.light_color = _l49_requested_controls["sun_color"]
	environment.ambient_light_energy = float(_l49_requested_controls["ambient_energy"])
	environment.ambient_light_color = _l49_requested_controls["ambient_color"]
	_sky_fill.light_energy = float(_l49_requested_controls["fill_energy"])
	_sky_fill.light_color = _l49_requested_controls["fill_color"]
	environment.fog_density = float(_l49_requested_controls["fog_density"])
	# Exposure remains the inherited 1.0; this wrapper does not assign it.
	var rotation: Vector3 = _l49_requested_controls["sun_rotation_degrees"]
	_l49_expected_direction = (global_basis*Basis.from_euler(rotation*deg_to_rad(1.0))).z.normalized()
	_l49_controls_applied = var_to_bytes(_l49_actual_controls()) == var_to_bytes(_l49_expected_native) and sun.global_basis.z.normalized().dot(_l49_expected_direction) > .999999
	_l49_protected_after = _l49_protected()
	_l49_protected_exact = var_to_bytes(before) == var_to_bytes(_l49_protected_after)
	_l49_rng_after = str(_rng.state)
	_l49_performed = true

func _l49_json(value: Variant) -> Variant:
	if value is Color: return [value.r,value.g,value.b,value.a]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2: return [value.x,value.y]
	if value is Basis: return [_l49_json(value.x),_l49_json(value.y),_l49_json(value.z)]
	if value is Transform3D: return {"basis":_l49_json(value.basis),"origin":_l49_json(value.origin)}
	if value is Array:
		var array_result: Array = []
		for item: Variant in value: array_result.append(_l49_json(item))
		return array_result
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key: Variant in value: dictionary_result[key] = _l49_json(value[key])
		return dictionary_result
	if value is Object: return {"object_id":str(value.get_instance_id())} if value != null else null
	return value

func get_lighting49_report() -> Dictionary:
	var actual: Dictionary = _l49_actual_controls()
	var valid: bool = not actual.is_empty() and _l49_performed
	var fresh_requested: Dictionary = _l49_requested(night_amount,rain_amount)
	var fresh_expected: Dictionary = _l49_native_expected(fresh_requested)
	var scalar_exact: bool = valid and var_to_bytes(actual) == var_to_bytes(fresh_expected) and var_to_bytes(_l49_expected_native) == var_to_bytes(fresh_expected)
	var current_protected: Dictionary = _l49_protected() if valid else {}
	var protected_exact: bool = valid and _l49_protected_exact and var_to_bytes(current_protected) == var_to_bytes(_l49_protected_after) and str(_rng.state) == _l49_rng_after
	var clock_inactive: bool = not bool(call("_m37_active")) if has_method("_m37_active") else true
	var light_direction: Vector3 = sun.global_basis.z.normalized() if valid else Vector3.ZERO
	var sun_mesh: Node3D = get("_r36_sun") as Node3D if valid else null
	var sky_root: Node3D = get("_r36_root") as Node3D if valid else null
	var visible_direction: Vector3 = (sun_mesh.global_position-sky_root.global_position).normalized() if is_instance_valid(sun_mesh) and is_instance_valid(sky_root) else Vector3.ZERO
	var requested_direction_dot: float = light_direction.dot(_l49_expected_direction)
	var visible_alignment_dot: float = light_direction.dot(visible_direction)
	var celestial_exact: bool = valid and clock_inactive and requested_direction_dot > .999999 and visible_alignment_dot > .999999
	var passed: bool = valid and _l49_controls_applied and scalar_exact and protected_exact and celestial_exact
	return {"schema":"mush-lighting49-proposal-observation/1","passed":passed,"performed":_l49_performed,
		"controls_applied":_l49_controls_applied and scalar_exact,"protected_practical_gill_and_registry_exact":protected_exact,
		"native_scalar_and_Color_readbacks_exact":scalar_exact,"scalar_comparison_domain":"independently encoded FP32 expected scalars; native Color components; exact Variant bytes",
		"source_path":_L49_SOURCE,"source_sha256":FileAccess.get_sha256(_L49_SOURCE),"parent_path":"res://lineage/entrance52-appearance-proposal02/texture-world.gd",
		"night_amount":night_amount,"rain_amount":rain_amount,"expected_requested":_l49_json(fresh_requested),"expected_native":_l49_json(fresh_expected),"actual_native":_l49_json(actual),
		"actual_sun_rotation_degrees":_l49_json(sun.rotation_degrees) if valid else [],"actual_sun_basis":_l49_json(sun.global_basis) if valid else [],
		"actual_moon_rotation_degrees":_l49_json(_moon.rotation_degrees) if is_instance_valid(_moon) else [],"actual_moon_global_position":_l49_json(_moon.global_position) if is_instance_valid(_moon) else [],
		"actual_fill_rotation_degrees":_l49_json(_sky_fill.rotation_degrees) if valid else [],"actual_fog_color":_l49_json(environment.fog_light_color) if valid else [],
		"light_direction":_l49_json(light_direction),"visible_sun_direction":_l49_json(visible_direction),"requested_direction_alignment_dot":requested_direction_dot,"sun_visible_disc_alignment_dot":visible_alignment_dot,
		"fixed_still_clock_inactive":clock_inactive,"celestial_anchor_alignment_passed":celestial_exact,"protected_readbacks":_l49_json(current_protected),"protected_snapshot_sha256":_l49_sha(current_protected),
		"tunable_values_proposed":true,"geometry_material_shader_changes":false,"art_approved":false,"source_adopted":false,"native_adopted":false,"motion_verified":false,"performance_measured":false,"Unreal_verified":false,
		"scope":"Lighting-only proposed fixed-clock same-camera checkpoint. Snapshot equality covers this wrapper's setter interval and current still readback, not a substitute for inherited geometry/material/native admission. Moon is the inherited sky mesh and the existing SunMoon light supplies night illumination. Native rendered pixels, reference fidelity, ordinary motion, gameplay and hardware performance require separate actual evidence."}
