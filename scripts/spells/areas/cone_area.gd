class_name ConeArea
extends AreaEffect
## The Cone Area: an instant sector in front of the player. Hits every enemy inside it once.
## Reach is the spell's effective range and the angle (degrees) is its effective size.

const MAX_ANGLE := 359.0
const MIN_ARC_POINTS := 8

var _duration: float = 0.0
var _life_left: float = 0.0

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _shape: CollisionPolygon2D = $Hitbox/Shape
@onready var _visual: Polygon2D = $Visual


func _physics_process(delta: float) -> void:
	_life_left -= delta
	_visual.modulate.a = clampf(_life_left / maxf(_duration, 0.001), 0.0, 1.0)
	if _life_left <= 0.0:
		queue_free()


func launch(spell: SpellData, origin: Vector2, direction: Vector2, _target: Vector2) -> void:
	global_position = origin
	rotation = direction.angle()
	var points := _sector(spell.effective_range(), clampf(spell.effective_size(), 1.0, MAX_ANGLE))
	_shape.polygon = points
	_visual.polygon = points
	_visual.color = spell.color
	_duration = spell.area_data.duration
	_life_left = _duration
	# One hit per enemy per cast: the cooldown outlasts the cone.
	_configure_hitbox(_hitbox, spell, _duration + 1.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	SpellSkin.dress(self, _visual, points, spell, Vector2.ZERO, SpellSkin.INSTANT_LIFE, rng)


## A fan from the origin, centred on +x.
static func _sector(reach: float, angle_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(angle_degrees) * 0.5
	var steps := maxi(MIN_ARC_POINTS, ceili(angle_degrees / 10.0))
	for i in steps + 1:
		points.append(Vector2.from_angle(lerpf(-half, half, float(i) / steps)) * reach)
	return points
