extends GutTest

var _root: Node2D
var _player: Player
var _profile: PlayerProfile
var _catalog: PotionCatalog


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_profile = PlayerProfile.new()
	_catalog = PotionCatalog.default_catalog()


func _potion(id: StringName) -> PotionData:
	return _catalog.find(id)


func _stock(id: StringName, count: int = 1) -> void:
	_profile.add_potion(id, count)


func _refusal(id: StringName, cooldown: float = 0.0, shared: float = 0.0) -> String:
	return PotionSystem.refusal(_potion(id), _player, _profile, cooldown, shared)


func _drain_mana() -> void:
	for spell in _player.loadout.slots:
		if spell != null:
			spell.current_mana = 0.0


func test_refuses_an_unknown_potion() -> void:
	assert_eq(PotionSystem.refusal(null, _player, _profile, 0.0, 0.0), PotionSystem.REASON_UNKNOWN)


func test_refuses_when_dead() -> void:
	_stock(&"potion_health")
	_player.health.take_damage(1000.0)
	assert_eq(_refusal(&"potion_health"), PotionSystem.REASON_DEAD)


func test_refuses_when_none_left() -> void:
	_player.health.take_damage(50.0)
	assert_eq(_refusal(&"potion_health"), PotionSystem.REASON_NONE)


func test_refuses_during_the_types_cooldown() -> void:
	_stock(&"potion_health")
	_player.health.take_damage(50.0)
	assert_eq(_refusal(&"potion_health", 3.0), PotionSystem.REASON_COOLDOWN)


func test_refuses_during_the_shared_cooldown() -> void:
	_stock(&"potion_health")
	_player.health.take_damage(50.0)
	assert_eq(_refusal(&"potion_health", 0.0, 0.4), PotionSystem.REASON_SHARED)


func test_refuses_a_timed_potion_whose_effect_is_active() -> void:
	_stock(&"potion_speed")
	_player.effects.start(_potion(&"potion_speed"))
	assert_eq(_refusal(&"potion_speed"), PotionSystem.REASON_ACTIVE)


func test_refuses_health_at_full_health() -> void:
	_stock(&"potion_health")
	assert_eq(_refusal(&"potion_health"), PotionSystem.REASON_FULL_HEALTH)


func test_refuses_mana_when_every_spell_is_full() -> void:
	_stock(&"potion_mana")
	assert_eq(_refusal(&"potion_mana"), PotionSystem.REASON_FULL_MANA)


func test_mana_counts_as_full_for_a_player_with_no_spells() -> void:
	_stock(&"potion_mana")
	for i in _player.loadout.slots.size():
		_player.loadout.slots[i] = null
	assert_eq(_refusal(&"potion_mana"), PotionSystem.REASON_FULL_MANA)


func test_refusal_order_is_the_documented_one() -> void:
	# Dead beats none left, none left beats cooldown, cooldown beats shared, shared beats active/full.
	_player.health.take_damage(1000.0)
	assert_eq(_refusal(&"potion_health", 3.0, 0.4), PotionSystem.REASON_DEAD)
	var alive := load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(alive)
	assert_eq(PotionSystem.refusal(_potion(&"potion_health"), alive, _profile, 3.0, 0.4), PotionSystem.REASON_NONE)
	_stock(&"potion_health")
	assert_eq(PotionSystem.refusal(_potion(&"potion_health"), alive, _profile, 3.0, 0.4), PotionSystem.REASON_COOLDOWN)
	assert_eq(PotionSystem.refusal(_potion(&"potion_health"), alive, _profile, 0.0, 0.4), PotionSystem.REASON_SHARED)
	assert_eq(PotionSystem.refusal(_potion(&"potion_health"), alive, _profile, 0.0, 0.0), PotionSystem.REASON_FULL_HEALTH)


func test_allows_a_valid_drink() -> void:
	_stock(&"potion_health")
	_player.health.take_damage(50.0)
	assert_eq(_refusal(&"potion_health"), "")
	_stock(&"potion_mana")
	_drain_mana()
	assert_eq(_refusal(&"potion_mana"), "")
	_stock(&"potion_speed")
	assert_eq(_refusal(&"potion_speed"), "")
	_stock(&"potion_invulnerability")
	assert_eq(_refusal(&"potion_invulnerability"), "")
	_stock(&"potion_luck")
	assert_eq(_refusal(&"potion_luck"), "")


func test_health_heals_forty_percent_of_max_health_and_never_overheals() -> void:
	_player.health.take_damage(90.0)
	assert_true(PotionSystem.apply(_potion(&"potion_health"), _player))
	assert_almost_eq(_player.health.current_health, 50.0, 0.001)
	_player.health.take_damage(10.0)
	PotionSystem.apply(_potion(&"potion_health"), _player)
	assert_almost_eq(_player.health.current_health, 80.0, 0.001)
	PotionSystem.apply(_potion(&"potion_health"), _player)
	PotionSystem.apply(_potion(&"potion_health"), _player)
	assert_eq(_player.health.current_health, 100.0)


func test_health_uses_the_boosted_max_health() -> void:
	var layer := StatBonuses.new()
	layer.add(StatBonuses.Stat.HEALTH, 1.0)
	_player.level_bonuses = layer
	_player.refresh_bonuses()
	_player.health.take_damage(150.0)
	PotionSystem.apply(_potion(&"potion_health"), _player)
	assert_almost_eq(_player.health.current_health, 50.0 + 80.0, 0.001)


func test_mana_restores_half_of_each_spells_pool() -> void:
	var crafted := SpellData.new()
	crafted.max_mana = 100.0
	crafted.mana_cost = 1.0
	_player.loadout.unlocked_slots = 2
	_player.loadout.equip(1, crafted)
	_drain_mana()
	assert_true(PotionSystem.apply(_potion(&"potion_mana"), _player))
	assert_almost_eq(_player.loadout.slots[0].current_mana, 500.0, 0.001)
	assert_almost_eq(_player.loadout.slots[1].current_mana, 50.0, 0.001)
	PotionSystem.apply(_potion(&"potion_mana"), _player)
	PotionSystem.apply(_potion(&"potion_mana"), _player)
	assert_almost_eq(_player.loadout.slots[0].current_mana, 1000.0, 0.001)
	assert_almost_eq(_player.loadout.slots[1].current_mana, 100.0, 0.001)


func test_mana_uses_the_bonus_pool() -> void:
	var layer := StatBonuses.new()
	layer.add(StatBonuses.Stat.SPELL_MANA, 0.5)
	_player.level_bonuses = layer
	_player.refresh_bonuses()
	_drain_mana()
	PotionSystem.apply(_potion(&"potion_mana"), _player)
	assert_almost_eq(_player.loadout.slots[0].current_mana, 750.0, 0.001)


func test_speed_damage_and_luck_start_timed_effects() -> void:
	for id in [&"potion_speed", &"potion_damage", &"potion_luck"]:
		assert_true(PotionSystem.apply(_potion(id), _player), str(id))
		assert_true(_player.effects.is_active(id), str(id))
	assert_false(PotionSystem.apply(_potion(&"potion_speed"), _player), "already running")


func test_invulnerability_starts_the_window() -> void:
	assert_true(PotionSystem.apply(_potion(&"potion_invulnerability"), _player))
	assert_true(_player.hurtbox.is_invulnerable())
