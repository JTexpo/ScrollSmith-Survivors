extends AreaTestBase

const CONE := "res://resources/spells/areas/cone_area.tres"
## Enemies are clamped to the arena (no negative coordinates), so shapes are cast from here.
const O := Vector2(300, 150)
const O_LOW := Vector2(300, 400)


func _damaged(enemy: Enemy) -> bool:
	return _health(enemy).current_health < _health(enemy).max_health


func test_cone_hits_enemies_inside_it_once() -> void:
	var spell := _spell(CONE)
	var enemies := [_enemy(O + Vector2(30, 0)), _enemy(O + Vector2(30, 15))]
	_launch(spell, O)
	await wait_physics_frames(8)
	for enemy in enemies:
		assert_eq(_health(enemy).current_health, _health(enemy).max_health - spell.damage)


func test_cone_misses_outside_angle_range_and_behind() -> void:
	var outside := [_enemy(O + Vector2(20, 40)), _enemy(O + Vector2(90, 0)), _enemy(O + Vector2(-30, 0))]
	_launch(_spell(CONE), O)
	await wait_physics_frames(8)
	for enemy in outside:
		assert_false(_damaged(enemy))


func test_cone_wider_than_180_still_hits_inside_and_misses_outside() -> void:
	var inside := _enemy(O + Vector2(-10, 40))
	var outside := _enemy(O + Vector2(-35, 20))
	_launch(_spell(CONE, 10.0, 0.0, 1.0, 240.0 / 70.0), O)
	await wait_physics_frames(8)
	assert_true(_damaged(inside))
	assert_false(_damaged(outside))


func test_cone_range_scale_shortens_it() -> void:
	var near := _enemy(O + Vector2(50, 0))
	_launch(_spell(CONE), O)
	await wait_physics_frames(8)
	assert_true(_damaged(near))
	var far := _enemy(O_LOW + Vector2(50, 0))
	_launch(_spell(CONE, 10.0, 0.0, 0.5), O_LOW)
	await wait_physics_frames(8)
	assert_false(_damaged(far))


func test_cone_carries_damage_and_knockback() -> void:
	var spell := _spell(CONE, 8.0, 80.0)
	var hitbox := _launch(spell, O).get_node("Hitbox") as HitboxComponent
	assert_eq(hitbox.damage, DamageSystem.calculate(spell.damage, spell.primary_element()))
	assert_eq(hitbox.knockback, 80.0)


func test_cone_frees_itself_after_its_window() -> void:
	var spell := _spell(CONE)
	var cone := _launch(spell, O)
	cone._physics_process(spell.area_data.duration + 0.05)
	assert_true(cone.is_queued_for_deletion())


func test_cone_follows_direction() -> void:
	var down := _enemy(O + Vector2(0, 30))
	var right := _enemy(O + Vector2(30, 0))
	_launch(_spell(CONE), O, Vector2.DOWN)
	await wait_physics_frames(8)
	assert_true(_damaged(down))
	assert_false(_damaged(right))

func test_the_cone_polygon_and_hitbox_are_unchanged_by_the_skin() -> void:
	var spell := _spell(CONE)
	var cone := _launch(spell, O) as ConeArea
	var expected := ConeArea._sector(spell.effective_range(), spell.effective_size())
	assert_eq((cone.get_node("Hitbox/Shape") as CollisionPolygon2D).polygon, expected, "what hits is the exact sector")
	assert_eq((cone.get_node("Visual") as Polygon2D).polygon, expected, "and what is tinted is the same sector")
