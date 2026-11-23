extends SceneTree
## The art tool. Reads `art/palette.txt`, every `art/sprites/*.sprite` and every `art/fonts/*.font` and writes the sheets,
## sprite sets and font sheets into `assets/`. Run it, then import:
##   godot --headless -s tools/art/art_builder.gd
##   godot --headless --import
## It exits with a non-zero code when anything is wrong.


func _init() -> void:
	var problems := ArtBuilder.build_all("res://art/sprites", "res://art/palette.txt", "res://assets/sprites")
	var written := ArtBuilder.files_written
	problems.append_array(FontBuilder.build_all("res://art/fonts", "res://assets/fonts"))
	written += FontBuilder.files_written
	for problem in problems:
		print("ART ERROR: ", problem)
	if problems.is_empty():
		print("ART OK: %d files" % written)
	quit(0 if problems.is_empty() else 1)
