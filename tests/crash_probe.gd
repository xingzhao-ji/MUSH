extends Node
## Test-only child-process stages. The parent kills a confirmed-live process
## after ready.json, then launches a new application to validate recovery.
const SaveStore = preload("res://scripts/save_store.gd")
var game: Node
var stage := ""
var report_dir := ""


func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	game=get_parent()
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var slot := ""
	for index in range(args.size()-1):
		match args[index]:
			"--probe-stage": stage=args[index+1]
			"--probe-slot": slot=args[index+1]
			"--report-dir": report_dir=args[index+1]
	if slot not in ["verification_crash_room","verification_crash_preview","verification_crash_bloom","verification_crash_mixed"] or report_dir.is_empty():
		game._quit_clean.call_deferred(2)
		return
	game.store.directory="user://"+slot
	game._explore()
	await _frames(5)
	if stage.begins_with("setup_"):
		_clean_slot()
		game._reset_world()
		game._explore()
		if stage in ["setup_room","setup_mixed"]:
			game.player.teleport_safe(Vector3(1.5,.6,.6),0)
			await _frames(5)
			if not game._save_now() or not game.begin_growth():
				_write("ready.json",{"ready":false,"reason":"Room setup failed"})
				game._quit_clean.call_deferred(2)
				return
			if stage=="setup_mixed" and not game.plant_patch():
				_write("ready.json",{"ready":false,"reason":"Concurrent paid cast failed"})
				game._quit_clean.call_deferred(2)
				return
			await get_tree().create_timer(.25,true).timeout
		elif stage=="setup_preview":
			game.player.teleport_safe(Vector3(0,.6,-.3),0)
			await _frames(5)
			if not game.commit_furniture("main_chair","chair_honey") or not game._save_now():
				_write("ready.json",{"ready":false,"reason":"Preview setup failed"})
				game._quit_clean.call_deferred(2)
				return
			game._socket_menu("main_chair")
			game._preview_furniture("chair_moss")
		elif stage=="setup_bloom":
			game.player.teleport_safe(Vector3(13,0,.3),0)
			await _frames(5)
			game.mana=100
			if not game.plant_patch():
				_write("ready.json",{"ready":false,"reason":"Bloom setup failed"})
				game._quit_clean.call_deferred(2)
				return
			await get_tree().create_timer(.25,true).timeout
		else:
			_write("ready.json",{"ready":false,"reason":"Unknown setup stage"})
			game._quit_clean.call_deferred(2)
			return
		_write("ready.json",{"ready":true,"pid":OS.get_process_id(),"stage":stage,"room_growing":game.room_growing,"preview":game.decor_preview,"bloom_clock":game.bloom_clock,"mana":game.mana,"transaction":game.restoration_tx})
		# Parent uses OS.kill on this live process. A timeout is an error, never
		# silently treated as a crash/restart pass.
		await get_tree().create_timer(40,true).timeout
		game._quit_clean.call_deferred(3)
		return
	var loaded: Dictionary=game.store.load_snapshot()
	var assertions: Array=[]
	assertions.append({"name":"Validated primary loads in a fresh application process","pass":loaded.ok and loaded.source=="primary"})
	if loaded.ok:
		game._load_data(loaded.data)
		game._explore()
		if stage=="resume_room":
			await _frames(5)
			assertions.append({"name":"Crash mid-growth restores stable pre-growth house","pass":not game.room_ready and not game.room_growing and game.world.wall_plug.visible and not game.world.right_room.visible and game.reservation.collision_layer==0})
			assertions.append({"name":"Player resumes on physical safe support","pass":game.player.is_on_floor()})
		elif stage=="resume_preview":
			await _frames(5)
			assertions.append({"name":"Crash during style preview retains committed honey chair","pass":game.furniture.get("main_chair","")=="chair_honey" and game.furniture_nodes.size()==1 and not game.decor_preview and game.preview_node==null})
		elif stage in ["resume_bloom","resume_mixed"]:
			assertions.append({"name":"Paid growth restores debit and final outcome together","pass":game.mana==75 and game.restoration_state=="bloomed" and game.resident_awake and game.path_restored and not game.restoration_tx.is_empty()})
			assertions.append({"name":"Pending bloom completes immediately without replay","pass":game.patch_visual_bloom==1 and game.bloom_clock<0 and not game.cast_plant() and game.mana==75})
			assertions.append({"name":"One resident survives process restart","pass":_count_named(game,"ResidentPlaceholder")==1})
			if stage=="resume_mixed":
				await _frames(5)
				assertions.append({"name":"Paid plant outcome survives while uncommitted room rolls back","pass":not game.room_ready and not game.room_growing and game.world.wall_plug.visible and not game.world.right_room.visible and game.reservation.collision_layer==0 and game.player.is_on_floor()})
		else:
			assertions.append({"name":"Known resume stage","pass":false})
	var passed := true
	for assertion in assertions:
		if not assertion.pass: passed=false
	_write("resume.json",{"ok":passed,"stage":stage,"pid":OS.get_process_id(),"assertions":assertions})
	game._quit_clean.call_deferred(0 if passed else 1)


func _frames(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _write(filename: String,data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(report_dir)
	var destination := report_dir.path_join(filename)
	var temporary := destination+".%d.tmp"%OS.get_process_id()
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if not file:
		push_error("Crash probe cannot write its result: "+error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error!=OK:
		DirAccess.remove_absolute(temporary)
		push_error("Crash probe cannot flush its result: "+error_string(write_error))
		return
	var publish_error: Error = DirAccess.rename_absolute(temporary,destination)
	if publish_error!=OK:
		push_error("Crash probe cannot publish its result: "+error_string(publish_error))


func _clean_slot() -> void:
	DirAccess.make_dir_recursive_absolute(game.store.directory)
	for filename in [SaveStore.PRIMARY,SaveStore.BACKUP,SaveStore.TEMP,SaveStore.BACKUP_TEMP,SaveStore.BACKUP_ROLLBACK]:
		if FileAccess.file_exists(game.store.directory.path_join(filename)): DirAccess.remove_absolute(game.store.directory.path_join(filename))


func _count_named(node: Node,label: String) -> int:
	var count := 1 if node.name==label else 0
	for child: Node in node.get_children(): count+=_count_named(child,label)
	return count
