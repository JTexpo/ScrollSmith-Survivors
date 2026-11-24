extends GutTest
## Sprint 16b: the forest's own enemy sprites (rats, ent, creepers, shaman). The goblin, wolves and kobolds keep showing through the
## `enemy_<type>` fallback; the maze is unchanged (the ruins' own sprites are in `test_ruins_art`).

const BOUNDS := Rect2(0, 0, 960, 540)
const NEW_TYPES: Array[StringName] = [&"swarmer", &"tank", &"exploder", &"support"]
const FALLBACK_TYPES: Array[StringName] = [&"standard", &"chaser", &"ranged"]
const ALL_TYPES: Array[StringName] = [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const ELEMENTS: Array[StringName] = [&"none", &"fire", &"thunder", &"land", &"sea"]
const SIZES := {&"swarmer": Vector2i(10, 10), &"tank": Vector2i(24, 24), &"exploder": Vector2i(14, 14), &"support": Vector2i(14, 14)}

var _root: Node2D
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 3


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


func test_the_forest_resolves_the_four_new_sprites_in_every_colourway() -> void:
	for type in NEW_TYPES:
		for element in ELEMENTS:
			var found := SpriteLibrary.find(StringName("enemy_forest_%s" % type), element)
			assert_not_null(found, "%s %s" % [element, type])
			assert_eq(found.frame_size, SIZES[type], "%s has the size of the sprite it replaces" % type)
		assert_not_null(SpriteLibrary.find_silhouette(StringName("enemy_forest_%s" % type)), "%s has a silhouette" % type)


func test_each_new_sprite_has_the_animations_of_the_sprite_it_replaces() -> void:
	for type in NEW_TYPES:
		var new_set := SpriteLibrary.find(StringName("enemy_forest_%s" % type), &"none").frames()
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


func test_the_forest_falls_back_for_standard_chaser_and_ranged() -> void:
	for type in FALLBACK_TYPES:
		assert_eq(_enemy(type, &"forest").look_sprite(), StringName("enemy_%s" % type), String(type))


func test_an_enemy_in_the_forest_set_uses_the_new_sprite_for_four_archetypes() -> void:
	for type in ALL_TYPES:
		var enemy := _enemy(type, &"forest")
		var expected := StringName("enemy_forest_%s" % type) if NEW_TYPES.has(type) else StringName("enemy_%s" % type)
		assert_eq(enemy.look_sprite(), expected, String(type))
		assert_true((enemy.get_node("Body") as BodyView).has_art(), "%s is drawn with art, never a square" % type)


func test_the_maze_and_empty_sets_are_unchanged() -> void:
	for art_set in [&"maze", &""]:
		for type in ALL_TYPES:
			assert_eq(_enemy(type, art_set).look_sprite(), StringName("enemy_%s" % type), "%s %s" % [art_set, type])


func test_every_element_of_every_new_forest_enemy_is_drawn_with_art() -> void:
	for type in NEW_TYPES:
		for element in ELEMENTS:
			var enemy := _enemy(type, &"forest", element)
			assert_true((enemy.get_node("Body") as BodyView).has_art(), "%s %s" % [element, type])
