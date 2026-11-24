class_name PotionSystem
extends RefCounted
## The rules of drinking a potion, in one place with no screen. A potion is only drunk (and consumed)
## when its effect really happens, so a refusal changes nothing. What a potion does comes from its
## kind and numbers, never from its id.

const REASON_UNKNOWN := "That potion does not exist."
const REASON_DEAD := "You can't drink while dead."
const REASON_NONE := "You have none left."
const REASON_COOLDOWN := "Still cooling down."
const REASON_SHARED := "Wait a moment."
const REASON_ACTIVE := "Its effect is already running."
const REASON_FULL_HEALTH := "Health is already full."
const REASON_FULL_MANA := "Every spell is already full."


## Why the potion can't be drunk now, or an empty string when it can. Checked in a fixed order:
## unknown, dead, none left, the type's cooldown, the shared cooldown, effect running, full health,
## full mana.
static func refusal(
	potion: PotionData,
	player: Player,
	potions: RunPotions,
	cooldown_left: float,
	shared_left: float,
) -> String:
	if potion == null:
		return REASON_UNKNOWN
	if player.health.is_dead():
		return REASON_DEAD
	if potions.potion_count(potion.id) <= 0:
		return REASON_NONE
	if cooldown_left > 0.0:
		return REASON_COOLDOWN
	if shared_left > 0.0:
		return REASON_SHARED
	if player.effects.is_active(potion.id):
		return REASON_ACTIVE
	if potion.kind == PotionData.Kind.HEAL and player.health.current_health >= player.health.max_health:
		return REASON_FULL_HEALTH
	if potion.kind == PotionData.Kind.RESTORE_MANA and all_spells_full(player):
		return REASON_FULL_MANA
	return ""


## Applies the effect. False if a timed effect could not start (it was already running).
static func apply(potion: PotionData, player: Player) -> bool:
	match potion.kind:
		PotionData.Kind.HEAL:
			player.health.heal(potion.magnitude * player.health.max_health)
			return true
		PotionData.Kind.RESTORE_MANA:
			for instance in player.loadout.slots:
				if instance != null:
					instance.restore_mana(potion.magnitude * instance.max_mana())
			return true
		PotionData.Kind.TIMED_BONUS, PotionData.Kind.INVULNERABILITY:
			return player.effects.start(potion)
	return false


## True when every filled slot is at its full pool, and for a player with no spells at all (also used by the
## Mana Shrine).
static func all_spells_full(player: Player) -> bool:
	for instance in player.loadout.slots:
		if instance != null and instance.current_mana < instance.max_mana():
			return false
	return true
