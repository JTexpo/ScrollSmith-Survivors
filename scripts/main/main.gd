class_name Main
extends Node2D
## Wires the main scene together: health and spell bars to the player, death screen to player death.

## DEBUG: the scrolls F10 hands out (3 of each). Delete with the debug key.
@export var debug_scrolls: Array[ScrollData] = []

@onready var _player: Player = $Player
@onready var _death_screen: DeathScreen = $DeathScreen
@onready var _health_bar: HealthBar = $Hud/HealthBar
@onready var _spell_bar: SpellBar = $Hud/SpellBar
@onready var _reticle: TargetReticle = $TargetReticle
@onready var _spawner: EnemySpawner = $EnemySpawner
@onready var _damage_numbers: DamageNumbers = $DamageNumbers
@onready var _dropper: ScrollDropper = $ScrollDropper
@onready var _toast: ScrollToast = $Hud/ScrollToast
@onready var _inventory_panel: InventoryPanel = $Hud/InventoryPanel
@onready var _inventory_button: InventoryButton = $Hud/InventoryButton
@onready var _interact_button: InteractButton = $Hud/InteractButton
@onready var _crafting_screen: CraftingScreen = $CraftingScreen
@onready var _xp_dropper: ValueDropper = $XpDropper
@onready var _gold_dropper: ValueDropper = $GoldDropper
@onready var _saver: ProfileSaver = $ProfileSaver
@onready var _pick_screen: BuffPickScreen = $BuffPickScreen
@onready var _xp_bar: XpBar = $Hud/XpBar
@onready var _level_toast: LevelToast = $Hud/LevelToast
@onready var _gold_counter: GoldCounter = $Hud/GoldCounter
@onready var _shop_screen: ShopScreen = $ShopScreen
@onready var _potion_bar: PotionBar = $Hud/PotionBar
@onready var _director: RunDirector = $RunDirector

## Where the profile is saved. Empty means "do not load or save": tests set it before adding Main to
## the tree so they never touch the player's real save.
@export var save_path: String = SaveGame.DEFAULT_PATH

var profile: PlayerProfile
var track: LevelTrack
var catalog: EquipmentCatalog
var potion_catalog: PotionCatalog

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameTime.reset()
	RunClock.reset()
	_health_bar.bind(_player.health)
	_player.died.connect(_death_screen.show_death)
	# A hidden bar ignores touches, so a dead player can't change spell and the restart tap gets through.
	_player.died.connect(_spell_bar.hide)
	_spell_bar.bind(_player.loadout)
	_reticle.bind(_player)
	_spawner.enemy_damaged.connect(_damage_numbers.show_number)
	_spawner.enemy_died.connect(_dropper.on_enemy_died)
	_inventory_panel.bind(_player.inventory)
	_player.collector.collected.connect(_toast.show_scroll)
	_player.inventory.changed.connect(_on_inventory_changed)
	_inventory_button.set_total(_player.inventory.total_count())
	_inventory_button.pressed.connect(_toggle_inventory)
	_player.died.connect(_inventory_panel.set_open.bind(false))
	# A hidden button ignores touches, so the restart tap gets through after death.
	_player.died.connect(_inventory_button.hide)
	_spell_bar.slot_pressed.connect(_player.loadout.select)
	_player.interaction.target_changed.connect(_on_interaction_target_changed)
	_interact_button.pressed.connect(_player.interaction.try_interact.bind(_player))
	_player.died.connect(_interact_button.hide)
	for lectern in get_tree().get_nodes_in_group(&"lecterns"):
		if is_ancestor_of(lectern):
			lectern.interacted.connect(_open_crafting)
	# The click that confirmed a craft is probably still held when the world resumes.
	_crafting_screen.closed.connect(_player.require_cast_release)
	_director.xp_dropper = _xp_dropper
	_director.gold_dropper = _gold_dropper
	_director.scroll_dropper = _dropper
	_begin_progression()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory"):
		_toggle_inventory()
	# DEBUG: refills every spell's mana. Delete once potions exist.
	elif event.is_action_pressed(&"debug_restore_mana"):
		_player.loadout.restore_all_mana()
	# DEBUG: 3 of every scroll, to try the panel and crafting without grinding. Delete later.
	elif event.is_action_pressed(&"debug_give_scrolls"):
		for scroll in debug_scrolls:
			_player.inventory.add(scroll, 3)
	# DEBUG: 3 of every potion, saved, until potions are found another way. Delete later.
	elif event.is_action_pressed(&"debug_give_potions"):
		for potion in potion_catalog.potions:
			profile.add_potion(potion.id, 3)
		_player.belt.refresh()
		_saver.save_now()
	# DEBUG: 100 XP, to try levels without grinding. It is saved like real XP. Delete later.
	elif event.is_action_pressed(&"debug_give_xp"):
		_player.progress.add_xp(100)


## Loads the profile, wires XP and saving, rolls the random starting buffs, asks for each owed chosen
## buff, then sets the run up. Nothing about the buffs is saved: this happens at every run start. With
## nothing to ask it finishes straight away. With a pick owed it waits on the pick screen (the world
## is paused meanwhile), so the run starts with the choice already applied.
func _begin_progression() -> void:
	_rng.randomize()
	track = LevelTrack.default_track()
	catalog = EquipmentCatalog.default_catalog()
	potion_catalog = PotionCatalog.default_catalog()
	profile = SaveGame.load_profile(save_path) if not save_path.is_empty() else PlayerProfile.new()
	var progress := _player.progress
	progress.bind(_player, profile, track)
	_player.belt.bind(_player, profile, potion_catalog)
	_player.belt.used.connect(_on_potion_used)
	_player.belt.refused.connect(_level_toast.show_message)
	_potion_bar.bind(_player.belt, _player.effects, potion_catalog)
	_potion_bar.slot_pressed.connect(_on_potion_slot_pressed)
	_player.died.connect(_potion_bar.hide)
	_saver.bind(profile, save_path)
	_xp_bar.bind(progress)
	_gold_counter.bind(progress)
	_player.bonuses_changed.connect(_on_bonuses_changed)
	_player.collector.xp_collected.connect(progress.add_xp)
	_player.collector.gold_collected.connect(progress.add_gold)
	_spawner.enemy_died.connect(_xp_dropper.on_enemy_died)
	_spawner.enemy_died.connect(_gold_dropper.on_enemy_died)
	progress.xp_changed.connect(_on_xp_changed)
	progress.gold_changed.connect(_on_gold_changed)
	progress.leveled_up.connect(_on_leveled_up)
	_player.died.connect(_on_player_died)
	_death_screen.shop_requested.connect(_on_shop_requested)
	_shop_screen.changed.connect(_saver.save_now)
	_shop_screen.closed.connect(_death_screen.set_shop_open.bind(false))
	var run_buffs := RunBuffs.new()
	var level := profile.level(track)
	var rolled := StartingBuffs.roll_random(run_buffs, track, level, _rng)
	for reward_level in StartingBuffs.unresolved_levels(run_buffs, track, level, LevelReward.Kind.CHOSEN_BUFF):
		var options := StartingBuffs.options_for(run_buffs, track, reward_level)
		if options.is_empty():
			continue
		_pick_screen.open(options, "Level %d: choose a buff for your starting spell" % reward_level)
		var picked: ScrollData = await _pick_screen.chosen
		run_buffs.set_pick(reward_level, picked.id)
	RunStart.prepare(_player, profile, track, run_buffs, catalog)
	for reward_level in rolled:
		_level_toast.show_message(_rolled_notice(run_buffs, reward_level))


func _on_xp_changed(_total_xp: int, _level: int) -> void:
	_saver.mark_dirty()


func _on_bonuses_changed(total: StatBonuses) -> void:
	_dropper.luck = total.fraction(StatBonuses.Stat.LUCK)


## A tap or click on a potion slot. The click that drinks must not also cast a spell, so casting waits
## until the cast input has been released.
func _on_potion_slot_pressed(index: int) -> void:
	_player.belt.use_slot(index)
	_player.require_cast_release()


## A drunk potion is saved at once, so quitting cannot refund it.
func _on_potion_used(_potion: PotionData) -> void:
	_saver.save_now()


func _on_gold_changed(_total_gold: int) -> void:
	_saver.mark_dirty()


func _on_leveled_up(level: int, reward: LevelReward) -> void:
	_level_toast.show_level_up(level, reward)
	_saver.save_now()


## "Starting spell gains Increased Damage": what a random reward rolled for this run.
func _rolled_notice(run_buffs: RunBuffs, reward_level: int) -> String:
	var reward := track.reward_for_level(reward_level)
	var scroll := StartingBuffs.find_scroll(track, run_buffs.pick(reward_level))
	var spell_name := "Starting spell" if reward.spell_index == 0 else "Second spell"
	return "%s gains %s" % [spell_name, scroll.display_name if scroll != null else "a buff"]


func _on_shop_requested() -> void:
	_shop_screen.open(profile, catalog, potion_catalog)


func _on_player_died() -> void:
	_death_screen.set_run_summary(_player.progress.run_xp, _player.progress.level(), _player.progress.run_gold)
	_saver.save_now()


func _toggle_inventory() -> void:
	if _player.health.is_dead():
		return
	_inventory_panel.toggle()


func _open_crafting(_actor: Node) -> void:
	if _player.health.is_dead() or _crafting_screen.is_open():
		return
	_crafting_screen.open(_player.inventory, _player.loadout)


func _on_interaction_target_changed(target: Node) -> void:
	_interact_button.set_available(target != null)


func _on_inventory_changed(_scroll: ScrollData) -> void:
	_inventory_button.set_total(_player.inventory.total_count())
