extends RefCounted
## Touch events the widget and screen tests send.


## A finger pressed at a position.
static func press_at(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = position
	return event


## A finger pressed at the origin, for a screen that takes a tap anywhere.
static func press() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event
