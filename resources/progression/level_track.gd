class_name LevelTrack
extends Resource
## The permanent wizard track: the XP curve, the reward for each level and the buffs a starting
## spell can receive. Level 1 is where everyone starts and gives nothing, so `rewards[0]` is level 2.
## All of it is data: nothing in code branches on a level number.

const DEFAULT_PATH := "res://resources/progression/level_track.tres"

@export var rewards: Array[LevelReward] = []
## XP to reach level 2. Each later level costs `cost_step` more than the one before it.
@export var first_cost: int = 30
@export var cost_step: int = 20
## The Buff scrolls a starting spell can be given (random or chosen).
@export var buff_pool: Array[ScrollData] = []


static func default_track() -> LevelTrack:
	return load(DEFAULT_PATH) as LevelTrack


func max_level() -> int:
	return 1 + rewards.size()


## Total XP needed to reach `level`. Level 1 and below are 0, and levels past the last are the last's.
func xp_for_level(level: int) -> int:
	var total := 0
	for k in range(2, mini(level, max_level()) + 1):
		total += first_cost + cost_step * (k - 2)
	return total


## The level `xp` reaches, from 1 to `max_level()`.
func level_for_xp(xp: int) -> int:
	var level := 1
	while level < max_level() and xp >= xp_for_level(level + 1):
		level += 1
	return level


## Null for level 1 and for levels outside the track.
func reward_for_level(level: int) -> LevelReward:
	if level < 2 or level > max_level():
		return null
	return rewards[level - 2]


func xp_into_level(xp: int) -> int:
	return maxi(xp, 0) - xp_for_level(level_for_xp(xp))


## XP still needed for the next level, 0 at the last level.
func xp_to_next(xp: int) -> int:
	var level := level_for_xp(xp)
	if level >= max_level():
		return 0
	return xp_for_level(level + 1) - maxi(xp, 0)


## How far through the current level, 0 to 1. Full at the last level.
func progress(xp: int) -> float:
	var level := level_for_xp(xp)
	if level >= max_level():
		return 1.0
	var span := xp_for_level(level + 1) - xp_for_level(level)
	return float(xp_into_level(xp)) / float(span)


## 1 plus every SLOT reward up to `level`.
func slot_count(level: int) -> int:
	var count := 1
	for l in range(2, mini(level, max_level()) + 1):
		if reward_for_level(l).kind == LevelReward.Kind.SLOT:
			count += 1
	return count


## The level at which spell slot `slot` (1 to 5) unlocks: 1 for the first slot, the level of the nth SLOT reward for
## the nth extra slot, and 0 for a slot the track never unlocks.
func level_for_slot(slot: int) -> int:
	if slot < 1:
		return 0
	if slot == 1:
		return 1
	var found := 1
	for l in range(2, max_level() + 1):
		if reward_for_level(l).kind == LevelReward.Kind.SLOT:
			found += 1
			if found == slot:
				return l
	return 0


## The sum of `amount` over every reward of `kind` up to `level`.
func stat_sum(kind: LevelReward.Kind, level: int) -> float:
	var total := 0.0
	for l in range(2, mini(level, max_level()) + 1):
		var reward := reward_for_level(l)
		if reward.kind == kind:
			total += reward.amount
	return total
