extends GutTest

var _root: Node2D
var _player: Player
var _catalog: PotionCatalog


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_catalog = PotionCatalog.default_catalog()


func _potion(id: StringName) -> PotionData:
	return _catalog.find(id)


func _speed() -> float:
	return (_player.get_node("MoveComponent") as MoveComponent).speed


func test_starting_a_speed_potion_raises_speed_and_expiry_restores_it() -> void:
	assert_true(_player.effects.start(_potion(&"potion_speed")))
	assert_almost_eq(_speed(), 126.0, 0.001)
	_player.effects._process(15.1)
	assert_almost_eq(_speed(), 90.0, 0.001)
	assert_false(_player.effects.is_active(&"potion_speed"))


func test_expiry_never_drops_level_or_equipment_bonuses() -> void:
	var level := StatBonuses.new()
	level.add(StatBonuses.Stat.SPEED, 0.08)
	var equipment := StatBonuses.new()
	equipment.add(StatBonuses.Stat.SPEED, 0.10)
	_player.level_bonuses = level
	_player.equipment_bonuses = equipment
	_player.refresh_bonuses()
	_player.effects.start(_potion(&"potion_speed"))
	assert_almost_eq(_speed(), 90.0 * 1.58, 0.001)
	_player.effects._process(15.1)
	assert_almost_eq(_speed(), 90.0 * 1.18, 0.001)


func test_two_different_timed_potions_stack_in_the_layer() -> void:
	_player.effects.start(_potion(&"potion_speed"))
	_player.effects.start(_potion(&"potion_damage"))
	assert_almost_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.SPEED), 0.4, 0.0001)
	assert_almost_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.SPELL_DAMAGE), 0.5, 0.0001)
	_player.effects._process(15.1)
	assert_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.SPEED), 0.0)
	assert_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.SPELL_DAMAGE), 0.0)


func test_one_expiring_leaves_the_other_running() -> void:
	_player.effects.start(_potion(&"potion_speed"))
	_player.effects.start(_potion(&"potion_luck"))
	_player.effects._process(16.0)
	assert_false(_player.effects.is_active(&"potion_speed"))
	assert_true(_player.effects.is_active(&"potion_luck"))
	assert_almost_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.LUCK), 1.0, 0.0001)
	assert_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.SPEED), 0.0)


func test_starting_an_active_potion_again_is_refused_and_changes_nothing() -> void:
	_player.effects.start(_potion(&"potion_speed"))
	_player.effects._process(5.0)
	var left := _player.effects.time_left(&"potion_speed")
	assert_false(_player.effects.start(_potion(&"potion_speed")))
	assert_almost_eq(_player.effects.time_left(&"potion_speed"), left, 0.0001)
	assert_almost_eq(_speed(), 126.0, 0.001)


func test_instant_potions_are_not_timed_effects() -> void:
	assert_false(_player.effects.start(_potion(&"potion_health")))
	assert_false(_player.effects.start(_potion(&"potion_mana")))
	assert_false(_player.effects.is_active(&"potion_health"))


func test_changed_is_emitted_on_start_and_on_expiry() -> void:
	watch_signals(_player.effects)
	_player.effects.start(_potion(&"potion_speed"))
	assert_signal_emit_count(_player.effects, "changed", 1)
	_player.effects._process(15.1)
	assert_signal_emit_count(_player.effects, "changed", 2)


func test_time_left_and_ratio_count_down() -> void:
	_player.effects.start(_potion(&"potion_speed"))
	assert_almost_eq(_player.effects.time_left(&"potion_speed"), 15.0, 0.0001)
	assert_almost_eq(_player.effects.ratio(&"potion_speed"), 1.0, 0.0001)
	_player.effects._process(7.5)
	assert_almost_eq(_player.effects.ratio(&"potion_speed"), 0.5, 0.0001)
	assert_eq(_player.effects.ratio(&"potion_luck"), 0.0)
	assert_eq(_player.effects.time_left(&"potion_luck"), 0.0)


func test_damage_potion_reaches_the_loadouts_bonuses() -> void:
	_player.effects.start(_potion(&"potion_damage"))
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.SPELL_DAMAGE), 0.5, 0.0001)
	_player.effects._process(15.1)
	assert_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.SPELL_DAMAGE), 0.0)


func test_luck_potion_reaches_bonuses_changed() -> void:
	watch_signals(_player)
	_player.effects.start(_potion(&"potion_luck"))
	var total := get_signal_parameters(_player, "bonuses_changed")[0] as StatBonuses
	assert_almost_eq(total.fraction(StatBonuses.Stat.LUCK), 1.0, 0.0001)


func test_invulnerability_potion_blocks_hits_and_runs_for_its_duration() -> void:
	_player.effects.start(_potion(&"potion_invulnerability"))
	assert_true(_player.effects.is_active(&"potion_invulnerability"))
	var hurtbox := _player.get_node("HurtboxComponent") as HurtboxComponent
	assert_false(hurtbox.receive_hit(30.0, Vector2.ZERO))
	assert_eq(_player.health.current_health, 100.0)
	hurtbox._process(4.99)
	_player.effects._process(4.99)
	assert_false(hurtbox.receive_hit(30.0, Vector2.ZERO))
	hurtbox._process(0.02)
	_player.effects._process(0.02)
	assert_false(_player.effects.is_active(&"potion_invulnerability"))
	assert_true(hurtbox.receive_hit(30.0, Vector2.ZERO))
	assert_eq(_player.health.current_health, 70.0)


func test_effects_are_not_carried_into_a_new_player() -> void:
	_player.effects.start(_potion(&"potion_speed"))
	var fresh := load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(fresh)
	assert_false(fresh.effects.is_active(&"potion_speed"))
	assert_eq(fresh.temporary_bonuses.fraction(StatBonuses.Stat.SPEED), 0.0)


func test_clear_removes_everything_and_refreshes() -> void:
	_player.effects.start(_potion(&"potion_speed"))
	_player.effects.start(_potion(&"potion_damage"))
	watch_signals(_player.effects)
	_player.effects.clear()
	assert_false(_player.effects.is_active(&"potion_speed"))
	assert_almost_eq(_speed(), 90.0, 0.001)
	assert_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.SPELL_DAMAGE), 0.0)
	assert_signal_emit_count(_player.effects, "changed", 1)


func test_effect_timers_use_a_pausable_process_mode() -> void:
	var holder := Node.new()
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child_autofree(holder)
	var effects := ActiveEffects.new()
	holder.add_child(effects)
	get_tree().paused = true
	var processes_while_paused := effects.can_process()
	get_tree().paused = false
	assert_false(processes_while_paused)
	assert_true(effects.can_process())


func test_the_effects_node_only_processes_while_something_runs() -> void:
	assert_false(_player.effects.is_processing())
	_player.effects.start(_potion(&"potion_speed"))
	assert_true(_player.effects.is_processing())
	_player.effects._process(15.1)
	assert_false(_player.effects.is_processing())
