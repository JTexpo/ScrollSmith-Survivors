extends GutTest
## The unlock toast shows "Achievement unlocked: ..." one at a time, queues the rest, freezes while paused and never takes a touch.

var _toast: AchievementToast


func before_each() -> void:
	_toast = (load("res://scenes/ui/achievement_toast.tscn") as PackedScene).instantiate() as AchievementToast
	add_child_autofree(_toast)


func after_each() -> void:
	get_tree().paused = false


func _data(description: String) -> AchievementData:
	var data := AchievementData.new()
	data.id = StringName(description)
	data.description = description
	return data


func test_it_is_hidden_until_an_unlock() -> void:
	assert_false(_toast.is_showing())
	assert_eq(_toast.queued_count(), 0)


func test_it_shows_the_text_of_an_unlock() -> void:
	_toast.show_unlocked(_data("defeat the Tempest Dragon"))
	assert_true(_toast.is_showing())
	assert_eq(_toast.text, "Achievement unlocked: defeat the Tempest Dragon")


func test_several_unlocks_queue_and_show_one_after_another() -> void:
	_toast.show_unlocked(_data("reach level 5"))
	_toast.show_unlocked(_data("survive 5 minutes"))
	_toast.show_unlocked(_data("earn 1000 Gold"))
	assert_eq(_toast.text, "Achievement unlocked: reach level 5")
	assert_eq(_toast.queued_count(), 2)
	_toast._process(AchievementToast.DURATION + 0.01)
	assert_eq(_toast.text, "Achievement unlocked: survive 5 minutes")
	assert_eq(_toast.queued_count(), 1)
	_toast._process(AchievementToast.DURATION + 0.01)
	assert_eq(_toast.text, "Achievement unlocked: earn 1000 Gold")
	assert_eq(_toast.queued_count(), 0)


func test_it_hides_after_its_duration() -> void:
	_toast.show_unlocked(_data("reach level 5"))
	_toast._process(AchievementToast.DURATION - 0.1)
	assert_true(_toast.is_showing())
	_toast._process(0.2)
	assert_false(_toast.is_showing())


func test_it_fades_out_in_the_last_half_second() -> void:
	_toast.show_unlocked(_data("reach level 5"))
	_toast._process(AchievementToast.DURATION - AchievementToast.FADE * 0.5)
	assert_lt(_toast.modulate.a, 1.0)
	assert_gt(_toast.modulate.a, 0.0)


func test_it_freezes_while_the_tree_is_paused() -> void:
	_toast.show_unlocked(_data("reach level 5"))
	_toast.show_unlocked(_data("reach level 10"))
	get_tree().paused = true
	await get_tree().create_timer(AchievementToast.DURATION + 0.5, true, false, true).timeout
	assert_true(_toast.is_showing(), "a paused game does not run the toast down")
	assert_eq(_toast.text, "Achievement unlocked: reach level 5")
	assert_eq(_toast.queued_count(), 1)


func test_it_never_takes_a_touch() -> void:
	assert_eq(_toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_toast.show_unlocked(_data("reach level 5"))
	assert_eq(_toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_it_uses_the_hud_toast_look() -> void:
	assert_eq(_toast.theme_type_variation, &"HudToast")
