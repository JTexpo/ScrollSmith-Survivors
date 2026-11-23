class_name AreaEffect
extends Node2D
## Base of every Area scene (Line, Cone, Area, Missile, Wave). SpellLoadout instantiates the
## spell's Area scene and calls launch(), and knows nothing else about the Area.


## Scales the damage of this one cast (equipment and level bonuses, a double-damage roll). The loadout
## sets it before `launch`, so no Area and no shared SpellData needs to know about it.
var damage_scale: float = 1.0


## Call after the effect is in the tree. Subclasses override this.
func launch(_spell: SpellData, _origin: Vector2, _direction: Vector2, _target: Vector2) -> void:
	push_error("AreaEffect.launch must be overridden")


## The one place an Area turns a spell into hit damage. The hitbox carries the raw damage and
## the spell's element, and the target's hurtbox applies the elemental multiplier on impact.
func _configure_hitbox(hitbox: HitboxComponent, spell: SpellData, hit_cooldown: float) -> void:
	hitbox.damage = spell.damage * damage_scale
	hitbox.element = spell.primary_element()
	hitbox.profile = spell.attack_profile()
	hitbox.knockback = spell.knockback
	hitbox.hit_cooldown = hit_cooldown
	_announce_hits(hitbox, spell)


## Every hit this effect lands is announced with the spell's impact weight and element, for the screen effects and the hit sound. One
## connection per hitbox, however often it is configured. Nothing else changes.
func _announce_hits(hitbox: HitboxComponent, spell: SpellData) -> void:
	if hitbox.has_meta(&"impact_announced"):
		return
	hitbox.set_meta(&"impact_announced", true)
	var weight := ImpactWeight.of(spell, null, damage_scale)
	var element_id := ElementLooks.id_of(spell.primary_element())
	hitbox.hit_landed.connect(func(target: HurtboxComponent) -> void: ImpactEvents.bus.hit.emit(target.global_position, weight, element_id))

