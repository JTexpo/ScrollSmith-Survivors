class_name StressTest
extends Node2D
## Development tool: keeps `enemy_count` full enemies alive around the player while a rotating
## attacker fires, and reports frame time. Not part of the player-facing game.
##
## Run: godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=10
## Options: --area=<missile|cone|zone|line|wave> --drops --boss --obstacles --map=<forest|first_map|maze> --sound --fx --minutes=M --copies=N --interval=SECONDS
## The clock starts at --minutes (default 5), so by default every archetype is unlocked and elites are in the mix.

const WARMUP_FRAMES := 30
const SPAWN_RADIUS_MIN := 40.0
const SPAWN_RADIUS_MAX := 200.0
const SPIN_SPEED := 7.0
const STRESS_SPELL := preload("res://resources/spells/stress_spell.tres")
## --area=<name> stresses that Area's starting spell instead of the default Missile.
const AREA_SPELLS := {
	"missile": "res://resources/spells/fire_missile.tres",
	"cone": "res://resources/spells/thunder_cone.tres",
	"zone": "res://resources/spells/land_area.tres",
	"line": "res://resources/spells/sea_line.tres",
	"wave": "res://resources/spells/sea_wave.tres",
}

@export var enemy_count: int = 300
## 0 means run until closed. Above 0 it prints one STRESS line and quits.
@export var run_seconds: float = 0.0
## Empty means the default stress spell. Otherwise a key of AREA_SPELLS.
@export var area_name: String = ""
## --drops: kills drop real scrolls, XP gems and Gold coins, and the arena starts with a full 100 pickups on the ground.
@export var drops: bool = false
## --minutes=M sets the run clock the spawner sees (0 means only Standard enemies at base strength).
@export var minutes: float = 5.0
## --boss: spawns an Ember Titan next to the player at the start, so its warnings, shots and summons are measured.
@export var boss: bool = false
## --sound: adds a sound board that plays a cast, hit and death sound for every one in the fight (audible), to measure the cost of
## sound and to prove the voice caps hold at the stress rate. The STRESS line then also shows how many requests were dropped.
@export var sound: bool = false
## --fx: adds the screen effects (the director, the burst layer, the shake and the flash), wired to the fight as in the game, and
## prints the most particles alive at once and how many shakes and flashes fired after the STRESS line.
@export var fx: bool = false
## --obstacles: uses the first map (its walls, obstacles and flow field) instead of the plain test arena.
@export var obstacles: bool = false
## --map=ID: uses that catalog map (and so implies --obstacles). An unknown id is reported and the first map kept.
@export var map_id: String = ""
## --copies=N makes the stress spell fire N copies per cast (Duplicate Area), as a ring.
@export var copies: int = 1
## --interval=S overrides the stress spell's cast interval (seconds), to measure at a real one.
@export var interval: float = 0.0

var _frame_ms: Array[float] = []
var _physics_ms_total: float = 0.0
var _process_ms_total: float = 0.0
var _samples: int = 0
var _elapsed: float = 0.0
var _frames: int = 0
var _angle: float = 0.0
var _label_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _board: SoundBoard
var _fx_burst: BurstLayer
var _fx_shake: CameraShake
var _fx_flash: ScreenFlash
var _fx_particles_max: int = 0

@onready var _spawner: EnemySpawner = $EnemySpawner
@onready var _player: Player = $Player
@onready var _loadout: SpellLoadout = $Player/SpellLoadout
@onready var _label: Label = $Hud/Label
@onready var _damage_numbers: DamageNumbers = $DamageNumbers
@onready var _dropper: ScrollDropper = $ScrollDropper
@onready var _xp_dropper: ValueDropper = $XpDropper
@onready var _gold_dropper: ValueDropper = $GoldDropper


func _ready() -> void:
	_read_command_line()
	if obstacles:
		_use_map()
	_rng.randomize()
	_spawner.set_process(false)
	_spawner.elapsed_override = minutes * 60.0
	_spawner.enemy_damaged.connect(_damage_numbers.show_number)
	if drops:
		_spawner.enemy_died.connect(_dropper.on_enemy_died)
		_spawner.enemy_died.connect(_xp_dropper.on_enemy_died)
		_spawner.enemy_died.connect(_gold_dropper.on_enemy_died)
		_scatter_pickups(_dropper.max_pickups)
	_player.health.set_max_health(1.0e9)
	_loadout.slots[0] = SpellInstance.new(_stress_spell())
	_loadout.select(0)
	if run_seconds > 0.0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_spawner.enemy_died.connect(_on_enemy_died)
	if sound:
		_add_sound()
	if fx:
		_add_fx()
	while _spawner.alive < enemy_count:
		if not _spawn_one():
			break
	if boss:
		var titan := _spawner.spawn_boss(_spawner.bosses()[0], 1)
		titan.global_position = _player.global_position + Vector2(110, -30)


func _physics_process(delta: float) -> void:
	_angle += SPIN_SPEED * delta
	_loadout.try_cast(_player.global_position, Vector2.from_angle(_angle))


func _process(delta: float) -> void:
	_frames += 1
	_label_timer += delta
	if _fx_burst != null:
		_fx_particles_max = maxi(_fx_particles_max, _fx_burst.active_count())
	if _label_timer >= 0.25:
		_label_timer = 0.0
		_label.text = "enemies %d  fps %d  frame %.1f ms" % [enemy_count, Engine.get_frames_per_second(), delta * 1000.0]
	if run_seconds <= 0.0 or _frames <= WARMUP_FRAMES:
		return
	_elapsed += delta
	_frame_ms.append(delta * 1000.0)
	_physics_ms_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_process_ms_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_samples += 1
	if _elapsed >= run_seconds:
		_report_and_quit()


## The named Area's spell with a bottomless pool and a fast interval, so it never runs dry.
func _stress_spell() -> SpellData:
	var spell: SpellData
	if AREA_SPELLS.has(area_name):
		spell = (load(AREA_SPELLS[area_name]) as SpellData).duplicate() as SpellData
		spell.max_mana = STRESS_SPELL.max_mana
		spell.cast_interval = STRESS_SPELL.cast_interval
	else:
		if area_name != "":
			push_error("Unknown --area=%s (use %s)" % [area_name, ", ".join(AREA_SPELLS.keys())])
		spell = STRESS_SPELL.duplicate() as SpellData
	spell.copies = copies
	if interval > 0.0:
		spell.cast_interval = interval
	return spell


## Puts `count` scrolls from the plain enemy's drop table on the ground around the player.
func _scatter_pickups(count: int) -> void:
	var entries := _spawner.config.elements[0].drop_table.entries
	for i in count:
		var offset := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
		_dropper.place(entries[i % entries.size()].scroll, _player.global_position + offset)


## Adds enemies up to `enemy_count` alive (a Swarmer cluster is trimmed to fit). False if nothing spawned.
func _spawn_one() -> bool:
	var offset := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	return _spawner.spawn_at(_player.global_position + offset, enemy_count - _spawner.alive) != null


## A board with the busiest sounds wired to the fight, so the caps are exercised at the stress rate.
func _add_sound() -> void:
	_board = (load("res://scenes/audio/sound_board.tscn") as PackedScene).instantiate() as SoundBoard
	add_child(_board)
	_board.unlock()
	_board.start_music()
	_loadout.cast_fired.connect(func(_index: int) -> void: _board.play(SoundId.CAST_FIRE))
	_spawner.enemy_damaged.connect(func(_at: Vector2, _amount: float, _effect: int) -> void: _board.play(SoundId.HIT_FIRE))
	_spawner.enemy_died.connect(func(_enemy: Enemy) -> void: _board.play(SoundId.ENEMY_DIE))


## The effects director and its parts, so every hit the casting areas announce makes its burst, shake and flash.
func _add_fx() -> void:
	_fx_burst = BurstLayer.new()
	add_child(_fx_burst)
	_fx_shake = CameraShake.new()
	add_child(_fx_shake)
	_fx_shake.bind(_player.get_node("Camera2D") as Camera2D)
	_fx_flash = ScreenFlash.new()
	add_child(_fx_flash)
	var director := FxDirector.new()
	add_child(director)
	director.setup(_fx_burst, _fx_shake, _fx_flash)
	director.setup_world(_player)


func _on_enemy_died(_enemy: Enemy) -> void:
	_refill.call_deferred()


func _refill() -> void:
	while _spawner.alive < enemy_count:
		if not _spawn_one():
			break


## The catalog map with that id, and a problem line when there is none (the first map is then the answer). An empty id is no problem.
static func map_for_id(id: String) -> Dictionary:
	var ruins := load("res://resources/maps/first_map.tres") as MapData
	if id.is_empty():
		return {"map": ruins, "problem": ""}
	var catalog := MapCatalog.default_catalog()
	var entry := catalog.find(StringName(id))
	if entry != null:
		return {"map": entry.map, "problem": ""}
	var ids := ", ".join(catalog.ids())
	return {"map": ruins, "problem": "Unknown --map=%s (use %s)" % [id, ids]}


## Swaps the test arena for the chosen map (the first one by default), and sets the spawner, camera and player start from it as Main does.
func _use_map() -> void:
	var arena := get_node_or_null("TestArena")
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	var map := (load("res://scenes/world/game_map.tscn") as PackedScene).instantiate() as GameMap
	var chosen := map_for_id(map_id)
	if not String(chosen["problem"]).is_empty():
		push_error(chosen["problem"])
	map.map_data = chosen["map"]
	_spawner.enemy_art_set = map.map_data.enemy_art_set
	# The player is placed first, so the map's field is built for where the player really stands.
	_player.global_position = map.player_start()
	add_child(map)
	move_child(map, 0)
	var area := map.bounds()
	_spawner.arena_bounds = area
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.limit_left = int(area.position.x)
	camera.limit_top = int(area.position.y)
	camera.limit_right = int(area.end.x)
	camera.limit_bottom = int(area.end.y)


func _read_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemies="):
			enemy_count = int(argument.get_slice("=", 1))
		elif argument.begins_with("--seconds="):
			run_seconds = float(argument.get_slice("=", 1))
		elif argument == "--drops":
			drops = true
		elif argument == "--boss":
			boss = true
		elif argument == "--obstacles":
			obstacles = true
		elif argument.begins_with("--map="):
			map_id = argument.get_slice("=", 1)
			obstacles = true
		elif argument == "--fx":
			fx = true
		elif argument == "--sound":
			sound = true
		elif argument.begins_with("--minutes="):
			minutes = maxf(float(argument.get_slice("=", 1)), 0.0)
		elif argument.begins_with("--copies="):
			copies = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--interval="):
			interval = float(argument.get_slice("=", 1))
		elif argument.begins_with("--area="):
			area_name = argument.get_slice("=", 1)


func _report_and_quit() -> void:
	var report := StressReport.summarize(_frame_ms)
	var spell := _loadout.slots[0].data as SpellData
	print("STRESS copies=%d interval=%.2f enemies=%d avg_fps=%.1f avg_frame_ms=%.2f p99_frame_ms=%.2f avg_physics_ms=%.2f avg_process_ms=%.2f" % [
		spell.copies,
		spell.cast_interval,
		enemy_count,
		report["avg_fps"],
		report["avg_ms"],
		report["p99_ms"],
		_physics_ms_total / maxf(_samples, 1),
		_process_ms_total / maxf(_samples, 1),
	])
	if fx:
		print("FX particles_max=%d shakes=%d flashes=%d" % [_fx_particles_max, _fx_shake.shakes_made(), _fx_flash.flashes_made()])
	if sound:
		print("SOUND started=%d dropped=%d voices_in_use=%d of %d" % [_board.plays_started(), _board.calls_dropped(), _board.voices_in_use(), SoundBoard.VOICES])
	get_tree().quit()
