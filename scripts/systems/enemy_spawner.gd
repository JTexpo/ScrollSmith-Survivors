class_name EnemySpawner
extends Node
## Spawns enemies on a ring just outside the player's view, inside the arena.

signal enemy_damaged(position: Vector2, amount: float, effect: int)
signal enemy_died(enemy: Enemy)
signal boss_spawned(boss: Boss, number: int)
signal boss_died(boss: Boss, number: int)

const MAX_SPAWNS_PER_TICK := 4
## At a map corner only about a quarter of the directions lead outside the view, so this must be generous.
const SPAWN_ANGLE_ATTEMPTS := 64
## How far a cluster member can start from the first one.
const CLUSTER_RADIUS := 24.0
## How far from a boss its summoned minions appear.
const SUMMON_RADIUS := 40.0

@export var config: SpawnConfig
@export var arena_bounds: Rect2 = Rect2(0, 0, 960, 540)
@export var view_size: Vector2 = Vector2(480, 270)

var rng := RandomNumberGenerator.new()
var alive: int = 0
## The living boss, or null. A boss does not count toward `alive`.
var boss: Boss
## Builds (and caches) the EnemyData of each archetype and element pair.
var composer := EnemyComposer.new()
## When 0 or more it replaces the run clock (tests and the stress scene use it).
var elapsed_override: float = -1.0
## Divides the spawn interval, so 0.5 doubles it. A living boss sets it to 0.5.
var spawn_rate_scale: float = 1.0
## Where enemies are added. Defaults to this node's parent.
var spawn_root: Node

var _time_since_spawn: float = 0.0


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if config == null:
		return
	var interval := current_interval()
	_time_since_spawn += delta
	var budget := MAX_SPAWNS_PER_TICK
	while _time_since_spawn >= interval and budget > 0:
		_time_since_spawn -= interval
		budget -= 1
		if try_spawn() == null:
			_time_since_spawn = 0.0
			return


## Run seconds for difficulty and unlocks: the override when set, otherwise the pausable run clock.
func elapsed_seconds() -> float:
	return elapsed_override if elapsed_override >= 0.0 else RunClock.seconds()


## Seconds between spawn attempts now: the curve's interval (else the config's), divided by the rate scale.
func current_interval() -> float:
	if config == null:
		return 0.5
	var base := config.difficulty.spawn_interval(elapsed_seconds()) if config.difficulty != null else config.interval
	return maxf(base / maxf(spawn_rate_scale, 0.01), 0.01)


func current_max_alive() -> int:
	if config.difficulty != null:
		return config.difficulty.max_alive(elapsed_seconds())
	return config.max_alive


## A role that has unlocked by `seconds`, picked by weight. Empty slots and zero weights are never picked,
## and the result is null when nothing is pickable.
func pick_archetype(seconds: float) -> EnemyArchetype:
	if config == null:
		return null
	var total := 0.0
	var last: EnemyArchetype = null
	for archetype in config.archetypes:
		if archetype != null and archetype.spawn_weight > 0.0 and archetype.unlock_seconds <= seconds:
			total += archetype.spawn_weight
			last = archetype
	if last == null:
		return null
	var roll := rng.randf() * total
	for archetype in config.archetypes:
		if archetype == null or archetype.spawn_weight <= 0.0 or archetype.unlock_seconds > seconds:
			continue
		roll -= archetype.spawn_weight
		if roll < 0.0:
			return archetype
	return last


## An element picked by weight (including "no element"), or null when there are none.
func pick_element() -> EnemyElement:
	if config == null:
		return null
	var total := 0.0
	var last: EnemyElement = null
	for element in config.elements:
		if element != null and element.spawn_weight > 0.0:
			total += element.spawn_weight
			last = element
	if last == null:
		return null
	var roll := rng.randf() * total
	for element in config.elements:
		if element == null or element.spawn_weight <= 0.0:
			continue
		roll -= element.spawn_weight
		if roll < 0.0:
			return element
	return last


## Whether a spawn at this time is an elite. Never without both a curve and a modifier, and no roll is
## drawn while the chance is zero.
func roll_elite(seconds: float) -> bool:
	if config == null or config.difficulty == null or config.elite_modifier == null:
		return false
	var chance := config.difficulty.elite_chance(seconds)
	return chance > 0.0 and rng.randf() < chance


func try_spawn() -> Enemy:
	if config == null or alive >= current_max_alive():
		return null
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return null
	var position := spawn_position(player.global_position)
	if position == Vector2.INF:
		return null
	return spawn_at(position)


## Spawns an enemy (or a cluster of them) at `position` and returns the first: it composes a role and an
## element, applies the difficulty scales for the run time and may make it an elite. Null when no
## archetype or element can be picked. `cluster_limit` above 0 caps how many members one spawn makes.
func spawn_at(position: Vector2, cluster_limit: int = 0) -> Enemy:
	var seconds := elapsed_seconds()
	var archetype := pick_archetype(seconds)
	var element := pick_element()
	if archetype == null or element == null:
		return null
	var composed := composer.compose(archetype, element)
	var first: Enemy = null
	var members := maxi(archetype.cluster_size, 1)
	if cluster_limit > 0:
		members = mini(members, cluster_limit)
	for i in members:
		if i > 0 and alive >= current_max_alive():
			break
		var at := position
		if i > 0:
			at = (position + Vector2.from_angle(rng.randf_range(0.0, TAU)) * CLUSTER_RADIUS * sqrt(rng.randf())).clamp(arena_bounds.position, arena_bounds.end)
		var enemy := _spawn_enemy(composed, at)
		if config.difficulty != null:
			enemy.apply_scales(config.difficulty.health_scale(seconds), config.difficulty.damage_scale(seconds), config.difficulty.speed_scale(seconds))
		if roll_elite(seconds):
			enemy.make_elite(config.elite_modifier)
		if first == null:
			first = enemy
	return first


## Spawns a boss just outside the view and returns it, or null without a player, a boss scene or data.
func spawn_boss(boss_data: BossData, number: int) -> Boss:
	if config == null or config.boss_scene == null or boss_data == null:
		return null
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return null
	var spot := spawn_position(player.global_position)
	if spot == Vector2.INF:
		spot = arena_bounds.get_center()
	var instance := config.boss_scene.instantiate() as Boss
	instance.setup(boss_data, number, config.difficulty, arena_bounds, rng)
	var root := spawn_root if spawn_root != null else get_parent()
	root.add_child(instance)
	instance.global_position = _unblocked(spot)
	instance.damaged.connect(enemy_damaged.emit)
	instance.summon_requested.connect(_on_boss_summon.bind(instance))
	instance.died.connect(_on_boss_died.bind(number))
	boss = instance
	boss_spawned.emit(instance, number)
	return instance


func _on_boss_summon(archetype: EnemyArchetype, count: int, source: Boss) -> void:
	var element := pick_element()
	if archetype == null or element == null:
		return
	var composed := composer.compose(archetype, element)
	var seconds := elapsed_seconds()
	for i in count:
		# Summons ignore the plain cap but never push the horde past twice it.
		if alive >= current_max_alive() * 2:
			break
		var at := (source.global_position + Vector2.from_angle(TAU * i / count) * SUMMON_RADIUS).clamp(arena_bounds.position, arena_bounds.end)
		var enemy := _spawn_enemy(composed, at)
		if config.difficulty != null:
			enemy.apply_scales(config.difficulty.health_scale(seconds), config.difficulty.damage_scale(seconds), config.difficulty.speed_scale(seconds))


func _on_boss_died(dead: Boss, number: int) -> void:
	if boss == dead:
		boss = null
	boss_died.emit(dead, number)


func _spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	var enemy := config.enemy_scene.instantiate() as Enemy
	enemy.setup(data, arena_bounds, rng)
	var root := spawn_root if spawn_root != null else get_parent()
	root.add_child(enemy)
	enemy.global_position = _unblocked(position)
	alive += 1
	enemy.died.connect(_on_enemy_died)
	enemy.damaged.connect(enemy_damaged.emit)
	return enemy


## A point just outside what the camera can see, clamped into the arena.
## The camera stops scrolling at the arena edge, so the visible area is the player-centred view
## pushed back inside the arena. Returns Vector2.INF when no valid point is found.
func spawn_position(player_position: Vector2) -> Vector2:
	var half_view := view_size / 2.0
	var lowest := arena_bounds.position + half_view
	var highest := (arena_bounds.end - half_view).max(lowest)
	var view_center := player_position.clamp(lowest, highest)
	var view_rect := Rect2(view_center - half_view, view_size)
	var ring_half := half_view + Vector2(config.spawn_margin, config.spawn_margin)
	for attempt in SPAWN_ANGLE_ATTEMPTS:
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var scale := maxf(absf(direction.x) / ring_half.x, absf(direction.y) / ring_half.y)
		var point := view_center + direction / scale
		point = point.clamp(arena_bounds.position, arena_bounds.end)
		if not _inside_inclusive(view_rect, point) and not _blocked(point):
			return point
	return Vector2.INF


## The map's obstacles, or null when the world has none.
func _obstacles() -> ObstacleMap:
	return get_tree().get_first_node_in_group(&"obstacle_map") as ObstacleMap


func _blocked(point: Vector2) -> bool:
	var obstacles := _obstacles()
	return obstacles != null and obstacles.is_blocked(point)


## `point`, or the nearest free spot when an obstacle covers it.
func _unblocked(point: Vector2) -> Vector2:
	var obstacles := _obstacles()
	return obstacles.push_out(point) if obstacles != null else point


func _inside_inclusive(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x <= rect.end.x and point.y <= rect.end.y


func _on_enemy_died(enemy: Enemy) -> void:
	alive = maxi(alive - 1, 0)
	enemy_died.emit(enemy)
