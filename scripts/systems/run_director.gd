class_name RunDirector
extends Node
## Runs the long arc of a run: it spawns a boss when the run clock reaches the next boss time (300 s, then
## 300 s after the previous boss spawned, waiting while one is alive), slows normal spawning to half while a
## boss lives, and pays the rewards when it dies. The run clock is pausable, so the timer stops with the
## pause. Dying is still the only way a run ends: after a boss the run goes on and the next one is tougher.

signal boss_spawned(boss: Boss, number: int)
signal boss_defeated(number: int)

## Where a boss's rewards appear around it.
const SCROLL_SPREAD := 16.0

@export var spawner: EnemySpawner

var xp_dropper: ValueDropper
var gold_dropper: ValueDropper
var scroll_dropper: ScrollDropper
var rng := RandomNumberGenerator.new()
## How many bosses have spawned so far (the living one is this number).
var boss_number: int = 0
## The run seconds read by the last _process, for tests and the clock label.
var last_seconds: float = 0.0

var _next_boss_at: float = -1.0
var _rewarded: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	if spawner != null:
		spawner.boss_died.connect(_on_boss_died)


func _process(_delta: float) -> void:
	last_seconds = RunClock.seconds()
	tick(last_seconds)


## Spawns the next boss when it is due. Does nothing without a boss roster, a curve, a scene or a living player.
func tick(seconds: float) -> void:
	if spawner == null or spawner.config == null:
		return
	var config := spawner.config
	var roster := spawner.bosses()
	if config.difficulty == null or roster.is_empty() or config.boss_scene == null:
		return
	if spawner.get_tree().get_first_node_in_group(&"player") == null:
		return
	if _next_boss_at < 0.0:
		_next_boss_at = config.difficulty.boss_interval_seconds
	if current_boss() != null or seconds < _next_boss_at:
		return
	boss_number += 1
	var data := roster[(boss_number - 1) % roster.size()]
	var boss := spawner.spawn_boss(data, boss_number)
	if boss == null:
		boss_number -= 1
		return
	_next_boss_at = seconds + config.difficulty.boss_interval_seconds
	spawner.spawn_rate_scale = 0.5
	boss_spawned.emit(boss, boss_number)


## The living boss, or null.
func current_boss() -> Boss:
	var boss := spawner.boss if spawner != null else null
	return boss if is_instance_valid(boss) and not boss.is_dead() else null


func _on_boss_died(boss: Boss, number: int) -> void:
	if _rewarded.has(boss.get_instance_id()):
		return
	_rewarded[boss.get_instance_id()] = true
	spawner.spawn_rate_scale = 1.0
	var at := boss.global_position
	var data := boss.data
	if xp_dropper != null:
		xp_dropper.place(data.reward_xp * number, at)
	if gold_dropper != null:
		gold_dropper.place(data.reward_gold * number, at)
	if scroll_dropper != null and data.reward_drop_table != null:
		for i in data.reward_scroll_count:
			var scroll := data.reward_drop_table.roll(rng)
			if scroll != null:
				scroll_dropper.place(scroll, at + Vector2.from_angle(TAU * i / maxi(data.reward_scroll_count, 1)) * SCROLL_SPREAD)
	boss_defeated.emit(number)
