extends GutTest
## Full screen: a static helper over the window mode, with a seam so a test records what it was asked to do (a headless run has no real
## window to change).

var _calls: Array[bool] = []
var _state: bool = false
var _old_setter: Callable
var _old_getter: Callable


func before_each() -> void:
	_calls.clear()
	_state = false
	_old_setter = ScreenMode.setter
	_old_getter = ScreenMode.getter
	ScreenMode.setter = func(on: bool) -> void:
		_calls.append(on)
		_state = on
	ScreenMode.getter = func() -> bool: return _state
	GameSettings.reset()


func after_each() -> void:
	ScreenMode.setter = _old_setter
	ScreenMode.getter = _old_getter
	GameSettings.reset()


func test_set_fullscreen_asks_the_window() -> void:
	ScreenMode.set_fullscreen(true)
	assert_eq(_calls, [true])
	assert_true(ScreenMode.is_fullscreen())


func test_toggle_flips_and_returns_the_new_state() -> void:
	assert_true(ScreenMode.toggle())
	assert_false(ScreenMode.toggle())
	assert_eq(_calls, [true, false])


func test_apply_saved_only_goes_fullscreen_when_saved_and_never_on_the_web() -> void:
	ScreenMode.apply_saved()
	assert_eq(_calls, [], "not saved: nothing changes")
	GameSettings.fullscreen = true
	ScreenMode.apply_saved(false)
	assert_eq(_calls, [true])
	_calls.clear()
	ScreenMode.apply_saved(true)
	assert_eq(_calls, [], "a browser only allows full screen after a tap, so it is never applied at start")


func test_the_real_window_helpers_exist_and_do_not_crash_headless() -> void:
	ScreenMode.setter = _old_setter
	ScreenMode.getter = _old_getter
	var before := ScreenMode.is_fullscreen()
	ScreenMode.set_fullscreen(before)
	assert_eq(ScreenMode.is_fullscreen(), before)
