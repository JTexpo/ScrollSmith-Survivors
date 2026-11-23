extends GutTest

var _root: Node2D
var _player: Player
var _body: BodyView


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_body = _player.get_node("Body") as BodyView


func test_the_player_has_a_body_view_with_art_and_the_idle_animation() -> void:
	assert_not_null(_body)
	assert_true(_body.has_art())
	_player._update_body(0.016)
	assert_eq(_body.current_animation(), &"idle")


func test_it_plays_move_when_moving_and_idle_when_still() -> void:
	_player.velocity = Vector2(60, 0)
	_player._update_body(0.016)
	assert_eq(_body.current_animation(), &"move")
	_player.velocity = Vector2.ZERO
	_player._update_body(0.016)
	assert_eq(_body.current_animation(), &"idle")


func test_it_faces_where_it_moves_and_where_it_aims_while_casting() -> void:
	var sprite := _body.get_node("Sprite") as AnimatedSprite2D
	_player.velocity = Vector2(-60, 0)
	_player._update_body(0.016)
	assert_true(sprite.flip_h, "moving left")
	_player.aim.aim_direction = Vector2.RIGHT
	_player.loadout.cast_fired.emit(0)
	_player._update_body(0.016)
	assert_false(sprite.flip_h, "casting to the right while moving left faces the aim")


func test_casting_plays_the_cast_animation_for_a_moment_then_returns() -> void:
	_player.loadout.cast_fired.emit(0)
	assert_eq(_body.current_animation(), &"cast")
	_player._update_body(0.1)
	assert_eq(_body.current_animation(), &"cast")
	_player._update_body(0.3)
	assert_eq(_body.current_animation(), &"idle")


func test_the_hit_flash_still_works_on_the_body() -> void:
	var flash := _player.get_node("HitFlashComponent") as HitFlashComponent
	assert_eq(flash.target, _body)
	flash.flash()
	assert_eq(_body.modulate, flash.flash_color)


func test_the_hurtbox_is_still_12_by_12() -> void:
	var shape := (_player.get_node("HurtboxComponent/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	assert_eq(shape.size, Vector2(12, 12))
	var body_shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	assert_eq(body_shape.size, Vector2(12, 12))
