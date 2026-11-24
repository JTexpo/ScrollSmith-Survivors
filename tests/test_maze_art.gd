extends GutTest
## Sprint 16d: the maze's own enemy sprites (a zombie, snakes, a ghost, a troll, a skeleton archer, a warforge, a beholder). The plain
## `enemy_<type>` sprites stay as the default and the fallback; the ruins and forest are unchanged.

const BOUNDS := Rect2(0, 0, 960, 540)
const ALL_TYPES: Array[StringName] = [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const ELEMENTS: Array[StringName] = [&"none", &"fire", &"thunder", &"land", &"sea"]
const RUINS_SPRITES: Array[StringName] = [&"standard", &"chaser", &"ranged"]
const FOREST_SPRITES: Array[StringName] = [&"swarmer", &"tank", &"exploder", &"support"]
const SIZES := {&"standard": Vector2i(14, 14), &"swarmer": Vector2i(10, 10), &"chaser": Vector2i(12, 12), &"tank": Vector2i(24, 24), &"ranged": Vector2i(14, 14), &"exploder": Vector2i(14, 14), &"support": Vector2i(14, 14)}

var _root: Node2D
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 6


func _enemy(archetype: StringName, art_set: StringName, element: StringName = &"none") -> Enemy:
	var data := _composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement,
	)
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.art_set = art_set
	enemy.setup(data, BOUNDS, _rng)
	_root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func test_the_maze_resolves_its_seven_sprites_in_every_colourway() -> void:
	for type in ALL_TYPES:
		for element in ELEMENTS:
			var found := SpriteLibrary.find(StringName("enemy_maze_%s" % type), element)
			assert_not_null(found, "%s %s" % [element, type])
			assert_eq(found.frame_size, SIZES[type], "%s has the size of the sprite beside it" % type)
		assert_not_null(SpriteLibrary.find_silhouette(StringName("enemy_maze_%s" % type)), "%s has a silhouette" % type)


func test_each_maze_sprite_has_the_animations_of_the_sprite_beside_it() -> void:
	for type in ALL_TYPES:
		var new_set := SpriteLibrary.find(StringName("enemy_maze_%s" % type), &"none").frames()
		var old_set := SpriteLibrary.find(StringName("enemy_%s" % type), &"none").frames()
		var new_names := new_set.get_animation_names()
		var old_names := old_set.get_animation_names()
		new_names.sort()
		old_names.sort()
		assert_eq(new_names, old_names, "%s: the same animation names" % type)
		for animation in old_set.get_animation_names():
			assert_eq(new_set.get_frame_count(animation), old_set.get_frame_count(animation), "%s %s: frames" % [type, animation])
			assert_eq(new_set.get_animation_speed(animation), old_set.get_animation_speed(animation), "%s %s: fps" % [type, animation])
			assert_eq(new_set.get_animation_loop(animation), old_set.get_animation_loop(animation), "%s %s: loop" % [type, animation])


func test_an_enemy_in_the_maze_set_uses_its_maze_sprite_for_all_seven() -> void:
	for type in ALL_TYPES:
		var enemy := _enemy(type, &"maze")
		assert_eq(enemy.look_sprite(), StringName("enemy_maze_%s" % type), String(type))
		assert_true((enemy.get_node("Body") as BodyView).has_art(), "%s is drawn with art, never a square" % type)


func test_the_ruins_forest_and_empty_sets_are_unchanged() -> void:
	for type in ALL_TYPES:
		var ruins := StringName("enemy_ruins_%s" % type) if RUINS_SPRITES.has(type) else StringName("enemy_%s" % type)
		assert_eq(_enemy(type, &"ruins").look_sprite(), ruins, "ruins %s" % type)
		var forest := StringName("enemy_forest_%s" % type) if FOREST_SPRITES.has(type) else StringName("enemy_%s" % type)
		assert_eq(_enemy(type, &"forest").look_sprite(), forest, "forest %s" % type)
		assert_eq(_enemy(type, &"").look_sprite(), StringName("enemy_%s" % type), "empty %s" % type)
		assert_eq(_enemy(type, &"nowhere").look_sprite(), StringName("enemy_%s" % type), "unknown %s" % type)


func test_every_maze_archetype_and_element_is_drawn_with_art() -> void:
	for type in ALL_TYPES:
		for element in ELEMENTS:
			assert_true((_enemy(type, &"maze", element).get_node("Body") as BodyView).has_art(), "%s %s" % [element, type])


func test_an_elite_maze_enemy_gets_an_outline_from_the_silhouette() -> void:
	var elite := load("res://resources/enemies/elite_modifier.tres") as EliteModifier
	for type in ALL_TYPES:
		var enemy := _enemy(type, &"maze")
		enemy.make_elite(elite)
		var outline := (enemy.get_node("Body") as BodyView).get_node("Outline") as AnimatedSprite2D
		assert_true(outline.visible, "%s: the silhouette outline shows" % type)
		assert_null(enemy.get_node_or_null("EliteOutline"), "%s: the square outline is only for enemies without art" % type)


## How many pixels differ between two frames of a sheet (frames sit side by side, left to right).
func _frame_difference(set_data: SpriteSetData, a: int, b: int) -> int:
	var sheet := set_data.sheet.get_image()
	var size := set_data.frame_size
	var differing := 0
	for y in size.y:
		for x in size.x:
			if sheet.get_pixel(a * size.x + x, y) != sheet.get_pixel(b * size.x + x, y):
				differing += 1
	return differing


func test_every_animation_of_the_maze_sprites_visibly_changes_between_its_frames() -> void:
	var animated := {&"move": [0, 1], &"death": [2, 3], &"attack": [4, 5], &"fuse": [4, 5], &"pulse": [4, 5]}
	for type in ALL_TYPES:
		for element in [&"none", &"fire"]:
			var set_data := SpriteLibrary.find(StringName("enemy_maze_%s" % type), element)
			for animation in animated:
				if not set_data.frames().has_animation(animation):
					continue
				var pair: Array = animated[animation]
				assert_gte(_frame_difference(set_data, pair[0], pair[1]), 8, "%s %s %s: the two frames differ by at least 8 pixels" % [element, type, animation])
