class_name Lectern
extends Area2D
## An Arcane Lectern: a static spot where the player can craft. It holds no crafting logic. It only
## says it was interacted with, and Main opens the crafting screen. Enemies ignore it, and it is
## reusable, unlimited and free. Passive: the player's InteractionComponent finds it.

signal interacted(actor: Node)


func _ready() -> void:
	add_to_group(&"lecterns")
	var body := $Body as BodyView
	if body.set_look(&"lectern"):
		body.play(&"idle")


func interact(actor: Node) -> void:
	interacted.emit(actor)


## The "E" prompt above it, shown while the player is close enough to use it.
func set_prompt_visible(value: bool) -> void:
	($Prompt as Label).visible = value
