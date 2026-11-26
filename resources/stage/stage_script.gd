class_name StageScript
extends Resource
## A looping scene as data: a sky, a ground, scenery, actors and timed beats. The `Stage` plays it. `still_time` is the moment shown
## as a still picture when motion is reduced.

@export var size: Vector2i = Vector2i(480, 160)
@export var loop_seconds: float = 10.0
@export var still_time: float = 0.0
@export var sky_color: Color = Color("6fd3ff")
## A floor tile name (`grass` for `tile_grass`) covering the stage from `ground_top` down; empty for none.
@export var ground_style: StringName
@export var ground_top: float = 0.0
@export var scenery: Array[StageScenery] = []
@export var actors: Array[StageActor] = []
@export var beats: Array[StageBeat] = []


## Every fault a script can have, one message each.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if loop_seconds <= 0.0:
		found.append("the loop is %s seconds" % str(loop_seconds))
	if still_time < 0.0 or still_time > loop_seconds:
		found.append("still_time %s is outside the loop" % str(still_time))
	var ids := {}
	for actor in actors:
		if actor == null or actor.id == &"":
			found.append("an actor has no id")
			continue
		if ids.has(actor.id):
			found.append("the actor id %s is used twice" % actor.id)
		ids[actor.id] = true
		if not actor.wizard and SpriteLibrary.find(actor.sprite, actor.variant) == null:
			found.append("actor %s has no sprite %s" % [actor.id, actor.sprite])
	for piece in scenery:
		if piece == null or SpriteLibrary.find(piece.sprite, piece.variant) == null:
			found.append("scenery has no sprite %s" % (piece.sprite if piece != null else &""))
	if ground_style != &"" and SpriteLibrary.find(StringName("tile_%s" % ground_style)) == null:
		found.append("no ground tile tile_%s" % ground_style)
	var last := -INF
	for i in beats.size():
		var beat := beats[i]
		if beat == null:
			found.append("beat %d is empty" % i)
			continue
		if beat.time < 0.0 or beat.time > loop_seconds:
			found.append("beat %d is at %s, outside the loop" % [i, str(beat.time)])
		if beat.time < last:
			found.append("beat %d is out of time order" % i)
		last = maxf(last, beat.time)
		if beat.action != StageBeat.Action.BURST and not ids.has(beat.actor):
			found.append("beat %d names the unknown actor '%s'" % [i, beat.actor])
		if beat.action in [StageBeat.Action.SHOOT, StageBeat.Action.BURST]:
			if beat.effect == &"":
				found.append("beat %d has no effect sprite" % i)
			elif SpriteLibrary.find(beat.effect) == null:
				found.append("beat %d has no sprite %s" % [i, beat.effect])
		if beat.action in [StageBeat.Action.WALK_TO, StageBeat.Action.SHOOT] and beat.duration <= 0.0:
			found.append("beat %d needs a duration above 0" % i)
	return found
