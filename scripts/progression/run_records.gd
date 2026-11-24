class_name RunRecords
extends RefCounted
## Compares a finished run with the saved bests (longest survival, most enemies defeated, highest level) and records any it beat. A stat
## is flagged as a new best only when the old best was above 0 and the run beat it: the first run sets its bests without a "New best!"
## and a tie or a worse run changes nothing.


## Updates `profile`'s bests from the run and returns `{"seconds": bool, "enemies": bool, "level": bool}` (true for a beaten non-zero best).
static func update(profile: PlayerProfile, enemies: int, level: int, seconds: float) -> Dictionary:
	var whole_seconds := floori(seconds)
	var flags := {
		"seconds": profile.best_seconds > 0 and whole_seconds > profile.best_seconds,
		"enemies": profile.best_enemies > 0 and enemies > profile.best_enemies,
		"level": profile.best_level > 0 and level > profile.best_level,
	}
	profile.best_seconds = maxi(profile.best_seconds, whole_seconds)
	profile.best_enemies = maxi(profile.best_enemies, enemies)
	profile.best_level = maxi(profile.best_level, level)
	return flags
