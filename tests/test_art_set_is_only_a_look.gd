extends GutTest
## Sprint 16c: an enemy's art set changes only how it looks. Its data, stats, hit shapes and behaviour are the same whatever the map names.

const BOUNDS := Rect2(0, 0, 960, 540)
const ALL_TYPES: Array[StringName] = [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const ELEMENTS: Array[StringName] = [&"none", &"fire", &"thunder", &"land", &"sea"]
const SETS: Array[StringName] = [&"", &"ruins", &"forest", &"maze"]

var _root: Node2D
var _player: Player
var _composer: EnemyComposer


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(400, 300)
	_composer = EnemyComposer.new()


func _enemy(archetype: StringName, art_set: StringName, element: StringName = &"none", at: Vector2 = Vector2(100, 100)) -> Enemy:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var data := _composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement,
	)
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.art_set = art_set
	enemy.setup(data, BOUNDS, rng)
	_root.add_child(enemy)
	enemy.global_position = at
	enemy.target_offset = Vector2.ZERO
	enemy.set_physics_process(false)
	return enemy


func _shape_size(enemy: Enemy, path: String) -> Vector2:
	var shape := (enemy.get_node(path) as CollisionShape2D).shape
	return (shape as RectangleShape2D).size if shape is RectangleShape2D else Vector2((shape as CircleShape2D).radius * 2.0, 0.0)


func test_the_composed_enemy_data_does_not_depend_on_the_art_set() -> void:
	for type in ALL_TYPES:
		for element in ELEMENTS:
			var reference := _enemy(type, &"", element)
			for art_set in SETS:
				var enemy := _enemy(type, art_set, element)
				assert_eq(enemy.data, reference.data, "%s %s %s: the same data" % [art_set, element, type])
				assert_eq(enemy.speed, reference.speed, "%s %s %s: the same speed" % [art_set, element, type])
				assert_eq(enemy.data.max_health, reference.data.max_health)
				assert_eq(enemy.data.contact_damage, reference.data.contact_damage)
				assert_eq(enemy.data.element, reference.data.element)
				assert_eq(enemy.data.xp_reward, reference.data.xp_reward)
				assert_eq(enemy.data.gold_reward, reference.data.gold_reward)


func test_the_hit_shapes_and_scale_do_not_depend_on_the_art_set() -> void:
	for type in ALL_TYPES:
		var reference := _enemy(type, &"")
		for art_set in SETS:
			var enemy := _enemy(type, art_set)
			assert_eq(enemy.scale, reference.scale, "%s %s: the same scale" % [art_set, type])
			assert_eq(_shape_size(enemy, "HurtboxComponent/CollisionShape2D"), _shape_size(reference, "HurtboxComponent/CollisionShape2D"), "%s %s: the same hurt shape" % [art_set, type])


func test_the_ranged_brain_still_plays_attack_on_the_new_elemental() -> void:
	var enemy := _enemy(&"ranged", &"ruins", &"none", Vector2(340, 300))
	assert_eq(enemy.look_sprite(), &"enemy_ruins_ranged")
	EnemyBrain.for_data(enemy.data).step(enemy, 1.1)
	var body := enemy.get_node("Body") as BodyView
	assert_eq(body.current_animation(), &"attack")
	enemy._physics_process(0.4)
	assert_eq(body.current_animation(), &"move", "and goes back to moving")
