class_name PointOfInterestData
extends Resource
## One kind of point of interest. Behaviour comes from `kind` and the numbers, never from the id. HEAL
## restores `amount` of maximum health, RESTORE_MANA restores `amount` of every spell's pool, LOOT gives Gold
## between `gold_min` and `gold_max` and `scroll_count` scrolls rolled from `scroll_table` (a Rare scroll spot
## is a LOOT with no Gold and a Rare-only table), and MERCHANT sells potions at `price_multiplier` times their
## price, `stock_per_potion` of each. Every kind is empty for `refresh_seconds` after use (a merchant restocks
## after that long).

enum Kind { HEAL, RESTORE_MANA, LOOT, MERCHANT }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.HEAL
## A fraction (0.5 is 50%). Used by HEAL and RESTORE_MANA.
@export var amount: float = 0.0
@export var gold_min: int = 0
@export var gold_max: int = 0
@export var scroll_count: int = 0
@export var scroll_table: DropTable
@export var stock_per_potion: int = 0
@export var price_multiplier: float = 1.0
@export var refresh_seconds: float = 180.0
## The sprite (`poi_<name>`, with `ready` and `used` animations). Empty, or a name with no art, keeps the drawn shape.
@export var sprite_name: StringName = &""
## The colour of the ring and of the drawn shape that stands in when there is no art.
@export var color: Color = Color.WHITE
