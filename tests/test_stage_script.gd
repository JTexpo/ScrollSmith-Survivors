extends GutTest
## A stage script is data; `problems()` reports every fault a builder could make in one.


func _actor(id: StringName = &"wizard", sprite: StringName = &"player") -> StageActor:
	var actor := StageActor.new()
	actor.id = id
	actor.sprite = sprite
	if sprite.begins_with("enemy_"):
		actor.variant = &"none"
	actor.start = Vector2(40, 100)
	return actor


func _beat(time: float, actor: StringName, action: StageBeat.Action) -> StageBeat:
	var beat := StageBeat.new()
	beat.time = time
	beat.actor = actor
	beat.action = action
	return beat


func _script() -> StageScript:
	var script := StageScript.new()
	script.size = Vector2i(480, 160)
	script.loop_seconds = 8.0
	script.still_time = 3.0
	script.actors = [_actor(&"wizard", &"player"), _actor(&"goblin", &"enemy_standard")] as Array[StageActor]
	var shoot := _beat(1.0, &"wizard", StageBeat.Action.SHOOT)
	shoot.to = Vector2(300, 100)
	shoot.duration = 0.5
	shoot.effect = &"fx_fire_orb_16"
	var burst := _beat(1.5, &"", StageBeat.Action.BURST)
	burst.to = Vector2(300, 100)
	burst.effect = &"fx_fire_burst"
	var walk := _beat(2.0, &"goblin", StageBeat.Action.WALK_TO)
	walk.to = Vector2(200, 100)
	walk.duration = 2.0
	script.beats = [shoot, burst, walk] as Array[StageBeat]
	return script


func test_a_good_script_has_no_problems() -> void:
	assert_eq(_script().problems(), PackedStringArray(), str(_script().problems()))


func test_a_loop_of_zero_or_less_is_a_problem() -> void:
	var script := _script()
	script.loop_seconds = 0.0
	assert_gt(script.problems().size(), 0)


func test_a_still_time_outside_the_loop_is_a_problem() -> void:
	var script := _script()
	script.still_time = 9.0
	assert_gt(script.problems().size(), 0)
	script.still_time = -1.0
	assert_gt(script.problems().size(), 0)


func test_an_actor_with_no_id_or_a_duplicate_id_is_a_problem() -> void:
	var script := _script()
	script.actors[0].id = &""
	assert_gt(script.problems().size(), 0)
	script = _script()
	script.actors[1].id = &"wizard"
	assert_gt(script.problems().size(), 0)


func test_a_beat_naming_no_actor_is_a_problem_except_a_burst() -> void:
	var script := _script()
	script.beats[2].actor = &"nobody"
	assert_gt(script.problems().size(), 0)
	script = _script()
	script.beats[2].actor = &""
	assert_gt(script.problems().size(), 0, "a walk needs an actor")
	assert_eq(_script().problems().size(), 0, "a burst needs none")


func test_a_beat_before_zero_or_after_the_loop_is_a_problem() -> void:
	var script := _script()
	script.beats[0].time = -0.5
	assert_gt(script.problems().size(), 0)
	script = _script()
	script.beats[2].time = 8.5
	assert_gt(script.problems().size(), 0)


func test_beats_out_of_time_order_are_a_problem() -> void:
	var script := _script()
	script.beats = [script.beats[2], script.beats[0], script.beats[1]] as Array[StageBeat]
	assert_gt(script.problems().size(), 0)


func test_a_missing_sprite_is_a_problem_for_an_actor_scenery_and_an_effect() -> void:
	var script := _script()
	script.actors[0].sprite = &"nothing_like_this"
	assert_gt(script.problems().size(), 0)
	script = _script()
	var tree := StageScenery.new()
	tree.sprite = &"nothing_like_this"
	script.scenery = [tree] as Array[StageScenery]
	assert_gt(script.problems().size(), 0)
	script = _script()
	script.beats[0].effect = &"nothing_like_this"
	assert_gt(script.problems().size(), 0)


func test_a_shoot_or_burst_with_no_effect_is_a_problem() -> void:
	var script := _script()
	script.beats[0].effect = &""
	assert_gt(script.problems().size(), 0)
	script = _script()
	script.beats[1].effect = &""
	assert_gt(script.problems().size(), 0)


func test_a_walk_or_shoot_with_no_duration_is_a_problem() -> void:
	var script := _script()
	script.beats[2].duration = 0.0
	assert_gt(script.problems().size(), 0)
	script = _script()
	script.beats[0].duration = 0.0
	assert_gt(script.problems().size(), 0)


func test_the_wizard_actor_needs_the_player_body_not_its_own_sprite_name() -> void:
	var script := _script()
	script.actors[0].wizard = true
	script.actors[0].sprite = &""
	assert_eq(script.problems(), PackedStringArray(), "a wizard actor draws the equipped look, so its sprite field is not checked")
