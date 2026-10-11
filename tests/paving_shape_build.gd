extends SceneTree
## Offline, create-only authoring; never loads or writes a player profile.
func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output = arg.trim_prefix("--report-dir=")
	var reports := ProjectSettings.globalize_path("res://reports/").simplify_path().trim_suffix("/")
	output = output.simplify_path()
	if not output.is_absolute_path() or not output.begins_with(reports + "/") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		push_error("Use a fresh --report-dir= beneath res://reports/"); quit(2); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: quit(2); return
	var author = load("res://tools/paving_shape.gd").new()
	var report: Dictionary = author.build(output)
	var report_path := output.path_join("paving-shape.json")
	if not FileAccess.file_exists(report_path):
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("PAVING_SHAPE_BUILD ", JSON.stringify({"passed":report.get("passed", false), "output":output}))
	quit(0 if report.get("passed", false) else 2)
