extends GutTest
## The deploy workflow also builds, checks and zips the itch.io upload, and never deploys from a pull request.

const PATH := "res://.github/workflows/deploy-web.yml"


func _text() -> String:
	return FileAccess.get_file_as_string(PATH)


func test_it_runs_on_pull_requests_pushes_to_main_and_by_hand() -> void:
	var text := _text()
	assert_true("pull_request:" in text)
	assert_true("push:" in text and "branches: [main]" in text)
	assert_true("workflow_dispatch:" in text)


func test_the_deploy_job_is_skipped_for_pull_requests() -> void:
	var text := _text()
	var deploy := text.substr(text.find("  deploy:"))
	assert_true("github.event_name != 'pull_request'" in deploy)


func test_the_build_job_writes_licences_checks_and_zips_from_inside_the_folder() -> void:
	var text := _text()
	var licences := text.find("tools/release/write_licences.gd")
	var check := text.find("tools/release/check_itch_zip.gd")
	var zip := text.find("cd build/web")
	assert_gt(licences, -1)
	assert_gt(check, licences, "the check runs after licences.txt is written")
	assert_gt(zip, check, "the zip is made after the check")
	assert_true("zip -r" in text.substr(zip))
	assert_true("actions/upload-artifact" in text)
	assert_true("retention-days: 14" in text)


func test_there_are_no_secrets_and_no_butler() -> void:
	var text := _text()
	assert_false("secrets." in text)
	assert_false("butler" in text)
