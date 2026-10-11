extends SceneTree
var checks: Array[Dictionary] = []
var game: Node3D
var out := ""

func _initialize() -> void: _run.call_deferred()
func check(label: String, value: bool, detail: Variant = null) -> void:
	checks.append({"name":label,"passed":value,"detail":detail})

func touch(id: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index=id
	event.position=point
	event.pressed=pressed
	event.canceled=canceled
	root.push_input(event)

func drag(id: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=id
	event.position=point
	event.relative=relative
	root.push_input(event)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): out=arg.trim_prefix("--report-dir=")
	if not out.is_absolute_path() or not out.simplify_path().begins_with(ProjectSettings.globalize_path("res://reports/")) or DirAccess.dir_exists_absolute(out) or FileAccess.file_exists(out):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	check("touch primary integration exists",ResourceLoader.exists("res://scripts/touch_controls.gd"))
	if not ResourceLoader.exists("res://scripts/touch_controls.gd"):
		_finish()
		return
	root.size=Vector2i(1280,720)
	game=load("res://tests/mobile_game_fixture.gd").new()
	root.add_child(game)
	for i in range(5): await physics_frame
	var controls: Control=game.get("touch_controls")
	check("actual clearing exposes touch controls",is_instance_valid(controls))
	if not is_instance_valid(controls):
		_finish()
		return
	controls.set_active(true)
	controls.layout_for_rect(Rect2(36,18,1208,680))
	await process_frame
	var origin: Vector2=controls.stick_adapter.get_global_rect().get_center()
	var player: CharacterBody3D=game.get("player")
	var start: Vector3=player.position
	touch(7,origin,true)
	drag(7,origin+Vector2(55,0),Vector2(55,0))
	for i in range(10): await physics_frame
	await process_frame
	check("joystick moves actual physics body after completed ticks",player.position.distance_to(start)>0.10,str(player.position-start))
	touch(8,origin+Vector2(10,10),true)
	touch(8,origin+Vector2(10,10),false,true)
	await physics_frame
	check("secondary joystick cancellation preserves primary owner",controls.stick_adapter.get_movement().x>0.7)
	var yaw: float=player.camera_yaw
	touch(9,Vector2(820,250),true)
	drag(9,Vector2(865,280),Vector2(45,30))
	await physics_frame
	check("camera and movement work simultaneously",absf(player.camera_yaw-yaw)>0.05 and controls.stick_adapter.get_movement().x>0.7)
	var before_glow: bool=player.glow_on
	var before_button_yaw: float=player.camera_yaw
	var glow_point: Vector2=controls.action_rects["glow"].get_center()
	touch(13,glow_point,true)
	drag(13,Vector2(870,220),Vector2(-120,-60))
	await process_frame
	check("UI-owned drag never rotates camera",is_equal_approx(player.camera_yaw,before_button_yaw))
	touch(13,glow_point,false)
	await process_frame
	check("glow is immediate from its touch action",player.glow_on!=before_glow)
	touch(7,origin,false,true)
	await physics_frame
	check("canceled movement clears dedicated actions",controls.stick_adapter.get_movement().length()<0.001)
	drag(7,origin+Vector2(80,0),Vector2(25,0))
	await physics_frame
	check("canceled touch ID cannot resume without press",controls.stick_adapter.get_movement().length()<0.001)
	touch(9,Vector2(865,280),false)
	touch(15,origin,true)
	drag(15,origin+Vector2(55,0),Vector2(55,0))
	await physics_frame
	game.call("_pause")
	check("menu immediately disables touch routing",not controls.active)
	check("menu clears all touches and velocity",controls.owners.is_empty() and player.velocity.x==0.0 and player.velocity.z==0.0 and controls.stick_adapter.get_movement()==Vector2.ZERO)
	game.call("_explore")
	drag(15,origin+Vector2(90,0),Vector2(35,0))
	await physics_frame
	check("resume waits for fresh touch",controls.stick_adapter.get_movement()==Vector2.ZERO)
	touch(15,origin,false)
	touch(19,origin,true)
	drag(19,origin+Vector2(55,0),Vector2(55,0))
	await physics_frame
	check("reused input after resume remains responsive",controls.stick_adapter.get_movement().x>0.7)
	controls.reset_all("inspection")
	var safe:=Rect2(36,18,1208,680)
	var all_inside:=safe.encloses(controls.stick_adapter.get_global_rect())
	for rect: Rect2 in controls.action_rects.values(): all_inside=all_inside and safe.encloses(rect)
	check("notch safe rectangle contains controls",all_inside)
	game.settings.float_toggle=true
	game._apply_settings()
	for i in range(3): await physics_frame
	var ground_y: float=player.position.y
	var hover_point: Vector2=controls.action_rects["hover"].get_center()
	touch(23,hover_point,true)
	touch(23,hover_point,false)
	for i in range(72): await physics_frame
	await process_frame
	check("touch hover lifts predictably with desktop toggle enabled",player.touch_hover_latched and player.position.y-ground_y>0.4 and player.position.y-ground_y<0.68,str(player.position))
	touch(24,hover_point,true)
	touch(24,hover_point,false)
	for i in range(72): await physics_frame
	await process_frame
	check("second touch hover gently settles with desktop toggle enabled",not player.touch_hover_latched and player.state=="Grounded" and absf(player.position.y-ground_y)<0.05,str(player.position))
	game.settings.sensitivity=1.0
	game._apply_settings()
	var yaw_one: float=player.camera_yaw
	touch(25,Vector2(820,250),true)
	drag(25,Vector2(865,250),Vector2(45,0))
	touch(25,Vector2(865,250),false)
	var look_one: float=player.camera_yaw-yaw_one
	game.settings.sensitivity=2.0
	game._apply_settings()
	var yaw_two: float=player.camera_yaw
	touch(26,Vector2(820,250),true)
	drag(26,Vector2(865,250),Vector2(45,0))
	touch(26,Vector2(865,250),false)
	check("touch look uses the real sensitivity setting",absf(look_one)>0.05 and absf((player.camera_yaw-yaw_two)-look_one*2.0)<0.00001)
	var environment: Node=game.get("environment_controller")
	check("actual clearing installs the shared environment coordinator",is_instance_valid(environment))
	_finish()

func _finish() -> void:
	var passed:=true
	for row: Dictionary in checks: passed=passed and bool(row.passed)
	var report: Dictionary={"schema":"mush-mobile-touch-viewport/1","passed":passed,"engine":Engine.get_version_info(),"checks":checks,"physical_device_tested":false,"scope":"Real clearing, native joystick and synthetic viewport multitouch; does not prove OS hardware routing or comfort"}
	var f:=FileAccess.open(out.path_join("result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	f.close()
	print(JSON.stringify(report))
	if is_instance_valid(game):
		game.call("_quit_clean",0 if passed else 1)
		return
	quit(0 if passed else 1)
