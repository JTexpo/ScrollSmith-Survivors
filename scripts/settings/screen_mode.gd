class_name ScreenMode
extends RefCounted
## Full screen on and off. On the web this is the browser's full screen, which a browser only allows from inside a tap or click, so it is
## never applied at start there (a phone player taps the button). On a desktop the saved choice is applied at start. `setter` and
## `getter` are a seam so a test can record the request (a headless run has no real window).

static var setter: Callable = func(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
static var getter: Callable = func() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func is_fullscreen() -> bool:
	return bool(getter.call())


static func set_fullscreen(on: bool) -> void:
	setter.call(on)


## Flips full screen and returns the new state.
static func toggle() -> bool:
	var next := not is_fullscreen()
	set_fullscreen(next)
	return next


## Applies the saved choice at start (never on the web: it needs a tap).
static func apply_saved(on_web: bool = OS.has_feature("web")) -> void:
	if GameSettings.fullscreen and not on_web:
		set_fullscreen(true)
