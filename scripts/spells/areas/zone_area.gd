class_name ZoneArea
extends AreaEffect
## The Area Area: a damage zone dropped where the player points, held within the spell's range.
## Radius is the spell's effective size. It lasts `duration` seconds and hits each enemy inside
## once per `tick_interval`.

const OUTLINE_POINTS := 24
const VISUAL_ALPHA := 0.35

var _life_left: float = 0.0
var _tick_interval: float = 0.0
var _tick_left: float = 0.0
var _outline: PackedVector2Array
var _spell: SpellData
var _rng := RandomNumberGenerator.new()

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _shape: CollisionShape2D = $Hitbox/Shape
@onready var _visual: Polygon2D = $Visual


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	# A fresh set of effect sprites at each damage tick, so the zone keeps looking alive. Damage timing is the hitbox's own.
	if _tick_interval > 0.0:
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left += _tick_interval
			SpellSkin.pulse(self, _outline, _spell, Vector2.ZERO, _tick_interval, _rng)


func launch(spell: SpellData, origin: Vector2, _direction: Vector2, target: Vector2) -> void:
	global_position = spell.clamp_target(origin, target)
	var radius := spell.effective_size()
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
	_life_left = spell.area_data.duration
	var tick := spell.area_data.tick_interval
	_tick_interval = tick
	_tick_left = tick
	_outline = outline
	_spell = spell
	_rng.randomize()
	SpellSkin.dress(self, _visual, outline, spell, Vector2.ZERO, tick if tick > 0.0 else SpellSkin.INSTANT_LIFE, _rng)
	# With no tick interval, each enemy is hit once for the zone's whole life.
	_configure_hitbox(_hitbox, spell, tick if tick > 0.0 else _life_left + 1.0)
