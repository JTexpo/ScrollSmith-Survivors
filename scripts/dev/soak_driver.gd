class_name SoakDriver
extends Node
## Developer tool: plays the whole game for many rounds and samples the engine's counters after each, so a leak shows as growth. Each
## round it keeps a crowd alive, casts every Area, kills enemies (which drop pickups) and walks onto the pickups, adds XP, buys and
## drinks a potion, fights a boss on the third round, and after each round kills the player and restarts with a fresh `Main`.
## Time is simulated: the difficulty clock is set from the round number and a round is a fixed number of frames, so the result does not
## depend on the frame rate. A test can ask it to leak a node every frame to prove the verdict can fail.

const CROWD := 60
const SPELL_PATHS := [
	"res://resources/spells/fire_missile.tres",
	"res://resources/spells/sea_cone.tres",
	"res://resources/spells/land_area.tres",
	"res://resources/spells/sea_line.tres",
	"res://resources/spells/sea_wave.tres",
]
const BOSS_ROUND := 2
## How many nodes the test-only leak adds each frame (enough to stand out from the normal wobble of a crowd).
const LEAK_NODES := 5
## Frames to let deaths, shots and effect sprites finish before a round is sampled (more than a second at 60 fps).
const SETTLE_FRAMES := 90

## Rounds between a death and a restart with a fresh `Main`. 1 (the default) keeps every sample the same phase: pickups pile up toward
## their caps (100 scrolls, 150 gems, 150 coins) inside one `Main`, which is load, not a leak, so a longer cycle would show a sawtooth.
var restart_every: int = 1
## Test only: add LEAK_NODES nodes every frame and never free them.
var leak_a_node_per_frame: bool = false

var _main: Main
var _rng := RandomNumberGenerator.new()
var _leaked: Array[Node] = []


## Runs `rounds` rounds of `frames_per_round` frames and returns one sample per round.
func run(rounds: int, frames_per_round: int) -> Array[Dictionary]:
	_rng.seed = 5
	var samples: Array[Dictionary] = []
	await _start_main()
	for round_number in rounds:
		await _play_round(round_number, frames_per_round)
		await _settle()
		# Sampled at the same point of every round (the end of play, crowd out), then the restart, so a restart's leak shows as growth
		# across rounds rather than as a dip.
		samples.append(SoakRun.take(round_number))
		if round_number % restart_every == restart_every - 1:
			await _restart()
	if is_instance_valid(_main):
		_main.queue_free()
	for node in _leaked:
		node.queue_free()
	_leaked.clear()
	await get_tree().process_frame
	return samples


func _start_main() -> void:
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as Main
	_main.save_path = ""
	(_main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child(_main)
	await get_tree().process_frame
	var player := _main.get_node("Player") as Player
	player.health.set_max_health(1.0e9)
	for i in SPELL_PATHS.size() - 1:
		player.loadout.unlock_next()
	for i in SPELL_PATHS.size():
		player.loadout.equip(i, load(SPELL_PATHS[i]) as SpellData)


func _restart() -> void:
	var player := _main.get_node("Player") as Player
	player.health.take_damage(1.0e12)
	await get_tree().process_frame
	_main.queue_free()
	await get_tree().process_frame
	await _start_main()


func _play_round(round_number: int, frames: int) -> void:
	var player := _main.get_node("Player") as Player
	var spawner := _main.get_node("EnemySpawner") as EnemySpawner
	spawner.elapsed_override = round_number * 60.0
	player.loadout.restore_all_mana()
	_main.profile.add_gold(500)
	player.progress.add_xp(400)
	ShopSystem.buy_potion(_main.profile, _main.run_potions, _main.potion_catalog, &"potion_health")
	var boss: Boss = null
	if round_number == BOSS_ROUND and not spawner.bosses().is_empty():
		boss = spawner.spawn_boss(spawner.bosses()[0], 1)
	for frame in frames:
		if frame % 10 == 0:
			_top_up_crowd(player, spawner)
		if frame % 6 == 0:
			player.loadout.select((frame / 6) % SPELL_PATHS.size())
			player.loadout.try_cast(player.global_position, Vector2.from_angle(_rng.randf_range(0.0, TAU)))
		if frame == frames / 3:
			_kill_some_enemies(20)
		if frame == frames / 2:
			_walk_onto_pickups(player)
			player.belt.use(&"potion_health")
		if boss != null and frame == frames - 10 and is_instance_valid(boss):
			var health := boss.find_child("HealthComponent", true, false) as HealthComponent
			if health != null:
				health.take_damage(1.0e12)
		if leak_a_node_per_frame:
			for i in LEAK_NODES:
				var leaked := Node.new()
				add_child(leaked)
				_leaked.append(leaked)
		await get_tree().process_frame


## Ends the fight so every round is sampled at rest: the crowd and the boss are killed and their death animations, shots and effects
## are given time to finish. The crowd's size swings with the difficulty clock, which is load and not a leak; what must stay flat is
## what is left over at rest.
func _settle() -> void:
	_main.get_node("EnemySpawner").set_process(false)
	_kill_some_enemies(100000)
	var spawner := _main.get_node("EnemySpawner") as EnemySpawner
	if is_instance_valid(spawner.boss):
		var boss_health := spawner.boss.find_child("HealthComponent", true, false) as HealthComponent
		if boss_health != null:
			boss_health.take_damage(1.0e12)
	for frame in SETTLE_FRAMES:
		await get_tree().process_frame
	# What was dropped is collected away (a pickup that is picked up simply frees itself), so the sample counts what is left over.
	for group in [&"scroll_pickups", &"xp_gems", &"gold_coins", &"enemy_projectiles", &"blast_zones"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	for frame in 30:
		await get_tree().process_frame
	_main.get_node("EnemySpawner").set_process(true)


func _top_up_crowd(player: Player, spawner: EnemySpawner) -> void:
	var guard := 0
	while spawner.alive < CROWD and guard < 20:
		guard += 1
		var offset := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(60.0, 220.0)
		spawner.spawn_at(player.global_position + offset, CROWD - spawner.alive)


func _kill_some_enemies(count: int) -> void:
	var killed := 0
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if killed >= count:
			break
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health != null and not health.is_dead():
			health.take_damage(1.0e9)
			killed += 1


func _walk_onto_pickups(player: Player) -> void:
	for group in [&"scroll_pickups", &"xp_gems", &"gold_coins"]:
		for pickup in get_tree().get_nodes_in_group(group):
			if pickup is Node2D:
				player.global_position = (pickup as Node2D).global_position
				break
