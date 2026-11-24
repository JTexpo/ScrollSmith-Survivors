class_name HomeScreen
extends Control
## The home screen, the first thing the game shows: Play, Shop, Tutorial, Settings and New game. It
## loads the progress save itself and owns the Shop and New game flows, so none of that needs a run. The run scene is not created until
## Play loads it (through SceneSwitcher), so no run, buff pick or crowd exists behind this screen. Touches are handled here because
## mouse emulation from touch is off.

const BUTTON_SIZE := Vector2(120, 28)
const FIRST_BUTTON_Y := 100.0
const BUTTON_STEP := 32.0
const ERASE_QUESTION := "Your XP, Gold and equipment will be erased. Your settings are kept."
const SURE_QUESTION := "This cannot be undone. Start over from level 1?"

var save_path: String = SaveGame.DEFAULT_PATH
var settings_path: String = SettingsStore.DEFAULT_PATH
var run_scene_path: String = Scenes.RUN
var profile: PlayerProfile

var _buttons: Dictionary = {}
var _message: Label
var _step: int = 0

@onready var _shop: ShopScreen = $ShopScreen
@onready var _settings: SettingsScreen = $SettingsScreen
@onready var _confirm: ConfirmDialog = $ConfirmDialog
@onready var _tutorial: TutorialScreen = $TutorialScreen


func _ready() -> void:
	SettingsStore.apply_saved(settings_path)
	ScreenMode.apply_saved()
	profile = SaveGame.load_profile(save_path)
	_build()
	_shop.changed.connect(_save_profile)
	_shop.closed.connect(_focus_play)
	_settings.settings_path = settings_path
	_settings.closed.connect(_focus_play)
	_tutorial.closed.connect(_focus_play)
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
	if not event is InputEventScreenTouch or _shop.is_open() or _settings.is_open() or _confirm.is_open() or _tutorial.is_open():
		return false
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


## Starts a run: loads the run scene. The error is returned so a missing scene is visible.
func play() -> Error:
	return SceneSwitcher.change_to(get_tree(), run_scene_path)


func open_shop() -> void:
	_shop.open(profile, EquipmentCatalog.default_catalog())


func open_tutorial() -> void:
	_tutorial.open()


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
		_focus_play()


func _on_cancelled() -> void:
	_step = 0
	_focus_play()


func _toggle_fullscreen() -> void:
	GameSettings.fullscreen = ScreenMode.toggle()
	SettingsStore.save_file(settings_path)


func _save_profile() -> void:
	SaveGame.save_profile(profile, save_path)


func _focus_play() -> void:
	if _buttons.has("Play") and is_inside_tree():
		(_buttons["Play"] as Button).grab_focus()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = UiKit.BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var title := UiKit.label("ScrollSmith Survivors", &"Heading")
	title.position = Vector2(0, 14)
	title.size = Vector2(480, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var wizard := BodyView.new()
	wizard.position = Vector2(240, 66)
	wizard.shadow_enabled = true
	add_child(wizard)
	wizard.set_look(&"player", &"base")
	wizard.play(&"idle")
	_message = UiKit.label("", &"Muted")
	_message.position = Vector2(0, 86)
	_message.size = Vector2(480, 12)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)
	var index := 0
	for entry in [["Play", &"ButtonGreen"], ["Shop", &""], ["Tutorial", &""], ["Settings", &""], ["New game", &"ButtonRed"]]:
		var button := UiKit.button(entry[0], entry[1])
		button.position = Vector2((480.0 - BUTTON_SIZE.x) / 2.0, FIRST_BUTTON_Y + index * BUTTON_STEP)
		button.custom_minimum_size = BUTTON_SIZE
		add_child(button)
		_buttons[entry[0]] = button
		index += 1
	(_buttons["Play"] as Button).pressed.connect(play)
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
