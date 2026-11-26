extends GutTest
## licences.txt is written from the engine's own notices, never typed from memory.


func test_it_starts_with_the_rights_line() -> void:
	assert_true("Copyright 2026 JTexpo. All rights reserved." in LicenceFile.text().substr(0, 200))


func test_it_contains_the_engine_licence_text() -> void:
	var first := ""
	for line in Engine.get_license_text().split("\n"):
		if not line.strip_edges().is_empty():
			first = line.strip_edges()
			break
	assert_false(first.is_empty())
	assert_true(first in LicenceFile.text())


func test_it_names_every_bundled_licence() -> void:
	var text := LicenceFile.text()
	for key in Engine.get_license_info().keys():
		assert_true(String(key) in text, String(key))


func test_it_names_every_bundled_component() -> void:
	var text := LicenceFile.text()
	for entry in Engine.get_copyright_info():
		assert_true(String(entry["name"]) in text, String(entry["name"]))


func test_it_is_not_tiny() -> void:
	assert_gt(LicenceFile.text().length(), 10000)
