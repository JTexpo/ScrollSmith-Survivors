# Sprint 1 Combat Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable arena where the player moves, aims and fires a temporary attack at a spawned horde, takes contact damage with knockback, dies, and restarts. It must hold 60 fps with 300 enemies.

**Architecture:** Combat is built from small reusable components (`HurtboxComponent`, `HitboxComponent`, `KnockbackComponent`, `HitFlashComponent`) on top of the existing `HealthComponent`. All damage passes through `DamageSystem`. Enemies are light `Node2D`s moved by position (no physics body). Aim and fire come from one `AimComponent` fed by mouse, stick or the touch aim stick.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing Sprint 0 code in `scripts/`, `scenes/`, `tests/`.

**Spec:** `docs/sprints/sprint-1-design.md` (approved). Also `docs/sprints/sprint-0-design.md`, `CLAUDE.md`, `technical-design.md`.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python`. Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding a `class_name` script.
- Work on branch `sprint-1-combat`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE naming, one responsibility per script, no autoloads, Input Map actions only, device `-1` on every input event.
- No elemental math, spells, mana, XP, drops, bosses, ranged enemies, real art/audio, screen shake or particles. Don't build later-sprint features.
- Gameplay numbers live in Resources or `@export`, not in logic. Starting values (tune by playing): player `max_health` 100, player invulnerability 0.5 s, player speed 90, enemy `max_health` 20, enemy `contact_damage` 10, enemy contact cooldown 1.0 s, enemy speed 40, speed variation ±0.15, offset radius 24, projectile damage 10, speed 220, cooldown 0.35 s, lifetime 1.2 s, spawn interval 0.5 s, max alive 150, spawn margin 24.
- Performance target (user decision): **60 fps with 300 full enemies on the user's Mac, 500 as a stretch goal.** If missed, optimization is in scope (Task 11). A 30 fps cap on phones may come later, but the code must be able to reach 60.
- Enemies never detect each other. Enemy hurtbox and contact hitbox are passive (`monitoring = false`, `monitorable = true`).
- Player holds no combat rules beyond wiring. UI reads from systems only.
- Collision layers (bit values): `WORLD`=1, `PLAYER_HURTBOX`=2, `ENEMY_HURTBOX`=4, `ENEMY_HITBOX`=8, `PLAYER_PROJECTILE`=16.

## Review Focus

- Touching the movement stick on a phone must not fire the attack through an emulated mouse click. Pinned in Task 6 (`emulate_mouse_from_touch` off, and a test).
- Many enemies hitting the player in the same frame must deal damage once per invulnerability window, and `died` must emit once. Pinned in Task 4.
- After the player dies, there is no movement, no firing, no spawning and no chasing, and restart works repeatedly. Pinned in Tasks 4, 8 and 9.
- A projectile overlapping several enemies in one frame hits exactly one and is freed. Pinned in Task 2 and Task 7.
- Spawn positions are always inside the arena and never on or inside the view around the player, even when the player stands in a corner. Pinned in Task 8.
- Aim with the mouse exactly on the player must not produce a zero or NaN direction. Pinned in Task 6.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/utilities/physics_layers.gd` | Layer bit constants |
| `scripts/systems/damage_system.gd` | Central damage calculation (pass-through for now) |
| `scripts/components/hurtbox_component.gd`, `hitbox_component.gd` | Hit/hurt detection and damage flow |
| `scripts/components/knockback_component.gd`, `hit_flash_component.gd` | Knockback velocity and hit flash |
| `scripts/components/aim_component.gd`, `attack_component.gd` | Aim direction and firing |
| `scripts/entities/projectile.gd`, `scenes/spells/projectiles/basic_projectile.tscn` | Temporary projectile |
| `resources/enemies/enemy_data.gd` (+ `basic_enemy.tres`), `resources/attacks/attack_data.gd` (+ `basic_attack.tres`), `resources/spawning/spawn_config.gd` (+ `default_spawn_config.tres`) | Tunable data |
| `scripts/systems/enemy_spawner.gd` | Timer spawner |
| `scripts/ui/health_bar.gd`, `death_screen.gd` + scenes | Placeholder health bar, death overlay |
| `scripts/main/main.gd` | Wiring for the main scene |
| `scripts/dev/stress_test.gd`, `scenes/world/stress_test.tscn` | Performance measurement |

---

### Task 1: Layers, input actions and DamageSystem

**Files:**
- Create: `scripts/utilities/physics_layers.gd`, `scripts/systems/damage_system.gd`, a one-off input script in the scratchpad (not committed)
- Modify: `project.godot` (layer names, `aim_*` and `restart` actions, `input_devices/pointing/emulate_mouse_from_touch=false`), `scripts/components/move_component.gd`
- Test: `tests/test_damage_system.gd`, `tests/test_input_map.gd` (extend), `tests/test_physics_layers.gd`, `tests/test_move_component.gd` (extend)

**Interfaces:**
- Produces: `class_name PhysicsLayers` with `const WORLD := 1`, `PLAYER_HURTBOX := 2`, `ENEMY_HURTBOX := 4`, `ENEMY_HITBOX := 8`, `PLAYER_PROJECTILE := 16`. `class_name DamageSystem extends RefCounted` with `static func calculate(base_damage: float) -> float` (returns `maxf(base_damage, 0.0)`). Actions `aim_up/down/left/right` (right stick, device -1), `restart` (R, controller Back/Select). `MoveComponent.apply(body: CharacterBody2D, direction: Vector2, extra_velocity: Vector2 = Vector2.ZERO) -> void` (velocity = limited direction × speed + extra).

- [ ] **Step 1: Write the failing tests.** `test_damage_system.gd`: pass-through (`calculate(12.0) == 12.0`), negative clamps to `0.0`. `test_physics_layers.gd`: for each layer `ProjectSettings.get_setting("layer_names/2d_physics/layer_N")` equals `world`, `player_hurtbox`, `enemy_hurtbox`, `enemy_hitbox`, `player_projectile` for N 1–5. `test_input_map.gd`: add the four `aim_*` actions and `restart` to `ACTIONS`; add `test_touch_does_not_emulate_mouse` asserting `ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch") == false`. `test_move_component.gd`: `test_extra_velocity_added` (direction zero, extra `(10, 0)` gives velocity `(10, 0)`).
- [ ] **Step 2: Run** the new/extended files. Expected: FAIL.
- [ ] **Step 3: Implement** the two scripts, the `extra_velocity` parameter, and the project settings (layer names; input actions via a headless script as in Sprint 0 with `deadzone` 0.2 for `aim_*`; the touch setting).
- [ ] **Step 4: Run** the full suite. Expected: all pass (Sprint 0's 29 plus the new ones).
- [ ] **Step 5: Commit** `feat: physics layers, aim/restart actions, DamageSystem`.

---

### Task 2: HurtboxComponent and HitboxComponent

**Files:**
- Create: `scripts/components/hurtbox_component.gd`, `scripts/components/hitbox_component.gd`
- Modify: `scripts/components/health_component.gd` (add `set_max_health`)
- Test: `tests/test_hurtbox_hitbox.gd`, `tests/test_health_component.gd` (extend)

**Interfaces:**
- Consumes: `HealthComponent`, `DamageSystem.calculate`.
- Produces:
  - `HealthComponent.set_max_health(value: float) -> void` (sets `max_health` and `current_health`, emits `health_changed`).
  - `class_name HurtboxComponent extends Area2D`: `@export var health: HealthComponent`, `@export var invulnerability_time: float = 0.0`, `signal hit_received(damage: float, source_position: Vector2, knockback: float)`, `func receive_hit(damage: float, source_position: Vector2, knockback: float = 0.0) -> bool` (returns `false` and does nothing while invulnerable or when `health.is_dead()`; otherwise applies `DamageSystem.calculate(damage)` through `health.take_damage`, emits `hit_received`, starts the invulnerability window), `func is_invulnerable() -> bool`. The window counts down in `_process` only while active.
  - `class_name HitboxComponent extends Area2D`: `@export var damage: float = 10.0`, `@export var knockback: float = 0.0`, `@export var hit_cooldown: float = 0.0` (per target), `@export var one_shot: bool = false`, `signal hit_landed(target: HurtboxComponent)`, `func try_hit(target: HurtboxComponent, now_msec: int = Time.get_ticks_msec()) -> bool` (rejects within the per-target cooldown; records the time only if the hit landed; calls `target.receive_hit(damage, global_position, knockback)`; emits `hit_landed`; for `one_shot` it then sets `monitoring` false via `set_deferred`). `_physics_process` polls `get_overlapping_areas()` only while `monitoring` is true, and calls `try_hit` for each `HurtboxComponent` found and stops after the first landed hit when `one_shot`.
  - `HurtboxComponent._physics_process` also polls `get_overlapping_areas()` while `monitoring`, and calls `area.try_hit(self)` for each `HitboxComponent` (this is how the player's passive-hitbox contact damage works).

- [ ] **Step 1: Write the failing tests** (`extends GutTest`, real nodes via `add_child_autofree`; physics-free tests call methods directly): `test_receive_hit_damages_health_and_emits`, `test_invulnerable_after_hit_rejects_second` (window 0.5, second call returns `false` and HP unchanged), `test_invulnerability_expires` (call `_process(0.6)` then a hit lands), `test_hit_on_dead_target_rejected`, `test_cooldown_blocks_repeat_hits` (`try_hit` at `now_msec` 0 and 500 with cooldown 1.0, second returns `false`; at 1100 returns `true`), `test_rejected_hit_does_not_consume_cooldown` (target invulnerable, rejected, then lands as soon as it expires without waiting for the cooldown), `test_one_shot_hits_only_one_of_two_overlapping` (integration: a monitoring one-shot hitbox overlapping two hurtboxes, then `await wait_physics_frames(3)`; exactly one target damaged; `monitoring` false afterwards). `test_health_component.gd`: `test_set_max_health_resets_current`.
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement** both components and `set_max_health`.
- [ ] **Step 4: Run** the full suite. Expected: all pass.
- [ ] **Step 5: Commit** `feat: Hurtbox/Hitbox components`.

---

### Task 3: KnockbackComponent and HitFlashComponent

**Files:**
- Create: `scripts/components/knockback_component.gd`, `scripts/components/hit_flash_component.gd`
- Test: `tests/test_knockback_component.gd`, `tests/test_hit_flash_component.gd`

**Interfaces:**
- Produces:
  - `class_name KnockbackComponent extends Node`: `@export var decay: float = 600.0` (speed lost per second), `var velocity: Vector2`, `func apply_impulse(direction: Vector2, strength: float) -> void` (adds `direction.normalized() * strength`; a zero direction or non-positive strength does nothing), `func update(delta: float) -> Vector2` (moves `velocity` toward zero by `decay * delta` without overshooting, and returns the value it had before decaying this step).
  - `class_name HitFlashComponent extends Node`: `@export var target: CanvasItem`, `@export var duration: float = 0.1`, `@export var flash_color: Color = Color(2, 2, 2, 1)`, `func flash() -> void` (sets `target.modulate = flash_color`, enables processing), `_process(delta)` restores `Color.WHITE` when time is up and disables processing, and a `var is_flashing: bool`.

- [ ] **Step 1: Write the failing tests:** `test_impulse_sets_velocity`, `test_update_decays_to_exactly_zero` (impulse 100, decay 600, `update(1.0)` leaves `velocity == Vector2.ZERO`, never negative), `test_zero_direction_ignored`, `test_flash_sets_color_then_restores` (call `flash()`, assert `target.modulate == flash_color`, `_process(0.2)`, assert `Color.WHITE` and `is_flashing == false`).
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement** both.
- [ ] **Step 4: Run** the full suite. Expected: all pass.
- [ ] **Step 5: Commit** `feat: Knockback and HitFlash components`.

---

### Task 4: Player combat state

**Files:**
- Modify: `scripts/entities/player.gd`, `scenes/player/player.tscn`
- Test: `tests/test_player.gd`, `tests/test_motion_mode.gd` (unchanged for the player)

**Interfaces:**
- Consumes: `HurtboxComponent`, `KnockbackComponent`, `HitFlashComponent`, `MoveComponent.apply(…, extra_velocity)`, `PhysicsLayers`.
- Produces: `Player` gains `signal died`, `@onready var health: HealthComponent`. The scene gets `HurtboxComponent` (Area2D, layer `PLAYER_HURTBOX`, mask `ENEMY_HITBOX`, `monitoring` true, `invulnerability_time` 0.5, `health` wired, a 12×12 rectangle shape), `KnockbackComponent`, `HitFlashComponent` (`target` = Body). `HealthComponent.max_health` 100. On `hit_received` the player calls `knockback.apply_impulse((global_position - source_position), knockback)` and `flash.flash()`. On `health.died` it removes itself from group `"player"` and emits `died`. A dead player does not move or fire.

- [ ] **Step 1: Write the failing tests** (instantiate `player.tscn`): `test_hit_reduces_health_and_flashes_and_knocks_back`, `test_second_hit_inside_window_ignored`, `test_many_hits_same_frame_deal_damage_once` (ten `receive_hit(10, …)` calls in a row leave HP 90), `test_death_emits_once_leaves_player_group_and_stops_movement` (kill with a huge hit and another; `watch_signals`; `assert_signal_emit_count(player, "died", 1)`; `Input.action_press("move_right")` then physics frames leave position unchanged; release the action afterwards), `test_knockback_moves_player_away_from_source` (hit from the left, a physics frame later `global_position.x` has increased).
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement.** `_physics_process(delta)` returns early when dead, otherwise calls `_move.apply(self, input_direction, _knockback.update(delta))`.
- [ ] **Step 4: Run** the full suite. Expected: all pass. Smoke-run with `godot --headless --quit-after 60` for no errors.
- [ ] **Step 5: Commit** `feat: player health, hurtbox, knockback, death`.

---

### Task 5: Light enemies

**Files:**
- Create: `resources/enemies/enemy_data.gd`, `resources/enemies/basic_enemy.tres`
- Modify: `scripts/entities/enemy.gd`, `scenes/enemies/base_enemy.tscn`, `tests/test_enemy.gd`, `tests/test_motion_mode.gd` (enemy scene removed from the list)
- Test: `tests/test_enemy.gd` (extended)

**Interfaces:**
- Consumes: Tasks 2 and 3 components, group `"player"`.
- Produces:
  - `class_name EnemyData extends Resource`: `@export var max_health: float = 20.0`, `contact_damage: float = 10.0`, `contact_cooldown: float = 1.0`, `contact_knockback: float = 80.0`, `speed: float = 40.0`, `speed_variation: float = 0.15`, `offset_radius: float = 24.0`.
  - `Enemy` becomes `extends Node2D` (no physics body, no `MoveComponent`): `signal died(enemy: Enemy)`, `@export var data: EnemyData`, `func setup(enemy_data: EnemyData, arena_bounds: Rect2, rng: RandomNumberGenerator) -> void` (applies data to `HealthComponent.set_max_health` and the contact hitbox, picks `speed = data.speed * rng.randf_range(1 - v, 1 + v)` and a random offset inside `offset_radius`), `func direction_to_target() -> Vector2` (direction to the first `"player"` node plus the offset, `Vector2.ZERO` if none; offset is zero before `setup`). `_physics_process(delta)` moves `position += (direction × speed + knockback.update(delta)) * delta`, then clamps to `arena_bounds`. Scene: root `Node2D`, `Body`, `HealthComponent`, `HurtboxComponent` (layer `ENEMY_HURTBOX`, mask 0, `monitoring` false), contact `HitboxComponent` (layer `ENEMY_HITBOX`, mask 0, `monitoring` false), `KnockbackComponent`, `HitFlashComponent`. On `hit_received` it knocks back and flashes. On death it sets `monitorable` false on both boxes via `set_deferred`, stops processing, emits `died(self)` once, shrinks via a short tween and `queue_free()`s.

- [ ] **Step 1: Write the failing tests** (existing two stay): `test_enemy_is_not_a_physics_body` (`assert_false(enemy is CharacterBody2D)`), `test_setup_applies_data_and_speed_variation_bounds` (30 seeds, speed within 40 × 0.85..1.15), `test_offset_within_radius`, `test_movement_clamped_to_bounds` (bounds `Rect2(0,0,100,100)`, enemy forced outside moves back inside after a physics frame with the player at the far side), `test_death_emits_once_and_boxes_deactivate`, `test_hit_after_death_rejected`, `test_contact_damages_player_integration` (an enemy overlapping a player hurtbox, then `await wait_physics_frames(3)`, player HP is below max and a second hit within the invulnerability window changes nothing), `test_hit_cooldown_applies_between_enemy_and_player_once_invulnerability_ends`.
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement.** Remove the enemy from `test_motion_mode.gd`. Create `basic_enemy.tres` with the default values and set it as the scene's `data`.
- [ ] **Step 4: Run** the full suite. Expected: all pass. Smoke-run for no errors and warnings.
- [ ] **Step 5: Commit** `feat: light enemies with health, hurtbox and contact damage`.

---

### Task 6: Aim and the touch aim stick

**Files:**
- Create: `scripts/components/aim_component.gd`
- Modify: `scripts/ui/touch_joystick.gd`, `scenes/ui/touch_controls.tscn`, `scenes/player/player.tscn`
- Test: `tests/test_aim_component.gd`, `tests/test_touch_joystick.gd` (extended)

**Interfaces:**
- Consumes: `aim_*` and `cast` actions from Task 1.
- Produces:
  - `class_name AimComponent extends Node`: `enum Source { MOUSE, STICK }`, `var aim_direction: Vector2 = Vector2.RIGHT`, `var is_firing: bool = false`, `var source: Source = Source.MOUSE`, `func update_aim(origin: Vector2, mouse_position: Vector2, stick: Vector2, firing: bool, mouse_moved: bool) -> void` (stick with length above 0.2 wins and sets `aim_direction = stick.normalized()`; otherwise the mouse wins only when `mouse_moved` is true, or already the source, and sets the direction from `mouse_position - origin`; a zero-length result keeps the previous direction; `is_firing = firing`). `_physics_process` gathers `Input.get_vector("aim_left","aim_right","aim_up","aim_down")`, `Input.is_action_pressed("cast")`, `get_parent().get_global_mouse_position()` and whether the mouse moved since the last frame, and calls `update_aim`.
  - `TouchJoystick` gains `@export var action_up/action_down/action_left/action_right: StringName` (defaults `move_up/down/left/right`) and `@export var held_action: StringName = &""` (pressed while the touch is held, released on release, hide and pause). `touch_controls.tscn` gets a second joystick bottom-right with `aim_*` actions and `held_action = &"cast"`.

- [ ] **Step 1: Write the failing tests.** Aim: `test_mouse_aims_from_origin_to_cursor`, `test_stick_overrides_mouse_while_held`, `test_mouse_takes_over_after_stick_released_and_moved`, `test_zero_length_mouse_keeps_previous_direction` (mouse exactly on the origin gives no NaN and the direction is unchanged), `test_firing_flag_follows_input`. Joystick: `test_aim_stick_presses_aim_actions_and_cast` (an instance with the `aim_*` exports: drag right gives `Input.get_vector("aim_left","aim_right","aim_up","aim_down") ≈ Vector2.RIGHT` and `Input.is_action_pressed("cast")`), `test_release_clears_cast`, `test_default_instance_still_drives_move_actions` (guards Sprint 0 behavior), `test_hiding_clears_held_action`. Each cleans up with `Input.action_release`.
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement** and add `AimComponent` to `player.tscn`.
- [ ] **Step 4: Run** the full suite. Expected: all pass. Verify manually with touch emulation: moving the movement stick does not fire, and the aim stick aims.
- [ ] **Step 5: Commit** `feat: aim component and touch aim stick`.

---

### Task 7: Temporary attack

**Files:**
- Create: `resources/attacks/attack_data.gd`, `resources/attacks/basic_attack.tres`, `scripts/components/attack_component.gd`, `scripts/entities/projectile.gd`, `scenes/spells/projectiles/basic_projectile.tscn`
- Modify: `scripts/entities/player.gd`, `scenes/player/player.tscn`
- Test: `tests/test_attack_component.gd`, `tests/test_projectile.gd`

**Interfaces:**
- Consumes: `AimComponent`, `HitboxComponent`, `PhysicsLayers`.
- Produces:
  - `class_name AttackData extends Resource`: `@export var damage: float = 10.0`, `cooldown: float = 0.35`, `projectile_speed: float = 220.0`, `lifetime: float = 1.2`, `knockback: float = 120.0`, `projectile_scene: PackedScene`.
  - `class_name AttackComponent extends Node`: `@export var data: AttackData`, `var projectile_root: Node` (defaults to the parent's parent), `func try_fire(origin: Vector2, direction: Vector2) -> Node2D` (returns the projectile, or `null` while on cooldown, with zero direction, or when `data` is null), cooldown ticks in `_process`.
  - `class_name Projectile extends Node2D`: `func launch(direction: Vector2, data: AttackData) -> void`; moves in a straight line, freed after `lifetime` or on `hit_landed`. Its `HitboxComponent` has layer `PLAYER_PROJECTILE`, mask `ENEMY_HURTBOX`, `monitoring` true, `one_shot` true.
  - `Player._physics_process` calls `_attack.try_fire(global_position, _aim.aim_direction)` when `_aim.is_firing` and not dead.

- [ ] **Step 1: Write the failing tests:** `test_fire_spawns_projectile_with_direction`, `test_cooldown_blocks_second_shot_then_allows` (`_process(0.4)` between shots), `test_zero_direction_does_not_fire`, `test_projectile_moves_straight` (`_physics_process` by 0.5 s moves ≈110 px), `test_projectile_freed_after_lifetime`, `test_projectile_hits_one_enemy_and_frees_integration` (two enemies overlapping the projectile: exactly one loses health, projectile gone after `await wait_physics_frames(4)`), `test_dead_player_does_not_fire`.
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement.** The projectile must be easy to delete in Sprint 2. Mark `basic_attack.tres`, `attack_component.gd` and the projectile scene with a header comment as temporary stand-ins.
- [ ] **Step 4: Run** the full suite. Expected: all pass. Run the project through the godot MCP server: LMB fires toward the cursor, with no errors or warnings.
- [ ] **Step 5: Commit** `feat: temporary attack and projectile`.

---

### Task 8: Spawner

**Files:**
- Create: `resources/spawning/spawn_config.gd`, `resources/spawning/default_spawn_config.tres`, `scripts/systems/enemy_spawner.gd`
- Modify: `scenes/main/main.tscn`
- Test: `tests/test_enemy_spawner.gd`

**Interfaces:**
- Consumes: `Enemy.setup`, `EnemyData`.
- Produces:
  - `class_name SpawnConfig extends Resource`: `@export var interval: float = 0.5`, `max_alive: int = 150`, `spawn_margin: float = 24.0`, `enemy_scene: PackedScene`, `enemy_data: EnemyData`.
  - `class_name EnemySpawner extends Node`: `@export var config: SpawnConfig`, `@export var arena_bounds: Rect2 = Rect2(0, 0, 960, 540)`, `@export var view_size: Vector2 = Vector2(480, 270)`, `var rng := RandomNumberGenerator.new()`, `var alive: int`, `func spawn_position(player_position: Vector2) -> Vector2` (a point on a ring outside the view rectangle around the player by `spawn_margin`, clamped into `arena_bounds`; retries up to 8 angles; returns `Vector2.INF` if none is valid), `func spawn_at(position: Vector2) -> Enemy` (ignores the cap), `func try_spawn() -> Enemy` (returns `null` at the cap, with no `"player"` node, or with no valid position), `func tick(delta: float) -> void` (accumulates time and calls `try_spawn` once per `interval` elapsed). `alive` decreases when an enemy's `died` fires. `tick` is driven by `_process`, so the spawn rate is editable in the inspector and no spawning happens once the player has left the `"player"` group.

- [ ] **Step 1: Write the failing tests** (seeded `rng`): `test_never_exceeds_max_alive` (cap 3, ten `try_spawn` calls), `test_alive_decrements_on_enemy_death`, `test_spawn_position_inside_bounds_and_outside_view` (200 seeds; player at the centre, then in each corner: every returned point is inside `arena_bounds`, and not inside the view rectangle around the player unless `Vector2.INF`), `test_no_spawn_without_player`, `test_tick_respects_interval` (interval 0.5: `tick(0.4)` spawns nothing, `tick(0.2)` spawns one), `test_no_spawn_after_player_death`.
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement,** add the spawner to `main.tscn` with `default_spawn_config.tres`, and spawn into the spawner's parent.
- [ ] **Step 4: Run** the full suite. Expected: all pass. Run via MCP: enemies arrive from outside the view and chase.
- [ ] **Step 5: Commit** `feat: configurable enemy spawner`.

---

### Task 9: Health bar, death screen, restart and main wiring

**Files:**
- Create: `scripts/ui/health_bar.gd`, `scripts/ui/death_screen.gd`, `scenes/ui/health_bar.tscn`, `scenes/ui/death_screen.tscn`, `scripts/main/main.gd`
- Modify: `scenes/main/main.tscn`
- Test: `tests/test_health_bar.gd`, `tests/test_death_screen.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `Player.health`, `Player.died`, `SceneSwitcher.change_to`.
- Produces:
  - `class_name HealthBar extends Control`: `func bind(health: HealthComponent) -> void` (connects `health_changed`, shows the current ratio as a filled bar, and has a visible "TEMP" label marking it a placeholder), `var ratio: float`.
  - `class_name DeathScreen extends CanvasLayer`: hidden at start. `func show_death() -> void`, `signal restart_requested`. It emits `restart_requested` on the `restart` action or any `InputEventScreenTouch` press, only while shown, and then reloads the current scene with `SceneSwitcher.change_to(get_tree(), get_tree().current_scene.scene_file_path)`.
  - `class_name Main extends Node2D` (`main.gd`): in `_ready` binds the health bar to the player and connects `player.died` to `death_screen.show_death`.

- [ ] **Step 1: Write the failing tests:** `test_health_bar_ratio_follows_health` (100 max, damage 25, `ratio == 0.75`), `test_death_screen_hidden_until_shown`, `test_restart_ignored_while_hidden`, `test_restart_requested_on_action_and_on_touch_when_shown`, `test_main_player_death_shows_death_screen` (instantiate `main.tscn`, kill the player, `death_screen.visible`), `test_restart_works_twice` (call the restart path twice, assert it returns `OK` each time and the scene root is the arena again).
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement** and wire the scenes (health bar top-left under a `CanvasLayer`, death screen above everything).
- [ ] **Step 4: Run** the full suite. Expected: all pass. Run via MCP: take damage, see the bar drop and the flash, die, restart.
- [ ] **Step 5: Commit** `feat: health bar, death screen, restart`.

---

### Task 10: Stress test

**Files:**
- Create: `scripts/dev/stress_test.gd`, `scenes/world/stress_test.tscn`
- Test: `tests/test_stress_report.gd`

**Interfaces:**
- Consumes: `EnemySpawner.spawn_at`, `AttackComponent.try_fire`, the player scene.
- Produces: `class_name StressTest extends Node2D` with `@export var enemy_count: int = 300` and `@export var run_seconds: float = 0.0` (0 means run until closed). Command-line overrides from `OS.get_cmdline_user_args()`: `--enemies=N`, `--seconds=S`. It spawns `enemy_count` full enemies on a ring around the player via `spawn_at`, respawns each one that dies to keep the count constant, makes the player effectively invulnerable (huge `max_health`), fires a rotating shot every frame through the `AttackComponent`, and shows an on-screen label with fps, enemy count and frame time. When `run_seconds > 0` it prints one line `STRESS enemies=<n> avg_fps=<x> avg_frame_ms=<x> p99_frame_ms=<x> avg_physics_ms=<x>` (from `Performance.TIME_PHYSICS_PROCESS`) and quits. A pure helper `class_name StressReport` with `static func summarize(frame_ms: Array[float]) -> Dictionary` returning `avg_ms`, `avg_fps` and `p99_ms`.

- [ ] **Step 1: Write the failing tests:** `test_summarize_average_and_fps` (`[16.0, 16.0, 16.0, 16.0]` gives `avg_ms == 16.0`, `avg_fps ≈ 62.5`), `test_summarize_p99_picks_worst_tail` (`99` values of 10.0 and one 100.0 give `p99_ms == 100.0` when the tail rounds up), `test_summarize_empty_is_safe` (no division by zero, returns zeros).
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement** the scene and script.
- [ ] **Step 4: Run** the full suite. Expected: all pass. Then measure windowed on this machine: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=100 --seconds=10`, then 300 and 500. If no display is available in this session, give the user the exact command and ask them to paste the output. Record the numbers in `development-log.md`.
- [ ] **Step 5: Commit** `feat: stress test scene and measurements`.

---

### Task 11: Performance gate, tuning and final verification

- [ ] **Step 1: Check the target.** If the 300-enemy run reaches 60 fps (avg frame time at most 16.6 ms, p99 recorded), note it in `development-log.md` and skip to Step 4.
- [ ] **Step 2: If it misses,** profile first (the Godot profiler or `Performance` monitors, physics time versus script time). Pick the cheapest candidate that the numbers justify (for example, fewer overlap queries, a cheaper enemy update loop, pooling projectiles and enemies), implement it with a test that pins the behavior it must keep, re-measure, and repeat. Log each change with before/after numbers. Don't optimize anything the numbers don't point at.
- [ ] **Step 3: If it still misses after a reasonable effort,** stop and report the numbers to the user rather than guess further.
- [ ] **Step 4: Run** the full suite and a clean smoke run (no errors or warnings) and an MCP run.
- [ ] **Step 5: Ask the user to play** the manual checklist: movement feel, mouse aim, controller aim, touch aim stick (emulated), damage, knockback, dying and restarting, spawn rate edits in `default_spawn_config.tres`, and a feel check at high enemy counts.
- [ ] **Step 6: Decision gate on crowd stacking.** After the user has played it and seen the stress test, ask whether stacking is bad enough to fix. If yes, add a grid-based separation push as a new tested task. If no, add a "crowd separation" line to Sprint 14's optimization tasks in `sprint-development.md`.
- [ ] **Step 7: Tick** the done Sprint 1 boxes in `sprint-development.md`, update `CLAUDE.md` (stress-test command, new architecture notes), update the memory notes, and commit `docs: Sprint 1 complete`.

## Self-review notes

- Spec coverage: layers/actions/damage (Task 1), hitbox/hurtbox and contact gating (2), knockback and flash (3), player health/death/invulnerability (4), light enemies, speed and offset variation, death (5), aim, touch aim stick and the touch-emulation issue (6), temporary attack (7), spawner and config (8), health bar, death screen and restart (9), stress test (10), the 60 fps gate and the crowd-stacking decision gate (11).
- Type consistency: `receive_hit(damage, source_position, knockback)` and `hit_received` carry the same three parameters in Tasks 2, 4 and 5. `MoveComponent.apply` gains `extra_velocity` in Task 1 and is used in Task 4. `Enemy.setup(enemy_data, arena_bounds, rng)` is produced in Task 5 and used in Task 8. `EnemySpawner.spawn_at` is produced in Task 8 and used in Task 10.
