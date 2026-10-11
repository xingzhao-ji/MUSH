# Provisional52 source-only authored worn stone volumes, extending preserved Source30.
# Floor support and full closed collision solids have explicit separate native authorities.
extends "res://lineage/cap-shoulder30-proposal01/shoulder-world.gd"
const _L35_PATH: String = "res://lineage/entrance52-author02/landform-world.gd"
const _L35_DATA: String = "res://lineage/entrance52-author02/descriptor.json"
const _L35_DIR: String = "res://lineage/entrance-landform52-owned-bake02/"
const _L46_EXPECTED_BAKE_DIR: String = "res://lineage/entrance-landform52-owned-bake02/"
const _L35_REV: String = "entrance-landform52-v1"
const _L35_SCHEMA: String = "rooted-foreground-groups-entrance52-v1"
var _l35_data: Dictionary = {}
var _l35_errors: Array[String] = []
var _l35_materials: Dictionary = {}
var _l35_shared_uniforms: Dictionary = {}
var _l35_shared_materials: Dictionary = {}
var _l35_material_resolution: Dictionary = {}
var _l35_registry_bindings: Dictionary = {}
var _l35_shared_uniform_values: Dictionary = {}
var _l35_selected_uniforms: Dictionary = {}
var _l35_selected_uniform_values: Dictionary = {}
var _l35_material_states: Dictionary = {}
var _l35_render: Array[Dictionary] = []
var _l35_batches: Array[Dictionary] = []
var _l35_prefixes: Array[Dictionary] = []
var _l35_hidden: Array[Dictionary] = []
var _l35_entry_foliage: Array[Dictionary] = []
var _l35_joins: Array[Dictionary] = []
var _l35_contact_indices: Array[int] = []
var _l35_quality: Dictionary = {}
var _l35_collision: Dictionary = {}
var _l35_roundtrip: Dictionary = {}
var _l35_batch_report: Dictionary = {"passed":false,"mode":"pending"}
var _l35_bake: Dictionary = {"mode":"not_started"}
var _l35_fingerprint: String = ""
var _l35_ready: bool = false
var _l35_consumed: bool = false
var _l35_materials_ready: bool = false
var _l35_tread_semantics: Dictionary = {"passed":false}
var _l35_grid_xs: Array[float] = []
var _l35_shape_rows: Dictionary = {}
var _l35_path_parameter_faces: PackedVector3Array = PackedVector3Array()
var _l35_path_selected_faces: PackedVector3Array = PackedVector3Array()
var _l35_path_labels: Array[Dictionary] = []
var _l35_shape_report: Dictionary = {"passed":false}
var _l35_path_role_codes: PackedInt32Array = PackedInt32Array()
var _l35_path_q_parameters: PackedFloat64Array = PackedFloat64Array()
var _l35_walking_faces: PackedVector3Array = PackedVector3Array()
var _l35_nonwalking_faces: PackedVector3Array = PackedVector3Array()
var _l35_walking_intrinsic: PackedVector3Array = PackedVector3Array()
var _l35_nonwalking_intrinsic: PackedVector3Array = PackedVector3Array()
var _l35_front09_report: Dictionary = {"passed":false}
var _l35_boundary_seam_report: Dictionary = {"schema":"mush-entrance35-native-boundary-seam-correction/1","passed":false,"status":"pending"}
var _l35_pose_rejections: Array[Dictionary] = []
var _l35_pose_candidates: int = 0
var _l35_entry_callers: int = 0 # Original legacy-four caller count; expected240.
var _l35_fairy_callers: int = 0 # Exact existing clustered fairy/_glow_mesh callers; measured, not assumed2.
# Mesh Resources are private cache keys only; none are serialized/fingerprinted.
var _l35_mesh_cache: Dictionary = {}
var _l35_progress_started_ms: int = 0
var _l35_progress_lines: int = 0
var _l35_progress_major_lines: int = 0
var _l35_full_footprints: int = 0
var _l35_search_rejections: int = 0

# Provisional source-only slab helper source, included verbatim in the owned World.
var _l48_faces: PackedVector3Array = PackedVector3Array()
var _l48_labels: Array[Dictionary] = []
var _l48_floor_labels: Array[Dictionary] = []
var _l48_cells: Array[Dictionary] = []
var _l48_rows: Array[float] = []
var _l48_report: Dictionary = {"schema":"mush-entrance48-slab-volume/1","passed":false}
var _l48_floor_bucket: Dictionary = {}


func _l35_progress(phase: String,important: bool=false) -> void:
	# At most64 search/caller lines and32 phase lines, including getter calls.
	# Timing/counters are stdout observations, never fingerprint/report inputs.
	if important:
		if _l35_progress_major_lines >= 32: return
		_l35_progress_major_lines += 1
	else:
		if _l35_progress_lines >= 64: return
		_l35_progress_lines += 1
	print("ENTRANCE46_PROGRESS01 "+JSON.stringify({"phase":phase,"elapsed_ms":Time.get_ticks_msec()-_l35_progress_started_ms,"entry_callers":_l35_entry_callers,"fairy_callers":_l35_fairy_callers,"total_guarded_callers":_l35_entry_callers+_l35_fairy_callers,"accepted_guarded_groups":_l35_entry_foliage.size(),"pose_candidates":_l35_pose_candidates,"full_footprints":_l35_full_footprints,"rejected_search_prefilters":_l35_search_rejections,"native_mesh_cache_entries":_l35_mesh_cache.size()}))

func _init() -> void:
	if _L35_PATH.begins_with("__ROOT_") or _L35_DATA.begins_with("__ROOT_") or _L35_DIR.begins_with("__ROOT_"):
		_l35_fail("UNASSEMBLED root source/descriptor/fresh-bake bindings");return
	if _L35_DIR != _L46_EXPECTED_BAKE_DIR:
		_l35_fail("Fresh46 owned bake directory must be the exclusive46 path");return
	_l35_progress_started_ms = Time.get_ticks_msec()
	_l35_progress("descriptor_begin",true)
	var file: FileAccess = FileAccess.open(_L35_DATA,FileAccess.READ)
	if file == null or file.get_length() > 16384:
		_l35_fail("Fresh bounded descriptor missing");return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		_l35_fail("Descriptor JSON invalid");return
	_l35_data = json.data as Dictionary
	if _l35_data.get("schema","") != "mush-entrance52-landform-data/1" or _l35_data.get("authoring_revision","") != _L35_REV or _l35_data.get("provisional") != true:
		_l35_fail("Descriptor schema/revision/provisional identity differs");return
	for key: String in ["rises","noses"]:
		if not _l35_data.get(key) is Array or (_l35_data[key] as Array).size() != 4:
			_l35_fail("Descriptor four-terrace profile missing");return
		var profile_limit: float = 0.55 if key == "noses" else 0.50
		for value: Variant in _l35_data[key]:
			if not _rooted_groups_numeric(value) or float(value) < 0.0 or float(value) > profile_limit: _l35_fail("Descriptor profile not bounded finite")
	var total: float = 0.0
	for value: Variant in _l35_data["rises"]: total += float(value)
	if absf(total-0.60) > 0.000000001 or float(_l35_data.get("threshold_height",-1)) != 0.60:
		_l35_fail("Current threshold and total rise must remain0.60")
	for key: String in ["upper_path_half_width","edge_wear_amplitude","joint_depth","joint_half_width","joint_fade_half_width","wear_end_fade_m","boundary_fade","soil_path_collar","soil_path_blend","walking_slope_limit_degrees","soil_rock_slope_limit_degrees","canonical_triangle_limit"]:
		if not _rooted_groups_numeric(_l35_data.get(key)) or float(_l35_data[key]) <= 0.0: _l35_fail("Descriptor scalar invalid: "+key)
	if not _l35_data.get("mounds") is Array or (_l35_data["mounds"] as Array).size() != 2:
		_l35_fail("Two asymmetric shoulder fields required");return
	for mound: Variant in _l35_data["mounds"]:
		if not mound is Dictionary: _l35_fail("Mound record missing");continue
		for key: String in ["x","z","radius_x","radius_z","height"]:
			if not _rooted_groups_numeric(mound.get(key)): _l35_fail("Mound finite scalar missing")
		if float(mound.get("height",-1)) < .60 or float(mound.get("height",1)) > .90 or float(mound.get("radius_x",0)) <= 1.0 or float(mound.get("radius_z",0)) <= 1.0: _l35_fail("Provisional shoulder heights/radii outside declared bounds")
	if not _rooted_groups_integer(_l35_data.get("extra_plant_attempts"),0,0): _l35_fail("This trial reuses existing foliage and adds zero new attempts")
	if float(_l35_data.get("joint_half_width",0)) != .025 or float(_l35_data.get("joint_fade_half_width",0)) != .10 or float(_l35_data.get("edge_wear_amplitude",0)) != .016 or float(_l35_data.get("joint_depth",0)) != .009 or float(_l35_data.get("wear_end_fade_m",0)) != .18:
		_l35_fail("Fresh46 wear/short-joint native recipe differs")
	if not _rooted_groups_numeric(_l35_data.get("stone_edge_crown_m")) or float(_l35_data.get("stone_edge_crown_m",0)) != .012:
		_l35_fail("Fresh46 physical perimeter crown proposal differs")
	if not _l35_shape_descriptor_exact(): _l35_fail("Solid48 explicit slab/floor authority recipe differs")
	var forks: Dictionary = _l35_data.get("selected_stone_material_forks",{}) as Dictionary
	if forks.get("schema","") != "mush-entrance35-selected-stone-forks/1" or forks.get("provisional") != true or forks.get("original_registry_unchanged") != true or forks.get("shader_unchanged") != true:
		_l35_fail("Fresh46 selected stone fork descriptor identity differs")
	for material_key: String in ["stone_light","stone"]:
		var proposed: Dictionary = forks.get(material_key,{}) as Dictionary
		var required: Dictionary = _l35_stone_spec(material_key)
		for uniform_key: String in required:
			if required[uniform_key] is Color:
				var color: Color = required[uniform_key]
				var components: Variant = proposed.get(uniform_key)
				if not components is Array or (components as Array).size() != 4: _l35_fail("Fresh46 proposed stone color shape differs");continue
				var finite_components: bool = true
				for component: Variant in components:
					finite_components = finite_components and _rooted_groups_numeric(component) and float(component) >= 0.0 and float(component) <= 1.0
				if not finite_components: _l35_fail("Fresh46 proposed stone color component invalid");continue
				if Color(float(components[0]),float(components[1]),float(components[2]),float(components[3])) != color: _l35_fail("Fresh46 proposed stone color differs")
			else:
				if not _rooted_groups_numeric(proposed.get(uniform_key)) or float(proposed[uniform_key]) != float(required[uniform_key]): _l35_fail("Fresh46 proposed stone scalar differs")
	var tint: Dictionary = _l35_data.get("ascent_block_tint",{}) as Dictionary
	if tint.get("provisional") != true or tint.get("gain_min") != .90 or tint.get("gain_max") != 1.06 or tint.get("alpha_unchanged") != true or tint.get("rng_calls") != 0 or tint.get("selected_ascent_stone_only") != true:
		_l35_fail("Fresh46 deterministic ascent tint policy differs")
	var entry_rgb: Dictionary = _l35_data.get("entry_vertex_rgb",{}) as Dictionary
	if entry_rgb.get("schema","") != "mush-entrance47-entry-vertex-rgb/1" or entry_rgb.get("provisional") != true or entry_rgb.get("ascent_only") != true or entry_rgb.get("original_materials_and_shaders_unchanged") != true or entry_rgb.get("alpha_unchanged") != true or entry_rgb.get("shared_block_gain_top_front") != true or entry_rgb.get("equal_final_top_front_RGB_claim") != false or not _rooted_groups_numeric(entry_rgb.get("nose_rgb_gain")) or float(entry_rgb.get("nose_rgb_gain",-1)) != .80:
		_l35_fail("Proposed47 entry-only vertex contrast policy differs")
	var moss_rgb: Variant = entry_rgb.get("joint_moss_rgb_multiplier")
	if not moss_rgb is Array or (moss_rgb as Array).size() != 3:
		_l35_fail("Proposed47 joint moss RGB shape differs")
	else:
		var required_moss: PackedFloat64Array = PackedFloat64Array([.72,.92,.62])
		for component: int in range(3):
			if not _rooted_groups_numeric(moss_rgb[component]) or float(moss_rgb[component]) != required_moss[component]: _l35_fail("Proposed47 joint moss RGB differs")
	var reach_policy: Dictionary = _l35_data.get("entry_projected_clearance_policy",{}) as Dictionary
	if reach_policy.get("schema","") != "mush-entrance35-projected-clearance-policy/1" or reach_policy.get("provisional") != true or reach_policy.get("preserve_larger_original_buffers") != true or not _rooted_groups_numeric(reach_policy.get("new_expansion_cap_m")) or float(reach_policy.get("new_expansion_cap_m",0)) <= 0.0 or float(reach_policy.get("new_expansion_cap_m",1)) > .50:
		_l35_fail("Fresh46 provisional projected clearance policy invalid")
	var fairy_policy: Dictionary = _l35_data.get("existing_fairy_pose_policy",{}) as Dictionary
	if fairy_policy.get("schema","") != "mush-entrance35-existing-fairy-pose-policy/1" or fairy_policy.get("provisional") != true or fairy_policy.get("resource_identity","") != "_glow_mesh" or fairy_policy.get("required_material_id","") != "fairy" or fairy_policy.get("clustered_only") != true or fairy_policy.get("original_constructor_reach_m") != .17 or fairy_policy.get("native_actual_fairy_count_required") != true:
		_l35_fail("Fresh46 exact existing fairy resource/caller policy invalid")

func _l35_fail(reason: String) -> void:
	if not _l35_errors.has(reason): _l35_errors.append(reason)

func _l35_sha(value: Variant) -> String:
	return _cap_preview_sha(var_to_bytes(value))

func _l35_shape_descriptor_exact() -> bool:
	var recipe: Dictionary = _l35_data.get("solid48_recipe",{}) as Dictionary
	if recipe.get("schema","")!="mush-entrance52-wornstone-recipe/1" or recipe.get("provisional")!=true or recipe.get("solid_faces_are_visible_and_colliding")!=true or recipe.get("floor_subset_only_for_support")!=true or recipe.get("hidden_ramp")!=false or recipe.get("roles_before_normal_measurement")!=true:return false
	if recipe.get("outer_bed_fan_split_policy","")!="existing-native-inherited-toe-at-or-after-midpoint-v1":return false
	var arrays: Dictionary = {"end_stations_z":PackedFloat64Array([8.85,7.82,6.84,4.06]),"top_levels_m":PackedFloat64Array([.13,.29,.43,.60]),"retained_station_z":PackedFloat64Array([4.7,5.5,5.93,6.5,7.5,8.5,9.5,11]),"tread_slab_counts":PackedFloat64Array([4,3,8,3])}
	for key: String in arrays:
		var actual: Variant = recipe.get(key);var required: PackedFloat64Array = arrays[key]
		if not actual is Array or (actual as Array).size()!=required.size():return false
		for i: int in range(required.size()):
			if not _rooted_groups_numeric(actual[i]) or float(actual[i])!=required[i]:return false
	for key: String in ["bottom_bury_m","replacement_triangle_target","additional_physical_triangle_limit"]:
		var required: Dictionary = {"bottom_bury_m":.020,"replacement_triangle_target":1050,"additional_physical_triangle_limit":4000}
		if not _rooted_groups_numeric(recipe.get(key)) or float(recipe[key])!=float(required[key]):return false
	if not recipe.get("points_qz") is Array or not recipe.get("slabs") is Array or not recipe.get("bed_regions") is Array or not recipe.get("transition_edges") is Array:return false
	var pool: Array = recipe["points_qz"] as Array
	if pool.size()<18 or pool.size()>512:return false
	for raw: Variant in pool:
		if not raw is Array or (raw as Array).size()!=2:return false
		if not _rooted_groups_numeric(raw[0]) or not _rooted_groups_numeric(raw[1]) or float(raw[0])<0.0 or float(raw[0])>1.0 or float(raw[1])<3.0 or float(raw[1])>11.0:return false
	var slabs: Array = recipe["slabs"] as Array;var counts: PackedInt32Array = PackedInt32Array([0,0,0,0])
	if slabs.size()!=18:return false
	for raw: Variant in slabs:
		if not raw is Dictionary:return false
		var slab: Dictionary = raw as Dictionary
		if not _rooted_groups_integer(slab.get("tread"),0,3):return false
		counts[int(slab["tread"])]+=1
		if not slab.get("polygon_indices") is Array or (slab["polygon_indices"] as Array).size()<6 or (slab["polygon_indices"] as Array).size()>8:return false
		for index: Variant in slab["polygon_indices"]:
			if not _rooted_groups_integer(index,0,pool.size()-1):return false
		if not _rooted_groups_numeric(slab.get("bevel_inset_m")) or float(slab["bevel_inset_m"])<.035 or float(slab["bevel_inset_m"])>.065:return false
		if not _rooted_groups_numeric(slab.get("bevel_drop_m")) or float(slab["bevel_drop_m"])<.006 or float(slab["bevel_drop_m"])>.008:return false
		if not slab.get("wear_plane") is Array or (slab["wear_plane"] as Array).size()!=4:return false
		for v: Variant in slab["wear_plane"]:
			if not _rooted_groups_numeric(v):return false
		var plane: Array = slab["wear_plane"] as Array
		if absf(float(plane[0]))>.004 or absf(float(plane[1]))>.004 or absf(float(plane[3]))>.008 or float(plane[2])<3.0 or float(plane[2])>8.85:return false
		if int(slab["tread"])==3 and (float(plane[0])!=0.0 or float(plane[1])!=0.0 or float(plane[3])!=0.0):return false
	if counts!=PackedInt32Array([4,3,8,3]):return false
	var regions: Array = recipe["bed_regions"] as Array;var triangle_count: int = 0
	if regions.is_empty() or regions.size()>16:return false
	for raw: Variant in regions:
		if not raw is Dictionary:return false
		var row: Dictionary = raw as Dictionary
		if not _rooted_groups_integer(row.get("role"),0,4) or (int(row["role"])!=0 and int(row["role"])!=4) or not _rooted_groups_integer(row.get("tread"),-1,3):return false
		if not _rooted_groups_numeric(row.get("level")) or float(row["level"])!=(.009 if int(row["tread"])==-1 else float(arrays["top_levels_m"][int(row["tread"])])):return false
		if not row.get("triangles") is Array or (row["triangles"] as Array).is_empty() or (row["triangles"] as Array).size()%3!=0:return false
		triangle_count+=(row["triangles"] as Array).size()/3
		for index: Variant in row["triangles"]:
			if not _rooted_groups_integer(index,0,pool.size()-1):return false
	if triangle_count>512:return false
	var transitions: Array = recipe["transition_edges"] as Array
	if transitions.is_empty() or transitions.size()>64:return false
	for raw: Variant in transitions:
		if not raw is Array or (raw as Array).size()!=5:return false
		for i: int in range(2):
			if not _rooted_groups_integer(raw[i],0,pool.size()-1):return false
		if not _rooted_groups_integer(raw[4],0,3) or not _rooted_groups_numeric(raw[2]) or not _rooted_groups_numeric(raw[3]):return false
		var tread: int = int(raw[4])
		if float(raw[2])!=(0.0 if tread==0 else float(arrays["top_levels_m"][tread-1])) or float(raw[3])!=float(arrays["top_levels_m"][tread]):return false
	return true

func _l35_active_fronts09_exact(values: Variant) -> bool:
	if not values is Array or (values as Array).size() != 4: return false
	for i: int in range(4):
		if not _rooted_groups_integer(values[i],i,i): return false
	return true

func _ready() -> void:
	if not _l35_errors.is_empty():
		_l35_ready = false
		return # Unassembled/invalid descriptor never constructs the inherited scene.
	_l35_progress("ready_begin",true)
	super._ready()
	_l35_progress("parent_ready_returned",true)
	if _r25_status != "complete" or _r27_status != "complete" or not _r25_errors.is_empty() or not _r27_errors.is_empty(): _l35_fail("Inherited assembly or fresh35 replay refused")
	if not _l35_tread_semantics.get("passed",false) or not _l35_quality.get("passed",false) or not _l35_collision.get("passed",false) or not _l35_roundtrip.get("passed",false) or not _l35_batch_report.get("passed",false): _l35_fail("Native landform quality/collision/codec/batch evidence incomplete")
	_l35_ready = _l35_errors.is_empty()
	_l35_progress("ready_end",true)

func _r25_nose(_i: int) -> float:
	# Legacy R25 requests eight sampling offsets, not eight physical rises.
	# Zero reuses its original end rows; fresh four-profile hinges are inserted below.
	return 0.0

func _l46_nose(i: int) -> float:
	return float((_l35_data.get("noses",[.40,.49,.43,.52]) as Array)[i]) if i >= 0 and i < 4 else 0.0

func _r25_grade(z: float) -> float:
	var height: float = 0.0
	var rises: Array = _l35_data.get("rises",[.13,.16,.14,.17])
	for i: int in range(4):
		var end_z: float = _l35_tread_end(i)
		height += float(rises[i])*clampf((end_z+_l46_nose(i)-z)/_l46_nose(i),0.0,1.0)
	return height

func _r25_width(z: float) -> float:
	return lerpf(float(_l35_data.get("upper_path_half_width",1.10)),super._r25_width(z),smoothstep(5.8,8.0,z)) if z > 3.12 else 1.08

func _l35_walk_reference_height(p: Vector3) -> float:
	var grade: float = _r25_grade(p.z)
	var left: float = float(Vector3(_r25_center(p.z)-_r25_width(p.z),0,0).x)
	var right: float = float(Vector3(_r25_center(p.z)+_r25_width(p.z),0,0).x)
	if p.x == left or p.x == right: return grade
	var tread: int = _l35_flat_tread(p.z)
	if tread < 0 or tread == 3: return grade
	var q: float = (p.x-_r25_center(p.z))/_r25_width(p.z)
	var edge: float = maxf(0.0,1.0-pow(absf(q),6.0))
	var upper: float = _l35_tread_end(tread+1)+_l46_nose(tread+1)
	var lower: float = _l35_tread_end(tread)
	var end_fade: float = float(_l35_data.get("wear_end_fade_m",.18))
	var ends: float = smoothstep(0.0,end_fade,p.z-upper)*smoothstep(0.0,end_fade,lower-p.z)
	var wear: float = float(_l35_data.get("edge_wear_amplitude",.016))*(.30+.70*pow(sin(p.x*3.7+p.z*2.1),2.0))
	var joint: float = _l35_joint_weight(p,tread)
	var perimeter: Vector2 = _l35_stone_perimeter(tread,p.z)
	var fraction: float = .5*(q+1.0)
	var edge_distance: float = minf(fraction-float(perimeter.x),float(perimeter.y)-fraction)*(right-left)
	var bevel: float = smoothstep(0.0,.10,maxf(0.0,edge_distance))
	var side: float = smoothstep(.36,.64,absf(q))
	var crown: float = float(_l35_data.get("stone_edge_crown_m",.012))*ends*side*bevel*(1.0-joint)
	return grade-edge*ends*(wear+float(_l35_data.get("joint_depth",.009))*joint)+crown

# The fresh four-terrace intrinsic path domain is triangulated once. Its selected native corners
# are the shared render/collider/support surface; no floating decorative stones.
# Four-terrace roles and height changes are authored independently of measured slopes.
# Four unequal rises with blunt compressed outboard fronts; central bevels remain visible.
func _l35_front_weight(q: float) -> float:
	return _l35_piecewise(q,PackedFloat64Array([0,.06,.18,.25,.50,.75,.82,.94,1]),PackedFloat64Array([0,1,1,0,0,0,.82,.82,0]))

func _l35_path_height(p: Vector3) -> float:
	var original: float = _l35_walk_reference_height(p)
	var left: float = float(Vector3(_r25_center(p.z)-_r25_width(p.z),0,0).x)
	var right: float = float(Vector3(_r25_center(p.z)+_r25_width(p.z),0,0).x)
	if p.x == left or p.x == right: return original
	var q: float = (p.x-left)/(right-left)
	var nose: int = _l35_nose_tread(p.z)
	if nose < 0: return original
	var rise: Array = _l35_data["rises"] as Array
	var lower: float = 0.0
	for i: int in range(nose): lower += float(rise[i])
	var upper: float = lower+float(rise[nose])
	var start: float = float(Vector3(0,0,PackedFloat64Array([9.00,7.98,7.01,4.28])[nose]).z)
	var run: float = PackedFloat64Array([.13,.15,.13,.16])[nose]
	var end: float = float(Vector3(0,0,start+run).z)
	# Actual outboard front has a blunt25mm upper/lower bevel, not a vertical face.
	var target: float = _l35_piecewise(p.z,PackedFloat64Array([start,start+.025,end-.025,end]),PackedFloat64Array([upper,upper-.015,lower+.015,lower]))
	if p.z <= start: target = upper
	if p.z >= end: target = lower
	return lerpf(original,target,_l35_front_weight(q))

func _l35_piecewise(q: float,xs: PackedFloat64Array,ys: PackedFloat64Array) -> float:
	for i: int in range(xs.size()-1):
		if q <= xs[i+1]: return lerpf(ys[i],ys[i+1],clampf((q-xs[i])/(xs[i+1]-xs[i]),0.0,1.0))
	return ys[ys.size()-1]

func _l35_front_offset(tread: int,fraction: float) -> float:
	if tread < 0 or tread >= 4 or fraction <= 0.0 or fraction >= 1.0: return 0.0
	return PackedFloat64Array([.060,-.055,.050,-.045])[tread]*_l35_front_weight(fraction)

func _l35_front_warp(z: float,fraction: float) -> float:
	# Native contact rows stay explicit zero anchors; fronts bend only between them.
	var xs: PackedFloat64Array = PackedFloat64Array([3.0,3.81,4.06,4.58,4.7,5.5,5.93,6.5,6.84,7.27,7.5,7.82,8.31,8.5,8.85,9.25,9.5,11.0])
	var ys: PackedFloat64Array = PackedFloat64Array([0,0,-.045,-.045,0,0,0,0,.050,.050,0,-.055,-.055,0,.060,.060,0,0])
	for i: int in range(xs.size()-1):
		if z <= xs[i+1]: return lerpf(ys[i],ys[i+1],smoothstep(xs[i],xs[i+1],z))*_l35_front_weight(fraction)
	return 0.0

func _l35_flat_progress(tread: int,z: float) -> float:
	var lo: float = 3.0 if tread == 3 else float(Vector3(0,0,_l35_tread_end(tread+1)+_l46_nose(tread+1)).z)
	return clampf((z-lo)/(_l35_tread_end(tread)-lo),0.0,1.0)

func _l35_curved_dividers(tread: int,z: float) -> PackedFloat64Array:
	var result: PackedFloat64Array = _l35_joint_fractions(tread)
	if tread == 3: return result
	var t: float = _l35_flat_progress(tread,z)
	var kink: float = 1.0-absf(2.0*t-1.0)
	for i: int in range(result.size()):
		var sign_value: float = -1.0 if (tread+i)%2 == 0 else 1.0
		result[i] += sign_value*.025*kink
	return result

func _l35_stone_perimeter(tread: int,z: float) -> Vector2:
	if tread < 0 or tread == 3: return Vector2(0,1)
	var lefts: PackedFloat64Array = PackedFloat64Array([.045,.070,.055,0])
	var rights: PackedFloat64Array = PackedFloat64Array([.940,.915,.935,1])
	var t: float = _l35_flat_progress(tread,z)
	var kink: float = 1.0-absf(2.0*t-1.0)
	return Vector2(lefts[tread]+.018*kink,rights[tread]-.022*kink)

func _l35_shape_tread(z: float) -> int:
	var nose: int = _l35_nose_tread(z)
	return nose if nose >= 0 else _l35_flat_tread(z)

func _l35_parameter_row(selected: PackedVector3Array) -> Dictionary:
	var key: String = _cap_preview_sha(selected.to_byte_array())
	var stored: Dictionary = _l35_shape_rows.get(key,{}) as Dictionary
	if stored.is_empty() or (stored.get("selected",PackedVector3Array()) as PackedVector3Array).to_byte_array() != selected.to_byte_array():
		_l35_fail("Fresh46 selected row missing exact intrinsic correspondence")
		return {}
	return stored

func _l35_emit_shaped(a: Vector3,b: Vector3,c: Vector3,pa: Vector3,pb: Vector3,pc: Vector3,path: Dictionary,qa: float,qb: float,qc: float) -> void:
	var fractions: PackedFloat64Array = PackedFloat64Array([qa,qb,qc])
	var intrinsic: PackedVector3Array = PackedVector3Array([pa,pb,pc])
	# Classify the authored native cell before computing its selected normal.
	var role: int = _l35_face_role09(fractions,intrinsic)
	var middle: Vector3 = (pa+pb+pc)/3.0
	var label: Dictionary = _l35_path_category(middle)
	label["parameter_middle"] = middle
	label["role_code"] = role
	label["role_fraction_parameters"] = fractions
	if role == 3:
		label["material"] = "soil";label["joint"] = true
	var before: int = (path["v"] as PackedVector3Array).size()
	_r25_emit(a,b,c,path,Color(.96,.96,.93),true)
	if (path["v"] as PackedVector3Array).size() != before+3:
		_l35_fail("Fresh46 canonical shape face rejected at native emission");return
	_l35_path_selected_faces.append_array(PackedVector3Array([a,b,c]))
	_l35_path_parameter_faces.append_array(intrinsic)
	_l35_path_q_parameters.append_array(fractions)
	_l35_path_role_codes.append(role)
	_l35_path_labels.append(label)
	if role < 2:
		_l35_walking_faces.append_array(PackedVector3Array([a,b,c]));_l35_walking_intrinsic.append_array(intrinsic)
	else:
		_l35_nonwalking_faces.append_array(PackedVector3Array([a,b,c]));_l35_nonwalking_intrinsic.append_array(intrinsic)

func _l35_tread_end(i: int) -> float:
	return float(Vector3(0,0,PackedFloat64Array([8.85,7.82,6.84,4.06])[i]).z)

func _l35_flat_tread(z: float) -> int:
	for i: int in range(4):
		var lo: float = 3.0 if i == 3 else float(Vector3(0,0,_l35_tread_end(i+1)+_l46_nose(i+1)).z)
		if z >= lo and z <= _l35_tread_end(i): return i
	return -1

func _l35_nose_tread(z: float) -> int:
	for i: int in range(4):
		var lo: float = _l35_tread_end(i)
		var hi: float = float(Vector3(0,0,lo+_l46_nose(i)).z)
		if z >= lo and z <= hi: return i
	return -1

func _l35_joint_fractions(tread: int) -> PackedFloat64Array:
	# Three-to-five unequal stone blocks per terrace; joints terminate at that terrace.
	var choices: Array = [[.21,.43,.67,.84],[.28,.53,.78],[.25,.55,.80],[.32,.66]]
	return PackedFloat64Array(choices[tread])

func _l35_transverse_bounds(tread: int) -> Vector2:
	var center: float = _l35_tread_end(tread)-.070
	var half_width: float = float(_l35_data.get("joint_half_width",.025))
	return Vector2(float(Vector3(0,0,center-half_width).z),float(Vector3(0,0,center+half_width).z))

func _l35_joint_weight(p: Vector3,tread: int) -> float:
	var span: float = 2.0*_r25_width(p.z)
	var left: float = _r25_center(p.z)-_r25_width(p.z)
	var half_width: float = float(_l35_data.get("joint_half_width",.025))
	var fade_width: float = float(_l35_data.get("joint_fade_half_width",.10))
	var weight: float = 0.0
	for fraction: float in _l35_curved_dividers(tread,p.z):
		weight = maxf(weight,1.0-smoothstep(half_width,fade_width,absf(p.x-(left+fraction*span))))
	if tread < 3:
		var perimeter: Vector2 = _l35_stone_perimeter(tread,p.z)
		var fraction: float = (p.x-left)/span
		var distance: float = minf(absf(fraction-float(perimeter.x)),absf(fraction-float(perimeter.y)))*span
		weight = maxf(weight,1.0-smoothstep(half_width,fade_width,distance))
	return weight

func _l35_path_knots(z: float) -> Array[float]:
	var tread: int = _l35_shape_tread(z)
	var perimeter: Vector2 = _l35_stone_perimeter(tread,z)
	var knots: Array[float] = [0.0,.06,.18,.25,.50,.75,.82,.94,1.0]
	var shape_controls: Array[float] = knots.duplicate()
	if tread >= 0 and tread < 3:
		knots.append(float(perimeter.x));knots.append(float(perimeter.y))
	var flat: int = _l35_flat_tread(z)
	if flat >= 0:
		var span: float = 2.0*_r25_width(z)
		var half_width: float = float(_l35_data.get("joint_half_width",.025))
		for fraction: float in _l35_curved_dividers(flat,z):
			for offset: float in PackedFloat64Array([-half_width,half_width]):
				var q: float = fraction+offset/span
				if q > 0.0 and q < 1.0 and not knots.has(q): knots.append(q)
	knots.sort()
	# Distinct scalar q values can denote the same complete emitted FP32 point.
	# Canonicalize the sample list before joining; keep literal shape controls.
	var left: float = float(Vector3(_r25_center(z)-_r25_width(z),0,0).x)
	var right: float = float(Vector3(_r25_center(z)+_r25_width(z),0,0).x)
	var native_points: PackedVector3Array = PackedVector3Array()
	var native_knots: Array[float] = []
	for q: float in knots:
		var x: float = left if q == 0.0 else (right if q == 1.0 else float(Vector3(left+(right-left)*q,0,0).x))
		var point: Vector3 = Vector3(x,0,z)
		point.y = _l35_path_height(point)
		point.z = z+_l35_front_warp(z,q)
		var existing: int = native_points.find(point)
		if existing >= 0:
			if shape_controls.has(q): native_knots[existing] = q
			continue
		native_points.append(point);native_knots.append(q)
	return native_knots

func _l35_path_category(p: Vector3) -> Dictionary:
	var nose: int = _l35_nose_tread(p.z)
	var tread: int = nose if nose >= 0 else _l35_flat_tread(p.z)
	if tread < 0: return {"material":"soil","nose":-1,"top":-1,"joint":false}
	var left: float = _r25_center(p.z)-_r25_width(p.z)
	var span: float = 2.0*_r25_width(p.z)
	var fraction: float = (p.x-left)/span
	var perimeter: Vector2 = _l35_stone_perimeter(tread,p.z)
	var joint: bool = tread < 3 and (fraction < perimeter.x or fraction > perimeter.y)
	if nose < 0:
		var half_width: float = float(_l35_data.get("joint_half_width",.025))
		for divider: float in _l35_curved_dividers(tread,p.z):
			if absf(p.x-(left+divider*span)) < half_width: joint = true
	# These triangle labels are sampled in the retained intrinsic domain, then
	# bound to the selected face at emission. Actual native triangle edges are
	# the authoritative polygonal outline, not an unsampled analytic curve.
	return {"material":"soil" if joint else ("stone" if nose >= 0 else "stone_light"),"nose":nose,"top":tread if nose < 0 else -1,"joint":joint}

func _l35_mound(p: Vector3) -> float:
	var height: float = 0.0
	for mound: Dictionary in _l35_data.get("mounds",[]):
		var q: float = pow((p.x-float(mound["x"]))/float(mound["radius_x"]),2.0)+pow((p.z-float(mound["z"]))/float(mound["radius_z"]),2.0)
		var mass: float = float(mound["height"])*pow(maxf(0.0,1.0-q),1.35)
		height = maxf(height,mass)
	return height

func _r25_soil_height(p: Vector3) -> float:
	var base: float = float(_r25_base(p).get("height",0.0))
	var boundary: float = minf(minf(p.x-_r25_rect.position.x,_r25_rect.end.x-p.x),minf(p.z-3.0,11.0-p.z))
	if boundary <= 0.0:
		if p.z == 3.0 and absf(p.x-_r25_center(p.z)) <= _r25_width(p.z)+.000001: return _r25_grade(p.z)
		return base
	if p.x < -3.6 and p.z < 4.8: return base
	var pot_mask: float = 1.0
	for side: float in PackedFloat64Array([-1,1]):
		for i: int in range(3):
			var pot: Vector2 = Vector2(side*(1.25+.38*i),3.55+.26*(i%2))
			pot_mask = minf(pot_mask,smoothstep(.42,.85,Vector2(p.x,p.z).distance_to(pot)))
	var branch: float = smoothstep(1.05,1.80,_r22_segment_distance(Vector2(p.x,p.z),Vector2(-1,11),Vector2(4,9)))
	var mass: float = _l35_mound(p)*smoothstep(0.0,float(_l35_data.get("boundary_fade",.70)),boundary)*pot_mask*branch
	var outside: float = absf(p.x-_r25_center(p.z))-_r25_width(p.z)
	if absf(outside) <= .000001: return _r25_grade(p.z)
	if pot_mask <= .000001: return base
	var collar: float = float(_l35_data.get("soil_path_collar",.30))
	var blend: float = float(_l35_data.get("soil_path_blend",.95))
	var tie: float = (1.0-smoothstep(collar,blend,maxf(0.0,outside)))*smoothstep(3.0,3.20,p.z)
	# Exact shared endpoint. Upper pots retain their fixed protected soil pockets.
	if absf(outside) <= .000001: return _r25_grade(p.z)
	return lerpf(base+mass,_r25_grade(p.z),tie*pot_mask)

func _l35_soil_row(xs: Array[float],z: float,band: int) -> PackedVector3Array:
	var left: float = float(Vector3(_r25_center(z)-_r25_width(z),0,0).x)
	var right: float = float(Vector3(_r25_center(z)+_r25_width(z),0,0).x)
	var lo: float = _r25_rect.position.x if band == 0 else right
	var hi: float = left if band == 0 else _r25_rect.end.x
	var required: Dictionary = {}
	required[lo] = true;required[hi] = true
	var columns: Array[float] = [lo,hi]
	for offset: float in PackedFloat64Array([.12,.30,.60,.95]):
		var x: float = float(Vector3(hi-offset if band == 0 else lo+offset,0,0).x)
		if x > lo and x < hi: required[x] = true;columns.append(x)
	if z <= 4.5:
		for pot_x: float in PackedFloat64Array([-2.01,-1.63,-1.25,1.25,1.63,2.01]):
			var native: float = float(Vector3(pot_x,0,0).x)
			if native > lo and native < hi: required[native] = true;columns.append(native)
	for x: float in xs:
		if x <= lo or x >= hi: continue
		var edge_distance: float = hi-x if band == 0 else x-lo
		if edge_distance < .12: continue
		var close: bool = false
		for anchor: float in required:
			if absf(x-anchor) < .04: close = true;break
		if not close: columns.append(x)
	columns.sort()
	var row: PackedVector3Array = PackedVector3Array()
	var previous: float = -INF
	for x: float in columns:
		if x == previous or (not required.has(x) and x-previous < .04): continue
		var point: Vector3 = Vector3(x,0,z)
		point.y = _r25_soil_height(point)
		row.append(point);previous = x
	return row

func _r25_row(xs: Array[float],z: float,band: int) -> PackedVector3Array:
	if _l35_grid_xs.is_empty():_l35_grid_xs=xs.duplicate()
	if band!=1:return _l35_soil_row(xs,z,band)
	# Legacy row construction supplies endpoints only; no old strip is emitted.
	var a: Vector2 = _l48_point(0,z);var b: Vector2 = _l48_point(1,z)
	return PackedVector3Array([Vector3(a.x,_r25_grade(z),z),Vector3(b.x,_r25_grade(z),z)])

func _r25_join_rows(a: PackedVector3Array,b: PackedVector3Array,band: int,soil: Dictionary,path: Dictionary) -> void:
	if band==1:return # Explicit slabs/floor domain are built once by _r25_prove_baseline_path.
	var splits: Array[float] = _l35_split_rows46()
	var previous: PackedVector3Array = a
	var last_z: float = a[0].z
	for z: float in splits:
		if z > last_z and z < b[0].z:
			var row: PackedVector3Array = _r25_row(_l35_grid_xs,z,band)
			_l35_join_native_rows(previous,row,band,soil,path)
			previous = row;last_z = z
	_l35_join_native_rows(previous,b,band,soil,path)

func _l35_split_rows46() -> Array[float]:
	# Profile/face-role hinges and every retained actual lateral station are native rows.
	var values: Array[float] = [3.55,3.81,4.7,5.5,5.93,6.5,7.5,8.5,9.5,11.0]
	for tread: int in range(4):
		var start: float = PackedFloat64Array([9.00,7.98,7.01,4.28])[tread]
		var run: float = PackedFloat64Array([.13,.15,.13,.16])[tread]
		values.append(_l35_tread_end(tread));values.append(_l35_tread_end(tread)+_l46_nose(tread))
		for z: float in PackedFloat64Array([start,start+.025,start+run-.025,start+run]): values.append(z)

	values.sort()
	var result: Array[float] = []
	for z: float in values:
		var native: float = float(Vector3(0,0,z).z)
		if not result.has(native): result.append(native)
	return result

func _l35_join_native_rows(a: PackedVector3Array,b: PackedVector3Array,band: int,soil: Dictionary,path: Dictionary) -> void:
	if band != 1:
		super._r25_join_rows(a,b,band,soil,path)
		return
	var ra: Dictionary = _l35_parameter_row(a)
	var rb: Dictionary = _l35_parameter_row(b)
	if ra.is_empty() or rb.is_empty(): return
	var qa: Array[float] = ra["knots"]
	var qb: Array[float] = rb["knots"]
	var pa: PackedVector3Array = ra["parameters"]
	var pb: PackedVector3Array = rb["parameters"]
	if qa.size() != a.size() or qb.size() != b.size() or pa.size() != a.size() or pb.size() != b.size():
		_l35_fail("Fresh46 native path knot/parameter cardinality differs");return
	var i: int = 0
	var j: int = 0
	while i < a.size()-1 or j < b.size()-1:
		if j == b.size()-1 or (i < a.size()-1 and qa[i+1] <= qb[j+1]):
			_l35_emit_shaped(a[i],a[i+1],b[j],pa[i],pa[i+1],pb[j],path,qa[i],qa[i+1],qb[j]);i += 1
		else:
			_l35_emit_shaped(a[i],b[j+1],b[j],pa[i],pb[j+1],pb[j],path,qa[i],qb[j+1],qb[j]);j += 1

func _r25_prove_baseline_path(_xs: Array[float],zs: Array[float]) -> void:
	_l48_build(zs)
	_l35_joins.clear();_l35_contact_indices.clear();_r25_join_proof.clear()
	var exact: bool = not _r25_path_faces.is_empty()
	for station: float in PackedFloat64Array([4.7,5.5,5.93,6.5,7.5,8.5,9.5,11]):
		var z: float = float(Vector3(0,0,station).z)
		var a: Vector2 = _l48_point(0,z);var b: Vector2 = _l48_point(1,z)
		var left: Vector3 = Vector3(a.x,_r25_grade(z),z);var right: Vector3 = Vector3(b.x,_r25_grade(z),z)
		var soil_left: Vector3 = Vector3(a.x,_r25_soil_height(left),z);var soil_right: Vector3 = Vector3(b.x,_r25_soil_height(right),z)
		exact=exact and left==soil_left and right==soil_right
		_l35_contact_indices.append(_l35_joins.size())
		_l35_joins.append({"z":z,"left_path":left,"left_soil":soil_left,"right_path":right,"right_soil":soil_right,"left_gap_m":soil_left.y-left.y,"right_gap_m":soil_right.y-right.y})
		_r25_join_proof.append({"z":z,"full_join":left==soil_left and right==soil_right,"exact_edge_y":left.y==soil_left.y and right.y==soil_right.y,"native_edge_y_gap_m":soil_left.y-left.y,"right_native_edge_y_gap_m":soil_right.y-right.y,"source":"Solid48 preserved eight native lateral edge stations"})
	_r25_baseline_path_faces=PackedVector3Array()
	_r25_path_proof={"schema":"mush-entrance48-native-floor-edges/1","passed":exact,"triangle_count":_r25_path_faces.size()/3,"actual_sha256":_cap_preview_sha(_r25_path_faces.to_byte_array()),"old591_equality_claim":false,"both_lateral_edges_native_exact":exact,"station_count":8,"scope":"Eight retained station edge vectors; explicit floors and closed slab walls replace the old single-height path. Actual scalar/capsule crossings must be tested."}
	if not exact:_r25_errors.append("Solid48 retained lateral edge discontinuity")

func _l35_face_role09(fractions: PackedFloat64Array,intrinsic: PackedVector3Array) -> int:
	if fractions.size() != 3 or intrinsic.size() != 3: return -1
	var lo: float = minf(fractions[0],minf(fractions[1],fractions[2]))
	var hi: float = maxf(fractions[0],maxf(fractions[1],fractions[2]))
	var outside_core: bool = hi <= .25 or lo >= .75
	var middle: Vector3 = (intrinsic[0]+intrinsic[1]+intrinsic[2])/3.0
	var nose: int = _l35_nose_tread(middle.z)
	if outside_core and nose >= 0: return 2
	var category: Dictionary = _l35_path_category(middle)
	if outside_core and bool(category.get("joint",false)):
		# Whole intrinsic flat-joint cells touching a retained native crossing row are walk zones.
		# This declaration precedes normal measurement; all actual fronts keep role2 above.
		var zlo: float = minf(intrinsic[0].z,minf(intrinsic[1].z,intrinsic[2].z))
		var zhi: float = maxf(intrinsic[0].z,maxf(intrinsic[1].z,intrinsic[2].z))
		for station: float in PackedFloat64Array([4.7,5.5,5.93,6.5,7.5,8.5,9.5,11]):
			var native_station: float = float(Vector3(0,0,station).z)
			if zlo<=native_station and native_station<=zhi: return 0
		return 3
	return 1 if nose >= 0 else 0

func _l35_role_binding09_exact() -> bool:
	# Compatibility method name; the old q-heightfield role contract is retired.
	return _l48_binding_exact()

func _l35_face_witness09(face: int) -> Dictionary:
	if face < 0 or face >= _l35_path_role_codes.size(): return {}
	var i: int = face*3
	var selected: PackedVector3Array = PackedVector3Array([_r25_path_faces[i],_r25_path_faces[i+1],_r25_path_faces[i+2]])
	var intrinsic: PackedVector3Array = PackedVector3Array([_l35_path_parameter_faces[i],_l35_path_parameter_faces[i+1],_l35_path_parameter_faces[i+2]])
	var qs: PackedFloat64Array = PackedFloat64Array([_l35_path_q_parameters[i],_l35_path_q_parameters[i+1],_l35_path_q_parameters[i+2]])
	return {"path_face_ordinal":face,"path_corner_index":i,"role_code":_l35_path_role_codes[face],"selected_face":selected,"intrinsic_face":intrinsic,"fraction_parameters":qs,"selected_native_sha256":_l35_sha(selected),"intrinsic_native_sha256":_l35_sha(intrinsic),"selected_face_varhex":var_to_bytes(selected).hex_encode(),"intrinsic_face_varhex":var_to_bytes(intrinsic).hex_encode(),"fraction_parameters_varhex":var_to_bytes(qs).hex_encode(),"source_role_recomputed_exact":_l35_face_role09(qs,intrinsic) == _l35_path_role_codes[face]}

func _l35_measure_roles09() -> Dictionary:
	var names: Array[String] = ["walking_top","walking_crossing","nonwalking_stone_front","nonwalking_chip_or_joint"]
	var rows: Array[Dictionary] = []
	var fronts: Array[Dictionary] = []
	for code: int in range(4): rows.append({"code":code,"name":names[code],"count":0,"projected_area_m2":0.0,"surface_area_m2":0.0,"max_slope_degrees":0.0,"minimum_y":INF,"maximum_y":-INF,"max_individual_face_Y_span_m":0.0,"max_slope_face_ordinal":-1,"max_Y_span_face_ordinal":-1})
	for tread: int in range(4): fronts.append({"tread":tread,"authored_steep_front":true,"count":0,"projected_area_m2":0.0,"surface_area_m2":0.0,"minimum_y":INF,"maximum_y":-INF,"max_slope_degrees":0.0,"max_slope_face_ordinal":-1,"minimum_slope_degrees":INF,"minimum_z":INF,"maximum_z":-INF,"min_x":INF,"max_x":-INF})
	var binding: bool = _l35_role_binding09_exact()
	for face: int in range(_l35_path_role_codes.size()):
		var i: int = face*3
		var a: Vector3 = _r25_path_faces[i];var b: Vector3 = _r25_path_faces[i+1];var c: Vector3 = _r25_path_faces[i+2]
		var cross: Vector3 = (c-a).cross(b-a)
		var normal: Vector3 = cross.normalized()
		var slope: float = rad_to_deg(acos(clampf(normal.y,-1.0,1.0)))
		var projected: float = absf(Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z)))*.5
		var low: float = minf(a.y,minf(b.y,c.y));var high: float = maxf(a.y,maxf(b.y,c.y))
		var code: int = _l35_path_role_codes[face]
		if code < 0 or code > 3: binding = false;continue
		var row: Dictionary = rows[code]
		row["count"] = int(row["count"])+1;row["projected_area_m2"] = float(row["projected_area_m2"])+projected;row["surface_area_m2"] = float(row["surface_area_m2"])+cross.length()*.5
		row["minimum_y"] = minf(float(row["minimum_y"]),low);row["maximum_y"] = maxf(float(row["maximum_y"]),high)
		if slope > float(row["max_slope_degrees"]): row["max_slope_degrees"] = slope;row["max_slope_face_ordinal"] = face
		if high-low > float(row["max_individual_face_Y_span_m"]): row["max_individual_face_Y_span_m"] = high-low;row["max_Y_span_face_ordinal"] = face
		if code == 2:
			var tread: int = int(_l35_path_labels[face]["nose"])
			if tread < 0 or tread > 3: binding = false;continue
			var front: Dictionary = fronts[tread]
			front["count"] = int(front["count"])+1;front["projected_area_m2"] = float(front["projected_area_m2"])+projected;front["surface_area_m2"] = float(front["surface_area_m2"])+cross.length()*.5
			front["minimum_y"] = minf(float(front["minimum_y"]),low);front["maximum_y"] = maxf(float(front["maximum_y"]),high)
			if slope > float(front["max_slope_degrees"]): front["max_slope_degrees"] = slope;front["max_slope_face_ordinal"] = face
			front["minimum_slope_degrees"] = minf(float(front["minimum_slope_degrees"]),slope)
			front["minimum_z"] = minf(float(front["minimum_z"]),minf(a.z,minf(b.z,c.z)));front["maximum_z"] = maxf(float(front["maximum_z"]),maxf(a.z,maxf(b.z,c.z)))
			front["min_x"] = minf(float(front["min_x"]),minf(a.x,minf(b.x,c.x)));front["max_x"] = maxf(float(front["max_x"]),maxf(a.x,maxf(b.x,c.x)))
	var meaningful: bool = float(rows[2]["projected_area_m2"]) >= .50 and float(rows[2]["surface_area_m2"]) >= .60 and float(rows[2]["max_slope_degrees"]) > 35.0 and int(rows[3]["count"]) > 0
	for row: Dictionary in rows:
		if int(row["count"]) <= 0: binding = false;row["minimum_y"] = 0.0;row["maximum_y"] = 0.0
		row["Y_span_m"] = float(row["maximum_y"])-float(row["minimum_y"])
		row["max_slope_witness"] = _l35_face_witness09(int(row["max_slope_face_ordinal"]))
		row["max_Y_span_witness"] = _l35_face_witness09(int(row["max_Y_span_face_ordinal"]))
	for front: Dictionary in fronts:
		if int(front["count"]) == 0:
			for key: String in ["minimum_y","maximum_y","minimum_slope_degrees","minimum_z","maximum_z","min_x","max_x"]: front[key] = 0.0
		front["Y_span_m"] = float(front["maximum_y"])-float(front["minimum_y"])
		front["max_slope_witness"] = _l35_face_witness09(int(front["max_slope_face_ordinal"]))
		front["world_X_span_m"] = float(front["max_x"])-float(front["min_x"])
		meaningful = meaningful and float(front["Y_span_m"]) >= .10 and float(front["surface_area_m2"]) >= .15 and float(front["max_slope_degrees"]) > 35.0
	return {"schema":"mush-entrance46-role-metrics/1","proposed_front_tread_count":4,"passed":binding and meaningful and maxf(float(rows[0]["max_slope_degrees"]),float(rows[1]["max_slope_degrees"])) <= 25.0 and maxf(float(rows[2]["max_slope_degrees"]),float(rows[3]["max_slope_degrees"])) <= 88.0,"source_authored_roles_complete":binding,"substantive_front_sanity_passed":meaningful,"role_summary":rows,"fronts_by_tread":fronts,"walking_max_slope_degrees":maxf(float(rows[0]["max_slope_degrees"]),float(rows[1]["max_slope_degrees"])),"nonwalking_max_slope_degrees":maxf(float(rows[2]["max_slope_degrees"]),float(rows[3]["max_slope_degrees"])),"walking_path_triangles":_l35_walking_faces.size()/3,"nonwalking_path_triangles":_l35_nonwalking_faces.size()/3,"path_role_sha256":_cap_preview_sha(_l35_path_role_codes.to_byte_array()),"path_fraction_parameter_sha256":_cap_preview_sha(_l35_path_q_parameters.to_byte_array()),"walking_selected_sha256":_cap_preview_sha(_l35_walking_faces.to_byte_array()),"nonwalking_selected_sha256":_cap_preview_sha(_l35_nonwalking_faces.to_byte_array()),"walking_intrinsic_sha256":_cap_preview_sha(_l35_walking_intrinsic.to_byte_array()),"nonwalking_intrinsic_sha256":_cap_preview_sha(_l35_nonwalking_intrinsic.to_byte_array()),"scope":"Authored native cell roles before slope measurement. Full path remains render/collider/support authority. Four unequal terraces have genuinely compressed outboard front planes and blunt edges; original center bevels remain visible parts of the same canonical field. No actual movement, visual success or approval inference."}

func get_stone_front09_evidence() -> Dictionary:
	return {"schema":"mush-entrance46-four-terrace-native-evidence/1","passed":false,"retired":true,"replacement_schema":"mush-entrance48-solid-evidence/1","scope":"Old all-positive-XZ heightfield proof does not cover true vertical slab walls. Use get_solid48_evidence."}

func _r25_measure() -> void:
	var area: float = 0.0;var raised: float = 0.0;var maximum: float = 0.0
	var walking_max: float = 0.0;var soil_max: float = 0.0;var bed_max: float = 0.0
	var finite: bool = true
	for kind: String in ["floor","soil"]:
		var faces: PackedVector3Array = _r25_path_faces if kind=="floor" else _r25_soil_faces
		for i: int in range(0,faces.size(),3):
			var a: Vector3 = faces[i];var b: Vector3 = faces[i+1];var c: Vector3 = faces[i+2]
			var cross: Vector3 = (c-a).cross(b-a);var normal: Vector3 = cross.normalized()
			var projected: float = (float(b.x)-float(a.x))*(float(c.z)-float(a.z))-(float(b.z)-float(a.z))*(float(c.x)-float(a.x))
			finite=finite and a.is_finite() and b.is_finite() and c.is_finite() and cross.length_squared()>1e-18 and normal.y>0.0 and projected>0.0
			area+=projected*.5;maximum=maxf(maximum,maxf(a.y,maxf(b.y,c.y)))
			var middle: Vector3 = (a+b+c)/3.0
			if middle.y>float(_r25_base(middle).get("height",middle.y))+.03:raised+=projected*.5
			var slope: float = rad_to_deg(acos(clampf(normal.y,-1.0,1.0)))
			if kind=="soil":soil_max=maxf(soil_max,slope)
			else:
				var role: int = int(_l48_floor_labels[i/3]["solid48_role"])
				if role==0 or role==1:walking_max=maxf(walking_max,slope)
				else:bed_max=maxf(bed_max,slope)
	var counts: Dictionary = {"walking_top":0,"walking_bevel":0,"vertical_stone_wall":0,"closed_stone_base":0,"exposed_bed_floor":0,"vertical_gap_soil":0}
	var names: Array[String] = ["walking_top","walking_bevel","vertical_stone_wall","closed_stone_base","exposed_bed_floor","vertical_gap_soil"]
	var all3d: bool = _l48_binding_exact();var vertical: bool = true
	for face: int in range(_l48_labels.size()):
		var a: Vector3 = _l48_faces[face*3];var b: Vector3 = _l48_faces[face*3+1];var c: Vector3 = _l48_faces[face*3+2]
		var cross: Vector3 = (c-a).cross(b-a)
		var role: int = int(_l48_labels[face]["solid48_role"])
		all3d=all3d and a.is_finite() and b.is_finite() and c.is_finite() and cross.length_squared()>1e-18 and role>=0 and role<=5
		if role>=0 and role<=5:counts[names[role]]=int(counts[names[role]])+1
		if role==2 or role==5:vertical=vertical and cross.y==0.0
	var coverage: bool = absf(area-_r25_rect.size.x*8.0)<=.001
	var passed: bool = finite and all3d and vertical and coverage and walking_max<=25.0 and soil_max<=88.0 and bed_max<=88.0 and _r25_faces.size()/3<=6000 and _l48_faces.size()/3<=1050 and raised>=8.0 and maximum>=.60 and _l35_shape_descriptor_exact()
	for name: String in names:passed=passed and int(counts[name])>0
	_l48_report={"schema":"mush-entrance48-slab-volume/1","passed":passed,"provisional":true,"geometry_contract":"separate-floor-support-and-closed-solids","slab_count":_l48_cells.size(),"terrace_count":4,"role_counts":counts,"full_solid_triangles":_l48_faces.size()/3,"floor_support_triangles":_r25_path_faces.size()/3,"soil_triangles":_r25_soil_faces.size()/3,"finite_3D_nondegenerate":all3d,"authored_vertical_walls_normal_Y_exact_zero":vertical,"walking_max_slope_degrees":walking_max,"exposed_bed_max_slope_degrees":bed_max,"soil_rock_max_slope_degrees":soil_max,"floor_projected_area_balance_passed":coverage,"floor_projected_area_m2":area,"floor_projected_area_error_m2":area-_r25_rect.size.x*8.0,"floor_sha256":_cap_preview_sha(_r25_path_faces.to_byte_array()),"solid_sha256":_cap_preview_sha(_l48_faces.to_byte_array()),"solid_labels_sha256":_l35_sha(_l48_labels),"roles_authored_before_normals":true,"old_all_path_upward_heightfield_claim":false,"vertical_wall_slope88_claim":false,"hidden_ramp":false,"replacement_triangle_target":1050,"additional_physical_triangle_limit":4000,"actual_additional_physical_triangles_pending":true,"actual_movement_passed":false,"art_approved":false,"scope":"Native floor coverage is separate from complete closed stone/soil-wall collision. Vertical faces are3D nondegenerate and authored by solid role, never admitted as upward floors or classified from slope. Full collider/readback and actual tagged auto-step/contact are separate required stages."}
	_l35_quality={"passed":passed,"schema":"mush-entrance48-floor-and-solid-quality/1","finite_upward_nondegenerate":finite,"finite_upward_scope":"Floor/soil support subset only; vertical/base solids use3D proof","projected_area_balance_within0_001_m2":coverage,"projected_area_error_m2":area-_r25_rect.size.x*8.0,"canonical_triangles":_r25_faces.size()/3,"path_triangles":_r25_path_faces.size()/3,"soil_triangles":_r25_soil_faces.size()/3,"full_solid_triangles":_l48_faces.size()/3,"raised_area_over30mm_m2":raised,"max_y":maximum,"walking_max_slope_degrees":walking_max,"path_max_slope_degrees":maxf(walking_max,bed_max),"soil_rock_max_slope_degrees":soil_max,"proposed_path_limit":25.0,"proposed_soil_rock_limit":88.0,"old_heightfield_nonwalking_path_limit_retired":true,"solid48":_l48_report.duplicate(true)}
	_l35_shape_report={"schema":"mush-entrance48-solid-shape/1","passed":passed,"provisional":true,"descriptor_recipe_exact":_l35_shape_descriptor_exact(),"ordered_floor_and_solid_labels_exact":_l48_binding_exact(),"old46_selected_intrinsic_heightfield_claim":false}
	_l35_front09_report={"schema":"mush-entrance46-role-metrics/1","passed":false,"retired":true,"replacement_schema":"mush-entrance48-slab-volume/1"}
	_r25_stats={"native_rect":[_r25_rect.position.x,_r25_rect.end.x,3,11],"canonical_triangles":_r25_faces.size()/3,"soil_triangles":_r25_soil_faces.size()/3,"path_triangles":_r25_path_faces.size()/3,"full_solid_triangles":_l48_faces.size()/3,"projected_area_m2":area,"raised_area_over30mm_m2":raised,"max_top_y_m":maximum,"max_top_triangle_slope_deg":maxf(walking_max,maxf(soil_max,bed_max)),"threshold_join":{"z_start":3.0,"y":.60,"half_width":1.08,"original_ramp_z_endpoint":3.10},"proposed35_rises_m":_l35_data.get("rises"),"flank_faces_collision":false,"fresh35_quality":_l35_quality}
	if not passed:_r25_errors.append("Solid48 native floor/solid quality or bounded replacement refused")

func _l35_realize(material: ShaderMaterial) -> Dictionary:
	var before: Dictionary = _cap_preview_uniforms(material)
	var properties: Array = material.get_property_list()
	var after: Dictionary = _cap_preview_uniforms(material)
	var passed: bool = true
	for key: String in _CAP_PREVIEW_UNIFORMS:
		var expected: Variant = before[key] if before[key] != null else RenderingServer.shader_get_parameter_default(material.shader.get_rid(),key)
		passed = passed and typeof(expected) == typeof(after[key]) and var_to_bytes(expected) == var_to_bytes(after[key])
	return {"passed":passed,"getter":"get_property_list","property_count":properties.size(),"native_explicit_or_declared_defaults_exact":passed,"shader_parameter_setters_invoked":false}

func _l35_stone_spec(key: String) -> Dictionary:
	# Top/front remain related pieces of the same stone; native normals supply contrast.
	if key == "stone_light": return {"base_color":Color(.50,.48,.43),"accent_color":Color(.25,.26,.22),"grain":.9,"roughness_value":.94}
	if key == "stone": return {"base_color":Color(.475,.456,.4085),"accent_color":Color(.2375,.247,.209),"grain":.9,"roughness_value":.94}
	return {}

func _l35_uniform_values_exact(actual: Dictionary,expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key: String in _CAP_PREVIEW_UNIFORMS:
		if not actual.has(key) or not expected.has(key) or typeof(actual[key]) != typeof(expected[key]) or var_to_bytes(actual[key]) != var_to_bytes(expected[key]): return false
		if expected[key] is Object and actual[key] != expected[key]: return false
	return true

func _l35_uniform_witness(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in values:
		var value: Variant = values[key]
		result[key] = {"type":typeof(value),"varhex":var_to_bytes(value).hex_encode()}
		if value is Color: result[key]["rgba"] = [value.r,value.g,value.b,value.a]
		elif value is float or value is int or value is bool or value == null: result[key]["value"] = value
	return result

func _l35_registry_exact() -> bool:
	if _materials.size() != _l35_registry_bindings.size(): return false
	for key: String in _l35_registry_bindings:
		if not _materials.has(key) or _materials[key] != _l35_registry_bindings[key]: return false
	return true

func _l35_prepare_materials() -> bool:
	if _l35_materials_ready: return true
	var rng: String = str(_rng.state)
	_l35_registry_bindings = _materials.duplicate()
	for key: String in ["soil","stone","stone_light"]:
		var original: ShaderMaterial = _materials[key] as ShaderMaterial
		_l35_shared_materials[key] = original
		var realization: Dictionary = _l35_realize(original)
		var original_values: Dictionary = _cap_preview_uniforms(original)
		_l35_shared_uniform_values[key] = original_values.duplicate()
		_l35_shared_uniforms[key] = var_to_bytes(original_values)
		_l35_material_states[key] = {"shader":original.shader,"render_priority":original.render_priority,"next_pass":original.next_pass}
		var selected: ShaderMaterial = original.duplicate(false) as ShaderMaterial
		var duplicated: Dictionary = _l35_realize(selected)
		var duplicate_exact: bool = realization.get("passed",false) and duplicated.get("passed",false) and selected != original and selected.shader == original.shader and selected.render_priority == original.render_priority and selected.next_pass == original.next_pass and _l35_uniform_values_exact(_cap_preview_uniforms(selected),original_values)
		var requested: Dictionary = _l35_stone_spec(key)
		var expected: Dictionary = original_values.duplicate()
		for uniform_key: String in requested:
			expected[uniform_key] = requested[uniform_key]
			selected.set_shader_parameter(uniform_key,requested[uniform_key])
		var readback: Dictionary = _cap_preview_uniforms(selected)
		var selected_exact: bool = _l35_uniform_values_exact(readback,expected)
		var original_exact: bool = _l35_uniform_values_exact(_cap_preview_uniforms(original),original_values) and var_to_bytes(_cap_preview_uniforms(original)) == _l35_shared_uniforms[key]
		var exact: bool = duplicate_exact and selected_exact and original_exact and _l35_registry_exact() and rng == str(_rng.state)
		_l35_selected_uniform_values[key] = expected.duplicate()
		_l35_selected_uniforms[key] = var_to_bytes(expected)
		_l35_material_resolution[key] = {"passed":exact,"original":realization,"duplicate":duplicated,"pre_set_duplicate_exact":duplicate_exact,"original_id":str(original.get_instance_id()),"duplicate_id":str(selected.get_instance_id()),"original_uniforms_sha256":_cap_preview_sha(_l35_shared_uniforms[key]),"uniforms_sha256":_cap_preview_sha(_l35_shared_uniforms[key]),"selected_uniforms_sha256":_cap_preview_sha(_l35_selected_uniforms[key]),"requested_parameters":_l35_uniform_witness(requested),"selected_readback":_l35_uniform_witness(readback),"selected_snapshot_varhex":(_l35_selected_uniforms[key] as PackedByteArray).hex_encode(),"selected_spec_exact":selected_exact,"original_uniforms_byteexact":original_exact,"original_registry_bindings_exact":_l35_registry_exact(),"shader_unchanged":selected.shader == original.shader,"intentional_selected_fork":not requested.is_empty(),"setters_on_original":false,"soil_uniforms_unchanged":key != "soil" or requested.is_empty()}
		_l35_materials[key] = selected
		if not exact: _l35_fail("Fresh46 original or selected private material specification differs")
	_l35_materials_ready = _l35_errors.is_empty() and _l35_registry_exact() and rng == str(_rng.state)
	return _l35_materials_ready

func _l35_materials_exact() -> bool:
	if not _l35_materials_ready or not _l35_registry_exact(): return false
	for key: String in ["soil","stone","stone_light"]:
		var original: ShaderMaterial = _materials[key] as ShaderMaterial
		var selected: ShaderMaterial = _l35_materials[key] as ShaderMaterial
		var state: Dictionary = _l35_material_states[key]
		if original != _l35_shared_materials.get(key) or selected == original or original.shader != state["shader"] or selected.shader != state["shader"] or original.render_priority != state["render_priority"] or selected.render_priority != state["render_priority"] or original.next_pass != state["next_pass"] or selected.next_pass != state["next_pass"]: return false
		if var_to_bytes(_cap_preview_uniforms(original)) != _l35_shared_uniforms[key] or not _l35_uniform_values_exact(_cap_preview_uniforms(original),_l35_shared_uniform_values[key]): return false
		if var_to_bytes(_cap_preview_uniforms(selected)) != _l35_selected_uniforms[key] or not _l35_uniform_values_exact(_cap_preview_uniforms(selected),_l35_selected_uniform_values[key]): return false
	return true

func _l35_stone_block_key(category: Dictionary,p: Vector3) -> int:
	if category.has("block48"):return int(category["block48"])
	var tread: int = maxi(int(category["top"]),int(category["nose"]))
	if tread < 0: return -1
	var width: float = _r25_width(p.z)
	var fraction: float = (p.x-(_r25_center(p.z)-width))/(2.0*width)
	var block: int = 0
	for divider: float in _l35_curved_dividers(tread,p.z):
		if fraction >= divider: block += 1
	return tread*8+block

func _l35_stone_tint_gain(block_key: int) -> float:
	return .90+.16*float((block_key*37+11)%17)/16.0

func _l35_rock_face(p: Vector3) -> bool:
	var outside: float = absf(p.x-_r25_center(p.z))-_r25_width(p.z)
	return outside > .35 and _l35_mound(p) > .18 and sin(p.x*3.1+p.z*2.2)+.4*sin(p.x*7.4-p.z*4.1) > -.15

func _l35_draw_bucket(source: Dictionary,kind: String) -> void:
	if not _l35_prepare_materials(): return
	var groups: Dictionary = {"soil":_r22_bucket(),"stone":_r22_bucket(),"stone_light":_r22_bucket()}
	var v: PackedVector3Array = source["v"]
	var n: PackedVector3Array = source["n"]
	var u: PackedVector2Array = source["u"]
	var colors: PackedColorArray = source["c"]
	var nose_counts: Array[int] = [0,0,0,0]
	var top_counts: Array[int] = [0,0,0,0]
	var counts: Dictionary = {"soil":0,"stone":0,"stone_light":0}
	var joint_count: int = 0
	var entry_front_rgb_triangles: int = 0
	var entry_moss_rgb_triangles: int = 0
	var tint_blocks: Dictionary = {}
	var tint_alpha_exact: bool = true
	var tint_geometry_exact: bool = true
	var tint_rng: String = str(_rng.state)
	for i: int in range(0,v.size(),3):
		var middle: Vector3 = (v[i]+v[i+1]+v[i+2])/3.0
		var inside: bool = _r25_rect.has_point(Vector2(middle.x,middle.z))
		var category: Dictionary = _l48_labels[i/3].duplicate() if kind == "ascent" and _l48_labels.size() == v.size()/3 else {"material":"stone" if inside and _l35_rock_face(middle) else "soil","nose":-1,"top":-1,"joint":false}
		var key: String = category["material"]
		counts[key] = int(counts[key])+1
		if kind == "ascent":
			if int(category["nose"]) >= 0: nose_counts[int(category["nose"])] += 1
			if int(category["top"]) >= 0 and not category["joint"]: top_counts[int(category["top"])] += 1
			if category["joint"]: joint_count += 1
		var entry: Dictionary = groups[key]
		var ev: PackedVector3Array = entry["v"];var en: PackedVector3Array = entry["n"];var eu: PackedVector2Array = entry["u"];var ec: PackedColorArray = entry["c"]
		var tread: int = int(category.get("tread48",maxi(int(category["top"]),int(category["nose"]))))
		var shade: float = .94+.025*sin(float(tread)*1.7) if kind == "ascent" else .86+.09*sin(middle.x*12.1+middle.z*8.3)
		var block_point: Vector3 = category.get("parameter_middle",middle)
		var block_key: int = _l35_stone_block_key(category,block_point) if kind == "ascent" and key != "soil" else -1
		var tint_gain: float = _l35_stone_tint_gain(block_key) if block_key >= 0 else 1.0
		var entry_front: bool = kind == "ascent" and int(category["nose"]) >= 0 and key != "soil"
		var entry_moss: bool = kind == "ascent" and bool(category.get("joint",false))
		if entry_front: entry_front_rgb_triangles += 1
		if entry_moss: entry_moss_rgb_triangles += 1
		if block_key >= 0:
			tint_blocks[str(block_key)] = {"native_block_key":block_key,"tread":tread,"nose":int(category["nose"]) >= 0,"gain":tint_gain,"gain_varhex":var_to_bytes(tint_gain).hex_encode()}
		for corner: int in range(3):
			ev.append(v[i+corner]);en.append(n[i+corner]);eu.append(u[i+corner])
			var original_color: Color = colors[i+corner]
			var selected_color: Color = Color(shade,shade,shade,1) if key != "soil" else original_color
			if entry_front:
				selected_color = Color(selected_color.r*.80,selected_color.g*.80,selected_color.b*.80,selected_color.a)
			if entry_moss:
				var moss: Color = Color(.72,.92,.62)
				selected_color = Color(selected_color.r*moss.r,selected_color.g*moss.g,selected_color.b*moss.b,selected_color.a)
			if block_key >= 0:
				selected_color = Color(selected_color.r*tint_gain,selected_color.g*tint_gain,selected_color.b*tint_gain,original_color.a)
				tint_alpha_exact = tint_alpha_exact and var_to_bytes(selected_color.a) == var_to_bytes(original_color.a) and tint_gain >= .90 and tint_gain <= 1.06
			if kind == "ascent": tint_alpha_exact = tint_alpha_exact and var_to_bytes(selected_color.a) == var_to_bytes(original_color.a)
			ec.append(selected_color)
			tint_geometry_exact = tint_geometry_exact and ev[ev.size()-1] == v[i+corner] and en[en.size()-1] == n[i+corner] and eu[eu.size()-1] == u[i+corner]
		entry["v"] = ev;entry["n"] = en;entry["u"] = eu;entry["c"] = ec
	if kind == "ascent":
		var passed: bool = v.to_byte_array()==_l48_faces.to_byte_array() and _l48_labels.size()==v.size()/3 and joint_count>0 and tint_alpha_exact and tint_geometry_exact and tint_rng==str(_rng.state) and entry_front_rgb_triangles>0 and entry_moss_rgb_triangles>0
		for tread: int in range(4):passed=passed and nose_counts[tread]>0 and top_counts[tread]>0
		_l35_tread_semantics={"schema":"mush-entrance48-slab-material-semantics/1","passed":passed,"proposed_tread_count":4,"slab_count":18,"top_triangles":top_counts,"vertical_wall_triangles":nose_counts,"joint_triangles":joint_count,"material_triangle_counts":counts,"complete_solid_position_input_exact":v.to_byte_array()==_l48_faces.to_byte_array(),"same_block_tint_top_front":true,"equal_final_top_front_RGB_claim":false,"entry_vertex_rgb":{"passed":passed,"nose_rgb_gain":.80,"joint_moss_rgb_multiplier":Vector3(.72,.92,.62),"front_rgb_triangles":entry_front_rgb_triangles,"moss_rgb_triangles":entry_moss_rgb_triangles,"alpha_byteexact":tint_alpha_exact},"ascent_block_tint":{"passed":tint_alpha_exact and tint_geometry_exact and tint_rng==str(_rng.state),"blocks":tint_blocks,"gain_min":.90,"gain_max":1.06,"alpha_byteexact":tint_alpha_exact,"rng_unchanged":tint_rng==str(_rng.state)},"old46_profile_row_semantics_claim":false,"scope":"Explicit short closed slab cells; shared block gain and current palette retained, separate front RGB contrast. Full native encoder/source/batch proof still required."}
		if not passed:_l35_fail("Solid48 native top/wall/joint material semantics refused")
	for key: String in groups:
		var bucket: Dictionary = groups[key]
		if (bucket["v"] as PackedVector3Array).is_empty(): continue
		var mesh: ArrayMesh = _array_mesh(bucket["v"],bucket["n"],bucket["u"],bucket["c"])
		var node: MeshInstance3D = _instance(mesh,_l35_materials[key] as Material,self)
		node.name = "Entrance35_%s_%s" % [kind,key]
		_l35_render.append({"kind":kind+"_"+key,"node":node,"mesh":mesh,"transform":node.transform,"material":node.material_override,"expected_arrays":mesh.surface_get_arrays(0),"canonical_input_position_bytes":(bucket["v"] as PackedVector3Array).to_byte_array(),"source_vertex_count":(bucket["v"] as PackedVector3Array).size()})

func _l35_correct_boundary_seams(source: Dictionary,original_source: ArrayMesh,original_xf: Transform3D) -> Dictionary:
	# Actual geometry correction, before native ArrayMesh emission. No tolerance.
	# Rect2.end is the canonical packed boundary; the old native grid endpoint
	# differs by exactly one FP32 ULP after Rect2 size/end arithmetic.
	if _l35_boundary_seam_report.get("status","pending") != "pending":
		_l35_fail("Boundary seam correction must run once on west-ground appended source");return source
	_l35_boundary_seam_report["status"] = "refused"
	for key: String in ["v","n"]:
		if not source.get(key) is PackedVector3Array:
			_l35_fail("Boundary seam source Vector3 field missing: "+key);return source
	if not source.get("u") is PackedVector2Array or not source.get("c") is PackedColorArray:
		_l35_fail("Boundary seam source UV/color field missing");return source
	var v: PackedVector3Array = source["v"]
	var n: PackedVector3Array = source["n"]
	var u: PackedVector2Array = source["u"]
	var colors: PackedColorArray = source["c"]
	if v.is_empty() or v.size()%3!=0 or v.size()>83536 or n.size()!=v.size() or u.size()!=v.size() or colors.size()!=v.size():
		_l35_fail("Boundary seam finite source field cardinality refused");return source
	var grid: PackedVector3Array = _foreground_bank_original_faces[0]
	var xs: Array[float] = []
	for p: Vector3 in grid:
		if not p.is_finite():_l35_fail("Boundary seam original grid nonfinite");return source
		if not xs.has(float(p.x)):xs.append(float(p.x))
	xs.sort()
	if xs.size()!=33:
		_l35_fail("Boundary seam original33 grid columns changed");return source
	var boundary: float = float(_r25_rect.end.x)
	# Parent partition uses actual render V; collision get_faces() snapped its grid.
	# This source is the exact original ArrayMesh supplied to _r25_remove_patch.
	if original_source == null or original_source.get_surface_count()<1 or original_xf != Transform3D.IDENTITY:
		_l35_fail("Boundary seam original native render source/identity transform missing");return source
	var original_arrays: Array = original_source.surface_get_arrays(0)
	if not original_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		_l35_fail("Boundary seam original native render V missing");return source
	var original_v: PackedVector3Array = original_arrays[Mesh.ARRAY_VERTEX]
	var render_xs: Array[float] = []
	for p: Vector3 in original_v:
		if not p.is_finite():_l35_fail("Boundary seam original native render V nonfinite");return source
		if not render_xs.has(float(p.x)):render_xs.append(float(p.x))
	render_xs.sort()
	if render_xs.size()!=33 or xs[28]!=boundary:
		_l35_fail("Boundary seam canonical/render33 grid source differs");return source
	var original_boundary: float = render_xs[28]
	var boundary_bytes: PackedByteArray = PackedFloat32Array([boundary]).to_byte_array()
	var original_bytes: PackedByteArray = PackedFloat32Array([original_boundary]).to_byte_array()
	if not is_finite(boundary) or not is_finite(original_boundary) or boundary<=0.0 or original_boundary<=boundary or original_bytes.decode_u32(0)!=boundary_bytes.decode_u32(0)+1:
		_l35_fail("Boundary seam exact adjacent packed Rect/grid endpoints changed");return source
	var ev: PackedVector3Array = PackedVector3Array()
	var en: PackedVector3Array = PackedVector3Array()
	var eu: PackedVector2Array = PackedVector2Array()
	var ec: PackedColorArray = PackedColorArray()
	var removed: Dictionary = {}
	var witnesses: Array[Dictionary] = []
	for offset: int in range(0,v.size(),3):
		var face: PackedVector3Array = PackedVector3Array([v[offset],v[offset+1],v[offset+2]])
		var has_boundary: bool = false
		var has_original: bool = false
		var exact_strip: bool = true
		for p: Vector3 in face:
			if not p.is_finite():_l35_fail("Boundary seam appended position nonfinite");return source
			has_boundary=has_boundary or float(p.x)==boundary
			has_original=has_original or float(p.x)==original_boundary
			exact_strip=exact_strip and (float(p.x)==boundary or float(p.x)==original_boundary) and p.z>=3.0 and p.z<=11.0
		var a: Vector3 = face[0];var b: Vector3 = face[1];var c: Vector3 = face[2]
		var determinant: float = (float(b.x)-float(a.x))*(float(c.z)-float(a.z))-(float(b.z)-float(a.z))*(float(c.x)-float(a.x))
		if exact_strip and has_boundary and has_original and determinant>0.0:
			if witnesses.size()>=16:_l35_fail("Boundary seam correction exceeds exact16 diagnosed artifacts");return source
			var collapsed: PackedVector3Array = face.duplicate()
			for corner: int in range(3):
				var p: Vector3 = collapsed[corner];p.x=boundary;collapsed[corner]=p
			var ca: Vector3 = collapsed[0];var cb: Vector3 = collapsed[1];var cc: Vector3 = collapsed[2]
			var collapsed_det: float = (float(cb.x)-float(ca.x))*(float(cc.z)-float(ca.z))-(float(cb.z)-float(ca.z))*(float(cc.x)-float(ca.x))
			if collapsed_det!=0.0:_l35_fail("Boundary seam collapsed face does not have exact zero XZ area");return source
			var face_n: PackedVector3Array = PackedVector3Array([n[offset],n[offset+1],n[offset+2]])
			var face_u: PackedVector2Array = PackedVector2Array([u[offset],u[offset+1],u[offset+2]])
			var face_c: PackedColorArray = PackedColorArray([colors[offset],colors[offset+1],colors[offset+2]])
			removed[offset/3]=true
			witnesses.append({"input_face_ordinal":offset/3,"input_corner_index":offset,"original_native_V_varhex":var_to_bytes(face).hex_encode(),"original_native_N_varhex":var_to_bytes(face_n).hex_encode(),"original_native_UV_varhex":var_to_bytes(face_u).hex_encode(),"original_native_COLOR_varhex":var_to_bytes(face_c).hex_encode(),"collapsed_native_V_varhex":var_to_bytes(collapsed).hex_encode(),"original_projected_determinant":determinant,"collapsed_projected_determinant":collapsed_det,"source_exact_two_X_boundary_pair":true,"source_Z_within_original_ROI":true})
			continue
		for corner: int in range(3):
			ev.append(v[offset+corner]);en.append(n[offset+corner]);eu.append(u[offset+corner]);ec.append(colors[offset+corner])
	if witnesses.size()!=16 or removed.size()!=16:
		_l35_fail("Boundary seam correction does not match exact16 diagnosed artifacts");return source
	# Independently reconstruct the ordered complement, without evaluating normals,
	# materials, slopes or any tolerance when selecting/removing a face.
	var pv: PackedVector3Array = PackedVector3Array()
	var pn: PackedVector3Array = PackedVector3Array()
	var pu: PackedVector2Array = PackedVector2Array()
	var pc: PackedColorArray = PackedColorArray()
	for offset: int in range(0,v.size(),3):
		if removed.has(offset/3):continue
		for corner: int in range(3):
			pv.append(v[offset+corner]);pn.append(n[offset+corner]);pu.append(u[offset+corner]);pc.append(colors[offset+corner])
	var remaining_exact: bool = ev.to_byte_array()==pv.to_byte_array() and en.to_byte_array()==pn.to_byte_array() and eu.to_byte_array()==pu.to_byte_array() and ec.to_byte_array()==pc.to_byte_array() and ev.size()==v.size()-48
	if not remaining_exact:_l35_fail("Boundary seam ordered remaining V/N/UV/C native bytes differ");return source
	var corrected: Dictionary = source.duplicate()
	corrected["v"]=ev;corrected["n"]=en;corrected["u"]=eu;corrected["c"]=ec
	var other_exact: bool = corrected.size()==source.size()
	for key: Variant in source:
		if key not in ["v","n","u","c"]:other_exact=other_exact and typeof(corrected[key])==typeof(source[key]) and corrected[key]==source[key]
	if not other_exact:_l35_fail("Boundary seam unrelated bucket values changed");return source
	_l35_boundary_seam_report={"schema":"mush-entrance35-native-boundary-seam-correction/1","passed":true,"status":"complete","authoritative_packed_Rect_end_X":boundary,"original_packed_render_grid_column28_X":original_boundary,"canonical_collision_grid_column28_X":xs[28],"original_render_V_sha256":_cap_preview_sha(original_v.to_byte_array()),"original_render_transform_identity":original_xf==Transform3D.IDENTITY,"authoritative_boundary_F32hex":boundary_bytes.hex_encode(),"original_grid_boundary_F32hex":original_bytes.hex_encode(),"boundary_values_exact_adjacent_FP32":true,"original_grid_columns":xs.size(),"input_triangles":v.size()/3,"removed_zero_projection_artifact_triangles":witnesses.size(),"remaining_triangles":ev.size()/3,"all16_input_native_face_identities":witnesses,"all_removed_collapsed_XZ_determinants_exact_zero":true,"remaining_V_N_UV_COLOR_ordered_native_bytes_exact":remaining_exact,"remaining_other_bucket_values_exact":other_exact,"remaining_field_sha256":{"V":_cap_preview_sha(ev.to_byte_array()),"N":_cap_preview_sha(en.to_byte_array()),"UV":_cap_preview_sha(eu.to_byte_array()),"COLOR":_cap_preview_sha(ec.to_byte_array())},"expected_remaining_field_sha256":{"V":_cap_preview_sha(pv.to_byte_array()),"N":_cap_preview_sha(pn.to_byte_array()),"UV":_cap_preview_sha(pu.to_byte_array()),"COLOR":_cap_preview_sha(pc.to_byte_array())},"canonical_collision_support_or_outside_prefix_changed":false,"observer_tolerance_or_slope_waiver":false,"scope":"Child-only pre-ArrayMesh correction of exact16 positive-XZ rounding seams spanning the adjacent packed native grid/Rect right boundary. Only these strip faces collapse to exact zero projected area and are omitted; every remaining native bucket field stays byteexact in original order. Current native author/replay and render/contact evidence remain separate."}
	return corrected

func _r25_remove_patch(source: ArrayMesh,node: MeshInstance3D,kind: String,added: Dictionary) -> ArrayMesh:
	var selected: ArrayMesh = super._r25_remove_patch(source,node,kind,added)
	if selected == null or kind != "west_ground": return selected
	var record: Dictionary = _r25_meshes[_r25_meshes.size()-1]
	var stored: Array = record["selected_encoded_prefix"]
	var prefix: ArrayMesh = ArrayMesh.new()
	prefix.set("_surfaces",stored)
	if prefix.get_surface_count() != stored.size() or var_to_bytes(prefix.get("_surfaces")) != var_to_bytes(stored):
		_l35_fail("Retained native outside surface buffers differ");return null
	_l35_prefixes.append({"mesh":prefix,"expected_encoded":stored.duplicate(true),"kind":kind,"retained_surface_count":stored.size(),"retained_indices":record["retained_indices"],"source":source})
	record["selected_mesh"] = prefix;record["extra_surface"] = -1
	record["fresh35_split_appended_render"] = true
	var corrected_added: Dictionary = _l35_correct_boundary_seams(added,source,node.transform)
	if not _l35_boundary_seam_report.get("passed",false): return prefix
	_l35_draw_bucket(corrected_added,"shoulder")
	return prefix

func _r25_embed_paving(node: MeshInstance3D,record: Dictionary) -> void:
	var changed: bool = _r25_affects(node.mesh as ArrayMesh,node.transform)
	if not changed:
		super._r25_embed_paving(node,record);return
	_l35_hidden.append({"kind":"superseded_thin_paving","node":node,"mesh":node.mesh,"transform":node.transform,"material":node.material_override})
	node.visible = false
	record["selected_mesh"] = node.mesh;record["selected_transform"] = node.transform
	record["fresh35_hidden_replaced_by_canonical_walktop"] = true

func _r25_actual_entry_stones() -> Array[Dictionary]:
	var original: Array[Dictionary] = super._r25_actual_entry_stones()
	var result: Array[Dictionary] = []
	for stone: Dictionary in original:
		var node: MeshInstance3D = stone.get("node") as MeshInstance3D
		if node != null and node.visible: result.append(stone)
	return result

func _create_stairs(parent: Node3D) -> void:
	_l35_progress("stairs_begin",true)
	super._create_stairs(parent)
	for record: Dictionary in _r25_stair_nodes:
		var node: MeshInstance3D = record["node"] as MeshInstance3D
		_l35_hidden.append({"kind":"superseded_thin_stair_"+String(record["kind"]),"node":node,"mesh":node.mesh,"transform":node.transform,"material":node.material_override});node.visible=false
	for selected: Dictionary in _r25_meshes:
		if String(selected.get("kind","")).begins_with("stair_bar_"):selected["fresh35_hidden_replaced_by_canonical_walktop"]=true
	# Parent's temporary floor-only shape is replaced in Ready before any physics frame.
	# One owned body carries every full visible solid; there is no second ramp collider.
	if _r25_stair_collision==null or not _r25_stair_collision.shape is ConcavePolygonShape3D:
		_l35_fail("Solid48 owned stair collider missing");return
	(_r25_stair_collision.shape as ConcavePolygonShape3D).set_faces(_l48_faces)
	var body: StaticBody3D = _r25_stair_collision.get_parent() as StaticBody3D
	if body==null:_l35_fail("Solid48 owned stair body missing");return
	body.set_meta("entrance48_step_surface",true);body.set_meta("entrance48_step_bounds",_r25_rect)
	var extra: int = _l48_faces.size()/3-_r25_old_stair_faces.size()/3
	var net: int = int(_r25_stats.get("west_collision_delta",0))+extra
	_r25_stats["stair_collision_delta"]=extra;_r25_stats["stair_support_delta"]=extra;_r25_stats["stair_support_triangles"]=_l48_faces.size()/3;_r25_stats["floor_support_triangles"]=_r25_path_faces.size()/3;_r25_stats["additional_physical_triangles"]=net
	_l48_report["actual_additional_physical_triangles_pending"]=false;_l48_report["actual_additional_physical_triangles"]=net
	_l48_report["additional_physical_triangle_budget_passed"]=net<=4000
	if net>4000:_r25_errors.append("Additional physical triangles exceed4000");_l35_fail("Solid48 additional physical budget refused")
	var bucket: Dictionary = _r22_bucket()
	for i: int in range(0,_l48_faces.size(),3):_r25_emit(_l48_faces[i],_l48_faces[i+1],_l48_faces[i+2],bucket,Color(.92,.94,.88),false)
	_l35_draw_bucket(bucket,"ascent")
	_r25_extra_stones=_r25_actual_entry_stones();_l35_capture_collision();_l35_progress("stairs_end",true)

func _create_foliage() -> void:
	_l35_progress("foliage_begin",true)
	super._create_foliage()
	_l35_progress("foliage_end",true)

func _l35_capture_collision() -> void:
	var expected_west: PackedVector3Array = _r25_outside(_r25_old_west_faces)
	expected_west.append_array(_r25_soil_faces)
	var actual_west: PackedVector3Array = (_r22_collision.shape as ConcavePolygonShape3D).get_faces() if _r22_collision != null and _r22_collision.shape is ConcavePolygonShape3D else PackedVector3Array()
	var actual_stair: PackedVector3Array = (_r25_stair_collision.shape as ConcavePolygonShape3D).get_faces() if _r25_stair_collision != null and _r25_stair_collision.shape is ConcavePolygonShape3D else PackedVector3Array()
	var passed: bool = not actual_west.is_empty() and not actual_stair.is_empty() and expected_west.to_byte_array() == actual_west.to_byte_array() and _l48_faces.to_byte_array() == actual_stair.to_byte_array()
	_l35_collision = {"passed":passed,"west_expected_sha256":_cap_preview_sha(expected_west.to_byte_array()),"west_actual_sha256":_cap_preview_sha(actual_west.to_byte_array()),"stair_expected_sha256":_cap_preview_sha(_l48_faces.to_byte_array()),"stair_actual_sha256":_cap_preview_sha(actual_stair.to_byte_array()),"canonical_sha256":_cap_preview_sha(_r25_faces.to_byte_array()),"path_sha256":_cap_preview_sha(_r25_path_faces.to_byte_array()),"soil_sha256":_cap_preview_sha(_r25_soil_faces.to_byte_array()),"west_shape_id":str(_r22_collision.shape.get_instance_id()) if _r22_collision != null else "missing","stair_shape_id":str(_r25_stair_collision.shape.get_instance_id()) if _r25_stair_collision != null else "missing","west_transform":_l35_sha(global_transform.affine_inverse()*_r22_collision.global_transform) if _r22_collision != null else "missing","stair_transform":_l35_sha(global_transform.affine_inverse()*_r25_stair_collision.global_transform) if _r25_stair_collision != null else "missing","solid48_sha256":_cap_preview_sha(_l48_faces.to_byte_array()),"solid48_full_collider_scope":true,"outside_partition_scope":"Inherited R22 native west faces and soil partition preserved; one owned stair shape uses complete Solid48 visible/collision faces, separate from floor-only support index."}
	if not passed: _l35_fail("Render authority/native west or stair collider differs")

func _l35_read_plant_faces(mesh: ArrayMesh) -> Dictionary:
	# Installed get_faces() builds a snapped TriangleMesh. This support proof uses
	# the renderer's actual vertex/index streams, including any native index order.
	var faces: PackedVector3Array = PackedVector3Array()
	if mesh == null or mesh.get_surface_count() < 1: return {"passed":false,"faces":faces}
	for surface: int in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: return {"passed":false,"faces":faces}
		var arrays: Array = mesh.surface_get_arrays(surface)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return {"passed":false,"faces":faces}
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: return {"passed":false,"faces":faces}
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if indices.is_empty():
			if vertices.size()%3 != 0: return {"passed":false,"faces":faces}
			faces.append_array(vertices)
		else:
			if indices.size()%3 != 0: return {"passed":false,"faces":faces}
			for index: int in indices:
				if index < 0 or index >= vertices.size(): return {"passed":false,"faces":faces}
				faces.append(vertices[index])
	return {"passed":not faces.is_empty(),"faces":faces}

func _l35_cacheable_mesh(mesh: ArrayMesh) -> bool:
	return mesh != null and (mesh == _grass_mesh or mesh == _flower_mesh or mesh == _broadleaf_mesh or mesh == _fern_mesh or mesh == _glow_mesh)

func _l35_native_surface_snapshot(mesh: ArrayMesh) -> Array:
	var result: Array = []
	if mesh == null: return result
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		result.append([mesh.surface_get_primitive_type(surface),mesh.surface_get_format(surface),arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX]])
	return result

func _l35_parent_samples_safe(mesh: ArrayMesh) -> bool:
	# The unchanged parent sampler reads first-surface V in triples, even when
	# native faces have an INDEX channel. Never invoke it on an unsafe source.
	if mesh == null or mesh.get_surface_count() < 1: return false
	var arrays: Array = mesh.surface_get_arrays(0)
	if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return false
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return not vertices.is_empty() and vertices.size()%3 == 0

func _l35_native_mesh(mesh: ArrayMesh) -> Dictionary:
	if not _l35_mesh_cache.has(mesh):
		var native: Dictionary = _l35_read_plant_faces(mesh)
		var faces: PackedVector3Array = native["faces"]
		var samples_safe: bool = bool(native["passed"]) and _l35_parent_samples_safe(mesh)
		var samples: PackedVector3Array = super._rooted_group_samples(mesh) if samples_safe else PackedVector3Array()
		_l35_mesh_cache[mesh] = {"passed":bool(native["passed"]) and samples_safe,"faces":faces,"samples":samples,"native_surfaces":_l35_native_surface_snapshot(mesh),"faces_sha256":_cap_preview_sha(faces.to_byte_array())}
	return _l35_mesh_cache[mesh] as Dictionary

func _l35_plant_faces(mesh: ArrayMesh) -> Dictionary:
	return _l35_native_mesh(mesh) if _l35_cacheable_mesh(mesh) else _l35_read_plant_faces(mesh)

func _rooted_group_samples(mesh: ArrayMesh) -> PackedVector3Array:
	# Preserve the exact parent helper's deduplicated native PackedVector3 order.
	# Other meshes, including the fixed474 targeted prototypes, are untouched.
	if _l35_cacheable_mesh(mesh): return _l35_native_mesh(mesh)["samples"] as PackedVector3Array
	return super._rooted_group_samples(mesh)

func _l35_validate_mesh_cache() -> Dictionary:
	var passed: bool = not _l35_mesh_cache.is_empty()
	var rows: Array = []
	for family: String in ["grass","flower","broadleaf","fern","fairy"]:
		var mesh: ArrayMesh = _grass_mesh if family == "grass" else _flower_mesh if family == "flower" else _broadleaf_mesh if family == "broadleaf" else _fern_mesh if family == "fern" else _glow_mesh
		if not _l35_mesh_cache.has(mesh):
			passed = false;rows.append({"family":family,"passed":false,"reason":"Actual reused family cache absent"});continue
		var cached: Dictionary = _l35_mesh_cache[mesh]
		var surfaces: Array = _l35_native_surface_snapshot(mesh)
		var actual: Dictionary = _l35_read_plant_faces(mesh)
		var faces: PackedVector3Array = actual["faces"]
		var samples_safe: bool = bool(actual["passed"]) and _l35_parent_samples_safe(mesh)
		var samples: PackedVector3Array = super._rooted_group_samples(mesh) if samples_safe else PackedVector3Array()
		var surface_exact: bool = var_to_bytes(cached["native_surfaces"]) == var_to_bytes(surfaces)
		var faces_exact: bool = faces.to_byte_array() == (cached["faces"] as PackedVector3Array).to_byte_array() and cached["faces_sha256"] == _cap_preview_sha(faces.to_byte_array())
		var samples_exact: bool = samples.to_byte_array() == (cached["samples"] as PackedVector3Array).to_byte_array()
		var exact: bool = bool(actual["passed"]) and samples_safe and bool(cached["passed"]) and surface_exact and faces_exact and samples_exact
		passed = passed and exact
		rows.append({"family":family,"passed":exact,"surface_count":surfaces.size(),"primitive_format_native_V_INDEX_exact":surface_exact,"original_first_surface_sample_source_safe":samples_safe,"expanded_native_triangle_order_bytes_and_sha_exact":faces_exact,"original_sample_order_bytes_exact":samples_exact,"native_faces_sha256":_cap_preview_sha(faces.to_byte_array()),"all_surface_native_V_INDEX_sha256":_l35_sha(surfaces),"original_samples_sha256":_cap_preview_sha(samples.to_byte_array())})
	return {"schema":"mush-entrance35-native-mesh-cache/1","passed":passed,"expected_original_families":5,"private_cache_resource_count":_l35_mesh_cache.size(),"actual_native_validation":rows,"scope":"Cache entries are keyed privately by actual immutable Mesh Resources. Current native surface count/primitive/format/V/INDEX, expanded TRIANGLES and exact original sample order/bytes are independently reread at this admission boundary. No cache key or timing enters the fingerprint; pose/support proofs are not memoized."}

func _l35_footprint(mesh: ArrayMesh,xf: Transform3D) -> Dictionary:
	# Native projected triangle clipping, not just roots or sparse vertex samples.
	# One linear plant face minus one linear canonical face has extrema at the
	# vertices of their clipped XZ overlap, including projected line/point intersections.
	# Root/vertex/edge samples remain additional witnesses for native rounding.
	_l35_full_footprints += 1
	var native: Dictionary = _l35_plant_faces(mesh)
	var local: PackedVector3Array = native["faces"]
	var minimum: float = INF
	var checked: int = 0
	var overlaps: int = 0
	var witness: Dictionary = {}
	var finite: bool = bool(native["passed"])
	for i: int in range(0,local.size(),3):
		var poly: Array[Vector3] = [xf*local[i],xf*local[i+1],xf*local[i+2]]
		poly = _r22_clip(poly,0,_r25_rect.position.x,true)
		poly = _r22_clip(poly,0,_r25_rect.end.x,false)
		poly = _r22_clip(poly,2,3.0,true)
		poly = _r22_clip(poly,2,11.0,false)
		if poly.is_empty(): continue
		var x0: float = poly[0].x;var x1: float = poly[0].x
		var z0: float = poly[0].z;var z1: float = poly[0].z
		for p: Vector3 in poly:
			x0 = minf(x0,p.x);x1 = maxf(x1,p.x);z0 = minf(z0,p.z);z1 = maxf(z1,p.z)
		if x1 < x0 or z1 < z0: continue
		var seen: Dictionary = {}
		for x: int in range(int(floor((x0-_r25_rect.position.x)/.30)),int(floor((x1-_r25_rect.position.x)/.30))+1):
			for z: int in range(int(floor((z0-3.0)/.30)),int(floor((z1-3.0)/.30))+1):
				for ordinal: int in _r25_cells.get(Vector2i(x,z),PackedInt32Array()) as PackedInt32Array:
					if seen.has(ordinal): continue
					seen[ordinal] = true
					var j: int = ordinal*3
					var clipped: Array[Vector3] = _r22_clip_triangle(poly,_r25_faces[j],_r25_faces[j+1],_r25_faces[j+2])
					if clipped.is_empty(): continue
					overlaps += 1
					for p: Vector3 in clipped:
						var hit: Dictionary = _foreground_bank_triangle_support(p,_r25_faces[j],_r25_faces[j+1],_r25_faces[j+2],-24,true)
						finite = finite and p.is_finite() and not hit.is_empty()
						if not hit.is_empty():
							var gap: float = p.y-float(hit["height"])
							if gap < minimum:
								minimum = gap;witness = {"plant_triangle":i/3,"canonical_triangle":ordinal,"actual_native_point":[p.x,p.y,p.z],"canonical_y":hit["height"],"gap_m":gap}
							checked += 1
	return {"passed":finite and (checked == 0 or minimum >= -.002),"native_triangle_overlap_count":overlaps,"clipped_vertex_count":checked,"minimum_gap_m":minimum if checked > 0 else 0.0,"minimum_native_witness":witness,"finite_native_support":finite,"source_triangle_count":local.size()/3,"source_native_sha256":native["faces_sha256"] if native.has("faces_sha256") else _cap_preview_sha(local.to_byte_array()),"TriangleMesh_snapping_used":false,"method":"Actual native rest plant TRIANGLES clipped against actual canonical35 TRIANGLES over the full changedZ3..11 patch; only legacy rootsZ3.3..8 receive this separate pose guard. Shader wind deformation extent is not measured"}

func _l35_complete_projected_reach(mesh: ArrayMesh,xf: Transform3D,original_reach: float) -> Dictionary:
	# Complete ACTUAL native V across every cached surface, not the possibly
	# partial sparse-sample prefix or just first-surface samples. Keep native
	# world-point/root-subtraction arithmetic consistent with the original guard.
	var cached: Dictionary = _l35_native_mesh(mesh)
	var surfaces: Array = cached.get("native_surfaces",[]) as Array
	var native_valid: bool = bool(cached.get("passed",false)) and not surfaces.is_empty()
	var finite: bool = xf.origin.is_finite() and xf.basis.x.is_finite() and xf.basis.y.is_finite() and xf.basis.z.is_finite()
	var vertex_count: int = 0
	var maximum_squared: float = 0.0
	for surface: Variant in surfaces:
		if not surface is Array or (surface as Array).size() != 4 or not surface[2] is PackedVector3Array:
			native_valid = false;continue
		var vertices: PackedVector3Array = surface[2]
		if vertices.is_empty(): native_valid = false
		for vertex: Vector3 in vertices:
			vertex_count += 1
			var p: Vector3 = xf*vertex
			if not p.is_finite(): finite = false;continue
			var squared: float = Vector2(p.x-xf.origin.x,p.z-xf.origin.z).length_squared()
			if not _rooted_groups_numeric(squared): finite = false;continue
			maximum_squared = maxf(maximum_squared,squared)
	var radius: float = sqrt(maximum_squared)
	var original_valid: bool = _rooted_groups_numeric(original_reach) and original_reach >= 0.0
	var original: float = original_reach if original_valid else 0.0
	var policy: Dictionary = _l35_data.get("entry_projected_clearance_policy",{}) as Dictionary
	var cap: float = float(policy.get("new_expansion_cap_m",.35))
	var effective_cap: float = maxf(original,cap)
	var derived: float = maxf(original,radius)
	var within: bool = derived <= effective_cap+.000001
	var passed: bool = native_valid and finite and original_valid and vertex_count > 0 and within
	return {"schema":"mush-entrance35-complete-projected-reach/1","passed":passed,"native_cache_valid":native_valid,"native_surface_count":surfaces.size(),"complete_native_V_count":vertex_count,"all_transformed_native_vertices_finite":finite,"original_caller_metadata_valid":original_valid,"original_caller_reach_m":original_reach,"complete_projected_radius_m":radius,"derived_root_clearance_m":derived,"proposed_new_expansion_cap_m":cap,"effective_cap_preserving_larger_original_m":effective_cap,"within_effective_cap_plus_original1um_allowance":within,"original_native_reach_comparison_allowance_m":.000001,"provisional":true,"scope":"All actual cached native surface V, including all native vertices on indexed surfaces. Radius uses transformed world points minus the actual root, maximum squared radius and one sqrt. Complete finite/native/count/cap checks required. Original caller metadata and larger.39/.45 buffers remain; the new expansion cap is a tunable proposal, not an approved gameplay value."}

func _l35_local_plant_issue(mesh: ArrayMesh,xf: Transform3D,caller_reach: float=-1.0,search_candidate: bool=false) -> Dictionary:
	var minimum: float = INF
	var samples: PackedVector3Array = _rooted_group_samples(mesh)
	var complete_reach: Dictionary = _l35_complete_projected_reach(mesh,xf,caller_reach)
	var checked: int = 0
	var reach: float = 0.0
	var issue: String = ""
	for sample: Vector3 in samples:
		var p: Vector3 = xf*sample
		reach = maxf(reach,Vector2(p.x-xf.origin.x,p.z-xf.origin.z).length())
		if not p.is_finite() or not _ground_foliage_allowed(p,0.0): issue = "nonfinite_or_original_protected_sample";break
		var hit: Dictionary = _rooted_ground_support(p)
		if hit.is_empty(): issue = "fresh35_missing_actual_sample_support";break
		checked += 1
		minimum = minf(minimum,p.y-float(hit["height"]))
		if p.y < float(hit["height"])-.002: issue = "fresh35_native_support_penetration";break
		var stone: Dictionary = _rooted_ground_stone_top(p,_r25_extra_stones)
		if not stone.is_empty() and p.y < float(stone["height"])-.002: issue = "retained_original_entry_stone_sample_penetration";break
	var limit: float = float(complete_reach["derived_root_clearance_m"])
	if not complete_reach["passed"]: issue = "fresh35_complete_native_projected_clearance_invalid_or_exceeds_proposed_cap"
	if not _ground_foliage_allowed(xf.origin,limit): issue = "derived_complete_native_root_clearance_protected"
	# Retain the complete inherited sparse predicate, including both R22 stones
	# and R25 extra stones. Full native overlap/root witnesses strengthen it.
	var original_issue: String = _r22_cluster_issue(mesh,xf,limit) if _r22_old_query == 0 else "current_native_query_required"
	if not original_issue.is_empty(): issue = "inherited_original_guard:"+original_issue
	var root: Dictionary = _r25_surface(xf.origin)
	var root_gap: float = xf.origin.y-float(root.get("height",xf.origin.y))
	# Exact conjunction short-circuit only for a SEARCH pose already proved
	# inadmissible. Selected/appended/readback poses still execute every original
	# guard plus the unchanged full native triangle clipping/support below.
	if search_candidate and (not issue.is_empty() or root.is_empty() or absf(root_gap) > .00001):
		_l35_search_rejections += 1
		return {"passed":false,"issue":issue if not issue.is_empty() else "fresh35_missing_root_query" if root.is_empty() else "fresh35_root_gap_exceeds10um","sample_count":samples.size(),"checked_entry_samples":checked,"minimum_soil_gap_m":minimum if checked > 0 else 0.0,"root_gap_m":root_gap,"actual_reach_m":complete_reach["complete_projected_radius_m"],"sparse_sample_prefix_reach_m":reach,"original_caller_reach_m":caller_reach,"derived_root_clearance_m":limit,"complete_native_projected_reach":complete_reach,"inherited_original_guard_passed":original_issue.is_empty(),"inherited_original_guard_reason":original_issue,"root_query_present":not root.is_empty(),"root_native_height":root.get("height"),"full_native_projected_footprint":{"observed":false,"skipped_only_because_search_pose_already_rejected":true},"domain":"Rejected search candidate only; no full-footprint pass is asserted"}
	var footprint: Dictionary = _l35_footprint(mesh,xf)
	if not footprint["passed"]: issue = "fresh35_native_full_footprint_penetration"
	if root.is_empty(): issue = "fresh35_missing_root_query"
	elif absf(root_gap) > .00001: issue = "fresh35_root_gap_exceeds10um"
	return {"passed":issue.is_empty(),"issue":issue,"sample_count":samples.size(),"checked_entry_samples":checked,"minimum_soil_gap_m":minimum if checked > 0 else 0.0,"root_gap_m":root_gap,"actual_reach_m":complete_reach["complete_projected_radius_m"],"sparse_sample_prefix_reach_m":reach,"original_caller_reach_m":caller_reach,"derived_root_clearance_m":limit,"complete_native_projected_reach":complete_reach,"inherited_original_guard_passed":original_issue.is_empty(),"inherited_original_guard_reason":original_issue,"root_query_present":not root.is_empty(),"root_native_height":root.get("height"),"full_native_projected_footprint":footprint,"domain":"Legacy entry rootsZ3.3..8, actual samples plus native projected overlap over the changed patchZ3..11; original fixed474 domain/guards remain unchanged."}

func _l35_pose_at(mesh: ArrayMesh,origin: Vector3,turn: Vector3,scale_value: Vector3,reach: float) -> Dictionary:
	var hit: Dictionary = _r25_surface(origin)
	if hit.is_empty() or not _ground_foliage_allowed(origin,reach): return {"passed":false,"reason":"missing_or_protected_root"}
	var p: Vector3 = Vector3(origin.x,float(hit["height"]),origin.z)
	var local_n: Vector3 = Basis(Vector3.UP,-turn.y)*(hit["normal"] as Vector3)
	var aligned: Vector3 = Vector3(atan2(local_n.z,local_n.y),turn.y,asin(clampf(-local_n.x,-1.0,1.0)))
	var options: Array[Vector3] = [aligned,turn]
	for offset: Vector2 in [Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3),Vector2(3,3),Vector2(-3,-3),Vector2(3,-3),Vector2(-3,3)]:
		options.append(Vector3(aligned.x+deg_to_rad(offset.x),turn.y,aligned.z+deg_to_rad(offset.y)))
	var last: Dictionary = {}
	for chosen: Vector3 in options:
		var xf: Transform3D = Transform3D(Basis.from_euler(chosen).scaled(scale_value),p)
		if xf.basis.y.normalized().dot(Vector3.UP) < cos(deg_to_rad(35.0)): continue
		_l35_pose_candidates += 1
		if _l35_pose_candidates == 1 or _l35_pose_candidates%128 == 0: _l35_progress("search_candidate")
		var proof: Dictionary = _l35_local_plant_issue(mesh,xf,reach,true)
		last = proof
		if proof.get("passed",false): return {"passed":true,"transform":xf,"turn":chosen,"proof":proof}
	return {"passed":false,"reason":last.get("issue","bounded_up_tilt"),"proof":last}

func _l35_fit_entry(mesh: ArrayMesh,origin: Vector3,turn: Vector3,scale_value: Vector3,reach: float) -> Dictionary:
	var same: Dictionary = _l35_pose_at(mesh,origin,turn,scale_value,reach)
	if same.get("passed",false): same["relocated"] = false;return same
	var side: float = -1.0 if origin.x < _r25_center(origin.z) else 1.0
	for radius: float in PackedFloat64Array([.12,.24,.36,.48,.60]):
		for direction: Vector2 in [Vector2(side,0),Vector2(0,1),Vector2(0,-1),Vector2(-side,0),Vector2(side,1).normalized(),Vector2(side,-1).normalized(),Vector2(-side,1).normalized(),Vector2(-side,-1).normalized()]:
			var candidate: Vector3 = origin+Vector3(direction.x*radius,0,direction.y*radius)
			if candidate.x < _r25_rect.position.x or candidate.x > _r25_rect.end.x or candidate.z < 3.3 or candidate.z > 8.0: continue
			if (candidate.x-_r25_center(candidate.z))*side <= 0.0: continue
			var fitted: Dictionary = _l35_pose_at(mesh,candidate,turn,scale_value,reach)
			if fitted.get("passed",false): fitted["relocated"] = true;return fitted
	return same

func _add_foliage(id: String,mesh: ArrayMesh,origin: Vector3,turn: Vector3,scale_value: Vector3) -> void:
	# The sealedD06 failures are original clustered fairy callers, not R19
	# library/context choices. Extend only this exact resident resource+id.
	var entry_domain: bool = _r25_direct_foliage and not _r22_shrub and origin.z >= 3.3 and origin.z <= 8.0 and origin.x >= _r25_rect.position.x and origin.x <= _r25_rect.end.x
	var legacy: bool = entry_domain and (mesh == _grass_mesh or mesh == _flower_mesh or mesh == _broadleaf_mesh or mesh == _fern_mesh)
	var fairy: bool = entry_domain and _r22_cluster and id == "fairy" and mesh == _glow_mesh
	if not legacy and not fairy:
		super._add_foliage(id,mesh,origin,turn,scale_value);return
	var placement_class: String = "fairy" if fairy else "legacy"
	if fairy: _l35_fairy_callers += 1
	else: _l35_entry_callers += 1
	var guarded_callers: int = _l35_entry_callers+_l35_fairy_callers
	if guarded_callers == 1 or guarded_callers%16 == 0: _l35_progress("entry_fit_begin")
	var reach: float = _r22_reach if _r22_cluster else .17
	var rng_before: String = str(_rng.state)
	var depth: int = _r22_old_query
	_r22_old_query = 0
	var fitted: Dictionary = _l35_fit_entry(mesh,origin,turn,scale_value,reach)
	if not fitted.get("passed",false):
		_l35_pose_rejections.append({"placement_class":placement_class,"id":id,"source_origin":[origin.x,origin.y,origin.z],"original_caller_reach_m":reach,"reason":fitted.get("reason"),"proof":fitted.get("proof",{})})
		_r22_old_query = depth
		_l35_fail("Fresh46 bounded entry pose search exhausted; original caller rejected honestly")
		return
	var selected: Transform3D = fitted["transform"]
	var counts: Dictionary = {}
	for key: String in _foliage_chunks: counts[key] = (_foliage_chunks[key]["transforms"] as Array).size()
	# This scoped legacy entry placer supersedes the parent's sparse-sample
	# reroot only for one already fully guarded append. Original474/context flows
	# elsewhere remain unchanged. Resource/material/yaw/scale/RNG stay original.
	var cluster: bool = _r22_cluster
	var direct: bool = _r25_direct_foliage
	_r22_cluster = false;_r25_direct_foliage = false
	super._add_foliage(id,mesh,selected.origin,fitted["turn"],scale_value)
	_r22_cluster = cluster;_r25_direct_foliage = direct
	_r22_old_query = depth
	var appended: int = 0
	for key: String in _foliage_chunks:
		var chunk: Dictionary = _foliage_chunks[key]
		var transforms: Array = chunk["transforms"]
		for i: int in range(int(counts.get(key,0)),transforms.size()):
			appended += 1
			var actual: Transform3D = transforms[i]
			var actual_mesh: ArrayMesh = chunk["mesh"] as ArrayMesh
			var old_depth: int = _r22_old_query;_r22_old_query = 0
			var proof: Dictionary = _l35_local_plant_issue(actual_mesh,actual,reach)
			_r22_old_query = old_depth
			var displacement: float = Vector2(actual.origin.x-origin.x,actual.origin.z-origin.z).length()
			var binding: bool = displacement <= .600001 and actual_mesh == mesh and chunk["id"] == id and var_to_bytes(actual) == var_to_bytes(selected) and fitted["turn"].y == turn.y and rng_before == str(_rng.state)
			_l35_entry_foliage.append({"placement_class":placement_class,"key":key,"index":i,"mesh":actual_mesh,"transform":actual,"source_origin":origin,"actual_id":chunk["id"],"family":"grass" if actual_mesh == _grass_mesh else "flower" if actual_mesh == _flower_mesh else "broadleaf" if actual_mesh == _broadleaf_mesh else "fern" if actual_mesh == _fern_mesh else "fairy","proof":proof,"caller_reach":reach,"actual_xy_displacement_m":displacement,"relocated":fitted.get("relocated",false),"same_binding_yaw_scale_rng":binding,"reposed":var_to_bytes(actual) != var_to_bytes(Transform3D(Basis.from_euler(turn).scaled(scale_value),origin))})
			if not proof.get("passed",false) or not binding: _l35_fail("Fresh46 actually appended entry pose/support/binding differs")
	if appended != 1: _l35_fail("Fresh46 entry caller must append exactly one original group")
	if guarded_callers == 1 or guarded_callers%16 == 0: _l35_progress("entry_fit_end")

func _rooted_groups_fingerprint() -> String:
	if _l35_consumed: return _l35_fingerprint
	var inherited: String = super._rooted_groups_fingerprint()
	if inherited.is_empty(): return ""
	var render: Array = []
	for record: Dictionary in _l35_render:
		var mesh: ArrayMesh = record["mesh"] as ArrayMesh
		render.append([record["kind"],record["transform"],mesh.surface_get_format(0),mesh.surface_get_arrays(0)])
	var plants: Array = []
	for record: Dictionary in _l35_entry_foliage:
		var mesh: ArrayMesh = record["mesh"] as ArrayMesh
		plants.append([record["actual_id"],record["index"],mesh.surface_get_format(0),mesh.surface_get_arrays(0),record["source_origin"],record["transform"],record["proof"],record["caller_reach"],record["relocated"],record["same_binding_yaw_scale_rng"]])
	return _l35_sha([_L35_REV,FileAccess.get_sha256(_L35_PATH),FileAccess.get_sha256(_L35_DATA),inherited,_r25_faces,_r25_soil_faces,_r25_path_faces,_l48_faces,_l48_labels,_l48_cells,_l35_path_role_codes,_l35_path_q_parameters,_l35_path_parameter_faces,render,plants])

func _r35_encode() -> Dictionary:
	var document: Dictionary = _rooted_groups_bake_document()
	document["schema"] = _L35_SCHEMA
	document["authoring_revision"] = _L35_REV
	return document

func _r35_decode(document: Dictionary) -> Dictionary:
	if document.get("schema","") != _L35_SCHEMA or document.get("authoring_revision","") != _L35_REV or document.get("codec_revision","") != _ROOTED_GROUPS_CODEC_REVISION: return {"ok":false,"error":"Fresh46 schema/revision/codec required"}
	var adapter: Dictionary = document.duplicate()
	adapter["schema"] = "rooted-foreground-groups-v2"
	adapter["authoring_revision"] = _ROOTED_GROUPS_AUTHORING_REVISION
	return _rooted_groups_decode_bake(adapter)

func _l35_verify_roundtrip() -> bool:
	var encoded: Dictionary = _r35_encode()
	var json: JSON = JSON.new()
	var parsed: bool = json.parse(JSON.stringify(encoded)) == OK and json.data is Dictionary
	var decoded: Dictionary = _r35_decode(json.data as Dictionary) if parsed else {"ok":false,"error":"Serialized native JSON roundtrip invalid"}
	var records_exact: bool = decoded.get("ok",false) and var_to_bytes(decoded.get("records")) == var_to_bytes(_rooted_foreground_group_records)
	var stats_exact: bool = decoded.get("ok",false) and var_to_bytes(decoded.get("stats")) == var_to_bytes(_rooted_foreground_group_stats)
	_l35_roundtrip = {"passed":parsed and records_exact and stats_exact,"serialized_parsed_native_decode_ok":decoded.get("ok",false),"all474_typed_records_exact":records_exact,"typed_statistics_exact":stats_exact,"record_count":_rooted_foreground_group_records.size(),"records_sha256":_l35_sha(_rooted_foreground_group_records),"decoded_records_sha256":_l35_sha(decoded.get("records")),"stats_sha256":_l35_sha(_rooted_foreground_group_stats),"decoded_stats_sha256":_l35_sha(decoded.get("stats")),"schema":_L35_SCHEMA,"codec_revision":_ROOTED_GROUPS_CODEC_REVISION,"error":decoded.get("error","")}
	if not _l35_roundtrip["passed"]: _l35_fail("Fresh46 actual serialized/parsed typed native roundtrip differs")
	return bool(_l35_roundtrip["passed"])

func _l35_set_bake(state: Dictionary) -> void:
	state["schema"] = "mush-entrance35-owned-bake-lock/1"
	state["authoring_revision"] = _L35_REV
	state["candidate_sha256"] = FileAccess.get_sha256(_L35_PATH)
	state["descriptor_sha256"] = FileAccess.get_sha256(_L35_DATA)
	_l35_bake = state.duplicate()
	_r27_set_bake(state)

func _l35_refuse(reason: String) -> void:
	_l35_fail(reason)
	_r27_errors.append("Fresh46 bake refused before replay append: "+reason)
	_l35_set_bake({"mode":"refused","reason":reason,"fingerprint":_rooted_groups_fingerprint(),"parent_ground_fingerprint":_r27_parent_ground_fingerprint})

func _create_rooted_ground_groups() -> void:
	_l35_progress("rooted474_enter",true)
	if not _l35_validate_mesh_cache().get("passed",false): _l35_fail("Fresh46 current native mesh/sample cache differs before author/replay")
	if not _l35_errors.is_empty() or not _r25_errors.is_empty() or not _r27_errors.is_empty() or _r25_stair_collision == null:
		_l35_refuse("Fresh46 construction/entry support failed before author/replay");return
	var rng_before: String = str(_rng.state)
	if bool(get_meta("review35_author_mode",false)):
		_l35_progress("rooted474_author_begin",true)
		_generate_rooted_ground_groups()
		_l35_progress("rooted474_author_end",true)
		_l35_fingerprint = _rooted_groups_fingerprint()
		var exact: bool = _l35_verify_roundtrip() and _rooted_foreground_group_records.size() == 474 and rng_before == str(_rng.state)
		_l35_set_bake({"mode":"authored" if exact else "refused","reason":"Standalone35 native generator and actual JSON typed roundtrip; accepted groups append during generation, not a replay","fingerprint":_l35_fingerprint,"parent_ground_fingerprint":_r27_parent_ground_fingerprint,"attempt_count":_rooted_foreground_group_records.size(),"rng_before":rng_before,"rng_after":str(_rng.state),"rng_exact":rng_before == str(_rng.state)})
		if not exact: _l35_refuse("Native35 author/typed codec/RNG failed")
		return
	var path: String = String(get_meta("review35_bake_lock_path",""))
	var pin: String = String(get_meta("review35_bake_lock_sha256",""))
	var decoded: Dictionary = {}
	var error: String = "Fresh46 lock/path/pin missing"
	if path.is_absolute_path() and path == path.simplify_path() and path.begins_with(_L35_DIR) and pin.length() == 64:
		var raw: PackedByteArray = _r22_read(path,16384)
		if not raw.is_empty() and _cap_preview_sha(raw) == pin:
			var json: JSON = JSON.new()
			if json.parse(raw.get_string_from_utf8()) == OK and json.data is Dictionary:
				var lock: Dictionary = json.data
				var payload_path: String = String(lock.get("payload_path",""))
				var payload_sha: String = String(lock.get("payload_sha256",""))
				var fingerprint: String = _rooted_groups_fingerprint()
				if lock.get("schema","") == "mush-entrance35-owned-bake-lock/1" and lock.get("authoring_revision","") == _L35_REV and lock.get("candidate_sha256","") == FileAccess.get_sha256(_L35_PATH) and lock.get("descriptor_sha256","") == FileAccess.get_sha256(_L35_DATA) and lock.get("fingerprint","") == fingerprint and lock.get("parent_ground_fingerprint","") == _r27_parent_ground_fingerprint and lock.get("codec_revision","") == _ROOTED_GROUPS_CODEC_REVISION and _rooted_groups_integer(lock.get("attempt_count"),474,474) and _rooted_groups_integer(lock.get("payload_bytes"),1,_ROOTED_GROUPS_BAKE_LIMIT) and payload_path.is_absolute_path() and payload_path == payload_path.simplify_path() and payload_path.begins_with(_L35_DIR) and payload_sha.length() == 64:
					var payload: PackedByteArray = _r22_read(payload_path,_ROOTED_GROUPS_BAKE_LIMIT)
					if not payload.is_empty() and payload.size() == int(lock["payload_bytes"]) and _cap_preview_sha(payload) == payload_sha:
						var parsed: JSON = JSON.new()
						if parsed.parse(payload.get_string_from_utf8()) == OK and parsed.data is Dictionary:
							decoded = _r35_decode(parsed.data as Dictionary);error = String(decoded.get("error","decode refused"))
						else: error = "Fresh46 payload JSON invalid"
					else: error = "Fresh46 payload bytes/SHA differ"
				else: error = "Fresh46 lock schema/source/data/fingerprint/codec/count/path differs"
			else: error = "Fresh46 lock JSON invalid"
		else: error = "Fresh46 lock exactSHA/length differs"
	if not decoded.get("ok",false): _l35_refuse(error);return
	# Decoder validates the complete fixed native474 table before first replay append.
	var records: Array[Dictionary] = decoded["records"]
	for record: Dictionary in records:
		if record["accepted"]: _add_foliage(record["id"],_foreground_understory_meshes[record["label"]],record["origin"],record["turn"],record["scale"])
	_rooted_foreground_group_records = records
	_rooted_foreground_group_stats = decoded["stats"]
	_l35_fingerprint = _rooted_groups_fingerprint()
	if not _l35_verify_roundtrip() or rng_before != str(_rng.state): _l35_refuse("Replay typed roundtrip/RNG differs");return
	_l35_set_bake({"mode":"baked","reason":"Fresh46 source/data/native fingerprint and complete474 typed payload validated before replay append; no oldR27 lock accepted","fingerprint":_l35_fingerprint,"parent_ground_fingerprint":_r27_parent_ground_fingerprint,"attempt_count":records.size(),"lock_path":path,"lock_sha256":pin,"rng_before":rng_before,"rng_after":str(_rng.state),"rng_exact":rng_before == str(_rng.state)})

func _l35_prefix_exact() -> bool:
	if _l35_prefixes.is_empty(): return false
	for record: Dictionary in _l35_prefixes:
		if var_to_bytes((record["mesh"] as ArrayMesh).get("_surfaces")) != var_to_bytes(record["expected_encoded"]): return false
	return true

func _l35_source_render_exact() -> bool:
	if _l35_render.is_empty(): return false
	for record: Dictionary in _l35_render:
		var mesh: ArrayMesh = record["mesh"]
		if mesh.get_surface_count() != 1 or var_to_bytes(mesh.surface_get_arrays(0)) != var_to_bytes(record["expected_arrays"]): return false
		if (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array() != record["canonical_input_position_bytes"]: return false
	return true

func _l35_expected_batches() -> Dictionary:
	var expected: Dictionary = {}
	for item: Node in find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = item as MeshInstance3D
		if node.material_override != _l35_materials.get("soil") and node.material_override != _l35_materials.get("stone") and node.material_override != _l35_materials.get("stone_light"): continue
		if node.mesh == null or not node.visible: continue
		var xf: Transform3D = global_transform.affine_inverse()*node.global_transform
		var key: String = "%s_%d_%d" % [node.material_override.get_instance_id(),int(floor(xf.origin.x/8)),int(floor(xf.origin.z/8))]
		if not expected.has(key): expected[key] = {"v":PackedVector3Array(),"n":PackedVector3Array(),"u":PackedVector2Array(),"c":PackedColorArray(),"material":node.material_override,"source_paths":[]}
		var entry: Dictionary = expected[key]
		(entry["source_paths"] as Array).append(str(get_path_to(node)))
		var v: PackedVector3Array = entry["v"];var n: PackedVector3Array = entry["n"];var u: PackedVector2Array = entry["u"];var c: PackedColorArray = entry["c"]
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var source_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX];var source_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL];var source_u: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV];var source_c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else source_v.size()
			for j: int in range(count):
				var i: int = indices[j] if not indices.is_empty() else j
				v.append(xf*source_v[i]);n.append((xf.basis.inverse().transposed()*source_n[i]).normalized());u.append(source_u[i]);c.append(source_c[i])
		entry["v"] = v;entry["n"] = n;entry["u"] = u;entry["c"] = c
	return expected

func _l35_batch_check(expected: Dictionary) -> void:
	var rows: Array = []
	var seen: Dictionary = {}
	var passed: bool = not expected.is_empty()
	for item: Node in find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = item as MeshInstance3D
		if node.mesh == null or (node.material_override != _l35_materials.get("soil") and node.material_override != _l35_materials.get("stone") and node.material_override != _l35_materials.get("stone_light")): continue
		var key: String = String(node.name).trim_prefix("Static_")
		if not expected.has(key) or seen.has(key) or node.get_parent().name != "BatchedStaticWorld": passed = false;continue
		seen[key] = true
		var entry: Dictionary = expected[key]
		var reference: ArrayMesh = _array_mesh(entry["v"],entry["n"],entry["u"],entry["c"])
		var expected_arrays: Array = reference.surface_get_arrays(0)
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var strict: bool = node.mesh is ArrayMesh and node.mesh.get_surface_count() == 1 and node.transform == Transform3D.IDENTITY and var_to_bytes(arrays) == var_to_bytes(expected_arrays) and (node.mesh as ArrayMesh).surface_get_format(0) == reference.surface_get_format(0) and node.material_override == entry["material"]
		passed = passed and strict
		_l35_batches.append({"node":node,"mesh":node.mesh,"material":node.material_override,"expected_arrays":expected_arrays,"transform":node.transform,"format":reference.surface_get_format(0),"key":key})
		rows.append({"key":key,"path":str(get_path_to(node)),"passed":strict,"all13_native_encoder_channels_exact":strict,"source_paths":entry["source_paths"],"vertices":(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),"position_sha256":_cap_preview_sha((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array()),"uv_sha256":_cap_preview_sha((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).to_byte_array()),"color_sha256":_cap_preview_sha((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).to_byte_array()),"actual_all13_sha256":_l35_sha(arrays),"expected_native_all13_sha256":_l35_sha(expected_arrays),"format":reference.surface_get_format(0),"raw_transformed_normal_bytes_exact":(arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array() == (entry["n"] as PackedVector3Array).to_byte_array()})
	passed = passed and seen.size() == expected.size() and _l35_source_render_exact() and _l35_prefix_exact() and _l35_materials_exact()
	_l35_batch_report = {"passed":passed,"mode":"actual_original_Source30_batch","expected_buckets":expected.size(),"actual_buckets":seen.size(),"rows":rows,"outside_encoded_prefix_exact":_l35_prefix_exact(),"retained_canonical_source_vertices_exact":_l35_source_render_exact(),"materials_exact":_l35_materials_exact(),"scope":"Selected isolated35 soil/stone/stone_light sources through the unchanged native8m batcher. All13 readback matches the installed original encoder; raw normals are a separate observation. No full-world renderer or performance claim."}
	if not passed: _l35_fail("Actual selected35 final render batch/source/native-prefix proof failed")

func _batch_static_meshes() -> void:
	_l35_capture_collision()
	if not _l35_materials_exact() or not _l35_source_render_exact() or not _l35_prefix_exact(): _l35_fail("Prebatch native source/material/prefix differs");return
	if bool(get_meta("review35_author_mode",false)):
		_l35_batch_report = {"passed":true,"mode":"author_no_render_batch","outside_encoded_prefix_exact":_l35_prefix_exact(),"retained_canonical_source_vertices_exact":_l35_source_render_exact(),"scope":"Standalone author intentionally retains source meshes so actual encode/decode after Ready recomputes fingerprints. No final render batches or inherited cap-material preview evidence observed in author mode."}
		return
	var expected: Dictionary = _l35_expected_batches()
	_l35_fingerprint = _rooted_groups_fingerprint()
	var rng: String = str(_rng.state)
	super._batch_static_meshes()
	_l35_consumed = true
	_l35_batch_check(expected)
	if rng != str(_rng.state): _l35_fail("Original batching changed RNG")

func _l35_current_batches_exact() -> bool:
	if bool(get_meta("review35_author_mode",false)): return not _l35_consumed
	if _l35_batches.is_empty(): return false
	for record: Dictionary in _l35_batches:
		var node: MeshInstance3D = record["node"]
		if node.mesh != record["mesh"] or node.material_override != record["material"] or node.transform != record["transform"] or (node.mesh as ArrayMesh).surface_get_format(0) != record["format"] or var_to_bytes(node.mesh.surface_get_arrays(0)) != var_to_bytes(record["expected_arrays"]): return false
	return true

func _l35_current_collision_exact() -> bool:
	if not _l35_collision.get("passed",false) or _r22_collision == null or _r25_stair_collision == null: return false
	return _l35_collision["west_actual_sha256"] == _cap_preview_sha((_r22_collision.shape as ConcavePolygonShape3D).get_faces().to_byte_array()) and _l35_collision["stair_actual_sha256"] == _cap_preview_sha((_r25_stair_collision.shape as ConcavePolygonShape3D).get_faces().to_byte_array()) and _l35_collision["canonical_sha256"] == _cap_preview_sha(_r25_faces.to_byte_array()) and _l35_collision["soil_sha256"] == _cap_preview_sha(_r25_soil_faces.to_byte_array()) and _l35_collision["path_sha256"] == _cap_preview_sha(_r25_path_faces.to_byte_array()) and _l35_collision.get("solid48_sha256","") == _cap_preview_sha(_l48_faces.to_byte_array()) and _l35_collision["west_transform"] == _l35_sha(global_transform.affine_inverse()*_r22_collision.global_transform) and _l35_collision["stair_transform"] == _l35_sha(global_transform.affine_inverse()*_r25_stair_collision.global_transform)

func _flush_foliage() -> void:
	_l35_progress("flush_foliage_begin",true)
	if not bool(get_meta("review35_author_mode",false)):
		super._flush_foliage();_l35_progress("flush_foliage_end",true);return
	# The unchanged flush can preserve its authored CPU placements on MultiMesh.
	# Headless dummy renderer is not evidence of rendered instance readback. This
	# flag is scoped to this flush only and restored before the batch callback.
	var had: bool = has_meta("portable_export")
	var previous: Variant = get_meta("portable_export",false)
	set_meta("portable_export",true)
	super._flush_foliage()
	if had: set_meta("portable_export",previous)
	else: remove_meta("portable_export")
	_l35_progress("flush_foliage_end",true)

func _l35_foliage_report() -> Dictionary:
	var author: bool = bool(get_meta("review35_author_mode",false))
	var passed: bool = not _l35_entry_foliage.is_empty()
	var pose_exact_all: bool = true
	var guards_all: bool = true
	var bindings_all: bool = true
	var failed_rows: Array = []
	var relocated: int = 0
	var max_displacement: float = 0.0
	var expanded_clearance_groups: int = 0
	var maximum_complete_radius: float = 0.0
	var maximum_derived_clearance: float = 0.0
	var maximum_effective_cap: float = 0.0
	var complete_reach_all: bool = true
	var complete_native_finite_all: bool = true
	var within_effective_cap_all: bool = true
	var original_reach_metadata_all: bool = true
	var derived_at_least_original_all: bool = true
	var complete_reach_group_count: int = 0
	var complete_native_vertex_count_sum: int = 0
	var legacy_groups: int = 0
	var fairy_groups: int = 0
	var caller_class_bindings_all: bool = true
	var reposed: int = 0
	var rows: Array = []
	var families: Dictionary = {}
	var materials: Dictionary = {}
	var shoulders: Dictionary = {"left":{"existing_groups":0,"raised_over100mm_groups":0,"max_root_y":0.0},"right":{"existing_groups":0,"raised_over100mm_groups":0,"max_root_y":0.0}}
	for record: Dictionary in _l35_entry_foliage:
		var placement_class: String = String(record.get("placement_class",""))
		if placement_class == "legacy":
			legacy_groups += 1
			caller_class_bindings_all = caller_class_bindings_all and (record["mesh"] == _grass_mesh or record["mesh"] == _flower_mesh or record["mesh"] == _broadleaf_mesh or record["mesh"] == _fern_mesh)
		elif placement_class == "fairy":
			fairy_groups += 1
			caller_class_bindings_all = caller_class_bindings_all and record["mesh"] == _glow_mesh and record["actual_id"] == "fairy" and String(record.get("family","")) == "fairy" and float(record.get("caller_reach",-1)) == .17
		else: caller_class_bindings_all = false
		var live: MultiMeshInstance3D = get_node_or_null("SpatiallyChunkedFoliage/"+String(record["key"])) as MultiMeshInstance3D
		var present: bool = live != null and live.multimesh != null and live.multimesh.mesh == record["mesh"] and live.multimesh.instance_count > int(record["index"])
		var exact: bool = false
		if author and present:
			var cpu: Variant = live.multimesh.get_meta("portable_authored_instance_transforms",null)
			exact = cpu is Array and (cpu as Array).size() == live.multimesh.instance_count and var_to_bytes(cpu[int(record["index"])]) == var_to_bytes(record["transform"])
		elif present:
			exact = var_to_bytes(live.multimesh.get_instance_transform(int(record["index"]))) == var_to_bytes(record["transform"])
		var proof: Dictionary = _l35_local_plant_issue(record["mesh"],record["transform"],float(record.get("caller_reach",-1)))
		pose_exact_all = pose_exact_all and exact
		guards_all = guards_all and bool(proof["passed"])
		var measured_reach: Dictionary = proof.get("complete_native_projected_reach",{}) as Dictionary
		complete_reach_group_count += 1
		complete_reach_all = complete_reach_all and measured_reach.get("schema","") == "mush-entrance35-complete-projected-reach/1" and bool(measured_reach.get("passed",false))
		complete_native_finite_all = complete_native_finite_all and bool(measured_reach.get("all_transformed_native_vertices_finite",false)) and int(measured_reach.get("complete_native_V_count",0)) > 0 and int(measured_reach.get("native_surface_count",0)) > 0
		within_effective_cap_all = within_effective_cap_all and bool(measured_reach.get("within_effective_cap_plus_original1um_allowance",false))
		original_reach_metadata_all = original_reach_metadata_all and var_to_bytes(measured_reach.get("original_caller_reach_m")) == var_to_bytes(record.get("caller_reach"))
		derived_at_least_original_all = derived_at_least_original_all and float(measured_reach.get("derived_root_clearance_m",0)) >= float(record.get("caller_reach",0))
		complete_native_vertex_count_sum += int(measured_reach.get("complete_native_V_count",0))
		maximum_complete_radius = maxf(maximum_complete_radius,float(measured_reach.get("complete_projected_radius_m",0)))
		maximum_derived_clearance = maxf(maximum_derived_clearance,float(measured_reach.get("derived_root_clearance_m",0)))
		maximum_effective_cap = maxf(maximum_effective_cap,float(measured_reach.get("effective_cap_preserving_larger_original_m",0)))
		if float(measured_reach.get("derived_root_clearance_m",0)) > float(record.get("caller_reach",0)): expanded_clearance_groups += 1
		bindings_all = bindings_all and bool(record.get("same_binding_yaw_scale_rng",false))
		if record.get("relocated",false): relocated += 1
		max_displacement = maxf(max_displacement,float(record.get("actual_xy_displacement_m",0.0)))
		if (not exact or not proof["passed"]) and failed_rows.size() < 8:
			var origin: Vector3 = (record["transform"] as Transform3D).origin
			failed_rows.append({"family":record["family"],"material_id":record["actual_id"],"index":record["index"],"origin":[origin.x,origin.y,origin.z],"pose_exact":exact,"proof":proof})
		passed = passed and exact and proof["passed"]
		if record["reposed"]: reposed += 1
		var xf: Transform3D = record["transform"]
		var id: String = String(record["actual_id"])
		families[String(record["family"])] = int(families.get(String(record["family"]),0))+1
		materials[id] = int(materials.get(id,0))+1
		var side: String = "left" if xf.origin.x < _r25_center(xf.origin.z) else "right"
		var bank: Dictionary = shoulders[side]
		bank["existing_groups"] = int(bank["existing_groups"])+1
		bank["max_root_y"] = maxf(float(bank["max_root_y"]),xf.origin.y)
		if xf.origin.y > float(_r25_base(xf.origin).get("height",xf.origin.y))+.10: bank["raised_over100mm_groups"] = int(bank["raised_over100mm_groups"])+1
		rows.append([id,record["index"],record["transform"],proof])
	var planted: bool = int(shoulders["left"]["raised_over100mm_groups"]) > 0 and int(shoulders["right"]["raised_over100mm_groups"]) > 0
	passed = passed and complete_reach_all and complete_native_finite_all and within_effective_cap_all and original_reach_metadata_all and derived_at_least_original_all and planted and bindings_all and _l35_entry_callers == 240 and legacy_groups == 240 and _l35_fairy_callers > 0 and fairy_groups == _l35_fairy_callers and _l35_entry_foliage.size() == legacy_groups+fairy_groups and caller_class_bindings_all and _l35_pose_rejections.is_empty()
	return {"passed":passed,"original_entry_callers":_l35_entry_callers,"expected_previous_native_callers":240,"legacy_original_callers":_l35_entry_callers,"legacy_existing_groups":legacy_groups,"fairy_original_callers":_l35_fairy_callers,"fairy_existing_groups":fairy_groups,"total_guarded_original_callers":_l35_entry_callers+_l35_fairy_callers,"all_caller_class_resource_bindings_exact":caller_class_bindings_all,"fairy_policy":_l35_data.get("existing_fairy_pose_policy",{}).duplicate(true),"relocated_groups":relocated,"actual_max_xy_displacement_m":max_displacement,"proposed_max_xy_displacement_m":.60,"native_FP32_displacement_rounding_allowance_m":.000001,"pose_candidates_separate_from474":_l35_pose_candidates,"rejected_original_callers":_l35_pose_rejections.size(),"bounded_first8_rejections":_l35_pose_rejections.slice(0,8),"bounded_first8_live_failures":failed_rows,"all_pose_readback_exact":pose_exact_all,"all_support_guards_passed":guards_all,"projected_clearance_policy":_l35_data.get("entry_projected_clearance_policy",{}).duplicate(true),"groups_with_measured_clearance_expansion":expanded_clearance_groups,"maximum_complete_native_projected_radius_m":maximum_complete_radius,"maximum_derived_root_clearance_m":maximum_derived_clearance,"maximum_effective_clearance_cap_m":maximum_effective_cap,"complete_native_projected_reach_groups":complete_reach_group_count,"all_complete_native_projected_reach_passed":complete_reach_all,"all_complete_native_vertices_finite_nonempty":complete_native_finite_all,"all_derived_clearances_within_effective_cap":within_effective_cap_all,"all_original_caller_reach_metadata_exact":original_reach_metadata_all,"all_derived_clearances_at_least_original":derived_at_least_original_all,"complete_native_vertex_counts_sum":complete_native_vertex_count_sum,"same_binding_yaw_scale_rng":bindings_all,"existing_groups":_l35_entry_foliage.size(),"reposed_groups":reposed,"actual_native_family_counts":families,"actual_material_id_counts":materials,"shoulder_occupancy":shoulders,"both_raised_shoulders_have_existing_groups":planted,"transform_evidence_mode":"author_retained_CPU_flush_metadata" if author else "actual_native_MultiMesh_instance_readback","authored_CPU_transform_metadata_exact":pose_exact_all if author else false,"native_MultiMesh_transform_readback_observed":not author,"actual_live_multimesh_transforms_exact":pose_exact_all if not author else false,"native_support_footprint_sha256":_l35_sha(rows),"additional_plant_attempts":0,"scope":"Exactly240 existing legacy-four entry ground-family callers plus the measured existing clustered fairy/_glow_mesh callers in the same entry-root rectangle. Counts are separated; actual native rest transforms and full projected triangle footprints are fitted against native support. Unsafe poses may relocate no farther than.60m on the same side; original resource/material/yaw/scale/RNG and caller-reach metadata are preserved. Root clearance uses the complete actual native mesh radius, capped under the new provisional policy while retaining larger original buffers. Pose readback and guard results are separate. This scoped05 placer replaces sparse-sample parent reroot only for these already guarded appends; no original fixed474 rule changes. Author uses explicitly retained CPU flush metadata because dummy renderer is not rendered-transform evidence. Replay capture demands native readback. Original fixed474 attempt table retains its unchanged generator/domain/guards and separate fresh35 typed bake."}

func _l35_route(z_values: PackedFloat64Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for z: float in z_values:
		var point: Vector3 = Vector3(_r25_center(z),0,z)
		var hit: Dictionary = _r25_surface(point)
		point.y = float(hit.get("height",0))
		result.append(point)
	return result

func _l35_contact_joins() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for original: Dictionary in _l35_joins:
		var row: Dictionary = original.duplicate()
		for side: String in ["left","right"]:
			var outward: float = -1.0 if side == "left" else 1.0
			var edge: Vector3 = row[side+"_path"]
			var start: Vector3 = edge+Vector3(outward*.25,0,0)
			var target: Vector3 = edge-Vector3(outward*.65,0,0)
			var start_hit: Dictionary = _r25_surface(start)
			var target_hit: Dictionary = _r25_surface(target)
			start.y = float(start_hit.get("height",start.y));target.y = float(target_hit.get("height",target.y))
			row[side+"_contact_start"] = start;row[side+"_contact_target"] = target
		row["contact_scope"] = "Designed open .30m soil collar, start .25m outside the shared lane edge, target .65m inside; distant rock flanks and fixed upper pot pockets are not walking-crossing targets"
		result.append(row)
	return result

func get_review35_approach_evidence() -> Dictionary:
	var result: Dictionary = get_review25_approach_evidence().duplicate()
	result["schema"] = "mush-entrance35-native-evidence/1"
	result["native_rect"] = _r25_rect
	result["bounds"] = [_r25_rect.position.x,_r25_rect.end.x,3,11]
	result["west_collision_transform"] = global_transform.affine_inverse()*_r22_collision.global_transform if _r22_collision != null else Transform3D.IDENTITY
	result["stair_collision_transform"] = global_transform.affine_inverse()*_r25_stair_collision.global_transform if _r25_stair_collision != null else Transform3D.IDENTITY
	result["expected_outside_faces"] = _r25_outside(_r25_old_west_faces)
	result["lateral_join_stations"] = _l35_contact_joins()
	result["contact_join_station_indices"] = _l35_contact_indices
	result["center_route"] = _l35_route(PackedFloat64Array([10.5,8,6.2,5.9,5.5,5.1,4.7,4.3,3.9,3.5,3.1]))
	var marker: Vector3 = Vector3(.25,0,5.1);marker.y = float(_r25_surface(marker).get("height",0))
	result["save_marker"] = marker
	result["garden_anchors"] = PackedVector3Array([Vector3(-5.8,0,2.5),Vector3(-4.8,0,3.5),Vector3(-3.8,0,4.5)])
	result["branch_anchors"] = PackedVector3Array([Vector3(-1,0,11),Vector3(4,0,9),Vector3(6.7,0,7.5)])
	result["render_records"] = _l35_render
	result["final_batch_records"] = _l35_batches
	result["batch_provenance"] = _l35_batch_report
	result["quality"] = _l35_quality
	result["semantic_tread_regions"] = _l35_tread_semantics
	result["retained_prefix_records"] = _l35_prefixes
	result["worn_stone_shape"] = _l35_shape_report.duplicate(true)
	result["worn_stone_intrinsic_faces"] = _l35_path_parameter_faces
	result["worn_stone_selected_faces"] = _l35_path_selected_faces
	result["worn_stone_face_labels"] = _l35_path_labels
	result["path_face_role_codes"] = _l35_path_role_codes
	result["path_face_q_parameters"] = _l35_path_q_parameters
	result["walking_path_faces"] = _l35_walking_faces
	result["nonwalking_path_faces"] = _l35_nonwalking_faces
	result["walking_intrinsic_faces"] = _l35_walking_intrinsic
	result["nonwalking_intrinsic_faces"] = _l35_nonwalking_intrinsic
	result["terrace46_recipe"] = _l35_data.get("terrace46_recipe",{}).duplicate(true)
	return result

func _l35_fixed_pot_support() -> Dictionary:
	var rows: Array = []
	var passed: bool = true
	for side: float in PackedFloat64Array([-1,1]):
		for index: int in range(3):
			var point: Vector3 = Vector3(side*(1.25+.38*index),0,3.55+.26*(index%2))
			var baseline: Dictionary = _r25_base(point)
			var actual: Dictionary = _r25_surface(point)
			var exact: bool = not baseline.is_empty() and not actual.is_empty() and absf(float(actual.get("height",INF))-float(baseline.get("height",-INF))) <= .002
			passed = passed and exact
			rows.append({"x":point.x,"z":point.z,"original_native_y":baseline.get("height"),"actual_canonical_y":actual.get("height"),"within2mm":exact})
	return {"passed":passed,"six_fixed_centers":rows,"scope":"Actual native support at the six inherited fixed entrance-pot centers. Their mesh/house positions are not changed by35; no whole-world prop or gameplay anchor audit claim."}

func _l35_boundary_seam_summary() -> Dictionary:
	var summary: Dictionary = _l35_boundary_seam_report.duplicate(true)
	var witnesses: Array = summary.get("all16_input_native_face_identities",[])
	summary["native_face_witness_count"] = witnesses.size()
	summary["native_face_witness_varbytes_sha256"] = _cap_preview_sha(var_to_bytes(witnesses))
	summary.erase("all16_input_native_face_identities")
	return summary

func get_native_boundary_seam_correction_evidence() -> Dictionary:
	# Serialize these bounded16 native face records once, separate from repeated reports.
	return _l35_boundary_seam_report.duplicate(true)

func get_landform35_report() -> Dictionary:
	_l35_progress("landform_report_begin",true)
	var author: bool = bool(get_meta("review35_author_mode",false))
	var mode: String = String(_l35_bake.get("mode",""))
	var foliage: Dictionary = _l35_foliage_report()
	var pots: Dictionary = _l35_fixed_pot_support()
	var native_cache: Dictionary = _l35_validate_mesh_cache()
	var current: bool = _l35_quality.get("passed",false) and _l35_role_binding09_exact() and _l35_shape_report.get("passed",false) and _l35_tread_semantics.get("passed",false) and native_cache.get("passed",false) and _l35_current_collision_exact() and _l35_current_batches_exact() and _l35_source_render_exact() and _l35_materials_exact() and _l35_prefix_exact() and foliage["passed"] and pots["passed"] and _l35_boundary_seam_report.get("passed",false)
	var bake_exact: bool = mode == ("authored" if author else "baked") and _rooted_foreground_group_records.size() == 474 and _l35_bake.get("fingerprint","") == _l35_fingerprint and _l35_bake.get("parent_ground_fingerprint","") == _r27_parent_ground_fingerprint and _l35_bake.get("candidate_sha256","") == FileAccess.get_sha256(_L35_PATH) and _l35_bake.get("descriptor_sha256","") == FileAccess.get_sha256(_L35_DATA)
	var passed: bool = _l35_ready and current and bake_exact and _l35_roundtrip.get("passed",false)
	var errors: Array = _l35_errors.duplicate()
	if not current: errors.append("Current35 native render/support/foliage proof differs")
	if not bake_exact: errors.append("Actual35 author/replay/source fingerprint binding differs")
	var result: Dictionary = {"schema":"mush-entrance35-landform/1","passed":passed,"status":"complete" if passed else "refused","errors":errors,"author_mode":author,"source_sha256":FileAccess.get_sha256(_L35_PATH),"descriptor_sha256":FileAccess.get_sha256(_L35_DATA),"authoring_revision":_L35_REV,"bake":_l35_bake.duplicate(),"native_typed_roundtrip":_l35_roundtrip.duplicate(),"quality":_l35_quality.duplicate(),"semantic_tread_regions":_l35_tread_semantics.duplicate(true),"worn_stone_shape":_l35_shape_report.duplicate(true),"stone_front46":_l35_front09_report.duplicate(true),"solid48":get_solid48_report(),"geometry_contract":"mush-entrance48-solid-evidence/1","obsolete_stone_front09_recipe_claim":false,"native_boundary_seam_correction":_l35_boundary_seam_summary(),"native_collider_authority":_l35_collision.duplicate(),"actual_current_native_support_sources_exact":current,"actual_current_final_render_batch_exact":current if not author else false,"final_render_batch_observed":not author,"material_defaults":_l35_material_resolution.duplicate(true),"selected_stone_palette_forks":{"passed":_l35_materials_exact(),"original_registry_bindings_exact":_l35_registry_exact(),"original_stone_soil_uniforms_byteexact":_l35_materials_exact(),"selected_spec_byteexact":_l35_materials_exact(),"source_palette_shader_uniforms_unchanged":false,"soil_and_shader_unchanged":true,"parameters":_l35_data.get("selected_stone_material_forks",{}).duplicate(true),"scope":"Only private isolated35 stone and stone_light clones receive the four requested parameters; original registry resources/uniforms and selected soil are not set. Selected readback/snapshot is distinct from unchanged-original evidence."},"existing_entry_foliage":foliage,"native_mesh_cache":native_cache,"fixed_pot_native_support":pots,"batch_provenance":_l35_batch_report.duplicate(true),"render_source_count":_l35_render.size(),"superseded_hidden_decorative_count":_l35_hidden.size(),"old591_path_equality_claim":false,"path_native_sha256":_cap_preview_sha(_r25_path_faces.to_byte_array()),"soil_native_sha256":_cap_preview_sha(_r25_soil_faces.to_byte_array()),"lateral_station_count":_l35_joins.size(),"intended_contact_indices":_l35_contact_indices,"art_approved":false,"source_adopted":false,"native_adopted":false,"scope":"Provisional48 short chipped closed slabs replace the old continuous ramp inside the same entry. Floor support and full solids are separate explicit authorities; vertical walls have no upward-heightfield or slope88 claim. Four rises/threshold, current palette, outside native prefixes, soil/collar, six pots/garden, original474 calls/RNG and material/encoder proofs remain required. Tagged auto-step, actual contact, actual screenshots and user visual approval remain separate. No Unreal, performance, adoption or acceptance claim."}
	_l35_progress("landform_report_end",true)
	return result

func get_entrance35_report() -> Dictionary:
	return get_landform35_report()

func get_review35_approach_report() -> Dictionary:
	return get_landform35_report()

func get_review25_approach_report() -> Dictionary:
	var report: Dictionary = super.get_review25_approach_report().duplicate(true)
	report["scope"] = "Inherited entrance reporting container, explicitly superseded by provisional35 canonical path/soil and fresh35 bake. No frozen old591 path equality or original eight-rise geometry claim. House/threshold and outside retained source remain inherited Source30."
	var stats: Dictionary = report.get("stats",{})
	stats["baseline_path_proof"] = _r25_path_proof.duplicate(true)
	stats["left_bank_join"] = {"source":"Fresh46 both-side exact native row joins; originalR25 feather specification is superseded","station_count":_l35_joins.size()}
	var paving: Dictionary = stats.get("visible_original_paving",{})
	paving["underpath_material"] = "Fresh46 canonical soil/stone walking tops; inherited changed thin paving/stair details hidden with resources retained"
	paving["paving_meshes_original"] = true
	paving["physical_top_unchanged"] = false
	paving["paving_scope"] = "Resources retained; this does not claim their changed-lane pieces remain visible or the proposed35 path equals old geometry"
	stats["visible_original_paving"] = paving
	report["stats"] = stats
	report["superseded_by_schema"] = "mush-entrance35-landform/1"
	return report

func get_terrace46_evidence() -> Dictionary:
	return get_stone_front09_evidence()

func _l48_point(q: float,z: float) -> Vector2:
	var left: float = _l48_edge(0,z).x
	var right: float = _l48_edge(1,z).x
	return Vector2(left if q==0.0 else (right if q==1.0 else left+(right-left)*q),z)

func _l48_edge(side: int,z: float) -> Vector3:
	var direction: float = -1.0 if side==0 else 1.0
	var point: Vector3 = Vector3(_r25_center(z)+direction*_r25_width(z),_r25_grade(z),z)
	# New cell boundaries sample the preserved native soil-edge segments, rather
	# than silently replacing their piecewise polygon with an analytic curve.
	for i: int in range(_l48_rows.size()-1):
		var za: float = _l48_rows[i];var zb: float = _l48_rows[i+1]
		if z>za and z<zb:
			var a: Vector3 = Vector3(_r25_center(za)+direction*_r25_width(za),_r25_grade(za),za)
			var b: Vector3 = Vector3(_r25_center(zb)+direction*_r25_width(zb),_r25_grade(zb),zb)
			var t: float = (z-za)/(zb-za)
			point=Vector3(float(a.x)+(float(b.x)-float(a.x))*t,float(a.y)+(float(b.y)-float(a.y))*t,z)
			break
	return point

func _l48_area(poly: PackedVector2Array) -> float:
	var value: float = 0.0
	for i: int in range(poly.size()): value += float(poly[i].x)*float(poly[(i+1)%poly.size()].y)-float(poly[i].y)*float(poly[(i+1)%poly.size()].x)
	return value*.5

func _l48_det(a: Vector2,b: Vector2,c: Vector2) -> float:
	return (float(b.x)-float(a.x))*(float(c.y)-float(a.y))-(float(b.y)-float(a.y))*(float(c.x)-float(a.x))

func _l48_triangles(poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var pending: PackedVector2Array = poly.duplicate()
	var result: Array[PackedVector2Array] = []
	if pending.size()>32 or _l48_area(pending)<0.0:
		_l35_fail("Solid48 bounded polygon winding/cardinality refused");return result
	for attempt: int in range(64):
		if pending.size()<3:return result
		var found: bool = false
		for i: int in range(pending.size()):
			var before: int = (i+pending.size()-1)%pending.size()
			var after: int = (i+1)%pending.size()
			var a: Vector2 = pending[before];var b: Vector2 = pending[i];var c: Vector2 = pending[after]
			if _l48_det(a,b,c)<=0.0:continue
			var contains: bool = false
			for j: int in range(pending.size()):
				if j==before or j==i or j==after:continue
				var p: Vector2 = pending[j]
				if _l48_det(a,b,p)>=0.0 and _l48_det(b,c,p)>=0.0 and _l48_det(c,a,p)>=0.0:contains=true;break
			if contains:continue
			result.append(PackedVector2Array([a,b,c]));pending.remove_at(i);found=true;break
		if not found:
			# An exactly zero projected construction sector has no floor domain.
			# It is not submitted to the inherited emitter; actual vertical walls are separate.
			if _l48_area(pending)==0.0:return result
			_l35_fail("Solid48 simple polygon has no positive ear");return result
	_l35_fail("Solid48 polygon triangulation exceeded64 iterations")
	return result

func _l48_chip_groups(quad: PackedVector2Array,both: bool) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for i: int in range(4):
		var p: Vector2 = quad[i]
		if i==1 or (both and i==3):
			var previous: Vector2 = quad[(i+3)%4];var following: Vector2 = quad[(i+1)%4]
			result.append(PackedVector2Array([p.lerp(previous,.035/p.distance_to(previous)),p.lerp(following,.035/p.distance_to(following))]))
		else:result.append(PackedVector2Array([p]))
	return result

func _l48_inset(poly: PackedVector2Array,distance: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in range(poly.size()):
		var a: Vector2 = poly[(i+poly.size()-1)%poly.size()];var b: Vector2 = poly[i];var c: Vector2 = poly[(i+1)%poly.size()]
		# Double scalar line intersection; only final authored coordinates pack to native Vector2.
		var ux: float = float(b.x)-float(a.x);var uz: float = float(b.y)-float(a.y)
		var vx: float = float(c.x)-float(b.x);var vz: float = float(c.y)-float(b.y)
		var ul: float = sqrt(ux*ux+uz*uz);var vl: float = sqrt(vx*vx+vz*vz)
		var det: float = ux*vz-uz*vx
		if ul<=0.0 or vl<=0.0 or det<=0.0:_l35_fail("Solid48 convex inset corner refused");return PackedVector2Array()
		var xx: float = float(a.x)-uz/ul*distance;var xz: float = float(a.y)+ux/ul*distance
		var yx: float = float(b.x)-vz/vl*distance;var yz: float = float(b.y)+vx/vl*distance
		var t: float = ((yx-xx)*vz-(yz-xz)*vx)/det
		result.append(Vector2(xx+ux*t,xz+uz*t))
	return result

func _l48_label(role: int,tread: int,block: int) -> Dictionary:
	return {"solid48_role":role,"role_code":role,"top":tread if role==0 or role==1 else -1,"nose":tread if role==2 else -1,"joint":role==5 or (block<0 and tread>=0),"material":"soil" if role==4 or role==5 or block<0 else ("stone_light" if role==0 or role==1 else "stone"),"block48":block,"tread48":tread}

func _l48_emit(a: Vector3,b: Vector3,c: Vector3,role: int,tread: int,block: int,floor_domain: bool,body_center: Vector3=Vector3.ZERO) -> void:
	var cross: Vector3 = (c-a).cross(b-a)
	if not a.is_finite() or not b.is_finite() or not c.is_finite() or cross.length_squared()<=1e-18:
		_l35_fail("Solid48 authored face nonfinite or3D degenerate");return
	if floor_domain and cross.y<=0.0:_l35_fail("Solid48 floor domain must be upward");return
	if block>=0 and cross.dot((a+b+c)/3.0-body_center)<=0.0:
		_l35_fail("Solid48 closed slab face does not point outward");return
	var label: Dictionary = _l48_label(role,tread,block)
	label["solid_face_ordinal"]=_l48_labels.size();label["floor_face_ordinal"]=_l48_floor_labels.size() if floor_domain else -1
	_l48_faces.append_array(PackedVector3Array([a,b,c]));_l48_labels.append(label)
	if floor_domain:
		_r25_path_faces.append_array(PackedVector3Array([a,b,c]));_l48_floor_labels.append(label.duplicate())

func _l48_at(p: Vector2,y: float) -> Vector3:
	return Vector3(p.x,y,p.y)

func _l48_bed_height(p: Vector2,level: float) -> float:
	var left: Vector2 = _l48_point(0,p.y);var right: Vector2 = _l48_point(1,p.y)
	if p.x==left.x:return _l48_edge(0,p.y).y
	if p.x==right.x:return _l48_edge(1,p.y).y
	return level-.009

func _l48_bed_polygon(poly: PackedVector2Array,tread: int,level: float,outer_soil: bool) -> void:
	for tri: PackedVector2Array in _l48_triangles(poly):
		var role: int = 4 if outer_soil else 0 # Authored region, before slope measurement.
		_l48_emit(_l48_at(tri[0],_l48_bed_height(tri[0],level)),_l48_at(tri[1],_l48_bed_height(tri[1],level)),_l48_at(tri[2],_l48_bed_height(tri[2],level)),role,tread,-1,true)

func _l48_bed_strip(edge: PackedVector2Array,inner_a: Vector2,inner_b: Vector2,tread: int,level: float,outer_soil: bool) -> void:
	# Endpoint fans retain every native boundary segment without a three-edge sliver.
	# If an inherited rise toe lies inside this outer strip beyond its midpoint,
	# meet at that existing native vertex. A ramp-edge fan then stays on its own
	# side of the toe instead of smearing the old ramp onto the flat landing.
	var split: int = 0;var nearest: float = INF
	var midpoint: Vector2 = (edge[0]+edge[edge.size()-1])*.5
	if outer_soil and tread>=0 and tread<3:
		var toe: float = float(Vector3(0,0,_l35_tread_end(tread+1)+_l46_nose(tread+1)).z)
		if toe>midpoint.y and toe>=minf(edge[0].y,edge[edge.size()-1].y) and toe<=maxf(edge[0].y,edge[edge.size()-1].y):
			var found: bool = false
			for point: Vector2 in edge:
				if point.y==toe:midpoint=point;found=true;break
			if not found:_l35_fail("Solid48 inherited native bed-fan toe missing");return
	for i: int in range(edge.size()):
		var distance: float = edge[i].distance_squared_to(midpoint)
		if distance<nearest:nearest=distance;split=i
	var triangles: Array[PackedVector2Array] = []
	for i: int in range(split):triangles.append(PackedVector2Array([inner_a,edge[i],edge[i+1]]))
	for i: int in range(split,edge.size()-1):triangles.append(PackedVector2Array([inner_b,edge[i],edge[i+1]]))
	triangles.append(PackedVector2Array([inner_a,edge[split],inner_b]))
	for tri: PackedVector2Array in triangles:
		var determinant: float = _l48_det(tri[0],tri[1],tri[2])
		if determinant<0.0:_l35_fail("Solid48 bed-strip partition winding refused");return
		if determinant==0.0:continue # Exact zero floor domain; gap walls are emitted separately.
		var role: int = 4 if outer_soil else 0
		_l48_emit(_l48_at(tri[0],_l48_bed_height(tri[0],level)),_l48_at(tri[1],_l48_bed_height(tri[1],level)),_l48_at(tri[2],_l48_bed_height(tri[2],level)),role,tread,-1,true)

func _l48_slab(poly: PackedVector2Array,tread: int,block: int,level: float,bottom: float,spec: Dictionary) -> void:
	var inner: PackedVector2Array = _l48_inset(poly,float(spec["bevel_inset_m"]))
	if inner.size()!=poly.size():return
	var plane: Array = spec["wear_plane"] as Array
	var top: PackedVector3Array = PackedVector3Array();var edge: PackedVector3Array = PackedVector3Array();var base: PackedVector3Array = PackedVector3Array()
	var center: Vector3 = Vector3.ZERO
	for i: int in range(poly.size()):
		top.append(_l48_at(inner[i],_l52_wear_y(inner[i],level,plane)))
		edge.append(_l48_at(poly[i],_l52_wear_y(poly[i],level,plane)-float(spec["bevel_drop_m"])))
		base.append(_l48_at(poly[i],bottom));center+=_l48_at(poly[i],(level+bottom)*.5)
		if absf(float(top[i].y)-level)>.008:_l35_fail("Stone52 native worn top exceeds8mm");return
	center/=float(poly.size())
	for tri: PackedVector2Array in _l48_triangles(inner):
		_l48_emit(top[inner.find(tri[0])],top[inner.find(tri[1])],top[inner.find(tri[2])],0,tread,block,true,center)
	for i: int in range(poly.size()):
		var j: int = (i+1)%poly.size()
		_l48_emit(edge[i],edge[j],top[j],1,tread,block,true,center);_l48_emit(edge[i],top[j],top[i],1,tread,block,true,center)
		_l48_emit(base[i],base[j],edge[j],2,tread,block,false,center);_l48_emit(base[i],edge[j],edge[i],2,tread,block,false,center)
	for tri: PackedVector2Array in _l48_triangles(poly):
		_l48_emit(base[poly.find(tri[0])],base[poly.find(tri[2])],base[poly.find(tri[1])],3,tread,block,false,center)
	_l48_cells.append({"block":block,"tread":tread,"polygon":poly,"top_polygon":inner,"top_vertices":top,"edge_vertices":edge,"bottom_vertices":base,"bottom_y":bottom,"center":center,"wear_plane":plane.duplicate(),"bevel_inset_m":spec["bevel_inset_m"],"bevel_drop_m":spec["bevel_drop_m"],"native_per_corner_witness_authoritative":true})

func _l52_wear_y(p: Vector2,level: float,plane: Array) -> float:
	return level+float(plane[0])*float(p.x)+float(plane[1])*(float(p.y)-float(plane[2]))+float(plane[3])

func _l52_points(recipe: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for qz: Array in recipe["points_qz"]:
		result.append(_l48_point(float(qz[0]),float(qz[1])))
	return result

func _l48_build(zs: Array[float]) -> void:
	_l48_faces.clear();_l48_labels.clear();_l48_floor_labels.clear();_l48_cells.clear();_r25_path_faces.clear()
	_l48_rows=zs.duplicate()
	for z: float in _l35_split_rows46():
		if not _l48_rows.has(z):_l48_rows.append(z)
	_l48_rows.sort()
	if not _l35_shape_descriptor_exact():_l35_fail("Stone52 explicit descriptor refused before emission");return
	var recipe: Dictionary = _l35_data["solid48_recipe"] as Dictionary
	var points: PackedVector2Array = _l52_points(recipe)
	var levels: PackedFloat64Array = PackedFloat64Array([.13,.29,.43,.60])
	var specs: Array = recipe["slabs"] as Array
	for block: int in range(specs.size()):
		var spec: Dictionary = specs[block] as Dictionary
		var poly: PackedVector2Array = PackedVector2Array()
		for index: Variant in spec["polygon_indices"]:poly.append(points[int(index)])
		var tread: int = int(spec["tread"])
		_l48_slab(poly,tread,block,levels[tread],(.0 if tread==0 else levels[tread-1])-.020,spec)
	# Explicit disjoint authored bed triangles; group and stride order are data authority.
	for region: Dictionary in recipe["bed_regions"]:
		var indices: Array = region["triangles"] as Array
		for off: int in range(0,indices.size(),3):
			_l48_bed_polygon(PackedVector2Array([points[int(indices[off])],points[int(indices[off+1])],points[int(indices[off+2])]]),int(region["tread"]),float(region["level"]),int(region["role"])==4)
	_l48_gap_walls()
	_l35_path_labels=_l48_floor_labels.duplicate(true);_l35_path_selected_faces=_r25_path_faces.duplicate();_l35_path_parameter_faces=_r25_path_faces.duplicate()
	_l35_path_role_codes.clear();_l35_walking_faces.clear();_l35_nonwalking_faces.clear()
	for face: int in range(_l48_floor_labels.size()):
		var role: int = int(_l48_floor_labels[face]["solid48_role"]);_l35_path_role_codes.append(role)
		var part: PackedVector3Array = PackedVector3Array([_r25_path_faces[face*3],_r25_path_faces[face*3+1],_r25_path_faces[face*3+2]])
		if role==0 or role==1:_l35_walking_faces.append_array(part)
		else:_l35_nonwalking_faces.append_array(part)

func _l48_gap_walls() -> void:
	# Explicit ledger endpoints; no fixed-Z test against stone polygon edges.
	var recipe: Dictionary = _l35_data["solid48_recipe"] as Dictionary
	var points: PackedVector2Array = _l52_points(recipe)
	for row: Array in recipe["transition_edges"]:
		var a2: Vector2 = points[int(row[0])];var b2: Vector2 = points[int(row[1])]
		var low: float = float(row[2])-.009;var high: float = float(row[3])-.009;var tread: int = int(row[4])
		var a: Vector3 = _l48_at(a2,low);var b: Vector3 = _l48_at(b2,low)
		var c: Vector3 = _l48_at(b2,high);var d: Vector3 = _l48_at(a2,high)
		_l48_emit(a,b,c,5,tread,-1,false);_l48_emit(a,c,d,5,tread,-1,false)

func _l48_binding_exact() -> bool:
	if _l48_faces.size()%3!=0 or _l48_faces.size()/3!=_l48_labels.size() or _r25_path_faces.size()/3!=_l48_floor_labels.size() or _l35_path_selected_faces.to_byte_array()!=_r25_path_faces.to_byte_array() or var_to_bytes(_l35_path_labels)!=var_to_bytes(_l48_floor_labels) or _l48_cells.size()!=18:return false
	var floor: PackedVector3Array = PackedVector3Array()
	var labels: Array[Dictionary] = []
	for face: int in range(_l48_labels.size()):
		var label: Dictionary = _l48_labels[face]
		if int(label.get("solid_face_ordinal",-1))!=face:return false
		var role: int = int(label.get("solid48_role",-1));var floor_ordinal: int = int(label.get("floor_face_ordinal",-1))
		if role<0 or role>5:return false
		if role==0 or role==1 or role==4:
			if floor_ordinal!=labels.size():return false
			floor.append_array(PackedVector3Array([_l48_faces[face*3],_l48_faces[face*3+1],_l48_faces[face*3+2]]));labels.append(label)
		elif floor_ordinal!=-1:return false
	return floor.to_byte_array()==_r25_path_faces.to_byte_array() and var_to_bytes(labels)==var_to_bytes(_l48_floor_labels) and _l48_closed_cells_exact()

func _l48_closed_cells_exact() -> bool:
	for cell: Dictionary in _l48_cells:
		var block: int = int(cell["block"]);var center: Vector3 = cell["center"]
		var edges: Dictionary = {};var count: int = 0
		for face: int in range(_l48_labels.size()):
			if int(_l48_labels[face].get("block48",-1))!=block:continue
			var tri: PackedVector3Array = PackedVector3Array([_l48_faces[face*3],_l48_faces[face*3+1],_l48_faces[face*3+2]])
			var cross: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0])
			if cross.length_squared()<=1e-18 or cross.dot((tri[0]+tri[1]+tri[2])/3.0-center)<=0.0:return false
			for i: int in range(3):
				var a: String = var_to_bytes(tri[i]).hex_encode();var b: String = var_to_bytes(tri[(i+1)%3]).hex_encode()
				var key: String = a+":"+b if a<b else b+":"+a
				edges[key]=int(edges.get(key,0))+1
			count+=1
		if count!=6*(cell["polygon"] as PackedVector2Array).size()-4:return false
		for key: String in edges:
			if int(edges[key])!=2:return false
	return true

func get_solid48_evidence() -> Dictionary:
	return {"schema":"mush-entrance48-solid-evidence/1","authoring_revision":_L35_REV,"packed_corner_witness_contract":"explicit-ledger52-per-corner-v1","recipe":_l35_data.get("solid48_recipe",{}).duplicate(true),"report":_l48_report.duplicate(true),"floor_support_faces":_r25_path_faces,"floor_roles":_l35_path_role_codes,"floor_labels":_l48_floor_labels.duplicate(true),"solid_faces":_l48_faces,"solid_labels":_l48_labels.duplicate(true),"slabs":_l48_cells.duplicate(true),"floor_sha256":_cap_preview_sha(_r25_path_faces.to_byte_array()),"solid_sha256":_cap_preview_sha(_l48_faces.to_byte_array()),"stair_collision_shape":_r25_stair_collision,"west_collision_shape":_r22_collision,"render_records":_l35_render,"final_batch_records":_l35_batches,"native_rect":_r25_rect,"block_tint_key_relation":"block48 indexes slabs[].block; slabs[].tread supplies tread48, not integer key/8"}

func get_solid48_report() -> Dictionary:
	var report: Dictionary = _l48_report.duplicate(true)
	report["current_ordered_authority_exact"]=_l48_binding_exact() and _l35_current_collision_exact()
	var body: StaticBody3D = _r25_stair_collision.get_parent() as StaticBody3D if _r25_stair_collision!=null else null
	var tagged: bool = body!=null and body.get_meta("entrance48_step_surface",false)==true and body.get_meta("entrance48_step_bounds",Rect2())==_r25_rect
	report["owned_step_surface_tag_and_native_bounds_exact"]=tagged
	report["native_step_bounds"]=_r25_rect
	report["slab_closed_native_edges_and_outward_normals_exact"]=_l48_closed_cells_exact()
	report["passed"]=bool(report.get("passed",false)) and report["current_ordered_authority_exact"] and tagged and bool(report.get("additional_physical_triangle_budget_passed",false))
	return report
