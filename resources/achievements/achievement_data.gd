class_name AchievementData
extends Resource
## One achievement: what the player has to do, how it looks and what (if anything) it gives. It is data only, so adding one is a new
## `.tres` and a catalog entry. `AchievementRules` decides when it is met and `AchievementTracker` unlocks it.

enum Kind { BOSS, LEVEL, GOLD_TOTAL, SURVIVE_SECONDS }

@export var id: StringName
@export var display_name: String
## The goal as a lower-case phrase: "defeat the Tempest Dragon", "reach level 10", "survive 10 minutes", "earn 1000 Gold".
@export var description: String
@export var kind: Kind = Kind.LEVEL
## The level, the Gold or the seconds to reach (unused for a boss).
@export var threshold: int = 0
## The `BossData.id` of the boss to defeat (a boss achievement only).
@export var boss_id: StringName
## The sprite name of the icon (`icon_ach_star`).
@export var icon: StringName
## An optional starting spell and the spell slot (3 to 5) it fills at run start once that slot is unlocked.
@export var reward_spell: SpellData
@export var reward_slot: int = 0

const FIRST_REWARD_SLOT := 3
const LAST_REWARD_SLOT := 5


func has_reward() -> bool:
	return reward_spell != null


## "Achievement unlocked: defeat the Tempest Dragon".
func toast_text() -> String:
	return "Achievement unlocked: %s" % description


## "Defeat the Tempest Dragon".
func goal_text() -> String:
	return description.substr(0, 1).to_upper() + description.substr(1)


## "Reward: Thunder Zone in slot 3 (level 10)", empty without a reward.
func reward_text(track: LevelTrack) -> String:
	if not has_reward():
		return ""
	return "Reward: %s in slot %d (level %d)" % [reward_spell.display_name, reward_slot, track.level_for_slot(reward_slot)]


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	var label := String(id) if id != &"" else "(no id)"
	if id == &"":
		found.append("an achievement has no id")
	if display_name.is_empty():
		found.append("%s has no name" % label)
	if description.is_empty():
		found.append("%s has no description" % label)
	if icon == &"":
		found.append("%s has no icon" % label)
	if kind == Kind.BOSS:
		if boss_id == &"":
			found.append("%s is a boss achievement with no boss id" % label)
	elif threshold <= 0:
		found.append("%s needs a threshold above 0" % label)
	if reward_spell != null:
		if reward_slot < FIRST_REWARD_SLOT or reward_slot > LAST_REWARD_SLOT:
			found.append("%s has a reward slot outside %d to %d" % [label, FIRST_REWARD_SLOT, LAST_REWARD_SLOT])
		if not SpellBuilder.can_cast(reward_spell):
			found.append("%s has a reward spell that can never cast" % label)
	elif reward_slot != 0:
		found.append("%s has a reward slot but no reward spell" % label)
	return found
