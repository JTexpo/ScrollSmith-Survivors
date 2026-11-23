class_name ImpactEvents
extends RefCounted
## Announces every spell hit with its weight and element, from the one place all five spell areas build their hits. One shared
## emitter (not an autoload): the area says what happened, and the effects and the sound board listen. Nothing else changes.

static var bus: ImpactEvents = ImpactEvents.new()

@warning_ignore("unused_signal")
signal hit(position: Vector2, weight: float, element_id: StringName)
