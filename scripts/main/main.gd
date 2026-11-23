class_name Main
extends Node2D
## Wires the main scene together: health and spell bars to the player, death screen to player death.

## A point of interest's effect was applied (not refused), or a merchant's stall opened. The sound board listens.
signal point_effect_applied(kind: int)

## DEBUG: the scrolls F10 hands out (3 of each). Delete with the debug key.
@export var debug_scrolls: Array[ScrollData] = []

@onready var _player: Player = $Player
@onready var _map: GameMap = $GameMap
@onready var _camera: Camera2D = $Player/Camera2D
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
@onready var _merchant_screen: MerchantScreen = $MerchantScreen
@onready var _potion_bar: PotionBar = $Hud/PotionBar
@onready var _director: RunDirector = $RunDirector
@onready var _boss_bar: BossBar = $Hud/BossBar
@onready var _mute_button: MuteButton = $Hud/MuteButton
@onready var _board: SoundBoard = $SoundBoard
@onready var _fx: FxDirector = $FxDirector
@onready var _warning: LowHealthWarning = $LowHealthWarning

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
	_apply_map()
	_health_bar.bind(_player.health)
	_warning.bind(_player.health)
	_warning.beat.connect(func(_level: int) -> void: _health_bar.beat())
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
	for point in get_tree().get_nodes_in_group(&"points_of_interest"):
		if is_ancestor_of(point):
			connect_point_of_interest(point)
	_merchant_screen.changed.connect(_on_merchant_purchase)
	_merchant_screen.closed.connect(_player.require_cast_release)
	_director.xp_dropper = _xp_dropper
	_director.gold_dropper = _gold_dropper
	_director.scroll_dropper = _dropper
	_boss_bar.bind(_director)
	_director.boss_spawned.connect(_on_boss_spawned)
	_director.boss_defeated.connect(_on_boss_defeated)
	_begin_progression()
	_board.bind(self)
	_fx.bind(self)
	_board.mute_changed.connect(_mute_button.set_muted)
	_mute_button.pressed.connect(_on_mute_button_pressed)
	_player.died.connect(_mute_button.hide)
	if profile.muted:
		_board.set_muted(true)
	_board.mute_changed.connect(_on_mute_changed)
	_board.start_if_allowed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory"):
		_toggle_inventory()
	# DEBUG: shows the map's bounds and placements. Delete when no longer needed.
	elif event.is_action_pressed(&"debug_toggle_map"):
		_map.toggle_debug()
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


## Hands the map's size to the spawner and camera, its spawn config to the spawner (when it has one)
## and its start to the player. Nothing else reads the arena size.
func _apply_map() -> void:
	var area := _map.bounds()
	_spawner.arena_bounds = area
	if _map.map_data != null and _map.map_data.spawn_config != null:
		_spawner.config = _map.map_data.spawn_config
	_player.global_position = _map.player_start()
	_camera.limit_left = int(area.position.x)
	_camera.limit_top = int(area.position.y)
	_camera.limit_right = int(area.end.x)
	_camera.limit_bottom = int(area.end.y)
	# The player entered the tree at (0, 0), so without this the smoothed camera glides in from the corner.
	_camera.reset_smoothing()


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


## Listens for a point of interest being used. Called for every point under Main when it starts, and by anything
## that adds one later.
func connect_point_of_interest(point: PointOfInterest) -> void:
	if not point.used.is_connected(_on_point_used):
		point.used.connect(_on_point_used)


## Routes the use of a point of interest. A refusal only shows its reason (nothing is consumed and no timer
## starts). A merchant opens its screen. Anything else is applied by the rules, its Gold is added, its scrolls are
## dropped beside it and its timer starts.
func _on_point_used(point: PointOfInterest, _actor: Node) -> void:
	if _player.health.is_dead():
		return
	if point.data.kind == PointOfInterestData.Kind.MERCHANT:
		if not _merchant_screen.is_open():
			_merchant_screen.open(profile, potion_catalog, point)
			point_effect_applied.emit(point.data.kind)
		return
	var reason := PointOfInterestSystem.refusal(point.data, _player, point.cooldown_left)
	if not reason.is_empty():
		_level_toast.show_message(reason)
		return
	var result := PointOfInterestSystem.apply(point.data, _player, _rng, _dropper.luck)
	if result.gold > 0:
		_player.progress.add_gold(result.gold)
	for i in result.scrolls.size():
		_dropper.place(result.scrolls[i], point.loot_spot(i, result.scrolls.size()))
	if not result.message.is_empty():
		_level_toast.show_message(result.message)
	point.start_cooldown()
	point_effect_applied.emit(point.data.kind)


## A potion bought from a merchant is saved at once, so quitting cannot undo the sale. The sale spent Gold on the
## profile directly, so the HUD is told too.
func _on_merchant_purchase() -> void:
	_player.belt.refresh()
	_player.progress.announce_gold()
	_saver.save_now()


## A drunk potion is saved at once, so quitting cannot refund it.
func _on_potion_used(_potion: PotionData) -> void:
	_saver.save_now()


## The board mutes or unmutes (its M key, or the button below) and tells the HUD button; the choice is saved here.
func _on_mute_changed(value: bool) -> void:
	profile.muted = value
	_saver.save_now()


## A click on the button must not also fire a spell, so casting waits for the click to be released.
func _on_mute_button_pressed() -> void:
	_board.set_muted(not _board.muted)
	_player.require_cast_release()


func _on_boss_spawned(boss: Boss, _number: int) -> void:
	_level_toast.show_message("The %s approaches!" % boss.data.display_name)


func _on_boss_defeated(_number: int) -> void:
	_level_toast.show_message("Boss defeated!")


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
	_death_screen.set_run_summary(_player.progress.run_xp, _player.progress.level(), _player.progress.run_gold, RunClock.seconds())
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
