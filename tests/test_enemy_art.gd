extends GutTest

const BOUNDS := Rect2(0, 0, 960, 540)
const ARCHETYPES: Array[StringName] = [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const ELEMENTS: Array[StringName] = [&"none", &"fire", &"thunder", &"land", &"sea"]
## The state animation an archetype's behaviour plays, besides move and death.
const STATE_ANIMATIONS := {&"ranged": &"attack", &"exploder": &"fuse", &"support": &"pulse"}

var _root: Node2D
var _player: Player
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(400, 300)
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 9


func _data(archetype: StringName, element: StringName) -> EnemyData:
	return _composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement,
	)


func _enemy(archetype: StringName, at: Vector2 = Vector2(100, 100), element: StringName = &"none") -> Enemy:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(_data(archetype, element), BOUNDS, _rng)
	_root.add_child(enemy)
	enemy.global_position = at
	enemy.target_offset = Vector2.ZERO
	enemy.set_physics_process(false)
	return enemy


func _body(enemy: Enemy) -> BodyView:
	return enemy.get_node("Body") as BodyView


func _sprite(enemy: Enemy) -> AnimatedSprite2D:
	return _body(enemy).get_node("Sprite") as AnimatedSprite2D


func _health(enemy: Enemy) -> HealthComponent:
	return enemy.get_node("HealthComponent") as HealthComponent


func test_every_archetype_and_element_resolves_to_art_with_its_animations() -> void:
	for archetype in ARCHETYPES:
		for element in ELEMENTS:
			var enemy := _enemy(archetype, Vector2(100, 100), element)
			var body := _body(enemy)
			var label := "%s %s" % [element, archetype]
			assert_true(body.has_art(), label)
			assert_eq(body.current_animation(), &"move", label)
			assert_true(body.has_animation(&"death"), label)
			if STATE_ANIMATIONS.has(archetype):
				assert_true(body.has_animation(STATE_ANIMATIONS[archetype]), label)


func test_the_composer_records_the_element_for_the_sprite() -> void:
	assert_eq(_data(&"tank", &"thunder").element_id, &"thunder")
	assert_eq(_data(&"tank", &"none").element_id, &"none")


func test_a_hand_made_enemy_without_an_archetype_shows_the_fallback_square() -> void:
	var data := load("res://tests/fixtures/enemies/fire_enemy.tres") as EnemyData
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(data, BOUNDS, _rng)
	_root.add_child(enemy)
	enemy.set_physics_process(false)
	var body := _body(enemy)
	assert_false(body.has_art())
	assert_true((body.get_node("Fallback") as ColorRect).visible)
	assert_eq(body.fallback_color, data.color)
	assert_eq((body.get_node("Fallback") as ColorRect).color, data.color)


func test_the_element_changes_the_variant_not_the_stats() -> void:
	var thunder := _enemy(&"tank", Vector2(100, 100), &"thunder")
	var land := _enemy(&"tank", Vector2(200, 100), &"land")
	assert_eq(_health(thunder).max_health, _health(land).max_health)
	assert_eq(thunder.data.speed, land.data.speed)
	var thunder_sheet := (_sprite(thunder).sprite_frames.get_frame_texture(&"move", 0) as AtlasTexture).atlas.resource_path
	var land_sheet := (_sprite(land).sprite_frames.get_frame_texture(&"move", 0) as AtlasTexture).atlas.resource_path
	assert_ne(thunder_sheet, land_sheet)
	assert_string_contains(thunder_sheet, "thunder")
	assert_string_contains(land_sheet, "land")


func test_the_sprite_is_one_to_one_whatever_the_body_scale_or_elite_size() -> void:
	var tank := _enemy(&"tank")
	assert_eq(tank.scale, Vector2.ONE * 1.5)
	assert_almost_eq(_sprite(tank).global_transform.get_scale().x, 1.0, 0.001)
	tank.make_elite(load("res://resources/enemies/elite_modifier.tres") as EliteModifier)
	assert_almost_eq(tank.scale.x, 1.5 * 1.4, 0.001)
	assert_almost_eq(_sprite(tank).global_transform.get_scale().x, 1.0, 0.001, "an elite is outlined, not stretched")
	var swarmer := _enemy(&"swarmer")
	assert_almost_eq(_sprite(swarmer).global_transform.get_scale().y, 1.0, 0.001)


func test_the_hit_shapes_are_unchanged() -> void:
	for archetype in ARCHETYPES:
		var enemy := _enemy(archetype)
		for path in ["HurtboxComponent/CollisionShape2D", "ContactHitbox/CollisionShape2D"]:
			var shape := (enemy.get_node(path) as CollisionShape2D).shape as RectangleShape2D
			assert_eq(shape.size, Vector2(12, 12), "%s %s" % [archetype, path])


func test_an_enemy_faces_its_velocity() -> void:
	var right_of_player := _enemy(&"standard", Vector2(500, 300))
	right_of_player._physics_process(0.016)
	assert_true(_sprite(right_of_player).flip_h, "walking left")
	var left_of_player := _enemy(&"standard", Vector2(300, 300))
	left_of_player._physics_process(0.016)
	assert_false(_sprite(left_of_player).flip_h, "walking right")


func test_an_elite_shows_the_silhouette_outline_with_art_and_the_square_without() -> void:
	var elite := load("res://resources/enemies/elite_modifier.tres") as EliteModifier
	var with_art := _enemy(&"chaser")
	with_art.make_elite(elite)
	var outline := _body(with_art).get_node("Outline") as AnimatedSprite2D
	assert_true(outline.visible)
	assert_eq(outline.self_modulate, elite.outline_color)
	assert_null(with_art.get_node_or_null("EliteOutline"), "the square outline is for enemies without art")
	var data := load("res://tests/fixtures/enemies/fire_enemy.tres") as EnemyData
	var plain := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	plain.setup(data, BOUNDS, _rng)
	_root.add_child(plain)
	plain.set_physics_process(false)
	plain.make_elite(elite)
	assert_not_null(plain.get_node_or_null("EliteOutline"))


func test_a_ranged_enemy_plays_attack_when_it_fires_then_returns_to_move() -> void:
	var enemy := _enemy(&"ranged", Vector2(340, 300))
	EnemyBrain.for_data(enemy.data).step(enemy, 1.1)
	assert_eq(_body(enemy).current_animation(), &"attack")
	enemy._physics_process(0.4)
	assert_eq(_body(enemy).current_animation(), &"move")


func test_an_exploder_plays_fuse_when_it_lights_its_fuse() -> void:
	var enemy := _enemy(&"exploder", Vector2(380, 300))
	EnemyBrain.for_data(enemy.data).step(enemy, 0.01)
	assert_eq(_body(enemy).current_animation(), &"fuse")
	enemy._physics_process(5.0)
	assert_eq(_body(enemy).current_animation(), &"fuse", "a fuse has no timeout: only the blast or death ends it")


func test_a_support_plays_pulse_when_it_heals() -> void:
	var support := _enemy(&"support", Vector2(100, 100))
	var hurt := _enemy(&"tank", Vector2(130, 100))
	_health(hurt).take_damage(40.0)
	EnemyBrain.for_data(support.data).step(support, 0.25)
	assert_eq(_body(support).current_animation(), &"pulse")
	support._physics_process(0.3)
	assert_eq(_body(support).current_animation(), &"move")


func test_a_support_with_nobody_to_heal_does_not_pulse() -> void:
	var support := _enemy(&"support", Vector2(100, 100))
	EnemyBrain.for_data(support.data).step(support, 0.5)
	assert_eq(_body(support).current_animation(), &"move")


func test_a_new_state_replaces_the_old_one_and_a_timer_never_leaves_it_stuck() -> void:
	var enemy := _enemy(&"ranged")
	enemy.show_state(&"attack", 0.3)
	enemy._physics_process(0.2)
	assert_eq(_body(enemy).current_animation(), &"attack")
	enemy.show_state(&"attack", 0.5)
	enemy._physics_process(0.2)
	assert_eq(_body(enemy).current_animation(), &"attack", "the first state's timer must not end the second")
	enemy._physics_process(0.4)
	assert_eq(_body(enemy).current_animation(), &"move")
	enemy.show_state(&"nonsense", 0.3)
	assert_eq(_body(enemy).current_animation(), &"move", "an animation the set lacks is ignored")


func test_death_plays_the_death_animation_then_frees_the_enemy_exactly_once() -> void:
	var enemy := _enemy(&"standard")
	watch_signals(enemy)
	_health(enemy).take_damage(1.0e9)
	assert_signal_emit_count(enemy, "died", 1)
	assert_eq(_body(enemy).current_animation(), &"death")
	assert_true(is_instance_valid(enemy), "still there while the animation plays")
	await wait_seconds(1.0)
	assert_false(is_instance_valid(enemy))


func test_death_without_a_death_animation_still_shrinks_and_frees() -> void:
	var enemy := _enemy(&"standard")
	var move_only := SpriteSetData.new()
	move_only.sheet = ImageTexture.create_from_image(Image.create(28, 14, false, Image.FORMAT_RGBA8))
	move_only.frame_size = Vector2i(14, 14)
	var move := SpriteAnimationData.new()
	move.name = &"move"
	move.first_frame = 0
	move.last_frame = 1
	move_only.animations = [move] as Array[SpriteAnimationData]
	_body(enemy).set_set(move_only)
	assert_false(_body(enemy).has_animation(&"death"))
	_health(enemy).take_damage(1.0e9)
	await wait_seconds(0.6)
	assert_false(is_instance_valid(enemy))


func test_killing_an_enemy_twice_in_the_animation_changes_nothing() -> void:
	var enemy := _enemy(&"standard")
	watch_signals(enemy)
	_health(enemy).take_damage(1.0e9)
	_health(enemy).take_damage(1.0e9)
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(50.0, Vector2.ZERO)
	assert_signal_emit_count(enemy, "died", 1)
	assert_eq(_body(enemy).current_animation(), &"death")
