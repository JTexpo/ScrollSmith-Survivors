class_name PointOfInterest
extends Area2D
## A shrine, chest, Rare scroll spot or merchant. It holds only what every kind shares: the "press E" prompt, the
## ready or refreshing state, a refresh timer and a ring that fills while it refreshes. It holds no rules: using
## it only says it was used, and `Main` applies `PointOfInterestSystem` and routes the result. Passive: the
## player's InteractionComponent finds it, like a Lectern. The timer counts `_process` time, so it freezes
## while the game is paused, and a point starts every run ready (nothing here is saved).

signal used(point: PointOfInterest, actor: Node)

## How far from the point a dropped scroll lands.
const LOOT_RADIUS := 20.0
const RING_RADIUS := 14.0

@export var data: PointOfInterestData

## Seconds until it can be used again (0 when ready).
var cooldown_left: float = 0.0
## Only a merchant has stock.
var stock: MerchantStock

@onready var _prompt: Label = $Prompt


func _ready() -> void:
	add_to_group(&"points_of_interest")
	if data != null and data.kind == PointOfInterestData.Kind.MERCHANT:
		stock = MerchantStock.new()
		stock.setup(PotionCatalog.default_catalog(), data.stock_per_potion)


func _process(delta: float) -> void:
	if data == null:
		return
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
		queue_redraw()
	if stock != null:
		var restocking := not stock.is_full()
		stock.tick(delta, data.refresh_seconds)
		if restocking:
			queue_redraw()
	if _prompt.visible:
		_prompt.text = prompt_text()


func interact(actor: Node) -> void:
	used.emit(self, actor)


func is_ready() -> bool:
	return cooldown_left <= 0.0


func start_cooldown() -> void:
	cooldown_left = data.refresh_seconds
	queue_redraw()


## 0 just after a use, 1 when ready again. For a merchant it is the restock, and 1 while its stock is full.
func refresh_progress() -> float:
	if data == null or data.refresh_seconds <= 0.0:
		return 1.0
	if stock != null:
		return 1.0 if stock.is_full() or stock.restock_left() <= 0.0 else 1.0 - stock.restock_left() / data.refresh_seconds
	return 1.0 - cooldown_left / data.refresh_seconds


## "Health Shrine (E)" when it can be used, "Health Shrine 2:15" while it refreshes. A merchant always shows (E).
func prompt_text() -> String:
	var title := data.display_name if data != null else ""
	if cooldown_left <= 0.0 or stock != null:
		return "%s (E)" % title
	var seconds := ceili(cooldown_left)
	return "%s %d:%02d" % [title, seconds / 60, seconds % 60]


## The shown or hidden "E" prompt, called by the player's InteractionComponent.
func set_prompt_visible(value: bool) -> void:
	_prompt.visible = value
	if value:
		_prompt.text = prompt_text()


## Where scroll number `index` of `count` is dropped: evenly round a small ring, so none stacks on another.
func loot_spot(index: int, count: int) -> Vector2:
	return global_position + Vector2.from_angle(PI / 2.0 + TAU * index / maxi(count, 1)) * LOOT_RADIUS


func _draw() -> void:
	if data == null:
		return
	var color := data.color
	draw_rect(Rect2(-7, -6, 14, 12), color.darkened(0.35))
	draw_rect(Rect2(-9, -10, 18, 5), color)
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 32, Color(color, 0.3), 1.0)
	var progress := refresh_progress()
	if progress < 1.0:
		draw_arc(Vector2.ZERO, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, color.lightened(0.3), 2.0)
