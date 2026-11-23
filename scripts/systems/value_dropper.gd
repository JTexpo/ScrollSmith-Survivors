class_name ValueDropper
extends Node
## Turns an enemy's death into XP gems or Gold coins on the ground (one dropper per kind). Keeps at most
## `max_gems` out: at the cap a new drop's value is added to the oldest one instead of being dropped,
## so nothing is ever lost.

@export var kind: ValueGem.Kind = ValueGem.Kind.XP
@export var gem_scene: PackedScene
@export var max_gems: int = 150
## Where from the dead enemy a drop lands. XP and Gold are fanned out to either side of where a scroll lands (Main sets
## them), so the three never sit exactly on top of each other. `place` is always exact.
@export var drop_offset: Vector2 = Vector2.ZERO

## Where pickups are added. Defaults to this node's parent.
var drop_root: Node

## Oldest first.
var _gems: Array[ValueGem] = []


## The pickup that received the value, or null if the enemy gives none of this kind.
func on_enemy_died(enemy: Enemy) -> ValueGem:
	if enemy == null or enemy.data == null or not enemy.gives_rewards:
		return null
	var reward := enemy.xp_reward() if kind == ValueGem.Kind.XP else enemy.gold_reward()
	if reward <= 0:
		return null
	return place(reward, enemy.global_position + drop_offset)


## Puts value on the ground at a world position. Returns the pickup now holding it.
func place(amount: int, world_position: Vector2) -> ValueGem:
	if amount <= 0 or gem_scene == null:
		return null
	_forget_gone_gems()
	if _gems.size() >= max_gems and not _gems.is_empty():
		_gems[0].add_value(amount)
		return _gems[0]
	var root := drop_root if drop_root != null else get_parent()
	var gem := gem_scene.instantiate() as ValueGem
	root.add_child(gem)
	gem.setup(amount)
	gem.global_position = world_position
	_gems.append(gem)
	return gem


func gem_count() -> int:
	_forget_gone_gems()
	return _gems.size()


func _forget_gone_gems() -> void:
	for i in range(_gems.size() - 1, -1, -1):
		if not is_instance_valid(_gems[i]) or _gems[i].is_queued_for_deletion():
			_gems.remove_at(i)
