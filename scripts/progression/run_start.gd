class_name RunStart
extends RefCounted
## Sets a run up from the saved profile: the stat bonuses, the unlocked slots and the starting spells
## with the buffs their rewards gave. It never rolls or asks for a pick (Main does that first), and
## running it again gives the same state, so a restart can never apply a bonus twice.


static func prepare(player: Player, profile: PlayerProfile, track: LevelTrack, run_buffs: RunBuffs, catalog: EquipmentCatalog) -> void:
	var level := profile.level(track)
	# The level and equipment layers first (the temporary layer is left as it is), so every spell
	# equipped below starts with the mana bonus and the casting speed.
	player.level_bonuses = StatBonuses.for_level(track, level)
	player.equipment_bonuses = ShopSystem.bonuses(profile, catalog)
	player.refresh_bonuses(false)
	# The wizard wears what is equipped (and the starter robe and hat where nothing is).
	var body := player.get_node_or_null("Body") as BodyView
	# Only a layered wizard (Player._ready adds the layers when the bare body has art): with no art the single original sprite
	# or the fallback square stays as it is, and no robe or hood floats over it.
	if body != null and not body.layer_names().is_empty():
		PlayerLook.apply(body, profile, catalog)
	var loadout := player.loadout
	loadout.set_unlocked_slots(track.slot_count(level))
	if not loadout.starting_spells.is_empty():
		_equip(loadout, 0, loadout.starting_spells[0], StartingBuffs.buffs_for_spell(run_buffs, track, level, 0))
	for reached in range(2, mini(level, track.max_level()) + 1):
		var reward := track.reward_for_level(reached)
		if reward.kind == LevelReward.Kind.SECOND_SPELL:
			_equip(loadout, 1, reward.spell, StartingBuffs.buffs_for_spell(run_buffs, track, level, 1))


static func _equip(loadout: SpellLoadout, slot: int, spell: SpellData, buffs: Array[ScrollData]) -> void:
	var built := SpellBuilder.with_buffs(spell, buffs)
	if built != null:
		loadout.equip(slot, built)
