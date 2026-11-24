extends GutTest
## Sprint 16c: the ruins' own enemy sprites (a bandit, a mimic, an elemental). The slime, armour, mephit (imp) and cultist stay; the forest and
## maze keep the goblin, wolf and kobold through the `enemy_<type>` fallback.

const BOUNDS := Rect2(0, 0, 960, 540)
const NEW_TYPES: Array[StringName] = [&"standard", &"chaser", &"ranged"]
const OLD_TYPES: Array[StringName] = [&"swarmer", &"tank", &"exploder", &"support"]
const ALL_TYPES: Array[StringName] = [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const ELEMENTS: Array[StringName] = [&"none", &"fire", &"thunder", &"land", &"sea"]
const SIZES := {&"standard": Vector2i(14, 14), &"chaser": Vector2i(12, 12), &"ranged": Vector2i(14, 14)}
const FOREST_SPRITES: Array[StringName] = [&"swarmer", &"tank", &"exploder", &"support"]

var _root: Node2D
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 5


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


func test_the_ruins_resolve_the_three_new_sprites_in_every_colourway() -> void:
	for type in NEW_TYPES:
		for element in ELEMENTS:
			var found := SpriteLibrary.find(StringName("enemy_ruins_%s" % type), element)
			assert_not_null(found, "%s %s" % [element, type])
			assert_eq(found.frame_size, SIZES[type], "%s has the size of the sprite beside it" % type)
		assert_not_null(SpriteLibrary.find_silhouette(StringName("enemy_ruins_%s" % type)), "%s has a silhouette" % type)


func test_each_new_ruins_sprite_has_the_animations_of_the_sprite_beside_it() -> void:
	for type in NEW_TYPES:
		var new_set := SpriteLibrary.find(StringName("enemy_ruins_%s" % type), &"none").frames()
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


func test_the_ranged_elemental_has_its_attack_animation() -> void:
	var frames := SpriteLibrary.find(&"enemy_ruins_ranged", &"none").frames()
	assert_true(frames.has_animation(&"attack"))
	assert_eq(frames.get_frame_count(&"attack"), 2)
	assert_eq(frames.get_animation_speed(&"attack"), 12.0)
	assert_false(frames.get_animation_loop(&"attack"))


func test_an_enemy_in_the_ruins_set_uses_the_new_sprite_for_three_archetypes() -> void:
	for type in ALL_TYPES:
		var enemy := _enemy(type, &"ruins")
		var expected := StringName("enemy_ruins_%s" % type) if NEW_TYPES.has(type) else StringName("enemy_%s" % type)
		assert_eq(enemy.look_sprite(), expected, String(type))
		assert_true((enemy.get_node("Body") as BodyView).has_art(), "%s is drawn with art, never a square" % type)


func test_the_forest_and_maze_still_resolve_the_old_sprites_for_these_three() -> void:
	for type in NEW_TYPES:
		assert_eq(_enemy(type, &"forest").look_sprite(), StringName("enemy_%s" % type), "forest %s" % type)
		assert_eq(_enemy(type, &"maze").look_sprite(), StringName("enemy_%s" % type), "maze %s" % type)
	for type in FOREST_SPRITES:
		assert_eq(_enemy(type, &"forest").look_sprite(), StringName("enemy_forest_%s" % type), "the forest's own %s" % type)
	for type in ALL_TYPES:
		assert_eq(_enemy(type, &"maze").look_sprite(), StringName("enemy_%s" % type), "maze %s" % type)


func test_an_unknown_or_empty_set_is_unchanged() -> void:
	for art_set in [&"", &"nowhere"]:
		for type in ALL_TYPES:
			assert_eq(_enemy(type, art_set).look_sprite(), StringName("enemy_%s" % type), "%s %s" % [art_set, type])


func test_every_ruins_archetype_and_element_is_drawn_with_art() -> void:
	for type in ALL_TYPES:
		for element in ELEMENTS:
			var enemy := _enemy(type, &"ruins", element)
			assert_true((enemy.get_node("Body") as BodyView).has_art(), "%s %s" % [element, type])


func test_an_elite_ruins_enemy_gets_an_outline_from_the_silhouette() -> void:
	var elite := load("res://resources/enemies/elite_modifier.tres") as EliteModifier
	for type in NEW_TYPES:
		var enemy := _enemy(type, &"ruins")
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


func test_every_animation_of_the_new_sprites_visibly_changes_between_its_frames() -> void:
	var animated := {&"move": [0, 1], &"death": [2, 3], &"attack": [4, 5]}
	for type in NEW_TYPES:
		for element in [&"none", &"fire"]:
			var set_data := SpriteLibrary.find(StringName("enemy_ruins_%s" % type), element)
			for animation in animated:
				if not set_data.frames().has_animation(animation):
					continue
				var pair: Array = animated[animation]
				assert_gte(_frame_difference(set_data, pair[0], pair[1]), 8, "%s %s: the two frames differ by at least 8 pixels" % [type, animation])
