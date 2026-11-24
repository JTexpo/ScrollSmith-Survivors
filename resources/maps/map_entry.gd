class_name MapEntry
extends Resource
## One map in the catalog: its data and the run scene that plays it. The scene path carries the choice of map.

@export var map: MapData
@export_file("*.tscn") var scene_path: String = ""


## The display name of the map's first boss (its own roster when it names any, else the spawn config's), or an empty string when it has none.
func boss_name() -> String:
	if map == null:
		return ""
	var roster: Array[BossData] = map.bosses
	if roster.is_empty() and map.spawn_config != null:
		roster = map.spawn_config.bosses
	if roster.is_empty() or roster[0] == null:
		return ""
	return roster[0].display_name
