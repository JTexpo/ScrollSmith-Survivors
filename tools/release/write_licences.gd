extends SceneTree
## Writes licences.txt for the web build:
##   godot --headless -s tools/release/write_licences.gd -- <output file>
## It exits with a non-zero code when it cannot write the file.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		print("LICENCES ERROR: give exactly one output path")
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		print("LICENCES ERROR: cannot write %s (%s)" % [args[0], error_string(FileAccess.get_open_error())])
		quit(1)
		return
	file.store_string(LicenceFile.text())
	file.close()
	print("LICENCES OK: %s" % args[0])
	quit(0)
