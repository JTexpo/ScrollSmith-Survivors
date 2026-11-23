class_name MissileBurst
extends AreaEffect
## The small burst where a Missile ends: a circular hit of the Missile's `burst_radius` that damages every enemy inside once, for the
## spell's damage times `burst_damage_share`, through the shared hitbox set-up (so the element, the damage scale and the impact
## announcement are the spell's own). A quick ring of effect sprites marks it.

const LIFE := 0.12
const OUTLINE_POINTS := 24
const VISUAL_ALPHA := 0.35

var _life_left: float = LIFE
var _rng := RandomNumberGenerator.new()

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _shape: CollisionShape2D = $Hitbox/Shape
@onready var _visual: Polygon2D = $Visual


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func launch(spell: SpellData, origin: Vector2, _direction: Vector2, _target: Vector2) -> void:
	global_position = origin
	var radius := spell.area_data.burst_radius
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	var outline := PackedVector2Array()
	for i in OUTLINE_POINTS:
		outline.append(Vector2.from_angle(TAU * i / OUTLINE_POINTS) * radius)
	_visual.polygon = outline
	var tint := spell.color
	tint.a = VISUAL_ALPHA
	_visual.color = tint
	_rng.randomize()
	SpellSkin.dress(self, _visual, outline, spell, Vector2.ZERO, SpellSkin.INSTANT_LIFE, _rng)
	# One hit on each enemy for the burst's whole short life.
	_configure_hitbox(_hitbox, spell, LIFE + 1.0)
	_hitbox.damage *= spell.area_data.burst_damage_share
