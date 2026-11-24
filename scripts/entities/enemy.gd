class_name Enemy
extends Node2D
## A light enemy: no physics body, moved by position. Hits are detected through
## its passive hurtbox and contact hitbox.

signal died(enemy: Enemy)
## A hit landed. `amount` is the final damage and `effect` an ElementTable.Effect.
signal damaged(position: Vector2, amount: float, effect: int)

@export var data: EnemyData

var speed: float = 0.0
var target_offset: Vector2 = Vector2.ZERO
## An elite is tougher, bigger and worth more (see EliteModifier).
## The map's enemy art set (`enemy_<set>_<type>` is tried before `enemy_<type>`); set by the spawner before `setup`. Empty means none.
var art_set: StringName = &""

var is_elite: bool = false
## False for an enemy that dies by its own blast (an Exploder): no XP, Gold or drops.
var gives_rewards: bool = true

## The speed this enemy was given at setup (data speed with its random spread). Difficulty and elite
## scales are always worked out from it, so applying them twice never compounds.
var _base_speed: float = 0.0
var _health_scale: float = 1.0
var _damage_scale: float = 1.0
var _speed_scale: float = 1.0
var _elite: EliteModifier
## What it does each step (chase, keep distance, explode, support), chosen from its data's behaviour.
var _brain: EnemyBrain

var _bounds: Rect2 = Rect2(0, 0, 960, 540)
var _dead: bool = false
## Seconds left of a timed state animation (an attack, a pulse). 0 means no timer.
var _state_left: float = 0.0
## The sprite and colour variant last shown, so the sprite is only looked up when it changes.
var _look_key: String = ""
## The map's obstacles, found once at `_ready`. Null means there are none, and the enemy moves as before.
var _obstacle_map: ObstacleMap

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _hitbox: HitboxComponent = $ContactHitbox
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _flash: HitFlashComponent = $HitFlashComponent
@onready var _body: BodyView = $Body


func _ready() -> void:
	add_to_group(&"enemies")
	_obstacle_map = get_tree().get_first_node_in_group(&"obstacle_map") as ObstacleMap
	_hurtbox.hit_received.connect(_on_hit_received)
	_health.died.connect(_on_died)
	if data != null:
		if speed == 0.0:
			speed = data.speed
		_base_speed = speed
		_apply_data()


func _physics_process(delta: float) -> void:
	if _brain == null:
		_brain = EnemyBrain.for_data(data)
	var velocity := _brain.step(self, delta) + _knockback.update(delta)
	_body.set_facing(velocity.x)
	_tick_state(delta)
	var next := position + velocity * delta
	if _obstacle_map != null:
		next = _obstacle_map.resolve_move(position, next)
	position = next.clamp(_bounds.position, _bounds.end)


## `arena_bounds` is in the parent's coordinate space.
func setup(enemy_data: EnemyData, arena_bounds: Rect2, rng: RandomNumberGenerator) -> void:
	data = enemy_data
	_brain = null
	_bounds = arena_bounds
	speed = data.speed * rng.randf_range(1.0 - data.speed_variation, 1.0 + data.speed_variation)
	_base_speed = speed
	var angle := rng.randf_range(0.0, TAU)
	target_offset = Vector2.from_angle(angle) * data.offset_radius * sqrt(rng.randf())
	if is_node_ready():
		_apply_data()


## The player this enemy is after, or null when there is none (or the player is dead).
func target_player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


## True when nothing solid stands between this enemy and `target` (always true when the world has no obstacles).
func has_clear_line_to(target: Node2D) -> bool:
	return _obstacle_map == null or not _obstacle_map.blocks_segment(global_position, target.global_position)


## How much its difficulty scale and elite status multiply damage it deals other than by touching
## (projectiles, blasts).
func damage_multiplier() -> float:
	return _damage_scale * (_elite.damage_multiplier if _elite != null else 1.0)


## Restores health, never above the maximum. Does nothing once dead.
func heal(amount: float) -> void:
	_health.heal(amount)


func is_dead() -> bool:
	return _dead


## Dies in its own blast: no XP, Gold or drops, and the usual death (one `died`, then the shrink).
func explode_and_die() -> void:
	if _dead:
		return
	gives_rewards = false
	_health.take_damage(_health.max_health * 1000.0)


## The difficulty scales for this one enemy (never edits the shared data). Setting them again replaces
## them, so they never compound.
func apply_scales(health_scale: float, damage_scale: float, speed_scale: float) -> void:
	_health_scale = health_scale
	_damage_scale = damage_scale
	_speed_scale = speed_scale
	if is_node_ready():
		_apply_data()


## Makes this enemy an elite. Calling it again does not compound.
func make_elite(modifier: EliteModifier) -> void:
	_elite = modifier
	is_elite = modifier != null
	if is_node_ready():
		_apply_data()


## XP this enemy drops: its data's value times the elite reward multiplier, never below 1 for an enemy
## that rewards at all.
func xp_reward() -> int:
	return _scaled_reward(data.xp_reward) if data != null else 0


func gold_reward() -> int:
	return _scaled_reward(data.gold_reward) if data != null else 0


## Multiplies the drop table's chance (archetype value times the elite multiplier).
func drop_chance_scale() -> float:
	if data == null:
		return 1.0
	return data.drop_chance_scale * (_elite.drop_chance_multiplier if _elite != null else 1.0)


func display_name() -> String:
	if data == null:
		return ""
	return ("Elite " if is_elite else "") + data.display_name


## Heads for the player plus a random offset that spreads the horde out while it is far away.
## The offset fades out as the enemy closes in, so it always ends up touching the player.
func direction_to_target() -> Vector2:
	var target := get_tree().get_first_node_in_group(&"player") as Node2D
	if target == null:
		return Vector2.ZERO
	var spread := 1.0
	if data != null and data.offset_radius > 0.0:
		var distance := global_position.distance_to(target.global_position)
		spread = clampf((distance - data.offset_radius) / data.offset_radius, 0.0, 1.0)
	var to_target := (target.global_position + target_offset * spread) - global_position
	if to_target.length() < 1.0:
		return Vector2.ZERO
	var straight := to_target.normalized()
	if _obstacle_map == null:
		return straight
	# Close to the player with a clear line, steer at where the player is now. The field is only for routing, and it
	# is built from where the player was a moment ago, so following it close in lets a runner shake off the horde.
	if to_target.length() <= ObstacleMap.NEAR_RANGE and _obstacle_map.line_clear(position, target.global_position):
		return straight
	var field := _obstacle_map.direction_from(position)
	if field == Vector2.ZERO:
		return straight
	# Follow the field, keeping the sideways nudge the horde-spreading offset gives.
	var plain := (target.global_position - global_position).normalized()
	var routed := (field + (straight - plain)).normalized()
	return routed if routed != Vector2.ZERO else straight


func _apply_data() -> void:
	if _brain == null:
		_brain = EnemyBrain.for_data(data)
	_health.set_max_health(data.max_health * _health_scale * (_elite.health_multiplier if _elite != null else 1.0))
	_hitbox.damage = data.contact_damage * _damage_scale * (_elite.damage_multiplier if _elite != null else 1.0)
	if _base_speed > 0.0:
		speed = _base_speed * _speed_scale * (_elite.speed_multiplier if _elite != null else 1.0)
	scale = Vector2.ONE * data.body_scale * (_elite.size_multiplier if _elite != null else 1.0)
	_apply_look()
	if _elite != null:
		if _body.has_art():
			_body.set_outline(_elite.outline_color, true)
		else:
			_ensure_outline()
	_hitbox.hit_cooldown = data.contact_cooldown
	_hitbox.knockback = data.contact_knockback
	_hurtbox.element = data.element


func _scaled_reward(base: int) -> int:
	if base <= 0:
		return 0
	return maxi(roundi(base * (_elite.reward_multiplier if _elite != null else 1.0)), 1)


## Chooses what the enemy looks like: the sprite of its archetype in its element's colours, or the coloured square
## when there is no art (hand-made data). The sprite is kept 1:1 whatever the node's scale, which sizes the hit shapes.
func _apply_look() -> void:
	_body.fallback_color = data.color
	var variant: StringName = data.element_id if data.element_id != &"" else &"none"
	var sprite := look_sprite()
	var key := "%s|%s" % [sprite, variant]
	if key != _look_key:
		_look_key = key
		if data.archetype_id != &"":
			_body.set_look(sprite, variant)
	if _body.has_art():
		_body.counter_scale(scale)
		_body.play(&"move")


## The sprite this enemy is drawn with: its map's art set version (`enemy_<set>_<type>`) when the set is named and that sprite exists, else
## the plain `enemy_<type>`. A missing sprite therefore never replaces the old look.
func look_sprite() -> StringName:
	var plain := StringName("enemy_%s" % data.archetype_id)
	if art_set == &"" or data.archetype_id == &"":
		return plain
	var variant: StringName = data.element_id if data.element_id != &"" else &"none"
	var themed := StringName("enemy_%s_%s" % [art_set, data.archetype_id])
	return themed if SpriteLibrary.find(themed, variant) != null else plain


## Plays a state animation (an attack, a fuse, a pulse), and goes back to walking after `seconds` (0 keeps it until
## something else replaces it). A state the sprite does not have is ignored.
func show_state(state: StringName, seconds: float = 0.0) -> void:
	if _dead or not _body.has_animation(state):
		return
	_body.play(state)
	_state_left = seconds


func _tick_state(delta: float) -> void:
	if _state_left <= 0.0:
		return
	_state_left -= delta
	if _state_left <= 0.0:
		_state_left = 0.0
		_body.play(&"move")


## A coloured square just behind the body, so an elite without art can be told apart at a glance.
func _ensure_outline() -> void:
	var outline := get_node_or_null("EliteOutline") as ColorRect
	if outline == null:
		outline = ColorRect.new()
		outline.name = "EliteOutline"
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.offset_left = -8.0
		outline.offset_top = -8.0
		outline.offset_right = 8.0
		outline.offset_bottom = 8.0
		add_child(outline)
		move_child(outline, 0)
	outline.color = _elite.outline_color


func _on_hit_received(damage: float, source_position: Vector2, knockback: float, effect: int) -> void:
	_knockback.apply_impulse(global_position - source_position, knockback)
	_flash.flash()
	damaged.emit(global_position, damage, effect)


func _on_death_animation_done(animation: StringName) -> void:
	if animation == &"death":
		queue_free()


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_hurtbox.set_deferred("monitorable", false)
	_hitbox.set_deferred("monitorable", false)
	set_physics_process(false)
	died.emit(self)
	if _body.has_animation(&"death"):
		# The death animation ends it. The timer is a net, so a missing or empty animation cannot keep it for ever.
		_state_left = 0.0
		_body.animation_done.connect(_on_death_animation_done, CONNECT_ONE_SHOT)
		_body.play(&"death")
		var net := create_tween()
		net.tween_interval(1.0)
		net.tween_callback(queue_free)
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(queue_free)
