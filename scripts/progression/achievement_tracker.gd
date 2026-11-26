class_name AchievementTracker
extends Node
## Decides when achievements unlock. It only LISTENS to announcements the game already makes (a boss dying, a level-up, Gold changing)
## and checks the run clock once a second; no gameplay script calls it or knows it exists (a guard test pins that). An unlock is
## recorded in the profile, saved at once and announced with `unlocked` (the toast and the chime listen). An earned achievement never
## unlocks twice. `sync` grants, silently, what an old save already proves. `stop` ends it when the player dies.

signal unlocked(data: AchievementData)

## How often the run clock is checked, in seconds.
const CLOCK_STEP := 1.0

## Where the run's seconds come from (a seam so a test can drive the clock).
var seconds_source: Callable = RunClock.seconds

var _catalog: AchievementCatalog
var _profile: PlayerProfile
var _track: LevelTrack
var _saver: ProfileSaver
var _stopped: bool = false
var _since_check: float = 0.0


func bind(catalog: AchievementCatalog, profile: PlayerProfile, track: LevelTrack, spawner: EnemySpawner, progress: RunProgress, saver: ProfileSaver) -> void:
	_catalog = catalog
	_profile = profile
	_track = track
	_saver = saver
	spawner.boss_died.connect(_on_boss_died)
	progress.leveled_up.connect(_on_leveled_up)
	progress.gold_changed.connect(_on_gold_changed)


func _process(delta: float) -> void:
	if _stopped or _catalog == null:
		return
	_since_check += delta
	if _since_check < CLOCK_STEP:
		return
	_since_check = 0.0
	_check(_facts(float(seconds_source.call())))


## Grants, with no signal and no toast, every level, Gold and survival achievement the profile already proves; saves once if any was granted.
func sync() -> void:
	if _catalog == null:
		return
	var granted := false
	var facts := _facts(float(_profile.best_seconds_overall()))
	for data in _catalog.achievements:
		if data.kind == AchievementData.Kind.BOSS or _profile.has_achievement(data.id):
			continue
		if AchievementRules.is_met(data, facts):
			_profile.grant_achievement(data.id)
			granted = true
	if granted and _saver != null:
		_saver.save_now()


## How many of the catalog's achievements the player holds (an id the catalog no longer has is not counted).
func earned_count() -> int:
	var count := 0
	if _profile != null and _catalog != null:
		for data in _catalog.achievements:
			if _profile.has_achievement(data.id):
				count += 1
	return count


## No further unlocks (the player died). The clock is checked one last time first, so surviving 5 minutes counts even when the
## player dies before the next once-a-second check.
func stop() -> void:
	if not _stopped and _catalog != null:
		_check(_facts(float(seconds_source.call())))
	_stopped = true


func _facts(seconds: float) -> AchievementFacts:
	var facts := AchievementFacts.new()
	facts.level = _profile.level(_track)
	facts.lifetime_gold = _profile.lifetime_gold
	facts.seconds = seconds
	return facts


func _on_boss_died(boss: Boss, _number: int) -> void:
	if _stopped or boss == null or boss.data == null:
		return
	var facts := _facts(float(seconds_source.call()))
	facts.boss_id = boss.data.id
	_check(facts)


func _on_leveled_up(_level: int, _reward: LevelReward) -> void:
	if not _stopped:
		_check(_facts(float(seconds_source.call())))


func _on_gold_changed(_total_gold: int) -> void:
	if not _stopped:
		_check(_facts(float(seconds_source.call())))


## Unlocks every achievement the facts meet that the player does not hold yet, in catalog order. The profile is saved once for the whole
## batch (a jump across several levels is one write) and before any announcement, so a crash can never lose an unlock the player was told about.
func _check(facts: AchievementFacts) -> void:
	var fresh: Array[AchievementData] = []
	for data in _catalog.achievements:
		if _profile.has_achievement(data.id):
			continue
		if AchievementRules.is_met(data, facts) and _profile.grant_achievement(data.id):
			fresh.append(data)
	if fresh.is_empty():
		return
	if _saver != null:
		_saver.save_now()
	for data in fresh:
		unlocked.emit(data)
