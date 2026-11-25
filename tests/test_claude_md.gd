extends GutTest
## CLAUDE.md holds the rules every session needs; each per-sprint section lives in docs/architecture/.

const MAX_BYTES := 25000
const CORE_HEADINGS := ["Project State", "Commands", "Required Workflow", "Architecture (big picture)", "Established Design Rules (do not change without asking)", "Conventions", "Web build and GitHub Pages", "Touch and input gotchas"]
const TOPICS := ["combat-and-spells", "scrolls-and-crafting", "progression-and-economy", "enemies-and-bosses", "maps-and-world", "map-content", "art", "interface-and-audio", "polish-and-performance", "front-door"]


func _headings(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	for line in text.split("\n"):
		if line.begins_with("## "):
			found.append(line.substr(3).strip_edges())
	return found


func test_claude_md_stays_under_25_kb() -> void:
	var size := FileAccess.get_file_as_string("res://CLAUDE.md").to_utf8_buffer().size()
	assert_lt(size, MAX_BYTES, "CLAUDE.md is %d bytes: move detail into docs/architecture/" % size)


func test_every_link_in_claude_md_resolves() -> void:
	var text := FileAccess.get_file_as_string("res://CLAUDE.md")
	var links := RegEx.create_from_string("docs/[A-Za-z0-9_./-]+\\.md").search_all(text)
	assert_gte(links.size(), 10, "the index links the ten topic docs")
	for link in links:
		assert_true(FileAccess.file_exists("res://" + link.get_string()), "%s does not exist" % link.get_string())


func test_core_sections_stay_in_claude_md() -> void:
	var headings := _headings(FileAccess.get_file_as_string("res://CLAUDE.md"))
	for heading in CORE_HEADINGS:
		assert_true(headings.has(heading), "CLAUDE.md lost the section '%s'" % heading)
	assert_true(headings.has("Where the detail lives"))


func test_no_per_sprint_section_is_left_in_claude_md() -> void:
	for heading in _headings(FileAccess.get_file_as_string("res://CLAUDE.md")):
		assert_false(heading.ends_with(")") and heading.contains("(Sprint "), "'%s' belongs in docs/architecture/" % heading)


func test_core_keeps_the_commands_and_test_rules_a_session_needs() -> void:
	var text := FileAccess.get_file_as_string("res://CLAUDE.md")
	for needle in ["tools/art/art_builder.gd", "soak_test.gd", "spell_audit.gd", "save_path", "scene_changer", "node_paths", "Never run two Godot processes", "tests/fixtures/claude_md_sections.txt", "docs/architecture/"]:
		assert_true(text.contains(needle), "CLAUDE.md lost '%s', which a session needs without opening a topic doc" % needle)


func test_core_keeps_the_user_rulings_and_the_no_autoload_rule() -> void:
	var text := FileAccess.get_file_as_string("res://CLAUDE.md")
	for needle in ["passes over obstacles", "never changes a stat", "potions last one run", "run continues after a boss", "rolled or picked again", "never scaled", "has no autoloads"]:
		assert_true(text.contains(needle), "CLAUDE.md lost the ruling '%s'" % needle)


func test_every_per_sprint_section_is_kept_in_a_topic_doc() -> void:
	var expected := PackedStringArray()
	for line in FileAccess.get_file_as_string("res://tests/fixtures/claude_md_sections.txt").split("\n", false):
		expected.append(line)
	var found := PackedStringArray()
	for file in DirAccess.get_files_at("res://docs/architecture"):
		if file.ends_with(".md"):
			found.append_array(_headings(FileAccess.get_file_as_string("res://docs/architecture/" + file)))
	for topic in TOPICS:
		assert_true(FileAccess.file_exists("res://docs/architecture/%s.md" % topic), topic)
	for heading in expected:
		assert_true(found.has(heading), "no topic doc holds the section '%s'" % heading)


func test_every_topic_doc_is_listed_in_the_index() -> void:
	var text := FileAccess.get_file_as_string("res://CLAUDE.md")
	for topic in TOPICS:
		assert_true(text.contains("docs/architecture/%s.md" % topic), topic)
