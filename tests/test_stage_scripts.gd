extends GutTest
## The five shipped scenes: the home fight and the four tutorial vignettes. They are data, so these tests read them, check them and play
## them on a stage.

const PATHS := {
	"home_fight": "res://resources/stage/home_fight.tres",
	"survive": "res://resources/stage/tutorial_survive.tres",
	"cast": "res://resources/stage/tutorial_cast.tres",
	"scrolls": "res://resources/stage/tutorial_scrolls.tres",
	"potions": "res://resources/stage/tutorial_potions.tres",
}


func before_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	FxSettings.reset()


func after_each() -> void:
	FxSettings.reset()


func _script(key: String) -> StageScript:
	return load(PATHS[key]) as StageScript


func _count(script: StageScript, action: StageBeat.Action, animation: StringName = &"") -> int:
	var count := 0
	for beat in script.beats:
		if beat.action == action and (animation == &"" or beat.animation == animation):
			count += 1
	return count


func _actor_sprites(script: StageScript) -> Array[StringName]:
	var found: Array[StringName] = []
	for actor in script.actors:
		found.append(&"player_body" if actor.wizard else actor.sprite)
	return found


func test_every_script_loads_and_has_no_problems() -> void:
	for key in PATHS:
		var script := _script(key)
		assert_not_null(script, key)
		if script != null:
			assert_eq(script.problems(), PackedStringArray(), "%s: %s" % [key, str(script.problems())])


func test_the_home_fight_has_a_wizard_and_enemies_that_are_shot_and_pop() -> void:
	var script := _script("home_fight")
	var wizards := script.actors.filter(func(a: StageActor) -> bool: return a.wizard)
	assert_eq(wizards.size(), 1)
	var enemies := script.actors.filter(func(a: StageActor) -> bool: return String(a.sprite).begins_with("enemy_"))
	assert_gte(enemies.size(), 3)
	assert_gte(_count(script, StageBeat.Action.SHOOT), 3)
	assert_gte(_count(script, StageBeat.Action.PLAY, &"death"), 3)
	assert_gte(_count(script, StageBeat.Action.BURST), 3)
	assert_gte(script.loop_seconds, 10.0)
	assert_lte(script.loop_seconds, 18.0)
	assert_eq(script.size, Vector2i(480, 212), "the grass runs down to the bottom of the screen behind the buttons")


func test_a_tougher_enemy_takes_two_hits() -> void:
	var script := _script("home_fight")
	var shots_at := {}
	for beat in script.beats:
		if beat.action == StageBeat.Action.SHOOT:
			shots_at[beat.time] = true
	assert_gt(_count(script, StageBeat.Action.SHOOT), _count(script, StageBeat.Action.PLAY, &"death"), "more shots than deaths: one enemy takes two")


func test_each_vignette_matches_its_page() -> void:
	var survive := _script("survive")
	assert_gte(_count(survive, StageBeat.Action.WALK_TO), 1)
	assert_gte(_count(survive, StageBeat.Action.HIDE), 2, "an XP gem and a coin are collected")
	assert_true(_actor_sprites(survive).has(&"pickup_xp") and _actor_sprites(survive).has(&"pickup_gold"))
	var cast := _script("cast")
	assert_gte(_count(cast, StageBeat.Action.SHOOT), 1)
	assert_true(_actor_sprites(cast).has(&"reticle"))
	var scrolls := _script("scrolls")
	assert_true(_actor_sprites(scrolls).has(&"scroll_base") and _actor_sprites(scrolls).has(&"lectern"))
	var first_death := INF
	var scroll_shown := INF
	var scroll_id: StringName = &""
	for actor in scrolls.actors:
		if actor.sprite == &"scroll_base":
			scroll_id = actor.id
	for beat in scrolls.beats:
		if beat.action == StageBeat.Action.PLAY and beat.animation == &"death":
			first_death = minf(first_death, beat.time)
		if beat.action == StageBeat.Action.SHOW and beat.actor == scroll_id:
			scroll_shown = minf(scroll_shown, beat.time)
	assert_gte(scroll_shown, first_death, "the scroll drops after the enemy pops")
	var potions := _script("potions")
	assert_true(_actor_sprites(potions).has(&"icon_potion") and _actor_sprites(potions).has(&"poi_merchant"))


func test_each_script_loops_cleanly() -> void:
	for key in PATHS:
		var script := _script(key)
		var stage := Stage.new()
		add_child_autofree(stage)
		stage.play(script)
		stage.set_process(false)
		var start := {}
		for actor in script.actors:
			start[actor.id] = stage.actor(actor.id).position
		stage.advance(script.loop_seconds)
		await get_tree().process_frame
		stage.advance(script.loop_seconds * 2.0)
		assert_eq(stage.elapsed(), 0.0, key)
		for actor in script.actors:
			assert_eq(stage.actor(actor.id).position, start[actor.id], "%s: %s is back at its start" % [key, actor.id])
		assert_eq(stage.orb_count(), 0, key)
		assert_eq(stage.effect_count(), 0, "%s: nothing left at the wrap" % key)


func test_a_still_frame_exists_inside_each_loop() -> void:
	for key in PATHS:
		var script := _script(key)
		assert_between(script.still_time, 0.0, script.loop_seconds, key)
		var stage := Stage.new()
		add_child_autofree(stage)
		stage.play(script)
		stage.set_process(false)
		var starts := {}
		var shown := {}
		for actor in script.actors:
			starts[actor.id] = stage.actor(actor.id).position
			shown[actor.id] = stage.actor(actor.id).visible
		stage.seek(script.still_time)
		var moved := stage.orb_count() > 0
		for actor in script.actors:
			if stage.actor(actor.id).position != starts[actor.id] or stage.actor(actor.id).visible != shown[actor.id]:
				moved = true
		assert_true(moved, "%s: the still frame is not an empty field" % key)


func test_enemies_never_reach_the_wizard_in_the_home_fight() -> void:
	var script := _script("home_fight")
	var stage := Stage.new()
	add_child_autofree(stage)
	stage.play(script)
	var wizard_x := 0.0
	for actor in script.actors:
		if actor.wizard:
			wizard_x = actor.start.x
	var t := 0.0
	while t < script.loop_seconds:
		stage.seek(t)
		for actor in script.actors:
			if String(actor.sprite).begins_with("enemy_") and stage.actor(actor.id).visible:
				assert_gt(stage.actor(actor.id).position.x, wizard_x + 40.0, "%s at %.1f s" % [actor.id, t])
		t += 0.25


func test_the_tutorial_vignettes_are_small_enough_for_the_tutorial_frame() -> void:
	for key in ["survive", "cast", "scrolls", "potions"]:
		var script := _script(key)
		assert_lte(script.size.x, 320, key)
		assert_lte(script.size.y, 96, key)
		assert_gte(script.loop_seconds, 5.0, key)
		assert_lte(script.loop_seconds, 12.0, key)


func test_no_scene_uses_the_bird_s_eye_tree_in_a_side_on_view() -> void:
	for key in PATHS:
		for piece in _script(key).scenery:
			assert_ne(piece.sprite, &"post_tree", "%s: the top-down tree does not belong in a side-on scene" % key)
	var sides := 0
	for piece in _script("home_fight").scenery:
		if String(piece.sprite).begins_with("tree_side"):
			sides += 1
	assert_gte(sides, 6, "the home scene is framed by side-view trees")


func test_trees_stand_on_the_grass_not_on_the_horizon_and_never_over_the_button_row() -> void:
	for key in PATHS:
		var script := _script(key)
		for piece in script.scenery:
			if not String(piece.sprite).begins_with("tree_side"):
				continue
			assert_gte(piece.position.y, script.ground_top + 20.0, "%s: a tree at base y %s stands on the horizon line" % [key, str(piece.position.y)])
			if key == "home_fight":
				var buttons_top := HomeScreen.BUTTONS_Y - HomeScreen.STAGE_RECT.position.y
				assert_lt(piece.position.y, buttons_top, "home_fight: a tree base at stage y %s would sit among the buttons (they start at %s)" % [str(piece.position.y), str(buttons_top)])

