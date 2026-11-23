class_name LineArea
extends AreaEffect
## The Line Area: an instant beam from the player. Hits every enemy inside the rectangle once.
## Length is the spell's effective range and width is its effective size.

var _duration: float = 0.0
var _life_left: float = 0.0

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _shape: CollisionShape2D = $Hitbox/Shape
@onready var _visual: Polygon2D = $Visual


func _physics_process(delta: float) -> void:
	_life_left -= delta
	_visual.modulate.a = clampf(_life_left / maxf(_duration, 0.001), 0.0, 1.0)
	if _life_left <= 0.0:
		queue_free()


func launch(spell: SpellData, origin: Vector2, direction: Vector2, _target: Vector2) -> void:
	global_position = origin
	rotation = direction.angle()
	var length := spell.effective_range()
	var width := spell.effective_size()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(length, width)
	_shape.shape = rectangle
	_shape.position = Vector2(length * 0.5, 0.0)
	var beam := PackedVector2Array([
		Vector2(0.0, -width * 0.5), Vector2(length, -width * 0.5),
		Vector2(length, width * 0.5), Vector2(0.0, width * 0.5),
	])
	_visual.polygon = beam
	_visual.color = spell.color
	_duration = spell.area_data.duration
	_life_left = _duration
	# One hit per enemy per cast: the cooldown outlasts the beam.
	_configure_hitbox(_hitbox, spell, _duration + 1.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	SpellSkin.dress(self, _visual, beam, spell, Vector2.ZERO, SpellSkin.INSTANT_LIFE, rng)
