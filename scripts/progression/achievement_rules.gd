class_name AchievementRules
extends RefCounted
## When an achievement is met. Pure: it reads an `AchievementData` and the facts and changes nothing.


static func is_met(data: AchievementData, facts: AchievementFacts) -> bool:
	match data.kind:
		AchievementData.Kind.BOSS:
			return facts.boss_id != &"" and facts.boss_id == data.boss_id
		AchievementData.Kind.LEVEL:
			return facts.level >= data.threshold
		AchievementData.Kind.GOLD_TOTAL:
			return facts.lifetime_gold >= data.threshold
		AchievementData.Kind.SURVIVE_SECONDS:
			return facts.seconds >= float(data.threshold)
	return false
