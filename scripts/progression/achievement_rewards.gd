class_name AchievementRewards
extends RefCounted
## Puts the spells earned by achievements into their slots at run start. A reward fills only a slot that is unlocked (by level) and
## empty, so a spell the player is using is never replaced, and it gets a fresh full-mana instance with no starting buffs (those
## belong to the two level-reward spells). It is never applied mid-run, like every starting-spell reward.


static func apply(loadout: SpellLoadout, profile: PlayerProfile, catalog: AchievementCatalog) -> void:
	for data in catalog.achievements:
		if not data.has_reward() or not profile.has_achievement(data.id):
			continue
		var index := data.reward_slot - 1
		if index < 0 or index >= loadout.slots.size():
			continue
		if loadout.is_unlocked(index) and loadout.slots[index] == null:
			loadout.equip(index, data.reward_spell)
