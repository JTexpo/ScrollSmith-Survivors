# Sprint 2 Base Spell System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Sprint 1 stand-in attack with four data-driven elemental spells (Fire, Thunder, Land, Sea), each cast from its own non-regenerating mana pool, selected from five slots by keyboard, controller or on-screen buttons.

**Architecture:** `SpellData` (Resource) is static configuration. `SpellInstance` (plain `RefCounted`) is built from it and owns current mana and the cast cooldown, so two instances of one definition never share mana. A `SpellLoadout` component on the player holds five slots and the selected index and spawns the spell projectile. `DamageSystem` gains an `ElementTable`-driven elemental multiplier. A temporary `SpellBar` HUD reads the loadout.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing Sprint 0 and 1 code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-2-design.md` (approved). Also `docs/sprints/sprint-0-design.md`, `docs/sprints/sprint-1-design.md`, `CLAUDE.md`, `technical-design.md` section 5.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python`. Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding a `class_name` script.
- Work on branch `sprint-2-base-spells`, cut from `main`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE naming, one responsibility per script, no new autoloads, Input Map actions only, device `-1` on every input event.
- No Areas (Sprint 3), enemy elements or vulnerability feedback (Sprint 4), scrolls, crafting, buffs, multi-Base rules, slot unlocks, potions, or final art/audio. Don't build later-sprint features.
- Mana never regenerates. A depleted spell never casts, never spends anything, and the loadout never auto-switches.
- Elemental math lives only in `DamageSystem` and `ElementTable`. Fire > Land > Thunder > Sea > Fire. Multipliers start at strong 1.5, weak 0.5, neutral 1.0 and are `@export`s on `ElementTable`.
- Gameplay numbers live in `.tres` Resources. Starting values (tune by playing), all with `area = MISSILE`, `max_hits = 1`, lifetime 1.2 s:

  | Spell | damage | cast_interval | mana_cost | max_mana | projectile_speed | knockback | colour |
  |---|---|---|---|---|---|---|---|
  | Fire | 10 | 0.35 | 1 | 40 | 220 | 120 | orange `Color(1, 0.45, 0.1)` |
  | Thunder | 7 | 0.18 | 1 | 60 | 300 | 80 | yellow `Color(1, 0.9, 0.2)` |
  | Land | 18 | 0.7 | 2 | 40 | 160 | 220 | brown `Color(0.6, 0.4, 0.2)` |
  | Sea | 9 | 0.3 | 1 | 45 | 200 | 60 | blue `Color(0.2, 0.55, 1)` |

- Slots: indices 0–4. Slots 0–3 hold Fire, Thunder, Land, Sea. Slot 4 is empty. Starting selection is slot 0.
- Collision layers unchanged: `WORLD`=1, `PLAYER_HURTBOX`=2, `ENEMY_HURTBOX`=4, `ENEMY_HITBOX`=8, `PLAYER_PROJECTILE`=16.
- The Player holds no spell rules beyond input wiring. UI reads from systems and never mutates gameplay data (touch taps call the same `select` the keys do).
- Perf gate: the Sprint 1 stress test must still reach 60 fps at 300 enemies (it was 733 fps avg on the user's M1).

## Review Focus

- Holding fire on a depleted spell: no projectile, no mana change, no auto-switch, and the dry cue fires once per press, not every frame. Pinned in Task 5.
- Two instances built from one `SpellData` share no mana. Pinned in Task 2.
- Selecting an empty slot, an out-of-range index, or cycling with one or zero filled slots leaves the selection unchanged without errors. Pinned in Task 5.
- A dead player casts nothing and ignores slot keys. Pinned in Task 6.
- Tapping a slot widget selects it and does not press `cast`. A tap outside any widget, or on a hidden bar, is ignored. Pinned in Task 7.
- A piercing projectile (`max_hits` above 1) hits distinct enemies and never the same enemy twice. Pinned in Task 3.

---

### Task 1: ElementTable and elemental DamageSystem

**Files:**
- Create: `resources/spells/element_table.gd`, `resources/spells/element_table.tres`, `tests/test_element_table.gd`
- Modify: `resources/spells/spell_data.gd` (add `const NO_ELEMENT := -1`), `scripts/systems/damage_system.gd`, `tests/test_damage_system.gd`

**Interfaces:**
- Consumes: `SpellData.Element` enum (FIRE, THUNDER, LAND, SEA).
- Produces: `SpellData.NO_ELEMENT: int` (-1). `class_name ElementTable extends Resource` with `@export var strong_multiplier := 1.5`, `weak_multiplier := 0.5`, `neutral_multiplier := 1.0`, `func multiplier(attacker: int, defender: int) -> float`, `static func default_table() -> ElementTable` (loads `res://resources/spells/element_table.tres`). `DamageSystem.calculate(base_damage: float, attacker_element: int = SpellData.NO_ELEMENT, defender_element: int = SpellData.NO_ELEMENT, table: ElementTable = null) -> float` (null table means `ElementTable.default_table()`).

- [ ] **Step 1: Write the failing tests.** `test_element_table.gd`: for each of the four (attacker, defender) pairs Fire→Land, Land→Thunder, Thunder→Sea, Sea→Fire assert `multiplier == strong_multiplier`; for each reverse pair (Land→Fire, Thunder→Land, Sea→Thunder, Fire→Sea) assert `weak_multiplier`; same element, and any pair with `NO_ELEMENT` on either side, assert `neutral_multiplier`; a table with `strong_multiplier = 3.0` returns 3.0 (configurable); `default_table()` returns a non-null table with 1.5 / 0.5 / 1.0. `test_damage_system.gd` adds: `calculate(10.0, FIRE, LAND) == 15.0`, `calculate(10.0, FIRE, SEA) == 5.0`, `calculate(10.0, FIRE) == 10.0` (no defender), `calculate(10.0, FIRE, LAND, custom_table)` uses the custom table, and the existing pass-through and negative-clamp tests still pass.
- [ ] **Step 2: Run to verify failure.** `godot --headless --import`, then `-gselect=test_element_table`. Expected: FAIL (class not defined).
- [ ] **Step 3: Implement** `ElementTable` with `multiplier` using a beats map `{FIRE: LAND, LAND: THUNDER, THUNDER: SEA, SEA: FIRE}`; create `element_table.tres`; change `DamageSystem.calculate` to `maxf(base_damage * table.multiplier(attacker, defender), 0.0)`. Existing callers pass one argument and stay valid.
- [ ] **Step 4: Run** `-gselect=test_element_table` and `-gselect=test_damage_system`, then the full suite. Expected: PASS, 0 failing.
- [ ] **Step 5: Commit** `feat: element table and elemental damage multiplier`.

### Task 2: SpellData fields, SpellInstance and the four spells

**Files:**
- Create: `scripts/spells/spell_instance.gd`, `resources/spells/fire.tres`, `thunder.tres`, `land.tres`, `sea.tres`, `tests/test_spell_instance.gd`, `tests/test_spell_resources.gd`
- Modify: `resources/spells/spell_data.gd`

**Interfaces:**
- Consumes: `SpellData` (exists), `SpellData.NO_ELEMENT` (Task 1).
- Produces: `SpellData` gains `@export` fields `max_mana: float`, `mana_cost: float`, `damage: float`, `cast_interval: float`, `projectile_speed: float`, `projectile_lifetime: float`, `knockback: float`, `max_hits: int = 1`, `color: Color`, `projectile_scene: PackedScene`, and `func primary_element() -> int` (first of `elements`, or `NO_ELEMENT` when empty). `class_name SpellInstance extends RefCounted`: `var data: SpellData`, `var current_mana: float`, `var cooldown_left: float`, `signal mana_changed(current: float, maximum: float)`, `func _init(spell_data: SpellData)` (starts at full mana, no cooldown), `func has_mana() -> bool` (`current_mana >= data.mana_cost`), `func can_cast() -> bool` (`has_mana()` and `cooldown_left <= 0`), `func cast() -> bool` (returns false and changes nothing unless `can_cast()`; otherwise spends `mana_cost`, sets `cooldown_left = cast_interval`, emits `mana_changed`, returns true), `func tick(delta: float) -> void`, `func restore_mana(amount: float = -1.0) -> void` (negative means full refill; never above `max_mana`; emits `mana_changed`), `func mana_ratio() -> float`.

- [ ] **Step 1: Write the failing tests.** `test_spell_instance.gd` (builds a `SpellData` in code, max_mana 3, cost 1, interval 0.5): starts at full mana; `cast()` spends exactly `mana_cost` and returns true; a second `cast()` straight away returns false and spends nothing (cooldown); after `tick(0.5)` it casts again; three casts empty the pool, the fourth returns false with `current_mana` unchanged and `can_cast()` false even after ticking (never regenerates: tick 100 s, mana still 0); `restore_mana()` refills to max, `restore_mana(1.0)` adds 1 and clamps at max; `mana_changed` emits on cast and on restore with the new values; **two instances built from one `SpellData` do not share mana** (cast one, the other stays full; mutating one does not change `data`). `test_spell_resources.gd`: for each of the four `.tres` files, load it and assert the table values in Global Constraints, `elements` has exactly one entry (FIRE, THUNDER, LAND, SEA respectively), `area == MISSILE`, `max_hits == 1`, `mana_cost <= max_mana`, `primary_element()` matches; `SpellData.new().primary_element() == NO_ELEMENT`; the existing `test_data_resources.gd` round-trip test still passes.
- [ ] **Step 2: Run to verify failure.** Expected: FAIL (missing `SpellInstance`, missing fields).
- [ ] **Step 3: Implement** the fields (defaults: max_mana 40, mana_cost 1, damage 10, cast_interval 0.35, projectile_speed 220, projectile_lifetime 1.2, knockback 0, max_hits 1, colour white), `SpellInstance`, and the four `.tres` files. Leave `projectile_scene` unset in the `.tres` files for now (Task 4 sets it).
- [ ] **Step 4: Run** `godot --headless --import`, then the two new test files, then the full suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: SpellData fields, SpellInstance with per-instance mana, four elemental spells`.

### Task 3: HitboxComponent max_hits

**Files:**
- Modify: `scripts/components/hitbox_component.gd`, `tests/test_hurtbox_hitbox.gd`

**Interfaces:**
- Consumes: existing `HitboxComponent` (`try_hit(target, now_msec)`, `one_shot`, `hit_cooldown`).
- Produces: `@export var max_hits: int = 0` (0 = unlimited). After `max_hits` landed hits the hitbox stops (monitoring off, physics process off), exactly as `one_shot` does after one hit. `func is_finished() -> bool`. `one_shot` keeps working and behaves like `max_hits = 1`. The overlap loop stops as soon as the hitbox is finished, so one frame never lands more than `max_hits` hits.

- [ ] **Step 1: Write the failing tests** in `test_hurtbox_hitbox.gd`: a hitbox with `max_hits = 2` against three overlapping hurtboxes lands exactly two hits in one physics frame and `is_finished()` is true; `max_hits = 1` behaves like `one_shot`; `max_hits = 0` keeps hitting all three; with `max_hits = 3` and a long `hit_cooldown`, calling `try_hit` on the same target twice lands once (a piercing shot never double-hits one enemy); `one_shot = true` still stops after one hit (existing tests pass unchanged).
- [ ] **Step 2: Run** `-gselect=test_hurtbox_hitbox`. Expected: FAIL (`max_hits` not defined).
- [ ] **Step 3: Implement** a private `_hits_landed` counter incremented in `try_hit`, a private `_finished` flag set when `one_shot` or `max_hits > 0 and _hits_landed >= max_hits`, and change the `_physics_process` loop to break when `_finished`.
- [ ] **Step 4: Run** `-gselect=test_hurtbox_hitbox` then the full suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: hitbox max_hits for piercing-ready projectiles`.

### Task 4: SpellProjectile

**Files:**
- Create: `scripts/entities/spell_projectile.gd`, `scenes/spells/projectiles/spell_projectile.tscn`, `tests/test_spell_projectile.gd`
- Modify: `resources/spells/fire.tres`, `thunder.tres`, `land.tres`, `sea.tres` (set `projectile_scene`)

**Interfaces:**
- Consumes: `SpellData` fields (Task 2), `HitboxComponent.max_hits` (Task 3), `DamageSystem.calculate` (Task 1), `PhysicsLayers`.
- Produces: `class_name SpellProjectile extends Node2D` with `var direction: Vector2`, `func launch(launch_direction: Vector2, spell: SpellData) -> void` (call after it is in the tree: normalises direction, sets speed and lifetime from the spell, tints `Body` with `spell.color`, sets `Hitbox.damage = DamageSystem.calculate(spell.damage, spell.primary_element())`, `Hitbox.knockback`, `Hitbox.max_hits = spell.max_hits`, and `Hitbox.hit_cooldown = spell.projectile_lifetime + 1.0` so one projectile never hits the same enemy twice), and `hits` (landed hit count). The projectile frees itself when `hits >= spell.max_hits` or its lifetime ends. Scene mirrors `basic_projectile.tscn` (Node2D, `Body` ColorRect 6×6, `Hitbox` Area2D layer 16 mask 4 with a radius-4 circle) but without `one_shot`. The old `Projectile`, `basic_projectile.tscn` and `AttackComponent` stay untouched until Task 6.

- [ ] **Step 1: Write the failing tests.** Load `fire.tres` and: the projectile moves `speed * delta` along the direction; it is freed after `projectile_lifetime`; `Body.color` equals the spell colour; hitbox damage equals `DamageSystem.calculate(spell.damage, spell.primary_element())`; with `max_hits = 1` it hits exactly one of two overlapping enemies and is freed (integration, `await wait_physics_frames(6)`, same shape as the Sprint 1 projectile test); with a `SpellData` copy at `max_hits = 3` and three enemies in its path it damages three distinct enemies, each only once, and is freed only after the third (`await` physics frames, assert each enemy's health dropped by exactly `damage`); with `max_hits = 3` and one enemy it stays alive after hitting it.
- [ ] **Step 2: Run** `-gselect=test_spell_projectile`. Expected: FAIL.
- [ ] **Step 3: Implement** the script and scene; set `projectile_scene` in the four `.tres`.
- [ ] **Step 4: Run** `godot --headless --import`, `-gselect=test_spell_projectile`, then the full suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: data-driven spell projectile`.

### Task 5: SpellLoadout

**Files:**
- Create: `scripts/components/spell_loadout.gd`, `tests/test_spell_loadout.gd`

**Interfaces:**
- Consumes: `SpellInstance` (Task 2), `SpellProjectile` (Task 4).
- Produces: `class_name SpellLoadout extends Node`. `const SLOT_COUNT := 5`. `@export var starting_spells: Array[SpellData]` (index = slot, null = empty). `var slots: Array[SpellInstance]` (size 5, null for empty, built in `_ready`), `var selected_index: int = 0`, `var projectile_root: Node` (defaults to `get_parent().get_parent()`). `signal selection_changed(index: int)`, `signal cast_fired(index: int)`, `signal cast_failed_dry(index: int)`. `func select(index: int) -> bool` (false and unchanged for an out-of-range index, an empty slot, or the already-selected slot; otherwise sets the index, emits `selection_changed`, true). `func cycle(step: int) -> bool` (moves to the next non-empty slot in the direction of `step`, wrapping; false if no other non-empty slot exists). `func selected() -> SpellInstance` (may be null). `func try_cast(origin: Vector2, direction: Vector2) -> bool` (false with no projectile when the selected slot is empty, direction is zero, or on cooldown; when the selected spell has no mana it returns false, spawns nothing, and emits `cast_failed_dry` only the first time since the last `end_cast()` or selection change; on success it calls `SpellInstance.cast()`, instantiates `data.projectile_scene` under `projectile_root`, positions it at `origin`, calls `launch(direction, data)`, emits `cast_fired`, returns true). `func end_cast() -> void` (clears the dry-cue latch). `func restore_all_mana() -> void`. A `_process(delta)` ticks every instance's cooldown.

- [ ] **Step 1: Write the failing tests** (build the loadout in code with the four `.tres`, `projectile_root` set to a test `Node2D`): slots 0–3 filled and 4 empty after `_ready`; `select(2)` changes selection and emits; `select(4)` (empty), `select(9)` and `select(-1)` return false and leave the selection; `select` on the current slot returns false; `cycle(1)` from slot 3 wraps to 0, `cycle(-1)` from 0 wraps to 3, both skipping empty slot 4; `cycle` with a single filled slot returns false and leaves the selection; `cycle` with no filled slots returns false without error; `try_cast` spawns one `SpellProjectile` at the origin with the aim direction and the spell's stats, spends exactly `mana_cost` from the selected slot only and leaves other slots untouched, then returns false while on cooldown and true after `_process(cast_interval)`; zero direction casts nothing and spends nothing; **depletion**: drain the selected spell to zero, then call `try_cast` repeatedly: no projectile is spawned, mana stays 0, `selected_index` is unchanged (no auto-switch), and `cast_failed_dry` emits exactly once across ten calls, emits again only after `end_cast()` or a selection change; casting on an empty selected slot does nothing and emits no dry cue; `restore_all_mana()` refills every instance and lets the depleted spell cast again; two loadouts built from the same `.tres` files do not share mana.
- [ ] **Step 2: Run** `-gselect=test_spell_loadout`. Expected: FAIL.
- [ ] **Step 3: Implement** `SpellLoadout`. Keep it free of input handling: the Player and Main call it.
- [ ] **Step 4: Run** `godot --headless --import`, `-gselect=test_spell_loadout`, then the full suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: SpellLoadout with five slots, selection and mana-gated casting`.

### Task 6: Input actions, Player swap, remove the stand-in attack

**Files:**
- Modify: `project.godot` (input actions), `scripts/entities/player.gd`, `scenes/player/player.tscn`, `scripts/dev/stress_test.gd`, `tests/test_input_map.gd`, `tests/test_player.gd`
- Create: `resources/spells/stress_spell.tres`
- Delete (with their `.uid` files): `scripts/components/attack_component.gd`, `scripts/entities/projectile.gd`, `scenes/spells/projectiles/basic_projectile.tscn`, `resources/attacks/` (`attack_data.gd`, `basic_attack.tres`), `tests/test_attack_component.gd`, `tests/test_projectile.gd`

**Interfaces:**
- Consumes: `SpellLoadout` (Task 5), the four spells.
- Produces: Input actions `spell_prev` (joypad left shoulder, button 9), `spell_next` (joypad right shoulder, button 10), `debug_restore_mana` (key F9, physical keycode 4194340), all with `device = -1`, deadzone 0.5. `Player` exposes `@onready var loadout: SpellLoadout = $SpellLoadout` and, in `_unhandled_input`, ignores everything when dead, selects the slot for `spell_slot_1`–`spell_slot_5` (slot N maps to index N-1), and calls `cycle(-1)` / `cycle(1)` for `spell_prev` / `spell_next`. In `_physics_process` it calls `loadout.try_cast(global_position, aim.aim_direction)` while `aim.is_firing` and `loadout.end_cast()` otherwise. `player.tscn` swaps `AttackComponent` for a `SpellLoadout` node with `starting_spells` set to `[fire, thunder, land, sea, null]`. `stress_spell.tres`: Fire's values but `max_mana = 1000000000`, `cast_interval = 0.05`, `mana_cost = 1`, same projectile scene.

- [ ] **Step 1: Write the failing tests.** `test_input_map.gd`: add the three new actions to `ACTIONS` (the existing any-device test then covers them), plus a test that `spell_prev` and `spell_next` each have an `InputEventJoypadButton` and `debug_restore_mana` has an `InputEventKey`. `test_player.gd`: the alive player holding `cast` spawns a `SpellProjectile` and spends mana from slot 0; pressing `spell_slot_2` (use `Input.parse_input_event` with an `InputEventAction`, or call `player._unhandled_input` with one) selects index 1; `spell_slot_5` (empty) leaves the selection; `spell_next` cycles forward; **a dead player ignores slot input and casts nothing** (kill via the hurtbox, then try both); depleting the selected spell and holding `cast` spawns nothing and does not change `selected_index`. Move the Sprint 1 "alive player fires and dead player does not" test onto `SpellProjectile`.
- [ ] **Step 2: Run** `-gselect=test_input_map` and `-gselect=test_player`. Expected: FAIL.
- [ ] **Step 3: Implement.** Add the three actions to `project.godot` (copy the shape of the existing joypad-button and key events), swap the Player to `SpellLoadout`, edit `player.tscn` (remove the `attack_component` and `basic_attack.tres` ext_resources and node; add the loadout), update `stress_test.gd` to take `$Player/SpellLoadout`, set slot 0 to `SpellInstance.new(stress_spell)`, `select(0)`, and call `try_cast` each physics frame in place of `try_fire` (remove the `AttackData` duplicate and `ATTACK_COOLDOWN`), then delete the stand-in files and their `.uid` files. Confirm nothing still references them: `grep -rn "AttackComponent\|AttackData\|basic_attack\|basic_projectile\|Projectile\b" scripts scenes resources tests` should show only `SpellProjectile` hits.
- [ ] **Step 4: Run** `godot --headless --import`, `-gselect=test_input_map`, `-gselect=test_player`, the full suite, and `godot --headless --quit-after 60` for a clean smoke run. Expected: PASS and no errors.
- [ ] **Step 5: Commit** `feat: player casts through SpellLoadout, controller cycling, remove stand-in attack`.

### Task 7: SpellBar HUD, touch slots, debug key

**Files:**
- Create: `scripts/ui/spell_bar.gd`, `scripts/ui/spell_slot_widget.gd`, `scenes/ui/spell_bar.tscn`, `tests/test_spell_bar.gd`
- Modify: `scenes/main/main.tscn`, `scripts/main/main.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `SpellLoadout` and its signals (Task 5), `SpellInstance.mana_changed` (Task 2), Player `loadout` (Task 6).
- Produces: `class_name SpellSlotWidget extends Control`: builds its own children in `_ready` (background, mana fill, number label, element-colour swatch; no hand-written child nodes in a scene), `signal pressed(index: int)`, `func setup(slot_index: int, spell: SpellData) -> void` (null means empty slot, drawn dim), `func set_mana(current: float, maximum: float) -> void` (sets public `ratio` and `depleted`), `func set_selected(value: bool) -> void` (public `selected`), `func flash_dry() -> void` and `func is_flashing() -> bool`, and `_input` that reacts only to `InputEventScreenTouch` presses inside `get_global_rect()` while `is_visible_in_tree()`, emitting `pressed(index)` and calling `get_viewport().set_input_as_handled()`. It never presses the `cast` action and ignores mouse clicks (desktop uses the keys). `class_name SpellBar extends Control` (scene is a single `Control` node with the script): `signal slot_pressed(index: int)`, `var widgets: Array[SpellSlotWidget]`, `func bind(loadout: SpellLoadout) -> void` (creates five widgets in a row at the bottom centre of the screen, about 28×18 px with 2 px gaps, connects each instance's `mana_changed`, `selection_changed` and `cast_failed_dry`, and shows the current state immediately). `Main` adds `@onready var _spell_bar: SpellBar = $Hud/SpellBar`, binds it to `_player.loadout`, connects `slot_pressed` to `_player.loadout.select`, and handles `debug_restore_mana` in `_unhandled_input` by calling `_player.loadout.restore_all_mana()`. Mark `Main`'s debug handling with a `# DEBUG` comment so it is easy to delete.

- [ ] **Step 1: Write the failing tests.** `test_spell_bar.gd`: after `bind`, five widgets exist, slots 0–3 show the spell colours and slot 4 is dim/empty; `ratio` follows `mana_changed` (cast once, `ratio` equals `current / max`); a depleted instance sets `depleted` true; `selection_changed` moves `selected` to the new widget only; `cast_failed_dry` makes that widget `is_flashing()`; **a touch press inside widget 2's rect emits `pressed(2)` and leaves `Input.is_action_pressed(&"cast")` false**; a touch press outside every widget emits nothing; a hidden bar ignores touches; a mouse button event in the rect emits nothing; touching an empty slot's widget still emits `pressed(4)` and the loadout ignores it (selection unchanged). `test_main.gd`: `Main` has the bar bound to the player's loadout (`widgets.size() == 5`); emitting `slot_pressed(1)` selects slot 1; calling `main._unhandled_input` with a `debug_restore_mana` action event refills a drained slot.
- [ ] **Step 2: Run** `-gselect=test_spell_bar` and `-gselect=test_main`. Expected: FAIL.
- [ ] **Step 3: Implement** the widgets, the bar, the scene, and the `main.tscn` / `main.gd` wiring. Keep widgets `mouse_filter = IGNORE` so they never swallow clicks meant for gameplay.
- [ ] **Step 4: Run** `godot --headless --import`, the two test files, then the full suite. Then run the project through the godot MCP server (`mcp__godot__run_project`, read `mcp__godot__get_debug_output`) for 5 seconds. Expected: PASS and no warnings or errors, the bar visible, all four slots shown.
- [ ] **Step 5: Commit** `feat: spell bar HUD with touch slot buttons and debug mana restore`.

### Task 8: Stress test, docs and the manual checklist

**Files:**
- Modify: `development-log.md`, `CLAUDE.md`, `sprint-development.md`, `docs/sprints/sprint-2-design.md` (status line)

**Interfaces:**
- Consumes: everything above.
- Produces: the recorded perf result and updated docs.

- [ ] **Step 1: Run the stress test.** `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=10` (windowed), and again with `--enemies=500`. Expected: one `STRESS` line each, avg fps at or above 60 (it was 733.6 and 535.3 in Sprint 1). If either drops below 60, stop and report: optimization becomes in scope.
- [ ] **Step 2: Update the docs.** `development-log.md`: a Sprint 2 section with the decisions (SpellInstance/Loadout split, numbers actually used if tuned, controller cycling, `max_hits`, the dry-cue latch, why enemy elements stay out), the new stress numbers, and the known limitation that damage is computed at cast time with no defender element (Sprint 4 moves the multiplier to hit time). `CLAUDE.md`: Project State mentions Sprint 2; replace the "TEMPORARY attack" lines in "Combat architecture" with a short "Spell architecture (Sprint 2)" section (SpellData vs SpellInstance, SpellLoadout, ElementTable, SpellBar and health bar still TEMPORARY); remove the old stress-test attacker wording. `sprint-development.md`: tick the Sprint 2 task boxes that are done (note "Implement spell targeting" is the aim direction, "spell visual effects" is the element tint, and that the enemy-side half of the elemental modifiers lands in Sprint 4). `docs/sprints/sprint-2-design.md`: status line becomes "Built".
- [ ] **Step 3: Full verification.** Full suite, smoke run, and a final godot MCP run with no warnings.
- [ ] **Step 4: Write the manual checklist** into the final message for the user: cast each of the four spells (keys 1–4), watch the bar drain, deplete one and hold the mouse button (nothing fires, nothing switches), pick another slot, refill with F9, tap slots with touch emulation, cycle with a controller's shoulder buttons if available.
- [ ] **Step 5: Commit** `docs: Sprint 2 complete`.
