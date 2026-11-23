extends AreaTestBase
## The Missile bursts where it ends (its first enemy hit, or the end of its range): a small area hit round that point whose size and
## damage come from the Missile's AreaData. Every other Area has no burst.

const FIRE_PATH := "res://resources/spells/fire_missile.tres"
const AREA_DIR := "res://resources/spells/areas/"

var _bursts: Array[MissileBurst] = []


func before_each() -> void:
	_bursts.clear()


func _fire() -> SpellData:
	return (load(FIRE_PATH) as SpellData).duplicate() as SpellData


## Launches a Missile and records every burst it spawns.
func _missile(spell: SpellData, at: Vector2 = Vector2.ZERO, scale: float = 1.0) -> MissileArea:
	var missile := spell.area_data.scene.instantiate() as MissileArea
	missile.damage_scale = scale
	add_child_autofree(missile)
	missile.burst_spawned.connect(func(burst: MissileBurst) -> void: _bursts.append(burst))
	missile.launch(spell, at, Vector2.RIGHT, at + Vector2(10000, 0))
	return missile


func _burst_at(spell: SpellData, at: Vector2, scale: float = 1.0) -> MissileBurst:
	var burst := (load("res://scenes/spells/areas/missile_burst.tscn") as PackedScene).instantiate() as MissileBurst
	burst.damage_scale = scale
	add_child_autofree(burst)
	burst.launch(spell, at, Vector2.RIGHT, at)
	return burst


func test_the_missile_area_data_has_the_burst_numbers() -> void:
	var data := load(AREA_DIR + "missile_area.tres") as AreaData
	assert_eq(data.burst_radius, 18.0, "small: half of the first 36 px (user play-test feedback)")
	assert_eq(data.burst_damage_share, 0.5)


func test_no_other_area_has_a_burst() -> void:
	for file in ["line_area.tres", "cone_area.tres", "zone_area.tres", "wave_area.tres"]:
		var data := load(AREA_DIR + file) as AreaData
		assert_eq(data.burst_radius, 0.0, file)
		assert_eq(data.burst_damage_share, 0.0, file)


func test_a_missile_bursts_once_where_it_hits() -> void:
	_enemy(Vector2(40, 0))
	_missile(_fire(), Vector2(0, 0))
	await wait_physics_frames(14)
	assert_eq(_bursts.size(), 1, "exactly one burst")
	assert_lte(absf(_bursts[0].global_position.x - 40.0), 12.0, "at the enemy it hit")


func test_the_burst_hits_every_enemy_in_the_radius_once() -> void:
	var spell := _fire()
	var inside := [_enemy(Vector2(200, 0)), _enemy(Vector2(210, 8)), _enemy(Vector2(192, -8))]
	var outside := _enemy(Vector2(200, 40))
	_burst_at(spell, Vector2(200, 0))
	await wait_physics_frames(8)
	for enemy in inside:
		assert_eq(_health(enemy).current_health, _health(enemy).max_health - spell.damage * 0.5, "one burst hit each")
	assert_eq(_health(outside).current_health, _health(outside).max_health, "none outside the radius")


func test_the_burst_damage_is_the_share_times_the_damage_scale() -> void:
	var spell := _fire()
	var enemy := _enemy(Vector2(200, 0))
	_burst_at(spell, Vector2(200, 0), 2.0)
	await wait_physics_frames(8)
	assert_eq(_health(enemy).current_health, _health(enemy).max_health - 10.0)


func test_a_missile_bursts_at_the_end_of_its_range() -> void:
	var spell := _fire()
	var missile := _missile(spell)
	missile._physics_process(spell.effective_range() / spell.projectile_speed + 0.05)
	await wait_physics_frames(2)
	assert_eq(_bursts.size(), 1)


func test_a_missile_with_no_burst_radius_makes_no_burst() -> void:
	var spell := _fire()
	spell.area_data = spell.area_data.duplicate() as AreaData
	spell.area_data.burst_radius = 0.0
	_enemy(Vector2(40, 0))
	_missile(spell)
	await wait_physics_frames(14)
	assert_eq(_bursts.size(), 0)


func test_a_missile_that_hits_two_enemies_in_one_frame_bursts_once() -> void:
	_enemy(Vector2(0, 0))
	_enemy(Vector2(2, 0))
	_missile(_fire(), Vector2(1, 0))
	await wait_physics_frames(10)
	assert_eq(_bursts.size(), 1)


func test_the_burst_uses_the_spells_element() -> void:
	var spell := _fire()
	var enemy := _enemy(Vector2(200, 0))
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).element = SpellData.Element.LAND
	_burst_at(spell, Vector2(200, 0))
	await wait_physics_frames(8)
	assert_eq(_health(enemy).current_health, _health(enemy).max_health - 5.0 * 1.5, "Fire is strong against Land")


func test_duplicate_area_bursts_once_per_copy() -> void:
	var spell := _fire()
	spell.copies = 3
	var loadout := SpellLoadout.new()
	add_child_autofree(loadout)
	loadout.slots[0] = SpellInstance.new(spell)
	var made: Array[MissileArea] = []
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MissileArea:
			(node as MissileArea).burst_spawned.connect(func(burst: MissileBurst) -> void: _bursts.append(burst))
			made.append(node))
	loadout.try_cast(Vector2(500, 500), Vector2.RIGHT)
	for m in made:
		m._physics_process(spell.effective_range() / spell.projectile_speed + 0.05)
	await wait_physics_frames(2)
	assert_eq(made.size(), 3)
	assert_eq(_bursts.size(), 3)


func test_the_burst_announces_its_hits() -> void:
	var spell := _fire()
	_enemy(Vector2(200, 0))
	_enemy(Vector2(210, 8))
	var heard := [0]
	var listener := func(_at: Vector2, _weight: float, _element: StringName) -> void: heard[0] += 1
	ImpactEvents.bus.hit.connect(listener)
	_burst_at(spell, Vector2(200, 0))
	await wait_physics_frames(8)
	ImpactEvents.bus.hit.disconnect(listener)
	assert_eq(heard[0], 2)
