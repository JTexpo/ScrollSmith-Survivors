class_name TargetReticle
extends Node2D
## A small crosshair showing where a ground-targeted spell will land (a ring and dot with no art). Visible
## only while such a spell is selected and the player is alive. Reads the player, changes nothing.

const RADIUS := 5.0

var _player: Player
var _view: BodyView


func _ready() -> void:
	visible = false
	_view = BodyView.new()
	add_child(_view)
	if _view.set_look(&"reticle"):
		_view.play(&"idle")
	else:
		_view.visible = false


func bind(player: Player) -> void:
	_player = player


func _process(_delta: float) -> void:
	var spell := _player.loadout.selected() if _player != null else null
	var shown := (
		spell != null
		and spell.data.area_data != null
		and spell.data.area_data.needs_ground_target
		and not _player.health.is_dead()
	)
	visible = shown
	if shown:
		global_position = spell.data.clamp_target(_player.global_position, _player.aim.aim_point)


## True when the sprite is shown, False when the drawn ring and dot stand in.
func has_art() -> bool:
	return _view != null and _view.has_art()


func draws_circle() -> bool:
	return not has_art()


func _draw() -> void:
	if has_art():
		return
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color.WHITE, 1.0)
	draw_circle(Vector2.ZERO, 1.0, Color.WHITE)
