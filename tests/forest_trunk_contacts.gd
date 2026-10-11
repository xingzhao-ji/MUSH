extends RefCounted
## Isolated native contacts only. Caller owns Main, trial, output and shutdown.
const CurrentPlayer = preload("res://scripts/air_capsule_guard.gd")
const ROOTS := [Vector3(-17.71118,-.35,-16.07478),Vector3(-14.6083,-.35,-17.85634),Vector3(14.9536,-.35,-18.3257),Vector3(17.98473,-.35,-16.35394)]
const ACTIONS := ["move_left","move_right","move_forward","move_back","touch_move_left","touch_move_right","touch_move_forward","touch_move_back","float","glow","interact","decorate","pause"]
const SETTINGS := ["collision_layer","collision_mask","motion_mode","up_direction","floor_max_angle","floor_snap_length","floor_stop_on_slope","floor_constant_speed","floor_block_on_wall","max_slides","safe_margin","slide_on_ceiling"]

class AfterPlayer:
	extends Node
	signal observed
	var serial: int = 0
	var delta: float = 0.0
	func _physics_process(value: float) -> void:
		serial+=1; delta=value; observed.emit()

var checks: Array[Dictionary]=[]

func run(game: Node3D, trial: Node3D) -> Dictionary:
	checks.clear()
	var result: Dictionary={"schema":"mush-forest-trunk-contacts/1","passed":false,"checks":checks,"cases":[],"endpoint_restored":false,"original_collision_bindings_exact":false,"controller_settings_exact":false,"counters_reset":false,"motion_acceptance":false}
	var player: CurrentPlayer=game.get("player") as CurrentPlayer
	if not _check("Actual unpaused Main/player and four trial bodies",player!=null and trial!=null and trial.name=="ForestMiddleLayer" and not game.get_tree().paused): return result
	var bodies: Array[StaticBody3D]=[]
	for node: Node in trial.find_children("*","StaticBody3D",true,false): bodies.append(node)
	if not _check("Exactly four five-segment unsafe layer1/mask2 trunks",_valid_bodies(bodies)): return result
	var pose: Vector3=player.global_position
	var yaw: float=player.camera_yaw
	var enabled: bool=player.enabled
	var physics: bool=player.is_physics_processing()
	var processing: bool=player.is_processing()
	var settings: PackedByteArray=_settings(player)
	var collisions: String=_collision_bindings(game.world)
	var step_before: Dictionary=player.entrance48_step_readback()
	var observer:=AfterPlayer.new()
	observer.process_physics_priority=player.process_physics_priority+100
	game.add_child(observer)
	_release(); player.release_controls(); player.enabled=true
	player.set_physics_process(true); player.set_process(true)
	await _frames(observer,3)
	for expected: Vector3 in ROOTS:
		var body: StaticBody3D=_body_at(bodies,expected)
		if not _check("Unique actual forest_root near "+str(expected),body!=null): continue
		var origin: Vector3=body.get_meta("forest_root")
		var support: Dictionary=_ground_at(player,origin+Vector3(0,0,1.5),bodies)
		if not _check("Supported clear approach at "+str(origin),not support.is_empty()): continue
		var start: Vector3=support.position+Vector3.UP*.008
		var row: Dictionary={"root":_v(origin),"body":str(body.get_path()),"support":_hit(support),"passed":false}
		_release(); player.release_controls(); player.teleport_safe(start,0.0)
		await _frames(observer,25)
		var placed: bool=_xz(player.global_position,start)<.03 and player.is_on_floor() and player.state=="Grounded" and not player.get("_require_release") and player._valid_safe_position(player.global_position)
		row["placed"]=placed; row["placed_position"]=_v(player.global_position)
		if not _check("Validated native approach pose "+str(origin),placed): result.cases.append(row); continue
		var before: Dictionary=player.entrance48_step_readback()
		row["approach"]=await _phase(player,body,origin,observer,Vector3.FORWARD,90)
		row["slide"]=await _phase(player,body,origin,observer,Vector3(1,0,-.3).normalized(),36)
		row["retreat"]=await _phase(player,body,origin,observer,Vector3.BACK,45)
		_release(); await _frames(observer,20)
		row["unsafe_support"]=_unsafe_support(player,body)
		var after: Dictionary=player.entrance48_step_readback()
		row["step_started_delta"]=int(after.started)-int(before.started)
		row["step_declined_delta"]=int(after.declined)-int(before.declined)
		row["step_last_attempt"]=after.get("last_attempt",{}).duplicate(true)
		row["settled_position"]=_v(player.global_position)
		row["settled_safe"]=player.is_on_floor() and player.state=="Grounded" and player._valid_safe_position(player.global_position)
		var approach: Dictionary=row.approach; var slide: Dictionary=row.slide; var retreat: Dictionary=row.retreat
		row["passed"]=approach.valid and approach.body_contact_ticks>0 and approach.obstructed_contact_ticks>0 and approach.travel_m>.1 and slide.valid and slide.displacement[0]>.25 and retreat.valid and retreat.displacement[2]>.5 and row.step_started_delta==0 and row.settled_safe and row.unsafe_support.passed
		_check("Native block/slide/retreat, no step and unsafe support "+str(origin),row.passed)
		result.cases.append(row)
	_release(); player.release_controls(); player.teleport_safe(pose,yaw)
	await _frames(observer,30)
	result["endpoint_restored"]=_xz(player.global_position,pose)<.03 and absf(player.global_position.y-pose.y)<.06 and player.is_on_floor() and player.state=="Grounded" and player._valid_safe_position(player.global_position) and absf(wrapf(player.camera_yaw-yaw,-PI,PI))<.00001
	player.enabled=enabled; player.set_physics_process(physics); player.set_process(processing)
	observer.set_physics_process(false); observer.queue_free()
	await game.get_tree().process_frame
	result["original_collision_bindings_exact"]=_collision_bindings(game.world)==collisions
	result["controller_settings_exact"]=_settings(player)==settings
	result["step_started_delta"]=int(player.entrance48_step_readback().started)-int(step_before.started)
	_check("Ordinary endpoint, settings/flags and collision bindings restored",result.endpoint_restored and result.original_collision_bindings_exact and result.controller_settings_exact and player.enabled==enabled and player.is_physics_processing()==physics and player.is_processing()==processing)
	var passed: bool=result.cases.size()==4 and result.step_started_delta==0
	for row: Dictionary in checks: passed=passed and row.passed
	result["passed"]=passed
	return result

func _phase(player: CurrentPlayer, body: StaticBody3D, origin: Vector3, observer: AfterPlayer, direction: Vector3, count: int) -> Dictionary:
	_release(); await _frames(observer,3)
	var start: Vector3=player.global_position
	var row: Dictionary={"ticks":0,"first_physics_frame":Engine.get_physics_frames()+1,"last_physics_frame":0,"direction":_v(direction),"from":_v(start),"valid":true,"body_contact_ticks":0,"obstructed_contact_ticks":0,"longest_contact_stall_ticks":0,"travel_m":0.0,"minimum_front_distance_m":INF,"maximum_rise_m":0.0,"maximum_drop_m":0.0,"input_min":INF,"input_max":0.0,"contact_witnesses":[],"first_samples":[],"last_samples":[],"selected_capsule_overlap":false,"capsule_overlap_queries":0,"overlap_query_saturated":false}
	var previous: Vector3=start
	var previous_frame: int=Engine.get_physics_frames()
	var stall: int=0
	player.camera_yaw=atan2(-direction.x,-direction.z)
	Input.action_press("move_forward",1.0)
	for index: int in range(count):
		await observer.observed
		var frame: int=Engine.get_physics_frames()
		var point: Vector3=player.global_position
		var displacement: Vector3=point-previous
		var planar: float=Vector2(displacement.x,displacement.z).length()
		var input: float=player._movement_input().length()
		var contacts: Array[Dictionary]=_contacts(player,body)
		var overlap: Dictionary=_capsule_overlap(player,body)
		row.capsule_overlap_queries+=1
		row.selected_capsule_overlap=row.selected_capsule_overlap or overlap.selected
		row.overlap_query_saturated=row.overlap_query_saturated or overlap.saturated
		row.ticks+=1; row.last_physics_frame=frame; row.travel_m+=planar
		row.minimum_front_distance_m=minf(row.minimum_front_distance_m,point.z-origin.z)
		row.maximum_rise_m=maxf(row.maximum_rise_m,displacement.y); row.maximum_drop_m=maxf(row.maximum_drop_m,-displacement.y)
		row.input_min=minf(row.input_min,input); row.input_max=maxf(row.input_max,input)
		if not contacts.is_empty():
			row.body_contact_ticks+=1
			# A round stem may legitimately deflect the capsule around its side.
			# Require native obstruction/deflection, not a manufactured long stall.
			if displacement.dot(direction)<2.2*observer.delta*.8 or absf(direction.cross(displacement).y)>.003: row.obstructed_contact_ticks+=1
			if row.contact_witnesses.size()<8: row.contact_witnesses.append({"physics_frame":frame,"position":_v(point),"contacts":contacts})
		stall=stall+1 if not contacts.is_empty() and planar<.001 else 0
		row.longest_contact_stall_ticks=maxi(row.longest_contact_stall_ticks,stall)
		var good: bool=frame==previous_frame+1 and observer.delta>0.0 and observer.delta<=.05 and point.is_finite() and player.velocity.is_finite() and player.enabled and not player.get("_require_release") and not player.get_tree().paused and player.state!="Recovering" and not player._outside_playable(point) and not player._over_water(point) and player.is_on_floor() and absf(input-1.0)<.00001 and absf(displacement.y)<=.22 and not overlap.selected and not overlap.saturated
		row.valid=row.valid and good
		var sample: Dictionary={"physics_frame":frame,"delta":observer.delta,"position":_v(point),"velocity":_v(player.velocity),"floor":player.is_on_floor(),"wall":player.is_on_wall(),"state":player.state,"step_phase":player.get("_step48_phase"),"input":input,"selected_contacts":contacts.size()}
		if index<3: row.first_samples.append(sample)
		if index>=count-3: row.last_samples.append(sample)
		previous=point; previous_frame=frame
		if not good: break
	_release()
	row["to"]=_v(player.global_position); row["displacement"]=_v(player.global_position-start)
	row.valid=row.valid and row.ticks==count and row.capsule_overlap_queries==count and not row.selected_capsule_overlap and not row.overlap_query_saturated
	return row

func _capsule_overlap(player: CurrentPlayer, body: StaticBody3D) -> Dictionary:
	var query:=PhysicsShapeQueryParameters3D.new()
	var capsule: CollisionShape3D=player.get_node("CollisionShape3D")
	query.shape=capsule.shape; query.transform=capsule.global_transform; query.collision_mask=1; query.exclude=[player.get_rid()]; query.margin=0.0
	var hits: Array[Dictionary]=player.get_world_3d().direct_space_state.intersect_shape(query,32)
	var selected: bool=false
	for hit: Dictionary in hits: selected=selected or hit.collider==body
	return {"selected":selected,"saturated":hits.size()==32}

func _unsafe_support(player: CurrentPlayer, body: StaticBody3D) -> Dictionary:
	var shape: CollisionShape3D=body.get_child(4)
	var cylinder: CylinderShape3D=shape.shape
	var top: Vector3=shape.global_transform*Vector3(0,cylinder.height*.5,0)
	var feet: Vector3=top+Vector3.UP*.02
	var query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.08,feet-Vector3.UP*.12,1,[player.get_rid()])
	var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
	var owned: bool=not hit.is_empty() and hit.collider==body and hit.normal.y>=cos(player.floor_max_angle) and not player._outside_playable(feet) and not player._over_water(feet)
	var ordinary: Dictionary=player._support_at(feet,.12)
	var float_allowed: bool=player._safe_hover_support(feet)
	var safe_allowed: bool=player._valid_safe_position(feet)
	return {"passed":owned and ordinary.is_empty() and not float_allowed and not safe_allowed,"feet":_v(feet),"raw_native_hit":_hit(hit),"owned_walkable_cap":owned,"ordinary_support_refused":ordinary.is_empty(),"float_support_refused":not float_allowed,"safe_position_refused":not safe_allowed}

func _contacts(player: CurrentPlayer, selected: StaticBody3D) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for i: int in range(player.get_slide_collision_count()):
		var collision: KinematicCollision3D=player.get_slide_collision(i)
		for j: int in range(collision.get_collision_count()):
			if collision.get_collider(j)==selected: rows.append({"slide":i,"contact":j,"shape":collision.get_collider_shape_index(j),"point":_v(collision.get_position(j)),"normal":_v(collision.get_normal(j))})
	return rows

func _valid_bodies(bodies: Array[StaticBody3D]) -> bool:
	if bodies.size()!=4: return false
	for body: StaticBody3D in bodies:
		if body.collision_layer!=1 or body.collision_mask!=2 or not bool(body.get_meta("unsafe_support",false)) or not body.get_meta("forest_root",null) is Vector3 or body.get_child_count()!=5 or body.has_meta("entrance48_step_surface"): return false
		for node: Node in body.get_children():
			var shape: CollisionShape3D=node as CollisionShape3D
			if shape==null: return false
			var cylinder: CylinderShape3D=shape.shape as CylinderShape3D
			if shape.disabled or cylinder==null or cylinder.height<=0.0 or cylinder.radius<=0.0 or not shape.transform.is_finite() or absf(shape.transform.basis.determinant()-1.0)>.00001: return false
	return true

func _body_at(bodies: Array[StaticBody3D], point: Vector3) -> StaticBody3D:
	var found: StaticBody3D
	for body: StaticBody3D in bodies:
		if (body.get_meta("forest_root") as Vector3).distance_to(point)<.001:
			if found!=null: return null
			found=body
	return found

func _ground_at(player: CurrentPlayer, point: Vector3, bodies: Array[StaticBody3D]) -> Dictionary:
	var exclude: Array[RID]=[player.get_rid()]
	for body: StaticBody3D in bodies: exclude.append(body.get_rid())
	var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.0,point-Vector3.UP*2.0,1,exclude))
	if hit.is_empty() or hit.normal.y<cos(player.floor_max_angle) or player._outside_playable(hit.position) or player._over_water(hit.position): return {}
	return hit

func _collision_bindings(world: Node3D) -> String:
	var rows: Array=[]
	for node: Node in world.find_children("*","CollisionShape3D",true,false): rows.append([node.get_instance_id(),node.global_transform,node.disabled,node.shape.get_instance_id(),node.get_parent().get_instance_id(),node.get_parent().collision_layer,node.get_parent().collision_mask])
	var h:=HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(var_to_bytes(rows)); return h.finish().hex_encode()

func _settings(player: CurrentPlayer) -> PackedByteArray:
	var values: Array=[]
	for key: String in SETTINGS: values.append([key,player.get(key)])
	return var_to_bytes(values)

func _release() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func _frames(observer: AfterPlayer, count: int) -> void:
	for i: int in range(count): await observer.observed

func _check(label: String, passed: bool) -> bool:
	checks.append({"label":label,"passed":passed}); return passed

func _hit(hit: Dictionary) -> Dictionary:
	if hit.is_empty(): return {}
	return {"body":str(hit.collider.get_path()),"shape":hit.shape,"position":_v(hit.position),"normal":_v(hit.normal)}

func _v(value: Vector3) -> Array: return [value.x,value.y,value.z]
func _xz(a: Vector3,b: Vector3) -> float: return Vector2(a.x-b.x,a.z-b.z).length()
