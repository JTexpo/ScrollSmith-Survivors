extends GutTest

var _toast: LevelToast
var _track: LevelTrack


func before_each() -> void:
	_toast = load("res://scenes/ui/level_toast.tscn").instantiate() as LevelToast
	add_child_autofree(_toast)
	_track = LevelTrack.default_track()


func _show(level: int) -> void:
	_toast.show_level_up(level, _track.reward_for_level(level))


func test_hidden_until_shown() -> void:
	assert_false(_toast.is_showing())


func test_shows_level_and_description() -> void:
	_show(5)
	assert_true(_toast.is_showing())
	assert_eq(_toast.text, "Level 5! Slot 2 unlocked")


func test_back_to_back_level_ups_are_listed_not_replaced() -> void:
	_show(2)
	_show(3)
	assert_eq(_toast.text, "Level 2! Faster movement\nLevel 3! More health")


func test_only_the_last_four_lines_are_kept() -> void:
	for level in range(2, 8):
		_show(level)
	var lines := _toast.text.split("\n")
	assert_eq(lines.size(), 4)
	assert_true(lines[0].begins_with("Level 4!"))
	assert_true(lines[3].begins_with("Level 7!"))


func test_hides_after_its_duration_and_starts_a_fresh_list() -> void:
	_show(2)
	_toast._process(LevelToast.DURATION + 0.1)
	assert_false(_toast.is_showing())
	_show(3)
	assert_eq(_toast.text, "Level 3! More health")


func test_ignores_the_mouse() -> void:
	assert_eq(_toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_show_message_appends_a_line_without_a_level_prefix() -> void:
	_toast.show_message("Starting spell gains Increased Damage")
	assert_true(_toast.is_showing())
	assert_eq(_toast.text, "Starting spell gains Increased Damage")
	_show(2)
	assert_eq(_toast.text, "Starting spell gains Increased Damage\nLevel 2! Faster movement")


func test_messages_and_level_ups_share_the_four_line_cap() -> void:
	for i in 3:
		_toast.show_message("note %d" % i)
	_show(2)
	_show(3)
	var lines := _toast.text.split("\n")
	assert_eq(lines.size(), 4)
	assert_eq(lines[0], "note 1")
	assert_true(lines[3].begins_with("Level 3!"))


func test_the_level_toast_is_a_dark_pill_with_outlined_text() -> void:
	assert_eq(_toast.theme_type_variation, &"HudToast")
	assert_eq(_toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_pill_shrinks_to_its_text() -> void:
	_show(3)
	var one_line := _toast.size.y
	_show(4)
	assert_gt(_toast.size.y, one_line, "a second line makes the pill taller")


func test_the_toast_stays_centred_when_its_text_changes() -> void:
	var toast := load("res://scenes/ui/level_toast.tscn").instantiate() as LevelToast
	toast.position = Vector2(150, 44)
	toast.size = Vector2(180, 46)
	add_child_autofree(toast)
	toast.show_message("Boss defeated!")
	assert_almost_eq(toast.position.x + toast.size.x * 0.5, 240.0, 0.51)
	toast.show_message("A much longer message on a second line")
	assert_almost_eq(toast.position.x + toast.size.x * 0.5, 240.0, 0.51)
	toast.show_message("W".repeat(50))
	assert_gte(toast.position.x, 0.0)
	assert_lte(toast.position.x + toast.size.x, UiKit.SCREEN_WIDTH)
