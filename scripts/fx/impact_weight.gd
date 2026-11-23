class_name ImpactWeight
extends RefCounted
## How heavy a spell's hits should feel, from 0 (a light pop) to 1 (a big thump). A long wait or a hard hit is heavier, so a slow
## spell no longer looks the same as a spammed one. It only reads the spell's numbers; it changes nothing.


## `damage_scale` is the cast's own damage multiplier (equipment, a double-damage roll), so a boosted hit is heavier.
static func of(spell: SpellData, config: ImpactConfig = null, damage_scale: float = 1.0) -> float:
	if spell == null:
		return 0.0
	var numbers := config if config != null else ImpactConfig.default_config()
	var wait := _norm(spell.cast_interval, numbers.wait_min, numbers.wait_max)
	var damage := _norm(spell.damage * damage_scale, numbers.damage_min, numbers.damage_max)
	return clampf(numbers.wait_share * wait + (1.0 - numbers.wait_share) * damage, 0.0, 1.0)


static func _norm(value: float, low: float, high: float) -> float:
	if high <= low:
		return 0.0
	return clampf((value - low) / (high - low), 0.0, 1.0)
