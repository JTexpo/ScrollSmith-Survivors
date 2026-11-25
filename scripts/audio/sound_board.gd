class_name SoundBoard
extends Node
## The one place sounds are played. A fixed pool of players (no node is made while playing), the three buses, the mute state and
## the unlock a browser needs. Gameplay never calls it directly: it listens to signals (see `bind`). A sound is silently skipped
## while muted, before the first input, for an unknown id or a missing file (reported once), and (for a `pausable` sound) while
## the game is paused. `VoiceLimiter` decides who gets a voice in a busy fight.

signal mute_changed(muted: bool)
## Every request to play a sound effect, before any of the rules that may silence it (locked, muted, paused, full voices). Tests and
## the sound-test tool listen to it.
signal requested(id: StringName)

const VOICES := 12
const BUS_SFX := &"Sfx"
const BUS_MUSIC := &"Music"
## Seconds a music crossfade takes (the boss loop in and out).
const CROSSFADE := 1.0
## How much quieter the music is while the game is paused (a screen is open).
const PAUSED_MUSIC_DB := -9.0
## The volume a faded-out music player sits at.
const SILENT_DB := -80.0
## Seconds between two footsteps while the wizard walks.
const STEP_INTERVAL := 0.32
## What an enemy this big or bigger sounds like when it dies.
const BIG_ENEMY_SCALE := 1.4

## Overridable for tests; null means the default catalog.
@export var catalog: SoundCatalog
## Milliseconds now. Tests replace it so time can be driven by hand.
var clock: Callable = func() -> int: return Time.get_ticks_msec()
var muted: bool = false
## In a browser, the permission to play sound lasts for the whole page, so a board made by a restart keeps it.
static var page_unlocked: bool = false
var rng := RandomNumberGenerator.new()

var _limiter: VoiceLimiter
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _unlocked: bool = false
var _dropped: int = 0
var _started: int = 0
var _last_pitch: float = 1.0
var _last_volume_offset: float = 0.0
var _impact_config: ImpactConfig

var _music: Dictionary = {}
var _music_levels: Dictionary = {&"run": -14.0, &"boss": -14.0}
var _music_state: StringName = &"off"
var _music_starts: int = 0
var _duck_db: float = 0.0
var _duck_rate: float = 0.0

var _bound: bool = false
var _player: Player
var _last_element: int = SpellData.Element.FIRE
var _step_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 13
	if inherits_page_unlock(OS.has_feature("web")):
		_unlocked = true
	if catalog == null:
		catalog = SoundCatalog.default_catalog()
	_setup_buses()
	apply_settings()
	SettingsEvents.bus.changed.connect(apply_settings)
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
	_update_steps(delta)


## The first tap, click or key press unlocks sound (browsers require it) and starts the music. It never consumes the event.
func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed)
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


## M mutes and unmutes. The board keeps running while the game is paused, so the key works in every menu too.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		set_muted(not muted)


func unlock() -> void:
	_unlocked = true
	if OS.has_feature("web"):
		page_unlocked = true


## A desktop game needs no gesture to play sound; a browser does, and a headless run (tests, servers) stays quiet.
static func starts_unlocked(is_web: bool, display_name: String) -> bool:
	return not is_web and display_name != "headless"


## Whether a new board in a browser already has the page's permission.
static func inherits_page_unlock(is_web: bool) -> bool:
	return is_web and page_unlocked


## Called by Main once the game is up: unlocks and starts the music where no gesture is needed (or the page already has one).
func start_if_allowed() -> void:
	if _unlocked or starts_unlocked(OS.has_feature("web"), DisplayServer.get_name()):
		unlock()
		start_music()


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


## How many sounds really got a voice (for tests and the stress scene).
func plays_started() -> int:
	return _started


func last_pitch_scale() -> float:
	return _last_pitch


func last_volume_offset_db() -> float:
	return _last_volume_offset


## Plays a sound effect. `pitch` multiplies the sound's own random wobble and `volume_offset_db` adds to its volume.
func play(id: StringName, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	requested.emit(id)
	# A board that has left the tree (a scene change is freeing it) cannot play: the engine refuses and logs an error.
	if muted or not _unlocked or not is_inside_tree():
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
	_release_idle_voices()
	var now: int = clock.call()
	var index := _limiter.request(data, now)
	if index < 0:
		_dropped += 1
		return
	var player := _players[index]
	player.stop()
	player.stream = _streams[id]
	player.volume_db = data.volume_db + volume_offset_db
	_last_volume_offset = volume_offset_db
	_last_pitch = pitch * pow(2.0, rng.randf_range(-data.wobble, data.wobble) / 12.0)
	player.pitch_scale = _last_pitch
	player.play()
	_started += 1
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
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), _setting_db(GameSettings.music_volume) + paused_offset + _duck_db)


## Sets both buses from the player's volume settings (the music bus keeps its paused offset and duck on top). Runs at start and
## whenever `SettingsEvents` announces a change.
func apply_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), _setting_db(GameSettings.sfx_volume))
	_apply_bus_volume()


## A 0 to 1 volume as decibels; 0 is silent.
static func _setting_db(volume: float) -> float:
	return SILENT_DB if volume <= 0.0 else maxf(linear_to_db(volume), SILENT_DB)


## Connects every game event to its sound, once. `main` is the Main node: the board only listens to signals that already exist
## (plus the few small ones added for it) and never changes anything in the game.
func bind(main: Node) -> void:
	if _bound:
		return
	_bound = true
	_player = main.get_node("Player") as Player
	_player.loadout.cast_fired.connect(_on_cast.bind(_player.loadout))
	_player.hurtbox.hit_received.connect(_on_player_hit)
	_player.died.connect(_on_player_died)
	_player.collector.collected.connect(func(_scroll: ScrollData) -> void: play(SoundId.PICKUP_SCROLL))
	_player.collector.xp_collected.connect(func(_amount: int) -> void: play(SoundId.PICKUP_XP))
	_player.collector.gold_collected.connect(func(_amount: int) -> void: play(SoundId.PICKUP_GOLD))
	_player.belt.used.connect(func(_potion: PotionData) -> void: play(SoundId.POTION_DRINK))
	_player.belt.refused.connect(func(_reason: String) -> void: play(SoundId.POTION_REFUSED))
	_player.progress.leveled_up.connect(_on_level_up)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.enemy_damaged.connect(_on_enemy_damaged)
	bind_impacts()
	(main.get_node("LowHealthWarning") as LowHealthWarning).beat.connect(on_health_beat)
	for widget in (main.get_node("Hud/SpellBar") as SpellBar).widgets:
		widget.went_low.connect(on_mana_low)
	spawner.enemy_died.connect(_on_enemy_died)
	var director := main.get_node("RunDirector") as RunDirector
	director.boss_spawned.connect(_on_boss_spawned)
	director.boss_defeated.connect(_on_boss_defeated)
	EnemyAttackEvents.bus.shot_fired.connect(func(_at: Vector2) -> void: play(SoundId.ENEMY_SHOT))
	EnemyAttackEvents.bus.blast_warned.connect(func(_at: Vector2, _radius: float) -> void: play(SoundId.BLAST_WARN))
	EnemyAttackEvents.bus.blast_detonated.connect(func(_at: Vector2) -> void: play(SoundId.BLAST_BOOM))
	for lectern in main.get_tree().get_nodes_in_group(&"lecterns"):
		if main.is_ancestor_of(lectern):
			lectern.interacted.connect(func(_actor: Node) -> void: play(SoundId.LECTERN_OPEN))
	main.point_effect_applied.connect(_on_point_effect)
	(main.get_node("CraftingScreen") as CraftingScreen).crafted.connect(func() -> void: play(SoundId.CRAFT_CONFIRM))
	(main.get_node("CraftingScreen") as CraftingScreen).refused.connect(func(_reason: String) -> void: play(SoundId.CRAFT_FAIL))
	var shop := main.get_node("ShopScreen") as ShopScreen
	shop.changed.connect(func() -> void: play(SoundId.SHOP_BUY if shop.last_action == &"buy" else SoundId.SHOP_EQUIP))
	shop.refused.connect(func(_reason: String) -> void: play(SoundId.SHOP_FAIL))
	var merchant := main.get_node("MerchantScreen") as MerchantScreen
	merchant.changed.connect(func() -> void: play(SoundId.SHOP_BUY))
	merchant.refused.connect(func(_reason: String) -> void: play(SoundId.SHOP_FAIL))
	for button in main.find_children("*", "Button", true, false):
		_wire_button(button as Button)
	get_tree().node_added.connect(_on_node_added)


## A spell slot's pool just dropped low: one faint blip.
func on_mana_low(_index: int) -> void:
	play(SoundId.MANA_LOW)


## The warning beat: only the strongest level makes a sound (the slow heart beat above the threshold is silent).
func on_health_beat(level: int) -> void:
	if level >= 2:
		play(SoundId.HEARTBEAT)


func _on_cast(index: int, loadout: SpellLoadout) -> void:
	var instance := loadout.slots[index]
	if instance == null:
		return
	_last_element = instance.data.primary_element()
	play(StringName("cast_" + _element_name(_last_element)))


## A strong hit adds a bright accent and a resisted one a dull one. The base hit sound itself comes from the spell's own hit event
## (`_on_impact`), which knows the hit's element and weight.
func _on_enemy_damaged(_position: Vector2, _amount: float, effect: int) -> void:
	if effect == ElementTable.Effect.VULNERABLE:
		play(SoundId.HIT_STRONG)
	elif effect == ElementTable.Effect.RESISTED:
		play(SoundId.HIT_RESISTED)


## Listens for spell hits (called by `bind`; tests call it directly).
func bind_impacts() -> void:
	if not ImpactEvents.bus.hit.is_connected(_on_impact):
		ImpactEvents.bus.hit.connect(_on_impact)


## The hit sound of the hit's own element, lower and louder the heavier the spell.
func _on_impact(_position: Vector2, weight: float, element_id: StringName) -> void:
	if _impact_config == null:
		_impact_config = ImpactConfig.default_config()
	var element := element_id if element_id in [&"fire", &"thunder", &"land", &"sea"] else &"fire"
	play(StringName("hit_" + String(element)), 1.0 - _impact_config.sound_pitch_drop * weight, _impact_config.sound_volume_up_db * weight)


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.is_elite:
		play(SoundId.ENEMY_DIE_ELITE)
	elif enemy.data != null and enemy.data.body_scale >= BIG_ENEMY_SCALE:
		play(SoundId.ENEMY_DIE_BIG)
	else:
		play(SoundId.ENEMY_DIE)


func _on_player_hit(_damage: float, _source: Vector2, _knockback: float, _effect: int) -> void:
	play(SoundId.PLAYER_HURT)


func _on_player_died() -> void:
	play(SoundId.PLAYER_DIE)
	duck(1.5, 10.0)


func _on_level_up(_level: int, _reward: LevelReward) -> void:
	play(SoundId.LEVEL_UP)
	duck(1.0, 8.0)


func _on_boss_spawned(boss: Boss, _number: int) -> void:
	play(SoundId.BOSS_SPAWN)
	set_boss_music(true)
	boss.attack_started.connect(_on_boss_attack)


func _on_boss_defeated(_number: int) -> void:
	play(SoundId.BOSS_DIE)
	set_boss_music(false)


func _on_boss_attack(attack: BossAttack) -> void:
	match attack.kind:
		BossAttack.Kind.SLAM:
			play(SoundId.BOSS_SLAM)
		BossAttack.Kind.CHARGE:
			play(SoundId.BOSS_CHARGE)
		BossAttack.Kind.BURST:
			play(SoundId.BOSS_BURST)


func _on_point_effect(kind: int) -> void:
	match kind:
		PointOfInterestData.Kind.HEAL:
			play(SoundId.SHRINE_HEAL)
		PointOfInterestData.Kind.RESTORE_MANA:
			play(SoundId.SHRINE_MANA)
		PointOfInterestData.Kind.LOOT:
			play(SoundId.CHEST_OPEN)
		PointOfInterestData.Kind.MERCHANT:
			play(SoundId.MERCHANT_OPEN)


## A soft step every STEP_INTERVAL while the wizard walks and is alive.
func _update_steps(delta: float) -> void:
	if _player == null or _player.health.is_dead() or _player.velocity.length() <= Player.MOVE_ANIMATION_SPEED:
		_step_left = 0.0
		return
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = STEP_INTERVAL
		play(SoundId.STEP)


## A leaving board stops listening for new buttons: during a scene change it is out of the tree for a frame while the next scene's buttons
## arrive, and wiring those to it would make it play from outside the tree.
func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_wire_button(node as Button)


func _wire_button(button: Button) -> void:
	if button.has_meta(&"sound_wired"):
		return
	button.set_meta(&"sound_wired", true)
	button.pressed.connect(func() -> void: play(SoundId.UI_BACK if button.theme_type_variation == &"ButtonRed" else SoundId.UI_CLICK))
	button.focus_entered.connect(func() -> void: play(SoundId.UI_HOVER))


func _element_name(element: int) -> String:
	var found := String(ElementLooks.id_of(element))
	return "fire" if found == "none" else found


## Stops every voice at once (a new run, a test).
func stop_all() -> void:
	for i in _players.size():
		_players[i].stop()
		_limiter.finished(i)


## A voice is normally freed by its player's `finished` signal. If that signal is ever missed (a player stopped from outside, a
## platform that does not send it), the slot would stay taken for the rest of the run, so idle players are released here.
func _release_idle_voices() -> void:
	for i in _players.size():
		if not _players[i].playing:
			_limiter.finished(i)


func _on_voice_finished(index: int) -> void:
	_limiter.finished(index)


## The Music and Sfx buses (both feed Master) come from `default_bus_layout.tres`, which the project loads at start. They are never
## added here: on the web a bus added at run time reverses the engine's bus order and silences everything
## (see `tests/test_audio_buses.gd`). Volumes live in the sound data and the music code.
func _setup_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			push_error("SoundBoard: the audio bus '%s' is missing; it comes from default_bus_layout.tres" % bus_name)
