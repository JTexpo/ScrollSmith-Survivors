class_name AreaTestBase
extends GutTest
## Shared helpers for the Area tests. Not run itself (no test_ prefix).

const ENEMY_SCENE := "res://scenes/enemies/base_enemy.tscn"


func _enemy(at: Vector2) -> Enemy:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Enemy
	add_child_autofree(enemy)
	enemy.global_position = at
	return enemy


func _health(enemy: Enemy) -> HealthComponent:
	return enemy.get_node("HealthComponent") as HealthComponent


func _damaged(enemy: Enemy) -> bool:
	return _health(enemy).current_health < _health(enemy).max_health


func _spell(area_path: String, damage := 10.0, knockback := 0.0, range_scale := 1.0, size_scale := 1.0) -> SpellData:
	var spell := SpellData.new()
	spell.elements = [SpellData.Element.FIRE]
	spell.damage = damage
	spell.knockback = knockback
	spell.projectile_speed = 140.0
	spell.range_scale = range_scale
	spell.size_scale = size_scale
	spell.area_data = load(area_path) as AreaData
	return spell


## A non-finite target means "far along direction", as SpellLoadout.try_cast does.
func _launch(spell: SpellData, origin := Vector2.ZERO, direction := Vector2.RIGHT, target := Vector2.INF) -> AreaEffect:
	var effect := spell.area_data.scene.instantiate() as AreaEffect
	add_child_autofree(effect)
	if not target.is_finite():
		target = origin + direction * 10000.0
	effect.launch(spell, origin, direction, target)
	return effect
