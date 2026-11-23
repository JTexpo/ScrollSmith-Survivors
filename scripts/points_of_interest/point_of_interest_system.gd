class_name PointOfInterestSystem
extends RefCounted
## The rules of using a point of interest, in one place with no screen. A use only happens (and starts the
## point's timer) when its effect really can happen, so a refusal changes nothing. What a point does comes
## from its kind and numbers, never from its id.

const REASON_DEAD := "You can't use that while dead."
const REASON_REFRESHING := "Not ready yet."
const REASON_FULL_HEALTH := PotionSystem.REASON_FULL_HEALTH
const REASON_FULL_MANA := PotionSystem.REASON_FULL_MANA


## Why the point can't be used now, or an empty string when it can. Checked in a fixed order: dead, still
## refreshing (never for a merchant, which is always open), full health for a Health Shrine, every spell full
## for a Mana Shrine.
static func refusal(data: PointOfInterestData, player: Player, cooldown_left: float) -> String:
	if player.health.is_dead():
		return REASON_DEAD
	if data.kind != PointOfInterestData.Kind.MERCHANT and cooldown_left > 0.0:
		return REASON_REFRESHING
	if data.kind == PointOfInterestData.Kind.HEAL and player.health.current_health >= player.health.max_health:
		return REASON_FULL_HEALTH
	if data.kind == PointOfInterestData.Kind.RESTORE_MANA and PotionSystem.all_spells_full(player):
		return REASON_FULL_MANA
	return ""


## Applies the effect. HEAL and RESTORE_MANA change the player at once, LOOT rolls Gold and scrolls and leaves
## placing them to the caller, and MERCHANT does nothing here (its screen sells). `luck` raises Uncommon and
## Rare scrolls as it does for enemy drops.
static func apply(data: PointOfInterestData, player: Player, rng: RandomNumberGenerator, luck: float = 0.0) -> PointOfInterestResult:
	var result := PointOfInterestResult.new()
	match data.kind:
		PointOfInterestData.Kind.HEAL:
			player.health.heal(data.amount * player.health.max_health)
			result.message = "Healed %d%%" % roundi(data.amount * 100.0)
		PointOfInterestData.Kind.RESTORE_MANA:
			for instance in player.loadout.slots:
				if instance != null:
					instance.restore_mana(data.amount * instance.max_mana())
			result.message = "Restored %d%% mana" % roundi(data.amount * 100.0)
		PointOfInterestData.Kind.LOOT:
			_roll_loot(data, rng, luck, result)
	return result


static func _roll_loot(data: PointOfInterestData, rng: RandomNumberGenerator, luck: float, result: PointOfInterestResult) -> void:
	var parts := PackedStringArray()
	if data.gold_max > 0:
		result.gold = rng.randi_range(data.gold_min, maxi(data.gold_max, data.gold_min))
		parts.append("+%d Gold" % result.gold)
	if data.scroll_table != null:
		for i in data.scroll_count:
			var scroll := data.scroll_table.roll(rng, luck)
			if scroll != null:
				result.scrolls.append(scroll)
				parts.append("Found: %s" % scroll.display_name)
	result.message = ", ".join(parts)
