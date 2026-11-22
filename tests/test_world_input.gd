extends GutTest
## World decorations (the arena floor, bodies, Lectern parts) must never capture touches. Godot's
## ColorRect stops mouse and touch input by default, and a visible one swallows every tap before
## it reaches code that listens in _unhandled_input, such as "tap to restart".

const SCENES := [
	"res://scenes/world/test_arena.tscn",
	"res://scenes/world/game_map.tscn",
	"res://scenes/player/player.tscn",
	"res://scenes/enemies/base_enemy.tscn",
	"res://scenes/interactables/lectern.tscn",
	"res://scenes/spells/areas/missile_area.tscn",
	"res://scenes/spells/areas/line_area.tscn",
	"res://scenes/spells/areas/cone_area.tscn",
	"res://scenes/spells/areas/zone_area.tscn",
	"res://scenes/spells/areas/wave_area.tscn",
	"res://scenes/scrolls/scroll_pickup.tscn",
	"res://scenes/ui/target_reticle.tscn",
]


func test_world_scenes_have_no_controls_that_stop_touches() -> void:
	for path in SCENES:
		var root := (load(path) as PackedScene).instantiate()
		add_child_autofree(root)
		var stack: Array = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is Control:
				assert_ne(node.mouse_filter, Control.MOUSE_FILTER_STOP, "%s / %s stops touches" % [path, root.get_path_to(node)])
