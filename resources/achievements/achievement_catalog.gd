class_name AchievementCatalog
extends Resource
## Every achievement, in the order the screen shows them.

const DEFAULT_PATH := "res://resources/achievements/achievement_catalog.tres"

@export var achievements: Array[AchievementData] = []


static func default_catalog() -> AchievementCatalog:
	return load(DEFAULT_PATH) as AchievementCatalog


func find(id: StringName) -> AchievementData:
	for data in achievements:
		if data != null and data.id == id:
			return data
	return null


func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for data in achievements:
		if data != null:
			found.append(data.id)
	return found


## Every entry's faults, plus a duplicate id, a reward slot used twice and a boss used twice.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	var seen_ids := {}
	var seen_slots := {}
	var seen_bosses := {}
	for data in achievements:
		if data == null:
			found.append("the catalog has an empty entry")
			continue
		found.append_array(data.problems())
		if seen_ids.has(data.id):
			found.append("the id %s is used twice" % data.id)
		seen_ids[data.id] = true
		if data.has_reward():
			if seen_slots.has(data.reward_slot):
				found.append("reward slot %d is used twice" % data.reward_slot)
			seen_slots[data.reward_slot] = true
		if data.kind == AchievementData.Kind.BOSS:
			if seen_bosses.has(data.boss_id):
				found.append("the boss %s has two achievements" % data.boss_id)
			seen_bosses[data.boss_id] = true
	return found
