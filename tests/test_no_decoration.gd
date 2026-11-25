extends GutTest
## The decoration system (scattered flowers, pebbles and cracks) was removed in spring cleaning 2.

const MAP_FILES := ["res://resources/maps/first_map.tres", "res://resources/maps/forest_map.tres", "res://resources/maps/maze_map.tres"]


func _decoration_properties(object: Object) -> Array[String]:
	var found: Array[String] = []
	for property in object.get_property_list():
		if String(property["name"]).begins_with("decoration_"):
			found.append(property["name"])
	return found


func test_map_data_and_zone_have_no_decoration_fields() -> void:
	assert_eq(_decoration_properties(MapData.new()), [] as Array[String])
	assert_eq(_decoration_properties(MapZone.new()), [] as Array[String])


func test_the_game_map_has_no_decor_layer() -> void:
	var node := (load("res://scenes/world/game_map.tscn") as PackedScene).instantiate() as GameMap
	node.map_data = load("res://resources/maps/first_map.tres") as MapData
	add_child_autofree(node)
	assert_null(node.get_node_or_null("Decor"))


func test_no_decor_sprite_sources_or_scripts_remain() -> void:
	for file in DirAccess.get_files_at("res://art/sprites"):
		assert_false(String(file).begins_with("decor_"), "%s" % file)
	for file in DirAccess.get_files_at("res://scripts/world"):
		assert_false(String(file).begins_with("map_decor"), "%s" % file)
	assert_false(ClassDB.class_exists(&"MapDecor") or FileAccess.file_exists("res://scripts/world/map_decor.gd"), "MapDecor is gone")


func test_the_map_files_name_no_decoration() -> void:
	for path in MAP_FILES:
		assert_false(FileAccess.get_file_as_string(path).contains("decoration_"), path)
