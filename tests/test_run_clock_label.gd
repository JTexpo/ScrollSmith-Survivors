extends GutTest

var _label: RunClockLabel


func before_each() -> void:
	GameTime.reset()
	RunClock.reset()
	_label = load("res://scenes/ui/run_clock_label.tscn").instantiate() as RunClockLabel
	add_child_autofree(_label)


func after_each() -> void:
	GameTime.reset()


func test_format() -> void:
	assert_eq(RunClockLabel.format(0.0), "0:00")
	assert_eq(RunClockLabel.format(59.9), "0:59")
	assert_eq(RunClockLabel.format(60.0), "1:00")
	assert_eq(RunClockLabel.format(307.0), "5:07")
	assert_eq(RunClockLabel.format(750.0), "12:30")
	assert_eq(RunClockLabel.format(3600.0), "60:00")
	assert_eq(RunClockLabel.format(-5.0), "0:00")


func test_the_label_starts_at_zero() -> void:
	assert_eq(_label.clock_text(), "0:00")
	assert_eq(_label.text, "0:00")


func test_the_label_shows_the_run_clock() -> void:
	RunClock.reset()
	await wait_seconds(0.2)
	_label._process(1.0)
	assert_eq(_label.clock_text(), RunClockLabel.format(RunClock.seconds()))


func test_the_label_updates_about_four_times_a_second() -> void:
	var before := _label.text
	_label._process(0.1)
	assert_eq(_label.text, before)
	_label._process(0.2)
	assert_eq(_label.text, RunClockLabel.format(RunClock.seconds()))


func test_the_label_stops_while_the_clock_is_frozen() -> void:
	GameTime.freeze()
	var text := _label.clock_text()
	await wait_seconds(0.2)
	_label._process(1.0)
	assert_eq(_label.clock_text(), text)
	GameTime.unfreeze()


func test_ignores_the_mouse() -> void:
	assert_eq(_label.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_clock_uses_the_outlined_hud_label() -> void:
	assert_eq(_label.theme_type_variation, &"HudLabel")
