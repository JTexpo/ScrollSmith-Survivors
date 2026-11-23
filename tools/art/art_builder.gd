extends SceneTree
## The art tool. Reads `art/palette.txt` and every `art/sprites/*.sprite` and writes the sheets and sprite sets into
## `assets/sprites/`. Run it, then import:
##   godot --headless -s tools/art/art_builder.gd
##   godot --headless --import
## It exits with a non-zero code when anything is wrong.


func _init() -> void:
	var problems := ArtBuilder.build_all("res://art/sprites", "res://art/palette.txt", "res://assets/sprites")
	for problem in problems:
		print("ART ERROR: ", problem)
	if problems.is_empty():
		print("ART OK: %d files" % ArtBuilder.files_written)
	quit(0 if problems.is_empty() else 1)
