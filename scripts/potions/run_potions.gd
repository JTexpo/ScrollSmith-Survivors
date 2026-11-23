class_name RunPotions
extends RefCounted
## The potions the player holds during ONE run: at most `MAX_POTIONS` of each type, never saved, gone when the run ends (a new `Main`
## starts with an empty one). The in-run merchant is the only source. The method names match what the saved profile used to have, so
## the belt and the shop rules take this where they took the profile.

const MAX_POTIONS := 3

## Potion id (StringName) to how many are held (1 to MAX_POTIONS; a zero count is removed).
var _counts: Dictionary = {}


func potion_count(id: StringName) -> int:
	return int(_counts.get(id, 0))


## Adds potions, never past MAX_POTIONS, and returns how many were really added.
func add_potion(id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var added := mini(amount, MAX_POTIONS - potion_count(id))
	if added > 0:
		_counts[id] = potion_count(id) + added
	return maxi(added, 0)


## Consumes one potion. False, with nothing changed, if there is none.
func use_potion(id: StringName) -> bool:
	var count := potion_count(id)
	if count <= 0:
		return false
	if count == 1:
		_counts.erase(id)
	else:
		_counts[id] = count - 1
	return true


func is_empty() -> bool:
	return _counts.is_empty()


func clear() -> void:
	_counts.clear()
