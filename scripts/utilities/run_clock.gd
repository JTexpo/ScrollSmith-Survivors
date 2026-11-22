class_name RunClock
extends RefCounted
## Seconds since the run began. It reads GameTime, which stands still while the game is paused (and
## which Main resets when a run starts), so difficulty, unlocks and the boss timer freeze with the
## pause and never run on during the crafting screen or a pick screen.


static func seconds() -> float:
	return GameTime.now_msec() / 1000.0
