class_name StatBonuses
extends RefCounted
## The stat bonuses level rewards and equipment add up to, as fractions of the base value (0.15 is
## +15%). One object, one path: the Player turns it into speed, health and spell mana, and the loadout
## into element damage, spell damage, casting speed and the two chance effects. New stats are appended,
## so the existing values never change.

enum Stat {
	SPEED,
	HEALTH,
	SPELL_MANA,
	DAMAGE_FIRE,
	DAMAGE_THUNDER,
	DAMAGE_LAND,
	DAMAGE_SEA,
	SPELL_DAMAGE,
	CAST_SPEED,
	CAST_TWICE_CHANCE,
	DOUBLE_DAMAGE_CHANCE,
	LUCK,
}

var _fractions: Dictionary = {}


## Every reward up to `level` of the matching kind, summed.
static func for_level(track: LevelTrack, level: int) -> StatBonuses:
	var bonuses := StatBonuses.new()
	bonuses.add(Stat.SPEED, track.stat_sum(LevelReward.Kind.SPEED, level))
	bonuses.add(Stat.HEALTH, track.stat_sum(LevelReward.Kind.HEALTH, level))
	bonuses.add(Stat.SPELL_MANA, track.stat_sum(LevelReward.Kind.MANA, level))
	return bonuses


## The element-damage stat for a `SpellData.Element`, or -1 for no element or an unknown value.
static func damage_stat(element: int) -> int:
	match element:
		SpellData.Element.FIRE:
			return Stat.DAMAGE_FIRE
		SpellData.Element.THUNDER:
			return Stat.DAMAGE_THUNDER
		SpellData.Element.LAND:
			return Stat.DAMAGE_LAND
		SpellData.Element.SEA:
			return Stat.DAMAGE_SEA
	return -1


## A new object holding the sum of two, with neither input changed.
static func combined(first: StatBonuses, second: StatBonuses) -> StatBonuses:
	var total := StatBonuses.new()
	total.add_all(first)
	total.add_all(second)
	return total


## Adds every fraction of `other` into this object.
func add_all(other: StatBonuses) -> void:
	for stat in other._fractions:
		add(stat, other._fractions[stat])


func add(stat: Stat, amount: float) -> void:
	_fractions[stat] = fraction(stat) + amount


## 0.0 for a stat nothing was added to.
func fraction(stat: Stat) -> float:
	return float(_fractions.get(stat, 0.0))


func multiplier(stat: Stat) -> float:
	return 1.0 + fraction(stat)
