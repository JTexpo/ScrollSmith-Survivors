extends GutTest
## Which things have a shadow: everything that moves or can be picked up or used. Walls and trees are
## static and have none, which is how a player tells them apart.

const SCENES := [
	"res://scenes/player/player.tscn",
	"res://scenes/enemies/base_enemy.tscn",
	"res://scenes/enemies/boss.tscn",
	"res://scenes/interactables/lectern.tscn",
	"res://scenes/interactables/point_of_interest.tscn",
	"res://scenes/scrolls/scroll_pickup.tscn",
	"res://scenes/progression/xp_gem.tscn",
	"res://scenes/progression/gold_coin.tscn",
]


func test_every_mover_pickup_and_interactable_turns_its_shadow_on() -> void:
	for path in SCENES:
		var node := (load(path) as PackedScene).instantiate()
		assert_true((node.get_node("Body") as BodyView).shadow_enabled, path)
		node.free()


func test_shadow_art_exists_in_the_widths_the_body_picks() -> void:
	for width in BodyView.SHADOW_WIDTHS:
		var set_data := SpriteLibrary.find(StringName("shadow_%d" % width))
		assert_not_null(set_data, "shadow_%d" % width)
		assert_eq(set_data.frame_size.x, width + 2, "the sprite is its width plus a 1 px margin each side")


func test_static_world_things_have_no_shadow() -> void:
	# Obstacles are drawn by DrawChunk, which never builds a BodyView.
	var chunk := DrawChunk.new()
	add_child_autofree(chunk)
	assert_eq(chunk.get_children().size(), 0)
