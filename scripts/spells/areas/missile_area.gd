class_name MissileArea
extends AreaEffect
## The Missile Area: one projectile that flies in a straight line. Speed, range, size,
## damage, tint and how many enemies it can hit all come from the SpellData it is launched with.

var direction: Vector2 = Vector2.RIGHT
var hits: int = 0

var _speed: float = 0.0
var _life_left: float = 0.0
var _max_hits: int = 1

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _body: ColorRect = $Body
@onready var _orb: BodyView = $Orb


func _ready() -> void:
	_hitbox.hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	position += direction * _speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func launch(spell: SpellData, origin: Vector2, launch_direction: Vector2, _target: Vector2) -> void:
	global_position = origin
	direction = launch_direction.normalized()
	_speed = spell.projectile_speed
	_life_left = spell.effective_range() / maxf(_speed, 0.001)
	_max_hits = spell.max_hits
	var size := spell.effective_size()
	_body.color = spell.color
	# With its element's art the missile is a flying object drawn 1:1 in one of three size classes, and only the hit shape
	# follows the exact size (a pixel is never scaled). Without art the old square is shown, scaled with the node as before.
	var look := ElementLooks.for_element(spell.primary_element())
	var has_orb := look != null and _orb.set_look(StringName("%s_%d" % [look.orb_sprite, orb_class(size)]))
	_orb.visible = has_orb
	_body.visible = not has_orb
	if has_orb:
		_orb.play(&"fly")
		_hitbox.scale = Vector2.ONE * size
	else:
		scale = Vector2.ONE * size
	_configure_hitbox(_hitbox, spell, _life_left + 1.0)
	_hitbox.max_hits = spell.max_hits


## The size class of the flying object (its sprite is 12, 16 or 24 px) for a missile of this size.
static func orb_class(size: float) -> int:
	if size <= 1.2:
		return 12
	if size <= 2.0:
		return 16
	return 24


func _on_hit_landed(_target: HurtboxComponent) -> void:
	hits += 1
	if hits >= _max_hits:
		queue_free()
