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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 13
	if catalog == null:
		catalog = SoundCatalog.default_catalog()
	_setup_buses()
	_limiter = VoiceLimiter.new(VOICES)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.finished.connect(_on_voice_finished.bind(i))
		add_child(player)
		_players.append(player)
	# Load every stream now, so nothing loads during a fight.
	for data in catalog.sounds:
		var stream := SoundLibrary.find(data.id)
		if stream != null:
			_streams[data.id] = stream


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
