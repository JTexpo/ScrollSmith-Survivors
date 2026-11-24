extends GutTest
## Sprint 16d: the Dire Minotaur in real runs. Driven by hand-stepped physics so it is fast and exact. The fight uses every attack and a three-dash
## stampede (on open ground, where no wall cuts the chain), the maze sends the Minotaur, and in the maze it crosses the corridors to the player.

const K := BossAttack.Kind
const STEP := 0.05
const MINOTAUR := "res://resources/bosses/dire_minotaur.tres"
const MAZE := "res://scenes/main/main_maze.tscn"
const FOREST := "res://scenes/main/main_forest.tscn"


func _new_main(path: String) -> Main:
	var main := load(path).instantiate() as Main
	main.save_path = ""
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	return main


func _zones() -> Array:
	return get_tree().get_nodes_in_group(&"blast_zones").filter(func(n): return not n.is_queued_for_deletion())


func _hit(boss: Boss, damage: float) -> void:
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(damage, Vector2.ZERO)


func test_the_director_spawns_the_minotaur_on_the_maze() -> void:
	var main := _new_main(MAZE)
	await wait_process_frames(2)
	var director := main.get_node("RunDirector") as RunDirector
	director.tick(300.0)
	var boss := director.current_boss()
	assert_not_null(boss)
	boss.set_physics_process(false)
	assert_eq(boss.data.id, &"dire_minotaur")


func test_the_minotaur_fight_uses_every_attack_and_a_stampede_and_dies_once() -> void:
	var main := _new_main(FOREST)
	await wait_process_frames(2)
	var player := main.get_node("Player") as Player
	player.health.set_max_health(1.0e9)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.set_process(false)
	var boss := spawner.spawn_boss(load(MINOTAUR) as BossData, 1)
	assert_not_null(boss)
	boss.set_physics_process(false)
	var kinds := {}
	var dashes_this_attack := 0
	var longest_chain := 0
	boss.attack_started.connect(func(attack: BossAttack) -> void:
		kinds[attack.kind] = true
		dashes_this_attack = 0)
	var died := []
	boss.died.connect(func(b: Boss) -> void: died.append(b))
	var health := boss.get_node("HealthComponent") as HealthComponent
	var cap_broken := false
	var was_acting := false
	for step in 8000:
		if not is_instance_valid(boss) or died.size() > 0:
			break
		boss._physics_process(STEP)
		for zone in _zones():
			(zone as BlastZone)._process(STEP)
		var acting := boss.state == Boss.State.ACT
		if acting and not was_acting:
			dashes_this_attack += 1
			longest_chain = maxi(longest_chain, dashes_this_attack)
		was_acting = acting
		if _zones().size() > BlastZone.MAX_ALIVE:
			cap_broken = true
		# Walk the fight through its phases by damage: below 60% (phase 2), below 25% (phase 3), then the kill.
		if step == 400:
			_hit(boss, health.max_health * 0.45)
		elif step == 1800:
			_hit(boss, health.max_health * 0.40)
		elif step == 3200:
			_hit(boss, health.max_health)
	assert_true(kinds.has(K.SLAM), "it used a slam")
	assert_true(kinds.has(K.CHARGE), "it used a charge")
	assert_true(kinds.has(K.BURST), "it used a burst")
	assert_true(kinds.has(K.SUMMON), "it used a summon")
	assert_gte(longest_chain, 3, "at least one stampede of three dashes ran")
	assert_false(cap_broken, "the blast zone cap held")
	assert_eq(died.size(), 1, "it died once")


func test_the_minotaurs_rewards_drop_once_where_it_died() -> void:
	var main := _new_main(MAZE)
	await wait_process_frames(2)
	var director := main.get_node("RunDirector") as RunDirector
	watch_signals(director)
	director.tick(300.0)
	var boss := director.current_boss()
	boss.set_physics_process(false)
	var at := boss.global_position
	_hit(boss, 1.0e9)
	await wait_process_frames(3)
	assert_signal_emit_count(director, "boss_defeated", 1)
	var gems := get_tree().get_nodes_in_group(&"xp_gems").filter(func(n): return not n.is_queued_for_deletion())
	assert_gt(gems.size(), 0, "XP dropped")
	for gem in gems:
		assert_lt((gem as Node2D).global_position.distance_to(at), 120.0, "dropped where the Minotaur fell")
	var before := gems.size()
	await wait_process_frames(3)
	var after := get_tree().get_nodes_in_group(&"xp_gems").filter(func(n): return not n.is_queued_for_deletion()).size()
	assert_eq(after, before, "the rewards drop once")


func test_the_minotaur_crosses_the_maze_to_the_player() -> void:
	var main := _new_main(MAZE)
	await wait_process_frames(2)
	var player := main.get_node("Player") as Player
	player.health.set_max_health(1.0e9)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.set_process(false)
	# A Minotaur that only walks (no attacks), starting in the farthest dead end, with the player standing in the cleared centre.
	var data := (load(MINOTAUR) as BossData).duplicate() as BossData
	var walker := BossPhase.new()
	walker.health_threshold = 1.0
	walker.attack_interval = 1.0
	data.phases = [walker] as Array[BossPhase]
	var boss := spawner.spawn_boss(data, 1)
	boss.set_physics_process(false)
	var maze := ((main.get_node("GameMap") as GameMap).map_data as MapData).mazes[0] as MapMaze
	var start := player.global_position
	var far := start
	for cell in maze.dead_end_cells():
		if cell.distance_to(start) > far.distance_to(start):
			far = cell
	boss.global_position = far
	var obstacle_map := get_tree().get_first_node_in_group(&"obstacle_map") as ObstacleMap
	var stuck_for := 0.0
	var last_spot := boss.global_position
	var reached := false
	var longest_stuck := 0.0
	for step in 6000:
		obstacle_map._physics_process(STEP)
		boss._physics_process(STEP)
		var here := boss.global_position
		if here.distance_to(last_spot) < 6.0 and here.distance_to(start) > 80.0:
			stuck_for += STEP
		else:
			stuck_for = 0.0
			last_spot = here
		longest_stuck = maxf(longest_stuck, stuck_for)
		if here.distance_to(start) <= 80.0:
			reached = true
			break
	assert_true(reached, "the Minotaur reached the player within 5 simulated minutes")
	assert_lt(longest_stuck, 20.0, "and never sat still for 20 s in a corridor")
