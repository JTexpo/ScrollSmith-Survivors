extends GutTest
## The checks the packaging step runs on the web build before it is zipped for itch.io.

const MB := 1024 * 1024


func _clean() -> Dictionary:
	return {"index.html": 5000, "index.js": 300000, "index.pck": 200000, "index.wasm": 39 * MB, "licences.txt": 90000}


func test_a_clean_set_has_no_problems() -> void:
	assert_eq(ItchZipRules.problems(_clean()), [] as Array[String])


func test_missing_index_html_is_reported() -> void:
	var files := _clean()
	files.erase("index.html")
	assert_false(ItchZipRules.problems(files).is_empty())


func test_a_nested_index_html_is_not_the_root_one() -> void:
	var files := {"web/index.html": 5000, "web/licences.txt": 90000}
	assert_false(ItchZipRules.problems(files).is_empty())


func test_more_than_1000_files_is_reported_and_exactly_1000_is_fine() -> void:
	var files := _clean()
	for i in 995:
		files["extra/%d.bin" % i] = 10
	assert_eq(files.size(), 1000)
	assert_true(ItchZipRules.problems(files).is_empty())
	files["extra/one_more.bin"] = 10
	assert_false(ItchZipRules.problems(files).is_empty())


func test_a_file_over_200_mb_is_reported_and_exactly_200_is_fine() -> void:
	var files := _clean()
	files["index.wasm"] = 200 * MB
	assert_true(ItchZipRules.problems(files).is_empty())
	files["index.wasm"] = 200 * MB + 1
	assert_false(ItchZipRules.problems(files).is_empty())


func test_a_total_over_500_mb_is_reported() -> void:
	var files := _clean()
	files["a.bin"] = 200 * MB
	files["b.bin"] = 200 * MB
	files["c.bin"] = 80 * MB
	assert_false(ItchZipRules.problems(files).is_empty())


func test_names_that_differ_only_by_case_are_reported() -> void:
	var files := _clean()
	files["Index.js"] = 10
	assert_false(ItchZipRules.problems(files).is_empty())


func test_a_missing_licences_file_is_reported() -> void:
	var files := _clean()
	files.erase("licences.txt")
	var problems := ItchZipRules.problems(files)
	assert_eq(problems.size(), 1)
	assert_true("licences.txt" in problems[0])


func test_an_empty_set_reports_the_missing_files() -> void:
	assert_gte(ItchZipRules.problems({}).size(), 2)
