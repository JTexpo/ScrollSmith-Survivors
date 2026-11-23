class_name Boss
extends Node2D
## TEMPORARY look: a boss, run entirely from a BossData. It reuses the enemy health, hurtbox, hit flash and
## contact hitbox, ignores knockback, and is a small state machine: IDLE (chase and count down), TELEGRAPH
## (the warning of one attack), ACT (a charge's dash) and RECOVER (still for a moment, and after a charge
## open to +damage). Everything happens in _physics_process with the step's delta, so nothing runs while the
## game is paused, and nothing runs while the player is dead.

signal damaged(position: Vector2, amount: float, effect: int)
signal died(boss: Boss)
signal phase_changed(index: int)
signal summon_requested(archetype: EnemyArchetype, count: int)
## An attack's warning began.
signal attack_started(attack: BossAttack)

enum State { IDLE, TELEGRAPH, ACT, RECOVER }

## Timers count down to this, not to exactly zero, so float error never costs a step.
const EPSILON := 0.0001
const BLAST_SCENE := preload("res://scenes/enemies/blast_zone.tscn")
const PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")

var data: BossData
var boss_number: int = 1
var state: State = State.IDLE
var phase: int = 0
## True while it is open after a charge: hits deal extra damage.
var vulnerable: bool = false

var _bounds: Rect2 = Rect2(0, 0, 960, 540)
## The map's obstacles, found once at `_ready`. Null means there are none.
var _obstacle_map: ObstacleMap
var _rng: RandomNumberGenerator
var _health_scale: float = 1.0
var _damage_scale: float = 1.0
var _attack_index: int = 0
var _attack: BossAttack
var _idle_left: float = 0.0
var _telegraph_left: float = 0.0
var _act_left: float = 0.0
var _recover_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _zone: BlastZone
var _vulnerability_bonus: float = 0.0
var _dead: bool = false

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _hitbox: HitboxComponent = $ContactHitbox
@onready var _flash: HitFlashComponent = $HitFlashComponent
@onready var _body: ColorRect = $Body


func _ready() -> void:
	_obstacle_map = get_tree().get_first_node_in_group(&"obstacle_map") as ObstacleMap
	_hurtbox.hit_received.connect(_on_hit_received)
	_health.died.connect(_on_died)
	if data != null:
		_apply()


func _physics_process(delta: float) -> void:
	if _dead or data == null:
		return
	var player := target_player()
	if player == null:
		return
	match state:
		State.IDLE:
			_chase(player, delta)
			_idle_left -= delta
			if _idle_left <= EPSILON:
				_begin_attack(player)
		State.TELEGRAPH:
			_telegraph_left -= delta
			if _telegraph_left <= EPSILON:
				_start_action()
		State.ACT:
			_dash(delta)
		State.RECOVER:
			_recover_left -= delta
			if _recover_left <= EPSILON:
				_end_recover()


func _draw() -> void:
	if state == State.TELEGRAPH and _attack != null and _attack.kind == BossAttack.Kind.CHARGE:
		var end := to_local(global_position + _dash_direction * _attack.dash_speed * _attack.dash_time)
		draw_line(Vector2.ZERO, end, Color(1.0, 0.3, 0.1, 0.8), 2.0)


## `curve` scales the boss for its number (the first boss is the plain one), and null means no scaling.
func setup(boss_data: BossData, number: int, curve: DifficultyCurve, arena_bounds: Rect2, rng: RandomNumberGenerator) -> void:
	data = boss_data
	boss_number = number
	_bounds = arena_bounds
	_rng = rng
	_health_scale = curve.boss_health_scale(number) if curve != null else 1.0
	_damage_scale = curve.boss_damage_scale(number) if curve != null else 1.0
	if is_node_ready():
		_apply()


func is_dead() -> bool:
	return _dead


func target_player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _apply() -> void:
	_health.set_max_health(data.max_health * _health_scale)
	_hitbox.damage = data.contact_damage * _damage_scale
	_hitbox.hit_cooldown = 1.0
	_hitbox.knockback = 120.0
	_hurtbox.element = data.element
	_body.color = data.color
	scale = Vector2.ONE * data.body_scale
	phase = 0
	_attack_index = 0
	state = State.IDLE
	_idle_left = _interval()


func _phase_data() -> BossPhase:
	if data.phases.is_empty():
		return null
	return data.phases[clampi(phase, 0, data.phases.size() - 1)]


func _interval() -> float:
	var current := _phase_data()
	return current.attack_interval if current != null else 2.5


func _chase(player: Node2D, delta: float) -> void:
	var current := _phase_data()
	var multiplier := current.speed_multiplier if current != null else 1.0
	var to_player := player.global_position - global_position
	if to_player.length() > 1.0:
		var direction := to_player.normalized()
		# Close in with a clear line it steers at the player, otherwise it follows the field (see Enemy.direction_to_target).
		if _obstacle_map != null and not (to_player.length() <= ObstacleMap.NEAR_RANGE and _obstacle_map.line_clear(position, player.global_position)):
			var routed := _obstacle_map.direction_from(position)
			if routed != Vector2.ZERO:
				direction = routed
		_move(direction * data.speed * multiplier * delta)


## Moves by `offset`, kept out of obstacles and inside the arena. True when an obstacle changed the move.
func _move(offset: Vector2) -> bool:
	var next := position + offset
	var blocked := false
	if _obstacle_map != null:
		var resolved := _obstacle_map.resolve_move(position, next)
		blocked = resolved != next
		next = resolved
	position = next.clamp(_bounds.position, _bounds.end)
	return blocked


func _begin_attack(player: Node2D) -> void:
	var current := _phase_data()
	if current == null or current.attacks.is_empty():
		_idle_left = _interval()
		return
	_attack = current.attacks[_attack_index % current.attacks.size()]
	_attack_index += 1
	state = State.TELEGRAPH
	_telegraph_left = _attack.telegraph_time
	match _attack.kind:
		BossAttack.Kind.SLAM:
			_zone = BlastZone.place(get_parent(), BLAST_SCENE, player.global_position, _attack.radius, _attack.damage * _damage_scale, _attack.telegraph_time)
		BossAttack.Kind.CHARGE:
			var to_player := player.global_position - global_position
			_dash_direction = to_player.normalized() if to_player.length() > 0.0 else Vector2.RIGHT
		_:
			_body.color = data.color.lightened(0.3)
	queue_redraw()
	attack_started.emit(_attack)


func _start_action() -> void:
	match _attack.kind:
		BossAttack.Kind.CHARGE:
			state = State.ACT
			_act_left = _attack.dash_time
			_hitbox.damage = _attack.damage * _damage_scale
			queue_redraw()
		BossAttack.Kind.BURST:
			_fire_burst()
			_finish_attack()
		BossAttack.Kind.SUMMON:
			summon_requested.emit(_attack.summon_archetype, _attack.count)
			_finish_attack()
		_:
			# SLAM: its blast zone detonates by itself at the end of the same warning.
			_finish_attack()


func _dash(delta: float) -> void:
	var blocked := _move(_dash_direction * _attack.dash_speed * delta)
	_act_left -= delta
	# An obstacle in the way ends the dash at once. The recovery and the vulnerability window still follow.
	if blocked or _act_left <= EPSILON:
		_hitbox.damage = data.contact_damage * _damage_scale
		_finish_attack()


func _fire_burst() -> void:
	var start := _rng.randf_range(0.0, TAU) if _rng != null else 0.0
	for i in _attack.count:
		var angle := start + TAU * i / _attack.count
		EnemyProjectile.fire(
			get_parent(),
			PROJECTILE_SCENE,
			global_position,
			Vector2.from_angle(angle),
			_attack.projectile_speed,
			_attack.damage * _damage_scale,
			_attack.projectile_range,
		)


func _finish_attack() -> void:
	state = State.RECOVER
	_recover_left = _attack.recover_time
	_vulnerability_bonus = _attack.vulnerability_bonus
	vulnerable = _vulnerability_bonus > 0.0
	_body.color = data.color.lightened(0.5) if vulnerable else data.color
	queue_redraw()


func _end_recover() -> void:
	state = State.IDLE
	vulnerable = false
	_vulnerability_bonus = 0.0
	_body.color = data.color
	_idle_left = _interval()
	queue_redraw()


## The hurtbox has already applied the damage. While open after a charge a hit also deals its bonus, once,
## and `damaged` reports the total for the damage numbers.
func _on_hit_received(damage: float, _source_position: Vector2, _knockback: float, effect: int) -> void:
	_flash.flash()
	var total := damage
	if vulnerable and _vulnerability_bonus > 0.0 and not _dead:
		var extra := damage * _vulnerability_bonus
		_health.take_damage(extra)
		total += extra
	damaged.emit(global_position, total, effect)
	_check_phase()


## Moves forward to the phase the health ratio has reached. A hit that skips a phase lands in the last one
## it reached, with one `phase_changed`.
func _check_phase() -> void:
	if _dead or _health.max_health <= 0.0:
		return
	var reached := data.phase_index(_health.current_health / _health.max_health)
	if reached > phase:
		phase = reached
		_attack_index = 0
		phase_changed.emit(reached)


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	if is_instance_valid(_zone) and not _zone.is_detonated():
		_zone.cancel()
	_hurtbox.set_deferred("monitorable", false)
	_hitbox.set_deferred("monitorable", false)
	set_physics_process(false)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(queue_free)
