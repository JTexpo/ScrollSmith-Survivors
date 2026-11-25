# Sprint 4 Elemental Affinities and Enemy Variety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make elemental spell choice matter. Enemies get an element, an attack carries its element to the moment it lands, the element table decides strong, weak or normal damage, and damage numbers show the result.

**Architecture:** `HitboxComponent.element` (attacker) and `HurtboxComponent.element` (defender) meet in `HurtboxComponent.receive_hit`, which asks `DamageSystem` for the final damage and the hit's `ElementTable.Effect`. Five `EnemyData` resources (plain plus four elements) feed a weighted `EnemySpawner` pool. `Enemy` emits `damaged`, the spawner re-emits it, and `Main` routes it to a pooled `DamageNumbers` node that draws every number in one `_draw`.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-4-design.md` (approved). Also `docs/sprints/sprint-3-design.md`, `CLAUDE.md`, `technical-design.md` section 8.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`.
- Work on branch `sprint-4-elemental-enemies`, cut from `main`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`).
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, no new autoloads, Input Map actions only. Hand-written `.tscn` needs `node_paths=PackedStringArray("prop")` for exported Node refs.
- Elemental math lives only in `ElementTable` and `DamageSystem`. No `if enemy is Fire`, no per-element code in spells, hitboxes, hurtboxes or enemies. Fire > Land > Thunder > Sea > Fire. An enemy takes the strong multiplier (1.5) from the element that beats it and the weak multiplier (0.5) from the one it beats. **Same element is normal damage** (user decision). No element on either side is normal damage.
- For now the player's hurtbox has no element and enemy contact hitboxes carry none, so hits on the player are neutral. This is only today's default, not a rule: the player's `HurtboxComponent.element` is an ordinary property, so Sprint 9 equipment (robes, hats) can give the player resistances or vulnerabilities without touching the damage code. Don't hardcode "the player is neutral" anywhere, and write it up that way in the docs. Enemies stay light `Node2D`s moved by position. Collision layers unchanged.
- No new enemy behaviours, waves, buffs, multi-element spells, XP, final art, or an in-game element legend.
- Enemy stats (all in `.tres`, tune by playing). All keep `contact_cooldown = 1.0`, `contact_knockback = 80.0`, `speed_variation = 0.15`, `offset_radius = 24.0`.

  | file | element | max_health | contact_damage | speed | color | spawn_weight |
  |---|---|---|---|---|---|---|
  | `basic_enemy.tres` | none (-1) | 20 | 10 | 40 | `Color(0.75, 0.75, 0.75)` | 1.0 |
  | `fire_enemy.tres` | FIRE (0) | 16 | 12 | 55 | `Color(1, 0.45, 0.1)` | 2.0 |
  | `thunder_enemy.tres` | THUNDER (1) | 12 | 8 | 75 | `Color(1, 0.9, 0.2)` | 2.0 |
  | `land_enemy.tres` | LAND (2) | 50 | 14 | 28 | `Color(0.6, 0.4, 0.2)` | 2.0 |
  | `sea_enemy.tres` | SEA (3) | 24 | 10 | 42 | `Color(0.2, 0.55, 1)` | 2.0 |

- Damage numbers: pool of 64, lifetime 0.6 s, rise 18 px. Neutral: white `Color.WHITE`, font size 8, no suffix. Vulnerable: yellow `Color(1, 0.9, 0.2)`, size 12, suffix "!". Resisted: grey `Color(0.6, 0.6, 0.6)`, size 6, no suffix. Text is the amount rounded to an integer, at least 1.
- Perf gate: the stress test (300 enemies, now elemental, with damage numbers) must stay at or above 60 fps (Sprint 3 Missile baseline: 720 fps).

## Review Focus

- A single cast that hits enemies of different elements (Line, Wave, Zone) must give each enemy its own multiplier. Pinned in Task 2.
- A killing hit must still emit `damaged` exactly once with the final amount, and must not error. Pinned in Task 2.
- A burst of hits (zone ticks, 300 enemies) must never grow the number pool past 64 or leave the node processing when idle. Pinned in Task 4.
- An empty pool, or a pool whose weights are all zero, must spawn nothing without errors. Pinned in Task 3.
- An unknown or out-of-range element value (for example 99) on either side must behave as normal damage without errors. Pinned in Task 1.

---

### Task 1: Hit-time elements

**Files:**
- Modify: `resources/spells/element_table.gd`, `scripts/systems/damage_system.gd`, `scripts/components/hitbox_component.gd`, `scripts/components/hurtbox_component.gd`, `scripts/spells/area_effect.gd`, `scripts/entities/player.gd`, `scripts/entities/enemy.gd` (handler signature only), `tests/test_element_table.gd`, `tests/test_damage_system.gd`, `tests/test_hurtbox_hitbox.gd`, `tests/test_missile_area.gd`

**Interfaces:**
- Produces `ElementTable.Effect { NEUTRAL, VULNERABLE, RESISTED }` and `ElementTable.effect(attacker: int, defender: int) -> Effect` (VULNERABLE when `BEATS[attacker] == defender`, RESISTED when `BEATS[defender] == attacker`, else NEUTRAL, including when either is `NO_ELEMENT` or unknown). `multiplier(attacker, defender)` returns the strong, weak or neutral multiplier according to `effect`.
- Produces `DamageSystem.effect(attacker: int, defender: int, table: ElementTable = null) -> ElementTable.Effect`. `calculate` keeps its signature.
- Produces `HitboxComponent.element: int = SpellData.NO_ELEMENT`, passed by `try_hit` as the new last argument of `receive_hit`.
- Produces `HurtboxComponent.element: int = SpellData.NO_ELEMENT`, `receive_hit(damage: float, source_position: Vector2, knockback: float = 0.0, attacker_element: int = SpellData.NO_ELEMENT) -> bool` (final damage is `DamageSystem.calculate(damage, attacker_element, element)`), and the signal `hit_received(damage: float, source_position: Vector2, knockback: float, effect: int)` where `effect` is an `ElementTable.Effect`.
- `AreaEffect._configure_hitbox` sets `hitbox.damage = spell.damage` (raw) and `hitbox.element = spell.primary_element()`.

- [ ] **Step 1: Write the failing tests.** `test_element_table.gd`: `test_effect_for_every_pair` (strong pairs give VULNERABLE, weak pairs RESISTED, same element NEUTRAL, `NO_ELEMENT` on either side NEUTRAL), `test_unknown_element_values_are_neutral` (`effect(FIRE, 99)` and `effect(99, FIRE)` and `multiplier(99, 99)` are neutral), `test_multiplier_agrees_with_effect`. `test_damage_system.gd`: `test_effect_helper_uses_the_default_table`. `test_hurtbox_hitbox.gd`: update the existing signal assertion to `[4.0, Vector2(-10, 0), 50.0, ElementTable.Effect.NEUTRAL]`, and add `test_hit_applies_the_multiplier_at_impact` (hp 30; hurtbox element LAND, `receive_hit(10.0, ZERO, 0.0, FIRE)` leaves 15, signal effect VULNERABLE; element SEA with FIRE leaves 25 after 5 damage, effect RESISTED; element FIRE with FIRE leaves 20 after 10, effect NEUTRAL; no element on the hurtbox is 10 damage), `test_hitbox_passes_its_element_to_the_hurtbox` (`hitbox.element = FIRE`, hurtbox element LAND, `try_hit` deals 15). `test_missile_area.gd`: update `test_hitbox_carries_spell_damage_and_knockback` to assert `hitbox.damage == spell.damage` and `hitbox.element == SpellData.Element.FIRE`, and add `test_fire_missile_is_multiplied_when_it_lands` (an enemy whose hurtbox `element` is set to LAND loses 15 of 20, one set to SEA loses 5).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures or parse errors for the missing `Effect`, `effect`, `element`.
- [ ] **Step 3: Implement** the interfaces above. Update the `_on_hit_received` handlers in `player.gd` and `enemy.gd` to take the fourth parameter (unused for now, prefix it with an underscore).
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: apply elemental multipliers at impact"`, with the trailer.

---

### Task 2: Elemental enemies

**Files:**
- Create: `resources/enemies/fire_enemy.tres`, `thunder_enemy.tres`, `land_enemy.tres`, `sea_enemy.tres`
- Modify: `resources/enemies/enemy_data.gd`, `resources/enemies/basic_enemy.tres`, `scripts/entities/enemy.gd`, `tests/test_enemy.gd`, `tests/test_data_resources.gd` (only if it checks enemy defaults)

**Interfaces:**
- Consumes: `HurtboxComponent.element`, `hit_received(..., effect)` from Task 1.
- Produces on `EnemyData`: `@export_enum("None:-1", "Fire:0", "Thunder:1", "Land:2", "Sea:3") var element: int = -1`, `@export var color: Color = Color(0.75, 0.75, 0.75)`, `@export var spawn_weight: float = 1.0`.
- Produces `Enemy.damaged(position: Vector2, amount: float, effect: int)`, emitted from the hit handler with `global_position`, the final dealt damage and the effect. `Enemy._apply_data` also sets `$HurtboxComponent.element = data.element` and `$Body.color = data.color`. The `ContactHitbox` element stays `NO_ELEMENT`.

- [ ] **Step 1: Write the failing tests** in `test_enemy.gd`: `test_enemy_data_files_match_the_stat_table` (all five files: element, max_health, contact_damage, speed, color, spawn_weight from the Global Constraints table, plus the shared cooldown, knockback, variation and offset), `test_enemy_takes_its_element_and_colour_from_data` (an enemy set up with `land_enemy.tres`: `HurtboxComponent.element == LAND`, `Body.color == data.color`, `ContactHitbox.element == SpellData.NO_ELEMENT`, and the plain enemy's hurtbox element is `NO_ELEMENT`), `test_contact_damage_on_the_player_is_neutral_for_every_enemy` (each enemy's `ContactHitbox.damage == data.contact_damage`), `test_damaged_signal_carries_final_amount_and_effect` (a Land enemy hit by `receive_hit(10.0, ZERO, 0.0, FIRE)` emits `damaged` with `[enemy.global_position, 15.0, ElementTable.Effect.VULNERABLE]`; a Sea enemy with FIRE emits 5.0 and RESISTED; a Fire enemy with FIRE emits 10.0 and NEUTRAL), `test_killing_hit_emits_damaged_once` (a plain enemy hit by `receive_hit(1000.0, ZERO)` emits `damaged` once with 1000.0, and `died` once), `test_one_cast_gives_each_element_its_own_multiplier` (a Line spell cast through `AreaTestBase`-style helpers over a Fire enemy and a Sea enemy side by side, both set up from their data, Fire spell: the Sea enemy loses 5 and the Fire enemy loses 10, so use enemies with enough health, for example the Land enemy for the strong case at 15). Put the last test in a new `tests/test_enemy_elements.gd` extending `AreaTestBase` (cast from `Vector2(300, 150)` as in the Line tests).
- [ ] **Step 2: Run to verify they fail.** Expected: failures for the missing fields and files.
- [ ] **Step 3: Implement** `EnemyData` fields, the five `.tres` files from the table (set `basic_enemy.tres` colour and weight too), `_body` onready and `_apply_data` additions, and the `damaged` emit in `_on_hit_received` (the handler takes `damage, source_position, knockback, effect`).
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: elemental enemy data and damaged signal"`, with the trailer.

---

### Task 3: Weighted spawn pool

**Files:**
- Modify: `resources/spawning/spawn_config.gd`, `resources/spawning/default_spawn_config.tres`, `scripts/systems/enemy_spawner.gd`, `tests/test_enemy_spawner.gd`

**Interfaces:**
- Consumes: `EnemyData.spawn_weight`, `Enemy.damaged` from Task 2.
- Produces `SpawnConfig.enemy_pool: Array[EnemyData]` (replaces `enemy_data`). `EnemySpawner.pick_enemy_data() -> EnemyData` picks by `spawn_weight` with the spawner's own `rng` (negative weights count as zero) and returns null for a null config, an empty pool or a zero total. `try_spawn()` returns null when it picks nothing, and `spawn_at(position)` uses `pick_enemy_data()` and returns null when it picks nothing. New signal `EnemySpawner.enemy_damaged(position: Vector2, amount: float, effect: int)` re-emitted for every spawned enemy's `damaged`.
- `default_spawn_config.tres` lists the five enemies (plain first).

- [ ] **Step 1: Write the failing tests.** Update `_make_spawner` in `test_enemy_spawner.gd` to set `config.enemy_pool` to `[basic_enemy.tres]` and keep the existing tests green. Add `test_pick_covers_every_pool_entry` (the five files, seed 7, 500 draws: every one appears), `test_pick_respects_weights` (pool of two copies of the plain data, one with `spawn_weight` 1.0 and one 3.0 via duplicates, 1000 draws: the heavier is picked more than twice as often as the lighter), `test_single_entry_pool_always_picks_it`, `test_empty_pool_and_zero_weights_spawn_nothing` (`pick_enemy_data()` is null, `try_spawn()` is null, `alive == 0`, for an empty pool and for all weights 0.0, with no errors), `test_spawned_enemy_uses_data_from_the_pool` (the spawned enemy's `data` is in the pool), `test_enemy_damaged_is_re_emitted` (spawn one, `watch_signals(spawner)`, hit its hurtbox with `receive_hit(10.0, ZERO, 0.0, FIRE)`: `enemy_damaged` was emitted once with the enemy's position and the same amount and effect as its own `damaged`).
- [ ] **Step 2: Run to verify they fail.** Expected: failures for the missing `enemy_pool`, `pick_enemy_data`, signal.
- [ ] **Step 3: Implement** the interfaces, and rewrite `default_spawn_config.tres` with the pool of five.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: weighted enemy pool and enemy_damaged signal"`, with the trailer.

---

### Task 4: DamageNumbers

**Files:**
- Create: `scripts/ui/damage_numbers.gd`, `tests/test_damage_numbers.gd`

**Interfaces:**
- Produces `DamageNumbers` (`class_name DamageNumbers extends Node2D`, TEMPORARY look, `z_index = 10`): constants `POOL_SIZE := 64`, `LIFETIME := 0.6`, `RISE := 18.0`; `show_number(position: Vector2, amount: float, effect: int) -> void` (position is global); `active_count() -> int`; `active_texts() -> Array[String]` in the order they were shown (for tests); `static style_for(effect: int) -> Dictionary` with keys `color`, `size`, `suffix` from the Global Constraints. A fixed array of records (position, text, effect, age); when full, the oldest is replaced. The node starts not processing, processes only while numbers are alive, redraws only while alive, and turns processing off again when the last number expires. `_draw` draws each number with `ThemeDB.fallback_font`, rising `RISE * age / LIFETIME` and fading out.

- [ ] **Step 1: Write the failing tests.** `test_starts_idle` (`active_count() == 0`, `is_processing()` false), `test_show_number_activates_it` (count 1, processing true), `test_text_rounds_and_is_at_least_one` (14.6 shows "15", 0.4 shows "1", and a vulnerable hit appends "!": 15.0 with VULNERABLE shows "15!"), `test_numbers_expire_and_processing_stops` (`_process(LIFETIME + 0.01)` leaves count 0 and processing false), `test_never_exceeds_the_pool` (200 shows leave `active_count() == POOL_SIZE`), `test_full_pool_replaces_the_oldest` (show amounts 1 to 64, then 65: the texts no longer contain "1" and do contain "65"), `test_style_by_effect` (`style_for` NEUTRAL is white size 8 empty suffix, VULNERABLE yellow size 12 "!", RESISTED grey size 6 empty suffix, and an unknown effect value falls back to the neutral style), `test_numbers_age_independently` (show one, `_process(0.4)`, show another, `_process(0.3)`: only the second is left).
- [ ] **Step 2: Run to verify they fail.** Expected: fail, class missing.
- [ ] **Step 3: Implement** `DamageNumbers` per the interface.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, the file, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: pooled damage numbers"`, with the trailer.

---

### Task 5: Wiring and the stress test

**Files:**
- Modify: `scripts/main/main.gd`, `scenes/main/main.tscn`, `scenes/world/stress_test.tscn`, `scripts/dev/stress_test.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `EnemySpawner.enemy_damaged`, `DamageNumbers.show_number` from Tasks 3 and 4.
- Produces a `DamageNumbers` node named `DamageNumbers` in `main.tscn` and `stress_test.tscn` (a plain `Node2D` at the origin, so its local and global positions match), with `Main._ready` and `StressTest._ready` connecting `EnemySpawner.enemy_damaged` to `DamageNumbers.show_number`.

- [ ] **Step 1: Write the failing test** in `test_main.gd`: `test_enemy_hits_show_damage_numbers` (instantiate `main.tscn`, spawn an enemy with `EnemySpawner.spawn_at(Vector2(100, 100))`, hit its hurtbox with `receive_hit(10.0, ZERO, 0.0, FIRE)`: `DamageNumbers.active_count() == 1`, and hitting the player's hurtbox shows no number).
- [ ] **Step 2: Run to verify it fails.** Expected: node missing.
- [ ] **Step 3: Implement** the nodes and connections. In `stress_test.gd`, connect in `_ready` before enemies are spawned.
- [ ] **Step 4: Run to verify it passes.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Then run the game once through the godot MCP (`run_project`, `get_debug_output`, `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: damage numbers wired into Main and the stress test"`, with the trailer.

---

### Task 6: Docs, stress measurements, wrap-up

**Files:**
- Modify: `README.md` (Elemental Affinities: replace "a Fire enemy may resist Fire damage but be vulnerable to Sea damage" with "a Fire enemy takes extra damage from Sea and reduced damage from Land, and normal damage from Fire and Thunder"), `technical-design.md` (section 8.2: enemies have one element and vulnerability and resistance come from the table, with per-enemy overrides left for later), `sprint-development.md` (tick every Sprint 4 box that is built, plus a Built note), `CLAUDE.md` (Project State, a "Elemental enemies (Sprint 4)" section, and fix the Sprint 2 line saying nothing passes a defender element yet), `development-log.md`, `docs/sprints/sprint-4-design.md` (Status: Built)

**Interfaces:** none (documentation and measurement).

- [ ] **Step 1: Run the stress test** at 300 enemies for the default Missile, `--area=wave` and `--area=zone`: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=10` (and with `--area=wave`, `--area=zone`). Record the `STRESS` lines. Expected: `avg_fps` of at least 60 for all three. If any is below 60, stop and report it before continuing.
- [ ] **Step 2: Update the docs** listed above. In `development-log.md` add a "Sprint 4 (elemental enemies)" entry: the decisions and calls from `docs/sprints/sprint-4-design.md`, the enemy stats, a note that the Sprint 2 cast-time limitation is gone, the known limitations (overkill damage numbers show full damage, which the user is happy with, and no in-game legend of the element cycle), and a note that the player has no element by default but the hurtbox property lets equipment add one later, and the stress table beside the Sprint 3 numbers.
- [ ] **Step 3: Run the full suite** and the smoke run. Expected: all pass, no errors.
- [ ] **Step 4: Commit.** `git add -A && git commit -m "docs: Sprint 4 complete"`, with the trailer.
