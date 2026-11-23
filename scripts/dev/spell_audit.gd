extends SceneTree
## Developer tool: prints damage per full mana pool for every Base and Area pair, every buff and the starting spells, against a
## tight group of 1 and of 8 enemies, sorted by the 8-enemy value, then the rows that sit far from the median. It changes nothing.
## Run: godot --headless -s scripts/dev/spell_audit.gd


func _init() -> void:
	var rows := SpellAudit.rows()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["per_pool_8"]) > float(b["per_pool_8"]))
	print("%-28s %10s %10s %8s %6s %6s" % ["spell", "pool x1", "pool x8", "dps x8", "casts", "cost"])
	for row in rows:
		print("%-28s %10.0f %10.0f %8.1f %6d %6.2f" % [row["id"], row["per_pool_1"], row["per_pool_8"], row["dps_8"], row["casts"], row["cost"]])
	print("FLAGGED (more than 3x or less than a third of the median at 8 enemies):")
	for row in SpellAudit.flagged(rows):
		print("  %s (%.0f)" % [row["id"], row["per_pool_8"]])
	quit()
