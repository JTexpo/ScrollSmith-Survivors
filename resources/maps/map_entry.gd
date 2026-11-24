class_name MapEntry
extends Resource
## One map in the catalog: its data and the run scene that plays it. The scene path carries the choice of map.

@export var map: MapData
@export_file("*.tscn") var scene_path: String = ""


## The display name of the first boss of the map's spawn config, or an empty string when it has none.
func boss_name() -> String:
	if map == null or map.spawn_config == null or map.spawn_config.bosses.is_empty() or map.spawn_config.bosses[0] == null:
		return ""
	return map.spawn_config.bosses[0].display_name
