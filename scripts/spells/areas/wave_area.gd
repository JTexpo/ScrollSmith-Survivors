class_name WaveArea
extends AreaEffect
## The Wave Area: a wide crescent that travels outward like a Missile and hits every enemy it
## passes through once. Width is the spell's effective size and grows while it travels.

const THICKNESS := 8.0
const BULGE_RATIO := 0.25
const ARC_POINTS := 10
## The flying objects along the front: one about every ORB_SPACING px, between 2 and MAX_ORBS.
const ORB_SPACING := 10.0
const MAX_ORBS := 24
## A wave wider than this carries the 16 px object, a narrower one the 12 px one.
const WIDE_FROM := 100.0

var direction: Vector2 = Vector2.RIGHT

var _speed: float = 0.0
var _range: float = 0.0
var _travelled: float = 0.0
var _elapsed: float = 0.0
var _base_width: float = 1.0
var _widen_rate: float = 0.0
var _orb_sprite: StringName = &""
var _orbs: Array[BodyView] = []

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _shape: CollisionPolygon2D = $Hitbox/Shape
@onready var _visual: Polygon2D = $Visual


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var step := _speed * delta
	global_position += direction * step
	_travelled += step
	var stretch := current_width() / _base_width
	_hitbox.scale.y = stretch
	_visual.scale.y = stretch
	_update_orbs()
	if _travelled >= _range:
		queue_free()


func launch(spell: SpellData, origin: Vector2, launch_direction: Vector2, _target: Vector2) -> void:
	global_position = origin
	direction = launch_direction.normalized()
	rotation = direction.angle()
	_speed = spell.projectile_speed
	_range = spell.effective_range()
	_base_width = spell.effective_size()
	_widen_rate = spell.area_data.widen_rate
	var crescent := _crescent(_base_width)
	_shape.polygon = crescent
	_visual.polygon = crescent
	_visual.color = spell.color
	SpellSkin.tint(_visual, crescent, spell)
	var look := ElementLooks.for_element(spell.primary_element())
	if look != null:
		var candidate := StringName("%s_%d" % [look.orb_sprite, 16 if _base_width > WIDE_FROM else 12])
		if SpriteLibrary.find(candidate) != null:
			_orb_sprite = candidate
	# One hit per enemy for the wave's whole trip, and hits never stop it.
	_configure_hitbox(_hitbox, spell, _range / maxf(_speed, 0.001) + 1.0)
	_hitbox.max_hits = 0
	_update_orbs()


## The flying objects along the wave's front (none without art).
func orbs() -> Array[BodyView]:
	return _orbs


## Keeps a row of the element's flying objects on the front of the crescent, more of them as it widens. They are upright
## and 1:1 (top level, so neither the wave's rotation nor its stretch touches them) and follow the wave every step.
func _update_orbs() -> void:
	if _orb_sprite == &"":
		return
	var width := current_width()
	var wanted := clampi(roundi(width / ORB_SPACING), 2, MAX_ORBS)
	while _orbs.size() < wanted:
		var orb := BodyView.new()
		orb.top_level = true
		add_child(orb)
		orb.set_look(_orb_sprite)
		orb.play(&"fly")
		_orbs.append(orb)
	while _orbs.size() > wanted:
		_orbs.pop_back().queue_free()
	var bulge := width * BULGE_RATIO
	for i in _orbs.size():
		var t := lerpf(-1.0, 1.0, float(i) / float(maxi(_orbs.size() - 1, 1)))
		_orbs[i].global_position = to_global(Vector2(bulge * (1.0 - t * t), t * width * 0.5)).round()


func current_width() -> float:
	return _base_width * (1.0 + _widen_rate * _elapsed)


## A thin curved band bulging forward (+x), `width` tip to tip along y.
static func _crescent(width: float) -> PackedVector2Array:
	var bulge := width * BULGE_RATIO
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in ARC_POINTS + 1:
		var t := lerpf(-1.0, 1.0, float(i) / ARC_POINTS)
		var x := bulge * (1.0 - t * t)
		outer.append(Vector2(x, t * width * 0.5))
		inner.append(Vector2(x - THICKNESS, t * width * 0.5))
	inner.reverse()
	return outer + inner
