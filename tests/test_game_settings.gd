extends GutTest


func before_each() -> void:
	GameSettings.reset()


func after_each() -> void:
	GameSettings.reset()


func test_defaults_are_point_eight() -> void:
	assert_eq(GameSettings.music_volume, 0.8)
	assert_eq(GameSettings.sfx_volume, 0.8)


func test_apply_clamps_to_zero_and_one() -> void:
	GameSettings.apply({"music": 3.0, "sfx": -2.0})
	assert_eq(GameSettings.music_volume, 1.0)
	assert_eq(GameSettings.sfx_volume, 0.0)


func test_apply_ignores_unknown_keys_and_wrong_types() -> void:
	GameSettings.apply({"music": "loud", "sfx": null, "nonsense": 1.0})
	assert_eq(GameSettings.music_volume, 0.8)
	assert_eq(GameSettings.sfx_volume, 0.8)
	GameSettings.apply({"music": 1})
	assert_eq(GameSettings.music_volume, 1.0, "a whole number is a number")


func test_to_dict_round_trips() -> void:
	GameSettings.music_volume = 0.3
	GameSettings.sfx_volume = 0.6
	var saved := GameSettings.to_dict()
	GameSettings.reset()
	GameSettings.apply(saved)
	assert_almost_eq(GameSettings.music_volume, 0.3, 0.0001)
	assert_almost_eq(GameSettings.sfx_volume, 0.6, 0.0001)


func test_reset_restores_defaults() -> void:
	GameSettings.music_volume = 0.1
	GameSettings.reset()
	assert_eq(GameSettings.music_volume, 0.8)
