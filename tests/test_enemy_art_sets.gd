extends GutTest
## A map names an enemy art set. An enemy looks for `enemy_<set>_<type>` first and falls back to today's `enemy_<type>`, so a set with no
## sprite (all of them, in Sprint 16a) never changes the look and never leaves a coloured square.

const BOUNDS := Rect2(0, 0, 960, 540)
const ARCHETYPES: Array[StringName] = [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const TEMP_ROOT := "res://.godot/art_tests/art_sets"

var _root: Node2D
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 4


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_ROOT + "/enemy_forest_standard_base.tres"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func _data(archetype: StringName, element: StringName = &"none") -> EnemyData:
	return _composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement,
	)


func _enemy(archetype: StringName, art_set: StringName) -> Enemy:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.art_set = art_set
	enemy.setup(_data(archetype), BOUNDS, _rng)
	_root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


## A throwaway set called `enemy_forest_standard` (a copy of the standard enemy's sheet) in a temporary sprite folder.
func _install_forest_standard() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/sprites/enemy_standard_none.tres"), ProjectSettings.globalize_path(TEMP_ROOT + "/enemy_forest_standard_base.tres"))
	SpriteLibrary.root = TEMP_ROOT


func test_an_empty_art_set_uses_the_archetype_sprite() -> void:
	for archetype in ARCHETYPES:
		assert_eq(_enemy(archetype, &"").look_sprite(), StringName("enemy_%s" % archetype))


func test_an_art_set_with_no_such_sprite_falls_back_to_the_archetype_sprite() -> void:
	for archetype in ARCHETYPES:
		var enemy := _enemy(archetype, &"nowhere")
		assert_eq(enemy.look_sprite(), StringName("enemy_%s" % archetype), "no enemy_nowhere_%s exists" % archetype)
		assert_true((enemy.get_node("Body") as BodyView).has_art(), "still drawn with art, never a square")


func test_an_art_set_with_a_sprite_uses_it() -> void:
	_install_forest_standard()
	assert_eq(_enemy(&"standard", &"forest").look_sprite(), &"enemy_forest_standard")
	assert_eq(_enemy(&"standard", &"ruins").look_sprite(), &"enemy_standard", "another set does not see it")


func test_the_look_cache_notices_a_changed_art_set() -> void:
	_install_forest_standard()
	var enemy := _enemy(&"standard", &"")
	var body := enemy.get_node("Body") as BodyView
	assert_false(body.has_art(), "the temporary folder has no plain enemy_standard, so the body shows its square")
	enemy.art_set = &"forest"
	enemy.setup(_data(&"standard"), BOUNDS, _rng)
	assert_true(body.has_art(), "after the set changes the look is looked up again")


func test_the_ruins_enemies_look_exactly_as_before_for_the_four_that_keep_their_sprites() -> void:
	for archetype in [&"swarmer", &"tank", &"exploder", &"support"]:
		var plain := _enemy(archetype, &"")
		var ruins := _enemy(archetype, &"ruins")
		assert_eq(ruins.look_sprite(), plain.look_sprite(), String(archetype))
		assert_eq((ruins.get_node("Body") as BodyView).has_art(), (plain.get_node("Body") as BodyView).has_art())
