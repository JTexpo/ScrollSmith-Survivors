extends AreaTestBase
## Every spell area builds its hits through AreaEffect._configure_hitbox, which announces each hit with the spell's weight.

const O := Vector2(300, 150)
const AREAS := {
	"cone": ["res://resources/spells/areas/cone_area.tres", Vector2(30, 0), Vector2.INF],
	"line": ["res://resources/spells/areas/line_area.tres", Vector2(40, 0), Vector2.INF],
	"missile": ["res://resources/spells/areas/missile_area.tres", Vector2(40, 0), Vector2.INF],
	"wave": ["res://resources/spells/areas/wave_area.tres", Vector2(30, 0), Vector2.INF],
	"zone": ["res://resources/spells/areas/zone_area.tres", Vector2(80, 0), Vector2(380, 150)],
}

var _heard: Array = []
var _listener: Callable


func before_each() -> void:
	_heard = []
	_listener = func(at: Vector2, weight: float, element: StringName) -> void: _heard.append([at, weight, element])
	ImpactEvents.bus.hit.connect(_listener)


func after_each() -> void:
	ImpactEvents.bus.hit.disconnect(_listener)


func test_every_area_announces_a_hit_with_the_spells_weight_and_element() -> void:
	for key in AREAS:
		_heard.clear()
		var entry: Array = AREAS[key]
		var spell := _spell(entry[0], 30.0)
		spell.cast_interval = 1.2
		spell.elements = [SpellData.Element.THUNDER]
		var enemy := _enemy(O + entry[1])
		_launch(spell, O, Vector2.RIGHT, entry[2])
		await wait_physics_frames(14)
		assert_gt(_heard.size(), 0, "%s announced a hit" % key)
		if not _heard.is_empty():
			assert_eq(_heard[0][2], &"thunder", key)
			assert_almost_eq(float(_heard[0][1]), ImpactWeight.of(spell), 0.0001, key)
		if is_instance_valid(enemy):
			enemy.queue_free()


func test_a_heavier_spell_announces_a_heavier_hit() -> void:
	var light := _spell("res://resources/spells/areas/cone_area.tres", 6.0)
	light.cast_interval = 0.3
	var heavy := _spell("res://resources/spells/areas/cone_area.tres", 35.0)
	heavy.cast_interval = 1.4
	_enemy(O + Vector2(30, 0))
	_launch(light, O)
	await wait_physics_frames(10)
	var light_weight: float = _heard[0][1] if not _heard.is_empty() else -1.0
	_heard.clear()
	_enemy(O + Vector2(30, 60))
	_launch(heavy, O + Vector2(0, 60))
	await wait_physics_frames(10)
	assert_gt(_heard[0][1] if not _heard.is_empty() else -1.0, light_weight)


func test_the_damage_scale_makes_the_announced_hit_heavier() -> void:
	var spell := _spell("res://resources/spells/areas/cone_area.tres", 10.0)
	spell.cast_interval = 0.5
	_enemy(O + Vector2(30, 0))
	_launch(spell, O)
	await wait_physics_frames(10)
	var normal_weight: float = _heard[0][1]
	_heard.clear()
	_enemy(O + Vector2(30, 60))
	var strong := spell.area_data.scene.instantiate() as AreaEffect
	add_child_autofree(strong)
	strong.damage_scale = 4.0
	strong.launch(spell, O + Vector2(0, 60), Vector2.RIGHT, O + Vector2(10000, 60))
	await wait_physics_frames(10)
	assert_gt(float(_heard[0][1]), normal_weight)


func test_one_hit_effect_announces_each_enemy_it_lands_on_once() -> void:
	var spell := _spell("res://resources/spells/areas/cone_area.tres", 10.0)
	_enemy(O + Vector2(30, 0))
	_enemy(O + Vector2(30, 10))
	_launch(spell, O)
	await wait_physics_frames(10)
	assert_eq(_heard.size(), 2, "one announcement per enemy hit, never doubled by a second connection")
