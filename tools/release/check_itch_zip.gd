extends SceneTree
## Checks a web build folder against itch.io's limits:
##   godot --headless -s tools/release/check_itch_zip.gd -- <folder>
## Prints `ITCH OK` or one `ITCH ERROR` line per problem, and exits with a non-zero code on any problem or an unreadable folder.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		print("ITCH ERROR: give exactly one folder")
		quit(1)
		return
	var root := args[0].trim_suffix("/")
	if not DirAccess.dir_exists_absolute(root):
		print("ITCH ERROR: %s is not a folder" % root)
		quit(1)
		return
	var files := {}
	_collect(root, "", files)
	var problems := ItchZipRules.problems(files)
	for problem in problems:
		print("ITCH ERROR: ", problem)
	if problems.is_empty():
		var total := 0
		for size in files.values():
			total += int(size)
		print("ITCH OK: %d files, %.1f MB" % [files.size(), total / 1048576.0])
	quit(0 if problems.is_empty() else 1)


func _collect(root: String, relative: String, files: Dictionary) -> void:
	var folder := root if relative.is_empty() else "%s/%s" % [root, relative]
	for file in DirAccess.get_files_at(folder):
		var path := "%s/%s" % [folder, file]
		var handle := FileAccess.open(path, FileAccess.READ)
		files[file if relative.is_empty() else "%s/%s" % [relative, file]] = handle.get_length() if handle != null else 0
	for sub in DirAccess.get_directories_at(folder):
		_collect(root, sub if relative.is_empty() else "%s/%s" % [relative, sub], files)
