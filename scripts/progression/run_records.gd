class_name RunRecords
extends RefCounted
## Compares a finished run with the saved bests of the map it was played on (longest survival, most enemies defeated) and records any it
## beat. A stat is flagged as a new best only when the old best was above 0 and the run beat it: the first run on a map sets its bests
## without a "New best!" and a tie or a worse run changes nothing. Another map's bests are never read or changed.


## Updates `profile`'s bests for `map_id` from the run and returns `{"seconds": bool, "enemies": bool}` (true for a beaten non-zero best).
static func update(profile: PlayerProfile, map_id: StringName, enemies: int, seconds: float) -> Dictionary:
	var whole_seconds := floori(seconds)
	var old_seconds := profile.best_seconds(map_id)
	var old_enemies := profile.best_enemies(map_id)
	var flags := {
		"seconds": old_seconds > 0 and whole_seconds > old_seconds,
		"enemies": old_enemies > 0 and enemies > old_enemies,
	}
	profile.set_best(map_id, maxi(old_seconds, whole_seconds), maxi(old_enemies, enemies))
	return flags
