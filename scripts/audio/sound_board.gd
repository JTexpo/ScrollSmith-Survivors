class_name SoundBoard
extends Node
## The one place sounds are played. A fixed pool of players (no node is made while playing), the three buses, the mute state and
## the unlock a browser needs. Gameplay never calls it directly: it listens to signals (see `bind`). A sound is silently skipped
## while muted, before the first input, for an unknown id or a missing file (reported once), and (for a `pausable` sound) while
## the game is paused. `VoiceLimiter` decides who gets a voice in a busy fight.

signal mute_changed(muted: bool)

const VOICES := 12
const BUS_SFX := &"Sfx"
const BUS_MUSIC := &"Music"
## Seconds a music crossfade takes (the boss loop in and out).
const CROSSFADE := 1.0
## How much quieter the music is while the game is paused (a screen is open).
const PAUSED_MUSIC_DB := -9.0
## The volume a faded-out music player sits at.
const SILENT_DB := -80.0

## Overridable for tests; null means the default catalog.
@export var catalog: SoundCatalog
## Milliseconds now. Tests replace it so time can be driven by hand.
var clock: Callable = func() -> int: return Time.get_ticks_msec()
var muted: bool = false
var rng := RandomNumberGenerator.new()

var _limiter: VoiceLimiter
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _unlocked: bool = false
var _dropped: int = 0
var _last_pitch: float = 1.0

var _music: Dictionary = {}
var _music_levels: Dictionary = {&"run": -14.0, &"boss": -14.0}
var _music_state: StringName = &"off"
var _music_starts: int = 0
var _duck_db: float = 0.0
var _duck_rate: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 13
	if catalog == null:
		catalog = SoundCatalog.default_catalog()
	_setup_buses()
	for key in _music_levels:
		var level := catalog.find(SoundId.MUSIC_RUN if key == &"run" else SoundId.MUSIC_BOSS)
		if level != null:
			_music_levels[key] = level.volume_db
	_limiter = VoiceLimiter.new(VOICES)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.finished.connect(_on_voice_finished.bind(i))
		add_child(player)
		_players.append(player)
	for key in [&"run", &"boss"]:
		var music_player := AudioStreamPlayer.new()
		music_player.bus = BUS_MUSIC
		music_player.volume_db = SILENT_DB
		add_child(music_player)
		_music[key] = music_player
	# Load every stream now, so nothing loads during a fight.
	for data in catalog.sounds:
		var stream := SoundLibrary.find(data.id)
		if stream != null:
			_streams[data.id] = stream


func _process(delta: float) -> void:
	advance_music(delta)


## The first tap, click or key press unlocks sound (browsers require it) and starts the music. It never consumes the event.
func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)
	if pressed:
		unlock()
		start_music()


## Losing focus or going to the background pauses the music; coming back resumes it.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_set_music_stream_paused(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_set_music_stream_paused(false)


func unlock() -> void:
	_unlocked = true


func is_unlocked() -> bool:
	return _unlocked


func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)
	mute_changed.emit(value)


func voice_count() -> int:
	return _players.size()


func voices_in_use() -> int:
	return _limiter.playing_count()


## How many requests the limiter refused (a busy fight is meant to refuse many).
func calls_dropped() -> int:
	return _dropped


func last_pitch_scale() -> float:
	return _last_pitch


## Plays a sound effect. `pitch` multiplies the sound's own random wobble.
func play(id: StringName, pitch: float = 1.0) -> void:
	if muted or not _unlocked:
		return
	var data := catalog.find(id)
	if data == null:
		SoundLibrary.warn_once(id)
		return
	if data.music:
		return
	if data.pausable and get_tree().paused:
		return
	if not _streams.has(id):
		SoundLibrary.warn_once(id)
		return
	var now: int = clock.call()
	var index := _limiter.request(data, now)
	if index < 0:
		_dropped += 1
		return
	var player := _players[index]
	player.stop()
	player.stream = _streams[id]
	player.volume_db = data.volume_db
	_last_pitch = pitch * pow(2.0, rng.randf_range(-data.wobble, data.wobble) / 12.0)
	player.pitch_scale = _last_pitch
	player.play()
	_limiter.started(index, data, now)


## Starts the run loop (once the first input has unlocked sound). It keeps playing for the rest of the run, even while paused,
## muted or under the boss loop, so it is always where it should be.
func start_music() -> void:
	if not _unlocked or _music_state != &"off":
		return
	if not _start_loop(&"run", SoundId.MUSIC_RUN):
		return
	_music_state = &"run"


## Crossfades the boss loop in (it starts from the top) or out (it stops once faded, so the next boss starts it from the top again).
func set_boss_music(active: bool) -> void:
	if _music_state == &"off":
		return
	if active and _music_state != &"boss":
		if not _start_loop(&"boss", SoundId.MUSIC_BOSS):
			return
		_music_state = &"boss"
	elif not active and _music_state == &"boss":
		_music_state = &"run"


## Lowers the music by `amount_db` and lets it climb back over `seconds` (a jingle plays over it).
func duck(seconds: float, amount_db: float) -> void:
	_duck_db = -absf(amount_db)
	_duck_rate = absf(amount_db) / maxf(seconds, 0.01)
	_apply_bus_volume()


## Moves the fades, the duck and the pause volume forward. `_process` calls it every frame; tests call it by hand.
func advance_music(delta: float) -> void:
	for key in _music:
		var music_player := _music[key] as AudioStreamPlayer
		var wanted := music_target_db(key) if _state_wants(key) else SILENT_DB
		music_player.volume_db = move_toward(music_player.volume_db, wanted, (music_target_db(key) - SILENT_DB) / CROSSFADE * delta)
		if key == &"boss" and _music_state != &"boss" and music_player.playing and music_player.volume_db <= SILENT_DB + 0.01:
			music_player.stop()
	_duck_db = move_toward(_duck_db, 0.0, _duck_rate * delta)
	_apply_bus_volume()


func music_state() -> StringName:
	return _music_state


## How many times a music player was started: the run loop once, the boss loop each boss.
func music_starts() -> int:
	return _music_starts


func music_volume_db(key: StringName) -> float:
	return (_music[key] as AudioStreamPlayer).volume_db


func music_target_db(key: StringName) -> float:
	return _music_levels[key]


func music_playing(key: StringName) -> bool:
	return (_music[key] as AudioStreamPlayer).playing


func music_bus_db() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC))


func music_stream_paused() -> bool:
	return (_music[&"run"] as AudioStreamPlayer).stream_paused


func _state_wants(key: StringName) -> bool:
	return (key == &"run" and _music_state != &"off" and _music_state != &"boss") or (key == &"boss" and _music_state == &"boss")


func _start_loop(key: StringName, id: StringName) -> bool:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		SoundLibrary.warn_once(id)
		return false
	var music_player := _music[key] as AudioStreamPlayer
	music_player.stream = stream
	music_player.volume_db = SILENT_DB if key == &"boss" else music_target_db(key)
	music_player.play()
	_music_starts += 1
	return true


func _set_music_stream_paused(value: bool) -> void:
	for key in _music:
		(_music[key] as AudioStreamPlayer).stream_paused = value


func _apply_bus_volume() -> void:
	var paused_offset := PAUSED_MUSIC_DB if is_inside_tree() and get_tree().paused else 0.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), paused_offset + _duck_db)


## Stops every voice at once (a new run, a test).
func stop_all() -> void:
	for i in _players.size():
		_players[i].stop()
		_limiter.finished(i)


func _on_voice_finished(index: int) -> void:
	_limiter.finished(index)


## Creates the Music and Sfx buses (both feed Master) if they are missing. Volumes live in the sound data and the music code.
func _setup_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
