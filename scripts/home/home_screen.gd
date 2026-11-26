class_name HomeScreen
extends Control
## The home screen, the first thing the game shows: Play (which opens the map select), Shop, Tutorial, Settings and New game. It
## loads the progress save itself and owns the Shop and New game flows, so none of that needs a run. The run scene is not created until
## Play loads it (through SceneSwitcher), so no run, buff pick or crowd exists behind this screen. Touches are handled here because
## mouse emulation from touch is off.

## The layout (480 by 270): the title banner on top between the two corner buttons, the animated stage in the middle and the five buttons in
## one row at the bottom. The "Starting over." message sits in the gap between the stage and the buttons.
const BANNER_RECT := Rect2(112, 6, 256, 46)
const STAGE_RECT := Rect2(0, 58, 480, 160)
const MESSAGE_RECT := Rect2(0, 220, 480, 10)
const BUTTON_SIZE := Vector2(88, 28)
const BUTTON_GAP := 4.0
const BUTTONS_Y := 232.0
const HOME_SCRIPT := "res://resources/stage/home_fight.tres"
const ROW_COUNT := 5
const ERASE_QUESTION := "Your XP, Gold and equipment will be erased. Your settings are kept."
const SURE_QUESTION := "This cannot be undone. Start over from level 1?"

var save_path: String = SaveGame.DEFAULT_PATH
var settings_path: String = SettingsStore.DEFAULT_PATH
var profile: PlayerProfile
## How a scene is loaded: `func(path: String) -> Error`. Empty uses `SceneSwitcher`. A test sets it so it never really changes scene.
var scene_changer: Callable = Callable()

var _buttons: Dictionary = {}
var _stage: Stage
## The stage is stopped while a full screen covers it (no work behind a screen nobody can see through).
var _stage_covered: bool = false
var _message: Label
var _step: int = 0

@onready var _shop: ShopScreen = $ShopScreen
@onready var _settings: SettingsScreen = $SettingsScreen
@onready var _confirm: ConfirmDialog = $ConfirmDialog
@onready var _tutorial: TutorialScreen = $TutorialScreen
@onready var _map_select: MapSelectScreen = $MapSelectScreen
@onready var _achievements: AchievementsScreen = $AchievementsScreen


func _ready() -> void:
	SettingsStore.apply_saved(settings_path)
	ScreenMode.apply_saved()
	profile = SaveGame.load_profile(save_path)
	_build()
	_shop.changed.connect(_save_profile)
	_shop.changed.connect(_dress_wizard)
	_shop.closed.connect(_focus_play)
	_settings.settings_path = settings_path
	_settings.closed.connect(_focus_play)
	_tutorial.closed.connect(_focus_play)
	_map_select.closed.connect(_focus_play)
	_achievements.closed.connect(_focus_play)
	_map_select.map_chosen.connect(play_map)
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(_on_cancelled)
	_focus_play()


func _input(event: InputEvent) -> void:
	# Taken before handling: a bridged tap on Play changes the scene, which takes this node out of the tree (no viewport) before we return.
	var viewport := get_viewport()
	if handle_input(event):
		viewport.set_input_as_handled()


## Turns a touch into the left mouse press or release the buttons expect, unless a screen on top is open (it bridges its own).
func handle_input(event: InputEvent) -> bool:
	if not event is InputEventScreenTouch or _shop.is_open() or _settings.is_open() or _confirm.is_open() or _tutorial.is_open() or _map_select.is_open() or _achievements.is_open():
		return false
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


## Opens the map select (the Play button). It focuses the map played last.
func open_map_select() -> void:
	_map_select.open(profile, MapCatalog.default_catalog(), GameSettings.last_map)


## Starts a run on the chosen map: remembers it (saved in the settings file) and loads the entry's run scene. The error is returned so a
## missing scene is visible, and a failed start remembers and changes nothing. The home screen never names a scene: the catalog does.
func play_map(entry: MapEntry) -> Error:
	if entry == null or entry.map == null or entry.scene_path.is_empty() or not ResourceLoader.exists(entry.scene_path):
		return ERR_FILE_NOT_FOUND
	GameSettings.last_map = entry.map.id
	SettingsStore.save_file(settings_path)
	if scene_changer.is_valid():
		return scene_changer.call(entry.scene_path)
	return SceneSwitcher.change_to(get_tree(), entry.scene_path)


func open_shop() -> void:
	_shop.open(profile, EquipmentCatalog.default_catalog())


func open_tutorial() -> void:
	_tutorial.open()


func open_achievements() -> void:
	_achievements.open(AchievementCatalog.default_catalog(), profile, LevelTrack.default_track())


func achievements_screen() -> AchievementsScreen:
	return _achievements


func map_select_screen() -> MapSelectScreen:
	return _map_select


func tutorial_screen() -> TutorialScreen:
	return _tutorial


func open_settings() -> void:
	_settings.open()


## Asks twice before anything is erased (the first question names what goes, the second says it cannot be undone).
func new_game() -> void:
	_step = 1
	_confirm.ask("Erase all progress?", ERASE_QUESTION, "Erase")


func message_text() -> String:
	return _message.text


func shop_screen() -> ShopScreen:
	return _shop


func settings_screen() -> SettingsScreen:
	return _settings


func confirm_dialog() -> ConfirmDialog:
	return _confirm


func _on_confirmed() -> void:
	if _step == 1:
		_step = 2
		_confirm.ask("Are you sure?", SURE_QUESTION, "Yes, start over")
	elif _step == 2:
		_step = 0
		SaveGame.erase(save_path)
		profile = SaveGame.load_profile(save_path)
		_message.text = "Starting over."
		_dress_wizard()
		_focus_play()


func _on_cancelled() -> void:
	_step = 0
	_focus_play()


func _toggle_fullscreen() -> void:
	GameSettings.fullscreen = ScreenMode.toggle()
	SettingsStore.save_file(settings_path)


func _save_profile() -> void:
	SaveGame.save_profile(profile, save_path)


func _process(_delta: float) -> void:
	sync_stage()


## Stops the stage when a full screen covers the home screen and lets it run again when that screen closes.
func sync_stage() -> void:
	var covered := _any_screen_open()
	if covered == _stage_covered:
		return
	_stage_covered = covered
	if covered:
		_stage.stop()
	else:
		_stage.resume()


func stage() -> Stage:
	return _stage


func message_rect() -> Rect2:
	return _message.get_global_rect()


func _any_screen_open() -> bool:
	return _shop.is_open() or _settings.is_open() or _confirm.is_open() or _tutorial.is_open() or _map_select.is_open() or _achievements.is_open()


func _dress_wizard() -> void:
	_stage.dress_wizard(profile, EquipmentCatalog.default_catalog())


func _focus_play() -> void:
	if _buttons.has("Play") and is_inside_tree():
		(_buttons["Play"] as Button).grab_focus()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = UiKit.BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var banner := BodyView.new()
	banner.name = "Banner"
	banner.position = BANNER_RECT.get_center()
	add_child(banner)
	if banner.set_look(&"banner_title"):
		banner.play(&"shimmer")
	_stage = Stage.new()
	_stage.name = "Stage"
	_stage.position = STAGE_RECT.position
	add_child(_stage)
	_stage.play(load(HOME_SCRIPT) as StageScript, profile, EquipmentCatalog.default_catalog())
	_message = UiKit.label("", &"Muted")
	_message.position = MESSAGE_RECT.position
	_message.size = MESSAGE_RECT.size
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)
	var row_width := ROW_COUNT * BUTTON_SIZE.x + (ROW_COUNT - 1) * BUTTON_GAP
	var index := 0
	for entry in [["Play", &"ButtonGreen"], ["Shop", &""], ["Tutorial", &""], ["Settings", &""], ["New game", &"ButtonRed"]]:
		var button := UiKit.button(entry[0], entry[1])
		button.position = Vector2((480.0 - row_width) / 2.0 + index * (BUTTON_SIZE.x + BUTTON_GAP), BUTTONS_Y)
		button.custom_minimum_size = BUTTON_SIZE
		add_child(button)
		_buttons[entry[0]] = button
		index += 1
	(_buttons["Play"] as Button).pressed.connect(open_map_select)
	(_buttons["Shop"] as Button).pressed.connect(open_shop)
	(_buttons["Settings"] as Button).pressed.connect(open_settings)
	(_buttons["New game"] as Button).pressed.connect(new_game)
	(_buttons["Tutorial"] as Button).pressed.connect(open_tutorial)
	# A phone player taps this to fill the screen (a browser allows full screen only from a tap).
	var fullscreen := UiKit.button("Full screen")
	fullscreen.position = Vector2(480.0 - 92.0, 8.0)
	fullscreen.custom_minimum_size = Vector2(84, 28)
	fullscreen.pressed.connect(_toggle_fullscreen)
	add_child(fullscreen)
	_buttons["Full screen"] = fullscreen
	# The mirror of Full screen, at the top left: the five main buttons already fill the screen's height.
	var achievements := UiKit.button("Achievements")
	achievements.position = Vector2(8.0, 8.0)
	achievements.custom_minimum_size = Vector2(100, 28)
	achievements.pressed.connect(open_achievements)
	add_child(achievements)
	_buttons["Achievements"] = achievements
