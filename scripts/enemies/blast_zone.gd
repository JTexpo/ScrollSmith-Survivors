class_name BlastZone
extends Node2D
## TEMPORARY look: a ground circle that warns, then blasts. For `fuse_time` seconds it only shows a growing
## warning, and it is harmless. At the end it checks the player once: a living player inside the radius
## takes the damage. It never moves, so it cannot follow the player, and it counts time with _process
## deltas, so it freezes while the game is paused. Exploders, Ranged-style bosses and the boss slam use it.
## At most MAX_ALIVE exist: a new zone frees the oldest.

const MAX_ALIVE := 40
const FLASH_TIME := 0.15

signal detonated

var radius: float = 36.0
var damage: float = 20.0
var fuse_time: float = 1.0

var _elapsed: float = 0.0
var _flash_left: float = 0.0
var _detonated: bool = false
var _cancelled: bool = false


## Adds a zone to `parent`, frees the oldest first at the cap, and returns it.
static func place(
	parent: Node,
	scene: PackedScene,
	world_position: Vector2,
	zone_radius: float,
	zone_damage: float,
	fuse: float,
) -> BlastZone:
	var live := parent.get_tree().get_nodes_in_group(&"blast_zones").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	while live.size() >= MAX_ALIVE:
		live.pop_front().queue_free()
	var zone := scene.instantiate() as BlastZone
	zone.radius = zone_radius
	zone.damage = zone_damage
	zone.fuse_time = fuse
	parent.add_child(zone)
	zone.global_position = world_position
	return zone


func _ready() -> void:
	add_to_group(&"blast_zones")


func _process(delta: float) -> void:
	if _cancelled:
		return
	if _detonated:
		_flash_left -= delta
		if _flash_left <= 0.0:
			queue_free()
		queue_redraw()
		return
	_elapsed += delta
	if _elapsed >= fuse_time:
		_detonate()
	queue_redraw()


func _draw() -> void:
	if _detonated:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.8, 0.3, 0.7))
		return
	var progress := clampf(_elapsed / maxf(fuse_time, 0.001), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.25, 0.1, 0.12 + 0.28 * progress))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.3, 0.1, 0.9), 1.0)
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 32, Color(1.0, 0.6, 0.2, 0.9), 1.0)


## Frees the zone without a blast (its owner died during the warning).
func cancel() -> void:
	_cancelled = true
	set_process(false)
	queue_free()


func is_detonated() -> bool:
	return _detonated


func _detonate() -> void:
	_detonated = true
	_flash_left = FLASH_TIME
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(global_position) <= radius:
		player.hurtbox.receive_hit(damage, global_position)
	detonated.emit()
