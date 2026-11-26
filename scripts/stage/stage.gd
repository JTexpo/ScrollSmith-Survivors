class_name Stage
extends Control
## Plays a `StageScript`: a sky, a ground, scenery and actors that walk, animate, shoot orbs and burst into sparks, looping for ever. It
## runs only the sprite code the game already has (`BodyView`, `EffectSprite`), never the game's systems, so it cannot touch a save or
## make a gameplay sound. The state is a function of the time into the loop (beats fire in order and every motion is evaluated at the
## beat's own time), so a big step and many small ones agree and `seek` is exact. At the wrap every actor is reset and every orb and
## spark this stage made is freed. Everything draws at depth 0 in tree order (sky, ground, the background scenery, the Y-sorted world, the orbs, then sparks), so
## the stage looks the same wherever it is placed and anything after it in the tree draws over it. When motion is reduced it builds the script's `still_time` frame and never processes. It ignores
## touches and clips to its rectangle.

const MAX_ORBS := 8
const MAX_EFFECTS := 24
const SPARK_FADE := 0.1
## Where an orb leaves its shooter, in pixels in front of and above the shooter's centre.
const ORB_OFFSET := Vector2(10.0, -2.0)

var _script: StageScript
var _elapsed: float = 0.0
var _next_beat: int = 0
var _playing: bool = false
var _reduced: bool = false
var _profile: PlayerProfile
var _catalog: EquipmentCatalog
var _actors: Dictionary = {}
var _definitions: Dictionary = {}
## Holds the scenery and the actors, depth-sorted by their feet with Y-sort, so no node needs a z above 0 (a positive z would draw over any
## control placed after the stage, such as the home screen's buttons).
var _world: Node2D
## Holds the background scenery (the bushes), behind the world so nothing in it can ever draw over an actor.
var _background: Node2D
## Holds the orbs, above the world.
var _overlay: Node2D
var _walks: Dictionary = {}
var _orbs: Array[Dictionary] = []
var _effects: Array[EffectSprite] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	advance(delta)


## Builds the scene and starts it at 0 (or builds its still frame when motion is reduced). `profile` and `catalog` dress a wizard actor
## in what the player has equipped; with none he wears the starter look.
func play(script: StageScript, profile: PlayerProfile = null, catalog: EquipmentCatalog = null) -> void:
	_clear_all()
	_script = script
	_profile = profile
	_catalog = catalog
	size = Vector2(script.size)
	custom_minimum_size = size
	_build(profile, catalog)
	_reduced = FxSettings.is_reduced()
	if _reduced:
		_playing = false
		set_process(false)
		seek(script.still_time)
		return
	_playing = true
	set_process(true)
	_reset()


## Halts the scene and removes its orbs and sparks (the actors stay where they are).
func stop() -> void:
	_playing = false
	set_process(false)
	_clear_dynamic()


## Carries on after `stop` from where it was (it does not restart the loop). If Reduce motion changed while the stage was stopped
## (Settings covers the home screen), it is built again so it shows the still frame or plays, as the setting now says.
func resume() -> void:
	if _script == null:
		return
	if FxSettings.is_reduced() != _reduced:
		play(_script, _profile, _catalog)
		return
	if _reduced:
		return
	_playing = true
	set_process(true)


func is_playing() -> bool:
	return _playing


func stage_script() -> StageScript:
	return _script


## Puts the equipped look on every wizard actor again (the Shop may have changed it while this stage was covered).
func dress_wizard(profile: PlayerProfile, catalog: EquipmentCatalog) -> void:
	if _script == null:
		return
	for definition in _script.actors:
		if definition.wizard and _actors.has(definition.id):
			PlayerLook.apply(_actors[definition.id], profile, catalog)


func elapsed() -> float:
	return _elapsed


func actor(id: StringName) -> BodyView:
	return _actors.get(id) as BodyView


func orb_count() -> int:
	return _orbs.size()


func effect_count() -> int:
	var count := 0
	for effect in _effects:
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			count += 1
	return count


## Moves the scene forward by `delta` seconds, wrapping (and resetting) at the end of the loop as often as needed.
func advance(delta: float) -> void:
	if _script == null or _script.loop_seconds <= 0.0:
		return
	var remaining := delta
	while remaining > 0.0:
		var step := minf(remaining, _script.loop_seconds - _elapsed)
		_elapsed += step
		remaining -= step
		_run_to(_elapsed)
		if _elapsed >= _script.loop_seconds - 0.000001:
			_reset()


## Shows the scene exactly as it is `time` seconds into the loop (from the start, so the answer never depends on what came before).
func seek(time: float) -> void:
	_reset()
	_run_to(clampf(time, 0.0, _script.loop_seconds))
	_elapsed = clampf(time, 0.0, _script.loop_seconds)


func _build(profile: PlayerProfile, catalog: EquipmentCatalog) -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = _script.sky_color
	sky.size = size
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	if _script.ground_style != &"":
		var tile := SpriteLibrary.find(StringName("tile_%s" % _script.ground_style))
		if tile != null:
			var ground := FloorPatch.new()
			ground.name = "Ground"
			ground.setup(Rect2(0.0, _script.ground_top, size.x, maxf(size.y - _script.ground_top, 0.0)), tile)
			add_child(ground)
	_background = Node2D.new()
	_background.name = "Background"
	_background.y_sort_enabled = true
	add_child(_background)
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)
	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	add_child(_overlay)
	for piece in _script.scenery:
		# Scenery stands on its position: a holder sits at that base point (what Y-sort measures) and the sprite rises from it.
		var holder := Node2D.new()
		holder.name = "Scenery"
		holder.position = piece.position
		(_background if piece.background else _world).add_child(holder)
		var view := BodyView.new()
		holder.add_child(view)
		view.set_look(piece.sprite, piece.variant)
		view.position = Vector2(0.0, -_feet(piece.sprite, piece.variant))
		_flatten(view)
	for definition in _script.actors:
		var body := BodyView.new()
		body.name = String(definition.id)
		body.shadow_enabled = definition.shadow
		_world.add_child(body)
		if definition.wizard:
			if body.set_look(&"player_body"):
				PlayerLook.apply(body, profile, catalog)
		else:
			body.set_look(definition.sprite, definition.variant)
		_flatten(body)
		_actors[definition.id] = body
		_definitions[definition.id] = definition


## A body's shadow sits just under its own body (the first child, at the body's own depth). `BodyView` puts it at the world's absolute shadow
## depth, which would put it under this stage's sky and above nothing; and no node here may have a depth other than 0.
func _flatten(body: BodyView) -> void:
	var shadow := body.get_node_or_null("Shadow") as Sprite2D
	if shadow != null:
		shadow.z_as_relative = true
		shadow.z_index = 0
		body.move_child(shadow, 0)


## Half the sprite's height: from a sprite's centre to its base.
func _feet(sprite: StringName, variant: StringName) -> int:
	var found := SpriteLibrary.find(sprite, variant)
	return int(found.frame_size.y / 2.0) if found != null else 0


func _reset() -> void:
	_clear_dynamic()
	_elapsed = 0.0
	_next_beat = 0
	_walks.clear()
	for id in _actors:
		var body: BodyView = _actors[id]
		var definition: StageActor = _definitions[id]
		body.position = definition.start
		body.visible = definition.visible_at_start
		body.set_facing(definition.facing)
		body.play(definition.animation)


## Fires every beat due by `time` (each after moving everything to the beat's own time), then moves everything to `time`.
func _run_to(time: float) -> void:
	while _next_beat < _script.beats.size() and _script.beats[_next_beat].time <= time:
		var beat := _script.beats[_next_beat]
		_next_beat += 1
		_update_motions(beat.time)
		_fire(beat)
	_update_motions(time)


func _fire(beat: StageBeat) -> void:
	var body := actor(beat.actor)
	match beat.action:
		StageBeat.Action.WALK_TO:
			if body != null:
				_walks[beat.actor] = {"from": body.position, "to": beat.to, "start": beat.time, "duration": beat.duration}
				body.set_facing(beat.to.x - body.position.x)
				body.play(beat.animation if beat.animation != &"" else &"move")
		StageBeat.Action.PLAY:
			if body != null:
				body.play(beat.animation)
		StageBeat.Action.FACE:
			if body != null:
				body.set_facing(beat.facing)
		StageBeat.Action.SHOW:
			if body != null:
				body.visible = true
		StageBeat.Action.HIDE:
			if body != null:
				body.visible = false
		StageBeat.Action.SHOOT:
			if body != null:
				_shoot(body, beat)
		StageBeat.Action.BURST:
			_burst(beat)
		StageBeat.Action.STOP:
			if body != null and _walks.has(beat.actor):
				_walks.erase(beat.actor)
				body.play((_definitions[beat.actor] as StageActor).animation)


func _shoot(shooter: BodyView, beat: StageBeat) -> void:
	if _orbs.size() >= MAX_ORBS:
		return
	var facing := -1.0 if shooter._facing < 0.0 else 1.0
	var orb := BodyView.new()
	orb.name = "Orb"
	orb.shadow_enabled = false
	_overlay.add_child(orb)
	orb.set_look(beat.effect)
	_flatten(orb)
	orb.play(&"fly")
	orb.set_facing(beat.to.x - shooter.position.x)
	var from := shooter.position + Vector2(ORB_OFFSET.x * facing, ORB_OFFSET.y)
	orb.position = from
	_orbs.append({"node": orb, "from": from, "to": beat.to, "start": beat.time, "duration": beat.duration})


func _burst(beat: StageBeat) -> void:
	if _reduced or not FxSettings.particles or effect_count() >= MAX_EFFECTS:
		return
	var spark := EffectSprite.spawn(self, beat.effect, global_position + beat.to, 0.0, SPARK_FADE)
	if spark != null:
		_effects.append(spark)


## Puts every walker and orb where it is at `time`; a finished walk ends where it is going and its actor returns to its own animation,
## a finished orb is freed.
func _update_motions(time: float) -> void:
	for id in _walks.keys():
		var walk: Dictionary = _walks[id]
		var progress := clampf((time - float(walk["start"])) / float(walk["duration"]), 0.0, 1.0)
		var body: BodyView = _actors[id]
		body.position = (walk["from"] as Vector2).lerp(walk["to"] as Vector2, progress)
		if progress >= 1.0:
			_walks.erase(id)
			body.play((_definitions[id] as StageActor).animation)
	var keep: Array[Dictionary] = []
	for orb in _orbs:
		var progress := clampf((time - float(orb["start"])) / float(orb["duration"]), 0.0, 1.0)
		if progress >= 1.0:
			(orb["node"] as Node).queue_free()
			continue
		(orb["node"] as BodyView).position = (orb["from"] as Vector2).lerp(orb["to"] as Vector2, progress)
		keep.append(orb)
	_orbs = keep


func _clear_dynamic() -> void:
	for orb in _orbs:
		(orb["node"] as Node).queue_free()
	_orbs.clear()
	for effect in _effects:
		if is_instance_valid(effect):
			effect.queue_free()
	_effects.clear()


func _clear_all() -> void:
	_clear_dynamic()
	_walks.clear()
	_actors.clear()
	_definitions.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
