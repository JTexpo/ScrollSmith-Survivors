class_name Player
extends CharacterBody2D

signal died
## The bonuses were recomputed. `total` is the sum of the three layers, for anything that needs the
## whole (the scroll dropper's luck).
signal bonuses_changed(total: StatBonuses)

const SLOT_ACTIONS: Array[StringName] = [
	&"spell_slot_1", &"spell_slot_2", &"spell_slot_3", &"spell_slot_4", &"spell_slot_5",
]
## How long the cast animation shows after a cast, in seconds.
const CAST_ANIMATION_TIME := 0.25
## Below this speed (px/s) the wizard stands still.
const MOVE_ANIMATION_SPEED := 5.0

const POTION_ACTIONS: Array[StringName] = [
	&"potion_1", &"potion_2", &"potion_3", &"potion_4", &"potion_5", &"potion_6",
]

var _cast_left: float = 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var _move: MoveComponent = $MoveComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _flash: HitFlashComponent = $HitFlashComponent
@onready var aim: AimComponent = $AimComponent
@onready var loadout: SpellLoadout = $SpellLoadout
@onready var inventory: ScrollInventory = $ScrollInventory
@onready var collector: PickupCollector = $PickupCollector
@onready var interaction: InteractionComponent = $InteractionComponent
@onready var progress: RunProgress = $RunProgress
@onready var effects: ActiveEffects = $ActiveEffects
@onready var belt: PotionBelt = $PotionBelt
@onready var _body: BodyView = $Body


## The values the scene starts with. Bonuses are always worked out from these, so applying the same
## bonuses twice gives the same result.
var base_speed: float = 0.0
var base_health: float = 0.0

## The three sources of bonuses. Each owner sets its own layer and then calls refresh_bonuses():
## RunStart and RunProgress set the level layer, RunStart sets the equipment layer, and ActiveEffects
## sets the temporary (potion) layer. Nothing else pushes bonuses to the player and the loadout.
var level_bonuses := StatBonuses.new()
var equipment_bonuses := StatBonuses.new()
var temporary_bonuses := StatBonuses.new()

var _cast_blocked: bool = false


## The player's hurtbox, for the things that grant it a timed window.
var hurtbox: HurtboxComponent:
	get:
		return _hurtbox


## Call when a menu closes. The player will not cast until the cast input has been released once,
## so the click that confirmed something in the menu cannot also fire a spell.
func require_cast_release() -> void:
	_cast_blocked = true


func _ready() -> void:
	base_speed = _move.speed
	base_health = health.max_health
	_hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	effects.bind(self)
	_body.set_look(&"player")
	loadout.cast_fired.connect(_on_cast_fired)


## Picks the wizard's animation and facing: casting shows the cast animation for a moment and faces the aim, otherwise
## it moves or stands, facing the way it walks.
func _update_body(delta: float) -> void:
	_cast_left = maxf(_cast_left - delta, 0.0)
	var casting := _cast_left > 0.0
	_body.set_facing(aim.aim_direction.x if casting or aim.is_firing else velocity.x)
	if casting:
		_body.play(&"cast")
	elif velocity.length() > MOVE_ANIMATION_SPEED:
		_body.play(&"move")
	else:
		_body.play(&"idle")


func _on_cast_fired(_index: int) -> void:
	_cast_left = CAST_ANIMATION_TIME
	_body.play(&"cast")


## Adds the level, equipment and temporary layers and pushes the total, so a bonus can neither be
## dropped nor counted twice whichever layer changed. With `heal_difference` a rise in maximum health
## also heals by that rise.
func refresh_bonuses(heal_difference: bool = false) -> void:
	var total := StatBonuses.combined(StatBonuses.combined(level_bonuses, equipment_bonuses), temporary_bonuses)
	apply_stat_bonuses(total, heal_difference)
	bonuses_changed.emit(total)


## Sets speed, maximum health and the spells' mana bonus from the base values and `bonuses`. With
## `heal_difference` a rise in maximum health also heals by that rise (a mid-run reward). Without it
## the player starts with full health (a new run).
func apply_stat_bonuses(bonuses: StatBonuses, heal_difference: bool = false) -> void:
	_move.speed = base_speed * bonuses.multiplier(StatBonuses.Stat.SPEED)
	var new_max := base_health * bonuses.multiplier(StatBonuses.Stat.HEALTH)
	if heal_difference:
		health.raise_max_health(new_max - health.max_health)
	else:
		health.set_max_health(new_max)
	loadout.set_bonuses(bonuses)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_move.apply(self, direction, _knockback.update(delta))
	_update_body(delta)
	if _cast_blocked:
		# The click that closed a menu is probably still held. Wait for it to be released. This
		# reads the real input, because aim.is_firing is updated after this node runs and is stale
		# on the first frame after a pause. The frame the guard lifts is skipped for the same reason.
		loadout.end_cast()
		if not Input.is_action_pressed(&"cast"):
			_cast_blocked = false
		return
	if aim.is_firing:
		loadout.try_cast(global_position, aim.aim_direction, aim.aim_point)
	else:
		loadout.end_cast()


func _unhandled_input(event: InputEvent) -> void:
	if health.is_dead():
		return
	if event.is_action_pressed(&"interact"):
		interaction.try_interact(self)
		return
	for index in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[index]):
			loadout.select(index)
			return
	for index in POTION_ACTIONS.size():
		if event.is_action_pressed(POTION_ACTIONS[index]):
			belt.use_slot(index)
			return
	if event.is_action_pressed(&"potion_prev"):
		belt.select(-1)
	elif event.is_action_pressed(&"potion_next"):
		belt.select(1)
	elif event.is_action_pressed(&"potion_use"):
		belt.use_selected()
	elif event.is_action_pressed(&"spell_prev"):
		loadout.cycle(-1)
	elif event.is_action_pressed(&"spell_next"):
		loadout.cycle(1)


func _on_hit_received(_damage: float, source_position: Vector2, knockback: float, _effect: int) -> void:
	_knockback.apply_impulse(global_position - source_position, knockback)
	_flash.flash()


func _on_died() -> void:
	remove_from_group(&"player")
	died.emit()
