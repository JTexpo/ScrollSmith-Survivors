class_name ActiveEffects
extends Node
## The timed potion effects running on the player. It owns the player's temporary bonus layer: it
## rebuilds the layer from the running TIMED_BONUS effects whenever one starts or ends, and then asks
## the player to refresh. An Invulnerability Potion also grants the hurtbox's own window. The timers
## tick in _process, so they freeze while the tree is paused, and the node only processes while an
## effect is running.

signal changed

## Potion id to {"potion": PotionData, "left": float}.
var _running: Dictionary = {}
var _player: Player


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	var expired := false
	for id in _running.keys():
		_running[id]["left"] -= delta
		if _running[id]["left"] <= 0.0:
			_running.erase(id)
			expired = true
	if expired:
		_apply()
		changed.emit()
	set_process(not _running.is_empty())


func bind(player: Player) -> void:
	_player = player


## Starts a timed potion. False, changing nothing, if it is not a timed potion or is already running.
func start(potion: PotionData) -> bool:
	var timed := potion.kind == PotionData.Kind.TIMED_BONUS or potion.kind == PotionData.Kind.INVULNERABILITY
	if not timed or potion.duration <= 0.0 or _running.has(potion.id):
		return false
	_running[potion.id] = {"potion": potion, "left": potion.duration}
	if potion.kind == PotionData.Kind.INVULNERABILITY:
		_player.hurtbox.grant_invulnerability(potion.duration)
	set_process(true)
	_apply()
	changed.emit()
	return true


func is_active(id: StringName) -> bool:
	return _running.has(id)


func time_left(id: StringName) -> float:
	return float(_running[id]["left"]) if _running.has(id) else 0.0


## Time left over the duration (1 just started, 0 not running).
func ratio(id: StringName) -> float:
	if not _running.has(id):
		return 0.0
	var potion := _running[id]["potion"] as PotionData
	return clampf(float(_running[id]["left"]) / potion.duration, 0.0, 1.0)


## Drops every effect. The hurtbox's own window is left to run out by itself.
func clear() -> void:
	_running.clear()
	set_process(false)
	_apply()
	changed.emit()


func _apply() -> void:
	var layer := StatBonuses.new()
	for id in _running:
		var potion := _running[id]["potion"] as PotionData
		if potion.kind != PotionData.Kind.TIMED_BONUS:
			continue
		for modifier in potion.modifiers:
			layer.add(modifier.stat, modifier.amount)
	_player.temporary_bonuses = layer
	_player.refresh_bonuses(true)
