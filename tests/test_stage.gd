extends GutTest
## The stage plays a script: actors walk, animate, shoot orbs and burst sparks, and a loop wraps with nothing left behind.

var _stage: Stage


func before_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	FxSettings.reset()
	_stage = Stage.new()
	add_child_autofree(_stage)


func after_each() -> void:
	FxSettings.reset()
	get_tree().paused = false


func _actor(id: StringName, sprite: StringName, start: Vector2, animation: StringName = &"idle") -> StageActor:
	var actor := StageActor.new()
	actor.id = id
	actor.sprite = sprite
	if sprite.begins_with("enemy_"):
		actor.variant = &"none"
	actor.start = start
	actor.animation = animation
	return actor


func _beat(time: float, actor: StringName, action: StageBeat.Action) -> StageBeat:
	var beat := StageBeat.new()
	beat.time = time
	beat.actor = actor
	beat.action = action
	return beat


func _script(beats: Array[StageBeat] = [] as Array[StageBeat], loop: float = 10.0) -> StageScript:
	var script := StageScript.new()
	script.size = Vector2i(480, 160)
	script.loop_seconds = loop
	script.still_time = loop / 2.0
	script.sky_color = Color("6fd3ff")
	script.actors = [_actor(&"wizard", &"player", Vector2(40, 100)), _actor(&"goblin", &"enemy_standard", Vector2(440, 100), &"move")] as Array[StageActor]
	script.beats = beats
	return script


func _walk(time: float, actor: StringName, to: Vector2, duration: float) -> StageBeat:
	var beat := _beat(time, actor, StageBeat.Action.WALK_TO)
	beat.to = to
	beat.duration = duration
	return beat


func _shoot(time: float, to: Vector2, duration: float) -> StageBeat:
	var beat := _beat(time, &"wizard", StageBeat.Action.SHOOT)
	beat.to = to
	beat.duration = duration
	beat.effect = &"fx_fire_orb_16"
	return beat


func _burst(time: float, at: Vector2) -> StageBeat:
	var beat := _beat(time, &"", StageBeat.Action.BURST)
	beat.to = at
	beat.effect = &"fx_fire_burst"
	return beat


func test_an_actor_starts_where_the_script_puts_it() -> void:
	_stage.play(_script())
	assert_eq(_stage.actor(&"wizard").position, Vector2(40, 100))
	assert_eq(_stage.actor(&"goblin").position, Vector2(440, 100))
	assert_eq(_stage.actor(&"goblin").current_animation(), &"move")
	assert_true(_stage.is_playing())


func test_walk_to_moves_an_actor_linearly_and_faces_it_that_way() -> void:
	_stage.play(_script([_walk(1.0, &"goblin", Vector2(240, 100), 2.0)] as Array[StageBeat]))
	_stage.advance(2.0)
	assert_almost_eq(_stage.actor(&"goblin").position.x, 340.0, 0.01, "half way after one of two seconds")
	_stage.advance(1.5)
	assert_almost_eq(_stage.actor(&"goblin").position.x, 240.0, 0.01, "arrived")
	assert_eq(_stage.actor(&"goblin")._facing, -1.0, "walking left faces left")


func test_a_walker_plays_its_walk_animation_and_returns_to_its_own_after_arriving() -> void:
	var beat := _walk(1.0, &"wizard", Vector2(120, 100), 1.0)
	beat.animation = &"move"
	_stage.play(_script([beat] as Array[StageBeat]))
	_stage.advance(1.5)
	assert_eq(_stage.actor(&"wizard").current_animation(), &"move")
	_stage.advance(1.0)
	assert_eq(_stage.actor(&"wizard").current_animation(), &"idle", "back to the actor's own animation")


func test_a_play_beat_changes_the_animation() -> void:
	var beat := _beat(1.0, &"wizard", StageBeat.Action.PLAY)
	beat.animation = &"cast"
	_stage.play(_script([beat] as Array[StageBeat]))
	assert_eq(_stage.actor(&"wizard").current_animation(), &"idle")
	_stage.advance(1.1)
	assert_eq(_stage.actor(&"wizard").current_animation(), &"cast")


func test_show_and_hide_toggle_an_actor_and_visible_at_start_is_honoured() -> void:
	var hidden := _script([_beat(1.0, &"goblin", StageBeat.Action.SHOW), _beat(2.0, &"goblin", StageBeat.Action.HIDE)] as Array[StageBeat])
	hidden.actors[1].visible_at_start = false
	_stage.play(hidden)
	assert_false(_stage.actor(&"goblin").visible)
	_stage.advance(1.5)
	assert_true(_stage.actor(&"goblin").visible)
	_stage.advance(1.0)
	assert_false(_stage.actor(&"goblin").visible)


func test_face_turns_an_actor() -> void:
	var beat := _beat(1.0, &"wizard", StageBeat.Action.FACE)
	beat.facing = -1.0
	_stage.play(_script([beat] as Array[StageBeat]))
	_stage.advance(1.1)
	assert_eq(_stage.actor(&"wizard")._facing, -1.0)


func test_shoot_launches_an_orb_that_arrives_at_its_target_and_is_gone_after() -> void:
	_stage.play(_script([_shoot(1.0, Vector2(300, 100), 1.0)] as Array[StageBeat]))
	assert_eq(_stage.orb_count(), 0)
	_stage.advance(1.5)
	assert_eq(_stage.orb_count(), 1, "in flight")
	_stage.advance(1.0)
	assert_eq(_stage.orb_count(), 0, "it arrived and is gone")


func test_burst_spawns_a_spark_unless_particles_are_off() -> void:
	_stage.play(_script([_burst(1.0, Vector2(200, 100))] as Array[StageBeat]))
	_stage.advance(1.1)
	assert_eq(_stage.effect_count(), 1)
	FxSettings.particles = false
	var second := Stage.new()
	add_child_autofree(second)
	second.play(_script([_burst(1.0, Vector2(200, 100))] as Array[StageBeat]))
	second.advance(1.1)
	assert_eq(second.effect_count(), 0, "the particles switch removes sparks")


func test_the_wrap_resets_every_actor_and_frees_every_orb_and_spark() -> void:
	_stage.play(_script([_walk(1.0, &"goblin", Vector2(240, 100), 2.0), _shoot(2.0, Vector2(300, 100), 8.0), _burst(8.0, Vector2(200, 100))] as Array[StageBeat], 10.0))
	_stage.advance(9.0)
	assert_eq(_stage.orb_count(), 1, "still flying")
	assert_eq(_stage.effect_count(), 1)
	assert_lt(_stage.actor(&"goblin").position.x, 440.0)
	_stage.advance(1.0)
	assert_eq(_stage.elapsed(), 0.0, "wrapped")
	assert_eq(_stage.actor(&"goblin").position, Vector2(440, 100))
	assert_eq(_stage.actor(&"goblin").current_animation(), &"move")
	assert_eq(_stage.orb_count(), 0)
	assert_eq(_stage.effect_count(), 0)


func test_many_loops_do_not_grow_the_node_count() -> void:
	_stage.play(_script([_shoot(1.0, Vector2(300, 100), 1.0), _burst(2.0, Vector2(200, 100)), _walk(3.0, &"goblin", Vector2(240, 100), 2.0)] as Array[StageBeat], 6.0))
	_stage.advance(6.0)
	await get_tree().process_frame
	var baseline := _stage.get_child_count()
	for i in 20:
		_stage.advance(6.0)
	await get_tree().process_frame
	assert_eq(_stage.get_child_count(), baseline, "a loop leaves nothing behind")
	assert_eq(_stage.orb_count(), 0)
	assert_eq(_stage.effect_count(), 0)


func test_orbs_and_sparks_never_exceed_their_caps() -> void:
	var beats: Array[StageBeat] = []
	for i in 40:
		beats.append(_shoot(0.1 + i * 0.01, Vector2(300, 100), 5.0))
	for i in 60:
		beats.append(_burst(1.0 + i * 0.01, Vector2(200, 100)))
	_stage.play(_script(beats, 10.0))
	_stage.advance(2.0)
	assert_lte(_stage.orb_count(), Stage.MAX_ORBS)
	assert_lte(_stage.effect_count(), Stage.MAX_EFFECTS)


func test_seek_is_deterministic() -> void:
	_stage.play(_script([_walk(1.0, &"goblin", Vector2(240, 100), 4.0), _shoot(2.0, Vector2(300, 100), 3.0)] as Array[StageBeat]))
	_stage.seek(3.3)
	var first := _stage.actor(&"goblin").position
	var first_orbs := _stage.orb_count()
	_stage.seek(7.0)
	_stage.seek(3.3)
	assert_eq(_stage.actor(&"goblin").position, first)
	assert_eq(_stage.orb_count(), first_orbs)
	assert_almost_eq(first.x, 440.0 - 200.0 * (2.3 / 4.0), 0.01)


func test_a_big_step_gives_the_same_state_as_many_small_ones() -> void:
	var beats := [_walk(1.0, &"goblin", Vector2(240, 100), 4.0), _walk(3.0, &"goblin", Vector2(100, 120), 2.0)] as Array[StageBeat]
	_stage.play(_script(beats))
	_stage.advance(4.5)
	var big := _stage.actor(&"goblin").position
	var other := Stage.new()
	add_child_autofree(other)
	other.play(_script(beats))
	for i in 45:
		other.advance(0.1)
	assert_almost_eq(other.actor(&"goblin").position.x, big.x, 0.05)
	assert_almost_eq(other.actor(&"goblin").position.y, big.y, 0.05)


func test_stop_halts_processing_and_clears_effects() -> void:
	_stage.play(_script([_shoot(0.5, Vector2(300, 100), 5.0), _burst(0.5, Vector2(200, 100))] as Array[StageBeat]))
	_stage.advance(1.0)
	assert_gt(_stage.orb_count() + _stage.effect_count(), 0)
	_stage.stop()
	assert_false(_stage.is_playing())
	assert_false(_stage.is_processing())
	assert_eq(_stage.orb_count(), 0)
	assert_eq(_stage.effect_count(), 0)


func test_reduced_motion_builds_the_still_frame_and_never_processes() -> void:
	FxSettings.reduce_motion()
	_stage.play(_script([_walk(1.0, &"goblin", Vector2(240, 100), 4.0), _burst(4.0, Vector2(200, 100))] as Array[StageBeat], 10.0))
	assert_false(_stage.is_processing())
	assert_false(_stage.is_playing())
	assert_almost_eq(_stage.actor(&"goblin").position.x, 440.0 - 200.0 * (4.0 / 4.0) , 0.01, "the walk is where it is at still_time (5 s), arrived")
	assert_eq(_stage.effect_count(), 0, "no sparks in a still frame")


func test_a_missing_sprite_falls_back_without_crashing() -> void:
	var script := _script()
	script.actors[1].sprite = &"nothing_like_this"
	_stage.play(script)
	assert_not_null(_stage.actor(&"goblin"))
	assert_false(_stage.actor(&"goblin").has_art())
	_stage.advance(1.0)


func test_the_wizard_actor_wears_the_equipped_look() -> void:
	var script := _script()
	script.actors[0].wizard = true
	var catalog := EquipmentCatalog.default_catalog()
	var profile := PlayerProfile.new()
	var robe: EquipmentData = null
	for item in catalog.items:
		if item.slot() == EquipmentData.Slot.ROBE:
			robe = item
			break
	assert_not_null(robe)
	profile.grant(robe.id)
	profile.equip(int(EquipmentData.Slot.ROBE), robe.id)
	_stage.play(script, profile, catalog)
	var body := _stage.actor(&"wizard")
	for layer in [&"robe", &"beard", &"headwear", &"weapon"]:
		assert_true(body.layer_names().has(layer), String(layer))
	var bare := Stage.new()
	add_child_autofree(bare)
	bare.play(script)
	assert_true(bare.actor(&"wizard").layer_names().has(&"robe"), "an empty profile shows the starter")


func test_the_stage_ignores_touches() -> void:
	_stage.play(_script([_walk(1.0, &"goblin", Vector2(240, 100), 2.0)] as Array[StageBeat]))
	assert_eq(_stage.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node in _stage.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.name))
	assert_true(_stage.clip_contents)


func test_play_again_replaces_the_previous_scene() -> void:
	_stage.play(_script())
	var first_count := _stage.get_child_count()
	_stage.play(_script())
	await get_tree().process_frame
	assert_eq(_stage.get_child_count(), first_count)


func test_stop_cancels_a_walk_where_the_actor_stands_and_returns_it_to_its_own_animation() -> void:
	var stop := _beat(2.0, &"goblin", StageBeat.Action.STOP)
	_stage.play(_script([_walk(1.0, &"goblin", Vector2(240, 100), 4.0), stop] as Array[StageBeat]))
	_stage.advance(2.0)
	var stood := _stage.actor(&"goblin").position
	assert_almost_eq(stood.x, 440.0 - 200.0 * 0.25, 0.01)
	_stage.advance(2.0)
	assert_eq(_stage.actor(&"goblin").position, stood, "it never moved again")
	assert_eq(_stage.actor(&"goblin").current_animation(), &"move", "back to its own animation")


func test_the_sky_the_ground_and_the_shadows_draw_in_the_stage_not_under_whatever_is_behind_it() -> void:
	var script := _script()
	script.ground_style = &"grass"
	script.ground_top = 60.0
	_stage.play(script)
	for node_name in ["Sky", "Ground"]:
		var node := _stage.get_node(node_name) as CanvasItem
		assert_true(node.z_as_relative, "%s is relative to the stage, so a backdrop behind the stage cannot cover it" % node_name)
		assert_eq(node.z_index, 0, node_name)
	for id in [&"wizard", &"goblin"]:
		var shadow := _stage.actor(id).get_node("Shadow") as Sprite2D
		assert_true(shadow.z_as_relative, "the shadow of %s is relative to its body, not at the world's absolute depth" % id)
		assert_eq(shadow.z_index, 0)
		assert_eq(shadow.get_index(), 0, "and the first child, so the body draws over it")
	assert_lt(_stage.get_node("Sky").get_index(), _stage.get_node("Ground").get_index(), "sky first, then ground, then everything else")
	assert_lt(_stage.get_node("Ground").get_index(), _stage.get_node("World").get_index())


func test_nothing_in_the_stage_sits_above_depth_zero_so_a_control_placed_after_it_draws_over_it() -> void:
	var script := _script([_shoot(0.5, Vector2(300, 100), 3.0), _burst(0.6, Vector2(200, 100))] as Array[StageBeat])
	var tree := StageScenery.new()
	tree.sprite = &"tree_side"
	tree.position = Vector2(300, 90)
	script.scenery = [tree] as Array[StageScenery]
	_stage.play(script)
	_stage.advance(1.0)
	for item in _stage.find_children("*", "CanvasItem", true, false):
		assert_eq((item as CanvasItem).z_index, 0, "%s: a positive depth would draw over the buttons that follow the stage" % item.name)
	assert_true((_stage.get_node("World") as Node2D).y_sort_enabled, "depth is by Y-sort, not by z")


func test_actors_nearer_the_bottom_draw_in_front_of_those_further_up() -> void:
	var script := _script()
	script.actors[0].start = Vector2(100, 120)
	script.actors[1].start = Vector2(100, 100)
	_stage.play(script)
	var near := _stage.actor(&"wizard")
	var far := _stage.actor(&"goblin")
	assert_gt(near.position.y, far.position.y, "the lower actor sorts later and so draws on top")
	assert_true((_stage.get_node("World") as Node2D).y_sort_enabled)


func test_scenery_stands_on_its_position_and_sorts_by_its_base() -> void:
	var script := _script()
	var tree := StageScenery.new()
	tree.sprite = &"tree_side"
	tree.position = Vector2(300, 100)
	script.scenery = [tree] as Array[StageScenery]
	_stage.play(script)
	var holder := _stage.get_node("World").get_node("Scenery") as Node2D
	assert_eq(holder.position, Vector2(300, 100), "the holder is at the base point")
	var view := holder.get_child(0) as BodyView
	assert_eq(view.position, Vector2(0, -23), "the sprite rises from the base by half its height (46 px)")


func test_orbs_draw_over_the_actors() -> void:
	_stage.play(_script([_shoot(0.2, Vector2(300, 100), 3.0)] as Array[StageBeat]))
	_stage.advance(0.5)
	var overlay := _stage.get_node("Overlay") as Node2D
	assert_eq(overlay.get_child_count(), 1, "the orb is on the layer above the world")
	assert_gt(overlay.get_index(), _stage.get_node("World").get_index())


func test_resume_continues_from_where_stop_left_it() -> void:
	_stage.play(_script([_walk(1.0, &"goblin", Vector2(240, 100), 4.0)] as Array[StageBeat]))
	_stage.advance(3.0)
	var at := _stage.actor(&"goblin").position
	_stage.stop()
	_stage.resume()
	assert_true(_stage.is_playing())
	assert_eq(_stage.actor(&"goblin").position, at, "resuming does not restart the loop")
	_stage.advance(1.0)
	assert_lt(_stage.actor(&"goblin").position.x, at.x)


func test_resume_does_nothing_when_motion_is_reduced() -> void:
	FxSettings.reduce_motion()
	_stage.play(_script())
	_stage.resume()
	assert_false(_stage.is_playing())
	assert_false(_stage.is_processing())


func test_dress_wizard_changes_what_the_wizard_wears() -> void:
	var script := _script()
	script.actors[0].wizard = true
	var catalog := EquipmentCatalog.default_catalog()
	_stage.play(script, PlayerProfile.new(), catalog)
	var robe: EquipmentData = null
	for item in catalog.items:
		if item.slot() == EquipmentData.Slot.ROBE and item.sprite_name != &"":
			robe = item
			break
	var before: SpriteFrames = _stage.actor(&"wizard")._layers[&"robe"].sprite_frames
	var profile := PlayerProfile.new()
	profile.grant(robe.id)
	profile.equip(int(EquipmentData.Slot.ROBE), robe.id)
	_stage.dress_wizard(profile, catalog)
	assert_ne(_stage.actor(&"wizard")._layers[&"robe"].sprite_frames, before)


func test_stage_script_returns_the_script_it_plays() -> void:
	var script := _script()
	_stage.play(script)
	assert_eq(_stage.stage_script(), script)


func test_background_scenery_draws_behind_every_actor_however_far_down_it_stands() -> void:
	var script := _script()
	var bush := StageScenery.new()
	bush.sprite = &"bush"
	bush.position = Vector2(100, 150)
	bush.background = true
	var tree := StageScenery.new()
	tree.sprite = &"tree_side"
	tree.position = Vector2(300, 90)
	script.scenery = [bush, tree] as Array[StageScenery]
	script.ground_style = &"grass"
	script.ground_top = 50.0
	_stage.play(script)
	var background := _stage.get_node("Background") as Node2D
	var world := _stage.get_node("World") as Node2D
	assert_eq(background.get_child_count(), 1, "the bush is on the background layer")
	assert_lt(background.get_index(), world.get_index(), "behind the world")
	assert_gt(background.get_index(), _stage.get_node("Ground").get_index(), "but in front of the ground")
	var in_world := 0
	for child in world.get_children():
		if child.name == "Scenery":
			in_world += 1
	assert_eq(in_world, 1, "the tree is depth-sorted with the actors")
	assert_true(background.y_sort_enabled, "background pieces still sort among themselves")
