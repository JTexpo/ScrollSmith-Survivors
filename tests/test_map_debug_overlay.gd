extends GutTest


func _map_node() -> GameMap:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(400, 300)
	map.player_start = Vector2(200, 150)
	var placement := MapPlacement.new()
	placement.scene = load("res://scenes/interactables/lectern.tscn")
	placement.position = Vector2(100, 100)
	map.placements = [placement] as Array[MapPlacement]
	var node := (load("res://scenes/world/game_map.tscn") as PackedScene).instantiate() as GameMap
	node.map_data = map
	add_child_autofree(node)
	return node


func test_it_is_hidden_until_toggled() -> void:
	var node := _map_node()
	var overlay := node.get_node("Debug") as MapDebugOverlay
	assert_false(overlay.visible)
	node.toggle_debug()
	assert_true(overlay.visible)
	node.toggle_debug()
	assert_false(overlay.visible)


func test_it_has_a_marker_per_placement_and_one_for_the_start() -> void:
	var overlay := _map_node().get_node("Debug") as MapDebugOverlay
	assert_eq(overlay.marker_count(), 2)
