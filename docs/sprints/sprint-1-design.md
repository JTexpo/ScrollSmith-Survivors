# Sprint 1 Design: Player Movement and Combat Foundation

**Status:** Reviewed by a fresh builder check, and the user's answers are folded in. Awaiting the user's approval. Nothing is built yet.

Scope comes from `sprint-development.md` (Sprint 1). Architecture follows `technical-design.md`, `CLAUDE.md` and `sprint-0-design.md`. The decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Before spell crafting exists, moving, fighting, taking hits and dying has to feel good. Sprint 1 delivers a playable arena where the player moves, aims and fires a temporary attack at a stream of enemies, takes contact damage with knockback, and can die. The values chosen here (player speed, enemy speed, collision behavior, spawn rates) carry into almost every later system, so tuning is a first-class part of the work.

**Goals**
- A playable loop: move, aim, shoot, survive, die, restart.
- Many enemies on screen at once without the frame rate collapsing, on desktop now and on phones/browsers later.
- Aim and fire that work the same on mouse, controller and touch.
- Every gameplay number is tunable from a Resource or `@export`, not buried in scripts.

**Non-goals (later sprints)**
- Spells, scrolls, mana, crafting, the Lectern, elemental math, XP, gold, drops, save data, boss or ranged enemies, real art and audio, screen shake and particles, a real game-over and menu flow.

**Anti-goals** (a failure even if it technically works)
- A combat design that has to be thrown away in Sprint 2 (the temporary attack is allowed to be thrown away, the hit/damage plumbing is not).
- Aiming that only works well with a mouse.
- A frame rate that only holds up with a handful of enemies. Concretely: below 60 fps at 300 full enemies on the user's Mac.

## 2. Decisions

| Area | Decision |
|---|---|
| Aim and fire | Manual aim on all platforms (user decision). Mouse position relative to the player, right stick on controller, a second on-screen touch stick on phones that aims and fires while held. All inputs produce one aim direction plus a "firing" flag. The last-used input wins. |
| Hit detection | Hitbox/hurtbox components built on `Area2D` (user decision), not direct body collisions. |
| Enemy movement | Lighter enemies (user decision): no `move_and_slide()`, no enemy-vs-enemy collision. They move by setting their position, clamped to the arena bounds. This changes the Sprint 0 `Enemy` script. |
| Performance | A stress-test scene with full enemies (chasing, active hitboxes and hurtboxes, taking projectile fire) that reports frame time (user decision). **Target: 60 fps with 300 enemies on the user's Mac, 500 as a stretch goal.** The game may later ship with a 30 fps cap (for example on phones), but the code must be fast enough to reach 60. If the target is missed, optimization (pooling, a cheaper enemy update loop, fewer physics areas) becomes part of Sprint 1. |
| Damage | One central `DamageSystem` function takes a base amount and returns the damage dealt. It is a plain pass-through for now, with no elemental math. |
| Spawner | Timer-based, configured by a `SpawnConfig` Resource (interval, max alive, spawn distance outside the camera view). |
| Contact damage limits | Both gates (user decision): each enemy contact hitbox has a per-target cooldown, and the player gets a short player-wide invulnerability window after any hit. Hit flash, knockback and damage apply only when a hit actually lands, not while invulnerable. The invulnerability state lives on the player's hurtbox/health path so a later Invulnerability Potion (Sprint 10) can reuse it. |
| Crowd stacking | No separation system in the first pass (my call). Each enemy gets a small random speed variation and a random offset around the player to spread the horde. **Decision gate at the end of Sprint 1:** after playing and running the stress test, the user decides whether stacking is bad enough to fix. If so, build a cheap grid-based separation push in Sprint 1. If not, add a "crowd separation" task to Sprint 14's optimization list in `sprint-development.md` so it is tracked. |
| Player health display | A minimal placeholder health bar, marked temporary (my call, agreed by the user). The real HUD stays in its own sprint. It reads `health_changed` and never mutates data. |
| Player death | A simple "You died" overlay with a restart key and a touch-friendly restart tap. |
| Feedback | A brief white flash on hit and a small knockback impulse. |

## 3. Approaches considered

- **Hit detection.** (1) Hitbox/hurtbox `Area2D` components. (2) Direct body collisions with `take_damage` calls. I chose (1) because damage, knockback and health flow through the components, matching the composition rules, and because Sprint 2's Line/Cone/Area spells can reuse the same pieces. Option (2) is less code now but couples combat logic to entities and does not suit Cone and Area spells.
- **Performance.** The main cost is `move_and_slide()` on every enemy, not the choice of hit detection. Enemies get passive `Area2D` hurtboxes and hitboxes (`monitoring = false`), so only the player's hurtbox and projectiles do any watching, and collision layers keep the number of tested pairs small. Browsers and phones run physics on one thread, so the budget is tighter than on desktop.
- **Aim and fire on touch.** (1) Auto-aim at the nearest enemy everywhere. (2) Manual on desktop and controller, auto-aim on touch. (3) Manual everywhere with a second touch stick. I chose (3) for player agency and a shared code path.

## 4. Constraints

- Everything in `sprint-0-design.md` still applies: Godot 4.7.2, typed GDScript, Compatibility renderer, 480×270 integer scaling, no autoloads, Input Map actions only, web-safe settings, GUT tests with the headless command in `CLAUDE.md`, all commands through the venv.
- Don't build features from future sprints. The sprint must leave a playable build.
- Elemental rules for multiple Base types are undecided, so the Damage System must not guess them.
- The Player holds no combat rules, and UI never mutates gameplay data directly.

## 5. Design

### Collision layers
Named layers in `project.godot`: `world`, `player_hurtbox`, `enemy_hurtbox`, `enemy_hitbox` (contact damage), `player_projectile`. Player projectiles detect `enemy_hurtbox` only. The player's hurtbox detects `enemy_hitbox` only. Enemies never detect each other. Exact layer numbers are the builder's call.

### Components (reusable, one responsibility each)
- `HealthComponent` (exists). Used by the player and the enemy.
- `HurtboxComponent` (`Area2D`): passes incoming hits to a `HealthComponent` and emits `hit_received(damage, source_position)`.
- `HitboxComponent` (`Area2D`): holds damage and knockback strength, damages a `HurtboxComponent` it overlaps. Contact hitboxes damage repeatedly, gated by a per-target cooldown.
- `KnockbackComponent`: accumulates a knockback velocity that decays over time and is added to the entity's movement.
- `HitFlashComponent`: briefly tints the body white when a hit lands.
- `DamageSystem` (`scripts/systems/damage_system.gd`): `static func calculate(base_damage: float) -> float`. All damage passes through it, so the elemental math can be added in one place later.

### Player
Gains a `HealthComponent` with a configured max, a hurtbox, a `KnockbackComponent`, a hit flash and a death state. On death it stops, emits `died`, and the death overlay appears. `Player` still only reads input and delegates.

### Aim and fire
New actions: `aim_up`, `aim_down`, `aim_left`, `aim_right` (right stick and the touch aim stick). `cast` already exists (LMB, right trigger); holding the touch aim stick also counts as firing. An `AimComponent` turns the active input into `aim_direction: Vector2` and `is_firing: bool`. The mouse aim direction is the mouse position relative to the player in world space. The touch aim stick is a second instance of the `TouchJoystick`, placed bottom-right, injecting the `aim_*` actions plus `cast` while held.

### Temporary attack
An `AttackComponent` fires a simple projectile in the aim direction while `is_firing`, at a fixed cooldown. The projectile is an `Area2D` with a `HitboxComponent`, moves in a straight line, and is freed on hit or after a lifetime. Its stats come from an `AttackData` Resource. This is a stand-in, so it is easy to delete when Sprint 2 introduces real spells. The hit and damage plumbing is the part that stays.

### Enemies
The Sprint 0 enemy becomes a light `Node2D`-based entity: it moves toward the player by position, clamped to the arena rectangle, with a passive hurtbox and a passive contact hitbox. Stats come from an `EnemyData` Resource (health, damage, speed, knockback taken). It has a `HealthComponent`, dies at zero health (freed, with a small death effect), and uses the hit flash and knockback. The existing `Enemy.direction_to_target()` behavior stays.

### Spawner
`EnemySpawner` runs on a timer from a `SpawnConfig` Resource: spawn interval, max alive, and spawn distance outside the camera view. Enemies spawn on a ring outside the visible area and inside the arena bounds, and no spawning happens once the player is dead. The spawn rate can be edited in the inspector, and a test pins the max-alive cap.

### Death and restart
A `DeathScreen` `CanvasLayer` shows "You died" with a restart action (an R key, a controller button, a tap). Restart reloads the arena scene through `SceneSwitcher`.

### Stress test
A separate scene, `scenes/world/stress_test.tscn`, spawns a configurable number of full enemies (default 300, adjustable up to 500 and beyond) around the player and shows frame time and enemy count on screen. The enemies chase, have active hitboxes and hurtboxes, and take fire from a test attacker, so the measurement reflects real play. It is a development tool, not part of the player flow. Its results go into `development-log.md`.

### Input additions
`aim_up/down/left/right` on the right stick (and the touch aim stick). `restart` on R and a controller button. Existing bindings are unchanged. Device ids use -1 as in Sprint 0.

## 6. Testing

- GUT unit tests for each component and system: damage pass-through, hit/hurt flow and invulnerability gating for contact damage, knockback decay, spawner cap and ring placement, `AimComponent` choosing the latest input, death emitting once, restart.
- A headless smoke run of the main scene with no errors or warnings, plus a run through the godot MCP server.
- The stress test reports frame time at 100, 300 and 500 enemies on desktop. Pass means 60 fps at 300. A phone/browser measurement waits for a web build in a later sprint.
- Manual checklist for the user: movement feel, aim with mouse, aim with controller, touch aim stick (via touch emulation), taking damage, knockback, dying and restarting, spawn rate tweaks, and a feel check at high enemy counts.

## 7. Open items for the builder

These are left to the builder, who should record any call made in `development-log.md`:
- Exact collision layer numbers and names.
- Starting values for player health and speed, enemy health, damage and speed, projectile speed and cooldown, knockback strength, and spawn interval and cap. Tune them by playing, and keep them in Resources.
- The size and placement of the touch aim stick.
- How the restart button looks on the death screen.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Performance still too low with many enemies | Stress test early. Then profile before optimizing, with pooling as the first step. |
| Mouse and touch aim feel inconsistent | One `AimComponent` with a single output. Manual test on each input. |
| Contact damage from many enemies at once kills the player instantly | Per-target hit cooldown plus a player-wide invulnerability window (both decided). |
| Horde collapses into one blob on the player | Random speed and offset variation now. Decision gate at the end of the sprint on whether to add separation. |
| Changing the Sprint 0 `Enemy` breaks its tests | Update those tests with the change and keep `direction_to_target()` behavior. |
| Touch can't be fully verified without a device | Test with touch emulation and recheck on a real device once a web build exists. |
