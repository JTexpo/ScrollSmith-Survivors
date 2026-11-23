extends GutTest

const BOUNDS := Rect2(0, 0, 960, 540)
const K := BossAttack.Kind
const STEP := 0.05

var _root: Node2D
var _player: Player
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(400, 300)
	_player.health.set_max_health(1.0e9)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 11


func _attack(kind: BossAttack.Kind, telegraph: float = 1.0) -> BossAttack:
	var attack := BossAttack.new()
	attack.kind = kind
	attack.telegraph_time = telegraph
	attack.damage = 10.0
	attack.radius = 48.0
	attack.count = 8
	attack.dash_speed = 260.0
	attack.dash_time = 0.6
	attack.recover_time = 2.0
	attack.projectile_speed = 100.0
	attack.projectile_range = 260.0
	if kind == K.CHARGE:
		attack.vulnerability_bonus = 0.5
	return attack


func _data(id: StringName, attacks: Array[BossAttack]) -> BossData:
	var phase := BossPhase.new()
	phase.health_threshold = 1.0
	phase.attacks = attacks
	phase.attack_interval = 0.5
	var data := BossData.new()
	data.id = id
	data.max_health = 1000.0
	data.contact_damage = 5.0
	data.speed = 0.0
	data.body_scale = 3.0
	data.color = Color(0.55, 0.1, 0.05)
	data.phases = [phase] as Array[BossPhase]
	return data


func _boss(data: BossData) -> Boss:
	var boss := (load("res://scenes/enemies/boss.tscn") as PackedScene).instantiate() as Boss
	boss.setup(data, 1, null, BOUNDS, _rng)
	_root.add_child(boss)
	boss.global_position = Vector2(100, 300)
	boss.set_physics_process(false)
	return boss


func _titan(attack: BossAttack) -> Boss:
	return _boss(_data(&"ember_titan", [attack] as Array[BossAttack]))


func _step(boss: Boss, seconds: float) -> void:
	for i in maxi(roundi(seconds / STEP), 1):
		boss._physics_process(STEP)


func _view(boss: Boss) -> BodyView:
	return boss.get_node("Body") as BodyView


func test_the_boss_has_art_and_idles() -> void:
	var boss := _titan(_attack(K.SLAM))
	assert_true(_view(boss).has_art())
	assert_eq(_view(boss).current_animation(), &"idle")
	for animation in [&"idle", &"telegraph", &"attack", &"vulnerable"]:
		assert_true(_view(boss).has_animation(animation), String(animation))


func test_a_warning_plays_telegraph_and_returns_to_idle() -> void:
	var boss := _titan(_attack(K.BURST, 0.5))
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	assert_eq(_view(boss).current_animation(), &"telegraph")
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.RECOVER)
	assert_eq(_view(boss).current_animation(), &"attack")
	await wait_seconds(0.5)
	assert_eq(boss.state, Boss.State.RECOVER)
	assert_eq(_view(boss).current_animation(), &"idle", "the burst's attack pose ends by itself")


func test_a_charge_or_burst_plays_attack() -> void:
	var charge := _titan(_attack(K.CHARGE, 0.2))
	_step(charge, 0.5)
	_step(charge, 0.3)
	assert_eq(charge.state, Boss.State.ACT)
	assert_eq(_view(charge).current_animation(), &"attack")
	var burst := _titan(_attack(K.BURST, 0.2))
	_step(burst, 0.5)
	_step(burst, 0.3)
	assert_eq(_view(burst).current_animation(), &"attack")


func test_the_vulnerability_window_plays_vulnerable_then_ends() -> void:
	var boss := _titan(_attack(K.CHARGE, 0.2))
	_step(boss, 0.5)
	_step(boss, 0.3)
	_step(boss, 0.8)
	assert_eq(boss.state, Boss.State.RECOVER)
	assert_true(boss.vulnerable)
	assert_eq(_view(boss).current_animation(), &"vulnerable")
	_step(boss, 2.0)
	assert_eq(boss.state, Boss.State.IDLE)
	assert_false(boss.vulnerable)
	assert_eq(_view(boss).current_animation(), &"idle")


func test_the_sprite_is_one_to_one_at_boss_scale_three_and_the_hurtbox_is_unchanged() -> void:
	var boss := _titan(_attack(K.SLAM))
	assert_eq(boss.scale, Vector2.ONE * 3.0)
	assert_almost_eq((_view(boss).get_node("Sprite") as Node2D).global_transform.get_scale().x, 1.0, 0.001)
	var shape := (boss.get_node("HurtboxComponent/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	assert_eq(shape.size, Vector2(12, 12))


func test_a_boss_without_art_keeps_the_tinted_square() -> void:
	var data := _data(&"no_such_boss", [_attack(K.BURST, 0.5), _attack(K.CHARGE, 0.2)] as Array[BossAttack])
	var boss := _boss(data)
	var fallback := _view(boss).get_node("Fallback") as ColorRect
	assert_false(_view(boss).has_art())
	assert_true(fallback.visible)
	assert_eq(fallback.color, data.color)
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	assert_eq(fallback.color, data.color.lightened(0.3), "a warning lightens the square")
	_step(boss, 0.6)
	_step(boss, 2.0)
	assert_eq(boss.state, Boss.State.IDLE)
	assert_eq(fallback.color, data.color)
	_step(boss, 0.5)
	_step(boss, 0.3)
	_step(boss, 0.8)
	assert_true(boss.vulnerable)
	assert_eq(fallback.color, data.color.lightened(0.5), "the open window lightens it more")


func test_the_hit_flash_still_works() -> void:
	var boss := _titan(_attack(K.SLAM))
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(5.0, Vector2.ZERO, 0.0, SpellData.NO_ELEMENT)
	assert_true((boss.get_node("HitFlashComponent") as HitFlashComponent).is_flashing)
	assert_ne(_view(boss).modulate, Color.WHITE)


func test_the_charge_warning_uses_marks_along_the_dash_line_then_clears() -> void:
	var boss := _titan(_attack(K.CHARGE, 0.5))
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	var marks := boss.charge_marks()
	assert_gt(marks.size(), 3, "a dashed line of marks")
	var to_player := (_player.global_position - boss.global_position).normalized()
	for mark in marks:
		var along := (mark.global_position - boss.global_position)
		assert_almost_eq(absf(along.normalized().dot(to_player)), 1.0, 0.05, "on the dash line")
		assert_almost_eq(mark.global_transform.get_scale().x, 1.0, 0.001, "never scaled, though the boss is x3")
	_step(boss, 0.6)
	assert_eq(boss.charge_marks().size(), 0, "gone when the charge starts")

