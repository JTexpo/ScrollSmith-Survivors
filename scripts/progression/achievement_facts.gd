class_name AchievementFacts
extends RefCounted
## What the player has done, as far as the achievement rules care: the level, the Gold earned over all runs, the seconds survived in
## this run and (for a boss event) the id of the boss just defeated.

var level: int = 1
var lifetime_gold: int = 0
var seconds: float = 0.0
var boss_id: StringName = &""
