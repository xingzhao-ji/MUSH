extends Node3D

signal mobile_release_requested(reason: String)

const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const Props = preload("res://scripts/props.gd")
const SaveScript = preload("res://scripts/save_store.gd")
const SOCKETS := {
	"main_chair": Vector3(-1.35,.6,1.1), "main_table": Vector3(1.35,.6,-1.35),
	"main_lamp": Vector3(-1.6,.6,-1.4), "annex_plant": Vector3(-3.9,.6,-1.15),
	"right_chair": Vector3(5.8,.6,1), "right_lamp": Vector3(5.5,.6,-.5)
}
const BINDINGS := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"glow":KEY_G,"float":KEY_SPACE,"interact":KEY_E,"decorate":KEY_B,"pause":KEY_ESCAPE}
var settings: Dictionary = {"float_toggle":false,"reduced_motion":false,"reduced_effects":false,"invert_y":false,"sensitivity":1.0,"prompt_scale":1.0,"music_volume":.35,"ambience_volume":.55,"effects_volume":.65,"bindings":BINDINGS.duplicate()}
var world: Node3D
var player: CharacterBody3D
var store: RefCounted
var mode := "title"
var sky := "day"
var weather := "sunny"
var door_state := "closed"
var door_time := 0.0
var door_start := 0.0
var door_target := 0.0
var room_ready := false
var room_growing := false
var growth_time := 0.0
var reservation: StaticBody3D
var restoration_state := "faded"
var restoration_tx := ""
var patch_visual_bloom := 0.0
const RESTORATION_RADIUS := 3.5
const RESTORATION_WAVE_FEATHER := 0.45
var bloom_clock := -1.0
var resident_awake := false
var path_restored := false
var mana := 100.0
var mana_delay := 0.0
var unlocked_plants: Array = ["moonbell"]
var furniture: Dictionary = {}
var furniture_nodes: Dictionary = {}
var garden: Array = []
var garden_nodes: Dictionary = {}
var garden_bloom: Dictionary = {}
var patch_node: Node3D
var patch_light: OmniLight3D
var patch_flora: Array[Node3D] = []
var resident: CharacterBody3D
var resident_visual: Node3D
var resident_time := 0.0
# Presentation only; durable awake outcome remains coupled to the planting debit.
const RESIDENT_WAKE_SECONDS := 0.8
var resident_wake_elapsed := 0.0
var resident_talking := false
var context := ""
var save_timer := -1.0
var dirty := false
var protected_save := false
var _title_save_data: Dictionary = {}
var _active_profile_loaded := false
var _mobile_interruption_reasons: Dictionary = {}
var _mobile_suspended := false
var _mobile_checkpoint_clock := 0.0
var _last_durable_player: Dictionary = {}
var _last_durable_glow := false
var toast_time := 0.0
var intro_time := 0.0
var ui: CanvasLayer
var modal: PanelContainer
var content: VBoxContainer
var prompt: Label
var notice: Label
var mana_label: Label
var helper: Label
var reticle: Label
var selected_socket := "main_chair"
var preview_style := ""
var preview_node: Node3D
var decor_preview := false
var garden_ghost: Node3D
var garden_target := Vector3.ZERO
var garden_valid := false
var garden_type := "moonbell"
var rebind_action := ""
var settings_return := "pause"
var appearance_sky := "day"
var appearance_weather := "sunny"
var last_device := "keyboard"
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var _effect_streams: Dictionary = {}
var review_target:Vector3=Vector3(3.2,1.65,0)
var review_camera: Camera3D
var verification := false
var _quitting := false
var _audio_glow_state := false
var _step_distance := 0.0
var _last_step_position := Vector3.ZERO

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_setup_input()
	world=WorldScript.new()
	world.name="WorldGeometry"
	add_child(world)
	player=PlayerScript.new()
	player.name="Player"
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.position=Vector3(-2,0,18)
	player.feedback.connect(_toast)
	store=SaveScript.new()
	_build_gameplay()
	_build_ui()
	_build_audio()
	_apply_settings()
	review_camera=Camera3D.new()
	review_camera.name="FixedReviewCamera"
	review_camera.position=Vector3(6,3.3,20)
	review_camera.fov=60
	add_child(review_camera)
	review_camera.look_at(review_target)
	verification="--verify" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--benchmark" in OS.get_cmdline_user_args() or "--traversal" in OS.get_cmdline_user_args() or "--crash-probe" in OS.get_cmdline_user_args()
	if verification:
		store.directory="user://verification"
		_start_new()
	else:
		_title()
	get_tree().auto_accept_quit=false
	Input.joy_connection_changed.connect(_controller_change)
	if "--crash-probe" in OS.get_cmdline_user_args():
		_start_crash_probe.call_deferred()
	if "--verify" in OS.get_cmdline_user_args():
		_start_acceptance.call_deferred()
	if "--benchmark" in OS.get_cmdline_user_args() or "--traversal" in OS.get_cmdline_user_args():
		_start_benchmark.call_deferred()

func _setup_input() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action): InputMap.add_action(action,.15)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode=int(settings.bindings.get(action,BINDINGS[action]))
		InputMap.action_add_event(action,key)
	var buttons := {"glow":JOY_BUTTON_X,"float":JOY_BUTTON_A,"interact":JOY_BUTTON_B,"decorate":JOY_BUTTON_Y,"pause":JOY_BUTTON_START}
	for action: String in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index=buttons[action]
		InputMap.action_add_event(action,event)
	for pair: Array in [["move_left",JOY_AXIS_LEFT_X,-1.0],["move_right",JOY_AXIS_LEFT_X,1.0],["move_forward",JOY_AXIS_LEFT_Y,-1.0],["move_back",JOY_AXIS_LEFT_Y,1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis=pair[1]
		event.axis_value=pair[2]
		InputMap.action_add_event(pair[0],event)

func _build_gameplay() -> void:
	patch_node=Node3D.new()
	patch_node.position=Vector3(13,0,-1)
	add_child(patch_node)
	Props.cylinder(patch_node,Vector3(0,.025,0),.65,.05,Props.material(Color("706857")))
	patch_light=OmniLight3D.new()
	patch_light.position.y=.6
	patch_light.omni_range=3
	patch_light.light_color=Color("b5caff")
	patch_light.light_energy=.7
	patch_light.visible=false
	patch_node.add_child(patch_light)
	for i in range(18):
		var a: float=i*2.39996
		var r: float=1+float(i%5)*.45
		var f:=Props.plant(.9)
		f.position=Vector3(13+sin(a)*r,.015,-1+cos(a)*r)
		f.scale=Vector3.ONE*(.7+float(i%3)*.16)
		add_child(f)
		patch_flora.append(f)
	var soil:=Node3D.new()
	soil.position=Vector3(-4.8,.02,3.5)
	add_child(soil)
	Props.box(soil,Vector3.ZERO,Vector3(2,.035,2),Props.material(Color("725c45")))
	for x in [-1.03,1.03]: Props.box(soil,Vector3(x,.07,0),Vector3(.065,.12,2.1),Props.material(Color("a08765")))
	for z in [-1.03,1.03]: Props.box(soil,Vector3(0,.07,z),Vector3(2.1,.12,.065),Props.material(Color("a08765")))
	resident=CharacterBody3D.new()
	resident.name="ResidentPlaceholder"
	resident.position=Vector3(14,0,-2)
	resident.collision_layer=4
	resident.collision_mask=1|16
	resident.floor_snap_length=.3
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.height=.8
	capsule.radius=.22
	shape.shape=capsule
	shape.position.y=.4
	resident.add_child(shape)
	resident_visual=Node3D.new()
	resident.add_child(resident_visual)
	var cloth:=Props.material(Color("9aaa85"))
	Props.sphere(resident_visual,Vector3(0,.35,0),Vector3(.5,.55,.4),cloth)
	Props.sphere(resident_visual,Vector3(0,.68,-.025),Vector3(.41,.38,.36),Props.material(Color("e3d5b1")))
	for x in [-.1,.1]:
		Props.sphere(resident_visual,Vector3(x,.06,-.045),Vector3(.14,.12,.24),cloth)
		Props.sphere(resident_visual,Vector3(x,.70,-.19),Vector3(.026,.026,.018),Props.material(Color("343429")))
	add_child(resident)
	_update_patch(0.0)
	reservation=StaticBody3D.new()
	reservation.name="GrowthReservation"
	reservation.collision_layer=0
	reservation.collision_mask=2
	var c:=CollisionShape3D.new()
	var b:=BoxShape3D.new()
	b.size=Vector3(5,4,4.6)
	c.shape=b
	c.position=Vector3(4.8,2,.6)
	reservation.add_child(c)
	add_child(reservation)

func _build_ui() -> void:
	ui=CanvasLayer.new()
	add_child(ui)
	var theme:=Theme.new()
	theme.default_font_size=19
	var panel_style:=StyleBoxFlat.new()
	panel_style.bg_color=Color("17251feb")
	panel_style.border_color=Color("89977b")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left=30
	panel_style.content_margin_right=30
	panel_style.content_margin_top=26
	panel_style.content_margin_bottom=24
	theme.set_stylebox("panel","PanelContainer",panel_style)
	for style_name in ["normal","hover","pressed","focus"]:
		var st:=StyleBoxFlat.new()
		st.bg_color=Color("354c3d") if style_name=="normal" else Color("54735b")
		st.set_corner_radius_all(7)
		st.content_margin_top=10
		st.content_margin_bottom=10
		st.content_margin_left=15
		st.content_margin_right=15
		if style_name=="focus":
			st.bg_color=Color(0,0,0,0)
			st.border_color=Color("f5db9f")
			st.set_border_width_all(2)
		theme.set_stylebox(style_name,"Button",st)
	theme.set_color("font_color","Label",Color("f0ead8"))
	theme.set_color("font_color","Button",Color("f0ead8"))
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=theme
	ui.add_child(root)
	modal=PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left=-290
	modal.offset_right=290
	modal.offset_top=-330
	modal.offset_bottom=330
	root.add_child(modal)
	var scroll:=ScrollContainer.new()
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	scroll.add_child(content)
	prompt=_overlay_label(root,Control.PRESET_CENTER_BOTTOM,Vector2(-400,-96),Vector2(400,-46))
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_shadow_color",Color.BLACK)
	prompt.add_theme_constant_override("shadow_outline_size",7)
	notice=_overlay_label(root,Control.PRESET_CENTER_TOP,Vector2(-430,28),Vector2(430,105))
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_shadow_color",Color.BLACK)
	notice.add_theme_constant_override("shadow_outline_size",6)
	mana_label=_overlay_label(root,Control.PRESET_BOTTOM_RIGHT,Vector2(-230,-80),Vector2(-24,-26))
	mana_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	mana_label.add_theme_constant_override("shadow_outline_size",5)
	helper=_overlay_label(root,Control.PRESET_TOP_LEFT,Vector2(28,28),Vector2(660,140))
	helper.add_theme_font_size_override("font_size",16)
	helper.add_theme_color_override("font_shadow_color",Color.BLACK)
	helper.add_theme_constant_override("shadow_outline_size",5)
	reticle=_overlay_label(root,Control.PRESET_CENTER,Vector2(-6,-12),Vector2(6,12))
	reticle.text="·"

func _overlay_label(root: Control, preset: int, low: Vector2, high: Vector2) -> Label:
	var label:=Label.new()
	label.set_anchors_and_offsets_preset(preset)
	label.offset_left=low.x
	label.offset_top=low.y
	label.offset_right=high.x
	label.offset_bottom=high.y
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func _clear_menu(title: String, description: String = "") -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	modal.show()
	var heading:=Label.new()
	heading.text=title
	heading.add_theme_font_size_override("font_size",30)
	content.add_child(heading)
	if not description.is_empty(): _label(description)

func _label(text: String) -> Label:
	var label:=Label.new()
	label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func _button(text: String, action: Callable, disabled: bool = false) -> Button:
	var button:=Button.new()
	button.text=text
	button.disabled=disabled
	button.pressed.connect(action)
	content.add_child(button)
	return button

func _focus_first() -> void:
	for child: Node in content.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			var menu_scroll: ScrollContainer = modal.get_child(0) as ScrollContainer
			menu_scroll.set_deferred("scroll_vertical",0)
			return

func _enter_menu(new_mode: String) -> void:
	mobile_release_requested.emit("menu")
	if new_mode!="controls": rebind_action=""
	mode=new_mode
	player.enabled=false
	player.release_controls()
	_reset_footstep_cadence()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_tree().paused=true
	prompt.text=""
	reticle.hide()

func _explore() -> void:
	if _mobile_suspended: return
	mobile_release_requested.emit("explore")
	rebind_action=""
	mode="explore"
	get_tree().paused=false
	player.release_controls()
	_reset_footstep_cadence()
	player.enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if verification else Input.MOUSE_MODE_CAPTURED
	modal.hide()
	reticle.show()
	resident_talking=false

func _title() -> void:
	# A fast Back tap must not reload stale settings before the debounce fires.
	if dirty and not protected_save and not _save_now(true): return
	_active_profile_loaded=false
	_enter_menu("title")
	_clear_menu("Mushroom Clearing","A small forest to wander, a home to make your own.\n\nPlant a little light. Let the world wake at your pace.")
	var result: Dictionary=store.load_snapshot()
	protected_save=result.source in ["future","corrupt","error"]
	_title_save_data=result.data.duplicate(true) if result.ok else {}
	if result.ok:
		if not dirty:
			settings=result.data.settings.duplicate(true)
			_setup_input()
			_apply_settings()
		_button("Continue",func(): _continue_from_title(); _toast(result.get("error","")))
	elif not str(result.error).is_empty():
		_label(str(result.error))
		protected_save=true
	_button("Begin a new clearing",_start_new)
	_button("Settings & controls",_settings_menu)
	_label("%s/%s/%s/%s move · mouse look · %s %s float\n%s glow · %s interact · %s decorate · %s pause" % [_key_hint("move_forward"),_key_hint("move_left"),_key_hint("move_back"),_key_hint("move_right"),"toggle" if settings.float_toggle else "hold",_key_hint("float"),_key_hint("glow"),_key_hint("interact"),_key_hint("decorate"),_key_hint("pause")])
	_focus_first()

func _continue_from_title() -> void:
	if _title_save_data.is_empty(): return
	var pending_settings:bool=dirty
	var data:Dictionary=_title_save_data.duplicate(true)
	# Preserve edits made on the title screen, including a failed/unsaved edit.
	data.settings=settings.duplicate(true)
	_load_data(data)
	if pending_settings: _schedule_save()
	_explore()

func _start_new() -> void:
	if protected_save:
		_enter_menu("new_confirm")
		_clear_menu("A fresh clearing","Your existing save files will be kept. This session can be explored without saving until the incompatible or damaged save is recovered.")
		_button("Begin without replacing the save",func(): _reset_world(); _explore())
		_button("Back",_title)
		_focus_first()
		return
	_reset_world()
	_explore()
	intro_time=9.0
	if not verification: _schedule_save()

func _reset_world() -> void:
	_active_profile_loaded=true
	_mobile_checkpoint_clock=0.0
	_last_durable_player.clear()
	mobile_release_requested.emit("reset")
	sky="day"
	weather="sunny"
	mana=100.0
	mana_delay=0.0
	restoration_state="faded"
	restoration_tx=""
	resident_awake=false
	resident_wake_elapsed=0.0
	resident_visual.rotation.z=1.15
	resident_visual.position.y=-.02
	resident.position=Vector3(14,0,-2)
	resident.velocity=Vector3.ZERO
	unlocked_plants=["moonbell"]
	path_restored=false
	patch_visual_bloom=0
	bloom_clock=-1
	room_ready=false
	room_growing=false
	world.set_room_ready(false)
	world.set_room_growth(0)
	reservation.collision_layer=0
	door_state="closed"
	world.door_hinge.rotation.y=0
	furniture.clear()
	garden.clear()
	garden_bloom.clear()
	_rebuild_furniture()
	_rebuild_garden()
	_update_patch(0)
	player.teleport_safe(Vector3(-2,0,18),0)
	_reset_footstep_cadence()
	player.set_glow(false)
	world.set_appearance(false,false,settings.reduced_effects)

func _notification(what: int) -> void:
	if not is_instance_valid(player): return
	if not verification:
		if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
			mobile_set_interruption("focus",true)
		elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
			mobile_set_interruption("focus",false)
		elif what==NOTIFICATION_APPLICATION_PAUSED:
			mobile_set_interruption("background",true)
		elif what==NOTIFICATION_APPLICATION_RESUMED:
			mobile_set_interruption("background",false)
		elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
			_cancel()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if not verification and (dirty or _active_profile_loaded):
			if not _save_now(true): return
		_quit_clean()

func mobile_audio_interruption_changed(interrupted:bool) -> void:
	# A real platform adapter must call this for audio-only interruptions.
	# Focus/background notifications alone do not prove native audio coverage.
	mobile_set_interruption("audio",interrupted)

func mobile_set_interruption(reason:String,interrupted:bool) -> void:
	if reason not in ["focus","background","audio"] or _quitting: return
	if interrupted: _mobile_interruption_reasons[reason]=true
	else: _mobile_interruption_reasons.erase(reason)
	var suspended:bool=not _mobile_interruption_reasons.is_empty()
	if suspended==_mobile_suspended: return
	_mobile_suspended=suspended
	player.release_controls()
	mobile_release_requested.emit("suspend" if suspended else "resume")
	if suspended:
		# Title settings/error menus do not have an active clearing to resume.
		if _active_profile_loaded and mode!="title": _pause()
		if dirty or _active_profile_loaded: _save_now(true)
	# Music may return after all observed interruptions; the environmental forest
	# bed stays paused until Keep wandering. Preserve both stream resources.
	for node:AudioStreamPlayer in [music,ambience]:
		if is_instance_valid(node): node.stream_paused=suspended or (node==ambience and get_tree().paused)
	if suspended:
		# Confirmation/footstep one-shots must not replay after a long interruption.
		for node:AudioStreamPlayer in [effects,footsteps]:
			if is_instance_valid(node): node.stop()

func _controller_change(_device: int, connected: bool) -> void:
	if not connected and mode=="explore":
		_pause()
		_toast("Controller disconnected. Reconnect or use keyboard and mouse.")

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		last_device="controller"
	elif event is InputEventJoypadMotion and absf(event.axis_value)>.2:
		last_device="controller"
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length_squared()>.25):
		last_device="keyboard"
	if mode=="controls" and not rebind_action.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var code: int=event.physical_keycode
		if code==KEY_ESCAPE or event.is_action_pressed("pause"):
			rebind_action=""
			_controls_menu()
			return
		for action: String in settings.bindings:
			if action!=rebind_action and settings.bindings[action]==code:
				_toast("That key is already used by "+action.replace("_"," ")+".")
				return
		settings.bindings[rebind_action]=code
		rebind_action=""
		_setup_input()
		_controls_menu()
		_schedule_save()
		return
	if event.is_action_pressed("pause") and not (event is InputEventKey and event.echo):
		get_viewport().set_input_as_handled()
		_cancel()
		return
	if mode=="garden_place" and ((event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A and event.pressed)):
		get_viewport().set_input_as_handled()
		if garden_valid:
			plant_garden(garden_target,garden_type)
			_end_garden_preview()
		else: _toast("Choose open soil inside the garden, away from other plants.")

func _unhandled_input(event: InputEvent) -> void:
	if mode!="explore": return
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact()
	elif event.is_action_pressed("decorate"):
		get_viewport().set_input_as_handled()
		if _inside_home() and player.state=="Grounded" and player.is_on_floor(): _decorate_menu()
		else: _toast("Decorate while standing inside your home.")

func _cancel() -> void:
	if mode=="explore": _pause()
	elif mode=="pause": _explore()
	elif mode=="garden_place": _end_garden_preview()
	elif mode=="decorate":
		if decor_preview:
			_cancel_decor_preview()
			_decorate_menu()
		else: _explore()
	elif mode=="audio_credits": _settings_menu()
	elif mode=="settings" or mode=="controls":
		rebind_action=""
		if settings_return=="title": _title()
		else: _pause()
	elif mode=="appearance": _pause()
	elif mode=="save_error": _return_after_save_error()
	elif mode=="title": pass
	elif mode=="growth_preview":
		world.set_room_growth(0)
		_explore()
	else:
		_cancel_decor_preview()
		_explore()

func _reset_footstep_cadence() -> void:
	_step_distance=0.0
	_last_step_position=player.position if is_instance_valid(player) else Vector3.ZERO

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		_reset_footstep_cadence()
		return
	if mode=="garden_place" and last_device=="controller":
		var stick:Vector2=Input.get_vector("move_left","move_right","move_forward","move_back")
		garden_target.x=clampf(garden_target.x+stick.x*delta,-5.8,-3.8)
		garden_target.z=clampf(garden_target.z+stick.y*delta,2.5,4.5)
	if player.glow_on!=_audio_glow_state:
		_audio_glow_state=player.glow_on
		_play_effect("glow")
		_schedule_save()
	var step_offset:Vector3=player.position-_last_step_position
	var step_delta:float=Vector2(step_offset.x,step_offset.z).length()
	# Audible contacts follow actual travel, not requested input or foot-bone phase.
	var grounded_walk:bool=mode=="explore" and player.enabled and player.state=="Grounded" and player.is_on_floor() and not bool(player.get("_pending_teleport")) and step_offset.length()<.2
	if grounded_walk:
		_step_distance+=step_delta
		if _step_distance>=.64:
			_step_distance=0.0
			_play_effect("footstep")
	else:
		_step_distance=0.0
	_last_step_position=player.position
	ambience.pitch_scale=.92 if sky=="night" else 1.0
	_update_door(delta)
	if room_growing:
		growth_time+=delta
		world.set_room_growth(clampf(growth_time/4.0,0,1))
		if growth_time>=4: _finish_growth()
	if mana_delay>0:
		mana_delay=maxf(0,mana_delay-delta)
	else: mana=minf(100,mana+10*delta)
	if bloom_clock>=0:
		bloom_clock+=delta
		patch_visual_bloom=clampf(bloom_clock/2,0,1)
		_update_patch(patch_visual_bloom)
		if bloom_clock>=3: bloom_clock=-1
	for id: String in garden_bloom.keys():
		garden_bloom[id]+=delta
		if garden_nodes.has(id):
			var progress:float=clampf(float(garden_bloom[id])/2,0,1)
			garden_nodes[id].scale=Vector3.ONE*(.25+.75*progress)
		if garden_bloom[id]>=2: garden_bloom.erase(id)
	_update_resident(delta)
	if mode=="explore": _update_context()

func _process(delta: float) -> void:
	# This Node runs ALWAYS: paused settings are durable without resuming play.
	# Background hooks are supplementary; accepted paid changes already commit.
	if save_timer>=0 and not _mobile_suspended:
		save_timer-=delta
		if save_timer<=0:
			save_timer=-1
			_save_now()
	if _active_profile_loaded and mode=="explore" and not get_tree().paused and not _mobile_suspended:
		_mobile_checkpoint_clock+=delta
		if _mobile_checkpoint_clock>=5.0:
			_mobile_checkpoint_clock=0.0
			# A bounded checkpoint policy for safe support/yaw, not a phone I/O budget.
			# Paid progress still saves synchronously before its presentation begins.
			var checkpoint:Dictionary=_snapshot()
			if var_to_bytes(checkpoint.player)!=var_to_bytes(_last_durable_player) or checkpoint.glow!=_last_durable_glow:
				_save_now(true)
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0: notice.text=""
	if intro_time>0 and mode=="explore":
		intro_time-=delta
		helper.text="%s/%s/%s/%s  wander · Mouse  look\n%s %s  float · %s  glow · %s  interact\n%s  sky, weather & settings" % [_key_hint("move_forward"),_key_hint("move_left"),_key_hint("move_back"),_key_hint("move_right"),"Toggle" if settings.float_toggle else "Hold",_key_hint("float"),_key_hint("glow"),_key_hint("interact"),_key_hint("pause")]
	else: helper.text=""
	if mode=="garden_place": _update_garden_preview()
	mana_label.visible=mode=="explore" and (mana<99.95 or context=="patch_grow" or context.begins_with("garden_grow:"))
	mana_label.text="Magic  %d / 100" % int(mana)
	if verification and "--capture" in OS.get_cmdline_user_args() and not has_meta("capture_started"):
		set_meta("capture_started",true)
		_capture_review()

func _key_hint(action: String) -> String:
	return OS.get_keycode_string(int(settings.bindings.get(action,BINDINGS[action])))

func _action_hint(action: String, controller_hint: String) -> String:
	return _key_hint(action) if last_device=="keyboard" else controller_hint

func _inside_home() -> bool:
	var p:Vector3=player.position
	return p.y>.35 and (Vector2(p.x,p.z).length()<2.65 or Vector2(p.x+4.1,p.z+.4).length()<1.65 or (room_ready and Vector2(p.x-4.95,p.z-.6).length()<1.5))

func _update_context() -> void:
	context=""
	var text: String=""
	var p: Vector3=player.position
	if p.distance_to(Vector3(0,.6,3))<1.8:
		context="door"
		text="Open the door" if door_state=="closed" else "Close the door" if door_state=="open" else "Door moving…"
	elif not room_ready and p.distance_to(Vector3(2,.6,.6))<1.3 and _inside_home():
		context="room"
		text="Grow an attached room" if not room_growing else "Room growing…"
	elif p.distance_to(resident.position)<1.5 and (restoration_state=="bloomed" or p.distance_to(resident.position)<p.distance_to(Vector3(13,0,-1))):
		context="resident"
		text="Talk to your neighbour" if resident_awake and bloom_clock<0 and resident_wake_elapsed>=RESIDENT_WAKE_SECONDS else "Your neighbour is resting"
	elif p.distance_to(Vector3(13,0,-1))<1.6:
		context="patch_plant" if restoration_state=="faded" else "patch_grow" if restoration_state=="planted" else "patch_done"
		text="Plant a luminous seed" if context=="patch_plant" else "Help the plant bloom · 25 magic" if context=="patch_grow" else "This little place is awake"
	elif p.distance_to(resident.position)<1.5:
		context="resident"
		text="Talk to your neighbour" if resident_awake and bloom_clock<0 and resident_wake_elapsed>=RESIDENT_WAKE_SECONDS else "Your neighbour is resting"
	else:
		for plant:Dictionary in garden:
			var v:=Vector3(plant.position[0],plant.position[1],plant.position[2])
			if plant.state=="seed" and p.distance_to(v)<1:
				context="garden_grow:"+plant.id
				text="Help the plant bloom · 25 magic"
				break
		if context.is_empty() and p.distance_to(Vector3(-4.8,0,3.5))<2.0:
			context="garden"
			text="Plant in your garden · %d / 8" % garden.size()
		elif context.is_empty() and _inside_home():
			text=_action_hint("decorate","Y")+"  ·  Make this home your own"
	if not context.is_empty() and context!="patch_done":
		if player.state!="Grounded" or not player.is_on_floor(): text="Land to interact"
		else: text=_action_hint("interact","B")+"  ·  "+text
	prompt.text=text

func _interact() -> void:
	if player.state!="Grounded" or not player.is_on_floor():
		_toast("Land before interacting.")
		return
	match context:
		"door": request_door()
		"room":
			if not room_growing: _growth_menu()
		"patch_plant": _plant_menu(false)
		"patch_grow": _grow_plant_menu("")
		"garden": _plant_menu(true)
		"resident":
			if resident_awake and bloom_clock<0 and resident_wake_elapsed>=RESIDENT_WAKE_SECONDS: _dialogue()
			elif resident_awake and bloom_clock<0: _toast("Your neighbour is waking. Give them a moment.")
			else: _toast("A luminous plant nearby might bring a little life back.")
	if context.begins_with("garden_grow:"): _grow_plant_menu(context.trim_prefix("garden_grow:"))

func request_door() -> bool:
	if door_state!="closed" and door_state!="open": return false
	var p:Vector3=player.position
	# Reserve the inward right-hinge sector. A player in it is never pushed by the leaf.
	if p.y<2.7 and p.x>-.95 and p.x<1.25 and p.z>1.1 and p.z<3.12:
		_toast("Step clear of the door's swing.")
		return false
	door_start=world.door_hinge.rotation.y
	door_target=deg_to_rad(-95) if door_state=="closed" else 0.0
	door_state="opening" if door_state=="closed" else "closing"
	door_time=0
	_play_effect("door")
	return true

func _update_door(delta: float) -> void:
	if door_state!="opening" and door_state!="closing": return
	if door_state=="closing":
		var p:Vector3=player.position
		if p.y<2.7 and p.x>-.95 and p.x<1.25 and p.z>1.1 and p.z<3.12:
			door_start=world.door_hinge.rotation.y
			door_target=deg_to_rad(-95)
			door_state="opening"
			door_time=0
			_toast("Door held open while the entry is occupied.")
	door_time+=delta
	world.door_hinge.rotation.y=lerpf(door_start,door_target,smoothstep(0,.6,door_time))
	if door_time>=.6:
		door_state="open" if door_target!=0 else "closed"
		_schedule_save()

func _growth_menu() -> void:
	_enter_menu("growth_preview")
	world.set_room_growth(.12)
	_clear_menu("Room to grow","A small room can grow from the east arch. This costs no magic.")
	_button("Grow this room",func():
		world.set_room_growth(0)
		if begin_growth() and mode!="save_error": _explore())
	_button("Cancel",func(): world.set_room_growth(0); _explore())
	_focus_first()

func begin_growth() -> bool:
	if room_ready or room_growing: return false
	var p:Vector3=player.position
	if p.x>2.0 and p.x<7.6 and p.z> -2.0 and p.z<3.2:
		_toast("Move away from the room space.")
		return false
	if _room_space_obstructed():
		_toast("The room space is obstructed. Clear it before growing.")
		return false
	if not world.has_method("set_room_ready"):
		_toast("The room assets are unavailable. Your home is safe.")
		return false
	if not _save_now(): return false
	room_growing=true
	growth_time=0
	reservation.collision_layer=4
	world.set_room_growth(.01)
	_play_effect("growth")
	return true

func _room_space_obstructed() -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(5,5.4,4.6)
	query.shape=box
	query.transform=Transform3D(Basis.IDENTITY,Vector3(4.8,3.35,.6))
	query.collision_mask=1|2|4|16
	var excluded:Array[RID]=[player.get_rid(),reservation.get_rid()]
	var original_home:Node=world.get_node("MushroomHome")
	for body:Node in original_home.find_children("*","CollisionObject3D",true,false):
		excluded.append(body.get_rid())
	query.exclude=excluded
	return not get_world_3d().direct_space_state.intersect_shape(query,64).is_empty()

func _finish_growth() -> void:
	world.set_room_ready(true)
	room_ready=true
	room_growing=false
	world.set_room_growth(0)
	reservation.collision_layer=0
	_toast("A little more room to call home.")
	_schedule_save()

func _plant_menu(is_garden: bool) -> void:
	_enter_menu("plant_preview")
	_clear_menu("A little light","Seeds unlock a plant type and can be used again. Planting costs no magic.")
	_button("Moonbell  ·  plant",func():
		if is_garden: _begin_garden_preview("moonbell")
		else: plant_patch(); _explore())
	_button("Sunfern  ·  seed not yet unlocked",func(): pass,true)
	_button("Cancel",_explore)
	_focus_first()

func plant_patch() -> bool:
	if restoration_state!="faded": return false
	restoration_state="planted"
	_update_patch(0)
	_schedule_save()
	return true

func _grow_plant_menu(id: String) -> void:
	_enter_menu("grow_plant")
	_clear_menu("Help it bloom","25 magic · grows in a few seconds\nYour magic returns on its own. You can keep wandering.")
	_button("Grow  ·  %d magic available" % int(mana),func():
		if cast_plant(id) and mode!="save_error": _explore(),mana<25)
	_button("Cancel",_explore)
	_focus_first()

func cast_plant(id: String = "") -> bool:
	if mana<25: _toast("This plant needs 25 magic. Yours is returning."); return false
	var target:Dictionary={}
	if id.is_empty():
		if restoration_state!="planted": return false
	else:
		for plant:Dictionary in garden:
			if plant.id==id: target=plant; break
		if target.is_empty() or target.state!="seed": return false
	mana-=25
	mana_delay=1
	var tx: String="cast_%d_%d" % [Time.get_unix_time_from_system()*1000,Time.get_ticks_usec()]
	if id.is_empty():
		restoration_state="bloomed"
		restoration_tx=tx
		resident_awake=true
		path_restored=true
		bloom_clock=0
		_update_patch(.05)
	else:
		target.state="bloomed"
		target.transaction_id=tx
		_rebuild_garden()
		garden_bloom[id]=0.0
		garden_nodes[id].scale=Vector3.ONE*.25
	# Debit + final logical outcome are one durable snapshot; visuals are presentation.
	# An unfinished structural preview is omitted, while paid plant outcomes remain durable.
	_save_now(true)
	_play_effect("growth")
	_toast("A little light takes root.")
	return true

func _update_patch(progress: float) -> void:
	patch_light.visible=restoration_state=="bloomed" and progress>0
	var old:=patch_node.get_node_or_null("Plant")
	if old: old.free()
	if restoration_state!="faded":
		var plant:=Props.plant(progress)
		plant.name="Plant"
		plant.position.y=.06
		plant.scale=Vector3.ONE*1.65
		patch_node.add_child(plant)
	for f:Node3D in patch_flora:
		var flora_progress:float=_flora_restoration_amount(f,progress)
		f.scale.y=.45+.55*flora_progress
		for mesh:Node in f.get_children():
			if mesh is MeshInstance3D:
				mesh.material_override.albedo_color=Color("828b73").lerp(Color("aabbe5"),flora_progress)


func _flora_restoration_amount(flora:Node3D,completed_progress:float) -> float:
	# The plant opens in0–2s; existing nearby flora responds outward in2–3s.
	# This is presentation only: paid flags are already saved and collision stays.
	var offset:Vector3=flora.global_position-patch_node.global_position
	var distance:float=Vector2(offset.x,offset.z).length()
	if distance>RESTORATION_RADIUS: return 0.0
	if restoration_state=="bloomed" and bloom_clock>=0.0:
		var spread:float=clampf(bloom_clock-2.0,0.0,1.0)
		var edge:float=spread*(RESTORATION_RADIUS+RESTORATION_WAVE_FEATHER)
		return clampf((edge-distance)/RESTORATION_WAVE_FEATHER,0.0,1.0)
	# Reset is muted; already-paid load and ordinary Skip apply the final state.
	return clampf(completed_progress,0.0,1.0) if restoration_state=="bloomed" else 0.0

func _begin_garden_preview(type: String) -> void:
	if garden.size()>=8: _toast("Your garden has room for eight plants."); return
	mode="garden_place"
	get_tree().paused=false
	player.enabled=false
	modal.hide()
	garden_type=type
	garden_target=Vector3(-4.8,0,3.5)
	garden_ghost=Props.plant(.2,type)
	add_child(garden_ghost)
	prompt.text="Click open garden soil to plant  ·  "+_key_hint("pause")+" cancel"
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _update_garden_preview() -> void:
	if not is_instance_valid(garden_ghost): return
	if last_device=="controller":
		garden_valid=_garden_allowed(garden_target)
		garden_ghost.position=garden_target
		garden_ghost.visible=true
		garden_ghost.scale=Vector3.ONE*(1.0 if garden_valid else .65)
		prompt.text="Left stick: choose soil · A: plant · Menu: cancel"
		return
	var camera:Camera3D=player.get_camera()
	var mouse:=get_viewport().get_mouse_position()
	var from:Vector3=camera.project_ray_origin(mouse)
	var to:Vector3=from+camera.project_ray_normal(mouse)*80
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	garden_valid=false
	if not hit.is_empty():
		garden_target=hit.position
		garden_target.x=snappedf(garden_target.x,.25)
		garden_target.z=snappedf(garden_target.z,.25)
		garden_target.y=0
		garden_valid=_garden_allowed(garden_target)
		garden_ghost.position=garden_target
	garden_ghost.visible=not hit.is_empty()
	garden_ghost.scale=Vector3.ONE*(1.0 if garden_valid else .65)
	prompt.text=("Click to plant" if garden_valid else "Choose open soil inside the wooden garden border")+"  ·  "+_key_hint("pause")+" cancel"

func _garden_allowed(pos:Vector3) -> bool:
	if garden.size()>=8 or pos.x< -5.8 or pos.x> -3.8 or pos.z<2.5 or pos.z>4.5 or absf(pos.y)>.1: return false
	for p:Dictionary in garden:
		if Vector2(pos.x-p.position[0],pos.z-p.position[2]).length()<.35: return false
	var query:=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*3,pos-Vector3.UP*.1,1|4|16|32)
	var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.normal.y>.86 and absf(hit.position.y-pos.y)<.06

func plant_garden(pos:Vector3,type:String="moonbell") -> bool:
	if not type in unlocked_plants or not _garden_allowed(pos): return false
	garden.append({"id":"garden_%d" % Time.get_ticks_usec(),"type":type,"position":[pos.x,0.0,pos.z],"state":"seed","transaction_id":""})
	_rebuild_garden()
	_schedule_save()
	return true

func _end_garden_preview() -> void:
	if is_instance_valid(garden_ghost): garden_ghost.queue_free()
	garden_ghost=null
	_explore()

func _rebuild_garden() -> void:
	for node:Node3D in garden_nodes.values(): node.free()
	garden_nodes.clear()
	for plant:Dictionary in garden:
		var node:=Props.plant(1 if plant.state=="bloomed" else 0,plant.type)
		node.position=Vector3(plant.position[0],plant.position[1],plant.position[2])
		add_child(node)
		garden_nodes[plant.id]=node

func _decorate_menu() -> void:
	_enter_menu("decorate")
	_clear_menu("Make yourself at home","Choose a place, then try a style. Apply keeps it; Cancel puts it back.")
	for socket: String in SOCKETS:
		if socket.begins_with("right_") and not room_ready: continue
		_button(socket.replace("_"," ").capitalize()+"  ·  "+str(furniture.get(socket,"empty")).replace("_"," "),func(): _socket_menu(socket))
	_button("Done",func(): _cancel_decor_preview(); _explore())
	_focus_first()

func _socket_menu(socket: String) -> void:
	_cancel_decor_preview()
	selected_socket=socket
	_enter_menu("decorate")
	_clear_menu(socket.replace("_"," ").capitalize(),"Try a style in this fixed place. Walkways stay clear.")
	var kind: String=socket.split("_")[1]
	for style:String in [kind+"_honey",kind+"_moss",""]:
		_button("Empty" if style.is_empty() else style.replace("_"," ").capitalize(),func(): _preview_furniture(style))
	_button("Back to places",_decorate_menu)
	_focus_first()

func _preview_furniture(style:String) -> void:
	_cancel_decor_preview()
	preview_style=style
	decor_preview=true
	if furniture_nodes.has(selected_socket): furniture_nodes[selected_socket].hide()
	if not style.is_empty():
		preview_node=Props.furniture(selected_socket.split("_")[1],style)
		preview_node.position=SOCKETS[selected_socket]
		for child:Node in preview_node.get_children():
			if child is StaticBody3D: child.collision_layer=0
		add_child(preview_node)
	_clear_menu("Try "+("Empty" if style.is_empty() else style.replace("_"," ")),"This is a preview. Your previous choice is kept until you apply.")
	_button("Apply",func():
		if commit_furniture(selected_socket,style):
			_cancel_decor_preview()
			_decorate_menu())
	_button("Cancel preview",func(): _cancel_decor_preview(); _socket_menu(selected_socket))
	_button("Done without applying",func(): _cancel_decor_preview(); _explore())
	_focus_first()

func _cancel_decor_preview() -> void:
	if is_instance_valid(preview_node): preview_node.free()
	preview_node=null
	if furniture_nodes.has(selected_socket): furniture_nodes[selected_socket].show()
	decor_preview=false

func commit_furniture(socket:String,style:String) -> bool:
	if not SOCKETS.has(socket): return false
	if socket.begins_with("right_") and not room_ready: return false
	var kind:String=socket.split("_")[1]
	if style!="" and style!=kind+"_honey" and style!=kind+"_moss": return false
	var pos:Vector3=SOCKETS[socket]
	var width:float=.46 if kind=="table" else .3
	if not style.is_empty() and Vector2(player.position.x-pos.x,player.position.z-pos.z).length()<width+.4:
		_toast("Step aside before changing this furniture.")
		return false
	if style.is_empty(): furniture.erase(socket)
	else: furniture[socket]=style
	_rebuild_furniture()
	_schedule_save()
	return true

func _rebuild_furniture() -> void:
	for node:Node3D in furniture_nodes.values(): node.free()
	furniture_nodes.clear()
	for socket:String in furniture:
		var node:=Props.furniture(socket.split("_")[1],furniture[socket])
		node.position=SOCKETS[socket]
		if socket=="main_chair": node.rotation.y=PI*.18
		if socket=="right_chair": node.rotation.y=PI*.7
		add_child(node)
		furniture_nodes[socket]=node

func _update_resident(delta:float) -> void:
	resident_time+=delta
	if not resident_awake or bloom_clock>=0:
		resident_wake_elapsed=0.0
		resident_visual.rotation.z=1.15
		resident_visual.position.y=-.02
		resident.velocity=Vector3(0,-2,0)
	else:
		resident_wake_elapsed=minf(resident_wake_elapsed+delta,RESIDENT_WAKE_SECONDS)
		var wake_fraction:float=resident_wake_elapsed/RESIDENT_WAKE_SECONDS
		var wake_ease:float=wake_fraction*wake_fraction*(3.0-2.0*wake_fraction)
		resident_visual.rotation.z=lerpf(1.15,0.0,wake_ease)
		resident_visual.position.y=lerpf(-.02,sin(resident_time*2.6)*.012,wake_ease)
		var target:=Vector3(16,0,-4) if sky=="night" else Vector3(14,0,-2)
		var offset:Vector3=target-resident.position
		offset.y=0
		if resident_wake_elapsed>=RESIDENT_WAKE_SECONDS and offset.length()>.15 and not resident_talking:
			resident.velocity=offset.normalized()*.6
			resident_visual.rotation.y=lerp_angle(resident_visual.rotation.y,atan2(-offset.x,-offset.z),delta*3)
		else: resident.velocity=Vector3.ZERO
		resident.velocity.y=-2
	resident.move_and_slide()

func _dialogue() -> void:
	resident_talking=true
	_enter_menu("dialogue")
	_clear_menu("Your neighbour","“Oh… the flowers are glowing again.\nI think I'll sit here a little while.\nThank you for bringing some light.”")
	if "sunfern" not in unlocked_plants:
		_button("Learn to plant Sunfern",_learn_sunfern)
	else:
		_label("Sunfern seeds are yours to plant again whenever you like.")
	_button("Take your time",_explore)
	_focus_first()

func _learn_sunfern() -> void:
	if not resident_awake or bloom_clock>=0 or resident_wake_elapsed<RESIDENT_WAKE_SECONDS or "sunfern" in unlocked_plants: return
	var previous:Array=unlocked_plants.duplicate()
	var previous_dirty:bool=dirty
	var previous_timer:float=save_timer
	unlocked_plants.append("sunfern")
	# Permanent learning is confirmed only after a durable write. Unlike paid
	# planting there is no currency debit or presentation outcome to retain.
	dirty=true
	if not _save_now(true):
		unlocked_plants=previous
		dirty=previous_dirty
		save_timer=previous_timer
		_toast("Sunfern was not unlocked because saving failed. Try learning it again after saving is available.")
		if mode=="save_error": _label("Sunfern was not unlocked. Your existing seeds remain yours; speak with your neighbour to try again.")
		return
	_dialogue()
	_toast("Sunfern seeds are yours to use again. No magic was spent.")

func _pause() -> void:
	if mode=="title": return
	_cancel_decor_preview()
	if is_instance_valid(garden_ghost): garden_ghost.free(); garden_ghost=null
	if mode=="growth_preview": world.set_room_growth(0)
	_enter_menu("pause")
	_clear_menu("A moment of quiet")
	_button("Keep wandering",_explore)
	_button("Sky & weather",_appearance_menu)
	_button("Settings & controls",_settings_menu)
	if room_growing: _button("Finish room growth",func(): _finish_growth(); _pause())
	if bloom_clock>=0: _button("Finish the bloom",func(): bloom_clock=-1; _update_patch(1); _pause())
	_button("Save",func():
		if _save_now(): _toast("Clearing saved."))
	_button("Save & quit",func(): if _save_now(): _quit_clean())
	if protected_save: _button("Quit unsaved session",_quit_clean)
	_focus_first()

func _appearance_menu() -> void:
	_enter_menu("appearance")
	appearance_sky=sky
	appearance_weather=weather
	_draw_appearance()

func _draw_appearance() -> void:
	_clear_menu("Sky & weather","Choose the mood whenever you like. The forest remains yours to explore.")
	_button(("● " if appearance_sky=="day" else "○ ")+"Day",func(): appearance_sky="day"; _draw_appearance())
	_button(("● " if appearance_sky=="night" else "○ ")+"Night",func(): appearance_sky="night"; _draw_appearance())
	_button(("● " if appearance_weather=="sunny" else "○ ")+"Clear sky",func(): appearance_weather="sunny"; _draw_appearance())
	_button(("● " if appearance_weather=="rain" else "○ ")+"Gentle rain",func(): appearance_weather="rain"; _draw_appearance())
	_button("Apply",func(): set_appearance(appearance_sky,appearance_weather); _toast("Sky and weather applied."))
	_button("Back",_pause)
	_focus_first()

func set_appearance(new_sky:String,new_weather:String) -> void:
	if not new_sky in ["day","night"] or not new_weather in ["sunny","rain"]: return
	sky=new_sky
	weather=new_weather
	world.set_appearance(sky=="night",weather=="rain",settings.reduced_effects)
	_schedule_save()

func _settings_menu() -> void:
	if mode=="title": settings_return="title"
	elif mode=="pause": settings_return="pause"
	_enter_menu("settings")
	_clear_menu("Make it comfortable")
	for key:String in ["float_toggle","reduced_motion","reduced_effects","invert_y"]:
		var check:=CheckButton.new()
		check.text=key.replace("_"," ").capitalize()
		check.button_pressed=settings[key]
		check.toggled.connect(func(value:bool): settings[key]=value; _apply_settings(); _schedule_save())
		content.add_child(check)
	for spec:Array in [["sensitivity","Look sensitivity",.1,3.0,.1],["prompt_scale","Prompt size",.75,2.0,.05],["music_volume","Music",0,1,.05],["ambience_volume","Forest ambience",0,1,.05],["effects_volume","Sound effects",0,1,.05]]:
		_label(spec[1])
		var slider:=HSlider.new()
		slider.min_value=spec[2]
		slider.max_value=spec[3]
		slider.step=spec[4]
		slider.value=settings[spec[0]]
		slider.value_changed.connect(func(value:float): settings[spec[0]]=value; _apply_settings(); _schedule_save())
		content.add_child(slider)
	_button("Rebind keyboard controls",_controls_menu)
	_button("Audio credits",_audio_credits_menu)
	_button("Back",_title if settings_return=="title" else _pause)
	_label("Sound can be muted with its slider. No interaction depends on audio.")
	_focus_first()

func _audio_credits_menu() -> void:
	_enter_menu("audio_credits")
	_clear_menu("Audio credits")
	_label("'Reverie' by Scott Buckley — released under CC-BY 4.0.\nwww.scottbuckley.com.au\nLicense: creativecommons.org/licenses/by/4.0/\nEnding and volume adapted for MUSH.")
	_label("Footsteps: Kenney — Impact Sounds (CC0 1.0).\nkenney.nl\nSoft blends adapted for MUSH.")
	_button("Back",_settings_menu)
	_focus_first()

func _controls_menu() -> void:
	rebind_action=""
	_enter_menu("controls")
	_clear_menu("Your controls","Select an action, then press a key. A key already in use is refused.\n\nController: left stick move · right stick look\nA float · X glow · B interact · Y decorate · Menu pause")
	for action:String in settings.bindings:
		_button(action.replace("_"," ").capitalize()+"  ·  "+OS.get_keycode_string(settings.bindings[action]),func(): rebind_action=action; _toast("Press a new key for "+action.replace("_"," ")))
	_button("Reset defaults",func(): settings.bindings=BINDINGS.duplicate(); _setup_input(); _controls_menu(); _schedule_save())
	_button("Back",_settings_menu)
	_focus_first()

func _apply_settings() -> void:
	player.float_toggle=settings.float_toggle
	player.sensitivity=settings.sensitivity
	player.invert_y=settings.invert_y
	player.reduced_motion=settings.reduced_motion
	player.reduced_effects=settings.reduced_effects
	prompt.add_theme_font_size_override("font_size",int(20*float(settings.prompt_scale)))
	world.set_appearance(sky=="night",weather=="rain",settings.reduced_effects)
	for pair:Array in [[music,"music_volume"],[ambience,"ambience_volume"],[effects,"effects_volume"],[footsteps,"effects_volume"]]:
		if is_instance_valid(pair[0]):
			pair[0].volume_db=linear_to_db(maxf(.0001,float(settings[pair[1]])))

func _snapshot() -> Dictionary:
	var p:Vector3=player.safe_position
	return {"schema_version":1,"build_version":"0.1.0","seed":7104,"sky":sky,"weather":weather,"player":{"position":[p.x,p.y,p.z],"yaw":player.camera_yaw},"glow":player.glow_on,"door":"closed" if door_state=="closed" else "open","room_right":room_ready,"mana":mana,"mana_delay":mana_delay,"unlocked_plants":unlocked_plants.duplicate(),"restoration":{"state":restoration_state,"transaction_id":restoration_tx,"resident_awake":resident_awake,"path_restored":path_restored},"furniture":furniture.duplicate(),"garden":garden.duplicate(true),"settings":settings.duplicate(true)}

func _schedule_save() -> void:
	dirty=true
	save_timer=.5

func _save_payload() -> Dictionary:
	if not _active_profile_loaded and not _title_save_data.is_empty():
		var data:Dictionary=_title_save_data.duplicate(true)
		data.settings=settings.duplicate(true)
		data.build_version=_snapshot().build_version
		return data
	# A first-ever title settings change has no previous world to overwrite.
	var data:Dictionary=_snapshot()
	# A loaded pose is shown immediately but support validates next physics tick.
	# An immediate focus-loss/menu save must retain the committed loaded point,
	# rather than overwriting it with the controller's pre-load safe marker.
	if player._pending_teleport and not _last_durable_player.is_empty():
		data.player=_last_durable_player.duplicate(true)
	return data

func _save_now(allow_during_growth: bool = false) -> bool:
	if room_growing and not allow_during_growth:
		dirty=true
		_toast("Save will complete when the room has finished growing.")
		return false
	if protected_save:
		_toast("Your existing save is protected. This session is unsaved.")
		return false
	var payload:Dictionary=_save_payload()
	var result:Dictionary=store.save_snapshot(payload)
	if result.ok:
		dirty=false
		save_timer=-1
		_last_durable_player=payload.player.duplicate(true)
		_last_durable_glow=payload.glow
		if not _active_profile_loaded: _title_save_data=payload.duplicate(true)
		return true
	_toast("Saving is paused. Your changes are still here.")
	if mode!="title" and not verification:
		_enter_menu("save_error")
		_clear_menu("The clearing is still here",str(result.error)+"\n\nYour changes remain in this session.")
		_button("Retry saving",func(): if _save_now(allow_during_growth): _return_after_save_error())
		_button("Continue unsaved",_return_after_save_error)
		_button("Quit without saving",func(): _quit_clean())
		_focus_first()
	return false

func _return_after_save_error() -> void:
	if _active_profile_loaded: _explore()
	else:
		# Do not call _title here: another failed write must not trap the user.
		settings_return="title"
		_settings_menu()

func _load_data(data:Dictionary) -> void:
	_active_profile_loaded=true
	_mobile_checkpoint_clock=0.0
	_last_durable_player=data.player.duplicate(true)
	_last_durable_glow=data.glow
	mobile_release_requested.emit("load")
	_cancel_decor_preview()
	sky=data.sky
	weather=data.weather
	settings=data.settings.duplicate(true)
	_setup_input()
	mana=data.mana
	mana_delay=data.mana_delay
	door_state=data.door
	world.door_hinge.rotation.y=0 if door_state=="closed" else deg_to_rad(-95)
	room_ready=data.room_right
	room_growing=false
	reservation.collision_layer=0
	world.set_room_ready(room_ready)
	world.set_room_growth(0)
	unlocked_plants=data.unlocked_plants.duplicate()
	restoration_state=data.restoration.state
	restoration_tx=data.restoration.transaction_id
	resident_awake=data.restoration.resident_awake
	# Loaded paid outcomes are already complete: do not replay the wake animation.
	resident_wake_elapsed=RESIDENT_WAKE_SECONDS if resident_awake else 0.0
	resident_visual.rotation.z=0.0 if resident_awake else 1.15
	resident_visual.position.y=0.0 if resident_awake else -.02
	path_restored=data.restoration.path_restored
	bloom_clock=-1
	patch_visual_bloom=1 if restoration_state=="bloomed" else 0
	_update_patch(patch_visual_bloom)
	furniture=data.furniture.duplicate()
	garden=data.garden.duplicate(true)
	garden_bloom.clear()
	_rebuild_furniture()
	_rebuild_garden()
	var p:Array=data.player.position
	player.teleport_safe(Vector3(p[0],p[1],p[2]),data.player.yaw)
	_reset_footstep_cadence()
	player.set_glow(data.glow)
	_apply_settings()
	world.night_amount=1.0 if sky=="night" else 0.0
	world.rain_amount=1.0 if weather=="rain" else 0.0
	world._apply_appearance()
	dirty=false

func _toast(message:String) -> void:
	if message.is_empty(): return
	notice.text=message
	toast_time=5

func _build_audio() -> void:
	music=AudioStreamPlayer.new()
	ambience=AudioStreamPlayer.new()
	effects=AudioStreamPlayer.new()
	footsteps=AudioStreamPlayer.new()
	for node:AudioStreamPlayer in [music,ambience,effects,footsteps]: add_child(node)
	if ResourceLoader.exists("res://assets/audio/clearing-reverie.mp3"):
		var score:AudioStreamMP3=load("res://assets/audio/clearing-reverie.mp3") as AudioStreamMP3
		if score!=null:
			score.loop=true
			music.stream=score
			music.play()
	if ResourceLoader.exists("res://assets/forest-ambience.wav"):
		ambience.stream=load("res://assets/forest-ambience.wav")
		ambience.play()
	# Finish existing effect reads during synchronous startup, before input frames.
	_effect_streams.clear()
	for kind: String in ["footstep","glow","door","growth"]:
		var path: String = "res://assets/audio/footstep-soft.tres" if kind=="footstep" else "res://assets/"+kind+".wav"
		if ResourceLoader.exists(path):
			var resource: Resource = load(path)
			if resource is AudioStream: _effect_streams[kind] = resource

func _play_effect(kind:String) -> void:
	var stream: AudioStream = _effect_streams.get(kind) as AudioStream
	if stream==null: return
	var sound:AudioStreamPlayer=footsteps if kind=="footstep" else effects
	sound.stream=stream
	sound.play()

func _review_lighting_state() -> Dictionary:
	# Read-only capture metadata, never called during ordinary play/benchmark.
	var turn: Vector3 = world.sun.rotation_degrees
	var practical: Array = []
	for light: OmniLight3D in world._practical_lights:
		practical.append({"path":str(world.get_path_to(light)),"energy":light.light_energy,"range":light.omni_range})
	var cool: Array = []
	for light: OmniLight3D in world._night_lights:
		cool.append({"path":str(world.get_path_to(light)),"energy":light.light_energy,"range":light.omni_range})
	return {"sun_energy":world.sun.light_energy,"sun_color":world.sun.light_color.to_html(),"sun_rotation":[turn.x,turn.y,turn.z],"sun_shadow_normal_bias":world.sun.shadow_normal_bias,
		"ambient_energy":world.environment.ambient_light_energy,"ambient_color":world.environment.ambient_light_color.to_html(),
		"fill_energy":world._sky_fill.light_energy,"fill_color":world._sky_fill.light_color.to_html(),
		"fog_density":world.environment.fog_density,"fog_color":world.environment.fog_light_color.to_html(),
		"sky_top":(world._cloud_sky_material.get_shader_parameter("top_color") as Color).to_html(),"sky_horizon":(world._cloud_sky_material.get_shader_parameter("horizon_color") as Color).to_html(),
		"practical_lights":practical,"night_lights":cool,"night_amount":world.night_amount,"rain_amount":world.rain_amount}

func _capture_review() -> void:
	var output:String="res://review" if OS.has_feature("editor") else "user://verification"
	var args:PackedStringArray=OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i]=="--report-dir": output=args[i+1]
		if args[i]=="--comparison-target-y":
			var value:float=args[i+1].to_float()
			if is_finite(value) and value>=0.5 and value<=4.0: review_target.y=value
	DirAccess.make_dir_recursive_absolute(output)
	review_camera.look_at(review_target)
	ui.hide()
	review_camera.make_current()
	get_window().content_scale_size=Vector2i(960,960)
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().size=Vector2i(960,960)
	player.teleport_safe(Vector3(4,0,14),.278)
	await get_tree().create_timer(4).timeout
	await RenderingServer.frame_post_draw
	var day_player_position: Vector3 = player.global_position
	var day_lighting: Dictionary = _review_lighting_state()
	get_viewport().get_texture().get_image().save_png(output.path_join("day.png"))
	world.set_appearance(true,false,false)
	await get_tree().create_timer(4).timeout
	await RenderingServer.frame_post_draw
	var night_player_position: Vector3 = player.global_position
	var night_lighting: Dictionary = _review_lighting_state()
	get_viewport().get_texture().get_image().save_png(output.path_join("night.png"))
	var record:=FileAccess.open(output.path_join("camera.json"),FileAccess.WRITE)
	record.store_string(JSON.stringify({"build":"0.1.0","scenery_revision":"15-source" if OS.has_feature("editor") else "15-native","exported":not OS.has_feature("editor"),"position":[6,3.3,20],"target":[review_target.x,review_target.y,review_target.z],"vertical_fov":60,"aspect":1,"exposure":world.environment.tonemap_exposure,"player_position_requested":[4,0,14],"player_position_day":[day_player_position.x,day_player_position.y,day_player_position.z],"player_position_night":[night_player_position.x,night_player_position.y,night_player_position.z],"player_yaw_requested":.278,"geometry":"same across day/night","day_lighting":day_lighting,"night_lighting":night_lighting,"rooted_group_load_status":world.get("_rooted_foreground_group_load_status"),"status":"revision 15 provisional physical house shape; fixed comparison camera/light14; visual approval pending"},"\t"))
	record.close()
	print("REVIEW_CAPTURE_COMPLETE")
	_quit_clean()

func _start_acceptance() -> void:
	var runner:Node=load("res://tests/acceptance.gd").new()
	runner.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(runner)

func _start_benchmark() -> void:
	var runner:Node=load("res://tests/benchmark.gd").new()
	add_child(runner)

func _start_crash_probe() -> void:
	var runner:Node=load("res://tests/crash_probe.gd").new()
	runner.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(runner)

func _exit_tree() -> void:
	for node:AudioStreamPlayer in [music,ambience,effects,footsteps]:
		if is_instance_valid(node):
			node.stop()
			node.stream=null
	_effect_streams.clear()

func _stop_audio() -> void:
	for node:AudioStreamPlayer in [music,ambience,effects,footsteps]:
		if is_instance_valid(node):
			node.stop()
			node.stream=null
	_effect_streams.clear()

func _quit_clean(exit_code:int=0) -> void:
	if _quitting: return
	_quitting=true
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	player.enabled=false
	get_tree().paused=false
	world.shutdown_visuals()
	_stop_audio()
	var next_mix: float = AudioServer.get_time_to_next_mix()
	if not is_finite(next_mix):
		next_mix = 0.0
	var audio_drain_delay: float = maxf(0.06, clampf(next_mix, 0.0, 0.20) + 0.02)
	await get_tree().create_timer(audio_drain_delay).timeout
	world.queue_free()
	player.queue_free()
	resident.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# The renderer releases generated particle shaders asynchronously. Give its
	# deferred release queue a short drain interval after the owning nodes die.
	await get_tree().create_timer(0.15,true).timeout
	# Quit-only synchronization, after normal node-owned RID release.
	if RenderingServer.has_method("force_sync"):
		RenderingServer.call("force_sync")
	get_tree().quit(exit_code)
