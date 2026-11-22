class_name DropTable
extends Resource
## What an enemy can drop when it dies: a chance that anything drops, then a weighted pick.

@export_range(0.0, 1.0) var drop_chance: float = 0.06
@export var entries: Array[DropEntry] = []


## Returns the scroll that drops, or null for no drop. Empty slots, entries without a scroll and
## weights at or below zero are never picked. `luck` raises the weight of rarer scrolls (see
## rarity_factor) and never changes whether anything drops. If luck would leave no weight at all, the
## roll falls back to luck 0. `chance_scale` multiplies the drop chance (elites and Tanks drop more),
## held between 0 and 1. At luck 0 and scale 1 the roll is exactly what it was before either existed.
func roll(rng: RandomNumberGenerator, luck: float = 0.0, chance_scale: float = 1.0) -> ScrollData:
	var chance := clampf(drop_chance * chance_scale, 0.0, 1.0)
	if chance <= 0.0:
		return null
	var used_luck := luck if _total_weight(luck) > 0.0 else 0.0
	var total := 0.0
	var last_pickable: DropEntry = null
	for entry in entries:
		var weight := _effective_weight(entry, used_luck)
		if weight > 0.0:
			total += weight
			last_pickable = entry
	if last_pickable == null:
		return null
	if chance < 1.0 and rng.randf() >= chance:
		return null
	var pick := rng.randf() * total
	for entry in entries:
		var weight := _effective_weight(entry, used_luck)
		if weight <= 0.0:
			continue
		pick -= weight
		if pick < 0.0:
			return entry.scroll
	return last_pickable.scroll


## How much luck scales a scroll's weight: Common x1, Uncommon x(1 + luck), Rare x(1 + 2 x luck),
## never below 0.
static func rarity_factor(rarity: int, luck: float) -> float:
	match rarity:
		ScrollData.Rarity.UNCOMMON:
			return maxf(1.0 + luck, 0.0)
		ScrollData.Rarity.RARE:
			return maxf(1.0 + 2.0 * luck, 0.0)
	return 1.0


func _effective_weight(entry: DropEntry, luck: float) -> float:
	if not _pickable(entry):
		return 0.0
	return entry.weight * rarity_factor(entry.scroll.rarity, luck)


func _total_weight(luck: float) -> float:
	var total := 0.0
	for entry in entries:
		total += _effective_weight(entry, luck)
	return total


func _pickable(entry: DropEntry) -> bool:
	return entry != null and entry.scroll != null and entry.weight > 0.0
