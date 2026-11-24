class_name MapCatalog
extends Resource
## The maps the player can choose, in the order the map select shows them. Adding a map is a new `MapData`, a run scene that holds it
## and an entry here; no code branches on a map id.

const DEFAULT_PATH := "res://resources/maps/map_catalog.tres"

@export var entries: Array[MapEntry] = []


static func default_catalog() -> MapCatalog:
	return load(DEFAULT_PATH) as MapCatalog


## Null if no entry has that map id.
func find(id: StringName) -> MapEntry:
	for entry in entries:
		if entry != null and entry.map != null and entry.map.id == id:
			return entry
	return null


## Null if no entry plays on that scene.
func entry_for_scene(path: String) -> MapEntry:
	if path.is_empty():
		return null
	for entry in entries:
		if entry != null and entry.scene_path == path:
			return entry
	return null


func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for entry in entries:
		if entry != null and entry.map != null:
			found.append(entry.map.id)
	return found


## The map chosen when nothing else was (the first entry).
func default_id() -> StringName:
	var all := ids()
	return all[0] if not all.is_empty() else &""
