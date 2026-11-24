extends GutTest
## The performance overlay: one line of engine counters testers can open on a phone. It is off by default, reads only engine counters,
## refreshes four times a second, does no work while hidden and never takes a touch.

var _overlay: PerfOverlay
var _spawner: EnemySpawner


func before_each() -> void:
	FxSettings.reset()
	_spawner = EnemySpawner.new()
	add_child_autofree(_spawner)
	_overlay = (load("res://scenes/ui/perf_overlay.tscn") as PackedScene).instantiate() as PerfOverlay
	add_child_autofree(_overlay)
	_overlay.bind(_spawner)


func after_each() -> void:
	FxSettings.reset()


func test_it_is_hidden_by_default() -> void:
	assert_false(FxSettings.perf_overlay)
	_overlay.sync()
	assert_false(_overlay.visible)


func test_the_switch_shows_and_hides_it() -> void:
	FxSettings.perf_overlay = true
	_overlay.sync()
	assert_true(_overlay.visible)
	FxSettings.perf_overlay = false
	_overlay.sync()
	assert_false(_overlay.visible)


func test_line_text_has_fps_ms_enemies_and_nodes_and_is_ascii() -> void:
	_spawner.alive = 42
	var text := _overlay.line_text()
	for word in ["fps", "ms", "enemies 42", "nodes"]:
		assert_string_contains(text, word)
	for i in text.length():
		assert_between(text.unicode_at(i), 32, 126, "ASCII only")


func test_it_refreshes_four_times_a_second_not_every_frame() -> void:
	FxSettings.perf_overlay = true
	_overlay.sync()
	_spawner.alive = 7
	_overlay.refresh_now()
	assert_string_contains(_overlay.shown_text(), "enemies 7")
	_spawner.alive = 8
	_overlay.advance(0.1)
	assert_string_contains(_overlay.shown_text(), "enemies 7", "not yet")
	_overlay.advance(0.2)
	assert_string_contains(_overlay.shown_text(), "enemies 8")
	assert_eq(PerfOverlay.REFRESH_SECONDS, 0.25)


func test_it_ignores_touches() -> void:
	for node in _overlay.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.name))


func test_it_does_no_work_while_hidden() -> void:
	_overlay.sync()
	assert_false(_overlay.is_processing())
	FxSettings.perf_overlay = true
	_overlay.sync()
	assert_true(_overlay.is_processing())


func test_f3_flips_the_switch_and_the_overlay() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as Main
	main.save_path = ""
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	var overlay := main.get_node("PerfOverlay") as PerfOverlay
	assert_false(overlay.visible)
	var event := InputEventAction.new()
	event.action = &"debug_perf_overlay"
	event.pressed = true
	main._unhandled_input(event)
	assert_true(FxSettings.perf_overlay)
	assert_true(overlay.visible)
	main._unhandled_input(event)
	assert_false(FxSettings.perf_overlay)
	assert_false(overlay.visible)
