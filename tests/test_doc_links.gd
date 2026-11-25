extends GutTest
## The sprint design documents live in docs/sprints/ and every mention of one resolves.

const CORE_ROOT_FILES := ["README.md", "technical-design.md", "sprint-development.md", "development-log.md", "CLAUDE.md", "claude-prompt.txt"]
const SKIPPED_FOLDERS := [".superpowers", "venv", ".godot", "addons", ".git", "export", "node_modules"]


func _join(folder: String, name: String) -> String:
	return folder + name if folder.ends_with("/") else "%s/%s" % [folder, name]


func _markdown_files(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".md"):
			found.append(_join(folder, file))
	for sub in DirAccess.get_directories_at(folder):
		if not SKIPPED_FOLDERS.has(sub):
			found.append_array(_markdown_files(_join(folder, sub)))
	return found


func test_every_mentioned_sprint_design_exists() -> void:
	var pattern := RegEx.create_from_string("(docs/sprints/)?sprint-[0-9a-z]+-design\\.md")
	var checked := 0
	for file in _markdown_files("res://"):
		var inside_sprints := file.begins_with("res://docs/sprints/")
		for found in pattern.search_all(FileAccess.get_file_as_string(file)):
			checked += 1
			var name := found.get_string().get_file()
			assert_true(FileAccess.file_exists("res://docs/sprints/" + name), "%s mentions %s, which does not exist" % [file, name])
			if not inside_sprints:
				assert_true(found.get_string().begins_with("docs/sprints/"), "%s mentions %s without the docs/sprints/ path" % [file, name])
	assert_gt(checked, 50, "the scan found the mentions")


func test_the_root_keeps_only_the_core_documents() -> void:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".md") or file.ends_with(".txt"):
			found.append(file)
	found.sort()
	var expected := PackedStringArray(CORE_ROOT_FILES)
	expected.sort()
	assert_eq(found, expected)
