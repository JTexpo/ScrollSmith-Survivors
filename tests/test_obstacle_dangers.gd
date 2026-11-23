extends GutTest

const DELTA := 1.0 / 60.0
const BOUNDS := Rect2(0, 0, 960, 540)
const PROJECTILE := preload("res://scenes/enemies/enemy_projectile.tscn")

var _root: Node2D
var _player: Node2D
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = Node2D.new()
	_root.add_child(_player)
	_player.add_to_group(&"player")
	_rng = RandomNumberGenerator.new()
	_rng.seed = 6


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


func _shot(at: Vector2) -> EnemyProjectile:
	var shot := PROJECTILE.instantiate() as EnemyProjectile
	_root.add_child(shot)
	shot.launch(at, Vector2.RIGHT, 300.0, 5.0, 500.0)
	shot.set_physics_process(false)
	return shot


func _boss_data(attacks: Array[BossAttack], speed: float, interval: float) -> BossData:
	var phase := BossPhase.new()
	phase.health_threshold = 1.0
	phase.attacks = attacks
	phase.attack_interval = interval
	var data := BossData.new()
	data.id = &"test_boss"
	data.display_name = "Test Boss"
	data.element = -1
	data.max_health = 1000.0
	data.contact_damage = 5.0
	data.speed = speed
	data.body_scale = 1.0
	data.phases = [phase] as Array[BossPhase]
	return data


func _boss(data: BossData, at: Vector2) -> Boss:
	var boss := (load("res://scenes/enemies/boss.tscn") as PackedScene).instantiate() as Boss
	boss.setup(data, 1, null, Rect2(0, 0, 2000, 2000), _rng)
	_root.add_child(boss)
	boss.global_position = at
	boss.set_physics_process(false)
	return boss


func _spawner() -> EnemySpawner:
	var config := SpawnConfig.new()
	config.interval = 0.5
	config.max_alive = 100
	config.spawn_margin = 24.0
	config.enemy_scene = load("res://scenes/enemies/base_enemy.tscn")
	config.archetypes = [load("res://resources/enemies/archetypes/swarmer.tres") as EnemyArchetype] as Array[EnemyArchetype]
	config.elements = [load("res://resources/enemies/elements/none.tres") as EnemyElement] as Array[EnemyElement]
	var spawner := EnemySpawner.new()
	spawner.config = config
	spawner.arena_bounds = BOUNDS
	spawner.view_size = Vector2(480, 270)
	_root.add_child(spawner)
	spawner.elapsed_override = 100.0
	spawner.rng.seed = 7
	return spawner


func test_a_projectile_is_freed_when_it_crosses_an_obstacle_and_one_beside_it_flies_on() -> void:
	_map(Vector2(640, 480), [_rect(Vector2(300, 100), Vector2(16, 200))] as Array[MapObstacle])
	var blocked := _shot(Vector2(250, 100))
	var clear := _shot(Vector2(250, 400))
	for step in 30:
		blocked._physics_process(DELTA)
		clear._physics_process(DELTA)
	assert_true(blocked.is_queued_for_deletion())
	assert_false(clear.is_queued_for_deletion())


func test_a_projectile_without_an_obstacle_map_is_unchanged() -> void:
	var shot := _shot(Vector2(250, 100))
	for step in 30:
		shot._physics_process(DELTA)
	assert_false(shot.is_queued_for_deletion())


func test_the_boss_walks_around_a_wall_to_the_player() -> void:
	var map := _map(Vector2(640, 320), [_rect(Vector2(320, 112), Vector2(16, 224))] as Array[MapObstacle])
	_player.position = Vector2(560, 60)
	map._physics_process(0.5)
	var boss := _boss(_boss_data([] as Array[BossAttack], 200.0, 99.0), Vector2(80, 60))
	var arrived := false
	for step in 1500:
		boss._physics_process(DELTA)
		assert_false(map.is_blocked(boss.position), "step %d at %s" % [step, boss.position])
		if boss.position.distance_to(_player.position) <= 20.0:
			arrived = true
			break
	assert_true(arrived)


func test_a_boss_charge_stops_at_an_obstacle_and_the_vulnerability_window_opens() -> void:
	var map := _map(Vector2(640, 480), [_rect(Vector2(280, 100), Vector2(16, 200))] as Array[MapObstacle])
	_player.position = Vector2(400, 100)
	map._physics_process(0.5)
	var charge := BossAttack.new()
	charge.kind = BossAttack.Kind.CHARGE
	charge.telegraph_time = 0.1
	charge.damage = 25.0
	charge.dash_speed = 260.0
	charge.dash_time = 0.6
	charge.recover_time = 2.0
	charge.vulnerability_bonus = 0.5
	var boss := _boss(_boss_data([charge] as Array[BossAttack], 0.0, 0.1), Vector2(200, 100))
	var acting_steps := 0
	for step in 200:
		boss._physics_process(DELTA)
		assert_false(map.is_blocked(boss.position), "step %d at %s" % [step, boss.position])
		if boss.state == Boss.State.ACT:
			acting_steps += 1
		if boss.state == Boss.State.RECOVER:
			break
	assert_eq(boss.state, Boss.State.RECOVER)
	assert_lt(acting_steps, 25, "it did not dash for its whole 0.6 s")
	assert_true(boss.vulnerable)
	assert_lt(boss.position.x, 270.0)


func test_spawn_position_never_returns_a_blocked_point() -> void:
	var map := _map(Vector2(960, 540), [_rect(Vector2(480, 111), Vector2(600, 60)), _rect(Vector2(480, 429), Vector2(600, 60))] as Array[MapObstacle])
	_player.position = Vector2(480, 270)
	var spawner := _spawner()
	var found := 0
	for i in 200:
		var at := spawner.spawn_position(_player.position)
		if at == Vector2.INF:
			continue
		found += 1
		assert_false(map.is_blocked(at), "blocked at %s" % at)
	assert_gt(found, 100)


func test_cluster_members_and_summons_are_moved_out_of_obstacles() -> void:
	var map := _map(Vector2(960, 540), [_rect(Vector2(300, 300), Vector2(100, 100))] as Array[MapObstacle])
	var spawner := _spawner()
	spawner.spawn_at(Vector2(300, 300))
	var spawned := get_tree().get_nodes_in_group(&"enemies")
	assert_gt(spawned.size(), 1, "a Swarmer comes as a cluster")
	for enemy in spawned:
		(enemy as Enemy).set_physics_process(false)
		assert_false(map.is_blocked((enemy as Enemy).position), "cluster member at %s" % (enemy as Enemy).position)
	spawner.config.boss_scene = load("res://scenes/enemies/boss.tscn")
	var boss := spawner.spawn_boss(_boss_data([] as Array[BossAttack], 0.0, 99.0), 1)
	boss.set_physics_process(false)
	boss.global_position = Vector2(300, 300)
	var before := get_tree().get_nodes_in_group(&"enemies").size()
	spawner._on_boss_summon(load("res://resources/enemies/archetypes/swarmer.tres") as EnemyArchetype, 4, boss)
	var after := get_tree().get_nodes_in_group(&"enemies")
	assert_eq(after.size(), before + 4)
	for enemy in after:
		(enemy as Enemy).set_physics_process(false)
		assert_false(map.is_blocked((enemy as Enemy).position), "summon at %s" % (enemy as Enemy).position)
