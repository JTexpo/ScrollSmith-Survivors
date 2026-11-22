class_name PotionCatalog
extends Resource
## Every potion, in the order the potion bar and the shop show them.

const DEFAULT_PATH := "res://resources/potions/potion_catalog.tres"

@export var potions: Array[PotionData] = []


static func default_catalog() -> PotionCatalog:
	return load(DEFAULT_PATH) as PotionCatalog


## Null if no potion has that id.
func find(id: StringName) -> PotionData:
	for potion in potions:
		if potion.id == id:
			return potion
	return null


## The potion's place in the bar, or -1 if the id is unknown.
func index_of(id: StringName) -> int:
	for i in potions.size():
		if potions[i].id == id:
			return i
	return -1
