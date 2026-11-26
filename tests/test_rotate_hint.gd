extends GutTest
## The rotate hint: a card for a touch browser held upright, which also pauses the game while it shows.

const PORTRAIT := Vector2(300, 600)
const LANDSCAPE := Vector2(600, 300)

var _hint: RotateHint


func before_each() -> void:
	get_tree().paused = false
	GameTime.unfreeze()
	_hint = (load("res://scenes/ui/rotate_hint.tscn") as PackedScene).instantiate() as RotateHint
	add_child_autofree(_hint)
	# The real window is a desktop here; the tests drive `update_for` themselves.
	_hint.set_process(false)


func after_each() -> void:
	get_tree().paused = false
	GameTime.unfreeze()


func test_should_show_only_for_a_touch_browser_in_portrait() -> void:
	assert_true(RotateHint.should_show(PORTRAIT, true, true))
	assert_false(RotateHint.should_show(LANDSCAPE, true, true))
	assert_false(RotateHint.should_show(Vector2(400, 400), true, true))
	assert_false(RotateHint.should_show(PORTRAIT, true, false))
	assert_false(RotateHint.should_show(PORTRAIT, false, true))


func test_the_card_shows_and_pauses_in_portrait() -> void:
	_hint.update_for(PORTRAIT, true, true)
	assert_true(_hint.is_showing())
	assert_true(_hint.card().visible)
	assert_true(get_tree().paused)


func test_turning_back_hides_it_and_resumes() -> void:
	_hint.update_for(PORTRAIT, true, true)
	_hint.update_for(LANDSCAPE, true, true)
	assert_false(_hint.is_showing())
	assert_false(_hint.card().visible)
	assert_false(get_tree().paused)
	assert_false(GameTime.is_frozen())


func test_it_does_not_unpause_what_it_did_not_pause() -> void:
	GamePause.set_paused(get_tree(), true)
	_hint.update_for(PORTRAIT, true, true)
	_hint.update_for(LANDSCAPE, true, true)
	assert_true(get_tree().paused, "the pause menu's pause is left alone")


func test_it_does_not_pause_twice_then_unpause_wrongly() -> void:
	_hint.update_for(PORTRAIT, true, true)
	_hint.update_for(PORTRAIT, true, true)
	_hint.update_for(LANDSCAPE, true, true)
	assert_false(get_tree().paused)
	assert_false(GameTime.is_frozen())


func test_it_never_shows_on_a_desktop() -> void:
	_hint.update_for(PORTRAIT, false, false)
	assert_false(_hint.is_showing())
	assert_false(get_tree().paused)


func test_the_card_ignores_touches_and_is_hidden_when_not_showing() -> void:
	assert_false(_hint.card().visible)
	assert_eq(_hint.card().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_hint.update_for(PORTRAIT, true, true)
	assert_eq(_hint.card().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in _hint.card().find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, child.name)


func test_the_hint_keeps_running_while_the_game_is_paused() -> void:
	assert_eq(_hint.process_mode, Node.PROCESS_MODE_ALWAYS)
