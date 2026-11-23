extends GutTest

const SCENE := "res://scenes/enemies/enemy_projectile.tscn"

var _root: Node2D
var _player: Player
var _scene: PackedScene


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_scene = load(SCENE) as PackedScene
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(400, 300)


func _fire(origin: Vector2, direction: Vector2 = Vector2.RIGHT, speed: float = 200.0, damage: float = 8.0, max_range: float = 300.0) -> EnemyProjectile:
	return EnemyProjectile.fire(_root, _scene, origin, direction, speed, damage, max_range)


func _live() -> Array:
	return get_tree().get_nodes_in_group(&"enemy_projectiles").filter(func(p): return not p.is_queued_for_deletion())


func test_it_moves_straight_at_its_speed() -> void:
	var projectile := _fire(Vector2(100, 100), Vector2.DOWN, 150.0)
	projectile._physics_process(0.1)
	assert_almost_eq(projectile.global_position.x, 100.0, 0.01)
	assert_almost_eq(projectile.global_position.y, 115.0, 0.01)


func test_it_frees_itself_after_its_range() -> void:
	var projectile := _fire(Vector2(100, 100), Vector2.RIGHT, 100.0, 8.0, 50.0)
	projectile._physics_process(0.4)
	assert_false(projectile.is_queued_for_deletion())
	projectile._physics_process(0.2)
	assert_true(projectile.is_queued_for_deletion())


func test_fire_adds_it_to_the_given_parent_at_the_origin() -> void:
	var projectile := _fire(Vector2(123, 45))
	assert_eq(projectile.get_parent(), _root)
	assert_eq(projectile.global_position, Vector2(123, 45))
	assert_true(projectile.is_in_group(&"enemy_projectiles"))


func test_it_hurts_the_player_once_and_frees_itself() -> void:
	var projectile := _fire(_player.global_position + Vector2(-30, 0), Vector2.RIGHT, 180.0, 8.0, 300.0)
	await wait_physics_frames(30)
	assert_eq(_player.health.current_health, 92.0)
	assert_true(not is_instance_valid(projectile) or projectile.is_queued_for_deletion())


func test_it_hits_only_once_even_if_it_overlaps_for_several_frames() -> void:
	var projectile := _fire(_player.global_position, Vector2.RIGHT, 1.0, 8.0, 300.0)
	await wait_physics_frames(20)
	assert_eq(_player.health.current_health, 92.0)


func test_it_passes_through_enemies_and_spells() -> void:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	_root.add_child(enemy)
	enemy.global_position = Vector2(150, 100)
	var health := enemy.get_node("HealthComponent") as HealthComponent
	var before := health.current_health
	var projectile := _fire(Vector2(100, 100), Vector2.RIGHT, 300.0, 8.0, 600.0)
	await wait_physics_frames(25)
	assert_eq(health.current_health, before)
	assert_true(is_instance_valid(projectile) and not projectile.is_queued_for_deletion(), "it was not spent on the enemy")
	assert_gt(projectile.global_position.x, 150.0)


func test_a_hit_on_an_invulnerable_player_does_nothing_and_it_keeps_flying() -> void:
	_player.hurtbox.grant_invulnerability(5.0)
	var projectile := _fire(_player.global_position, Vector2.RIGHT, 1.0, 8.0, 300.0)
	await wait_physics_frames(10)
	assert_eq(_player.health.current_health, 100.0)
	assert_true(is_instance_valid(projectile) and not projectile.is_queued_for_deletion(), "a refused hit does not spend it")


func test_the_cap_frees_the_oldest() -> void:
	var first := _fire(Vector2(10, 10))
	for i in EnemyProjectile.MAX_ALIVE:
		_fire(Vector2(20 + i, 10))
	assert_true(first.is_queued_for_deletion())
	assert_eq(_live().size(), EnemyProjectile.MAX_ALIVE)


func test_it_has_no_element_and_the_given_damage() -> void:
	var projectile := _fire(Vector2(10, 10), Vector2.RIGHT, 100.0, 12.5)
	assert_eq(projectile.hitbox.element, SpellData.NO_ELEMENT)
	assert_eq(projectile.hitbox.damage, 12.5)
	assert_true(projectile.hitbox.one_shot)


func test_the_hitbox_is_on_the_enemy_hitbox_layer() -> void:
	var projectile := _fire(Vector2(10, 10))
	assert_eq(projectile.hitbox.collision_layer, PhysicsLayers.ENEMY_HITBOX)
	assert_eq(projectile.hitbox.collision_mask, 0)


func test_every_control_in_the_projectile_ignores_the_mouse() -> void:
	var projectile := _fire(Vector2(10, 10))
	for child in projectile.find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(child.name))


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"


func _fire_as(element_id: StringName) -> EnemyProjectile:
	return EnemyProjectile.fire(_root, _scene, Vector2(100, 100), Vector2.RIGHT, 200.0, 8.0, 300.0, element_id)


func _sheet_path(projectile: EnemyProjectile) -> String:
	var frames := (projectile.get_node("Orb/Sprite") as AnimatedSprite2D).sprite_frames
	return ((frames.get_frame_texture(&"fly", 0) as AtlasTexture).atlas).resource_path


func test_a_shot_takes_the_shooters_element_colours() -> void:
	var fire := _fire_as(&"fire")
	var sea := _fire_as(&"sea")
	assert_true((fire.get_node("Orb") as BodyView).has_art())
	assert_ne(_sheet_path(fire), _sheet_path(sea), "a Fire Kobold and a Sea Kobold throw different orbs")
	assert_string_contains(_sheet_path(fire), "fire")
	assert_string_contains(_sheet_path(_fire_as(&"")), "none", "no element gets the plain colours")
	assert_string_contains(_sheet_path(_fire_as(&"none")), "none")
	assert_false((fire.get_node("Body") as ColorRect).visible, "the old square steps aside")


func test_a_shot_without_art_keeps_its_square() -> void:
	SpriteLibrary.root = "res://.godot/art_tests/no_such_folder"
	var shot := _fire_as(&"fire")
	assert_false((shot.get_node("Orb") as BodyView).has_art())
	assert_true((shot.get_node("Body") as ColorRect).visible)


func test_a_shot_is_drawn_one_to_one() -> void:
	var shot := _fire_as(&"land")
	assert_almost_eq((shot.get_node("Orb/Sprite") as Node2D).global_transform.get_scale().x, 1.0, 0.001)


func test_a_shot_draws_above_the_players_effect_sprites() -> void:
	var shot := _fire_as(&"fire")
	var effect := EffectSprite.spawn(_root, &"fx_fire_burst", Vector2(100, 100), 0.0, 0.1)
	assert_gt(shot.z_index, effect.z_index, "an enemy shot is never covered by a spell effect")
	assert_eq(shot.z_index, WarningMark.ATTACK_Z)
	effect.queue_free()


func test_enemy_attack_events_fire_for_a_shot() -> void:
	var shots := []
	var on_shot := func(at: Vector2) -> void: shots.append(at)
	EnemyAttackEvents.bus.shot_fired.connect(on_shot)
	EnemyProjectile.fire(_root, _scene, Vector2(10, 20), Vector2.RIGHT, 100.0, 5.0, 100.0)
	assert_eq(shots.size(), 1)
	assert_eq(shots[0], Vector2(10, 20))
	EnemyAttackEvents.bus.shot_fired.disconnect(on_shot)
