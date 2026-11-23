extends GutTest

const DELTA := 1.0 / 60.0

var _root: Node2D
var _player: Node2D
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = Node2D.new()
	_root.add_child(_player)
	_player.add_to_group(&"player")
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 4


func _rect(position: Vector2, size: Vector2) -> MapObstacle:
	var obstacle := MapObstacle.new()
	obstacle.kind = MapObstacle.Kind.RECT
	obstacle.position = position
	obstacle.size = size
	return obstacle


func _map(size: Vector2, obstacles: Array[MapObstacle]) -> ObstacleMap:
	var data := MapData.new()
	data.id = &"test"
	data.size = size
	data.player_start = Vector2(8, 8)
	data.obstacles = obstacles
	var node := ObstacleMap.new()
	node.cells_per_frame = 100000
	_root.add_child(node)
	node.setup(data)
	return node


func _enemy(archetype: StringName, at: Vector2) -> Enemy:
	var data := _composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/none.tres") as EnemyElement,
	)
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(data, Rect2(0, 0, 2000, 2000), _rng)
	_root.add_child(enemy)
	enemy.position = at
	enemy.target_offset = Vector2.ZERO
	enemy.speed = 200.0
	enemy.set_physics_process(false)
	return enemy


## Steps the enemy and returns true when it ends within 20 px of the player without ever standing in a blocked cell.
func _chases(enemy: Enemy, map: ObstacleMap, steps: int) -> bool:
	for step in steps:
		enemy._physics_process(DELTA)
		if map.overlaps_wall(enemy.position):
			return false
		if enemy.position.distance_to(_player.position) <= 20.0:
			return true
	return false


func test_without_an_obstacle_map_the_direction_is_the_old_one() -> void:
	_player.position = Vector2(300, 100)
	var enemy := _enemy(&"standard", Vector2(100, 100))
	assert_eq(enemy.direction_to_target(), Vector2.RIGHT)


func test_in_open_ground_the_direction_is_close_to_the_old_one() -> void:
	_player.position = Vector2(400, 300)
	_map(Vector2(640, 480), [_rect(Vector2(600, 440), Vector2(20, 20))] as Array[MapObstacle])
	var enemy := _enemy(&"standard", Vector2(100, 120))
	var straight := (_player.position - enemy.position).normalized()
	assert_lt(absf(rad_to_deg(enemy.direction_to_target().angle_to(straight))), 15.0)


func test_an_enemy_goes_around_a_wall_to_reach_the_player() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(320, 112), Vector2(16, 224))] as Array[MapObstacle])
	_player.position = Vector2(560, 60)
	map._physics_process(0.5)
	var enemy := _enemy(&"standard", Vector2(80, 60))
	assert_true(_chases(enemy, map, 900))


func test_an_enemy_outside_a_u_shaped_dead_end_reaches_a_player_inside_it() -> void:
	var map := _map(Vector2(640, 480), [
		_rect(Vector2(320, 160), Vector2(192, 16)),
		_rect(Vector2(232, 240), Vector2(16, 192)),
		_rect(Vector2(408, 240), Vector2(16, 192)),
	] as Array[MapObstacle])
	_player.position = Vector2(320, 260)
	map._physics_process(0.5)
	var enemy := _enemy(&"standard", Vector2(320, 60))
	assert_true(_chases(enemy, map, 1500))


func test_knockback_into_a_wall_never_ends_inside_an_obstacle() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(320, 112), Vector2(16, 224))] as Array[MapObstacle])
	_player.position = Vector2(560, 60)
	map._physics_process(0.5)
	var enemy := _enemy(&"standard", Vector2(270, 100))
	(enemy.get_node("KnockbackComponent") as KnockbackComponent).apply_impulse(Vector2.RIGHT, 400.0)
	for step in 90:
		enemy._physics_process(DELTA)
		assert_false(map.overlaps_wall(enemy.position), "step %d at %s" % [step, enemy.position])


func test_a_retreating_ranged_enemy_stops_at_a_wall() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(320, 112), Vector2(16, 224))] as Array[MapObstacle])
	_player.position = Vector2(230, 100)
	map._physics_process(0.5)
	var enemy := _enemy(&"ranged", Vector2(270, 100))
	for step in 180:
		enemy._physics_process(DELTA)
		assert_false(map.overlaps_wall(enemy.position), "step %d at %s" % [step, enemy.position])
	assert_lt(enemy.position.x, 312.0, "it stopped short of the wall's face")


func test_an_enemy_standing_in_an_obstacle_is_moved_out_on_its_first_step() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(320, 112), Vector2(16, 224))] as Array[MapObstacle])
	_player.position = Vector2(560, 60)
	map._physics_process(0.5)
	var enemy := _enemy(&"standard", Vector2(320, 100))
	assert_true(map.overlaps_wall(enemy.position))
	enemy._physics_process(DELTA)
	assert_false(map.overlaps_wall(enemy.position))


func test_a_ranged_enemy_does_not_hold_or_fire_behind_a_wall() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(320, 112), Vector2(16, 224))] as Array[MapObstacle])
	_player.position = Vector2(365, 100)
	map._physics_process(0.5)
	var enemy := _enemy(&"ranged", Vector2(275, 100))
	for step in 50:
		enemy._physics_process(DELTA)
	assert_gt(enemy.position.distance_to(Vector2(275, 100)), 40.0, "it went to find a way round, not stood at its preferred distance")
	assert_eq(get_tree().get_nodes_in_group(&"enemy_projectiles").size(), 0, "no shots fired into the wall")


func test_a_ranged_enemy_with_a_clear_line_still_holds_at_its_distance() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(600, 300), Vector2(16, 16))] as Array[MapObstacle])
	_player.position = Vector2(365, 100)
	map._physics_process(0.5)
	var enemy := _enemy(&"ranged", Vector2(275, 100))
	for step in 30:
		enemy._physics_process(DELTA)
	assert_lt(enemy.position.distance_to(Vector2(275, 100)), 3.0)


## True when the enemy's body (12 px) and a player standing at `at` overlap.
func _touching(enemy: Enemy, at: Vector2) -> bool:
	return absf(enemy.position.x - at.x) < 12.0 and absf(enemy.position.y - at.y) < 12.0


func test_an_enemy_reaches_a_player_hiding_in_the_corner_of_two_walls() -> void:
	# A vertical wall (x 292 to 308, y 0 to 300) meets a horizontal one (x 0 to 300, y 292 to 308) at an inside corner.
	var map := _map(Vector2(640, 480), [_rect(Vector2(300, 150), Vector2(16, 300)), _rect(Vector2(150, 300), Vector2(300, 16))] as Array[MapObstacle])
	# The player stands as close to both walls as its 12 px body allows: 6 px from each face.
	var corner := Vector2(292.0 - 6.0, 292.0 - 6.0)
	_player.position = corner
	map._physics_process(0.5)
	var enemy := _enemy(&"standard", Vector2(100, 100))
	var touched := false
	for step in 900:
		enemy._physics_process(DELTA)
		if _touching(enemy, corner):
			touched = true
			break
	assert_true(touched, "the enemy stopped %s from the player in the corner" % snappedf(enemy.position.distance_to(corner), 0.1))


func test_an_enemy_reaches_a_player_pressed_against_the_far_side_of_a_thin_wall() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(320, 112), Vector2(16, 224))] as Array[MapObstacle])
	# The wall's east face is at x = 328. The player stands 6 px from it, and the enemy starts straight across the wall.
	var behind := Vector2(334.0, 100.0)
	_player.position = behind
	map._physics_process(0.5)
	var enemy := _enemy(&"standard", Vector2(260, 100))
	var touched := false
	for step in 1200:
		enemy._physics_process(DELTA)
		if _touching(enemy, behind):
			touched = true
			break
	assert_true(touched, "the enemy stopped %s from the player behind the wall" % snappedf(enemy.position.distance_to(behind), 0.1))


func test_an_enemy_close_to_the_player_steers_at_where_the_player_is_now() -> void:
	var map := _map(Vector2(640, 480), [_rect(Vector2(600, 440), Vector2(20, 20))] as Array[MapObstacle])
	_player.position = Vector2(100, 100)
	map._physics_process(0.5)
	# The player moves and the field has not caught up yet (it rebuilds over many frames).
	_player.position = Vector2(300, 100)
	var enemy := _enemy(&"standard", Vector2(220, 160))
	var straight := (_player.position - enemy.position).normalized()
	assert_lt(absf(rad_to_deg(enemy.direction_to_target().angle_to(straight))), 5.0, "it chases the ghost where the player was")


func test_a_player_hugging_a_corridor_wall_is_caught_while_running_back_and_forth() -> void:
	# A 64 px wide corridor: walls at y 100 and y 180 (16 px thick), x 100 to 500.
	var map := _map(Vector2(640, 320), [_rect(Vector2(300, 100), Vector2(400, 16)), _rect(Vector2(300, 180), Vector2(400, 16))] as Array[MapObstacle])
	var hug_y := 108.0 + 6.0
	_player.position = Vector2(160, hug_y)
	map._physics_process(0.5)
	var enemy := _enemy(&"standard", Vector2(300, 140))
	enemy.speed = 90.0
	var touching := 0
	var direction := 1.0
	for step in 1200:
		# The player runs the corridor at 120 px/s, hugging the north wall, and turns round at the ends.
		_player.position.x += direction * 120.0 * DELTA
		if _player.position.x > 440.0 or _player.position.x < 160.0:
			direction = -direction
		map._physics_process(DELTA)
		enemy._physics_process(DELTA)
		if _touching(enemy, _player.position):
			touching += 1
	assert_gt(touching, 150, "the enemy was in contact with the runner on only %d of 1200 frames" % touching)
