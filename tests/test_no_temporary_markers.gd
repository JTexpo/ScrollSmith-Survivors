extends GutTest
## Game code and data carry no "TEMPORARY" marker: the placeholder looks were replaced in Sprints 13b to 13d.


func _offenders(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		var path := "%s/%s" % [folder, file]
		if (path.ends_with(".gd") or path.ends_with(".tres") or path.ends_with(".tscn")) and FileAccess.get_file_as_string(path).contains("TEMPORARY"):
			found.append(path)
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_offenders("%s/%s" % [folder, sub]))
	return found


func test_no_script_or_resource_says_temporary() -> void:
	var offenders: Array[String] = []
	for folder in ["res://scripts", "res://resources"]:
		offenders.append_array(_offenders(folder))
	assert_eq(offenders, [] as Array[String], "rewrite the comment to say what the code is now")
