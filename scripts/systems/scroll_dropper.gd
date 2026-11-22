class_name ScrollDropper
extends Node
## Turns an enemy's death into a scroll on the ground. Enemies only carry a drop table (data), so
## this is where the roll happens. Keeps at most `max_pickups` scrolls out: a new drop removes
## the oldest one, so a drop that rolled always appears.

@export var pickup_scene: PackedScene
@export var max_pickups: int = 100
## Raises the chance of rarer scrolls (a Luck Potion). Main keeps it in step with the player's bonuses.
var luck: float = 0.0

var rng := RandomNumberGenerator.new()
## Where pickups are added. Defaults to this node's parent.
var drop_root: Node

## Oldest first.
var _pickups: Array[ScrollPickup] = []


func _ready() -> void:
	rng.randomize()


## Returns the pickup that was placed, or null if nothing dropped.
func on_enemy_died(enemy: Enemy) -> ScrollPickup:
	if enemy == null or enemy.data == null or enemy.data.drop_table == null or pickup_scene == null:
		return null
	var scroll := enemy.data.drop_table.roll(rng, luck)
	if scroll == null:
		return null
	return place(scroll, enemy.global_position)


## Puts a scroll on the ground at a world position. It counts against the cap like any drop.
func place(scroll: ScrollData, world_position: Vector2) -> ScrollPickup:
	if scroll == null or pickup_scene == null:
		return null
	_forget_gone_pickups()
	while _pickups.size() >= max_pickups and not _pickups.is_empty():
		_pickups.pop_front().queue_free()
	var root := drop_root if drop_root != null else get_parent()
	var pickup := pickup_scene.instantiate() as ScrollPickup
	root.add_child(pickup)
	pickup.setup(scroll)
	pickup.global_position = world_position
	_pickups.append(pickup)
	return pickup


func _forget_gone_pickups() -> void:
	for i in range(_pickups.size() - 1, -1, -1):
		if not is_instance_valid(_pickups[i]) or _pickups[i].is_queued_for_deletion():
			_pickups.remove_at(i)
