class_name GoldCounter
extends Label
## "Gold 120" under the level text, in the outlined gold HUD label. It only shows what a RunProgress reports and
## holds no rules.

var _gold: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = gold_text()


func bind(progress: RunProgress) -> void:
	progress.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(progress.profile.gold)


func gold_text() -> String:
	return "Gold %d" % _gold


func _on_gold_changed(total_gold: int) -> void:
	_gold = total_gold
	text = gold_text()
