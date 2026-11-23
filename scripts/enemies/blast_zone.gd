class_name BlastZone
extends Node2D
## A ground circle that warns, then blasts. For `fuse_time` seconds it only shows a growing
## warning, and it is harmless. At the end it checks the player once: a living player inside the radius
## takes the damage. It never moves, so it cannot follow the player, and it counts time with _process
## deltas, so it freezes while the game is paused. Exploders, Ranged-style bosses and the boss slam use it.
## At most MAX_ALIVE exist: a new zone frees one that already blasted, else the oldest.

const MAX_ALIVE := 40
const FLASH_TIME := 0.15
## The warning is a ring of marks about every MARK_SPACING px (at least MIN_MARKS) on the circle, and a bright ring of the same
## marks that grows out from the middle as the fuse burns. At detonation a burst sprite plays (more of them for a big zone).
const MARK_SPACING := 10.0
const MIN_MARKS := 8
const BURST_SIZE := 32.0

signal detonated

var radius: float = 36.0
var damage: float = 20.0
var fuse_time: float = 1.0

var _elapsed: float = 0.0
var _flash_left: float = 0.0
var _detonated: bool = false
var _cancelled: bool = false
var _outer: Array[Sprite2D] = []
var _inner: Array[Sprite2D] = []
var _marks_built: bool = false


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
		var victim := _eviction_victim(live)
		live.erase(victim)
		victim.queue_free()
	var zone := scene.instantiate() as BlastZone
	zone.radius = zone_radius
	zone.damage = zone_damage
	zone.fuse_time = fuse
	parent.add_child(zone)
	zone.global_position = world_position
	zone._build_marks()
	return zone


## Which zone to free at the cap: one that has already blasted (it is only a flash now), else the oldest.
static func _eviction_victim(zones: Array) -> BlastZone:
	for zone in zones:
		if (zone as BlastZone).is_detonated():
			return zone
	return zones[0]


func _ready() -> void:
	z_index = WarningMark.ATTACK_Z
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
	else:
		_update_inner_ring()
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / maxf(fuse_time, 0.001), 0.0, 1.0)
	if not draws_circles():
		# With art the marks and the burst carry the look, and only the faint tint of the exact area stays.
		if not _detonated:
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.25, 0.1, 0.1 + 0.2 * progress))
		return
	if _detonated:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.8, 0.3, 0.7))
		return
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.25, 0.1, 0.12 + 0.28 * progress))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.3, 0.1, 0.9), 1.0)
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 32, Color(1.0, 0.6, 0.2, 0.9), 1.0)


## Frees the zone without a blast (its owner died during the warning).
func cancel() -> void:
	_cancelled = true
	set_process(false)
	queue_free()


## The marks of the outer ring (on the circle) and of the inner ring (growing with the fuse). Both are empty without art.
func outer_marks() -> Array[Sprite2D]:
	return _outer


func inner_marks() -> Array[Sprite2D]:
	return _inner


## True when the old drawn warning is used because there is no mark art.
func draws_circles() -> bool:
	return _outer.is_empty()


func _build_marks() -> void:
	if _marks_built or not is_inside_tree():
		return
	_marks_built = true
	var count := maxi(MIN_MARKS, roundi(TAU * radius / MARK_SPACING))
	for i in count:
		var direction := Vector2.from_angle(TAU * i / count)
		var outer := WarningMark.make(self, global_position + direction * radius, false)
		if outer == null:
			return
		_outer.append(outer)
		var inner := WarningMark.make(self, global_position, true)
		inner.visible = false
		_inner.append(inner)


## The bright ring grows from the middle to the edge as the fuse burns down, flashing as it goes.
func _update_inner_ring() -> void:
	if _inner.is_empty():
		return
	var progress := clampf(_elapsed / maxf(fuse_time, 0.001), 0.0, 1.0)
	var flash := int(_elapsed * 6.0) % 2 == 1
	for i in _inner.size():
		var direction := Vector2.from_angle(TAU * i / _inner.size())
		_inner[i].global_position = (global_position + direction * radius * progress).round()
		_inner[i].visible = progress > 0.1
		WarningMark.set_bright(_inner[i], flash)


func _hide_marks() -> void:
	for mark in _outer + _inner:
		mark.visible = false


## A burst at the middle, and for a big zone a ring of them, so the whole circle is covered.
func _spawn_bursts() -> void:
	if _outer.is_empty():
		return
	var parent := get_parent()
	var spots: Array[Vector2] = [global_position]
	if radius > BURST_SIZE * 0.75:
		var count := clampi(roundi(radius / 12.0), 3, 7)
		for i in count:
			spots.append(global_position + Vector2.from_angle(TAU * i / count) * radius * 0.55)
	for spot in spots:
		var burst := EffectSprite.spawn(parent, &"fx_blast_burst", spot + Vector2(0.0, BURST_SIZE / 2.0 - 2.0), 0.0, 0.1)
		if burst != null:
			burst.z_as_relative = false
			burst.z_index = WarningMark.ATTACK_Z


func is_detonated() -> bool:
	return _detonated


func _detonate() -> void:
	_detonated = true
	_flash_left = FLASH_TIME
	_hide_marks()
	_spawn_bursts()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(global_position) <= radius:
		player.hurtbox.receive_hit(damage, global_position)
	detonated.emit()
