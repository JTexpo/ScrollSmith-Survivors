extends AreaTestBase

const LINE := "res://resources/spells/areas/line_area.tres"
## Enemies are clamped to the arena (no negative coordinates), so shapes are cast from here.
const O := Vector2(300, 150)
const O_LOW := Vector2(300, 400)


func _damaged(enemy: Enemy) -> bool:
	return _health(enemy).current_health < _health(enemy).max_health


func test_line_hits_every_enemy_along_it_once() -> void:
	var spell := _spell(LINE)
	var enemies := [_enemy(O + Vector2(40, 0)), _enemy(O + Vector2(90, 0)), _enemy(O + Vector2(140, 0))]
	_launch(spell, O)
	await wait_physics_frames(8)
	for enemy in enemies:
		assert_eq(_health(enemy).current_health, _health(enemy).max_health - spell.damage)


func test_line_misses_enemies_outside_it() -> void:
	var outside := [_enemy(O + Vector2(40, 20)), _enemy(O + Vector2(200, 0)), _enemy(O + Vector2(-40, 0))]
	_launch(_spell(LINE), O)
	await wait_physics_frames(8)
	for enemy in outside:
		assert_false(_damaged(enemy))


func test_line_range_scale_shortens_it() -> void:
	var long_enemy := _enemy(O + Vector2(140, 0))
	_launch(_spell(LINE), O)
	await wait_physics_frames(8)
	assert_true(_damaged(long_enemy))
	var short_enemy := _enemy(O_LOW + Vector2(140, 0))
	_launch(_spell(LINE, 10.0, 0.0, 0.5), O_LOW)
	await wait_physics_frames(8)
	assert_false(_damaged(short_enemy))


func test_line_carries_damage_and_knockback() -> void:
	var spell := _spell(LINE, 14.0, 60.0)
	var hitbox := _launch(spell, O).get_node("Hitbox") as HitboxComponent
	assert_eq(hitbox.damage, DamageSystem.calculate(spell.damage, spell.primary_element()))
	assert_eq(hitbox.knockback, 60.0)


func test_line_frees_itself_after_its_window() -> void:
	var spell := _spell(LINE)
	var line := _launch(spell, O)
	line._physics_process(spell.area_data.duration + 0.05)
	assert_true(line.is_queued_for_deletion())


func test_line_follows_direction() -> void:
	var down := _enemy(O + Vector2(0, 90))
	var right := _enemy(O + Vector2(90, 0))
	_launch(_spell(LINE), O, Vector2.DOWN)
	await wait_physics_frames(8)
	assert_true(_damaged(down))
	assert_false(_damaged(right))

func test_the_line_rectangle_and_hitbox_are_unchanged_by_the_skin() -> void:
	var spell := _spell("res://resources/spells/areas/line_area.tres")
	var line := _launch(spell, Vector2(300, 150)) as LineArea
	var length := spell.effective_range()
	var width := spell.effective_size()
	assert_eq(((line.get_node("Hitbox/Shape") as CollisionShape2D).shape as RectangleShape2D).size, Vector2(length, width))
	assert_eq((line.get_node("Visual") as Polygon2D).polygon.size(), 4)
