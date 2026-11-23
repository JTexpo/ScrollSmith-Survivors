class_name FxDirector
extends Node
## The one place the screen effects are made. It listens to announcements (a spell hit with its weight, a blast, a boss attack) and
## answers with a pixel burst, a whole-pixel shake and a soft flash scaled by the weight, within hard budgets (a few bursts per frame,
## the burst pool's cap, the shake and flash gaps) so a crowd fight stays readable. Gameplay never calls it.

const MAX_BURSTS_PER_FRAME := 4
## The dust of a heavy hit starts above this weight.
const DUST_FROM := 0.5
const DUST_MAX_COUNT := 8
const BLAST_KICK := 0.6
const SLAM_KICK := 0.8

var _burst: BurstLayer
var _shake: CameraShake
var _flash: ScreenFlash
var _config: ImpactConfig
var _connected: bool = false
var _bursts: int = 0
var _frame_bursts: int = 0


func _process(_delta: float) -> void:
	begin_frame()


## Builds the parts under `main` and wires them (Main calls this once).
func bind(main: Node) -> void:
	if _connected:
		return
	var burst := BurstLayer.new()
	burst.name = "BurstLayer"
	main.add_child(burst)
	var shake := CameraShake.new()
	shake.name = "CameraShake"
	add_child(shake)
	var flash := ScreenFlash.new()
	flash.name = "ScreenFlash"
	add_child(flash)
	shake.bind(main.get_node("Player/Camera2D") as Camera2D)
	setup(burst, shake, flash)
	(main.get_node("RunDirector") as RunDirector).boss_spawned.connect(_on_boss_spawned)


## Uses these three parts and listens for the announcements. Safe to call twice.
func setup(burst: BurstLayer, shake: CameraShake, flash: ScreenFlash) -> void:
	_burst = burst
	_shake = shake
	_flash = flash
	if _connected:
		return
	_connected = true
	ImpactEvents.bus.hit.connect(_on_hit)
	EnemyAttackEvents.bus.blast_detonated.connect(_on_blast)


func is_bound() -> bool:
	return _connected


## Starts a new frame's burst budget (`_process` does this every frame; tests call it by hand).
func begin_frame() -> void:
	_frame_bursts = 0


func bursts_made() -> int:
	return _bursts


func burst_layer() -> BurstLayer:
	return _burst


func camera_shake() -> CameraShake:
	return _shake


func on_boss_attack(attack: BossAttack) -> void:
	if attack.kind == BossAttack.Kind.SLAM and _shake != null:
		_shake.kick(SLAM_KICK)


func _on_boss_spawned(boss: Boss, _number: int) -> void:
	boss.attack_started.connect(on_boss_attack)


func _on_hit(position: Vector2, weight: float, element_id: StringName) -> void:
	if _burst == null:
		return
	if FxSettings.particles and _frame_bursts < MAX_BURSTS_PER_FRAME:
		_frame_bursts += 1
		_bursts += 1
		var numbers := _numbers()
		var colors := _colors_for(element_id)
		_burst.burst(position, &"sparks", colors, roundi(lerpf(numbers.particles_light, numbers.particles_heavy, weight)))
		if weight > DUST_FROM:
			_burst.burst(position, &"dust", colors, roundi((weight - DUST_FROM) * 2.0 * DUST_MAX_COUNT))
	if _shake != null:
		_shake.shake(weight)
	if _flash != null:
		_flash.flash(weight)


func _on_blast(position: Vector2) -> void:
	if _burst != null and FxSettings.particles and _frame_bursts < MAX_BURSTS_PER_FRAME:
		_frame_bursts += 1
		_bursts += 1
		_burst.burst(position, &"dust", [Color(0.95, 0.6, 0.25), Color(0.8, 0.35, 0.2)], 8)
	if _shake != null:
		_shake.kick(BLAST_KICK)


## An element's burst wears its own look's colours (its edge and its tint, made solid).
func _colors_for(element_id: StringName) -> Array[Color]:
	for element in [SpellData.Element.FIRE, SpellData.Element.THUNDER, SpellData.Element.LAND, SpellData.Element.SEA]:
		if ElementLooks.id_of(element) == element_id:
			var look := ElementLooks.for_element(element)
			if look != null:
				return [look.edge, Color(look.tint.r, look.tint.g, look.tint.b, 1.0)]
	return [Color.WHITE, Color(0.8, 0.8, 0.9)]


func _numbers() -> ImpactConfig:
	if _config == null:
		_config = ImpactConfig.default_config()
	return _config
