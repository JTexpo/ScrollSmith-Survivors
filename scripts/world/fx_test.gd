class_name FxTest
extends Control
## A developer tool, not part of the game: fire light, medium and heavy impacts of every element, set the wizard's health to see the
## low-health warning, take a hit from any side, trigger the pickup, level-up, Rare drop and blast effects, and set every effect switch
## and scale, so the effects can be judged and tuned by feel. It uses the same parts and the same announcements as the game.
## The settings it changes are put back when the scene closes. Run it with `godot --path . res://scenes/world/fx_test.tscn`.

const LIGHT := 0.1
const MEDIUM := 0.5
const HEAVY := 1.0
const LEFT := Vector2.LEFT
const RIGHT := Vector2.RIGHT
const TOP := Vector2.UP
const BOTTOM := Vector2.DOWN

const SCREEN := Vector2(480, 270)
## Where the impacts land and where the wizard stands: clear of the buttons.
const IMPACT_AT := Vector2(50, 170)
const WIZARD_AT := Vector2(120, 205)
const GRASS := Color("8fd36b")
const ELEMENTS := [&"fire", &"thunder", &"land", &"sea"]
const WEIGHTS := {"Light": LIGHT, "Med": MEDIUM, "Heavy": HEAVY}
const BUTTON_HEIGHT := 22.0
const MAX_HEALTH := 100.0

var _director: FxDirector
var _burst: BurstLayer
var _flash: ScreenFlash
var _shake: CameraShake
var _warning: LowHealthWarning
var _indicator: HitIndicator
var _health: HealthComponent
var _health_bar: HealthBar
var _wizard: BodyView
var _stand_in: Node2D
var _info: Label
var _health_label: Label
var _impact_buttons: Array[Button] = []
var _switches: Dictionary = {}
var _last_weight: float = 0.0
var _saved_settings: Dictionary = {}


func _ready() -> void:
	_saved_settings = FxSettings.to_dict()
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	var camera := Camera2D.new()
	camera.position = SCREEN / 2.0
	world.add_child(camera)
	var floor_rect := ColorRect.new()
	floor_rect.color = GRASS
	floor_rect.size = SCREEN * 2.0
	floor_rect.position = -SCREEN / 2.0
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(floor_rect)
	_stand_in = Node2D.new()
	_stand_in.position = WIZARD_AT
	world.add_child(_stand_in)
	_wizard = BodyView.new()
	_wizard.shadow_enabled = true
	_stand_in.add_child(_wizard)
	_wizard.set_look(&"player", &"base")
	_wizard.play(&"idle")
	_burst = BurstLayer.new()
	world.add_child(_burst)
	_health = HealthComponent.new()
	_health.max_health = MAX_HEALTH
	add_child(_health)
	_shake = CameraShake.new()
	add_child(_shake)
	_shake.bind(camera)
	_flash = ScreenFlash.new()
	add_child(_flash)
	_indicator = HitIndicator.new()
	add_child(_indicator)
	_warning = LowHealthWarning.new()
	add_child(_warning)
	_warning.bind(_health)
	_director = FxDirector.new()
	add_child(_director)
	_director.setup(_burst, _shake, _flash)
	_director.setup_world(_stand_in)
	_director.setup_player(_wizard, _indicator)
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_build_ui(ui)
	_warning.beat.connect(_on_beat)


func _process(_delta: float) -> void:
	_info.text = "weight %.2f  trauma %.2f  particles %d  warning %d" % [_last_weight, _shake.trauma(), _burst.active_count(), _warning.level()]


func _exit_tree() -> void:
	FxSettings.apply(_saved_settings)


func director() -> FxDirector:
	return _director


func burst_layer() -> BurstLayer:
	return _burst


func warning() -> LowHealthWarning:
	return _warning


func indicator() -> HitIndicator:
	return _indicator


func impact_button_count() -> int:
	return _impact_buttons.size()


func switch_count() -> int:
	return _switches.size()


func last_weight() -> float:
	return _last_weight


## The same announcement a spell's hit makes.
func press_impact(element_id: StringName, weight: float) -> void:
	_last_weight = weight
	ImpactEvents.bus.hit.emit(IMPACT_AT, weight, element_id)


## A hit on the wizard from the side `direction` points to.
func hit_from(direction: Vector2) -> void:
	_director.on_player_hit(WIZARD_AT, WIZARD_AT + direction * 200.0)


## One of the light touches: pickup, level_up, rare_drop or blast.
func press_action(action: StringName) -> void:
	match action:
		&"pickup":
			_director.on_xp_collected()
		&"level_up":
			_director.on_level_up()
		&"rare_drop":
			var rare := ScrollData.new()
			rare.rarity = ScrollData.Rarity.RARE
			_director.on_scroll_placed(rare, IMPACT_AT)
		&"blast":
			EnemyAttackEvents.bus.blast_detonated.emit(IMPACT_AT)


## Sets the stand-in wizard's health, dead or alive, so the warning can be seen at any level.
func set_health_percent(percent: float) -> void:
	_health.set_max_health(MAX_HEALTH)
	_health.take_damage(MAX_HEALTH - clampf(percent, 0.0, 100.0))
	if _health_label != null:
		_health_label.text = "Health %d%%" % roundi(percent)


func set_shake_scale(value: float) -> void:
	FxSettings.shake_scale = clampf(value, 0.0, 1.0)


func set_flash_scale(value: float) -> void:
	FxSettings.flash_scale = clampf(value, 0.0, 1.0)


func set_switch(key: String, on: bool) -> void:
	FxSettings.set_switch(key, on)
	if _switches.has(key):
		var button := _switches[key] as Button
		button.set_pressed_no_signal(on)
		button.text = _switch_text(key, on)


func _build_ui(ui: CanvasLayer) -> void:
	_health_bar = (load("res://scenes/ui/health_bar.tscn") as PackedScene).instantiate() as HealthBar
	_health_bar.position = Vector2(4, 2)
	ui.add_child(_health_bar)
	_health_bar.bind(_health)
	_info = UiKit.label("", &"HudLabel")
	_info.position = Vector2(4, 252)
	ui.add_child(_info)
	var row := 0
	for element in ELEMENTS:
		var y := 20.0 + row * (BUTTON_HEIGHT + 2.0)
		var name_label := UiKit.label(String(element).capitalize(), &"HudLabel")
		name_label.position = Vector2(4, y + 6.0)
		ui.add_child(name_label)
		var column := 0
		for title in WEIGHTS:
			var button := UiKit.button(title)
			button.position = Vector2(50 + column * 42, y)
			button.custom_minimum_size = Vector2(40, BUTTON_HEIGHT)
			button.pressed.connect(press_impact.bind(element, WEIGHTS[title]))
			ui.add_child(button)
			_impact_buttons.append(button)
			column += 1
		row += 1
	_add_row(ui, 20.0, "Hit me", [["Left", LEFT], ["Right", RIGHT], ["Top", TOP], ["Bottom", BOTTOM]], hit_from)
	_add_row(ui, 46.0, "", [["Pickup", &"pickup"], ["Level", &"level_up"], ["Rare", &"rare_drop"], ["Blast", &"blast"]], press_action)
	_add_slider(ui, 74.0, "Health 100%", 100.0, 100.0, set_health_percent, true)
	_add_slider(ui, 92.0, "Shake", 1.0, 1.0, set_shake_scale, false)
	_add_slider(ui, 110.0, "Flash", 1.0, 1.0, set_flash_scale, false)
	var index := 0
	for key in FxSettings.SWITCH_KEYS:
		var button := UiKit.button(_switch_text(key, FxSettings.get_switch(key)))
		button.toggle_mode = true
		button.button_pressed = FxSettings.get_switch(key)
		button.position = Vector2(180 + (index % 2) * 148, 132.0 + floorf(index / 2.0) * (BUTTON_HEIGHT + 2.0))
		button.custom_minimum_size = Vector2(144, BUTTON_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggled.connect(func(on: bool) -> void: set_switch(key, on))
		ui.add_child(button)
		_switches[key] = button
		index += 1


func _add_row(ui: CanvasLayer, y: float, _title: String, entries: Array, handler: Callable) -> void:
	var x := 180.0
	for entry in entries:
		var button := UiKit.button(entry[0])
		button.position = Vector2(x, y)
		button.custom_minimum_size = Vector2(70, BUTTON_HEIGHT)
		button.pressed.connect(handler.bind(entry[1]))
		ui.add_child(button)
		x += 74.0


func _add_slider(ui: CanvasLayer, y: float, title: String, maximum: float, start: float, handler: Callable, is_health: bool) -> void:
	var label := UiKit.label(title, &"HudLabel")
	label.position = Vector2(180, y)
	ui.add_child(label)
	if is_health:
		_health_label = label
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = maximum
	slider.step = 1.0 if is_health else 0.05
	slider.value = start
	slider.position = Vector2(270, y)
	slider.custom_minimum_size = Vector2(190, 14)
	slider.size = slider.custom_minimum_size
	slider.value_changed.connect(handler)
	ui.add_child(slider)


func _switch_text(key: String, on: bool) -> String:
	return "%s %s" % [key.replace("_", " "), "on" if on else "off"]


func _on_beat(level: int) -> void:
	if level >= 1:
		_health_bar.beat()
