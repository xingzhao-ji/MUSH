extends "res://lineage/timber28-proposal01/timber-world.gd"
# Main-only compact shoulder/return proposal. No Ready, shader, normal or bake override.
const _SHOULDER30_PARENT = preload("res://lineage/timber28-proposal01/timber-world.gd")
const _SHOULDER30_PARENT_SHA: String = "b4d9de5e076a71eaf980aa4abecad79da6821db053f5d77d7c4c590810ebd246"
var _shoulder30_errors: Array[String] = []
var _shoulder30_source_profile: Array[Vector2] = []
var _shoulder30_profile: Array[Vector2] = []
var _shoulder30_profile_calls: int = 0
var _shoulder30_main_calls: int = 0
var _shoulder30_calls: Array[Dictionary] = []
var _shoulder30_native: Dictionary = {}
var _shoulder30_source_skin: ArrayMesh
var _shoulder30_skin: ArrayMesh
var _shoulder30_attachment_source: Dictionary = {}
var _shoulder30_attachment_selected: Dictionary = {}

func _shoulder30_hermite(a: float,b: float,ma: float,mb: float,x: float,xa: float,xb: float) -> float:
	var t: float = (x-xa)/(xb-xa)
	var t2: float = t*t
	var t3: float = t2*t
	return (2.0*t3-3.0*t2+1.0)*a+(t3-2.0*t2+t)*(xb-xa)*ma+(-2.0*t3+3.0*t2)*b+(t3-t2)*(xb-xa)*mb

func _shoulder30_source_dome_slope(fraction: float,radius: float) -> float:
	# dy/df is converted to dy/dx by dividing by radius. At preserved row22,
	# inherited .009 shoulder is constant; only .020 outer reduction varies.
	var t: float = (fraction-0.800)/(0.955-0.800)
	var reduction_derivative: float = 6.0*t*(1.0-t)/(0.955-0.800)
	return (-2.0*3.10*0.49*fraction*pow(1.0-fraction*fraction,-0.51)-radius*0.020*reduction_derivative)/radius

func _shoulder30_source_return_slope(t: float,radius: float) -> float:
	# Parametric dy/dt from the inherited cubic plus .025R roll bell. Source
	# packed values anchor endpoints; this scalar continuation is a model tangent.
	var start: float = float(_shoulder30_source_profile[32].y)
	var finish: float = float(_shoulder30_source_profile[40].y)
	var dome_dy_df: float = -2.0*3.10*0.49*0.955*pow(1.0-0.955*0.955,-0.51)
	var control_a: float = start+dome_dy_df*(1.006-0.955)
	var control_b: float = finish+(radius*0.015*PI/0.617)*(1.014-0.972)
	var u: float = 1.0-t
	return 3.0*((control_a-start)*u*u+2.0*(control_b-control_a)*u*t+(finish-control_b)*t*t)+radius*0.025*PI*sin(TAU*t)

func _cap_rolled_profile(radius: float,crown: float) -> Array[Vector2]:
	var source: Array[Vector2] = super._cap_rolled_profile(radius,crown)
	if not _r27_main_style(radius,crown): return source
	_shoulder30_profile_calls += 1
	_shoulder30_source_profile = source.duplicate()
	if source.size() != 41 or float(source[21].x)/radius > 0.82 or float(source[22].x)/radius <= 0.82 or float(source[22].x)/radius >= 0.88:
		_shoulder30_errors.append("Verified41 source rows/protected halo identity differs")
		return source
	var selected: Array[Vector2] = source.duplicate()
	var cut_x: float = float(source[22].x)
	var cut_y: float = float(source[22].y)
	var end_x: float = float(source[32].x)
	var lip_y: float = float(source[40].y)
	var turn_y: float = lip_y+0.50
	var peak_y: float = lip_y+0.14
	var cut_slope: float = _shoulder30_source_dome_slope(cut_x/radius,radius)
	var turn_slope: float = -1.90
	# Preserve row22 position as an additional halo so native row21 normals stay.
	for row: int in range(23,33):
		var point: Vector2 = source[row]
		point.y = _shoulder30_hermite(cut_y,turn_y,cut_slope,turn_slope,float(point.x),cut_x,end_x)
		selected[row] = point
	var turn_dt: float = turn_slope*3.0*radius*(1.006-0.955)
	var peak_dt: float = -0.40
	var join_dt: float = _shoulder30_source_return_slope(0.875,radius)
	# Return X turns back inward: fit Y in its original parametric t, not radial X.
	for row: int in range(33,39):
		var t: float = float(row-32)/8.0
		var point: Vector2 = source[row]
		if t <= 0.625:
			point.y = _shoulder30_hermite(turn_y,peak_y,turn_dt,peak_dt,t,0.0,0.625)
		else:
			point.y = _shoulder30_hermite(peak_y,float(source[39].y),peak_dt,join_dt,t,0.625,0.875)
		selected[row] = point
	# Source39/40 remain byte-exact, retaining actual centered-difference lip40 N.
	_shoulder30_profile = selected.duplicate()
	_r27_selected_profile = selected.duplicate() # Parent record reflects actual selected41.
	return selected

func _shoulder30_channels(mesh: ArrayMesh) -> Dictionary:
	var records: Array = []
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var slots: Array = []
		for slot: int in range(arrays.size()):
			var value: Variant = arrays[slot]
			var data: PackedByteArray = PackedByteArray()
			if value != null: data = value if value is PackedByteArray else value.to_byte_array()
			slots.append({"slot":slot,"type":typeof(value),"null":value == null,"sha256":_cap_preview_sha(data)})
		records.append({"primitive":mesh.surface_get_primitive_type(surface),"format":mesh.surface_get_format(surface),"slots":slots})
	return {"class":mesh.get_class(),"surfaces":records}

func _shoulder30_quality(mesh: ArrayMesh) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	var degenerate: PackedInt32Array = PackedInt32Array()
	var nonfinite: int = 0
	var nonunit: int = 0
	var opposed: int = 0
	var minimum_dot: float = INF
	var first_bad: Dictionary = {}
	for corner: int in range(count):
		var index: int = indices[corner] if not indices.is_empty() else corner
		if not vertices[index].is_finite() or not normals[index].is_finite(): nonfinite += 1
		var size: float = normals[index].length()
		if size < 0.995 or size > 1.005: nonunit += 1
	for ordinal: int in range(count/3):
		var a_index: int = indices[ordinal*3] if not indices.is_empty() else ordinal*3
		var b_index: int = indices[ordinal*3+1] if not indices.is_empty() else ordinal*3+1
		var c_index: int = indices[ordinal*3+2] if not indices.is_empty() else ordinal*3+2
		var front: Vector3 = (vertices[c_index]-vertices[a_index]).cross(vertices[b_index]-vertices[a_index])
		if front.length_squared() == 0.0:
			degenerate.append(ordinal)
			continue
		front = front.normalized()
		for index: int in [a_index,b_index,c_index]:
			var agreement: float = front.dot(normals[index])
			minimum_dot = minf(minimum_dot,agreement)
			if not is_finite(agreement) or agreement <= 0.0:
				opposed += 1
				if first_bad.is_empty(): first_bad = {"face":ordinal,"corner":index,"dot":agreement,"a":str(vertices[a_index]),"b":str(vertices[b_index]),"c":str(vertices[c_index]),"normal":str(normals[index])}
	return {"surfaces":mesh.get_surface_count(),"triangles":count/3,"nonfinite_corners":nonfinite,"nonunit_normals":nonunit,"opposed_corners":opposed,"minimum_front_dot":minimum_dot,"degenerate_ordinals":Array(degenerate),"degenerate_mask_sha256":_cap_preview_sha(degenerate.to_byte_array()),"first_bad":first_bad}

func _shoulder30_skin_parity(source: ArrayMesh,selected: ArrayMesh) -> Dictionary:
	var a: Array = source.surface_get_arrays(0)
	var b: Array = selected.surface_get_arrays(0)
	var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var an: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bn: PackedVector3Array = b[Mesh.ARRAY_NORMAL]
	var au: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var source_xz: PackedVector2Array = PackedVector2Array()
	var selected_xz: PackedVector2Array = PackedVector2Array()
	var inner_a: PackedVector3Array = PackedVector3Array()
	var inner_b: PackedVector3Array = PackedVector3Array()
	var lip_a: PackedVector3Array = PackedVector3Array()
	var lip_b: PackedVector3Array = PackedVector3Array()
	var inner_uv: float = Vector2(0.0,21.0/40.0).y
	var maximum_delta: float = 0.0
	if av.size() != bv.size() or av.size() != 46080 or an.size() != bn.size(): return {"passed":false,"reason":"Native skin stream cardinality differs"}
	for corner: int in range(av.size()):
		source_xz.append(Vector2(av[corner].x,av[corner].z))
		selected_xz.append(Vector2(bv[corner].x,bv[corner].z))
		maximum_delta = maxf(maximum_delta,absf(av[corner].y-bv[corner].y))
		if au[corner].y <= inner_uv:
			inner_a.append_array(PackedVector3Array([av[corner],an[corner]]))
			inner_b.append_array(PackedVector3Array([bv[corner],bn[corner]]))
		if au[corner].y == 1.0:
			lip_a.append_array(PackedVector3Array([av[corner],an[corner]]))
			lip_b.append_array(PackedVector3Array([bv[corner],bn[corner]]))
	var other_slots: bool = true
	for slot: int in range(Mesh.ARRAY_MAX):
		if slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]: continue
		if typeof(a[slot]) != typeof(b[slot]) or var_to_bytes(a[slot]) != var_to_bytes(b[slot]): other_slots = false
	var xz_exact: bool = source_xz.to_byte_array() == selected_xz.to_byte_array()
	var inner_exact: bool = inner_a.to_byte_array() == inner_b.to_byte_array()
	var lip_exact: bool = lip_a.to_byte_array() == lip_b.to_byte_array()
	var format_exact: bool = source.surface_get_format(0) == selected.surface_get_format(0) and source.surface_get_primitive_type(0) == selected.surface_get_primitive_type(0)
	return {"passed":xz_exact and inner_exact and lip_exact and other_slots and format_exact,"all_XZ_exact":xz_exact,"UV_COLOR_INDEX_other_slots_exact":other_slots,"format_primitive_exact":format_exact,"inner_through_row21_V_N_exact":inner_exact,"inner_source_sha256":_cap_preview_sha(inner_a.to_byte_array()),"inner_selected_sha256":_cap_preview_sha(inner_b.to_byte_array()),"lip40_V_N_exact":lip_exact,"lip_source_sha256":_cap_preview_sha(lip_a.to_byte_array()),"lip_selected_sha256":_cap_preview_sha(lip_b.to_byte_array()),"maximum_native_Y_delta_m":maximum_delta,"normal_halo":"Row22 NORMAL may change outside protected fraction<=.82; row22 position stays exact."}

func _shoulder30_profile_proof() -> Dictionary:
	var old: PackedVector2Array = PackedVector2Array(_shoulder30_source_profile)
	var new: PackedVector2Array = PackedVector2Array(_shoulder30_profile)
	var xs_old: PackedFloat32Array = PackedFloat32Array()
	var xs_new: PackedFloat32Array = PackedFloat32Array()
	var inner_exact: bool = true
	var end_exact: bool = true
	var descending: bool = true
	var peak_index: int = 0
	var maximum_delta: float = 0.0
	for row: int in range(old.size()):
		xs_old.append(old[row].x);xs_new.append(new[row].x)
		maximum_delta = maxf(maximum_delta,absf(old[row].y-new[row].y))
		if row <= 22 and var_to_bytes(old[row]) != var_to_bytes(new[row]): inner_exact = false
		if row >= 39 and var_to_bytes(old[row]) != var_to_bytes(new[row]): end_exact = false
		if row > 0 and new[row].y >= new[row-1].y: descending = false
		if new[row].x > new[peak_index].x: peak_index = row
	var turn_expected: Vector2 = Vector2(old[32].x,float(old[40].y)+0.50)
	var peak_expected: Vector2 = Vector2(old[37].x,float(old[40].y)+0.14)
	var targets: bool = var_to_bytes(new[32]) == var_to_bytes(turn_expected) and var_to_bytes(new[37]) == var_to_bytes(peak_expected) and peak_index == 37
	var x_exact: bool = xs_old.to_byte_array() == xs_new.to_byte_array()
	var rows_old: Array = []
	var rows_new: Array = []
	for row: int in range(old.size()): rows_old.append([old[row].x,old[row].y]);rows_new.append([new[row].x,new[row].y])
	return {"passed":old.size() == 41 and new.size() == 41 and x_exact and inner_exact and end_exact and descending and targets,"source":rows_old,"selected":rows_new,"all41_X_native_bytes_exact":x_exact,"rows0_through22_native_Vector2_exact":inner_exact,"rows39_40_native_Vector2_exact":end_exact,"strictly_descending_sampled_Y":descending,"targets_round_once_to_native_Vector2":targets,"maximum_radius_row":peak_index,"maximum_radius_height_above_lip_m":float(new[peak_index].y)-float(new[40].y),"maximum_profile_Y_delta_m":maximum_delta,"source_profile_sha256":_cap_preview_sha(old.to_byte_array()),"selected_profile_sha256":_cap_preview_sha(new.to_byte_array()),"C1_scope":"Scalar Hermite continuation from row22 source tangent, main shoulder at32, parametric return at37, source39 continuation;39/40 native positions fixed. Native facets/normals are checked separately; no native-facet C1 equality claim."}

func _cap(origin: Vector3,radius: float,crown: float,parent: Node3D) -> void:
	var main: bool = _r27_main_style(radius,crown) and origin == _R27_MAIN_ORIGIN and parent.name == "MushroomHome"
	var first: int = parent.get_child_count()
	var rng_before: String = str(_rng.state)
	super._cap(origin,radius,crown,parent)
	_shoulder30_calls.append({"main":main,"radius":radius,"crown":crown,"origin":str(origin),"parent":String(parent.name),"rng_unchanged":rng_before == str(_rng.state)})
	if not main: return
	_shoulder30_main_calls += 1
	var skin: MeshInstance3D
	var underbody: MeshInstance3D
	for ordinal: int in range(first,parent.get_child_count()):
		var node: MeshInstance3D = parent.get_child(ordinal) as MeshInstance3D
		if node == null: continue
		if node.name == "FoldedPeachUmbrella": skin = node
		if node.name == "ContinuousPleatedCreamUnderbody": underbody = node
	if skin == null or underbody == null or _shoulder30_source_profile.size() != 41 or _shoulder30_profile.size() != 41:
		_shoulder30_errors.append("Verified main skin/underbody/profile41 absent")
		return
	var reference: Node3D = _SHOULDER30_PARENT.new() as Node3D
	var never_tree: bool = not reference.is_inside_tree()
	# Exact unchanged native wall cache is required by the original neck ray query.
	reference.set("_main_stem_wall_sectors",_main_stem_wall_sectors.duplicate())
	_shoulder30_source_skin = reference.call("_cap_surface_mesh",_shoulder30_source_profile,radius,true) as ArrayMesh
	var old_underbody: ArrayMesh = reference.call("_cap_main_pleated_underbody_mesh",radius) as ArrayMesh
	reference.free()
	_shoulder30_skin = skin.mesh as ArrayMesh
	var source_quality: Dictionary = _shoulder30_quality(_shoulder30_source_skin)
	var selected_quality: Dictionary = _shoulder30_quality(_shoulder30_skin)
	var parity: Dictionary = _shoulder30_skin_parity(_shoulder30_source_skin,_shoulder30_skin)
	var profile_proof: Dictionary = _shoulder30_profile_proof()
	var underbody_exact: bool = var_to_bytes(_shoulder30_channels(old_underbody)) == var_to_bytes(_shoulder30_channels(underbody.mesh as ArrayMesh))
	var transform_expected: Transform3D = Transform3D(Basis.IDENTITY,_R27_MAIN_ORIGIN)
	var transforms_exact: bool = var_to_bytes(skin.transform) == var_to_bytes(transform_expected) and var_to_bytes(underbody.transform) == var_to_bytes(transform_expected)
	var quality: bool = source_quality["triangles"] == 15360 and selected_quality["triangles"] == 15360 and source_quality["nonfinite_corners"] == 0 and selected_quality["nonfinite_corners"] == 0 and source_quality["nonunit_normals"] == 0 and selected_quality["nonunit_normals"] == 0 and source_quality["opposed_corners"] == 0 and selected_quality["opposed_corners"] == 0 and source_quality["degenerate_mask_sha256"] == selected_quality["degenerate_mask_sha256"] and (source_quality["degenerate_ordinals"] as Array).size() == 192
	_shoulder30_attachment_source = _r27_skin_hit(_shoulder30_source_skin,Vector2(-0.50,-0.55))
	_shoulder30_attachment_selected = _r27_skin_hit(_shoulder30_skin,Vector2(-0.50,-0.55))
	var attachment_exact: bool = not _shoulder30_attachment_source.is_empty() and var_to_bytes(_shoulder30_attachment_source) == var_to_bytes(_shoulder30_attachment_selected)
	var passed: bool = never_tree and quality and bool(parity["passed"]) and bool(profile_proof["passed"]) and underbody_exact and transforms_exact and attachment_exact and rng_before == str(_rng.state)
	_shoulder30_native = {"passed":passed,"profile":profile_proof,"source_skin_quality":source_quality,"selected_skin_quality":selected_quality,"native_skin_parity":parity,"underbody_all13_slots_format_primitive_exact_to_source_factory":underbody_exact,"underbody_native_source":_shoulder30_channels(old_underbody),"underbody_native_selected":_shoulder30_channels(underbody.mesh as ArrayMesh),"source_factory_never_tree_or_Ready":never_tree,"source_factory_wall_cache_sectors":_main_stem_wall_sectors.size(),"skin_underbody_origin_Basis_exact":transforms_exact,"source_skin_local_bounds":str(_shoulder30_source_skin.get_aabb()),"selected_skin_local_bounds":str(_shoulder30_skin.get_aabb()),"inner_attachment_native_packed_triangle_hit_exact":attachment_exact,"source_attachment_hit":_shoulder30_attachment_source,"selected_attachment_hit":_shoulder30_attachment_selected,"main_call_rng_unchanged":rng_before == str(_rng.state)}
	if not passed: _shoulder30_errors.append("Native main profile/quality/protected boundary/underbody/attachment admission failed")

func get_cap_shoulder30_report() -> Dictionary:
	var root_exact: bool = false
	var root_proof: Dictionary = {}
	if not _r27_chimney.is_empty() and not _shoulder30_attachment_source.is_empty():
		var original_hit: Dictionary = _r27_chimney["baseline_hit"] as Dictionary
		var expected: Transform3D = _r27_chimney["baseline_root_transform"]
		var delta: float = float(_shoulder30_attachment_source["height"])-float(original_hit["height"])
		expected.origin.y = float(expected.origin.y)+delta
		var node: Node3D = _r27_chimney["node"] as Node3D
		root_exact = var_to_bytes(expected) == var_to_bytes(node.transform) and var_to_bytes(expected) == var_to_bytes(_r27_chimney["selected_root_transform"])
		root_proof = {"passed":root_exact,"expected_native_Transform3D_hex":var_to_bytes(expected).hex_encode(),"actual_native_Transform3D_hex":var_to_bytes(node.transform).hex_encode(),"rule":"Source timber28 skin packed triangle top hit minus retained Parent25 top hit; parent original root plus same scalar delta quantized once to nativeY. No get_faces/snap."}
	var rng_exact: bool = true
	for call_record: Dictionary in _shoulder30_calls: rng_exact = rng_exact and bool(call_record["rng_unchanged"])
	var passed: bool = _shoulder30_errors.is_empty() and _shoulder30_main_calls == 1 and _shoulder30_profile_calls == 1 and bool(_shoulder30_native.get("passed",false)) and root_exact and rng_exact and _r27_status == "complete"
	var errors: Array[String] = _shoulder30_errors.duplicate()
	if not root_exact: errors.append("Current chimney root does not match source native attachment")
	if _r27_status != "complete": errors.append("Inherited normal27 construction incomplete")
	return {"schema":"mush-cap-shoulder30-main-only/1","passed":passed,"status":"complete" if passed else "refused","errors":errors,"main_calls":_shoulder30_main_calls,"main_profile_calls":_shoulder30_profile_calls,"calls":_shoulder30_calls.duplicate(true),"native":_shoulder30_native.duplicate(true),"current_chimney_root":root_proof,"scope":"Main peach outer shoulder/return Y only, regenerated native normals/tangents by unchanged surface mesh. Inner positions+N throughfraction<=.82, extra row22 positional halo, all41 radialX, full nativeXZ/UV/COLOR/INDEX/format and exact lip40 positions+N retained. Actual underbody13 and chimney native attachment/root match source factory. All unrelated geometry/material/light/physics/RNG/bake functions remain inherited; no full144 fresh/wholeworld/clearance/performance/art approval/adoption claim."}
