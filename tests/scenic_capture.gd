extends Node
## Matched RUNTIME stills of the actual game for scenery review: two scenic and
## two ground-level player-camera views in day, night and rain, plus one HUD frame.
## Stills prove depicted states only. Design-reference images are never loaded.
const SIZE := Vector2i(1280,720)
const HOME_ANCHOR := Vector3(0.5,3.0,0.0)
const APPEARANCES: Array = [["day",false,false],["night",true,false],["rain",false,true]]
var game: Node
var output := "user://verification/scenic"

func _ready() -> void:
	game = get_parent()
	_run.call_deferred()

func _bridge_bounds() -> AABB:
	var bridge: Node = game.world.find_child("ArchedTimberBridge",true,false)
	var bounds := AABB()
	if bridge == null: return bounds
	for mesh: MeshInstance3D in bridge.find_children("*","MeshInstance3D",true,false):
		var box: AABB = mesh.global_transform*mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	return bounds

func _views() -> Array[Dictionary]:
	var bridge: AABB = _bridge_bounds()
	var overlook: Dictionary = game.prototype_scenery.overlook_pose() if is_instance_valid(game.get("prototype_scenery")) else {"position":Vector3(40,3,-40),"target":Vector3(378,100,-648),"fov":48.0}
	var middle: Vector3 = bridge.get_center()
	return [
		{"view":"scenic-home","camera":"review","position":Vector3(6,3.3,20),"target":Vector3(3.2,1.65,0),"fov":60.0,"player":Vector3(4,0.08,14),"yaw":0.278,"anchor":HOME_ANCHOR},
		{"view":"scenic-vista","camera":"review","position":Vector3(-1,2.6,22),"target":Vector3(22,9,-40),"fov":55.0,"player":Vector3(-5.0,0.08,13.0),"yaw":-0.03,"anchor":HOME_ANCHOR},
		{"view":"rim-overlook","camera":"review","position":overlook.position,"target":overlook.target,"fov":overlook.fov,"player":Vector3(4,0.08,14),"yaw":0.278,"anchor":overlook.target},
		{"view":"world-overview","camera":"review","position":Vector3(-320,620,520),"target":Vector3(150,-40,-480),"fov":62.0,"player":Vector3(4,0.08,14),"yaw":0.278,"anchor":Vector3(0,0,0)},
		{"view":"ground-path","camera":"player","player":Vector3(-2,0.08,18),"look_at":HOME_ANCHOR,"pitch":-4.0,"anchor":HOME_ANCHOR},
		{"view":"ground-bridge","camera":"player","player":Vector3(middle.x-4.0,0.08,middle.z+2.0),"look_at":middle,"pitch":-6.0,"anchor":middle,"found":bridge.size != Vector3.ZERO},
	]

func _pose(spec: Dictionary) -> Camera3D:
	var camera: Camera3D
	var yaw: float = spec.get("yaw",0.0)
	if spec.camera == "player":
		var aim: Vector3 = spec.look_at-spec.player
		yaw = atan2(-aim.x,-aim.z)
		game.player._camera_pitch = deg_to_rad(spec.pitch)
		camera = game.player._camera
	else:
		camera = game.review_camera
		camera.position = spec.position
		camera.fov = spec.fov
		camera.look_at(spec.target)
	game.player.teleport_safe(spec.player,yaw)
	camera.make_current()
	await get_tree().create_timer(1.2).timeout
	return camera

func _capture(label: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var path := output.path_join(label+".png")
	var saved: int = frame.save_png(path)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(frame.get_data())
	return {"file":label+".png","saved":saved == OK and frame.get_size() == SIZE,"rgba_sha256":hash.finish().hex_encode(),"png_sha256":FileAccess.get_sha256(path)}

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index: int in range(arguments.size()-1):
		if arguments[index] == "--report-dir": output = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	game.ui.hide()
	game.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.world.set_living_motion_enabled(false)
	game.world._time = 0.0
	game.world._m37_elapsed = 0.0
	game.get_window().content_scale_size = SIZE
	game.get_window().size = SIZE
	var prototype: Node = game.get("prototype_scenery")
	var has_prototype: bool = is_instance_valid(prototype)
	if has_prototype: prototype.set_frozen(true)
	var rows: Array = []
	var probe: Array = []
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for radius: float in [0.0, 25.0, 45.0, 60.0, 80.0, 110.0, 150.0]:
		for angle: float in [0.0, 90.0, 180.0, 270.0]:
			var x: float = radius * cos(deg_to_rad(angle))
			var z: float = 3.0 + radius * sin(deg_to_rad(angle))
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -40.0, z), 1)
			var hit: Dictionary = space.intersect_ray(query)
			probe.append({"x":x,"z":z,"y":hit.position.y if not hit.is_empty() else null})
	var hud: Dictionary = {}
	var passed := true
	for appearance: Array in APPEARANCES:
		game.world.set_appearance(appearance[1],appearance[2],false)
		await get_tree().create_timer(4.5).timeout
		for spec: Dictionary in _views():
			if has_prototype: prototype.set_overview(spec.view == "world-overview")
			var camera: Camera3D = await _pose(spec)
			var label: String = spec.view+"-"+appearance[0]
			var row: Dictionary = await _capture(label)
			if has_prototype:
				prototype.set_debug_mask(true)
				var mask: Dictionary = await _capture(label+"-mask")
				prototype.set_debug_mask(false)
				row.merge({"mask_file":mask.file,"mask_png_sha256":mask.png_sha256,"mask_rgba_sha256":mask.rgba_sha256,"mask_saved":mask.saved})
			var anchored: bool = camera.is_position_in_frustum(spec.anchor) and spec.get("found",true)
			var one: bool = row.saved and row.get("mask_saved",true) and anchored and game.player.is_on_floor() and game.world.snapshot_loaded
			passed = passed and one
			row.merge({"view":spec.view,"appearance":appearance[0],"passed":one,"camera":spec.camera,"camera_position":_v(camera.global_position),"camera_forward":_v(-camera.global_basis.z),"vertical_fov":camera.fov,"player_position":_v(game.player.global_position),"anchor":_v(spec.anchor),"anchor_in_frustum":anchored,"player_floor":game.player.is_on_floor(),"night_amount":game.world.night_amount,"rain_amount":game.world.rain_amount})
			rows.append(row)
			if spec.view == "ground-path" and appearance[0] == "day":
				game.ui.show()
				hud = await _capture("ground-path-day-hud")
				game.ui.hide()
				hud["passed"] = hud.saved
				passed = passed and hud.saved
	var debug_files: Array = []
	if has_prototype:
		# Diagnostic colours are taken in day/no-rain: restore that appearance after the
		# rain loop and let the 2 s appearance transition settle before capturing.
		game.world.set_appearance(false,false,false)
		prototype.set_overview(false)
		await get_tree().create_timer(4.5).timeout
		prototype.set_debug_colors(true)
		for spec: Dictionary in _views():
			if spec.view != "rim-overlook" and spec.view != "scenic-vista": continue
			await _pose(spec)
			var shot: Dictionary = await _capture(spec.view+"-day-debug-colors")
			shot.merge({"view":spec.view,"night_amount":game.world.night_amount,"rain_amount":game.world.rain_amount,"lighting":"unlit terrain/lake albedo; fog disabled; other materials lit"})
			debug_files.append(shot)
		prototype.set_debug_colors(false)
	var report := {"schema":"mush-scenic-capture/1","passed":passed,"build":"0.6.0","look":"prototype" if has_prototype else "baseline","prototype_report":prototype.get_report() if has_prototype else null,"views":rows,"ground_probe":probe,"debug_color_files":debug_files,"hud":hud,"world_living_motion_disabled":true,"prototype_shader_motion_frozen":prototype.frozen if has_prototype else null,"environment_wind_strength_measured":game.environment_controller.get("_applied_wind_strength"),"other_shader_freeze_state":null,"motion_note":"prototype_shader_motion_frozen is the prototype far layer only. environment_wind_strength_measured is the shared controller wind value at report time; it says nothing about clouds, water or other shaders, whose freeze state is not enforced or verified here (null). Stills do not establish motion, physics or performance.","motion_verified":false,"art_approved":false,"concept_images_loaded":false,"renderer_capabilities":game.world.get_renderer_capabilities_report()}
	var file := FileAccess.open(output.path_join("scenic.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("SCENIC_CAPTURE_COMPLETE ",JSON.stringify({"passed":passed,"views":rows.size(),"look":report.look}))
	game._quit_clean(0 if passed else 1)

func _v(value: Vector3) -> Array:
	return [value.x,value.y,value.z]
