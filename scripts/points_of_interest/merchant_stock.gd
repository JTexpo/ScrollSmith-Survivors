class_name MerchantStock
extends RefCounted
## What one merchant has left to sell: a count per potion that refills, all at once, a set time after the first
## sale. Runtime state only, never saved, so a new run (a new merchant node) starts full.

var _counts: Dictionary = {}
var _full_count: int = 0
## Seconds until the refill, or -1 while nothing is missing or the timer has not started.
var _left: float = -1.0


func setup(catalog: PotionCatalog, per_potion: int) -> void:
	_full_count = per_potion
	_counts.clear()
	for potion in catalog.potions:
		_counts[potion.id] = per_potion
	_left = -1.0


func count(id: StringName) -> int:
	return int(_counts.get(id, 0))


## Takes one. False when there is none (an unknown potion has none), and the count never goes below zero.
func take(id: StringName) -> bool:
	if count(id) <= 0:
		return false
	_counts[id] = count(id) - 1
	return true


## Counts the restock down while anything is missing, and refills every potion when it runs out. The timer starts
## on the first tick after a sale.
func tick(delta: float, restock_seconds: float) -> void:
	if is_full():
		_left = -1.0
		return
	if _left < 0.0:
		_left = restock_seconds
	_left -= delta
	if _left <= 0.0:
		for id in _counts:
			_counts[id] = _full_count
		_left = -1.0


## Seconds until the refill (0 when nothing is missing or the timer has not started yet).
func restock_left() -> float:
	return maxf(_left, 0.0)


## Seconds until everything is back, for the prompt and the screen: 0 when the stock is full, the whole `restock_seconds` right after a
## sale (the timer starts on the next tick), then what is left.
func seconds_to_restock(restock_seconds: float) -> float:
	if is_full():
		return 0.0
	return restock_seconds if _left < 0.0 else _left


func is_full() -> bool:
	for id in _counts:
		if int(_counts[id]) < _full_count:
			return false
	return true
