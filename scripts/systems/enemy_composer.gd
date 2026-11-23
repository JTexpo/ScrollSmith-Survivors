class_name EnemyComposer
extends RefCounted
## Builds the EnemyData for an archetype and element pair. The result is cached, so every enemy of a
## pair shares one resource, which is why nothing may edit it: per-spawn values (difficulty scales,
## the elite flag) live on the Enemy instance. Each composer has its own cache.

var _cache: Dictionary = {}


func compose(archetype: EnemyArchetype, element: EnemyElement) -> EnemyData:
	var key := "%s|%s" % [_key_part(archetype.id, archetype), _key_part(element.id, element)]
	if _cache.has(key):
		return _cache[key]
	var data := EnemyData.new()
	data.display_name = ("%s %s" % [element.display_name, archetype.display_name]).strip_edges()
	data.archetype_id = archetype.id
	data.element_id = element.id
	data.max_health = archetype.max_health
	data.speed = archetype.speed
	data.contact_damage = archetype.contact_damage
	data.body_scale = archetype.body_scale
	data.speed_variation = archetype.speed_variation
	data.offset_radius = archetype.offset_radius
	data.contact_cooldown = archetype.contact_cooldown
	data.contact_knockback = archetype.contact_knockback
	data.xp_reward = archetype.xp_reward
	data.gold_reward = archetype.gold_reward
	data.drop_chance_scale = archetype.drop_chance_scale
	data.behavior = archetype.behavior
	data.spawn_weight = archetype.spawn_weight * element.spawn_weight
	data.element = element.element
	data.color = _shaded(element.color, archetype.shade)
	data.drop_table = element.drop_table
	_cache[key] = data
	return data


## A resource's id names it, so the same pair is found again even after a resource is reloaded. A
## hand-made resource with no id falls back to its instance.
static func _key_part(id: StringName, resource: Resource) -> String:
	return str(id) if not str(id).is_empty() else "#%d" % resource.get_instance_id()


static func _shaded(color: Color, shade: float) -> Color:
	return color.lightened(shade) if shade >= 0.0 else color.darkened(-shade)
