extends AreaTestBase

const LINE := "res://resources/spells/areas/line_area.tres"
## Enemies are clamped to the arena (no negative coordinates), so shapes are cast from here.
const O := Vector2(300, 150)


func _enemy_from(path: String, at: Vector2) -> Enemy:
	var enemy := _enemy(at)
	enemy.setup(load(path) as EnemyData, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	return enemy


func test_one_cast_gives_each_element_its_own_multiplier() -> void:
	var land := _enemy_from("res://tests/fixtures/enemies/land_enemy.tres", O + Vector2(40, 0))
	var sea := _enemy_from("res://tests/fixtures/enemies/sea_enemy.tres", O + Vector2(90, 0))
	var fire := _enemy_from("res://tests/fixtures/enemies/fire_enemy.tres", O + Vector2(140, 0))
	var plain := _enemy_from("res://tests/fixtures/enemies/basic_enemy.tres", O + Vector2(40, 40))
	_launch(_spell(LINE), O)
	await wait_physics_frames(8)
	assert_eq(_health(land).current_health, _health(land).max_health - 15.0, "Fire vs Land is strong")
	assert_eq(_health(sea).current_health, _health(sea).max_health - 5.0, "Fire vs Sea is weak")
	assert_eq(_health(fire).current_health, _health(fire).max_health - 10.0, "Fire vs Fire is normal")
	assert_eq(_health(plain).current_health, _health(plain).max_health, "off the line")
