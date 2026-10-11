extends RefCounted
## Offline upper-roof generation only; no resources, world or runtime assignment.
## Retains original connectivity except one three-triangle native local repair.
## Source topology/controls: mac060_paving_upper_row_bent78 and paving_shape.gd.
## paving_shape provenance SHA256: 10541bf76ca5d9b4854aedd88d0481c6cd5ef1ab32e91cd71fbc1f118614fb61.
## The two vertical-cap-only OUTER32 stations16/22 are not roof52 vertices.
const Annulus = preload("res://tools/paving_geometry_predicates.gd")
const SOURCE_ROOF_SHA := "d0613c5f227ca9ce4b9c2d7c709c6ef77294ec230374b23359f8c8d7ca5df76a"
const OUTER32 := "8b1bacbff628dc3e48e1da40ef0440bf3bdf8f3e48e1da40a38f18bf3bdf8f3e48e1da40234b1fbe3bdf8f3e48e1da409777493e3bdf8f3e48e1da40a678d53e3bdf8f3e48e1da402d795b3ff628dc3e48e1da40efe9533f087dc13e0000e040a16f533f46d2bf3eec51e040373d523f6da7bb3eb81ee1405f1c4f3f93d1b03e3333e340ca624e3f7651ae3e14aee340ea2c4d3f9726aa3ee17ae440bfd9463fe37a943ed7a3e840f9b43b3fe17a943e0000f040590d2d3fe17a943e713dfa405a0d2d3fd9cef73d713dfa40cc9d183ed9cef73d713dfa4037ec46bdd9cef73d713dfa408ef8d7bed9cef73d713dfa4087665cbfd9cef73d713dfa4075df81bfd9cef73d713dfa40f482c2bfd9cef73d713dfa40f482c2bfe17a943e713dfa40c2f1babfe17a943e0000f0408dcfb5bfe37a943ed7a3e8401aecb2bf9726aa3ee17ae440255db2bf7651ae3e14aee3403407b2bf93d1b03e3333e3401c91b0bf6da7bb3eb81ee1406e00b0bf46d2bf3eec51e0406cc6afbf087dc13e0000e040"
const CUT_CONTROLS := "f09b48bd3bdf8f3e295cdf40bd8431be3de8103e3333f340"
const SOURCE_FOOT_XZ := ["a0369ebfb81edd40370234bfec51dc4073fc11be6666de4051cf8abec3f5f44045b2cdbed7a3f840c0a888bf0000f840ee98acbf3333f7404ce9aebf52b8f240","45a558bc48e1de406a00d53ec3f5dc40c8ee383fae47dd4076bf313f0000e440c27b0e3f7b14f640801ad33eec51f840286a29bc295cf740319404be3333f340"]
const AREA_LIMIT_M2 := 0.00000001
const WALKING_AUTHORING_DEGREES := 25.0
const MAXIMUM_MAP_POINTS := 2048

func _sha(packet: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(packet)
	return hash.finish().hex_encode()

func _key(p: Vector3) -> String:
	return PackedVector3Array([p]).to_byte_array().hex_encode()

func _xyz(hex: String) -> PackedVector3Array:
	var bytes: PackedByteArray=hex.hex_decode(); var points:=PackedVector3Array()
	if bytes.size()%12!=0 or bytes.hex_encode()!=hex: return points
	for i: int in range(0,bytes.size(),12): points.append(Vector3(bytes.decode_float(i),bytes.decode_float(i+4),bytes.decode_float(i+8)))
	return points if points.to_byte_array()==bytes else PackedVector3Array()

func _xz(points: PackedVector3Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p: Vector3 in points: result.append(Vector2(p.x,p.z))
	return result

func _finish(evidence: Dictionary,context: Dictionary,triangles: PackedVector3Array,controls: PackedVector3Array,reason: String="") -> Dictionary:
	var current: PackedByteArray=(context.source as PackedVector3Array).to_byte_array()
	var map_current: PackedByteArray=var_to_bytes(context.point_map)
	evidence["source_after_sha256"]=_sha(current); evidence["point_map_after_sha256"]=_sha(map_current)
	evidence["source_held_exact"]=current==context.source_before
	evidence["point_map_held_exact"]=map_current==context.map_before
	var passed: bool=reason.is_empty() and evidence.source_held_exact and evidence.point_map_held_exact
	if not passed:
		evidence["failure"]=reason if not reason.is_empty() else "Source or point-map packet changed"
		triangles=PackedVector3Array(); controls=PackedVector3Array()
	evidence["passed"]=passed; evidence["topology_passed"]=passed
	return {"passed":passed,"triangles":triangles,"controls":controls,"evidence":evidence}

func _refuse(evidence: Dictionary,context: Dictionary,reason: String) -> Dictionary:
	return _finish(evidence,context,PackedVector3Array(),PackedVector3Array(),reason)

# Exact native XYZ directed graph, reusing candidate66's edge/cycle contract.
func _boundary(triangles: PackedVector3Array) -> Dictionary:
	if triangles.is_empty() or triangles.size()%3!=0: return {"passed":false,"failure":"Triangle packet cardinality"}
	var directions: Dictionary={}; var points: Dictionary={}
	for i: int in range(0,triangles.size(),3):
		for j: int in range(3):
			var a: Vector3=triangles[i+j]; var b: Vector3=triangles[i+(j+1)%3]
			if not a.is_finite() or not b.is_finite() or _key(a)==_key(b): return {"passed":false,"failure":"Nonfinite or zero native edge"}
			var aa:=_key(a); var bb:=_key(b); var edge:=aa+":"+bb
			points[aa]=a; directions[edge]=int(directions.get(edge,0))+1
	var next: Dictionary={}; var incoming: Dictionary={}; var singles:=0; var pairs:=0
	for edge: String in directions:
		var ends: PackedStringArray=edge.split(":"); var a: String=ends[0]; var b: String=ends[1]
		if directions[edge]!=1: return {"passed":false,"failure":"Repeated native directed edge"}
		if directions.has(b+":"+a): pairs+=1; continue
		if next.has(a) or incoming.has(b): return {"passed":false,"failure":"Branched native boundary"}
		next[a]=b; incoming[b]=true; singles+=1
	if singles!=46 or next.size()!=incoming.size(): return {"passed":false,"failure":"Expected46 roof-only boundary edges","boundary_edges":singles}
	for key: String in next:
		if not incoming.has(key): return {"passed":false,"failure":"Open native cycle"}
	var unseen: Dictionary=next.duplicate(); var loops: Array[PackedVector3Array]=[]
	while not unseen.is_empty():
		var first: String=str(unseen.keys()[0]); var current: String=first; var loop:=PackedVector3Array()
		while unseen.has(current):
			loop.append(points[current]); var following: String=str(unseen[current]); unseen.erase(current); current=following
		if current!=first or loop.size()<3: return {"passed":false,"failure":"Boundary is not disjoint closed cycles"}
		loops.append(loop)
	return {"passed":true,"loops":loops,"boundary_edges":singles,"internal_edge_pairs":int(pairs/2),"unique_vertices":points.size()}

func _edges(loops: Array[PackedVector3Array]) -> Dictionary:
	var result: Dictionary={}
	for loop: PackedVector3Array in loops:
		for i: int in range(loop.size()): result[_key(loop[i])+":"+_key(loop[(i+1)%loop.size()])]=true
	return result

func _rotate_xyz(loop: PackedVector3Array,first: Vector3) -> PackedVector3Array:
	var result:=PackedVector3Array(); var start: int=-1
	for i: int in range(loop.size()):
		if _key(loop[i])==_key(first): start=i; break
	if start<0: return result
	for i: int in range(loop.size()): result.append(loop[(start+i)%loop.size()])
	return result

func _rotate_xz(loop: PackedVector3Array,first: Vector2) -> PackedVector3Array:
	var result:=PackedVector3Array(); var start: int=-1
	for i: int in range(loop.size()):
		if Vector2(loop[i].x,loop[i].z)==first: start=i; break
	if start<0: return result
	for i: int in range(loop.size()): result.append(loop[(start+i)%loop.size()])
	return result

func _sector(outer: PackedVector3Array,a: int,b: int) -> PackedVector3Array:
	var result:=PackedVector3Array(); var i: int=a; result.append(outer[i])
	while i!=b:
		i=(i+1)%outer.size(); result.append(outer[i])
	return result

# Same half-open scan-line span recipe as paving_shape.gd; no nearest-point weld.
func _span(loop: PackedVector3Array,z: float) -> PackedFloat64Array:
	var xs: Array[float]=[]
	for i: int in range(loop.size()):
		var a: Vector3=loop[i]; var b: Vector3=loop[(i+1)%loop.size()]
		if (a.z<=z and z<b.z) or (b.z<=z and z<a.z): xs.append(lerpf(a.x,b.x,(z-a.z)/(b.z-a.z)))
	if xs.size()!=2: return PackedFloat64Array()
	xs.sort(); return PackedFloat64Array(xs)

func _quality(triangles: PackedVector3Array,protected: Dictionary) -> Dictionary:
	var native := Annulus.new(); var rows: Array[Dictionary]=[]
	var walkable:=0.0; var steep:=0.0; var total:=0.0; var maximum:=0.0; var violations:=0
	for i: int in range(0,triangles.size(),3):
		var tri: PackedVector3Array=triangles.slice(i,i+3)
		var normal: Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]); var area: float=native._area(_xz(tri))
		if not normal.is_finite() or not is_finite(area) or area<=0.0 or normal.length_squared()<=1e-18 or not is_finite(normal.length_squared()) or normal.y<=0.0: return {"passed":false,"failure":"Nonfinite/degenerate/non-upward actual roof triangle","face":int(i/3)}
		normal=normal.normalized(); var slope: float=rad_to_deg(acos(clampf(normal.y,-1.0,1.0)))
		if not normal.is_finite() or not is_finite(slope): return {"passed":false,"failure":"Nonfinite native normal/slope"}
		var touches_protected:=false
		for p: Vector3 in tri: touches_protected=touches_protected or protected.has(_key(p))
		var within: bool=slope<=WALKING_AUTHORING_DEGREES
		if within: walkable+=area
		else:
			steep+=area
			if not touches_protected: violations+=1
		total+=area; maximum=maxf(maximum,slope)
		rows.append({"face":int(i/3),"native_XYZ_hex":tri.to_byte_array().hex_encode(),"normal_f32_hex":PackedVector3Array([normal]).to_byte_array().hex_encode(),"slope_degrees":slope,"slope_f64_hex":PackedFloat64Array([slope]).to_byte_array().hex_encode(),"projected_area_m2":area,"within25_degrees":within,"touches_literal_protected_exterior":touches_protected,"interior_25_degree_violation":not within and not touches_protected})
	return {"passed":true,"faces":rows,"projected_area_m2":total,"within25_projected_area_m2":walkable,"over25_projected_area_m2":steep,"maximum_slope_degrees":maximum,"interior_25_degree_violations":violations,"interior_authoring_25_degrees_passed":violations==0,"walking_surface_accepted":false}

func _validate_projected(triangles: PackedVector3Array,outer: PackedVector3Array,holes: Array[PackedVector3Array],source_quality: Dictionary,new_quality: Dictionary) -> Dictionary:
	var native := Annulus.new(); var boundary: Dictionary=_boundary(triangles)
	if not boundary.passed: return boundary
	var expected_loops: Array[PackedVector3Array]=[outer]
	for hole: PackedVector3Array in holes:
		var clockwise: PackedVector3Array=hole.duplicate(); clockwise.reverse(); expected_loops.append(clockwise)
	if _edges(boundary.loops)!=_edges(expected_loops): return {"passed":false,"failure":"Actual outer30/mapped-hole directed boundary differs"}
	var unique: Dictionary={}
	for i: int in range(0,triangles.size(),3):
		for j: int in range(3):
			var a: Vector3=triangles[i+j]; var b: Vector3=triangles[i+(j+1)%3]
			var aa:=_key(a); var bb:=_key(b); var key: String=aa+":"+bb if aa<bb else bb+":"+aa
			unique[key]=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z)])
	var segments: Array=unique.values(); var crossing_checks:=0
	for i: int in range(segments.size()):
		for j: int in range(i+1,segments.size()):
			var a: PackedVector2Array=segments[i]; var b: PackedVector2Array=segments[j]; crossing_checks+=1
			if native._annulus_contact(a[0],a[1],b[0],b[1]) and not native._annulus_only_endpoint(a[0],a[1],b[0],b[1]): return {"passed":false,"failure":"Projected edge crossing/overlap/T-junction"}
	var maximum_overlap:=0.0; var maximum_hole_overlap:=0.0; var triangle_pair_checks:=0; var hole_checks:=0
	var newly_steep_over_source_walkable:=0.0; var steep_region_checks:=0
	for i: int in range(0,triangles.size(),3):
		var tri: PackedVector2Array=_xz(triangles.slice(i,i+3)); var center: Vector2=(tri[0]+tri[1]+tri[2])/3.0
		if not Geometry2D.is_point_in_polygon(center,_xz(outer)): return {"passed":false,"failure":"Actual native centroid outside original outer30"}
		for hole: PackedVector3Array in holes:
			if Geometry2D.is_point_in_polygon(center,_xz(hole)): return {"passed":false,"failure":"Actual native centroid inside mapped hole"}
			for overlap: PackedVector2Array in Geometry2D.intersect_polygons(tri,_xz(hole)):
				var area: float=absf(native._area(overlap)); hole_checks+=1
				if not is_finite(area) or area>AREA_LIMIT_M2: return {"passed":false,"failure":"Actual native triangle/hole overlap"}
				maximum_hole_overlap=maxf(maximum_hole_overlap,area)
		for j: int in range(i+3,triangles.size(),3):
			triangle_pair_checks+=1
			for overlap: PackedVector2Array in Geometry2D.intersect_polygons(tri,_xz(triangles.slice(j,j+3))):
				var area: float=absf(native._area(overlap))
				if not is_finite(area) or area>AREA_LIMIT_M2: return {"passed":false,"failure":"Actual native roof triangles overlap"}
				maximum_overlap=maxf(maximum_overlap,area)
		if not bool(new_quality.faces[int(i/3)].within25_degrees):
			for row: Dictionary in source_quality.faces:
				if not bool(row.within25_degrees): continue
				steep_region_checks+=1
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(tri,_xz(_xyz(str(row.native_XYZ_hex)))):
					var area: float=absf(native._area(overlap))
					if not is_finite(area): return {"passed":false,"failure":"Nonfinite old/new slope-region intersection"}
					newly_steep_over_source_walkable+=area
	var expected_area: float=native._area(_xz(outer))
	for hole: PackedVector3Array in holes: expected_area-=native._area(_xz(hole))
	var delta: float=absf(float(new_quality.projected_area_m2)-expected_area)
	if not is_finite(delta) or delta>AREA_LIMIT_M2: return {"passed":false,"failure":"Native full-roof projected area mismatch","area_delta_m2":delta if is_finite(delta) else null}
	return {"passed":true,"boundary_edges":46,"internal_edge_pairs":boundary.internal_edge_pairs,"unique_vertices":boundary.unique_vertices,"outer30_and_mapped_holes_exact":true,"internal_directed_edges_paired":true,"projected_edge_contact_checks":crossing_checks,"projected_edge_crossings":0,"native_triangle_pair_checks":triangle_pair_checks,"maximum_triangle_overlap_m2":maximum_overlap,"native_hole_overlap_fragments":hole_checks,"maximum_hole_overlap_m2":maximum_hole_overlap,"projected_area_m2":float(new_quality.projected_area_m2),"expected_projected_area_m2":expected_area,"area_delta_m2":delta,"new_steep_over_source_walkable_area_m2":newly_steep_over_source_walkable,"new_steep_over_source_walkable_area_f64_hex":PackedFloat64Array([newly_steep_over_source_walkable]).to_byte_array().hex_encode(),"slope_region_pair_checks":steep_region_checks,"no_new_steep_coverage_over_source_walkable_within_area_limit":newly_steep_over_source_walkable<=AREA_LIMIT_M2,"walking_surface_accepted":false}

# Bound each end segment against every native hole station in its Z interval.
# Piecewise-linear boundaries attain extrema at those stations. The complete
# sector-nesting proof below remains the authority for the entire bent cut.
func _end_control(control: Vector3,endpoint: Vector3,holes: Array[PackedVector3Array]) -> Dictionary:
	var low: float=-INF; var high: float=INF; var rows: Array=[]
	const CLEARANCE_X := .002
	for side: int in range(2):
		for p: Vector3 in holes[side]:
			var t: float=(float(p.z)-endpoint.z)/(float(control.z)-endpoint.z)
			if t<=0.0 or t>1.0: continue
			var bound: float=float(endpoint.x)+(float(p.x)+(CLEARANCE_X if side==0 else -CLEARANCE_X)-endpoint.x)/t
			if side==0: low=maxf(low,bound)
			else: high=minf(high,bound)
			rows.append({"side":side,"station_XYZ_hex":_key(p),"control_X_bound":bound})
	if low>high: return {"passed":false,"failure":"Empty end-cut feasible interval","minimum_X":low,"maximum_X":high}
	var fresh:=control; fresh.x=clampf(control.x,low,high)
	var minimum:=INF
	for side: int in range(2):
		var stations:=holes[side].duplicate()
		var span:=_span(holes[side],control.z)
		if span.size()!=2: return {"passed":false,"failure":"End-control scanline span missing"}
		stations.append(Vector3(span[1 if side==0 else 0],0.0,control.z))
		for p: Vector3 in stations:
			var t: float=(float(p.z)-endpoint.z)/(float(control.z)-endpoint.z)
			if t<=0.0 or t>1.0: continue
			var cut_x: float=float(endpoint.x)+(float(fresh.x)-endpoint.x)*t
			minimum=minf(minimum,cut_x-p.x if side==0 else p.x-cut_x)
	# Read back the float32 control before checking; allow only10nm roundoff.
	return {"passed":fresh.is_finite() and is_finite(minimum) and minimum>=CLEARANCE_X-.00000001,"control":fresh,"evidence":{"initial_X":control.x,"chosen_X":fresh.x,"requested_clearance_X_m":CLEARANCE_X,"minimum_native_clearance_X_m":minimum,"roundoff_allowance_m":.00000001,"constraints":rows}}

func build(source_roof: PackedVector3Array,point_map: Dictionary) -> Dictionary:
	var context: Dictionary={"source":source_roof,"point_map":point_map,"source_before":source_roof.to_byte_array(),"map_before":var_to_bytes(point_map)}
	var evidence: Dictionary={"schema":"mush-upper-roof-generation/1","passed":false,"generation_only":true,"native_geometry_only":true,"world_assignments":0,"resources_created":0,"walking_surface_accepted":false,"art_accepted":false,"performance_measured":false,"source_before_sha256":_sha(context.source_before),"point_map_before_sha256":_sha(context.map_before),"source_face_range":[2387,2439],"source_roof_sha256":SOURCE_ROOF_SHA,"projected_area_limit_m2":AREA_LIMIT_M2,"walking_authoring_limit_degrees":WALKING_AUTHORING_DEGREES,"caps_outside_adapter":true}
	if source_roof.size()!=156 or evidence.source_before_sha256!=SOURCE_ROOF_SHA: return _refuse(evidence,context,"Exact pinned52 roof packet required")
	if point_map.size()>MAXIMUM_MAP_POINTS: return _refuse(evidence,context,"Point map exceeds bounded2048 entries")
	for key: Variant in point_map:
		if not key is String or str(key).length()!=24 or _xyz(str(key)).size()!=1 or typeof(point_map[key])!=TYPE_VECTOR3 or not (point_map[key] as Vector3).is_finite(): return _refuse(evidence,context,"Point map requires exact nativeXYZ hex keys and finite Vector3 values")
	var native := Annulus.new(); var source_graph: Dictionary=_boundary(source_roof)
	evidence["source_graph"]=source_graph.duplicate(true); evidence.source_graph.erase("loops")
	if not source_graph.passed or source_graph.loops.size()!=3 or source_graph.unique_vertices!=48: return _refuse(evidence,context,"Source must have three simple manifold loops and48 vertices")
	var literal_outer: PackedVector3Array=_xyz(OUTER32); var source_controls: PackedVector3Array=_xyz(CUT_CONTROLS)
	var expected_outer:=PackedVector3Array()
	for i: int in range(literal_outer.size()):
		if i!=16 and i!=22: expected_outer.append(literal_outer[i])
	var outer:=PackedVector3Array(); var clockwise_holes: Array[PackedVector3Array]=[]
	for loop: PackedVector3Array in source_graph.loops:
		if not native._annulus_simple(_xz(loop)): return _refuse(evidence,context,"Source projected boundary is not simple")
		var area: float=native._area(_xz(loop))
		if area>0.0:
			if not outer.is_empty() or loop.size()!=30: return _refuse(evidence,context,"Exactly one CCW outer30 required")
			outer=_rotate_xyz(loop,expected_outer[0])
		else:
			if area>=0.0 or loop.size()!=8: return _refuse(evidence,context,"Exactly two clockwise8 holes required")
			clockwise_holes.append(loop)
	if outer.to_byte_array()!=expected_outer.to_byte_array() or clockwise_holes.size()!=2: return _refuse(evidence,context,"Roof outer30 must equal OUTER32 excluding vertical-cap-only16/22")
	for p: Vector3 in literal_outer:
		if point_map.has(_key(p)) and _key(point_map[_key(p)])!=_key(p): return _refuse(evidence,context,"Outer roof/cap station map must remain exact")
	var source_keys: Dictionary={}
	for p: Vector3 in source_roof: source_keys[_key(p)]=true
	for p: Vector3 in source_controls:
		if not source_keys.has(_key(p)) or (point_map.has(_key(p)) and _key(point_map[_key(p)])!=_key(p)): return _refuse(evidence,context,"Both literal source controls must be present and unmapped")
	var holes: Array[PackedVector3Array]=[]; var hole_rows: Array[Dictionary]=[]
	for foot_hex: String in SOURCE_FOOT_XZ:
		var foot_bytes: PackedByteArray=foot_hex.hex_decode(); var first:=Vector2(foot_bytes.decode_float(0),foot_bytes.decode_float(4)); var selected:=PackedVector3Array()
		for old_clockwise: PackedVector3Array in clockwise_holes:
			var ccw: PackedVector3Array=old_clockwise.duplicate(); ccw.reverse(); ccw=_rotate_xz(ccw,first)
			if _xz(ccw).to_byte_array()==foot_bytes: selected=ccw; break
		if selected.size()!=8: return _refuse(evidence,context,"Source holes must bind ordered upper FEET[2/3]")
		var mapped:=PackedVector3Array()
		for p: Vector3 in selected:
			if not point_map.has(_key(p)): return _refuse(evidence,context,"Every native hole station requires explicit point-map correspondence")
			mapped.append(point_map[_key(p)])
		if not native._annulus_nested(_xz(mapped),_xz(outer)): return _refuse(evidence,context,"Mapped hole is not strictly simple CCW inside outer30")
		holes.append(mapped); hole_rows.append({"source_CCW_native_XYZ_hex":selected.to_byte_array().hex_encode(),"mapped_CCW_native_XYZ_hex":mapped.to_byte_array().hex_encode(),"mapped_point_count":8})
	for i: int in range(8):
		for j: int in range(8):
			var left: PackedVector2Array=_xz(holes[0]); var right: PackedVector2Array=_xz(holes[1])
			if native._annulus_contact(left[i],left[(i+1)%8],right[j],right[(j+1)%8]): return _refuse(evidence,context,"Mapped hole boundaries touch or cross")
	if Geometry2D.is_point_in_polygon(_xz(holes[0])[0],_xz(holes[1])) or Geometry2D.is_point_in_polygon(_xz(holes[1])[0],_xz(holes[0])): return _refuse(evidence,context,"Mapped holes overlap or nest")
	var controls:=source_controls.duplicate(); var spans: Array[Dictionary]=[]
	for i: int in range(2):
		var left: PackedFloat64Array=_span(holes[0],controls[i].z); var right: PackedFloat64Array=_span(holes[1],controls[i].z)
		if left.size()!=2 or right.size()!=2 or not left[1]<right[0]: return _refuse(evidence,context,"Both mapped hole spans and a strict control gap required")
		var p: Vector3=controls[i]; p.x=(left[1]+right[0])*.5; controls[i]=p
		if not p.is_finite() or not float(p.x)>left[1] or not float(p.x)<right[0]: return _refuse(evidence,context,"Native midpoint control must remain strictly inside gap")
		spans.append({"control":i,"left_span_f64_hex":left.to_byte_array().hex_encode(),"right_span_f64_hex":right.to_byte_array().hex_encode(),"gap_m":right[0]-left[1],"source_native_XYZ_hex":_key(source_controls[i]),"candidate_native_XYZ_hex":_key(p),"YZ_held_exact":PackedVector2Array([Vector2(p.y,p.z)]).to_byte_array()==PackedVector2Array([Vector2(source_controls[i].y,source_controls[i].z)]).to_byte_array()})
	var end_fit: Array=[]
	for i: int in range(2):
		var fit: Dictionary=_end_control(controls[i],outer[3 if i==0 else 17],holes)
		if not fit.passed: return _refuse(evidence,context,"No bounded end-cut clearance interval")
		controls[i]=fit.control; end_fit.append(fit.evidence)
		spans[i]["initial_midpoint_native_XYZ_hex"]=spans[i].candidate_native_XYZ_hex
		spans[i]["candidate_native_XYZ_hex"]=_key(controls[i])
	evidence["end_cut_constraint_fit"]=end_fit
	var a:=3; var b:=17
	if _key(outer[a])!=_key(literal_outer[3]) or _key(outer[b])!=_key(literal_outer[18]): return _refuse(evidence,context,"Exact OUTER32[3/18] cut endpoints required")
	var x: PackedVector3Array=_sector(outer,a,b); var y: PackedVector3Array=_sector(outer,b,a); var reverse_controls: PackedVector3Array=controls.duplicate(); reverse_controls.reverse(); x.append_array(reverse_controls); y.append_array(controls)
	var sectors: Array[PackedVector3Array]=[x,y]; var assignments:=PackedInt32Array(); var matrix: Array=[]
	for sector: PackedVector3Array in sectors:
		if not native._annulus_simple(_xz(sector)) or native._area(_xz(sector))<=0.0: return _refuse(evidence,context,"Actual bent sector must remain simple and positive")
		var row: Array[bool]=[]
		for hole: PackedVector3Array in holes: row.append(native._annulus_nested(_xz(hole),_xz(sector)))
		matrix.append(row)
		if row[0]==row[1]: return _refuse(evidence,context,"Exactly one mapped hole per actual bent sector")
		assignments.append(0 if row[0] else 1)
	if x.size()!=17 or y.size()!=19 or assignments[0]==assignments[1] or absf(native._area(_xz(x))+native._area(_xz(y))-native._area(_xz(outer)))>AREA_LIMIT_M2: return _refuse(evidence,context,"Complete17/19 bent sectors with distinct holes required")
	evidence.merge({"outer30_native_XYZ_hex":outer.to_byte_array().hex_encode(),"outer32_cap_only_indices":[16,22],"holes":hole_rows,"source_controls_native_XYZ_hex":source_controls.to_byte_array().hex_encode(),"controls_native_XYZ_hex":controls.to_byte_array().hex_encode(),"control_spans":spans,"cut_OUTER32_indices":[3,18],"cut_roof_outer_indices":[a,b],"sector_hole_matrix":matrix,"sector_hole_assignments":Array(assignments),"sector_native_XYZ_hex":[x.to_byte_array().hex_encode(),y.to_byte_array().hex_encode()]},true)
	var mapped: Dictionary=point_map.duplicate()
	for i: int in range(2): mapped[_key(source_controls[i])]=controls[i]
	var triangles:=PackedVector3Array()
	for p: Vector3 in source_roof: triangles.append(mapped.get(_key(p),p))
	evidence["connectivity_recipe"]="Retain native source face slots; refit both controls as well as hole stations."
	# The narrowed front contour folds source faces45/47. Include adjacent44
	# to form their complete simple five-station domain and retain its boundary.
	var polygon:=PackedVector3Array([triangles[45*3],triangles[45*3+1],triangles[45*3+2],triangles[47*3],triangles[44*3+1]])
	if _key(triangles[47*3+1])!=_key(polygon[0]) or _key(triangles[47*3+2])!=_key(polygon[2]) or _key(triangles[44*3])!=_key(polygon[3]) or _key(triangles[44*3+2])!=_key(polygon[0]) or not native._annulus_simple(_xz(polygon)) or native._area(_xz(polygon))<=0.0: return _refuse(evidence,context,"Exact positive simple three-face local patch required")
	var local_indices:=Geometry2D.triangulate_polygon(_xz(polygon))
	if local_indices.size()!=9: return _refuse(evidence,context,"Three native local replacement triangles required")
	var patch:=PackedVector3Array()
	for index: int in local_indices: patch.append(polygon[index])
	var patch_faces: Array[int]=[44,45,47]
	for face: int in range(3):
		for corner: int in range(3): triangles[patch_faces[face]*3+corner]=patch[face*3+corner]
	evidence["original_face_connectivity_retained"]=false
	evidence["local_native_retriangulation"]={"roof_faces":patch_faces,"native_input_XYZ_hex":polygon.to_byte_array().hex_encode(),"native_indices_hex":local_indices.to_byte_array().hex_encode(),"replacement_XYZ_hex":patch.to_byte_array().hex_encode(),"all_other_faces_point_mapped_in_place":true}
	if triangles.size()!=156: return _refuse(evidence,context,"Exactly52 actual roof triangles required")
	# Same original25 protected exterior stations; exclude five lowered front stations.
	var protected: Dictionary={}
	for i: int in range(outer.size()):
		if i<16 or i>20: protected[_key(outer[i])]=true
	var old_quality: Dictionary=_quality(source_roof,protected); var new_quality: Dictionary=_quality(triangles,protected)
	evidence["source_quality"]=old_quality; evidence["candidate_quality"]=new_quality
	if not old_quality.passed or not new_quality.passed: return _refuse(evidence,context,"Actual native roof winding/finite quality refused")
	var topology: Dictionary=_validate_projected(triangles,outer,holes,old_quality,new_quality); evidence["topology"]=topology
	if not topology.passed: return _refuse(evidence,context,str(topology.failure))
	evidence["protected_exterior_station_count"]=protected.size()
	evidence["interior_authoring_25_degrees_passed"]=new_quality.interior_authoring_25_degrees_passed
	evidence["new_steep_coverage_requires_independent_authoring_review"]=not topology.no_new_steep_coverage_over_source_walkable_within_area_limit
	evidence["candidate_native_XYZ_hex"]=triangles.to_byte_array().hex_encode(); evidence["candidate_sha256"]=_sha(triangles.to_byte_array())
	evidence["slope_violations_do_not_change_topology_result"]=true
	return _finish(evidence,context,triangles,controls)
