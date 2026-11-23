extends SceneTree
## The art tool. Reads `art/palette.txt`, every `art/sprites/*.sprite`, every `art/fonts/*.pixelfont` and the sound recipes and
## tunes in `audio/` and writes the sheets, sprite sets, font sheets, the game theme and the WAV files into `assets/` and `resources/ui/`. Run it, then import:
##   godot --headless -s tools/art/art_builder.gd
##   godot --headless --import
## It exits with a non-zero code when anything is wrong.


func _init() -> void:
	var problems := ArtBuilder.build_all("res://art/sprites", "res://art/palette.txt", "res://assets/sprites")
	var written := ArtBuilder.files_written
	problems.append_array(FontBuilder.build_all("res://art/fonts", "res://assets/fonts"))
	written += FontBuilder.files_written
	problems.append_array(ThemeBuilder.write())
	written += 1
	problems.append_array(AudioBuilder.build_all("res://audio", "res://assets/audio"))
	for problem in problems:
		print("ART ERROR: ", problem)
	if problems.is_empty():
		print("ART OK: %d files" % written)
	quit(0 if problems.is_empty() else 1)
