extends RefCounted
## Builds an enemy of an archetype, element and art set, standing still in a test root.

const BOUNDS := Rect2(0, 0, 960, 540)


static func make(root: Node2D, composer: EnemyComposer, rng: RandomNumberGenerator, archetype: StringName, art_set: StringName, element: StringName = &"none") -> Enemy:
	var data := composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement,
	)
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.art_set = art_set
	enemy.setup(data, BOUNDS, rng)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
