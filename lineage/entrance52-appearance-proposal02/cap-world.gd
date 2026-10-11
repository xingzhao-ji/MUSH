extends "res://lineage/entrance52-appearance-proposal02/lighting-world.gd"
# Proposed main outer flesh only. All values remain disposable/tunable.
const _CAP51_SOURCE: String = "res://lineage/entrance52-appearance-proposal02/cap-world.gd"
const _CAP51_PARENT = preload("res://lineage/entrance52-appearance-proposal02/lighting-world.gd")
const _CAP51_PARENT_SHA: String = "c38a71792a48494d4db2c5bd8581df053c5b2294724b30771ae95b776f261810"
const _CAP51_TURN: float = .72
const _CAP51_PEAK: float = .30
var _cap51_old: Array[Vector2] = []
var _cap51_new: Array[Vector2] = []
var _cap51_profile_calls: int = 0
var _cap51_main_calls: int = 0
var _cap51_errors: Array[String] = []
var _cap51_native: Dictionary = {}
var _cap51_skin: MeshInstance3D
var _cap51_underbody: MeshInstance3D
var _cap51_channels: Dictionary = {}
var _cap51_protected: Dictionary = {}
var _cap51_ready: bool = false
var _cap51_protection_seal_calls: int = 0
var _cap51_batch_inputs: Dictionary = {}
var _cap51_batch_capture_calls: int = 0

func _cap_rolled_profile(radius: float,crown: float) -> Array[Vector2]:
	var source: Array[Vector2] = super._cap_rolled_profile(radius,crown)
	if not _r27_main_style(radius,crown): return source
	_cap51_profile_calls+=1
	_cap51_old=source.duplicate()
	if source.size()!=41:
		_cap51_errors.append("Main profile41 absent")
		return source
	var selected: Array[Vector2] = source.duplicate()
	var cut_x: float = float(source[22].x)
	var end_x: float = float(source[32].x)
	var turn: float = float(source[40].y)+_CAP51_TURN
	var peak: float = float(source[40].y)+_CAP51_PEAK
	var cut_slope: float = _shoulder30_source_dome_slope(cut_x/radius,radius)
	for row: int in range(23,33):
		var point: Vector2 = source[row]
		point.y=_shoulder30_hermite(float(source[22].y),turn,cut_slope,-1.90,float(point.x),cut_x,end_x)
		selected[row]=point
	var turn_dt: float = -1.90*3.0*radius*(1.006-.955)
	var join_dt: float = _shoulder30_source_return_slope(.875,radius)
	for row: int in range(33,39):
		var t: float = float(row-32)/8.0
		var point: Vector2 = source[row]
		point.y=_shoulder30_hermite(turn,peak,turn_dt,-.40,t,0,.625) if t<=.625 else _shoulder30_hermite(peak,float(source[39].y),-.40,join_dt,t,.625,.875)
		selected[row]=point
	_cap51_new=selected.duplicate()
	# Retain the old checker against ACTUAL new values: its old Y targets fail.
	_shoulder30_profile=selected.duplicate()
	_r27_selected_profile=selected.duplicate()
	return selected

func _cap51_profile_state() -> Dictionary:
	if _cap51_old.size()!=41 or _cap51_new.size()!=41: return {"passed":false,"reason":"Profile41 absent"}
	var xs_a: PackedFloat32Array = PackedFloat32Array()
	var xs_b: PackedFloat32Array = PackedFloat32Array()
	var protected: bool = true
	var descending: bool = true
	var changed: Array[int] = []
	var maximum_delta: float = 0.0
	for row: int in range(41):
		xs_a.append(_cap51_old[row].x);xs_b.append(_cap51_new[row].x)
		if row<=22 or row>=39: protected=protected and var_to_bytes(_cap51_old[row])==var_to_bytes(_cap51_new[row])
		if row>0: descending=descending and _cap51_new[row].y<_cap51_new[row-1].y
		if _cap51_old[row].y!=_cap51_new[row].y: changed.append(row)
		maximum_delta=maxf(maximum_delta,absf(float(_cap51_old[row].y)-float(_cap51_new[row].y)))
	var domain: bool = changed.size()==16
	for row: int in changed: domain=domain and row>=23 and row<=38
	var targets: bool = var_to_bytes(_cap51_new[32])==var_to_bytes(Vector2(_cap51_old[32].x,float(_cap51_old[40].y)+_CAP51_TURN)) and var_to_bytes(_cap51_new[37])==var_to_bytes(Vector2(_cap51_old[37].x,float(_cap51_old[40].y)+_CAP51_PEAK))
	return {"passed":protected and descending and domain and targets and xs_a.to_byte_array()==xs_b.to_byte_array(),"all41_X_native_bytes_exact":xs_a.to_byte_array()==xs_b.to_byte_array(),"positions0_22_and39_40_exact":protected,"changed_Y_rows":changed,"strictly_descending_native_Y":descending,"requested_native_targets_exact":targets,"maximum_native_profile_Y_delta_m":maximum_delta,"source_profile_sha256":_cap_preview_sha(PackedVector2Array(_cap51_old).to_byte_array()),"selected_profile_sha256":_cap_preview_sha(PackedVector2Array(_cap51_new).to_byte_array()),"actual_row32_above_lip":float(_cap51_new[32].y)-float(_cap51_new[40].y),"actual_row37_above_lip":float(_cap51_new[37].y)-float(_cap51_new[40].y)}

func _cap51_mesh_state(source: ArrayMesh,selected: ArrayMesh) -> Dictionary:
	if source==null or selected==null or source.get_surface_count()!=1 or selected.get_surface_count()!=1: return {"passed":false,"reason":"Native parent/current meshes absent"}
	var parity: Dictionary = _shoulder30_skin_parity(source,selected)
	var a: Array = source.surface_get_arrays(0)
	var b: Array = selected.surface_get_arrays(0)
	var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var an: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bn: PackedVector3Array = b[Mesh.ARRAY_NORMAL]
	if av.size()!=46080 or bv.size()!=av.size() or uv.size()!=av.size() or an.size()!=av.size() or bn.size()!=av.size(): return {"passed":false,"reason":"Native skin cardinality differs"}
	var p_a: PackedVector3Array = PackedVector3Array()
	var p_b: PackedVector3Array = PackedVector3Array()
	var normal_changes: int = 0
	for corner: int in range(av.size()):
		if uv[corner].y<=Vector2(0,22.0/40.0).y or uv[corner].y>=Vector2(0,39.0/40.0).y: p_a.append(av[corner]);p_b.append(bv[corner])
		if var_to_bytes(an[corner])!=var_to_bytes(bn[corner]): normal_changes+=1
	var quality: Dictionary = _shoulder30_quality(selected)
	var original_quality: Dictionary = _shoulder30_quality(source)
	var quality_passed: bool = quality["triangles"]==15360 and quality["nonfinite_corners"]==0 and quality["nonunit_normals"]==0 and quality["opposed_corners"]==0 and quality["degenerate_mask_sha256"]==original_quality["degenerate_mask_sha256"] and (quality["degenerate_ordinals"] as Array).size()==192
	return {"passed":parity.get("passed",false) and p_a.to_byte_array()==p_b.to_byte_array() and quality_passed and normal_changes>0,"parent30_native_channel_parity":parity,"positions0_22_and39_40_native_exact":p_a.to_byte_array()==p_b.to_byte_array(),"actual_triangle_normal_quality":quality,"parent_triangle_normal_quality":original_quality,"changed_normal_corners":normal_changes,"normal_scope":"Native identity only rings0..21 and40. Rings22..39 recompute by unchanged centered derivative; measured finite/unit/front agreement remains mandatory.","source_channels":_shoulder30_channels(source),"selected_channels":_shoulder30_channels(selected)}

func _cap(origin: Vector3,radius: float,crown: float,parent: Node3D) -> void:
	var main: bool = _r27_main_style(radius,crown) and origin==_R27_MAIN_ORIGIN and parent.name=="MushroomHome"
	var first: int = parent.get_child_count()
	var rng_before: String = str(_rng.state)
	super._cap(origin,radius,crown,parent)
	if not main: return
	_cap51_main_calls+=1
	for ordinal: int in range(first,parent.get_child_count()):
		var node: MeshInstance3D = parent.get_child(ordinal) as MeshInstance3D
		if node==null: continue
		if node.name=="FoldedPeachUmbrella": _cap51_skin=node
		if node.name=="ContinuousPleatedCreamUnderbody": _cap51_underbody=node
	if not is_instance_valid(_cap51_skin) or not is_instance_valid(_cap51_underbody):
		_cap51_errors.append("Main skin/cream underbody absent")
		return
	var reference: Node3D = _CAP51_PARENT.new() as Node3D
	var never_ready: bool = not reference.is_inside_tree()
	reference.set("_main_stem_wall_sectors",_main_stem_wall_sectors.duplicate())
	var profile: Array[Vector2] = reference.call("_cap_rolled_profile",radius,crown) as Array[Vector2]
	var source_mesh: ArrayMesh = reference.call("_cap_surface_mesh",profile,radius,true) as ArrayMesh
	var old_underbody: ArrayMesh = reference.call("_cap_main_pleated_underbody_mesh",radius) as ArrayMesh
	reference.free()
	var selected: ArrayMesh = _cap51_skin.mesh as ArrayMesh
	var mesh_state: Dictionary = _cap51_mesh_state(source_mesh,selected)
	var source_hit: Dictionary = _r27_skin_hit(source_mesh,Vector2(-.50,-.55))
	var current_hit: Dictionary = _r27_skin_hit(selected,Vector2(-.50,-.55))
	var attachment: bool = not source_hit.is_empty() and var_to_bytes(source_hit)==var_to_bytes(current_hit)
	var underbody: bool = var_to_bytes(_shoulder30_channels(old_underbody))==var_to_bytes(_shoulder30_channels(_cap51_underbody.mesh as ArrayMesh))
	var xf: Transform3D = Transform3D(Basis.IDENTITY,_R27_MAIN_ORIGIN)
	var transforms: bool = var_to_bytes(_cap51_skin.transform)==var_to_bytes(xf) and var_to_bytes(_cap51_underbody.transform)==var_to_bytes(xf)
	_cap51_channels=_shoulder30_channels(selected)
	_cap51_native={"passed":never_ready and mesh_state.get("passed",false) and attachment and underbody and transforms and rng_before==str(_rng.state),"mesh":mesh_state,"underbody_all13_format_primitive_exact":underbody,"skin_underbody_transform_exact":transforms,"chimney_native_packed_triangle_hit_exact":attachment,"attachment_source_sha256":_cap_preview_sha(var_to_bytes(source_hit)),"attachment_selected_sha256":_cap_preview_sha(var_to_bytes(current_hit)),"source_factory_never_tree_or_Ready":never_ready,"main_call_RNG_exact":rng_before==str(_rng.state)}

func _cap51_protection() -> Dictionary:
	var shapes: Dictionary = {}
	var todo: Array[Node] = [self]
	while not todo.is_empty():
		var node: Node = todo.pop_back()
		for child: Node in node.get_children(): todo.append(child)
		if not node is CollisionShape3D: continue
		var collision: CollisionShape3D = node as CollisionShape3D
		var shape: Shape3D = collision.shape
		var fields: Dictionary = {}
		if shape!=null:
			for prop: Dictionary in shape.get_property_list():
				var key: String = str(prop["name"])
				if key in ["script","resource_name","resource_path","resource_local_to_scene"]: continue
				if int(prop["usage"])&PROPERTY_USAGE_STORAGE: fields[key]=shape.get(key)
		shapes[str(node.get_path())]={"resource_id":str(shape.get_instance_id()) if shape!=null else "","class":shape.get_class() if shape!=null else "","global_transform":collision.global_transform,"disabled":collision.disabled,"body_id":str(collision.get_parent().get_instance_id()),"collision_layer":(collision.get_parent() as CollisionObject3D).collision_layer if collision.get_parent() is CollisionObject3D else -1,"collision_mask":(collision.get_parent() as CollisionObject3D).collision_mask if collision.get_parent() is CollisionObject3D else -1,"fields_sha256":_cap_preview_sha(var_to_bytes(fields))}
	var registry: Dictionary = {}
	for key: String in _materials:
		var material: Material = _materials[key] as Material
		registry[key]={"id":str(material.get_instance_id()),"shader_id":str((material as ShaderMaterial).shader.get_instance_id()) if material is ShaderMaterial and (material as ShaderMaterial).shader!=null else ""}
	var cap_bindings: Array = []
	for node: MeshInstance3D in [_cap51_skin,_cap51_underbody]:
		cap_bindings.append({"material_id":str(node.material_override.get_instance_id()) if is_instance_valid(node) and node.material_override!=null else "","transform":node.transform if is_instance_valid(node) else Transform3D.IDENTITY})
	var rng_exact: bool = true
	for call_record: Dictionary in _r27_cap_calls: rng_exact=rng_exact and call_record["rng_before"]==call_record["rng_after"]
	return {"all_cap_call_RNG_exact":rng_exact,"nonmain_cap_calls":_r27_cap_calls.size()-_r27_main_calls,"colliders":shapes.size(),"collider_native_sha256":_cap_preview_sha(var_to_bytes(shapes)),"original_registry_sha256":_cap_preview_sha(var_to_bytes(registry)),"cap_bindings_sha256":_cap_preview_sha(var_to_bytes(cap_bindings)),"scope":"Same-process native identities/fields; no cross-process Resource ID comparison. Selected canopy/cloud forks are inherited motion scope and are not mislabeled cap mutations."}

func _ready() -> void:
	super._ready()
	_cap51_bind_renderer_batches()
	call_deferred("_cap51_seal_protection")

func _cap51_seal_protection() -> void:
	_cap51_protection_seal_calls+=1
	if _cap51_protection_seal_calls!=1 or _cap51_ready:
		_cap51_errors.append("One setup-only deferred Cap51 protection seal required")
		_cap51_ready=false
		return
	_cap51_protected=_cap51_protection()
	_cap51_ready=true

func get_cap51_report() -> Dictionary:
	var legacy: Dictionary = super.get_cap_shoulder30_report()
	var old_native: Dictionary = legacy.get("native",{})
	var old_profile: Dictionary = old_native.get("profile",{})
	var old_source_quality: Dictionary = old_native.get("source_skin_quality",{})
	var old_selected_quality: Dictionary = old_native.get("selected_skin_quality",{})
	var old_quality_exact: bool = old_source_quality.get("triangles",-1)==15360 and old_selected_quality.get("triangles",-1)==15360 and old_source_quality.get("nonfinite_corners",-1)==0 and old_selected_quality.get("nonfinite_corners",-1)==0 and old_source_quality.get("nonunit_normals",-1)==0 and old_selected_quality.get("nonunit_normals",-1)==0 and old_source_quality.get("opposed_corners",-1)==0 and old_selected_quality.get("opposed_corners",-1)==0 and old_source_quality.get("degenerate_mask_sha256","")!= "" and old_source_quality.get("degenerate_mask_sha256","")==old_selected_quality.get("degenerate_mask_sha256","") and (old_source_quality.get("degenerate_ordinals",[]) as Array).size()==192
	var old_calls: Array = legacy.get("calls",[])
	var old_calls_rng_exact: bool = not old_calls.is_empty()
	for call_record: Dictionary in old_calls: old_calls_rng_exact=old_calls_rng_exact and call_record.get("rng_unchanged",false)
	var expected_policy_failure: bool = old_quality_exact and old_native.get("source_factory_never_tree_or_Ready",false) and old_native.get("main_call_rng_unchanged",false) and old_calls_rng_exact and legacy.get("main_calls",-1)==1 and legacy.get("main_profile_calls",-1)==1 and legacy.get("passed",true)==false and legacy.get("errors",[])==["Native main profile/quality/protected boundary/underbody/attachment admission failed"] and old_profile.get("targets_round_once_to_native_Vector2",true)==false and old_profile.get("all41_X_native_bytes_exact",false) and old_profile.get("rows0_through22_native_Vector2_exact",false) and old_profile.get("rows39_40_native_Vector2_exact",false) and old_profile.get("strictly_descending_sampled_Y",false) and old_native.get("native_skin_parity",{}).get("passed",false) and old_native.get("underbody_all13_slots_format_primitive_exact_to_source_factory",false) and old_native.get("skin_underbody_origin_Basis_exact",false) and old_native.get("inner_attachment_native_packed_triangle_hit_exact",false) and legacy.get("current_chimney_root",{}).get("passed",false) and _r27_status=="complete"
	var profile: Dictionary = _cap51_profile_state()
	var current: Dictionary = _cap51_protection() if _cap51_ready else {}
	var protected: bool = _cap51_ready and var_to_bytes(current)==var_to_bytes(_cap51_protected)
	var renderer: Dictionary = _cap51_renderer_state()
	var selected: bool = renderer.get("passed",false)
	var passed: bool = _cap51_ready and _cap51_errors.is_empty() and _cap51_main_calls==1 and _cap51_profile_calls==1 and profile.get("passed",false) and _cap51_native.get("passed",false) and protected and current.get("all_cap_call_RNG_exact",false) and selected and expected_policy_failure and FileAccess.get_sha256("res://lineage/entrance52-appearance-proposal02/lighting-world.gd")==_CAP51_PARENT_SHA
	return {"schema":"mush-cap51-main-outer-flesh/1","passed":passed,"performed":_cap51_ready,"errors":_cap51_errors.duplicate(),"source_path":_CAP51_SOURCE,"source_sha256":FileAccess.get_sha256(_CAP51_SOURCE),"profile":profile,"native":_cap51_native.duplicate(true),"current_selected_native_channels_exact":selected,"current_selected_native_channels_proof_mode":"ordered_source_to_current_native8m_batch_all13","current_renderer_native_batches":renderer,"actual_preencoding_raw_color_uniqueness_claimed":false,"current_collider_registry_cap_bindings_exact":protected,"protected_counts_hashes":current,"legacy30_exact_Y_policy_retired":true,"legacy30_report_passed":legacy.get("passed",false),"legacy30_failed_report":legacy,"legacy30_failure_exactly_expected_Y_policy_only":expected_policy_failure,"requested_tunables":{"turn32_above_lip_m":_CAP51_TURN,"max_radius37_above_lip_m":_CAP51_PEAK,"turn_slope":-1.90,"peak_return_dt":-.40},"angular_formula_changed":false,"height_dependent_angular_gate_changes_only_with_outer_profile":true,"new_angular_lobes_claimed":false,"new_parts_or_hidden_ring":false,"all_dimensions_proposed":true,"native_export_prepared":false,"art_approved":false,"source_adopted":false,"performance_measured":false,"scope":"Main skinY23..38 only; separate native parent30 parity/normal quality/cream underbody/chimney attachment/current protected bindings. Old30 exactY targets fail and remain nested. No wholeworld, contact, export or art acceptance claim."}

func get_cap_shoulder30_report() -> Dictionary:
	# Compatibility admission is explicitly the separately measured NEW shape.
	var new: Dictionary = get_cap51_report()
	var old: Dictionary = new.get("legacy30_failed_report",{}).duplicate(true)
	old["passed"]=new.get("passed",false)
	old["status"]="complete" if new.get("passed",false) else "refused"
	old["errors"]=[] if new.get("passed",false) else ["Cap51 native scoped proof refused; see get_cap51_report"]
	old["legacy30_original_passed"]=new.get("legacy30_report_passed",false)
	old["legacy30_exact_Y_policy_retired"]=true
	old["legacy30_failed_report"]=new.get("legacy30_failed_report",{})
	old["cap51_scoped_proof_schema"]=new.get("schema","")
	old["cap51_native_protected_channels_passed"]=new.get("passed",false)
	old["scope"]="Compatibility uses separateCap51 native protected-channel/normal/attachment proof. Original30 target policy FAILED and is nested unchanged; no certification of old Y design."
	return old

func get_review27_cap_report() -> Dictionary:
	var report: Dictionary = super.get_review27_cap_report()
	report["cap51_outer_Y_rows23_38_changed"]=true
	report["angular_formula_changed"]=false
	report["height_dependent_angular_gate_follows_new_outer_profile"]=true
	report["scope"]="Inherited27 innercrown, unequal valley formula, chimney/bake/nonmain contract retained. Cap51 changes outerY23..38 and its inherited height-dependent fine/angular gates; no new angular lobes. NativeCap51 and actual pixels remain separate."
	return report

func _cap_preview_install(skin: MeshInstance3D) -> Dictionary:
	# Capture AFTER the unchanged inherited private-material fork, BEFORE batching.
	var expected: Dictionary = super._cap_preview_install(skin)
	if not expected.is_empty() and not _cap51_capture_renderer_inputs():
		_cap51_batch_inputs.clear()
		_cap51_errors.append("Cap51 post-install/prebatch native source mapping refused")
	return expected

func _cap51_capture_renderer_inputs() -> bool:
	_cap51_batch_capture_calls+=1
	if _cap51_batch_capture_calls!=1 or not _cap51_batch_inputs.is_empty() or not is_instance_valid(_cap51_skin) or not is_instance_valid(_cap51_underbody): return false
	var inverse: Transform3D = global_transform.affine_inverse()
	var targets: Dictionary = {}
	for target: MeshInstance3D in [_cap51_skin,_cap51_underbody]:
		var mesh: ArrayMesh = target.mesh as ArrayMesh
		if mesh==null or mesh.get_surface_count()!=1 or mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES or target.material_override==null or not target.visible: return false
		if target==_moon or door_hinge.is_ancestor_of(target) or wall_plug.is_ancestor_of(target) or right_room.is_ancestor_of(target) or target.material_override==_water_material or target.material_override==_fall_material: return false
		var channels: Dictionary = _shoulder30_channels(mesh)
		var protected_channels: Dictionary = _cap51_channels if target==_cap51_skin else _shoulder30_native.get("underbody_native_selected",{})
		if var_to_bytes(channels)!=var_to_bytes(protected_channels): return false
		var xf: Transform3D = inverse*target.global_transform
		var key: String = "%s_%d_%d" % [target.material_override.get_instance_id(),int(floor(xf.origin.x/8.0)),int(floor(xf.origin.z/8.0))]
		if _cap51_batch_inputs.has(key): return false
		targets[str(target.get_instance_id())]="main_skin" if target==_cap51_skin else "cream_underbody"
		_cap51_batch_inputs[key]={"v":PackedVector3Array(),"n":PackedVector3Array(),"u":PackedVector2Array(),"c":PackedColorArray(),"material":target.material_override,"sources":[],"target_count":0,"target_channels":channels,"target_path":str(get_path_to(target)),"target_label":targets[str(target.get_instance_id())]}
	# Exact original ordered eligibility, material/8m key, surface/index expansion.
	for item: Node in find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = item as MeshInstance3D
		if node.mesh==null or not node.visible or node==_moon: continue
		if door_hinge.is_ancestor_of(node) or wall_plug.is_ancestor_of(node) or right_room.is_ancestor_of(node): continue
		var material: Material = node.material_override
		if material==null or material==_water_material or material==_fall_material: continue
		var xf: Transform3D = inverse*node.global_transform
		var key: String = "%s_%d_%d" % [material.get_instance_id(),int(floor(xf.origin.x/8.0)),int(floor(xf.origin.z/8.0))]
		if not _cap51_batch_inputs.has(key): continue
		var entry: Dictionary = _cap51_batch_inputs[key]
		var vertices: PackedVector3Array = entry["v"]
		var normals: PackedVector3Array = entry["n"]
		var uvs: PackedVector2Array = entry["u"]
		var colors: PackedColorArray = entry["c"]
		var first: int = vertices.size()
		var normal_transform: Basis = xf.basis.inverse().transposed()
		var surfaces: Array[Dictionary] = []
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			if arrays.is_empty(): continue
			if arrays.size()!=Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array: return false
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var u: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if n.size()!=v.size() or (not u.is_empty() and u.size()!=v.size()) or (not c.is_empty() and c.size()!=v.size()): return false
			var count: int = indices.size() if not indices.is_empty() else v.size()
			var start: int = vertices.size()
			for j: int in range(count):
				var i: int = indices[j] if not indices.is_empty() else j
				if i<0 or i>=v.size(): return false
				vertices.append(xf*v[i])
				normals.append((normal_transform*n[i]).normalized())
				uvs.append(u[i] if not u.is_empty() else Vector2.ZERO)
				colors.append(c[i] if not c.is_empty() else Color.WHITE)
			surfaces.append({"surface":surface,"first_corner":start,"corner_count":count,"primitive":node.mesh.surface_get_primitive_type(surface),"format":node.mesh.surface_get_format(surface),"source_all13_native_sha256":_cap_preview_sha(var_to_bytes(arrays))})
		var label: String = str(targets.get(str(node.get_instance_id()),"other_same_bucket_source"))
		if label!="other_same_bucket_source": entry["target_count"]=int(entry["target_count"])+1
		(entry["sources"] as Array).append({"node":node,"path":str(get_path_to(node)),"label":label,"world_relative_transform":xf,"local_transform":node.transform,"material":material,"visible":node.visible,"cast_shadow":node.cast_shadow,"first_corner":first,"corner_count":vertices.size()-first,"surfaces":surfaces})
		entry["v"]=vertices;entry["n"]=normals;entry["u"]=uvs;entry["c"]=colors
	for key: String in _cap51_batch_inputs:
		var entry: Dictionary = _cap51_batch_inputs[key]
		if int(entry["target_count"])!=1 or (entry["v"] as PackedVector3Array).is_empty(): return false
		# Scratch reference is never installed/drawn or retained as a live source mesh.
		var reference: ArrayMesh = _array_mesh(entry["v"],entry["n"],entry["u"],entry["c"])
		if reference==null or reference.get_surface_count()!=1: return false
		entry["expected_arrays"]=reference.surface_get_arrays(0)
		entry["expected_format"]=reference.surface_get_format(0)
		entry["expected_primitive"]=reference.surface_get_primitive_type(0)
		entry["expected_channels"]=_shoulder30_channels(reference)
		reference=null
		entry.erase("v");entry.erase("n");entry.erase("u");entry.erase("c")
	return _cap51_batch_inputs.size()==2

func _cap51_bind_renderer_batches() -> void:
	var seen: Dictionary = {}
	for item: Node in find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = item as MeshInstance3D
		if node.get_parent().name!="BatchedStaticWorld": continue
		var key: String = String(node.name).trim_prefix("Static_")
		if not _cap51_batch_inputs.has(key): continue
		if seen.has(key): _cap51_errors.append("Duplicate Cap51 current render bucket");continue
		seen[key]=true
		if node.mesh==null or not node.mesh is ArrayMesh:
			_cap51_errors.append("Cap51 current render bucket missing native mesh");continue
		var entry: Dictionary = _cap51_batch_inputs[key]
		entry["node"]=node;entry["mesh_id"]=str(node.mesh.get_instance_id());entry["parent"]=node.get_parent();entry["cast_shadow"]=node.cast_shadow
	if seen.size()!=2: _cap51_errors.append("Two Cap51 current renderer buckets required")
	if not _cap51_renderer_state().get("passed",false): _cap51_errors.append("Cap51 postbatch current native13 mapping refused")

func _cap51_renderer_state() -> Dictionary:
	var rows: Array[Dictionary] = []
	var passed: bool = _cap51_batch_capture_calls==1 and _cap51_batch_inputs.size()==2
	var current_cohort: int = 0
	for item: Node in find_children("*","MeshInstance3D",true,false):
		var candidate: MeshInstance3D = item as MeshInstance3D
		if candidate.mesh==null: continue
		for key: String in _cap51_batch_inputs:
			if candidate.material_override==_cap51_batch_inputs[key]["material"]: current_cohort+=1
	passed=passed and current_cohort==2
	for key: String in _cap51_batch_inputs:
		var entry: Dictionary = _cap51_batch_inputs[key]
		var node: MeshInstance3D = entry.get("node") as MeshInstance3D
		if not is_instance_valid(node) or node.mesh==null or not node.mesh is ArrayMesh:
			passed=false;rows.append({"key":key,"passed":false,"reason":"Current renderer native batch absent"});continue
		var mesh: ArrayMesh = node.mesh as ArrayMesh
		if mesh.get_surface_count()!=1:
			passed=false;rows.append({"key":key,"passed":false,"reason":"Current native surface count differs"});continue
		var arrays: Array = mesh.surface_get_arrays(0)
		if arrays.size()!=Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			passed=false;rows.append({"key":key,"passed":false,"reason":"Current native13/position array absent"});continue
		var expected: Array = entry["expected_arrays"]
		var channels: Dictionary = _shoulder30_channels(mesh)
		var encoded: bool = var_to_bytes(arrays)==var_to_bytes(expected) and var_to_bytes(channels)==var_to_bytes(entry["expected_channels"])
		var bound: bool = node.get_parent()==entry.get("parent") and node.get_parent().name=="BatchedStaticWorld" and String(node.name)=="Static_"+key and str(mesh.get_instance_id())==entry.get("mesh_id","") and node.material_override==entry["material"] and var_to_bytes(node.transform)==var_to_bytes(Transform3D.IDENTITY) and var_to_bytes(global_transform.affine_inverse()*node.global_transform)==var_to_bytes(Transform3D.IDENTITY) and node.visible and node.is_visible_in_tree() and node.cast_shadow==entry["cast_shadow"] and mesh.surface_get_format(0)==entry["expected_format"] and mesh.surface_get_primitive_type(0)==entry["expected_primitive"] and mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES
		var sources_exact: bool = true
		var spans: Array[Dictionary] = []
		var next_corner: int = 0
		var mapped_targets: int = 0
		for source: Dictionary in entry["sources"]:
			var original: MeshInstance3D = source["node"] as MeshInstance3D
			var source_exact: bool = is_instance_valid(original) and original.mesh==null and original.material_override==source["material"] and original.visible==source["visible"] and original.cast_shadow==source["cast_shadow"] and var_to_bytes(original.transform)==var_to_bytes(source["local_transform"]) and var_to_bytes(global_transform.affine_inverse()*original.global_transform)==var_to_bytes(source["world_relative_transform"]) and str(get_path_to(original))==source["path"] and int(source["first_corner"])==next_corner and int(source["corner_count"])>0
			sources_exact=sources_exact and source_exact
			next_corner+=int(source["corner_count"])
			if source["label"]!="other_same_bucket_source": mapped_targets+=1
			spans.append({"source_path":source["path"],"label":source["label"],"first_corner":source["first_corner"],"corner_count":source["corner_count"],"source_mesh_null_after_batch":is_instance_valid(original) and original.mesh==null,"source_binding_transform_exact":source_exact,"surface_spans":source["surfaces"]})
		var complete: bool = next_corner==(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() and mapped_targets==1 and int(entry["target_count"])==1
		var strict: bool = encoded and bound and sources_exact and complete
		passed=passed and strict
		rows.append({"key":key,"passed":strict,"renderer_path":str(get_path_to(node)),"target_path":entry["target_path"],"target_label":entry["target_label"],"vertices":(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),"actual_all13_native_sha256":_cap_preview_sha(var_to_bytes(arrays)),"expected_all13_native_sha256":_cap_preview_sha(var_to_bytes(expected)),"all13_native_encoder_exact":encoded,"current_node_mesh_material_transform_format_primitive_identity_exact":bound,"source_null_state_binding_transform_exact":sources_exact,"ordered_source_spans_cover_entire_bucket":complete,"source_local_channel_hashes":entry["target_channels"],"source_spans":spans,"format":mesh.surface_get_format(0),"primitive":mesh.surface_get_primitive_type(0)})
	return {"schema":"mush-cap51-current-render-batches/1","passed":passed,"performed":_cap51_batch_capture_calls==1,"batch_count":rows.size(),"actual_current_material_cohort_count":current_cohort,"target_source_count":2,"rows":rows,"proof_mode":"ordered_source_to_current_native8m_batch_all13","source_mesh_restored":false,"duplicate_geometry_installed":false,"scratch_mesh_ever_installed_or_tree_entered":false,"actual_preencoding_raw_color_uniqueness_claimed":false,"scope":"Construction-local native13/profile/quality/attachment proof is retained separately. Current rendering is proven through original ordered source transforms/index expansion and original native encoder into actual installed batches; native encoding is lossy, so raw-color uniqueness is not claimed. Getter performs only native readback."}
