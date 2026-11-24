extends GutTest
## Sprint 16b: the Tempest Dragon in a real run on the forest. Driven by hand-stepped physics so it is fast and exact: it must use every
## attack, never break the blast zone cap, telegraph, and die and pay out once. The forest sends the Dragon, the ruins and maze the Titan.

const K := BossAttack.Kind
const STEP := 0.05
const SCENES := {
	&"forest": "res://scenes/main/main_forest.tscn",
	&"first_map": "res://scenes/main/main.tscn",
	&"maze": "res://scenes/main/main_maze.tscn",
}


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


func test_the_director_spawns_each_maps_own_boss() -> void:
	var expected := {&"forest": &"tempest_dragon", &"first_map": &"ember_titan", &"maze": &"dire_minotaur"}
	for id in SCENES:
		var main := _new_main(SCENES[id])
		await wait_process_frames(2)
		var director := main.get_node("RunDirector") as RunDirector
		director.tick(300.0)
		var boss := director.current_boss()
		assert_not_null(boss, "%s sends a boss at 300 s" % id)
		boss.set_physics_process(false)
		assert_eq(boss.data.id, expected[id], String(id))
		main.queue_free()
		await wait_process_frames(2)


func test_the_dragon_fight_runs_every_attack_and_dies_once() -> void:
	var main := _new_main(SCENES[&"forest"])
	await wait_process_frames(2)
	var player := main.get_node("Player") as Player
	player.health.set_max_health(1.0e9)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.set_process(false)
	var boss := spawner.spawn_boss(load("res://resources/bosses/tempest_dragon.tres") as BossData, 1)
	assert_not_null(boss)
	boss.set_physics_process(false)
	var kinds := {}
	boss.attack_started.connect(func(attack: BossAttack) -> void: kinds[attack.kind] = true)
	var died := []
	boss.died.connect(func(b: Boss) -> void: died.append(b))
	var health := boss.get_node("HealthComponent") as HealthComponent
	var cap_broken := false
	for step in 6000:
		if not is_instance_valid(boss) or died.size() > 0:
			break
		boss._physics_process(STEP)
		for zone in _zones():
			(zone as BlastZone)._process(STEP)
		if _zones().size() > BlastZone.MAX_ALIVE:
			cap_broken = true
		# Walk the fight through its phases by damage: below 60% (phase 2), below 25% (phase 3), then the kill.
		if step == 400:
			_hit(boss, health.max_health * 0.45)
		elif step == 1300:
			_hit(boss, health.max_health * 0.40)
		elif step == 2200:
			_hit(boss, health.max_health)
	assert_true(kinds.has(K.LIGHTNING), "it used lightning")
	assert_true(kinds.has(K.CHARGE), "it used a charge")
	assert_true(kinds.has(K.BURST), "it used a burst")
	assert_true(kinds.has(K.SUMMON), "it used a summon")
	assert_false(cap_broken, "the blast zone cap held")
	assert_eq(died.size(), 1, "it died once")


func test_the_dragons_rewards_drop_once_where_it_died() -> void:
	var main := _new_main(SCENES[&"forest"])
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
		assert_lt((gem as Node2D).global_position.distance_to(at), 120.0, "dropped where the Dragon fell")
	var before := gems.size()
	await wait_process_frames(3)
	var after := get_tree().get_nodes_in_group(&"xp_gems").filter(func(n): return not n.is_queued_for_deletion()).size()
	assert_eq(after, before, "the rewards drop once")
