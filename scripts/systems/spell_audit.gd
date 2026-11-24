class_name SpellAudit
extends RefCounted
## A model of how much damage each spell does, so every Base, Area and buff can be compared by numbers. It assumes a tight group of
## enemies and counts how many one cast reaches (the constants below are the model's guesses, not game rules). It reads spells and
## changes nothing: it is a developer tool for tuning, and it never edits a balance number.

## The group's radius (px) the burst's reach is measured against.
const CLUSTER_RADIUS := 30.0
## How many enemies of a tight group each instant shape reaches at most.
const LINE_TARGETS := 3
const CONE_TARGETS := 6
const WAVE_TARGETS := 5
const BASES := ["fire", "thunder", "land", "sea"]
const AREAS := {"missile": "missile", "cone": "cone", "line": "line", "wave": "wave", "zone": "area"}
const BUFFS := ["additional_base", "damage", "double_vulnerability", "duplicate_area", "ignore_resistance", "max_mana"]
const STARTING := {
	"start_fire_missile": "res://resources/spells/fire_missile.tres",
	"start_sea_cone": "res://resources/spells/sea_cone.tres",
	"start_land_area": "res://resources/spells/land_area.tres",
	"start_sea_line": "res://resources/spells/sea_line.tres",
	"start_sea_wave": "res://resources/spells/sea_wave.tres",
}


## How many hits one cast makes on a group of `targets` enemies (not counting Duplicate Area copies).
static func hits_per_cast(spell: SpellData, targets: int) -> float:
	var n := maxi(targets, 1)
	var data := spell.area_data
	match data.type:
		AreaData.AreaType.MISSILE:
			var hits := 1.0
			if data.burst_radius > 0.0:
				var inside := clampi(roundi(n * pow(data.burst_radius / CLUSTER_RADIUS, 2.0)), 1, n)
				hits += data.burst_damage_share * inside
			return hits
		AreaData.AreaType.LINE:
			return float(mini(n, LINE_TARGETS))
		AreaData.AreaType.CONE:
			return float(mini(n, CONE_TARGETS))
		AreaData.AreaType.WAVE:
			return float(mini(n, WAVE_TARGETS))
		AreaData.AreaType.AREA:
			var ticks := 1.0 if data.tick_interval <= 0.0 else maxf(data.duration / data.tick_interval, 1.0)
			return n * ticks
	return float(n)


## Damage one cast does to a group, burst and copies included (`hits_per_cast` already counts a burst hit as its share of a hit).
static func damage_per_cast(spell: SpellData, targets: int) -> float:
	return spell.damage * hits_per_cast(spell, targets) * maxi(spell.copies, 1)


## Damage a full pool does to a group of `targets` enemies.
static func damage_per_pool(spell: SpellData, targets: int) -> float:
	return SpellBuilder.whole_casts(spell) * damage_per_cast(spell, targets)


## Damage per second while casting as fast as the cast interval allows (the pool is ignored).
static func damage_per_second(spell: SpellData, targets: int) -> float:
	return damage_per_cast(spell, targets) / maxf(spell.cast_interval, 0.001)


## One row for the table.
static func row_for(id: String, spell: SpellData) -> Dictionary:
	return {
		"id": id,
		"name": spell.display_name,
		"per_pool_1": damage_per_pool(spell, 1),
		"per_pool_8": damage_per_pool(spell, 8),
		"dps_8": damage_per_second(spell, 8),
		"casts": SpellBuilder.whole_casts(spell),
		"cost": spell.mana_cost,
	}


## Every Base and Area pair at Normal range, every buff on Fire Missile (Additional Base on Fire and Sea), and the starting spells.
## Anything that is missing (a renamed or removed scroll or spell) is skipped, not a crash. The lists are parameters so a test can
## prove that.
static func rows(bases_list: Array = BASES, areas: Dictionary = AREAS, buffs: Array = BUFFS, starting: Dictionary = STARTING) -> Array[Dictionary]:
	var normal := normal_option()
	var result: Array[Dictionary] = []
	if normal == null:
		return result
	for base in bases_list:
		var base_scroll := _scroll("base", base)
		if base_scroll == null:
			continue
		for area in areas:
			var area_scroll := _scroll("area", areas[area])
			if area_scroll == null:
				continue
			result.append(row_for("%s_%s" % [base, area], SpellBuilder.build([base_scroll], area_scroll, normal)))
	var fire := _scroll("base", "fire")
	var sea := _scroll("base", "sea")
	var missile := _scroll("area", "missile")
	if fire != null and sea != null and missile != null:
		for buff in buffs:
			var buff_scroll := _scroll("buff", buff)
			if buff_scroll == null:
				continue
			var bases: Array = [fire, sea] if buff == "additional_base" else [fire]
			result.append(row_for("fire_missile+%s" % buff, SpellBuilder.build(bases, missile, normal, [buff_scroll])))
	for id in starting:
		if ResourceLoader.exists(starting[id]):
			var spell := load(starting[id]) as SpellData
			if spell != null:
				result.append(row_for(id, spell))
	return result


## The crafting range option labelled "Normal" (not whatever happens to be second).
static func normal_option() -> RangeOption:
	for option in CraftingRules.default_rules().range_options:
		if option.label == "Normal":
			return option
	return null


static func _scroll(folder: String, name: String) -> ScrollData:
	var path := "res://resources/scrolls/%s/%s.tres" % [folder, name]
	return load(path) as ScrollData if ResourceLoader.exists(path) else null


## Rows whose 8-target damage per pool is more than `factor` times the median, or less than the median divided by `factor`.
static func flagged(all_rows: Array[Dictionary], factor: float = 3.0) -> Array[Dictionary]:
	var values: Array[float] = []
	for row in all_rows:
		values.append(float(row["per_pool_8"]))
	values.sort()
	var median := values[values.size() / 2] if not values.is_empty() else 0.0
	var found: Array[Dictionary] = []
	for row in all_rows:
		var value := float(row["per_pool_8"])
		if value > median * factor or value < median / factor:
			found.append(row)
	return found
