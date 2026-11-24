class_name MissileArea
extends AreaEffect
## The Missile Area: one projectile that flies in a straight line. Speed, range, size,
## damage, tint and how many enemies it can hit all come from the SpellData it is launched with.

## A burst was spawned (tests and tools listen to it).
signal burst_spawned(burst: MissileBurst)

const BURST_SCENE := preload("res://scenes/spells/areas/missile_burst.tscn")

var direction: Vector2 = Vector2.RIGHT
var hits: int = 0

var _speed: float = 0.0
var _life_left: float = 0.0
var _max_hits: int = 1
var _spell: SpellData
var _ended: bool = false

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _body: ColorRect = $Body
@onready var _orb: BodyView = $Orb


func _ready() -> void:
	_hitbox.hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	position += direction * _speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_end()


func launch(spell: SpellData, origin: Vector2, launch_direction: Vector2, _target: Vector2) -> void:
	global_position = origin
	direction = launch_direction.normalized()
	_speed = spell.projectile_speed
	_life_left = spell.effective_range() / maxf(_speed, 0.001)
	_max_hits = spell.max_hits
	_spell = spell
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
		_end()


## Ends the Missile once: a small burst where it stopped (when its AreaData has one), then it is gone. The burst is added a moment
## later because a hit lands inside a physics callback, by a static function that holds only weak references, so a parent or a
## Missile freed in the meantime cannot break it (an unused burst is freed, never left as an orphan).
func _end() -> void:
	if _ended:
		return
	_ended = true
	var data := _spell.area_data if _spell != null else null
	if data != null and data.burst_radius > 0.0:
		var burst := BURST_SCENE.instantiate() as MissileBurst
		burst.damage_scale = damage_scale
		MissileArea._spawn_burst.bind(weakref(get_parent()), burst, _spell, global_position, weakref(self)).call_deferred()
	queue_free()


## Adds the burst to its parent and launches it, then announces it (so a listener gets a burst that is already in the tree).
static func _spawn_burst(parent_ref: WeakRef, burst: MissileBurst, spell: SpellData, at: Vector2, emitter_ref: WeakRef) -> void:
	var parent := parent_ref.get_ref() as Node
	if parent == null or not parent.is_inside_tree():
		burst.free()
		return
	parent.add_child(burst)
	burst.launch(spell, at, Vector2.ZERO, at)
	var emitter := emitter_ref.get_ref() as MissileArea
	if emitter != null:
		emitter.burst_spawned.emit(burst)
