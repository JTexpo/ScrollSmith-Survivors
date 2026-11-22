class_name BossData
extends Resource
## A boss: its stats, its phases and its rewards. The Boss scene runs any BossData, so a new boss is a new
## resource (and new attack numbers), not new code.

@export var id: StringName
@export var display_name: String
@export_enum("None:-1", "Fire:0", "Thunder:1", "Land:2", "Sea:3") var element: int = -1
@export var max_health: float = 1000.0
@export var contact_damage: float = 20.0
@export var speed: float = 30.0
@export var body_scale: float = 3.0
@export var color: Color = Color(0.55, 0.1, 0.05)
## From the first phase to the last, with falling thresholds.
@export var phases: Array[BossPhase] = []
## XP and Gold (both multiplied by the boss number) and the scrolls it drops.
@export var reward_xp: int = 300
@export var reward_gold: int = 150
@export var reward_scroll_count: int = 2
@export var reward_drop_table: DropTable


## The phase for a health ratio: the last phase whose threshold the ratio has reached, so a hit that skips
## a phase lands in the one it reached. A ratio above 1 is the first phase, and no phases gives 0.
func phase_index(health_ratio: float) -> int:
	for i in range(phases.size() - 1, -1, -1):
		if health_ratio <= phases[i].health_threshold:
			return i
	return 0
