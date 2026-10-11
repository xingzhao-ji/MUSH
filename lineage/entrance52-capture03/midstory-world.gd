extends "res://lineage/entrance52-capture03/motion-world.gd"

# Detached proposal: separate added nodes, no inherited generator or bake edits.
# This source is not a native placement, rendered appearance or approval receipt.
const _S45_SOURCE: String = "res://lineage/entrance52-capture03/midstory-world.gd"
const _S45_DESCRIPTOR: String = "res://lineage/entrance52-capture03/midstory-descriptor.json"
const _S45_PARENT: String = "res://lineage/entrance52-capture03/motion-world.gd"
const _S45_ROOT_GAP: float = 0.002
const _S45_ROOT_GAP_LIMIT: float = 0.004
const _S45_CLIP_EPSILON: float = 0.0000001
const _S45_AREA_ABSOLUTE: float = 0.0000001
const _S45_AREA_RELATIVE: float = 0.00001
const _S45_WIND_BOUND: float = 0.008
const _S45_ADDED_NODE_COUNT: int = 36
var _s45_data: Dictionary = {}
var _s45_group: Node3D
var _s45_rows: Array[Dictionary] = []
var _s45_floor_sources: Array[Dictionary] = []
var _s45_floor_faces: PackedVector3Array = PackedVector3Array()
var _s45_floor_cells: Dictionary = {}
var _s45_floor_exclusions: Array[RID] = []
var _s45_visual_obstacles: Array[AABB] = []
var _s45_visual_sources: Array[Dictionary] = []
var _s45_materials: Dictionary = {}
var _s45_errors: Array[String] = []
var _s45_rng: String = ""
var _s45_rooted_sha: String = ""
var _s45_registry: Dictionary = {}
var _s45_built: bool = false
var _s45_physics_origin: int = 0
var _s45_native: Dictionary = {"passed":false,"performed":false}
var _s45_report: Dictionary = {"passed":false,"status":"not_constructed"}

func _s45_fail(message: String) -> void:
	if not _s45_errors.has(message): _s45_errors.append(message)

func _ready() -> void:
	super._ready()
	_s45_rng = str(_rng.state)
	_s45_rooted_sha = _cap_preview_sha(var_to_bytes(_rooted_foreground_group_records))
	for key: String in _materials: _s45_registry[key] = _materials[key]
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_S45_DESCRIPTOR)) != OK or not parser.data is Dictionary:
		_s45_fail("Descriptor parse refused");return
	_s45_data = parser.data as Dictionary
	if _s45_data.get("schema") != "mush-midstory45-proposal/1" or _s45_data.get("provisional") != true or _s45_data.get("parent_sha256") != FileAccess.get_sha256(_S45_PARENT):
		_s45_fail("Descriptor schema/proposal/exact parent binding refused");return
	var groups: Array = _s45_data.get("groups",[])
	if groups.size() != 3: _s45_fail("Exactly three bounded authored groups required");return
	if global_transform != Transform3D.IDENTITY: _s45_fail("This proposal requires the existing identity world frame");return
	if not _s45_cache_floor(): return
	_s45_cache_visual_obstacles(groups)
	_s45_group = Node3D.new()
	_s45_group.name = "ProposedMidstory45"
	add_child(_s45_group)
	for group: Dictionary in groups:
		if not _s45_build_group(group): break
	_s45_built = _s45_rows.size() == _S45_ADDED_NODE_COUNT and _s45_errors.is_empty()
	_s45_physics_origin = Engine.get_physics_frames()
	_s45_native = _s45_native_geometry_proof()
	if not _s45_native.get("passed",false): _s45_fail("Separate added-node native geometry admission refused")
	_s45_apply_wind()

func _s45_cache_floor() -> bool:
	var terrain: Node3D = get_node_or_null("GroundAndPaths") as Node3D
	if terrain == null: _s45_fail("Actual GroundAndPaths unavailable");return false
	var inverse_world: Transform3D = global_transform.affine_inverse()
	for child: Node in terrain.get_children():
		var body: StaticBody3D = child as StaticBody3D
		if body == null or (body.collision_layer & 1) == 0: continue
		for possible_shape: Node in body.get_children():
			var shape: CollisionShape3D = possible_shape as CollisionShape3D
			if shape == null or shape.disabled or not shape.shape is ConcavePolygonShape3D: continue
			var faces: PackedVector3Array = (shape.shape as ConcavePolygonShape3D).get_faces()
			if faces.is_empty() or faces.size()%3 != 0: _s45_fail("Native floor triangle stream invalid");return false
			var xf: Transform3D = inverse_world*shape.global_transform
			_s45_floor_sources.append({"node":shape,"resource":shape.shape,"body":body,"body_RID":body.get_rid(),"body_collision_layer":body.collision_layer,"body_collision_mask":body.collision_mask,"terrain":terrain,"transform":xf,"faces_sha256":_cap_preview_sha(faces.to_byte_array())})
			if not _s45_floor_exclusions.has(body.get_rid()): _s45_floor_exclusions.append(body.get_rid())
			for i: int in range(0,faces.size(),3):
				var a: Vector3 = xf*faces[i]
				var b: Vector3 = xf*faces[i+1]
				var c: Vector3 = xf*faces[i+2]
				if not a.is_finite() or not b.is_finite() or not c.is_finite(): _s45_fail("Nonfinite native floor");return false
				if absf(_s45_cross(Vector2(b.x-a.x,b.z-a.z),Vector2(c.x-a.x,c.z-a.z))) <= 0.000000000001: continue
				var ordinal: int = _s45_floor_faces.size()/3
				_s45_floor_faces.append_array(PackedVector3Array([a,b,c]))
				var bounds: AABB = AABB(a,Vector3.ZERO).expand(b).expand(c)
				for x: int in range(int(floor(bounds.position.x)),int(floor(bounds.end.x))+1):
					for z: int in range(int(floor(bounds.position.z)),int(floor(bounds.end.z))+1):
						var key: Vector2i = Vector2i(x,z)
						var indices: PackedInt32Array = _s45_floor_cells.get(key,PackedInt32Array())
						indices.append(ordinal);_s45_floor_cells[key] = indices
	if _s45_floor_sources.is_empty(): _s45_fail("No actual direct terrain floor collision sources");return false
	return true

func _s45_candidates(bounds: AABB) -> PackedInt32Array:
	var unique: Dictionary = {}
	for x: int in range(int(floor(bounds.position.x)),int(floor(bounds.end.x))+1):
		for z: int in range(int(floor(bounds.position.z)),int(floor(bounds.end.z))+1):
			for ordinal: int in _s45_floor_cells.get(Vector2i(x,z),PackedInt32Array()): unique[ordinal] = true
	var result: PackedInt32Array = PackedInt32Array()
	for ordinal: int in unique: result.append(ordinal)
	result.sort()
	return result

func _s45_cross(a: Vector2,b: Vector2) -> float:
	return a.x*b.y-a.y*b.x

func _s45_floor_height(p: Vector3,a: Vector3,b: Vector3,c: Vector3) -> float:
	var ab: Vector2 = Vector2(b.x-a.x,b.z-a.z)
	var ac: Vector2 = Vector2(c.x-a.x,c.z-a.z)
	var ap: Vector2 = Vector2(p.x-a.x,p.z-a.z)
	var divisor: float = _s45_cross(ab,ac)
	return a.y+_s45_cross(ap,ac)/divisor*(b.y-a.y)+_s45_cross(ab,ap)/divisor*(c.y-a.y)

func _s45_support(p: Vector3) -> Dictionary:
	var highest: float = -INF
	var result: Dictionary = {}
	for ordinal: int in _s45_floor_cells.get(Vector2i(int(floor(p.x)),int(floor(p.z))),PackedInt32Array()):
		var i: int = ordinal*3
		var a: Vector3 = _s45_floor_faces[i]
		var b: Vector3 = _s45_floor_faces[i+1]
		var c: Vector3 = _s45_floor_faces[i+2]
		var ab: Vector2 = Vector2(b.x-a.x,b.z-a.z)
		var ac: Vector2 = Vector2(c.x-a.x,c.z-a.z)
		var ap: Vector2 = Vector2(p.x-a.x,p.z-a.z)
		var divisor: float = _s45_cross(ab,ac)
		var u: float = _s45_cross(ap,ac)/divisor
		var v: float = _s45_cross(ab,ap)/divisor
		if u < -_S45_CLIP_EPSILON or v < -_S45_CLIP_EPSILON or u+v > 1.0+_S45_CLIP_EPSILON: continue
		var height: float = a.y+u*(b.y-a.y)+v*(c.y-a.y)
		if height > highest:
			highest = height
			var normal: Vector3 = (b-a).cross(c-a).normalized()
			if normal.y < 0.0: normal = -normal
			result = {"height":height,"normal":normal,"floor_ordinal":ordinal}
	return result

func _s45_cache_visual_obstacles(groups: Array) -> void:
	# Selected original-registry static surfaces, including matching noncolliding rocks.
	# Triangle AABB overlap is conservative: an ambiguous near miss refuses.
	var solids: Array = []
	for key: String in ["stone","stone_light","bark","wood","wood_light","wall","floor"]:
		if _materials.has(key): solids.append(_materials[key])
	var regions: Array[AABB] = []
	for group: Dictionary in groups:
		var center: Array = group.get("center_xz",[])
		if center.size() != 2: continue
		regions.append(AABB(Vector3(float(center[0])-2.0,-1.0,float(center[1])-2.0),Vector3(4.0,4.0,4.0)))
	var inverse_world: Transform3D = global_transform.affine_inverse()
	for child: Node in find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = child as MeshInstance3D
		if node.mesh == null or not node.visible or not solids.has(node.material_override) or not node.mesh is ArrayMesh: continue
		var xf: Transform3D = inverse_world*node.global_transform
		var mesh: ArrayMesh = node.mesh as ArrayMesh
		var relevant: bool = false
		for surface: int in range(mesh.get_surface_count()):
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for i: int in range(0,count,3):
				var a: Vector3 = xf*vertices[indices[i] if not indices.is_empty() else i]
				var b: Vector3 = xf*vertices[indices[i+1] if not indices.is_empty() else i+1]
				var c: Vector3 = xf*vertices[indices[i+2] if not indices.is_empty() else i+2]
				var bounds: AABB = AABB(a,Vector3.ZERO).expand(b).expand(c)
				for region: AABB in regions:
					if _s45_closed_overlap(region,bounds):
						_s45_visual_obstacles.append(bounds);relevant = true;break
		if relevant: _s45_visual_sources.append({"node":node,"mesh":mesh,"mesh_sha256":_m37_mesh_sha(mesh),"transform":node.global_transform,"material":node.material_override,"visible":node.visible})

func _s45_closed_overlap(a: AABB,b: AABB) -> bool:
	# Closed intervals: exact boundary contact also refuses this conservative gate.
	return a.position.x <= b.end.x and a.end.x >= b.position.x and a.position.y <= b.end.y and a.end.y >= b.position.y and a.position.z <= b.end.z and a.end.z >= b.position.z

func _s45_vec3(value: Variant) -> Vector3:
	if not value is Array or (value as Array).size() != 3: return Vector3(INF,INF,INF)
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _s45_build_group(group: Dictionary) -> bool:
	var center: Array = group.get("center_xz",[])
	var parts: Array = group.get("parts",[])
	if center.size() != 2 or parts.size() != 9: _s45_fail("Finite center and nine authored foliage parts per group required");return false
	var center_point: Vector3 = Vector3(float(center[0]),0.0,float(center[1]))
	if not center_point.is_finite() or center_point.x < -22.0 or center_point.x > 23.0 or center_point.z < -21.0 or center_point.z > 27.0:
		_s45_fail("Authored group exceeds inherited clearing bounds");return false
	var part_index: int = 0
	for part: Dictionary in parts:
		var offset: Vector3 = _s45_vec3(part.get("offset"))
		var scale_value: Vector3 = _s45_vec3(part.get("scale"))
		var yaw: float = float(part.get("yaw",INF))
		var kind: String = str(part.get("kind",""))
		var material_id: String = str(part.get("material",""))
		if not offset.is_finite() or not scale_value.is_finite() or not is_finite(yaw) or scale_value.x <= 0.0 or scale_value.y <= 0.0 or scale_value.z <= 0.0 or offset.length() > 1.5 or scale_value.length() > 3.0:
			_s45_fail("Authored finite transform refused");return false
		if not ["leaf_volume","fern","broadleaf"].has(kind) or not ["leaf","leaf_dark","leaf_gold"].has(material_id): _s45_fail("Unlicensed/new/unrecognized resource selection refused");return false
		var point: Vector3 = center_point+Vector3(offset.x,0.0,offset.z)
		var support: Dictionary = _s45_support(point)
		if support.is_empty(): _s45_fail("Authored part has no actual native floor support");return false
		point.y = float(support.height)+_S45_ROOT_GAP
		var mesh: ArrayMesh = _canopy_far_mesh if kind == "leaf_volume" else (_fern_mesh if kind == "fern" else _broadleaf_mesh)
		var orientation: Basis = Basis(Vector3.UP,yaw) if kind == "leaf_volume" else _review20_surface_basis(support.normal,yaw)
		var basis_value: Basis = orientation*Basis.from_scale(scale_value)
		var pose: Transform3D = Transform3D(basis_value,Vector3(0,offset.y,0))
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 1
		mm.set_instance_transform(0,pose)
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = str(group.get("id","group"))+"_"+kind+"_"+str(part_index)
		node.position = point
		node.multimesh = mm
		node.material_override = _s45_leaf_material(material_id) if kind == "leaf_volume" else (_materials[material_id] as Material)
		if kind == "leaf_volume":
			var margin: PackedByteArray = PackedFloat32Array([_s45_shader_bound()*sqrt(3.0)]).to_byte_array()
			if margin.decode_float(0) < _s45_shader_bound()*sqrt(3.0): margin.encode_u32(0,margin.decode_u32(0)+1)
			node.extra_cull_margin = margin.decode_float(0)
		_s45_group.add_child(node)
		_s45_record(node,kind,point,_s45_shader_bound() if kind == "leaf_volume" else 0.0)
		if kind == "leaf_volume": _s45_build_stem(point,offset.y,str(group.get("id","group"))+"_stem_"+str(part_index))
		part_index += 1
	return true

func _s45_leaf_material(material_id: String) -> ShaderMaterial:
	if _s45_materials.has(material_id): return _s45_materials[material_id].selected as ShaderMaterial
	var original: ShaderMaterial = _materials[material_id] as ShaderMaterial
	var realization: Dictionary = _m37_prime(original,_M37_LEAF_KEYS)
	var selected: ShaderMaterial = original.duplicate(false) as ShaderMaterial
	selected.shader = _M37_WIND_SHADER
	var exact: bool = realization.get("passed",false) and selected != original and selected.render_priority == original.render_priority and selected.next_pass == original.next_pass and var_to_bytes(_m37_parameters(original,_M37_LEAF_KEYS)) == var_to_bytes(_m37_parameters(selected,_M37_LEAF_KEYS))
	if not exact: _s45_fail("Owned leaf wind fork changes inherited parameters")
	_s45_materials[material_id] = {"original":original,"selected":selected,"realization":realization,"initial_exact":exact}
	return selected

func _s45_build_stem(point: Vector3,height: float,node_name: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = node_name+"_root"
	root.position = point
	_s45_group.add_child(root)
	var node: MeshInstance3D = _tube([Vector3.ZERO,Vector3(.025,height*.46,-.018),Vector3(0,height,0)],.038,.012,_materials["bark"] as Material,root,7)
	node.name = node_name
	# The owned tube's first ring follows actual native soil rather than clipping it.
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in range(vertices.size()):
		if vertices[i].y > .04: continue
		var hit: Dictionary = _s45_support(point+vertices[i])
		if hit.is_empty(): _s45_fail("Owned stem foot has no actual native support");continue
		vertices[i].y = float(hit.height)+_S45_ROOT_GAP-point.y
	var normals: PackedVector3Array = PackedVector3Array()
	for i: int in range(0,vertices.size(),3):
		var normal: Vector3 = (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		normals.append_array(PackedVector3Array([normal,normal,normal]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var owned: ArrayMesh = ArrayMesh.new()
	owned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	node.mesh = owned
	_s45_record(node,"owned_stem",point,0.0)

func _s45_record(node: GeometryInstance3D,kind: String,root: Vector3,wind: float) -> void:
	var mesh: Mesh = (node as MultiMeshInstance3D).multimesh.mesh if node is MultiMeshInstance3D else (node as MeshInstance3D).mesh
	var mm_pose: Transform3D = (node as MultiMeshInstance3D).multimesh.get_instance_transform(0) if node is MultiMeshInstance3D else Transform3D.IDENTITY
	var inverse_basis: Basis = (node.global_basis*mm_pose.basis).inverse()
	var inverse_norm: float = sqrt(inverse_basis.x.length_squared()+inverse_basis.y.length_squared()+inverse_basis.z.length_squared())
	var jacobian_lower: float = 1.0-1.2*wind*inverse_norm
	if not is_finite(jacobian_lower) or jacobian_lower <= .5: _s45_fail("Added native transform lacks a positive analytic wind Jacobian")
	_s45_rows.append({"node":node,"kind":kind,"root":root,"mesh":mesh,"mesh_sha256":_m37_mesh_sha(mesh),"transform":node.transform,"global_transform":node.global_transform,"mm_pose":mm_pose,"material":node.material_override,"wind_bound_m":wind,"wind_jacobian_lower_bound":jacobian_lower,"extra_cull_margin":node.extra_cull_margin,"cast_shadow":node.cast_shadow})

func _s45_shader_bound() -> float:
	# Certify the GPU uniform's actual binary32 maximum, including its rounding.
	return PackedFloat32Array([_S45_WIND_BOUND]).to_byte_array().decode_float(0)

func _s45_triangle_clip(poly: Array[Vector3],a: Vector3,b: Vector3,c: Vector3) -> Array[Vector3]:
	var floor_points: Array[Vector3] = [a,b,c]
	var orientation: float = signf(_s45_cross(Vector2(b.x-a.x,b.z-a.z),Vector2(c.x-a.x,c.z-a.z)))
	for edge: int in range(3):
		if poly.is_empty(): break
		var start: Vector3 = floor_points[edge]
		var end: Vector3 = floor_points[(edge+1)%3]
		var direction: Vector2 = Vector2(end.x-start.x,end.z-start.z)
		var result: Array[Vector3] = []
		var last: Vector3 = poly[poly.size()-1]
		var last_distance: float = orientation*_s45_cross(direction,Vector2(last.x-start.x,last.z-start.z))
		for point: Vector3 in poly:
			var distance: float = orientation*_s45_cross(direction,Vector2(point.x-start.x,point.z-start.z))
			var inside: bool = distance >= -_S45_CLIP_EPSILON
			var last_inside: bool = last_distance >= -_S45_CLIP_EPSILON
			if inside != last_inside and absf(distance-last_distance) > 0.000000000001: result.append(last.lerp(point,last_distance/(last_distance-distance)))
			if inside: result.append(point)
			last = point;last_distance = distance
		poly = result
	return poly

func _s45_projected_area(poly: Array[Vector3]) -> float:
	var area: float = 0.0
	for i: int in range(1,poly.size()-1): area += absf(_s45_cross(Vector2(poly[i].x-poly[0].x,poly[i].z-poly[0].z),Vector2(poly[i+1].x-poly[0].x,poly[i+1].z-poly[0].z)))*.5
	return area

func _s45_degenerate_coverage(a: Vector3,b: Vector3,c: Vector3,polygons: Array) -> bool:
	# A native vertical triangle projects to a segment or point. Cover the entire
	# segment with the actual soil-clipped intervals; endpoints alone are weaker.
	var pairs: Array = [[a,b],[b,c],[c,a]]
	var first: Vector2 = Vector2(a.x,a.z)
	var direction: Vector2 = Vector2.ZERO
	for pair: Array in pairs:
		var candidate: Vector2 = Vector2(pair[1].x-pair[0].x,pair[1].z-pair[0].z)
		if candidate.length_squared() > direction.length_squared():
			first = Vector2(pair[0].x,pair[0].z);direction = candidate
	if direction.length_squared() == 0.0: return not _s45_support(a).is_empty()
	var intervals: Array[Vector2] = []
	for polygon: Array[Vector3] in polygons:
		var lo: float = INF
		var hi: float = -INF
		for point: Vector3 in polygon:
			var t: float = (Vector2(point.x,point.z)-first).dot(direction)/direction.length_squared()
			lo = minf(lo,t);hi = maxf(hi,t)
		if is_finite(lo) and is_finite(hi): intervals.append(Vector2(lo,hi))
	intervals.sort_custom(func(x: Vector2,y: Vector2) -> bool: return x.x < y.x)
	var covered: float = 0.0
	for interval: Vector2 in intervals:
		if interval.x > covered+_S45_CLIP_EPSILON: return false
		covered = maxf(covered,interval.y)
	return covered >= 1.0-_S45_CLIP_EPSILON

func _s45_native_geometry_proof() -> Dictionary:
	var passed: bool = _s45_built and _s45_rows.size() == _S45_ADDED_NODE_COUNT
	var triangle_count: int = 0
	var vertex_count: int = 0
	var clipped_polygons: int = 0
	var degenerate_projected: int = 0
	var minimum_gap: float = INF
	var maximum_root_gap: float = 0.0
	var coverage_error: float = 0.0
	var wind_aabb_gap: float = INF
	var failures: Array[Dictionary] = []
	var rows: Array[Dictionary] = []
	var inverse_world: Transform3D = global_transform.affine_inverse()
	for entry: Dictionary in _s45_rows:
		var node: GeometryInstance3D = entry.node
		var xf: Transform3D = inverse_world*node.global_transform*entry.mm_pose
		var root_hit: Dictionary = _s45_support(entry.root)
		var root_gap: float = float(entry.root.y)-float(root_hit.get("height",INF))
		maximum_root_gap = maxf(maximum_root_gap,absf(root_gap))
		var node_passed: bool = not root_hit.is_empty() and root_gap >= 0.0 and root_gap <= _S45_ROOT_GAP_LIMIT
		var vertices_passed: bool = true
		var triangle_support_passed: bool = true
		var coverage_passed: bool = true
		var bounds: AABB = AABB()
		var first_point: bool = true
		var source_rows: Array = []
		for surface: int in range(entry.mesh.get_surface_count()):
			var arrays: Array = entry.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var world_points: PackedVector3Array = PackedVector3Array()
			for vertex: Vector3 in vertices:
				var point: Vector3 = xf*vertex
				world_points.append(point);vertex_count += 1
				if first_point: bounds = AABB(point,Vector3.ZERO);first_point = false
				else: bounds = bounds.expand(point)
				var support: Dictionary = _s45_support(point)
				if not point.is_finite() or support.is_empty() or not _ground_foliage_allowed(point,float(entry.wind_bound_m)):
					node_passed = false;vertices_passed = false
				else:
					var gap: float = point.y-float(support.height)
					minimum_gap = minf(minimum_gap,gap)
					if gap < 0.0: node_passed = false;vertices_passed = false
			var count: int = indices.size() if not indices.is_empty() else world_points.size()
			for i: int in range(0,count,3):
				var a: Vector3 = world_points[indices[i] if not indices.is_empty() else i]
				var b: Vector3 = world_points[indices[i+1] if not indices.is_empty() else i+1]
				var c: Vector3 = world_points[indices[i+2] if not indices.is_empty() else i+2]
				triangle_count += 1
				var area: float = _s45_projected_area([a,b,c])
				var covered: float = 0.0
				var clipped_any: bool = false
				var clipped_for_coverage: Array = []
				var triangle_bounds: AABB = AABB(a,Vector3.ZERO).expand(b).expand(c)
				for ordinal: int in _s45_candidates(triangle_bounds):
					var j: int = ordinal*3
					var floor_a: Vector3 = _s45_floor_faces[j]
					var floor_b: Vector3 = _s45_floor_faces[j+1]
					var floor_c: Vector3 = _s45_floor_faces[j+2]
					var polygon: Array[Vector3] = _s45_triangle_clip([a,b,c],floor_a,floor_b,floor_c)
					if polygon.is_empty(): continue
					clipped_any = true;clipped_polygons += 1
					clipped_for_coverage.append(polygon)
					covered += _s45_projected_area(polygon)
					for point: Vector3 in polygon:
						var gap: float = point.y-_s45_floor_height(point,floor_a,floor_b,floor_c)
						minimum_gap = minf(minimum_gap,gap)
						if not is_finite(gap) or gap < 0.0: node_passed = false;triangle_support_passed = false
				if area == 0.0:
					degenerate_projected += 1
					if not clipped_any or not _s45_degenerate_coverage(a,b,c,clipped_for_coverage): node_passed = false;coverage_passed = false
				else:
					var error: float = absf(covered-area)
					coverage_error = maxf(coverage_error,error)
					if not clipped_any or error > maxf(_S45_AREA_ABSOLUTE,area*_S45_AREA_RELATIVE): node_passed = false;coverage_passed = false
				source_rows.append([surface,i,area,covered])
		var reach: float = 0.0
		for corner: int in range(8):
			var point: Vector3 = bounds.get_endpoint(corner)
			reach = maxf(reach,Vector2(point.x-entry.root.x,point.z-entry.root.z).length())
		var root_route_passed: bool = _ground_foliage_allowed(entry.root,reach+float(entry.wind_bound_m))
		if not root_route_passed: node_passed = false
		var expanded: AABB = bounds.grow(float(entry.wind_bound_m))
		var visual_obstacles_passed: bool = true
		for obstacle: AABB in _s45_visual_obstacles:
			if _s45_closed_overlap(expanded,obstacle): node_passed = false;visual_obstacles_passed = false;break
		var wind_gap: float = 0.0
		if float(entry.wind_bound_m) > 0.0:
			var highest_floor: float = -INF
			for ordinal: int in _s45_candidates(expanded):
				for corner: int in range(3): highest_floor = maxf(highest_floor,_s45_floor_faces[ordinal*3+corner].y)
			wind_gap = bounds.position.y-highest_floor
			wind_aabb_gap = minf(wind_aabb_gap,wind_gap)
			if not is_finite(wind_gap) or wind_gap <= 0.0: node_passed = false
		passed = passed and node_passed
		rows.append({"name":String(node.name),"kind":entry.kind,"passed":node_passed,"all_native_vertices_support_and_route_passed":vertices_passed,"all_native_triangle_soil_clips_passed":triangle_support_passed,"all_projected_native_triangle_coverage_passed":coverage_passed,"complete_root_AABB_route_allowed":root_route_passed,"conservative_original_solid_triangle_AABB_clear":visual_obstacles_passed,"native_mesh_sha256":entry.mesh_sha256,"root_gap_m":root_gap,"complete_projected_AABB_radius_m":reach,"native_world_AABB":str(bounds),"wind_bound_m":entry.wind_bound_m,"wind_expanded_AABB_floor_gap_m":wind_gap,"support_area_rows_sha256":_cap_preview_sha(var_to_bytes(source_rows))})
		entry["world_bounds"] = bounds
		if not node_passed and failures.size() < 8: failures.append(rows[rows.size()-1])
	return {"passed":passed,"performed":true,"source_kind":"Actual native collision faces and native mesh surface V/INDEX, no sparse-sample substitute","added_nodes":_s45_rows.size(),"native_vertices_checked":vertex_count,"native_triangles_checked":triangle_count,"clipped_soil_polygons":clipped_polygons,"projected_degenerate_triangles":degenerate_projected,"projected_degenerate_scope":"Exact zero-area native projections have complete soil-clipped segment interval coverage; point projections require their actual native support. All native vertices and every clipped plane witness still undergo gap checks.","maximum_projected_coverage_area_error_m2":coverage_error,"coverage_absolute_limit_m2":_S45_AREA_ABSOLUTE,"coverage_relative_limit":_S45_AREA_RELATIVE,"minimum_native_soil_gap_m":minimum_gap if is_finite(minimum_gap) else 0.0,"maximum_root_gap_m":maximum_root_gap,"minimum_wind_AABB_floor_gap_m":wind_aabb_gap if is_finite(wind_aabb_gap) else 0.0,"floor_sources":_s45_floor_sources.size(),"native_floor_triangles":_s45_floor_faces.size()/3,"native_floor_faces_sha256":_cap_preview_sha(_s45_floor_faces.to_byte_array()),"non_soil_original_visual_triangle_obstacles":_s45_visual_obstacles.size(),"visual_obstacle_policy":"Closed-AABB overlap (including exact touching) refuses against visible ArrayMesh MeshInstance3D triangle surfaces matching the original stone/stone_light/bark/wood/wood_light/wall/floor registry material_overrides. Cache regions are each authored center plus/minus2m XZ, Y-1..3m. Other physical obstacles are checked by the separate native physics query. Proposed foliage and stem/crown joins intentionally overlap within each own authored group.","rows":rows,"first8_failures":failures,"GPU_vertex_readback":false}

func _s45_physics_clearance() -> Dictionary:
	var passed: bool = _s45_built
	var rows: Array[Dictionary] = []
	if not is_inside_tree() or Engine.get_physics_frames() < _s45_physics_origin+2: return {"passed":false,"performed":false,"reason":"Caller must wait two native physics updates after this added assembly"}
	for entry: Dictionary in _s45_rows:
		if not entry.has("world_bounds"): passed = false;continue
		var bounds: AABB = entry.world_bounds
		bounds = bounds.grow(float(entry.wind_bound_m))
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(maxf(bounds.size.x,.0001),maxf(bounds.size.y,.0001),maxf(bounds.size.z,.0001))
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = global_transform*Transform3D(Basis.IDENTITY,bounds.get_center())
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.margin = 0.0
		query.exclude = _s45_floor_exclusions
		var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query,8)
		passed = passed and hits.is_empty()
		var paths: Array[String] = []
		for hit: Dictionary in hits: paths.append(str((hit.collider as Node).get_path()))
		rows.append({"name":String(entry.node.name),"passed":hits.is_empty(),"hit_paths":paths})
	return {"passed":passed,"performed":true,"query_count":rows.size(),"collision_mask":1,"exact_native_floor_body_RID_exclusions":_s45_floor_exclusions.size(),"scope":"Conservative BoxShape covers each complete added native mesh AABB plus its analytic horizontal sway bound. Only the exact captured direct terrain floor bodies are excluded. Ambiguous obstacle AABB proximity refuses; these shrubs add no new movement colliders.","rows":rows}

func _s45_apply_wind() -> void:
	var active: bool = _m37_active()
	for key: String in _s45_materials:
		var original: ShaderMaterial = _s45_materials[key].original
		var selected: ShaderMaterial = _s45_materials[key].selected
		selected.set_shader_parameter("night_amount",original.get_shader_parameter("night_amount"))
		selected.set_shader_parameter("wind_time",_m37_elapsed)
		selected.set_shader_parameter("wind_displacement_m",_S45_WIND_BOUND*lerpf(.72,1.0,rain_amount) if active else 0.0)

func _process(delta: float) -> void:
	super._process(delta)
	_s45_apply_wind()

func set_living_motion_enabled(value: bool) -> void:
	super.set_living_motion_enabled(value)
	_s45_apply_wind()

func set_living_motion_reduced(value: bool) -> void:
	super.set_living_motion_reduced(value)
	_s45_apply_wind()

func initialize_living_motion() -> Dictionary:
	if not get_midstory45_report().get("passed",false):
		_m37_errors.append("Separate Midstory45 native support/rest/obstacle admission required before motion")
		return get_living_motion_report()
	var report: Dictionary = super.initialize_living_motion()
	_s45_apply_wind()
	return report

func get_midstory45_report() -> Dictionary:
	var rest_exact: bool = _s45_built and global_transform == Transform3D.IDENTITY and str(_rng.state) == _s45_rng and _cap_preview_sha(var_to_bytes(_rooted_foreground_group_records)) == _s45_rooted_sha
	var inverse_world: Transform3D = global_transform.affine_inverse()
	for key: String in _s45_registry: rest_exact = rest_exact and _materials[key] == _s45_registry[key]
	for entry: Dictionary in _s45_floor_sources:
		var shape: CollisionShape3D = entry.node
		if not is_instance_valid(shape) or not shape.shape is ConcavePolygonShape3D: rest_exact = false;continue
		var body: StaticBody3D = entry.body
		if not is_instance_valid(body) or shape.disabled or shape.get_parent() != body or body.get_parent() != entry.terrain or entry.terrain != get_node_or_null("GroundAndPaths") or body.get_rid() != entry.body_RID or (body.collision_layer & 1) == 0 or body.collision_layer != entry.body_collision_layer or body.collision_mask != entry.body_collision_mask:
			rest_exact = false;continue
		rest_exact = rest_exact and shape.shape == entry.resource and inverse_world*shape.global_transform == entry.transform and _cap_preview_sha((shape.shape as ConcavePolygonShape3D).get_faces().to_byte_array()) == entry.faces_sha256
	var mesh_hashes: Dictionary = {}
	for entry: Dictionary in _s45_visual_sources:
		var node: MeshInstance3D = entry.node
		if not is_instance_valid(node) or node.mesh == null: rest_exact = false;continue
		if not mesh_hashes.has(node.mesh.get_instance_id()): mesh_hashes[node.mesh.get_instance_id()] = _m37_mesh_sha(node.mesh)
		rest_exact = rest_exact and node.mesh == entry.mesh and mesh_hashes[node.mesh.get_instance_id()] == entry.mesh_sha256 and node.global_transform == entry.transform and node.material_override == entry.material and node.visible == entry.visible
	for entry: Dictionary in _s45_rows:
		var node: GeometryInstance3D = entry.node
		if not is_instance_valid(node): rest_exact = false;continue
		if node is MultiMeshInstance3D and ((node as MultiMeshInstance3D).multimesh == null or (node as MultiMeshInstance3D).multimesh.mesh == null): rest_exact = false;continue
		if node is MeshInstance3D and (node as MeshInstance3D).mesh == null: rest_exact = false;continue
		var mesh: Mesh = (node as MultiMeshInstance3D).multimesh.mesh if node is MultiMeshInstance3D else (node as MeshInstance3D).mesh
		if not mesh_hashes.has(mesh.get_instance_id()): mesh_hashes[mesh.get_instance_id()] = _m37_mesh_sha(mesh)
		rest_exact = rest_exact and mesh == entry.mesh and mesh_hashes[mesh.get_instance_id()] == entry.mesh_sha256 and node.transform == entry.transform and node.global_transform == entry.global_transform and node.material_override == entry.material and var_to_bytes(node.extra_cull_margin) == var_to_bytes(entry.extra_cull_margin) and node.cast_shadow == entry.cast_shadow
		if node is MultiMeshInstance3D: rest_exact = rest_exact and (node as MultiMeshInstance3D).multimesh.instance_count == 1 and (node as MultiMeshInstance3D).multimesh.get_instance_transform(0) == entry.mm_pose
	var forks_exact: bool = true
	for key: String in _s45_materials:
		var entry: Dictionary = _s45_materials[key]
		forks_exact = forks_exact and entry.initial_exact and entry.selected != entry.original and entry.selected.shader == _M37_WIND_SHADER and entry.selected.render_priority == entry.original.render_priority and entry.selected.next_pass == entry.original.next_pass and var_to_bytes(_m37_parameters(entry.selected,_M37_LEAF_KEYS)) == var_to_bytes(_m37_parameters(entry.original,_M37_LEAF_KEYS))
		var expected_displacement: float = _S45_WIND_BOUND*lerpf(.72,1.0,rain_amount) if _m37_active() else 0.0
		forks_exact = forks_exact and var_to_bytes(entry.selected.get_shader_parameter("wind_time")) == var_to_bytes(_m37_elapsed) and var_to_bytes(entry.selected.get_shader_parameter("wind_displacement_m")) == var_to_bytes(expected_displacement)
	var physics: Dictionary = _s45_physics_clearance()
	var passed: bool = _s45_errors.is_empty() and _s45_native.get("passed",false) and rest_exact and forks_exact and physics.get("passed",false)
	_s45_report = {"schema":"mush-midstory45-native/1","passed":passed,"status":"source_and_native_review_only" if passed else "refused_or_pending","source_sha256":FileAccess.get_sha256(_S45_SOURCE),"descriptor_sha256":FileAccess.get_sha256(_S45_DESCRIPTOR),"parent_sha256":FileAccess.get_sha256(_S45_PARENT),"errors":_s45_errors.duplicate(),"native_geometry":_s45_native.duplicate(true),"actual_physics_obstacle_clearance":physics,"current_added_rest_bindings_exact":rest_exact,"material_forks_exact":forks_exact,"owned_leaf_material_forks":_s45_materials.size(),"global_RNG_exact":str(_rng.state) == _s45_rng,"inherited474_record_hash_exact":_cap_preview_sha(var_to_bytes(_rooted_foreground_group_records)) == _s45_rooted_sha,"existing_474_242_proof_covers_added_nodes":false,"additional_baked_attempts":0,"added_nodes_separate_from_original_pipeline":true,"wind":{"maximum_horizontal_displacement_m_proposed":_S45_WIND_BOUND,"clock_seconds":_m37_elapsed,"active":_m37_active(),"clock_owner":"Inherited pause-aware living37 delta clock","shader_path":_M37_WIND_SHADER.resource_path,"shader_sha256":FileAccess.get_sha256(_M37_WIND_SHADER.resource_path),"native_meshes_static":true,"GPU_displaced_vertex_readback":false,"motion_video_verified":false},"placements_approved":false,"art_approved":false,"source_adopted":false,"native_adopted":false,"performance_measured":false,"scope":"Three provisional asymmetric shrub groups in the existing clearing. Actual native complete mesh vertices/triangles, native collision soil-plane clipping, conservative visual/physics obstacles and rest hashes are separate added-node gates. No inherited full-game/contact/render/performance or art approval claim. Root must await physics updates, require this report and the current admitted terrain/Sky/Motion reports, then inspect actual engine captures."}
	return _s45_report.duplicate(true)
