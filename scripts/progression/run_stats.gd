class_name RunStats
extends RefCounted
## The tally of one run: enemies and bosses defeated, scrolls collected, spells crafted, potions drunk, XP and Gold earned and the highest
## level reached. It only LISTENS to announcements the game already makes (it never calls into gameplay), is created by `Main` at each run
## start and is never saved; `freeze` stops it at death. An enemy counts as defeated only when it gives rewards (an Exploder that blasted
## itself was not defeated by the player), and a boss counts as a boss and not also as an enemy.

var enemies: int = 0
var bosses: int = 0
var scrolls: int = 0
var crafts: int = 0
var potions: int = 0
var xp: int = 0
var gold: int = 0
var level: int = 1

var _frozen: bool = false
var _bound: bool = false


func bind(spawner: EnemySpawner, director: RunDirector, collector: PickupCollector, crafting: CraftingScreen, belt: PotionBelt, progress: RunProgress) -> void:
	if _bound:
		return
	_bound = true
	spawner.enemy_died.connect(_on_enemy_died)
	director.boss_defeated.connect(_on_boss_defeated)
	collector.collected.connect(_on_scroll_collected)
	collector.xp_collected.connect(_on_xp)
	collector.gold_collected.connect(_on_gold)
	crafting.crafted.connect(_on_crafted)
	belt.used.connect(_on_potion_used)
	progress.leveled_up.connect(_on_leveled_up)


## Stops counting (the player died).
func freeze() -> void:
	_frozen = true


func is_frozen() -> bool:
	return _frozen


func _on_enemy_died(enemy: Enemy) -> void:
	if not _frozen and is_instance_valid(enemy) and enemy.gives_rewards:
		enemies += 1


func _on_boss_defeated(_number: int) -> void:
	if not _frozen:
		bosses += 1


func _on_scroll_collected(_scroll: ScrollData) -> void:
	if not _frozen:
		scrolls += 1


func _on_xp(amount: int) -> void:
	if not _frozen:
		xp += amount


func _on_gold(amount: int) -> void:
	if not _frozen:
		gold += amount


func _on_crafted() -> void:
	if not _frozen:
		crafts += 1


func _on_potion_used(_potion: PotionData) -> void:
	if not _frozen:
		potions += 1


func _on_leveled_up(new_level: int, _reward: LevelReward) -> void:
	if not _frozen:
		level = maxi(level, new_level)
