class_name SettingsEvents
extends RefCounted
## A static announcement that a setting changed (a slider moved, a switch flipped, saved settings were loaded). The sound board and the
## performance overlay listen; nothing here changes anything. Not an autoload, like `EnemyAttackEvents`.

signal changed

static var bus := SettingsEvents.new()


static func announce() -> void:
	bus.changed.emit()
