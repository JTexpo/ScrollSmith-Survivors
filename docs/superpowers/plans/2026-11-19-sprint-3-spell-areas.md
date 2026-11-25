# Sprint 3 Spell Areas and Behaviors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Area a real, separate part of every spell. Five Areas (Line, Cone, Area, Missile, Wave) each live in their own scene behind one `launch` call, with range and size as per-spell numbers, so Sprint 6 crafting can scale them.

**Architecture:** `AreaData` (Resource) holds one Area type's scene and default numbers. `SpellData` points at an `AreaData` and carries `range_scale` and `size_scale`. Each Area scene's root script extends `AreaEffect` and implements `launch(spell, origin, direction, target)`. `SpellLoadout.try_cast` instantiates the spell's Area scene and calls `launch`, with no per-type branching. A temporary `TargetReticle` shows where an Area-type spell will land.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-3-design.md` (approved). Also `docs/sprints/sprint-2-design.md`, `CLAUDE.md`, `technical-design.md` sections 5 and 9.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python`. Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script.
- Work on branch `sprint-3-spell-areas`, cut from `main`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`).
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, no new autoloads, Input Map actions only. Hand-written `.tscn` needs `node_paths=PackedStringArray("prop")` for exported Node refs. Use `is_instance_of` for scene-class checks.
- No crafting, scrolls, buffs, Duplicate Area, enemy elements or vulnerability, final art or audio. No `match area`/`if area ==` anywhere in `SpellLoadout`, `Player`, `DamageSystem` or any Area script. Targeting reads `AreaData.needs_ground_target`, never the type.
- Mana never regenerates. A depleted spell never casts, spends nothing, and the loadout never auto-switches. Mana cost is an authored number on each spell, never computed from range in this sprint.
- Damage goes through `AreaEffect._configure_hitbox` (`DamageSystem.calculate`), so Sprint 4 moves the multiplier to hit time in one place.
- Collision layers unchanged. Area hitboxes use `collision_layer = 16` (PLAYER_PROJECTILE) and `collision_mask = 4` (ENEMY_HURTBOX), exactly like the Sprint 2 projectile. Every Area scene has a child named `Hitbox` (a `HitboxComponent`).
- Folders: scripts in `scripts/spells/` and `scripts/spells/areas/`, scenes in `scenes/spells/areas/`, `AreaData` files in `resources/spells/areas/`, `AreaData` class in `resources/spells/area_data.gd`.
- `AreaData` starting values (tune by playing). `default_size` means: Line width px, Cone angle degrees, Area radius px, Wave width px, Missile scale factor.

  | file | type | default_range | default_size | duration | tick_interval | widen_rate | needs_ground_target |
  |---|---|---|---|---|---|---|---|
  | `missile_area.tres` | MISSILE | 264 | 1.0 | 0 | 0 | 0 | false |
  | `line_area.tres` | LINE | 160 | 10 | 0.12 | 0 | 0 | false |
  | `cone_area.tres` | CONE | 56 | 70 | 0.12 | 0 | 0 | false |
  | `zone_area.tres` | AREA | 120 | 36 | 3.0 | 0.5 | 0 | true |
  | `wave_area.tres` | WAVE | 120 | 48 | 0 | 0 | 0.5 | false |

- Starting spells (slots 0–4, tune by playing). Colours: Fire `Color(1, 0.45, 0.1)`, Thunder `Color(1, 0.9, 0.2)`, Land `Color(0.6, 0.4, 0.2)`, Sea `Color(0.2, 0.55, 1)`. `range_scale = size_scale = 1.0`, `max_hits = 1`.

  | slot | file | element | area | damage | cast_interval | mana_cost | max_mana | projectile_speed | knockback |
  |---|---|---|---|---|---|---|---|---|---|
  | 0 | `fire_missile.tres` | FIRE | missile | 10 | 0.35 | 1 | 40 | 220 | 120 |
  | 1 | `thunder_cone.tres` | THUNDER | cone | 8 | 0.4 | 2 | 60 | (default) | 80 |
  | 2 | `land_area.tres` | LAND | zone | 12 | 1.0 | 4 | 60 | (default) | 40 |
  | 3 | `sea_line.tres` | SEA | line | 14 | 0.6 | 2 | 50 | (default) | 60 |
  | 4 | `sea_wave.tres` | SEA | wave | 12 | 0.8 | 3 | 60 | 140 | 100 |

- Perf gate: with each of the five Areas firing at 0.05 s intervals, the stress test must stay at or above 60 fps with 300 enemies (Sprint 2 Missile baseline: 696.6 fps).

## Review Focus

- Instant shapes (Line, Cone) must hit an enemy already inside the shape when cast, even though an `Area2D` needs a physics frame to see overlaps. Pinned in Task 2.
- A Cone wider than 180 degrees is concave and must still hit enemies inside it and miss those outside. Pinned in Task 2.
- Shrinking range or size to zero (a crafted "shortest" spell) must not create zero-size shapes or errors. Pinned in Task 1.
- Aiming an Area at the player's own position, or with the mouse exactly on the player, lands the zone on the player without errors. Pinned in Tasks 1 and 3.
- A depleted or Area-less spell casts nothing and spends no mana, for any Area. Pinned in Tasks 1 and 5.

---

### Task 1: AreaData, AreaEffect, SpellData reshape, Missile conversion, loadout seam

**Files:**
- Create: `resources/spells/area_data.gd`, `scripts/spells/area_effect.gd`, `resources/spells/areas/missile_area.tres`, `tests/area_test_base.gd`, `tests/test_area_data.gd`, `tests/stub_area_effect.gd`
- Move: `scripts/entities/spell_projectile.gd` to `scripts/spells/areas/missile_area.gd` (class `MissileArea`), `scenes/spells/projectiles/spell_projectile.tscn` to `scenes/spells/areas/missile_area.tscn`, `tests/test_spell_projectile.gd` to `tests/test_missile_area.gd` (use `git mv`, and move the `.uid` files too)
- Modify: `resources/spells/spell_data.gd`, `scripts/components/spell_loadout.gd`, the five existing spell `.tres` (fire, thunder, land, sea, stress_spell), `tests/test_spell_loadout.gd`, `tests/test_spell_bar.gd`, `tests/test_spell_resources.gd`, `tests/test_data_resources.gd`, `tests/test_player.gd`

**Interfaces:**
- Produces `AreaData` (`class_name AreaData extends Resource`): `enum AreaType { LINE, CONE, AREA, MISSILE, WAVE }`, and exports `type: AreaType = MISSILE`, `scene: PackedScene`, `default_range: float = 100.0`, `default_size: float = 1.0`, `duration: float = 0.0`, `tick_interval: float = 0.0`, `widen_rate: float = 0.0`, `needs_ground_target: bool = false`.
- Produces on `SpellData`: remove the `AreaType` enum, `area`, `projectile_lifetime` and `projectile_scene`. Add exports `area_data: AreaData`, `range_scale: float = 1.0`, `size_scale: float = 1.0`; constants `MIN_RANGE := 1.0`, `MIN_SIZE := 0.1`; `area_type() -> AreaData.AreaType`; `effective_range() -> float` (`maxf(area_data.default_range * range_scale, MIN_RANGE)`); `effective_size() -> float` (`maxf(area_data.default_size * size_scale, MIN_SIZE)`); `clamp_target(origin: Vector2, target: Vector2) -> Vector2` (`origin + (target - origin).limit_length(effective_range())`).
- Produces `AreaEffect` (`class_name AreaEffect extends Node2D`): `launch(spell: SpellData, origin: Vector2, direction: Vector2, target: Vector2) -> void` (base calls `push_error`, subclasses override) and `_configure_hitbox(hitbox: HitboxComponent, spell: SpellData, hit_cooldown: float) -> void` (sets `damage = DamageSystem.calculate(spell.damage, spell.primary_element())`, `knockback = spell.knockback`, `hit_cooldown`).
- Produces `MissileArea extends AreaEffect` with `direction: Vector2`, `hits: int`, and the old projectile behaviour. Lifetime is `effective_range() / projectile_speed`, node scale is `effective_size()`, `max_hits` from the spell, `hit_cooldown = lifetime + 1.0`. `launch` sets `global_position = origin`.
- Produces `SpellLoadout.try_cast(origin: Vector2, direction: Vector2, target: Vector2 = Vector2.INF) -> bool`. A non-finite `target` means "far along `direction`" (`origin + direction * 10000.0`). It returns false before spending mana if `data.area_data` or its `scene` is null.
- Produces `tests/area_test_base.gd` (`class_name AreaTestBase extends GutTest`, not run itself): `_enemy(at: Vector2) -> Enemy` (adds `base_enemy.tscn` with `add_child_autofree`), `_health(enemy) -> HealthComponent`, `_spell(area_path: String, damage := 10.0, knockback := 0.0, range_scale := 1.0, size_scale := 1.0) -> SpellData` (FIRE element, `projectile_speed = 140.0`, `area_data` loaded from the path), `_launch(spell: SpellData, origin := Vector2.ZERO, direction := Vector2.RIGHT, target := Vector2.INF) -> AreaEffect` (instantiates `spell.area_data.scene`, `add_child_autofree`, calls `launch`; a non-finite target is replaced by `origin + direction * 10000.0`).
- Produces `tests/stub_area_effect.gd` (`class_name StubAreaEffect extends AreaEffect`) recording `launched_spell`, `launched_origin`, `launched_direction`, `launched_target`.

- [ ] **Step 1: Write the failing tests.** In `tests/test_area_data.gd` (extends `GutTest`): `test_effective_range_and_size_follow_scales` (default_range 100, default_size 10, scales 2.0 and 0.5 give 200 and 5), `test_one_area_at_two_ranges` (same `AreaData`, `range_scale` 1.0 and 0.5 give 100 and 50), `test_effective_values_never_collapse_to_zero` (scales 0.0 give `MIN_RANGE` and `MIN_SIZE`), `test_area_type_comes_from_area_data` (`area_data.type = AreaType.WAVE` makes `spell.area_type() == AreaData.AreaType.WAVE`), `test_clamp_target_limits_distance_to_range` (range 100, origin (10,0), target (500,0) gives (110,0)), `test_clamp_target_keeps_closer_points_and_handles_target_on_origin` (target (50,0) stays; target equal to origin returns origin, no NaN). In `tests/test_spell_loadout.gd` add `test_try_cast_launches_the_spells_own_area_scene` (a `PackedScene` packed from a `StubAreaEffect` node, spell `area_data.scene` set to it, cast with origin (5,5), direction RIGHT, target (50,5): the stub recorded the same spell, origin, direction and target, and exactly one effect was added to the root), `test_non_finite_target_becomes_a_far_point_along_direction` (stub target is `(5,5) + RIGHT * 10000`), `test_spell_without_area_casts_nothing_and_spends_nothing` (null `area_data`: returns false, no child, mana unchanged). Update the existing tests: replace `SpellProjectile` with `MissileArea`, the spell paths stay (`fire.tres` etc., renamed in Task 5), `test_data_resources.gd` uses `AreaData.AreaType` and `area_data` instead of `area` (round-trip a `SpellData` whose `area_data.type = CONE` is not needed: assert `SpellData.new().area_data == null` and that a saved spell keeps its `range_scale`/`size_scale`), `test_spell_resources.gd` drops the `area`/`projectile_lifetime` assertions and asserts `spell.area_type() == AreaData.AreaType.MISSILE` and `spell.effective_range() == 264.0`. In `tests/test_missile_area.gd` replace the lifetime test with `test_missile_freed_after_range_over_speed` (`_physics_process(range / speed + 0.05)` queues free; a smaller `range_scale` frees sooner) and add `test_missile_size_scales_the_node` (`size_scale = 2.0` gives `scale == Vector2(2, 2)`). Launch through `AreaTestBase._launch`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full test command. Expected: failures or parse errors for the missing `AreaData`, `AreaEffect`, `MissileArea`.
- [ ] **Step 3: Implement** the interfaces above. Create `AreaData`, `AreaEffect`, and `StubAreaEffect`. Move the projectile script and scene with `git mv`, rename the class and scene root to `MissileArea`/`MissileArea` and make it extend `AreaEffect`. Write `missile_area.tres` from the table (scene = `missile_area.tscn`). Edit the five spell `.tres` files: remove `area`, `projectile_lifetime`, `projectile_scene`; add `area_data = ExtResource(missile_area.tres)` (load_steps adjusted). Update `SpellLoadout.try_cast` to the new signature (guard first, then `spell.cast()`, then instantiate `area_data.scene as AreaEffect`, `add_child`, `launch`, `cast_fired.emit`). Update `Player` to keep calling `try_cast(global_position, _aim.aim_direction)` (target default). Update `stress_test.gd` only if it references removed fields (it does not).
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: AreaData and AreaEffect seam; Missile becomes an Area"`, with the trailer.

---

### Task 2: Line and Cone

**Files:**
- Create: `scripts/spells/areas/line_area.gd`, `scripts/spells/areas/cone_area.gd`, `scenes/spells/areas/line_area.tscn`, `scenes/spells/areas/cone_area.tscn`, `resources/spells/areas/line_area.tres`, `resources/spells/areas/cone_area.tres`, `tests/test_line_area.gd`, `tests/test_cone_area.gd`

**Interfaces:**
- Consumes: `AreaEffect`, `AreaData`, `SpellData.effective_range()/effective_size()`, `AreaTestBase` from Task 1.
- Produces `LineArea` and `ConeArea` (both `extends AreaEffect`). Each scene is a `Node2D` root with a `Hitbox` (`HitboxComponent`, layer 16, mask 4, `max_hits = 0`, one `CollisionShape2D` or `CollisionPolygon2D` built in `launch`) and a visual in the spell colour that fades over the window. `launch` places the root at `origin`, rotates it to `direction`, builds the shape from `effective_range()` and `effective_size()`, calls `_configure_hitbox(hitbox, spell, area_data.duration + 1.0)` (once per enemy per cast), and frees the node after `area_data.duration` seconds of `_physics_process`.
- Line shape: rectangle, length `effective_range()`, width `effective_size()`, starting at the origin. Cone shape: a sector with reach `effective_range()` and angle `clampf(effective_size(), 1.0, 360.0)` degrees centred on the direction (a polygon fan with at least 8 arc points).

- [ ] **Step 1: Write the failing tests.** Both files extend `AreaTestBase` and use `await wait_physics_frames(4)` after launching. Line (range 160, width 10, origin (0,0), direction RIGHT): `test_line_hits_every_enemy_along_it_once` (enemies at (40,0), (90,0), (140,0) each lose exactly `damage` after 8 frames: `health == max_health - spell.damage`), `test_line_misses_enemies_outside_it` (enemies at (40,20), (200,0), (-40,0) untouched), `test_line_range_scale_shortens_it` (enemy at (140,0) is hit with `range_scale = 1.0` and untouched with `0.5`), `test_line_carries_damage_and_knockback` (the `Hitbox` has `damage == DamageSystem.calculate(spell.damage, spell.primary_element())` and the spell's `knockback`), `test_line_frees_itself_after_its_window` (`_physics_process(area_data.duration + 0.05)` queues free), `test_line_follows_direction` (direction DOWN hits an enemy at (0,90), misses one at (90,0)). Cone (range 56, angle 70, RIGHT): `test_cone_hits_enemies_inside_it_once` (enemies at (30,0) and (30,15) hit once each), `test_cone_misses_outside_angle_range_and_behind` (enemies at (20,40), (90,0), (-30,0) untouched), `test_cone_wider_than_180_still_hits_inside_and_misses_outside` (`size_scale = 240.0 / 70.0`: enemy at (-10,40) hit, enemy at (-35,20) untouched), `test_cone_range_scale_shortens_it` (enemy at (50,0) hit with 1.0, untouched with 0.5), plus the same carries-damage, frees-itself and follows-direction tests.
- [ ] **Step 2: Run to verify they fail** (`-gselect=test_line_area`, `-gselect=test_cone_area`). Expected: fail, scenes and classes missing.
- [ ] **Step 3: Implement** `LineArea`, `ConeArea`, their scenes (hand-written `.tscn`, `Hitbox` child with the same layers and mask as `missile_area.tscn`) and the two `.tres` from the table.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, both files, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: Line and Cone areas"`, with the trailer.

---

### Task 3: Area (ground zone) and Wave

**Files:**
- Create: `scripts/spells/areas/zone_area.gd`, `scripts/spells/areas/wave_area.gd`, `scenes/spells/areas/zone_area.tscn`, `scenes/spells/areas/wave_area.tscn`, `resources/spells/areas/zone_area.tres`, `resources/spells/areas/wave_area.tres`, `tests/test_zone_area.gd`, `tests/test_wave_area.gd`

**Interfaces:**
- Consumes: Task 1 interfaces. `SpellData.clamp_target`.
- Produces `ZoneArea` (`class_name ZoneArea`, the Area type) and `WaveArea`, both `extends AreaEffect`, both with a `Hitbox` child as in Task 2.
- `ZoneArea.launch`: places itself at `spell.clamp_target(origin, target)`, builds a circle of radius `effective_size()`, `_configure_hitbox(hitbox, spell, area_data.tick_interval)` (an enemy inside is hit once per tick), `max_hits = 0`, visual in the spell colour, frees after `area_data.duration` of `_physics_process`.
- `WaveArea.launch`: starts at `origin`, rotated to `direction`, moves at `spell.projectile_speed`, frees after travelling `effective_range()`, hits each enemy once (`hit_cooldown` longer than its travel time, `max_hits = 0`, so hits never free it). Shape is a crescent: a thin curved band spanning `current_width()`. `current_width() -> float` returns `effective_size() * (1.0 + area_data.widen_rate * elapsed)` where `elapsed` is the seconds travelled, and the hitbox and visual follow it.

- [ ] **Step 1: Write the failing tests.** Zone (range 120, radius 36, duration 3.0, tick 0.5; origin (0,0), direction RIGHT): `test_zone_lands_at_the_target_when_in_range` (target (80,0): `global_position == (80,0)`), `test_zone_target_is_clamped_to_range` (target (500,0) gives `(120,0)`), `test_zone_with_target_on_the_player_lands_on_the_player` (target (0,0) gives `(0,0)`), `test_zone_hits_enemies_inside_not_outside` (enemy at (80,0) hit, at (80,60) untouched, after 8 frames), `test_zone_ticks_on_its_interval` (the `Hitbox.hit_cooldown == 0.5`; with a hurtbox, `try_hit(hurtbox, 1000)` is true, `try_hit(hurtbox, 1499)` false, `try_hit(hurtbox, 1500)` true), `test_zone_ends_after_its_duration` (`_physics_process(3.05)` queues free), `test_zone_range_scale_moves_the_clamp_in` (`range_scale = 0.5` and target (500,0) gives `(60,0)`). Wave (range 120, width 48, widen 0.5, speed 140): `test_wave_moves_at_spell_speed` (after `_physics_process(0.5)` `position.x` is about 70, `position.y` about 0), `test_wave_widens_while_travelling` (`current_width()` is 48 at launch and 60 after 0.5 s), `test_wave_ends_at_range` (`_physics_process(120.0 / 140.0 + 0.05)` queues free; `range_scale = 0.5` ends it after about 0.43 s), `test_wave_hits_every_enemy_it_passes_once_and_keeps_going` (enemies at (30,0), (60,0), (90,0); after `await wait_physics_frames(40)` each lost exactly `damage` and the wave is valid and not queued for deletion), `test_wave_misses_enemies_outside_its_width` (enemy at (60,60) untouched), `test_wave_carries_damage_and_knockback`.
- [ ] **Step 2: Run to verify they fail.** Expected: fail, classes missing.
- [ ] **Step 3: Implement** both Areas, scenes and `.tres` files from the table. A `ZoneArea` with a null or zero `tick_interval` must still tick (treat 0 as "once"), so it never errors.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, both files, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: ground Area and Wave"`, with the trailer.

---

### Task 4: Aim point, target reticle, wiring

**Files:**
- Create: `scripts/ui/target_reticle.gd`, `scenes/ui/target_reticle.tscn`, `tests/test_target_reticle.gd`
- Modify: `scripts/components/aim_component.gd`, `scripts/entities/player.gd`, `scenes/main/main.tscn`, `scripts/main/main.gd`, `tests/test_aim_component.gd`, `tests/test_player.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `SpellData.clamp_target`, `AreaData.needs_ground_target`, `SpellLoadout.try_cast(origin, direction, target)`.
- Produces `AimComponent.FAR_DISTANCE := 10000.0` and `aim_point: Vector2`. When the source is MOUSE, `aim_point` is the mouse position passed to `update_aim`. When it is STICK, `aim_point = origin + aim_direction * FAR_DISTANCE`, recomputed every call so it follows the player when the stick is released. `update_aim`'s signature is unchanged.
- Produces `Player.aim` (the `AimComponent`, public, replacing `_aim`), and `Player` casts with `loadout.try_cast(global_position, aim.aim_direction, aim.aim_point)`.
- Produces `TargetReticle` (`class_name TargetReticle extends Node2D`): `bind(player: Player) -> void`. Each `_process` it is visible only if the player is alive, the selected spell exists, and its `area_data.needs_ground_target` is true; then `global_position = spell.clamp_target(player.global_position, player.aim.aim_point)`. It draws a small ring in `_draw`. It never changes gameplay data. `Main` adds a `TargetReticle` node and binds it.

- [ ] **Step 1: Write the failing tests.** `test_aim_component.gd`: `test_mouse_aim_point_is_the_cursor` (`update_aim(Vector2(10,10), Vector2(10,50), ZERO, false, true)` gives `aim_point == (10,50)`), `test_stick_aim_point_is_far_along_the_direction` (stick `(0,-1)` from origin (5,5): `aim_point == (5,5) + UP * AimComponent.FAR_DISTANCE`), `test_stick_aim_point_follows_the_origin_after_release` (after a stick aim, a call with a new origin (50,0) and no stick, no mouse move, gives `(50,0) + UP * FAR_DISTANCE`), `test_mouse_exactly_on_the_player_keeps_a_finite_aim_point` (origin equals mouse: `aim_point == origin`, direction unchanged). `test_target_reticle.gd` (builds a `Player` under a per-test root and a reticle, calls `bind`, sets `player.aim.aim_point` and calls `_process(0.0)`): `test_reticle_hidden_for_a_missile_spell` (default slot 0 is Fire Missile), `test_reticle_shows_at_the_clamped_target_for_a_ground_spell` (swap `player.loadout.slots[0]` to an instance of a spell whose `area_data.needs_ground_target = true`, range 100, `aim_point` (300,0) from player at (0,0): visible, position (100,0); `aim_point` (40,0): position (40,0)), `test_reticle_hides_when_the_player_dies`. `test_player.gd`: `test_player_exposes_its_aim_component` (`player.aim` is the `AimComponent` child); keep the existing projectile-count tests, now counting `MissileArea`. `test_main.gd`: `test_main_has_a_bound_target_reticle` (node `TargetReticle` exists and is hidden at start).
- [ ] **Step 2: Run to verify they fail.** Expected: failures for the missing property and class.
- [ ] **Step 3: Implement** the interfaces above. Add `TargetReticle` to `main.tscn` (instanced scene, after `Player`), bind in `Main._ready` with `_reticle.bind(_player)`. Mark the reticle TEMPORARY in its script header.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: aim point and target reticle for ground-targeted spells"`, with the trailer.

---

### Task 5: The five spells, slots and the stress test option

**Files:**
- Move: `resources/spells/fire.tres` to `fire_missile.tres`, `thunder.tres` to `thunder_cone.tres`, `land.tres` to `land_area.tres`, `sea.tres` to `sea_line.tres` (with `git mv`, then rewrite the values)
- Create: `resources/spells/sea_wave.tres`
- Modify: `scenes/player/player.tscn`, `scripts/dev/stress_test.gd`, `resources/spells/stress_spell.tres` (unchanged values, check it still loads), `tests/test_spell_resources.gd`, `tests/test_spell_loadout.gd`, `tests/test_spell_bar.gd`, `tests/test_player.gd`

**Interfaces:**
- Consumes: all five `AreaData` files.
- Produces the five spell files in the Global Constraints table, with `id` and `display_name` set (`fire_missile`/"Fire Missile", `thunder_cone`/"Thunder Cone", `land_area`/"Land Area", `sea_line`/"Sea Line", `sea_wave`/"Sea Wave").
- Produces `--area=<missile|line|cone|zone|wave>` for the stress test: it loads the matching spell (`fire_missile`, `sea_line`, `thunder_cone`, `land_area`, `sea_wave`), duplicates it with `max_mana = 1.0e9` and `cast_interval = 0.05`, and puts it in slot 0. With no `--area`, it keeps using `stress_spell.tres`.

- [ ] **Step 1: Write the failing tests.** `test_spell_resources.gd`: a table of path, element, area type, damage, interval, cost, max mana, knockback for all five spells (values from the Global Constraints), asserting each field, `spell.area_type()`, `spell.mana_cost <= spell.max_mana`, `range_scale == 1.0`, `size_scale == 1.0`, and `projectile_speed` 220 for Fire Missile and 140 for Sea Wave. Add `test_each_area_has_a_distinct_default_range_role` (`cone_area.default_range < line_area.default_range`, and all five `AreaData` types differ). `test_spell_loadout.gd`: replace `PATHS` with the five new paths (all five slots filled), update `test_four_slots_filled_and_fifth_empty` to `test_five_slots_filled`, and update tests that assumed an empty slot 4 (use `null` explicitly where they need one). Add `test_depleted_area_spell_spawns_nothing` for slots 1 to 4 (each drained spell casts nothing, spends nothing, and the selection does not change). `test_spell_bar.gd`: `PATHS` becomes the five new paths. `test_player.gd`: the starting slots are the five files in order.
- [ ] **Step 2: Run to verify they fail.** Expected: failures for the missing paths and values.
- [ ] **Step 3: Implement.** `git mv` the four files, write all five `.tres` files from the table, point `player.tscn` at them (`starting_spells` has five entries, no null). Add `--area=` to `stress_test.gd`.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors. Then run the game once through the godot MCP (`run_project`, then `get_debug_output`, then `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: five starting spells, one per Area, and a stress-test area option"`, with the trailer.

---

### Task 6: Docs, stress measurements, wrap-up

**Files:**
- Modify: `README.md` (Area Scrolls: add **Wave**, update the Available Areas list and the example spell table with `Sea Wave | Sea + Wave | Moving wall of damage`, and any "four Areas" wording), `technical-design.md` (section 9: add `9.5 Wave`, say five Areas, and note the `AreaData` plus one-scene-per-Area structure), `sprint-development.md` (Sprint 3: add Wave tasks, tick every completed box, change "all four Area types"/"All four Areas" to five, add a Built note), `CLAUDE.md` (Project State, plus a "Spell architecture (Sprint 3)" section), `development-log.md`, `docs/sprints/sprint-3-design.md` (Status: Built)

**Interfaces:** none (documentation and measurement).

- [ ] **Step 1: Run the stress test for each Area.** For each of `missile`, `line`, `cone`, `zone`, `wave`: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=10 --area=<name>`. Record the `STRESS` line for each. Expected: `avg_fps` of at least 60 for all five. If any is below 60, stop and report it before continuing.
- [ ] **Step 2: Update the docs** listed above. In `development-log.md` add a "Sprint 3 (spell areas)" entry: the decisions and calls from `docs/sprints/sprint-3-design.md`, the starting numbers, and a table of the five stress results beside the Sprint 2 Missile baseline (696.6 fps at 300 enemies). Note that damage is still worked out at cast time and Sprint 4 must move the multiplier to hit time through `AreaEffect._configure_hitbox`.
- [ ] **Step 3: Run the full suite** and the smoke run. Expected: all pass, no errors.
- [ ] **Step 4: Commit.** `git add -A && git commit -m "docs: Sprint 3 complete"`, with the trailer.
