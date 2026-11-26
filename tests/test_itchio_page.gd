extends GutTest
## The itch.io page text (docs/release-planning/itchio-page.md) is what the user pastes into the page form. These tests keep it in step with the
## game: the version, the controls and the embed size.

const PATH := "res://docs/release-planning/itchio-page.md"
const SECTIONS := ["Title", "Tagline", "Description", "Controls", "Features", "Genre and tags", "Made with", "Licence", "Embed and page settings", "Version"]


func _text() -> String:
	return FileAccess.get_file_as_string(PATH)


## The text under `## <heading>` up to the next `## ` heading.
func _section(heading: String) -> String:
	var text := _text()
	var start := text.find("## %s\n" % heading)
	if start < 0:
		return ""
	var body_start := start + heading.length() + 4
	var next := text.find("\n## ", body_start)
	return text.substr(body_start, (next if next >= 0 else text.length()) - body_start)


func test_the_page_document_has_every_section() -> void:
	for heading in SECTIONS:
		assert_false(_section(heading).strip_edges().is_empty(), "section '%s' exists and is not empty" % heading)


func test_the_page_version_matches_the_game() -> void:
	assert_true(GameVersion.current() in _section("Version"))


func test_the_controls_table_lists_every_control() -> void:
	var controls := _section("Controls")
	for line in ControlsText.lines():
		if line.begins_with("Touch:") or line.begins_with("Keys "):
			assert_true(line in controls, line)
			continue
		var parts := line.split(": ", true, 1)
		var keyboard: Array[String] = []
		var pad: Array[String] = []
		for item in parts[1].split(", "):
			if item.begins_with("Pad"):
				pad.append(item)
			else:
				keyboard.append(item)
		var row := "| %s | %s | %s |" % [parts[0], ", ".join(keyboard) if not keyboard.is_empty() else "-", ", ".join(pad) if not pad.is_empty() else "-"]
		assert_true(row in controls, "the row %s" % row)


func test_the_page_is_ascii_and_names_godot_and_the_rights_line() -> void:
	var text := _text()
	for i in text.length():
		assert_lt(text.unicode_at(i), 128, "non-ASCII character at %d" % i)
	assert_true("Godot" in _section("Made with"))
	assert_true("All rights reserved" in _section("Licence"))


func test_the_embed_size_is_a_whole_multiple_of_480_by_270() -> void:
	var regex := RegEx.create_from_string("Embed size: (\\d+) x (\\d+)")
	var found := regex.search(_section("Embed and page settings"))
	assert_not_null(found)
	var width := int(found.get_string(1))
	var height := int(found.get_string(2))
	assert_eq(width % 480, 0)
	assert_eq(height % 270, 0)
	assert_eq(width / 480, height / 270)


func test_the_tags_fit_itch_ios_limit_of_ten() -> void:
	var line := ""
	for l in _section("Genre and tags").split("\n"):
		if l.begins_with("Tags:"):
			line = l.trim_prefix("Tags:")
	assert_false(line.strip_edges().is_empty())
	assert_lte(line.split(",", false).size(), 10)
