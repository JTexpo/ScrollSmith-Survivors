class_name RunRecap
extends RefCounted
## Builds the rows of the death screen's run recap from the run's tally, its time and the saved bests. Pure: it changes nothing.
## A row is `{"label": String, "value": String, "best": String, "new_best": bool}`. Only the time, enemies and level rows have a best.
## A beaten best shows `new_best` instead of the best text, and only when the save worked (the card never announces a record that was
## not written). On a first run the bests were zero before, so nothing is flagged and the run's own best is simply shown.


static func rows(stats: RunStats, seconds: float, profile: PlayerProfile, flags: Dictionary, saved: bool) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	found.append(_row("Time survived", RunClockLabel.format(seconds), _best_time(profile.best_seconds), saved and bool(flags.get("seconds", false))))
	found.append(_row("Enemies defeated", str(stats.enemies), _best_number(profile.best_enemies), saved and bool(flags.get("enemies", false))))
	found.append(_row("Bosses defeated", str(stats.bosses), "", false))
	found.append(_row("Level reached", str(stats.level), _best_number(profile.best_level), saved and bool(flags.get("level", false))))
	found.append(_row("XP earned", str(stats.xp), "", false))
	found.append(_row("Gold earned", str(stats.gold), "", false))
	found.append(_row("Scrolls collected", str(stats.scrolls), "", false))
	found.append(_row("Spells crafted", str(stats.crafts), "", false))
	found.append(_row("Potions drunk", str(stats.potions), "", false))
	return found


static func _row(label: String, value: String, best: String, new_best: bool) -> Dictionary:
	return {"label": label, "value": value, "best": "" if new_best else best, "new_best": new_best}


static func _best_time(seconds: int) -> String:
	return "best %s" % RunClockLabel.format(seconds) if seconds > 0 else ""


static func _best_number(value: int) -> String:
	return "best %d" % value if value > 0 else ""
