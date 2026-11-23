class_name PotionBelt
extends Node
## The player's potions during a run: drinks them through PotionSystem, keeps each type's cooldown and
## the short shared cooldown, and remembers which potion the controller has selected. The stock itself
## is the run's `RunPotions` (never saved, empty at the next run). Cooldowns tick in _process, so they freeze while the
## tree is paused, and the node only processes while one is running.

## Seconds after any drink before another potion can be drunk, so mashing cannot burn a stack.
const SHARED_COOLDOWN := 1.0

signal used(potion: PotionData)
signal refused(reason: String)
## The stock, a cooldown or the selection changed.
signal changed

## The controller's selected potion (an index into the catalog).
var selected_index: int = 0

var _player: Player
var _potions: RunPotions
var _catalog: PotionCatalog
## Potion id to seconds of cooldown left.
var _cooldowns: Dictionary = {}
var _shared: float = 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	var ended := false
	_shared = maxf(_shared - delta, 0.0)
	for id in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
			ended = true
	if ended:
		changed.emit()
	set_process(_shared > 0.0 or not _cooldowns.is_empty())


func bind(player: Player, potions: RunPotions, catalog: PotionCatalog) -> void:
	_player = player
	_potions = potions
	_catalog = catalog
	selected_index = 0


## Drinks one potion. A refusal keeps the potion, starts no cooldown and emits `refused`.
func use(id: StringName) -> PotionResult:
	var result := PotionResult.new()
	var potion := _catalog.find(id)
	var reason := PotionSystem.refusal(potion, _player, _potions, cooldown_left(id), _shared)
	if reason.is_empty() and not PotionSystem.apply(potion, _player):
		reason = PotionSystem.REASON_ACTIVE
	if not reason.is_empty():
		result.reason = reason
		refused.emit(reason)
		return result
	_potions.use_potion(id)
	_cooldowns[id] = potion.cooldown
	_shared = SHARED_COOLDOWN
	set_process(true)
	result.ok = true
	result.potion = potion
	used.emit(potion)
	changed.emit()
	return result


## Drinks the potion at a place in the bar (0 is the first). An index outside the bar is refused.
func use_slot(index: int) -> PotionResult:
	if _catalog == null or index < 0 or index >= _catalog.potions.size():
		var result := PotionResult.new()
		result.reason = PotionSystem.REASON_UNKNOWN
		return result
	return use(_catalog.potions[index].id)


## Tells listeners the stock changed (a debug gift, a purchase) so the bar redraws.
func refresh() -> void:
	changed.emit()


func count(id: StringName) -> int:
	return _potions.potion_count(id) if _potions != null else 0


func cooldown_left(id: StringName) -> float:
	return float(_cooldowns.get(id, 0.0))


## Cooldown left over the potion's cooldown: 1 just drunk, 0 ready.
func cooldown_ratio(id: StringName) -> float:
	var potion := _catalog.find(id) if _catalog != null else null
	if potion == null or potion.cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_left(id) / potion.cooldown, 0.0, 1.0)


func shared_left() -> float:
	return _shared


## Moves the controller's selection through the potions in bar order, wrapping around.
func select(step: int) -> void:
	if _catalog == null or _catalog.potions.is_empty():
		return
	selected_index = posmod(selected_index + step, _catalog.potions.size())
	changed.emit()


func use_selected() -> PotionResult:
	return use(_catalog.potions[selected_index].id)
