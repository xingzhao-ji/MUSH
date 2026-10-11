extends Node
## Fixed native views of the portable scene. Source authoring proofs remain separate.
var game: Node

func _ready() -> void:
	game = get_parent()
	_run.call_deferred()

func _run() -> void:
	var output := "user://verification/capture"
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
	game.get_window().content_scale_size = Vector2i(960,960)
	game.get_window().size = Vector2i(960,960)
	game.player.teleport_safe(Vector3(4,0.08,14),0.278)
	var views: Array = []
	var passed := true
	for spec: Array in [["day",false,false],["night",true,false],["entrance-day",false,true],["entrance-night",true,true]]:
		var camera: Camera3D = game.review_camera
		camera.position = Vector3(-3,2.1,11.5) if spec[2] else Vector3(6,3.3,20)
		var target := Vector3(0,.55,5) if spec[2] else Vector3(3.2,1.65,0)
		camera.fov = 60
		camera.look_at(target)
		camera.make_current()
		game.world.set_appearance(spec[1],false,false)
		await get_tree().create_timer(4.0).timeout
		await RenderingServer.frame_post_draw
		var frame: Image = get_viewport().get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		var filename: String = spec[0]+".png"
		var saved: int = frame.save_png(output.path_join(filename))
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(frame.get_data())
		var one: bool = saved == OK and frame.get_size() == Vector2i(960,960) and game.player.is_on_floor() and game.world.snapshot_loaded and not game.world._m37_active()
		passed = passed and one
		views.append({"file":filename,"passed":one,"rgba_sha256":hash.finish().hex_encode(),"png_sha256":FileAccess.get_sha256(output.path_join(filename)),"camera_position":[camera.position.x,camera.position.y,camera.position.z],"target":[target.x,target.y,target.z],"vertical_fov":camera.fov,"night_amount":game.world.night_amount,"rain_amount":game.world.rain_amount,"lighting":game._review_lighting_state(),"player_floor":game.player.is_on_floor()})
	var report := {"schema":"mush-portable-scene-native-capture/1","passed":passed,"build":"0.6.0","native_export":not OS.has_feature("editor"),"snapshot_sha256":FileAccess.get_sha256("res://baked/clearing.res"),"source_stage":"mac060","forest_middle_layer":game.world.forest_enclosure,"world_living_motion_disabled":true,"environmental_shader_motion_frozen":false,"art_approved":false,"renderer_capabilities":game.world.get_renderer_capabilities_report(),"views":views}
	var file := FileAccess.open(output.path_join("camera.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CURRENT_CAPTURE_COMPLETE ",JSON.stringify({"passed":passed,"views":views.size()}))
	game._quit_clean(0 if passed else 1)
