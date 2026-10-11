extends Node
## Real live-game/file integration. --mobile-save-reader is a second-process check.
## This catches paused debounce, stale title Continue, lost paid outcomes, unsafe
## replacement, lost seed permanence, and resume before all interruptions end.
const Store=preload("res://scripts/save_store.gd")
var game:Node
var rows:Array[Dictionary]=[]
var directory:=""
var slot:=""
var reader:=false
var release_events:Array[String]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	game=get_parent()
	_run.call_deferred()

func _check(ok:bool,name:String,observed:Variant=null) -> void:
	rows.append({"passed":ok,"name":name,"observed":observed})

func _arguments() -> bool:
	var args:=OS.get_cmdline_user_args()
	var reports:=0
	var slots:=0
	reader="--mobile-save-reader" in args
	for i:int in range(args.size()-1):
		if args[i]=="--report-dir": directory=args[i+1]; reports+=1
		if args[i]=="--mobile-save-slot": slot=args[i+1]; slots+=1
	var pattern:=RegEx.new()
	pattern.compile("^[A-Za-z0-9_]{8,48}$")
	return reports==1 and slots==1 and not directory.is_empty() and pattern.search(slot)!=null

func _button(text:String) -> Button:
	for node:Node in game.content.get_children():
		if node is Button and node.text==text: return node
	return null

func _sliders() -> Array[HSlider]:
	var result:Array[HSlider]=[]
	for node:Node in game.content.get_children():
		if node is HSlider: result.append(node)
	return result

func _disk() -> Dictionary:
	# A fresh production store object reads the durable result, not game caches.
	var store:=Store.new()
	store.directory=game.store.directory
	return store.load_snapshot()

func _world_only(data:Dictionary) -> Dictionary:
	var copy:=data.duplicate(true)
	copy.erase("settings")
	copy.erase("build_version")
	# JSON reads all numbers as float. Compare values in that same domain, while
	# retaining every world key; int/float representation is not lost progress.
	return JSON.parse_string(JSON.stringify(copy))

func _slot_bytes() -> Dictionary:
	var result:Dictionary={}
	for name:String in [Store.PRIMARY,Store.BACKUP]:
		var path:String=game.store.directory.path_join(name)
		result[name]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func _fixture() -> Dictionary:
	var data:Dictionary=game._snapshot()
	data.mana=73.0
	data.mana_delay=0.0
	data.sky="night"
	data.weather="rain"
	data.room_right=true
	data.glow=true
	data.door="closed"
	data.restoration={"state":"bloomed","transaction_id":"mobile_paid_01","resident_awake":true,"path_restored":true}
	data.unlocked_plants=["moonbell"]
	data.furniture={"right_lamp":"lamp_honey"}
	data.garden=[]
	data.player={"position":[-2.0,0.0,12.0],"yaw":0.25}
	data.settings.music_volume=0.35
	data.settings.sensitivity=1.0
	data.settings.invert_y=false
	return data

func _run() -> void:
	if not _arguments():
		game._quit_clean(2)
		return
	_check(game.verification,"test is isolated from the ordinary profile")
	_check(OS.get_user_data_dir().contains("MUSH-mobile-development"),"mobile project has its own application userdir",OS.get_user_data_dir())
	game._pause()
	game.store.directory="user://verification/"+slot
	game._preview_slot=game.store.directory
	game.dirty=false
	game.save_timer=-1.0
	game.protected_save=false
	game.mobile_release_requested.connect(func(reason:String): release_events.append(reason))
	if reader:
		await _run_reader()
		_finish()
		return
	if FileAccess.file_exists(game.store.directory.path_join(Store.PRIMARY)) or FileAccess.file_exists(game.store.directory.path_join(Store.BACKUP)):
		_check(false,"writer refuses a pre-existing verification slot",game.store.directory)
		_finish()
		return
	var seed:=_fixture()
	_check(game.store.save_snapshot(seed).ok,"fixture saves one validated paid profile")
	game.settings.music_volume=0.1
	game._apply_settings()
	game._title()
	_check(is_equal_approx(game.settings.music_volume,0.35),"title applies stored audio settings before Continue")
	game._settings_menu()
	game.mobile_set_interruption("focus",true)
	_check(game.mode=="settings" and not game._active_profile_loaded and get_tree().paused and not game.player.enabled,"focus loss retains inactive title settings rather than gameplay Pause",game.mode)
	game.mobile_set_interruption("focus",false)
	game._title()
	game._settings_menu()
	var sliders:=_sliders()
	_check(sliders.size()==5,"real settings sliders are present")
	if sliders.size()!=5:
		_finish()
		return
	sliders[2].value=0.2
	_check(game.dirty and get_tree().paused,"Music slider schedules a save in paused title settings")
	await get_tree().create_timer(0.8,true).timeout
	var disk:=_disk()
	_check(disk.ok and is_equal_approx(disk.data.settings.music_volume,0.2),"title setting becomes durable without gameplay resume",disk.data.get("settings",{}))
	_check(disk.ok and _world_only(disk.data)==_world_only(seed),"title settings save preserves every pre-existing world/player field",{"disk":_world_only(disk.data),"fixture":_world_only(seed)})
	var title_before:=_slot_bytes()
	game.store.fail_stage="write"
	game.verification=false
	sliders[2].value=0.25
	_check(not game._save_now(true) and game.mode=="save_error","title setting write refusal presents the actual save error panel")
	game._cancel()
	_check(game.mode=="settings" and not game._active_profile_loaded and get_tree().paused and not game.player.enabled,"Back from a title save error returns to settings without loading a default world",game.mode)
	_check(title_before==_slot_bytes() and game.dirty,"title refusal and Back preserve disk bytes and pending edits")
	game.verification=true
	game.store.fail_stage=""
	_check(game._save_now(true),"title pending edit retries without replacing existing progress")
	game._title()
	game._settings_menu()
	sliders=_sliders()
	sliders[2].value=0.3
	var back:=_button("Back")
	_check(back!=null,"real settings Back action exists")
	if back!=null: back.pressed.emit()
	disk=_disk()
	_check(disk.ok and is_equal_approx(disk.data.settings.music_volume,0.3),"Back before debounce flushes latest settings")
	var continue_button:=_button("Continue")
	_check(continue_button!=null,"title Continue is present for the preserved profile")
	if continue_button!=null: continue_button.pressed.emit()
	game._pause()
	_check(game.mode=="pause" and is_equal_approx(game.settings.music_volume,0.3) and game.mana==73.0 and game.restoration_tx=="mobile_paid_01" and game.room_ready,"Continue uses current settings and paid progress without a new debit")
	_check(game._save_now(true),"immediate paused save after Continue completes")
	disk=_disk()
	_check(disk.ok and disk.data.player==seed.player,"save before pending teleport validation preserves the loaded player payload",{"disk_player":disk.data.get("player",{}),"loaded_player":seed.player,"pending_teleport":game.player._pending_teleport,"current_safe_position":[game.player.safe_position.x,game.player.safe_position.y,game.player.safe_position.z]})
	game._settings_menu()
	sliders=_sliders()
	sliders[0].value=2.4
	await get_tree().create_timer(0.8,true).timeout
	disk=_disk()
	_check(disk.ok and is_equal_approx(disk.data.settings.sensitivity,2.4),"active-session paused sensitivity survives a fresh store read")
	for fault:Array in [["write",0.4],["flush",0.45],["replace",0.5]]:
		var stage:String=fault[0]
		var wanted:float=fault[1]
		var before:=_slot_bytes()
		game.store.fail_stage=stage
		game.settings.music_volume=wanted
		game._apply_settings()
		game._schedule_save()
		_check(not game._save_now(true),"injected "+stage+" refuses the setting save")
		_check(before==_slot_bytes(),"injected "+stage+" preserves primary and backup bytes")
		_check(game.dirty and is_equal_approx(game.settings.music_volume,wanted),"injected "+stage+" retains dirty settings for retry")
		game.store.fail_stage=""
		_check(game._save_now(true),"retry after "+stage+" commits the retained setting")
		disk=_disk()
		_check(disk.ok and is_equal_approx(disk.data.settings.music_volume,wanted) and disk.data.restoration==seed.restoration and disk.data.mana==73.0,"retry after "+stage+" preserves the paid outcome without recharging/debit")
	# Optional dialogue is the only new unlocking interaction; travel stays free.
	game._dialogue()
	var learn:=_button("Learn to plant Sunfern")
	_check(learn!=null,"awake dialogue offers optional permanent Sunfern learning")
	if learn!=null:
		var before:=_slot_bytes()
		var old_dirty:bool=game.dirty
		game.store.fail_stage="write"
		game.verification=false
		learn.pressed.emit()
		game.verification=true
		_check(game.unlocked_plants==["moonbell"] and before==_slot_bytes() and game.dirty==old_dirty,"refused Sunfern write rolls back only the proposed unlock")
		_check(game.mode=="save_error","refused Sunfern write retains the ordinary error panel")
		game.store.fail_stage=""
		game._dialogue()
		learn=_button("Learn to plant Sunfern")
		if learn!=null: learn.pressed.emit()
		disk=_disk()
		_check(disk.ok and disk.data.unlocked_plants==["moonbell","sunfern"] and game.unlocked_plants==["moonbell","sunfern"],"accepted Sunfern offer is durable in the confirming tick")
		_check(disk.ok and disk.data.mana==73.0 and disk.data.restoration==seed.restoration,"seed learning does not charge magic or repeat restoration")
		game._dialogue()
		_check(_button("Learn to plant Sunfern")==null and game.unlocked_plants==["moonbell","sunfern"],"repeated dialogue cannot duplicate the permanent seed")
		game._load_data(disk.data)
		_check(game.unlocked_plants==["moonbell","sunfern"],"reloaded profile retains the learned seed")
	# Scripted interruption composition; this does not simulate OS/device delivery.
	game._explore()
	game._play_effect("glow")
	game._play_effect("footstep")
	var music_stream:AudioStream=game.music.stream
	var ambience_stream:AudioStream=game.ambience.stream
	game.settings.music_volume=0.45
	game._schedule_save()
	game.mobile_set_interruption("focus",true)
	_check(get_tree().paused and not game.player.enabled and game.music.stream_paused and game.ambience.stream_paused,"focus interruption pauses controls and loop audio")
	_check(not game.effects.playing and not game.footsteps.playing and game.music.stream==music_stream and game.ambience.stream==ambience_stream,"interruption discards stale one-shots but retains loop resources")
	_check(not game.dirty and _disk().ok,"interruption flushes pending settings through durable save")
	var events_before:=release_events.size()
	game.mobile_set_interruption("focus",true)
	_check(release_events.size()==events_before,"repeated focus interruption is idempotent")
	game.mobile_set_interruption("background",true)
	game.mobile_audio_interruption_changed(true)
	game.mobile_set_interruption("focus",false)
	game.mobile_set_interruption("background",false)
	game._explore()
	_check(get_tree().paused and not game.player.enabled and game.music.stream_paused,"remaining audio interruption blocks premature gameplay and audio resume")
	game.mobile_audio_interruption_changed(false)
	_check(get_tree().paused and not game.player.enabled and not game.music.stream_paused and not game.ambience.stream_paused,"all interruptions ending resumes audio and leaves explicit gameplay pause")
	game._explore()
	_check(not get_tree().paused and game.player.enabled and "suspend" in release_events and "resume" in release_events,"Keep wandering restores controls after release signals")
	game._pause()
	# Leave a literal final fixture for the separate process, not a cached object.
	var final_data:=seed.duplicate(true)
	final_data.unlocked_plants=["moonbell","sunfern"]
	final_data.settings.music_volume=0.45
	final_data.settings.sensitivity=2.4
	game._load_data(final_data)
	_check(game._save_now(true),"writer commits the final relaunch fixture")
	var copy:=final_data.duplicate(true)
	copy.build_version="0.4.0"
	_check(not game.store.validate(copy).is_empty(),"unknown future content version is rejected")
	copy=final_data.duplicate(true)
	copy.schema_version=2
	_check(not game.store.validate(copy).is_empty(),"unknown future schema is rejected")
	copy=final_data.duplicate(true)
	copy.build_version="0.2.2"
	_check(game.store.validate(copy).is_empty(),"strict schema 1 remains backward compatible with 0.2.2")
	_finish()

func _run_reader() -> void:
	var disk:=_disk()
	_check(disk.ok and disk.source=="primary","second process reads the actual committed primary",disk.get("source"))
	if not disk.ok: return
	_check(disk.data.schema_version==1 and disk.data.build_version=="0.3.0","relaunch uses current schema/content version")
	game.settings.music_volume=0.1
	game.settings.sensitivity=1.0
	game._title()
	_check(is_equal_approx(game.settings.music_volume,0.45) and is_equal_approx(game.settings.sensitivity,2.4),"second process title applies committed settings before Continue")
	var button:=_button("Continue")
	_check(button!=null,"second process has the actual Continue action")
	if button!=null: button.pressed.emit()
	game._pause()
	_check(game.mana==73.0 and game.mana_delay==0.0 and game.restoration_state=="bloomed" and game.restoration_tx=="mobile_paid_01" and game.resident_awake and game.path_restored,"relaunch retains one coupled paid outcome without a new debit")
	_check(game.sky=="night" and game.weather=="rain" and game.room_ready and game.furniture=={"right_lamp":"lamp_honey"} and game.player.glow_on,"relaunch retains appearance, room, furniture and Glow")
	_check(game.unlocked_plants==["moonbell","sunfern"],"second process keeps permanent seed learning")
	_check(game.player.global_position==Vector3(-2,0,12) and is_equal_approx(game.player.camera_yaw,0.25),"relaunch displays the committed player position and camera yaw")
	game._explore()
	# physics_frame is emitted before node physics. Three signals allow two
	# ordinary controller steps: validate the 8mm support offset, then land through
	# the existing 3mm margin. Do not widen position tolerances or finish manually.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	game._pause()
	_check(not game.player._pending_teleport and game.player.is_on_floor() and Vector2(game.player.safe_position.x,game.player.safe_position.z).distance_to(Vector2(-2,12))<0.01 and absf(game.player.safe_position.y)<0.05,"ordinary physics validates loaded support near the committed point",{"safe_position":[game.player.safe_position.x,game.player.safe_position.y,game.player.safe_position.z],"global_position":[game.player.global_position.x,game.player.global_position.y,game.player.global_position.z],"pending":game.player._pending_teleport,"is_on_floor":game.player.is_on_floor(),"ordinary_controller_steps_before_pause":2})

func _finish() -> void:
	var passed:=true
	for row:Dictionary in rows: passed=passed and row.passed
	var report:Dictionary={"schema":"mush-mobile-save-integration/1","passed":passed,"phase":"reader" if reader else "writer","assertions":rows.size(),"checks":rows,"slot":game.store.directory,"resolved_user_dir":OS.get_user_data_dir(),"engine":Engine.get_version_info(),"source_main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"source_save_store_sha256":FileAccess.get_sha256("res://scripts/save_store.gd"),"test_sha256":FileAccess.get_sha256("res://tests/mobile_save.gd"),"durable_file_sha256":_slot_bytes(),"release_events":release_events,"physical_device_verified":false,"native_interruption_delivery_verified":false,"scope":"Real game menu signals, application-local files, production fault hooks, and scripted lifecycle/audio composition. Reader requires a distinct second process. No physical touch, device filesystem fault, audio-focus delivery, human usability or store-readiness claim."}
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		game._quit_clean(2)
		return
	var file:=FileAccess.open(directory.path_join("mobile-save.json"),FileAccess.WRITE)
	if file==null:
		game._quit_clean(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.flush()
	var write_ok:=file.get_error()==OK
	file.close()
	print("MOBILE_SAVE_COMPLETE ",JSON.stringify({"passed":passed,"phase":report.phase,"assertions":rows.size(),"report":directory}))
	game._quit_clean(0 if passed and write_ok else 1)
