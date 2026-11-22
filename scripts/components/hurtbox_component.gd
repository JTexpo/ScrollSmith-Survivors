class_name HurtboxComponent
extends Area2D
## Receives hits for an entity and forwards them to its HealthComponent.
## Passive hurtboxes (monitoring = false) cost nothing per frame.

## `effect` is an ElementTable.Effect: how the attacker's element fared against this one.
signal hit_received(damage: float, source_position: Vector2, knockback: float, effect: int)

@export var health: HealthComponent
## This target's element (none by default). Enemies take theirs from EnemyData, and equipment
## can give the player one later.
@export var element: int = SpellData.NO_ELEMENT
## Player-wide window after a landed hit during which further hits are ignored.
@export var invulnerability_time: float = 0.0

var _invulnerable_left: float = 0.0
## A separate window granted from outside (an Invulnerability Potion). It runs next to the per-hit
## window: a landed hit never shortens or clears it, and it never starts or stretches the per-hit one.
var _granted_left: float = 0.0


func _ready() -> void:
	set_process(false)
	set_physics_process(monitoring)


func _process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_granted_left = maxf(_granted_left - delta, 0.0)
	if _invulnerable_left <= 0.0 and _granted_left <= 0.0:
		set_process(false)


func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		var hitbox := area as HitboxComponent
		if hitbox != null:
			hitbox.try_hit(self)


## Blocks every hit for `seconds`. Ignores zero and negative values, and a shorter grant never
## replaces a longer one that is still running.
func grant_invulnerability(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_granted_left = maxf(_granted_left, seconds)
	set_process(true)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0 or _granted_left > 0.0


func receive_hit(
	damage: float,
	source_position: Vector2,
	knockback: float = 0.0,
	attacker_element: int = SpellData.NO_ELEMENT,
	profile: AttackProfile = null,
) -> bool:
	if health == null or health.is_dead() or is_invulnerable():
		return false
	var result: HitResult
	if profile != null:
		result = DamageSystem.resolve(damage, profile.elements, element, profile.vulnerability_scale, profile.ignores_resistance)
	else:
		result = DamageSystem.resolve(damage, [attacker_element], element)
	health.take_damage(result.amount)
	hit_received.emit(result.amount, source_position, knockback, result.effect)
	if invulnerability_time > 0.0:
		_invulnerable_left = invulnerability_time
		set_process(true)
	return true
