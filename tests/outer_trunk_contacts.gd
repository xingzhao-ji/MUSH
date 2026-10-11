extends RefCounted
## Actual one-body native regression; caller owns installation/removal and Main.
const Contacts = preload("res://tests/forest_trunk_contacts.gd")
const CurrentPlayer = preload("res://scripts/air_capsule_guard.gd")
const BATCH: String = "BatchedStaticWorld/Static_-9223371994861402623_1_-2"
const PACKET_SHA: String = "83ee726ad28f038147f016f3e2c54b821a32e8b5e56201d7ef2d149ba86ffe66"
var checks: Array[Dictionary] = []

func run(game: Node3D) -> Dictionary:
	checks.clear()
	var result: Dictionary = {"schema":"mush-outer-trunk-contacts/1","passed":false,"checks":checks,"case":{},"endpoint_restored":false,"controller_settings_exact":false,"collision_bindings_exact":false,"native_cylinder_geometry_exact":false,"motion_acceptance":false,"scope":"One new cylinder trunk: actual approach/block or deflection, lateral slide, retreat, unsafe cap refusal and original player endpoint/settings restoration; root owns body rollback."}
	var player: CurrentPlayer = game.get("player") as CurrentPlayer
	var body: StaticBody3D = game.world.get_node_or_null("OuterTreeContact") as StaticBody3D
	if not _check("Actual unpaused player and new body",player!=null and body!=null and not game.get_tree().paused): return result
	var admitted: Dictionary = _body_record(game.world,body)
	result["body_admission"]=admitted
	if not _check("Three native packet-enclosing cylinders, bounded shell, unsafe layer1/mask2",admitted.passed): return result
	var fixture: RefCounted = Contacts.new()
	var bodies: Array[StaticBody3D] = [body]
	var origin: Vector3 = body.get_meta("forest_root") as Vector3
	var support: Dictionary = fixture._ground_at(player,origin+Vector3(0,0,1.7),bodies)
	if not _check("Supported south approach outside water/playable boundary",not support.is_empty()): return result
	var start: Vector3 = support.position+Vector3.UP*.008
	var pose: Vector3 = player.global_position
	var yaw: float = player.camera_yaw
	var enabled: bool = player.enabled
	var physics: bool = player.is_physics_processing()
	var processing: bool = player.is_processing()
	var settings: PackedByteArray = fixture._settings(player)
	var collisions: String = fixture._collision_bindings(game.world)
	var step_before: Dictionary = player.entrance48_step_readback()
	var observer: Contacts.AfterPlayer = Contacts.AfterPlayer.new()
	observer.process_physics_priority=player.process_physics_priority+100
	game.add_child(observer)
	fixture._release(); player.release_controls(); player.enabled=true
	player.set_physics_process(true); player.set_process(true)
	await fixture._frames(observer,3)
	player.teleport_safe(start,0.0)
	await fixture._frames(observer,25)
	var row: Dictionary = {"root":fixture._v(origin),"body":str(body.get_path()),"support":fixture._hit(support),"placed_position":fixture._v(player.global_position),"passed":false}
	var placed: bool = fixture._xz(player.global_position,start)<.03 and player.is_on_floor() and player.state=="Grounded" and not player.get("_require_release") and player._valid_safe_position(player.global_position)
	row["placed"]=placed
	if _check("Validated native approach pose",placed):
		row["approach"]=await fixture._phase(player,body,origin,observer,Vector3.FORWARD,90)
		row["slide"]=await fixture._phase(player,body,origin,observer,Vector3(1,0,-.3).normalized(),36)
		row["retreat"]=await fixture._phase(player,body,origin,observer,Vector3.BACK,45)
		fixture._release(); await fixture._frames(observer,20)
		row["unsafe_support"]=_unsafe_support(player,body,fixture)
		var after: Dictionary = player.entrance48_step_readback()
		row["step_started_delta"]=int(after.started)-int(step_before.started)
		row["step_last_attempt"]=after.get("last_attempt",{}).duplicate(true)
		row["settled_position"]=fixture._v(player.global_position)
		row["settled_safe"]=player.is_on_floor() and player.state=="Grounded" and player._valid_safe_position(player.global_position)
		var approach: Dictionary = row.approach; var slide: Dictionary = row.slide; var retreat: Dictionary = row.retreat
		row.passed=approach.valid and approach.body_contact_ticks>0 and approach.obstructed_contact_ticks>0 and approach.travel_m>.1 and slide.valid and slide.displacement[0]>.25 and retreat.valid and retreat.displacement[2]>.5 and row.step_started_delta==0 and row.settled_safe and row.unsafe_support.passed
		_check("Native obstruction/slide/retreat, every-tick no-overlap, no steps and unsafe cap refusal",row.passed)
	result["case"]=row
	fixture._release(); player.release_controls(); player.teleport_safe(pose,yaw)
	await fixture._frames(observer,30)
	result.endpoint_restored=fixture._xz(player.global_position,pose)<.03 and absf(player.global_position.y-pose.y)<.06 and player.is_on_floor() and player.state=="Grounded" and player._valid_safe_position(player.global_position) and absf(wrapf(player.camera_yaw-yaw,-PI,PI))<.00001
	player.enabled=enabled; player.set_physics_process(physics); player.set_process(processing)
	observer.set_physics_process(false); observer.queue_free()
	await game.get_tree().process_frame
	result.collision_bindings_exact=fixture._collision_bindings(game.world)==collisions
	result.controller_settings_exact=fixture._settings(player)==settings
	result.native_cylinder_geometry_exact=var_to_bytes(_body_record(game.world,body))==var_to_bytes(admitted)
	result["step_started_delta"]=int(player.entrance48_step_readback().started)-int(step_before.started)
	_check("Endpoint, settings/flags, original bodies and exact native cylinder geometry restored",result.endpoint_restored and result.collision_bindings_exact and result.controller_settings_exact and result.native_cylinder_geometry_exact and player.enabled==enabled and player.is_physics_processing()==physics and player.is_processing()==processing)
	var passed: bool = bool(row.passed) and result.step_started_delta==0
	for check: Dictionary in checks: passed=passed and bool(check.passed)
	result.passed=passed
	return result

func _body_record(world: Node3D, body: StaticBody3D) -> Dictionary:
	var row: Dictionary = {"passed":false,"segments":[],"packet_sha256":"","containment_tolerance_m":.00001,"maximum_radial_shell_m":0.0,"lower_1_6m":{"definition":"Conservative whole-segment radial shell for segments intersecting the first 1.6m above the native root; not a measured movement clearance.","segments":[],"maximum_radial_shell_bound_m":0.0}}
	var source: MeshInstance3D = world.get_node_or_null(BATCH) as MeshInstance3D
	if source==null or source.mesh==null or source.global_transform!=Transform3D.IDENTITY or source.mesh.get_surface_count()!=1 or source.material_override!=world._materials.bark: return row
	if body.global_transform!=Transform3D.IDENTITY or body.collision_layer!=1 or body.collision_mask!=2 or not bool(body.get_meta("unsafe_support",false)) or body.has_meta("entrance48_step_surface") or body.get_child_count()!=3: return row
	if not (body.get_meta("forest_root",null) is Vector3) or not (body.get_meta("forest_root") as Vector3).is_equal_approx(Vector3(15.965662,0,-15.513497)): return row
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if vertices.size()<216 or (arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty()): return row
	var packet: PackedVector3Array = vertices.slice(0,216)
	row.packet_sha256=_sha(packet.to_byte_array())
	if row.packet_sha256!=PACKET_SHA: return row
	var root_y: float = (body.get_meta("forest_root") as Vector3).y
	for index: int in range(3):
		var contact: CollisionShape3D = body.get_child(index) as CollisionShape3D
		if contact==null or contact.disabled or not (contact.shape is CylinderShape3D): return row
		var points: PackedVector3Array = packet.slice(index*72,(index+1)*72)
		var bottom: Vector3 = Vector3.ZERO
		var top: Vector3 = Vector3.ZERO
		# Exact native _smooth_quad order [a,c,b,a,d,c], twelve ring samples.
		for side: int in range(12):
			bottom+=points[side*6]/12.0
			top+=points[side*6+4]/12.0
		var axis: Vector3 = top-bottom
		if not axis.is_finite() or axis.length()<=.00001: return row
		var pose: Transform3D = Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())),(bottom+top)*.5)
		if contact.transform!=pose: return row
		var inverse: Transform3D = pose.affine_inverse()
		var radius: float = 0.0
		var half_height: float = 0.0
		var minimum_y: float = INF
		var maximum_y: float = -INF
		for point: Vector3 in points:
			if not point.is_finite(): return row
			var local: Vector3 = inverse*point
			radius=maxf(radius,Vector2(local.x,local.z).length())
			half_height=maxf(half_height,absf(local.y))
			minimum_y=minf(minimum_y,point.y); maximum_y=maxf(maximum_y,point.y)
		var shape: CylinderShape3D = contact.shape as CylinderShape3D
		if shape.radius!=radius or shape.height!=half_height*2.0 or radius<=0.0 or half_height<=0.0: return row
		var contained: bool = true
		for point: Vector3 in points:
			var local: Vector3 = contact.global_transform.affine_inverse()*point
			contained=contained and local.is_finite() and Vector2(local.x,local.z).length()<=shape.radius+.00001 and absf(local.y)<=shape.height*.5+.00001
		# Native polygon ring edges provide a conservative radial shell bound.
		# Both rings share the admitted ordered angular topology; their frustum
		# side faces interpolate between these endpoint polygons.
		var inradius: float = INF
		for side: int in range(12):
			for pair: Vector2i in [Vector2i(0,2),Vector2i(4,1)]:
				var first: Vector3 = inverse*points[side*6+pair.x]
				var last: Vector3 = inverse*points[side*6+pair.y]
				var p: Vector2 = Vector2(first.x,first.z)
				var edge: Vector2 = Vector2(last.x,last.z)-p
				if edge.length_squared()<=.000000000001: return row
				var fraction: float = clampf(-p.dot(edge)/edge.length_squared(),0.0,1.0)
				inradius=minf(inradius,(p+edge*fraction).length())
		var shell: float = maxf(0.0,shape.radius-inradius)
		var segment: Dictionary = {"index":index,"shape_id":shape.get_instance_id(),"contact_id":contact.get_instance_id(),"transform_hex":var_to_bytes(contact.transform).hex_encode(),"radius_m":shape.radius,"height_m":shape.height,"source_corners":points.size(),"source_points_sha256":_sha(points.to_byte_array()),"all_corners_contained":contained,"minimum_native_ring_inradius_m":inradius,"radial_shell_bound_m":shell,"source_minimum_y":minimum_y,"source_maximum_y":maximum_y}
		row.segments.append(segment)
		row.maximum_radial_shell_m=maxf(float(row.maximum_radial_shell_m),shell)
		if maximum_y>=root_y and minimum_y<=root_y+1.6:
			row.lower_1_6m.segments.append(index)
			row.lower_1_6m.maximum_radial_shell_bound_m=maxf(float(row.lower_1_6m.maximum_radial_shell_bound_m),shell)
		if not contained or shell>.20: return row
	if row.lower_1_6m.segments.is_empty(): return row
	row.passed=true
	return row

func _unsafe_support(player: CurrentPlayer, body: StaticBody3D, fixture: RefCounted) -> Dictionary:
	var selected: CollisionShape3D
	var highest: float = -INF
	var top: Vector3 = Vector3.ZERO
	var cap_maximum_y: float = -INF
	for node: Node in body.get_children():
		var contact: CollisionShape3D = node as CollisionShape3D
		var shape: CylinderShape3D = contact.shape as CylinderShape3D
		var center: Vector3 = contact.global_transform*Vector3(0,shape.height*.5,0)
		if center.y>highest:
			highest=center.y; selected=contact; top=center
			var cap_axis: Vector3 = contact.global_transform.basis.y.normalized()
			cap_maximum_y=center.y+shape.radius*sqrt(maxf(0.0,1.0-cap_axis.y*cap_axis.y))
	var feet: Vector3 = top+Vector3.UP*.02
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(top.x,cap_maximum_y+.08,top.z),top-Vector3.UP*.10,1,[player.get_rid()]))
	var owned: bool = not hit.is_empty() and hit.collider==body and hit.normal.y>=cos(player.floor_max_angle) and not player._outside_playable(feet) and not player._over_water(feet)
	var ordinary: Dictionary = player._support_at(feet,.12)
	var float_allowed: bool = player._safe_hover_support(feet)
	var safe_allowed: bool = player._valid_safe_position(feet)
	return {"passed":owned and ordinary.is_empty() and not float_allowed and not safe_allowed,"native_segment":selected.get_index(),"native_cap_maximum_y":cap_maximum_y,"native_upper_cap_center":fixture._v(top),"feet":fixture._v(feet),"raw_native_hit":fixture._hit(hit),"owned_walkable_cap":owned,"ordinary_support_refused":ordinary.is_empty(),"float_support_refused":not float_allowed,"safe_position_refused":not safe_allowed}

func _check(label: String, passed: bool) -> bool:
	checks.append({"label":label,"passed":passed}); return passed
func _sha(bytes: PackedByteArray) -> String:
	if bytes.is_empty(): return ""
	var hash: HashingContext = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
