class_name RunClock
extends RefCounted
## Seconds since the run began. It reads GameTime, which stands still while the game is paused, so
## difficulty, unlocks and the boss timer freeze with the pause and never run on during the crafting
## screen or a pick screen. GameTime itself counts from the start of the program, so a run marks its
## start with reset(). Main calls it right after GameTime.reset() when a run starts. The state is
## static because there are no autoloads.

static var _start_msec: int = 0


## Marks now as the start of the run.
static func reset() -> void:
	_start_msec = GameTime.now_msec()


static func seconds() -> float:
	return maxf(GameTime.now_msec() - _start_msec, 0) / 1000.0
