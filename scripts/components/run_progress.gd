class_name RunProgress
extends Node
## Turns collected XP into level-ups during a run. Stat and slot rewards apply the moment their level
## is reached. Rewards that change the starting spells (random buff, chosen buff, second spell) wait
## for the next run, so a level-up never interrupts a fight or touches a spell the player is using.

signal xp_changed(total_xp: int, level: int)
signal leveled_up(level: int, reward: LevelReward)
signal gold_changed(total_gold: int)

var profile: PlayerProfile
var track: LevelTrack
## XP collected since this run began.
var run_xp: int = 0
## Gold collected since this run began.
var run_gold: int = 0

var _player: Player


func bind(player: Player, run_profile: PlayerProfile, level_track: LevelTrack) -> void:
	_player = player
	profile = run_profile
	track = level_track


func level() -> int:
	return profile.level(track)


## Ignores amounts at or below 0 and a dead player. Several level-ups from one gain apply in order.
func add_xp(amount: int) -> void:
	if amount <= 0 or profile == null or _player.health.is_dead():
		return
	var before := level()
	profile.add_xp(amount)
	run_xp += amount
	xp_changed.emit(profile.total_xp, level())
	for reached in range(before + 1, level() + 1):
		var reward := track.reward_for_level(reached)
		_apply(reached, reward)
		leveled_up.emit(reached, reward)


## Banks Gold the moment it is collected. Ignores amounts at or below 0 and a dead player.
func add_gold(amount: int) -> void:
	if amount <= 0 or profile == null or _player.health.is_dead():
		return
	profile.earn_gold(amount)
	run_gold += amount
	gold_changed.emit(profile.gold)


## Tells the HUD the profile's Gold changed some other way than by collecting a coin (a purchase).
func announce_gold() -> void:
	if profile != null:
		gold_changed.emit(profile.gold)

func _apply(reached: int, reward: LevelReward) -> void:
	match reward.kind:
		LevelReward.Kind.SPEED, LevelReward.Kind.HEALTH, LevelReward.Kind.MANA:
			_player.level_bonuses = StatBonuses.for_level(track, reached)
			_player.refresh_bonuses(true)
		LevelReward.Kind.SLOT:
			_player.loadout.unlock_next()
		_:
			# Random buff, chosen buff and second spell are applied at the start of the next run.
			pass
