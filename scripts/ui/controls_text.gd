class_name ControlsText
extends RefCounted
## The Controls page: what each key, controller button and touch control does. The keys are read from the Input Map, so the page can
## never disagree with the real bindings.

## Label and the actions it shows.
const ENTRIES := [
	["Move", [&"move_up", &"move_down", &"move_left", &"move_right"]],
	["Aim", [&"aim_up", &"aim_down", &"aim_left", &"aim_right"]],
	["Cast", [&"cast"]],
	["Interact", [&"interact"]],
	["Previous spell", [&"spell_prev"]],
	["Next spell", [&"spell_next"]],
	["Inventory", [&"toggle_inventory"]],
	["Next potion", [&"potion_next"]],
	["Previous potion", [&"potion_prev"]],
	["Drink potion", [&"potion_use"]],
	["Pause", [&"pause"]],
	["Mute", [&"mute"]],
]
const TOUCH_LINES: Array[String] = [
	"Touch: the left stick moves and the right stick aims and casts.",
	"Touch: tap a spell slot or a potion to use it, Interact beside a Lectern, shrine or merchant.",
	"Keys 1 to 5 pick a spell slot and Z X C V B N drink the six potions.",
]


## The first key of an action as text (a keyboard key if it has one, else a mouse or pad button), or "" for an unknown action.
static func key_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	var fallback := ""
	for event in InputMap.action_get_events(action):
		var text := _event_text(event)
		if text.is_empty():
			continue
		if event is InputEventKey:
			return text
		if fallback.is_empty():
			fallback = text
	return fallback


## The keys of several actions joined with spaces ("W A S D").
static func keys_for(actions: Array) -> String:
	var keys: Array[String] = []
	for action in actions:
		var text := key_for(action)
		if not text.is_empty():
			keys.append(text)
	return " ".join(keys)


static func lines() -> Array[String]:
	var found: Array[String] = []
	for entry in ENTRIES:
		var keys: Array[String] = []
		for action in entry[1]:
			for event in InputMap.action_get_events(action):
				var text := _event_text(event)
				if not text.is_empty() and not keys.has(text):
					keys.append(text)
		found.append("%s: %s" % [entry[0], ", ".join(keys)])
	found.append_array(TOUCH_LINES)
	return found


static func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return (event as InputEventKey).as_text_physical_keycode()
	if event is InputEventMouseButton:
		return "Mouse %s" % ("left" if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT else "button %d" % (event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return "Pad button %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		return "Pad stick"
	return ""
