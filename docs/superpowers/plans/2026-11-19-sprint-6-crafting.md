# Sprint 6 Arcane Lectern and Spell Crafting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player starts with one spell, walks to an Arcane Lectern, and crafts a new spell from a Base scroll, an Area scroll and a range choice on a one-screen workbench, with the world paused while crafting.

**Architecture:** A static `SpellBuilder` turns scrolls plus a range option into a runtime `SpellData`, using baselines on each Area (`AreaStats`) and multipliers on each Base scroll (`BaseModifiers`). A static `CraftingSystem` validates, consumes scrolls all-or-nothing and equips through `SpellLoadout.equip`. A `CraftingSession` holds the screen's choices and previews with no UI. `CraftingScreen` is a thin pausing UI over the session. Lecterns are passive `interactable` areas found by an `InteractionComponent` on the player.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-6-design.md` (approved). Also `docs/sprints/sprint-5-design.md`, `CLAUDE.md`, `technical-design.md` sections 5 and 7.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python` (never bare `python3`, not even for a version check). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''` and prefer the Edit tool for multi-line edits. zsh does not word-split unquoted variables.
- Work on branch `sprint-6-crafting`, cut from `main`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`).
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, no new autoloads (so `GameTime` is a static helper), Input Map actions only (device -1 on every event). Hand-written `.tscn` needs `node_paths=PackedStringArray("prop")` for exported Node refs. Don't name a parameter `position` in a `Node2D` subclass.
- All crafting and stat rules live in `SpellBuilder` and `CraftingSystem`. The Lectern, the screen and `Player` hold none, and the screen only calls the session, which calls the systems. No stat is hand-written for any Base and Area pair. Elemental math stays in `ElementTable` and `DamageSystem`. Scrolls are consumed only by `CraftingSystem.craft`, all-or-nothing, after full validation.
- No buff effects or buff selection (buff scrolls show locked), no multi-element spells, no size choice, no levels or XP, no general pause menu, no art.
- Collision layers 1 to 6 unchanged. New layer 7 `interactable` = bit 64.
- **Opening ease (user decision):** the starting Fire Missile pool goes from 40 to 100 casts and the scroll `drop_chance` goes from 0.06 to 0.10 in all five drop tables.
- **Baselines (`AreaStats`, tune by playing).** All pools are 100.

  | Area | damage | cast_interval | mana_cost | max_mana | projectile_speed | knockback |
  |---|---|---|---|---|---|---|
  | Missile | 10 | 0.35 | 1 | 100 | 220 | 120 |
  | Cone | 10 | 0.55 | 2 | 100 | 220 | 100 |
  | Line | 12 | 0.7 | 2 | 100 | 220 | 70 |
  | Area (zone) | 12 | 1.2 | 4 | 100 | 220 | 40 |
  | Wave | 11 | 0.9 | 3 | 100 | 140 | 100 |

- **Multipliers (`BaseModifiers`, tune by playing; derived from the Sprint 2 Missile numbers).**

  | Base | damage | cast_interval | mana_cost | max_mana | projectile_speed | knockback |
  |---|---|---|---|---|---|---|
  | Fire | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
  | Thunder | 0.7 | 0.5 | 1.0 | 1.5 | 1.35 | 0.65 |
  | Land | 1.8 | 2.0 | 2.0 | 1.0 | 0.75 | 1.8 |
  | Sea | 0.9 | 0.85 | 1.0 | 1.1 | 0.9 | 0.5 |

- **Range options (`CraftingRules`):** Short (`range_scale` 0.6, `cost_multiplier` 0.7), Normal (1.0, 1.0), Long (1.5, 1.4), Very long (2.0, 1.8), in that order.
- **Final spell rule:** damage, interval, speed and knockback are baseline times the Base multiplier. `mana_cost` is baseline times the Base's cost multiplier times the range option's cost multiplier. `max_mana` is baseline times the Base's pool multiplier. `size_scale` is 1.0 and `max_hits` is 1. Fire plus Missile at Normal must equal `fire_missile.tres` exactly (10, 0.35, 1, 100, 220, 120).
- Lecterns: three, at (160, 120), (800, 150) and (480, 450) in the arena, off-screen from the player's start at (480, 270). Interaction radius about 24 px, reusable, unlimited and free.
- Perf gate: the stress test (300 enemies) must stay at or above 60 fps (Sprint 5 baseline: 657 fps Missile, 194 Wave, 416 Zone).

## Review Focus

- A failed craft (no Base, no Area, wrong category, a scroll the player lacks, a locked slot, a bad range option, buffs given) must leave the inventory and loadout exactly as they were. Pinned in Task 4.
- Locked slots must not be selectable, equippable, cyclable or tappable, and a replaced slot's mana bar must follow the new spell's mana, not the old one's. Pinned in Task 3.
- The click that confirms a craft must not fire a spell when the game resumes, and a Wave, Zone or Line alive across a pause must not hit an enemy twice. Pinned in Task 5.
- A dead player must not be able to interact with a Lectern or keep the crafting screen open, and an empty inventory must open the screen with Confirm disabled and a reason. Pinned in Tasks 6 and 7.
- Touch on the paused modal screen (mouse emulation is off) must reach the buttons. Pinned in Task 8.

---

### Task 1: Crafting data and the opening-ease numbers

**Files:**
- Create: `resources/crafting/area_stats.gd`, `resources/crafting/base_modifiers.gd`, `resources/crafting/range_option.gd`, `resources/crafting/crafting_rules.gd`, `resources/crafting/crafting_rules.tres`, `resources/crafting/area_stats/{missile,cone,line,zone,wave}.tres`, `resources/crafting/base_modifiers/{fire,thunder,land,sea}.tres`, `tests/test_crafting_data.gd`
- Modify: `resources/spells/area_data.gd`, `resources/scrolls/scroll_data.gd`, the five `resources/spells/areas/*_area.tres` (set `base_stats`), the four `resources/scrolls/base/*.tres` (set `modifiers`), `resources/spells/fire_missile.tres` (`max_mana = 100.0`), the five `resources/drops/*_drops.tres` (`drop_chance = 0.1`), `tests/test_spell_resources.gd`, `tests/test_drop_table.gd`

**Interfaces:**
- Produces `AreaStats` (`class_name AreaStats extends Resource`): `@export var damage, cast_interval, mana_cost, max_mana, projectile_speed, knockback: float`.
- Produces `BaseModifiers` (`class_name BaseModifiers extends Resource`): the same six names, all `@export var ...: float = 1.0`.
- Produces `RangeOption` (`class_name RangeOption extends Resource`): `@export var label: String`, `@export var range_scale: float = 1.0`, `@export var cost_multiplier: float = 1.0`.
- Produces `CraftingRules` (`class_name CraftingRules extends Resource`): `@export var range_options: Array[RangeOption]`, `option(index: int) -> RangeOption` (null if out of range), `normal_index() -> int` (the index whose `range_scale` is 1.0, else 0), `static default_rules() -> CraftingRules` (loads `res://resources/crafting/crafting_rules.tres`).
- `AreaData.base_stats: AreaStats` and `ScrollData.modifiers: BaseModifiers` (Base scrolls only) are new exports.

- [ ] **Step 1: Write the failing tests.** `test_crafting_data.gd`: `test_area_baselines_match_the_table` (each of the five `*_area.tres` has `base_stats` with the table's numbers), `test_base_scrolls_carry_the_multipliers` (each of the four Base scrolls has `modifiers` matching the table, and the Area and Buff scrolls have none), `test_rules_have_the_four_range_options_in_order` (labels "Short", "Normal", "Long", "Very long", scales and cost multipliers from the table, `normal_index() == 1`, `option(9)` and `option(-1)` are null, costs strictly increase with range), `test_default_rules_loads`. Update `test_spell_resources.gd` so Fire Missile's pool is 100, and `test_drop_table.gd` so the drop chance test expects 0.1 (rename it `test_drop_chance_is_ten_percent_everywhere`).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures or parse errors for the missing classes and fields.
- [ ] **Step 3: Implement** the classes and fields, then write the data files. Generate the `.tres` edits with a throwaway script run by `venv/bin/python` and kept in the scratchpad, not the repo, or edit by hand. Add `base_stats` to each Area file and `modifiers` to each Base scroll through `ext_resource` lines, and fix `load_steps`.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: crafting data, and a bigger Fire Missile pool and 10% drops"`, with the trailer.

---

### Task 2: SpellBuilder

**Files:**
- Create: `scripts/crafting/spell_builder.gd`, `tests/test_spell_builder.gd`

**Interfaces:**
- Consumes: Task 1 data, `ScrollData`, `SpellData`, `AreaData`.
- Produces `SpellBuilder` (`class_name SpellBuilder extends RefCounted`, all static): `build(base: ScrollData, area: ScrollData, option: RangeOption) -> SpellData` (null if any input is null, the categories are wrong, the Base has no `modifiers`, or the Area scroll has no `area_data` or `base_stats`); `display_name(base, area, option) -> String` ("Fire Missile", with " (Short)" style suffix using `option.label` when `option.range_scale != 1.0`); `describe(spell: SpellData) -> Dictionary` with keys `name` (String), `damage`, `interval`, `cost`, `pool`, `casts` (pool divided by cost), `range` (`effective_range()`) as floats, and `area` (String name of the Area type, such as "Missile"). The built spell follows the Final spell rule in the Global Constraints, with `elements = [base.element]`, `area_data = area.area_data`, `range_scale = option.range_scale`, `size_scale = 1.0`, `max_hits = 1`, `color = base.color`, `display_name` from `display_name`, and `id` as `StringName("<base id>_<area id>_<lowercased option label>")` with spaces turned into underscores.

- [ ] **Step 1: Write the failing tests.** `test_spell_builder.gd` (load the 15 scrolls and `CraftingRules.default_rules()`): `test_fire_missile_at_normal_equals_the_starting_spell` (every field against `fire_missile.tres`: damage, cast_interval, mana_cost, max_mana, projectile_speed, knockback, max_hits, elements, color, `area_type()`, `range_scale` 1.0, `size_scale` 1.0), `test_every_base_and_area_pair_builds` (4 x 5, non-null, element equals the Base's, `area_data` equals the Area scroll's), `test_longer_range_costs_more_and_gives_fewer_casts` (for the four options on Thunder plus Wave: cost strictly increases, `max_mana` is unchanged, casts strictly decrease, `range_scale` follows the option), `test_land_is_slower_and_heavier_than_thunder` (same Area: Land has more damage and a longer interval than Thunder, and Thunder has the bigger pool), `test_name_and_id` (Fire Missile Normal is "Fire Missile", Long adds " (Long)", the id is `fire_missile_normal`), `test_describe_reports_the_numbers` (casts equals pool over cost, name matches), `test_bad_inputs_return_null` (null base, null area, null option, an Area scroll given as the Base, a Base given as the Area, a Base scroll with no modifiers).
- [ ] **Step 2: Run to verify they fail.** Expected: fail, class missing.
- [ ] **Step 3: Implement** `SpellBuilder`.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, the file, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: SpellBuilder turns scrolls into a spell"`, with the trailer.

---

### Task 3: Slots, replacing spells, and the spell bar

**Files:**
- Modify: `scripts/components/spell_loadout.gd`, `scripts/ui/spell_slot_widget.gd`, `scripts/ui/spell_bar.gd`, `scenes/player/player.tscn`, `project.godot` (action `debug_unlock_slot`, key F11, physical keycode 4194342), `scripts/main/main.gd`, `tests/test_spell_loadout.gd`, `tests/test_spell_bar.gd`, `tests/test_player.gd`, `tests/test_main.gd`, `tests/test_input_map.gd`

**Interfaces:**
- Produces on `SpellLoadout`: `@export var unlocked_slots: int = SLOT_COUNT`; `is_unlocked(index: int) -> bool` (in range and below `unlocked_slots`); `unlock_next() -> bool` (false when all five are unlocked, else raises `unlocked_slots` by one and emits `slot_unlocked(index)`); `equip(index: int, spell: SpellData) -> SpellInstance` (null if the spell is null or the index is out of range or locked; otherwise builds a fresh full-mana `SpellInstance`, puts it in the slot, resets the dry-cue latch when it is the selected slot, emits `slot_changed(index)`, returns it); signals `slot_changed(index: int)` and `slot_unlocked(index: int)`. `_ready` builds instances only for unlocked slots. `select` also rejects locked slots, and `cycle` skips them.
- Produces on `SpellSlotWidget`: `var locked: bool`, `set_locked(value: bool)`. A locked widget is dimmed with a lock mark ("x" in the label), and `handle_touch` returns false.
- `SpellBar.bind` sets each widget's locked state, and rebinds a widget when `slot_changed` fires (re-run `setup`, set the mana, move the `mana_changed` connection to the new instance and disconnect it from the old one) and unlocks it on `slot_unlocked`.
- The player scene sets `unlocked_slots = 1` and `starting_spells` to Fire Missile only. `Main` handles `debug_unlock_slot` with `_player.loadout.unlock_next()` (marked DEBUG).

- [ ] **Step 1: Write the failing tests.** `test_spell_loadout.gd` (keep the existing five-spell fixtures, which still work since `unlocked_slots` defaults to 5): `test_locked_slots_hold_no_spell_even_if_listed` (starting spells in locked slots are ignored), `test_unlock_next_unlocks_one_slot_and_emits` (from 1: `is_unlocked(1)` true after, `slot_unlocked` emitted with the index, false after five), `test_equip_into_an_empty_unlocked_slot`, `test_equip_replaces_with_a_fresh_full_pool` (drain the old spell, equip a different one: new instance, full mana, not the same object, `slot_changed` emitted with the index), `test_equip_refuses_locked_out_of_range_and_null` (returns null, slots unchanged, no signal), `test_select_and_cycle_skip_locked_slots` (with unlocked_slots 2, selecting 3 fails and cycling alternates 0 and 1), `test_selection_survives_replacing_the_selected_slot` (selected index unchanged, the dry-cue latch resets). `test_spell_bar.gd`: `test_locked_slots_are_dimmed_and_inert` (widget `locked`, `handle_touch` false, `slot_pressed` not emitted), `test_unlocking_a_slot_enables_its_widget`, `test_a_replaced_slot_follows_the_new_instances_mana` (equip, cast, the widget ratio follows the new instance and not the old one). `test_player.gd`: `test_player_starts_with_only_fire_missile_and_four_locked_slots` (replaces the five-spell test: slot 0 is Fire Missile with a pool of 100, slots 1 to 4 are null and locked), and fix the slot-key test (keys for locked slots do nothing; after `unlock_next` and an `equip`, the key selects it). `test_main.gd`: fix `test_spell_bar_is_bound_and_slot_presses_select` (equip into slot 2 first), and add `test_debug_unlock_key_unlocks_the_next_slot`. `test_input_map.gd`: add `debug_unlock_slot` to `ACTIONS` and a key test.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures for the missing members.
- [ ] **Step 3: Implement** the interfaces. Edit `player.tscn` to drop the four unused spell resource references.
- [ ] **Step 4: Run to verify they pass.** Full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** and a godot MCP run (`run_project`, `get_debug_output`, `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: locked spell slots, equip, and a one-spell start"`, with the trailer.

---

### Task 4: CraftingSystem

**Files:**
- Create: `scripts/crafting/crafting_request.gd`, `scripts/crafting/crafting_result.gd`, `scripts/crafting/crafting_system.gd`, `tests/test_crafting_system.gd`

**Interfaces:**
- Consumes: `SpellBuilder`, `CraftingRules`, `ScrollInventory` (`has`, `remove`, `count`), `SpellLoadout` (`is_unlocked`, `equip`).
- Produces `CraftingRequest` (`class_name CraftingRequest extends RefCounted`): `var base: ScrollData`, `var area: ScrollData`, `var option_index: int = 0`, `var buffs: Array[ScrollData] = []`, `var slot_index: int = 0`.
- Produces `CraftingResult` (`class_name CraftingResult extends RefCounted`): `var ok: bool`, `var reason: String`, `var spell: SpellData`.
- Produces `CraftingSystem` (`class_name CraftingSystem extends RefCounted`, all static) with reason constants `REASON_NO_BASE := "Choose a Base scroll."`, `REASON_NO_AREA := "Choose an Area scroll."`, `REASON_WRONG_BASE := "That is not a Base scroll."`, `REASON_WRONG_AREA := "That is not an Area scroll."`, `REASON_BAD_RANGE := "Choose a range."`, `REASON_BUFFS_LOCKED := "Buffs are not available yet."`, `REASON_LOCKED_SLOT := "That slot is locked."`, `REASON_MISSING := "You don't have that scroll."`; `preview(request, rules) -> SpellData` (the built spell, or null if the Base, Area or option is unusable; ignores the inventory and the slot); `validate(request, rules, inventory, loadout) -> CraftingResult` (checks in this order: no Base, no Area, wrong Base category, wrong Area category, bad range option, buffs not empty, locked or out-of-range slot, a missing scroll; `spell` is set whenever `preview` works); `craft(request, rules, inventory, loadout) -> CraftingResult` (validates, and only on `ok` removes one Base and one Area from the inventory and calls `loadout.equip`, returning the result with the spell).

- [ ] **Step 1: Write the failing tests.** `test_crafting_system.gd` (an inventory and loadout built per test, 1 unlocked slot unless stated): `test_valid_craft_consumes_exactly_one_of_each_and_equips` (own 2 Fire, 1 Missile: after craft Fire 1, Missile 0, slot 0 holds the built spell with a full pool), `test_craft_replaces_the_target_slot_only` (3 unlocked slots, target slot 2: slots 0 and 1 untouched), `test_each_invalid_case_changes_nothing` (for no Base, no Area, a Base passed as the Area, an Area passed as the Base, a bad option index (-1 and 9), a non-empty buffs list, a locked slot, an out-of-range slot, and a Base the player does not own and an Area the player does not own: `ok` false, the exact reason constant, the inventory counts and `total_count()` identical, every loadout slot identical, no `changed` or `slot_changed` signal), `test_preview_ignores_the_inventory` (an empty inventory still previews a spell, and returns null without a Base), `test_validate_never_consumes` (a valid request validated three times leaves the inventory alone), `test_a_second_craft_needs_new_scrolls` (after one craft, the same request fails with `REASON_MISSING`), `test_crafted_spell_works_in_the_loadout` (select the slot and `try_cast` with a real `Node2D` root: the spell casts and spends its mana cost).
- [ ] **Step 2: Run to verify they fail.** Expected: fail, classes missing.
- [ ] **Step 3: Implement** the three classes.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, the file, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: CraftingSystem validates, consumes and equips"`, with the trailer.

---

### Task 5: Pause, the pause-aware clock, and the resume guard

**Files:**
- Create: `scripts/utilities/game_time.gd`, `scripts/utilities/game_pause.gd`, `tests/test_game_time.gd`
- Modify: `scripts/components/hitbox_component.gd`, `scripts/entities/player.gd`, `scripts/main/main.gd`, `tests/test_hurtbox_hitbox.gd`, `tests/test_player.gd`

**Interfaces:**
- Produces `GameTime` (`class_name GameTime extends RefCounted`, static state): `now_msec() -> int` (real milliseconds minus the time spent frozen, and constant while frozen), `freeze()`, `unfreeze()`, `is_frozen() -> bool`, `reset()` (clears frozen state and the total).
- Produces `GamePause` (`class_name GamePause extends RefCounted`): `static set_paused(tree: SceneTree, paused: bool)` sets `tree.paused` and calls `GameTime.freeze()` or `unfreeze()`.
- `HitboxComponent.try_hit(target, now_msec: int = GameTime.now_msec())` uses it in place of `Time.get_ticks_msec()`.
- `Player.require_cast_release() -> void`: until the cast input has been released once, `Player._physics_process` does not cast (it still calls `loadout.end_cast()` while firing is held). `Main._ready` calls `GameTime.reset()`.

- [ ] **Step 1: Write the failing tests.** `test_game_time.gd` (reset in `before_each`, and `get_tree().paused = false` plus `GameTime.reset()` in `after_each`): `test_frozen_clock_does_not_advance` (freeze, record, `OS.delay_msec(40)`, equal), `test_unfreeze_resumes_without_a_jump` (after unfreeze, `now_msec()` is within 25 ms of the frozen value, and then advances), `test_freeze_is_idempotent` (two freezes and one unfreeze resume correctly), `test_reset_clears_state`, `test_game_pause_sets_the_tree_and_the_clock` (call `GamePause.set_paused(get_tree(), true)`: `get_tree().paused` and `GameTime.is_frozen()` are true, then false again, with no awaits between). `test_hurtbox_hitbox.gd`: `test_hit_cooldown_survives_a_pause` (cooldown 0.05 s: hit once, `GameTime.freeze()`, `OS.delay_msec(80)`, a second `try_hit` with the default clock is false, then `unfreeze()` and `OS.delay_msec(60)`, a third is true). `test_player.gd`: `test_no_cast_until_the_cast_input_is_released_after_resume` (call `require_cast_release()`, hold `cast` with `Input.action_press`, wait physics frames: no `MissileArea` appears and mana is untouched; release, wait, hold again: it casts).
- [ ] **Step 2: Run to verify they fail.** Expected: fail, classes and method missing.
- [ ] **Step 3: Implement** the classes, the hitbox change, and the guard in `Player`.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass (and the earlier tests that call `try_hit` with an explicit clock are unaffected).
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: pause-aware clock, GamePause and a cast guard after resume"`, with the trailer.

---

### Task 6: Lecterns and interaction

**Files:**
- Create: `scripts/interactables/lectern.gd`, `scenes/interactables/lectern.tscn`, `scripts/components/interaction_component.gd`, `scripts/ui/interact_button.gd`, `scenes/ui/interact_button.tscn`, `tests/test_lectern.gd`, `tests/test_interaction_component.gd`, `tests/test_interact_button.gd`
- Modify: `scripts/utilities/physics_layers.gd`, `project.godot` (layer 7 name), `tests/test_physics_layers.gd`, `scenes/player/player.tscn`, `scripts/entities/player.gd`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_player.gd`, `tests/test_main.gd`

**Interfaces:**
- Produces `PhysicsLayers.INTERACTABLE := 64` and `2d_physics/layer_7="interactable"`.
- Produces `Lectern` (`class_name Lectern extends Area2D`, scene root `Area2D` with `collision_layer = 64`, `collision_mask = 0`, `monitoring = false`, a circle `CollisionShape2D` of radius 24, a placeholder purple stand drawn with `ColorRect`s, and a hidden `Label` named `Prompt` reading "E"): `signal interacted(actor: Node)`, `interact(actor: Node) -> void` (emits it), `set_prompt_visible(value: bool)`. It joins the group `lecterns`.
- Produces `InteractionComponent` (`class_name InteractionComponent extends Area2D`, mask 64, circle radius 20): `@export var health: HealthComponent`, `signal target_changed(target: Node)`, `signal interacted(target: Node)`, `target() -> Node`, `try_interact(actor: Node) -> bool`. Each physics frame it picks the nearest overlapping area that has an `interact` method (null if the owner is dead), shows that target's prompt (`set_prompt_visible(true)` if it has the method) and hides the previous one, and emits `target_changed` when the target changes. `try_interact` returns false when dead or without a target, else calls `target.interact(actor)`, emits `interacted`, and returns true.
- Produces `Player.interaction: InteractionComponent` (`@onready`, node `InteractionComponent` with `health` set), and `Player._unhandled_input` calls `interaction.try_interact(self)` on the `interact` action (ignored when dead).
- Produces `InteractButton` (`class_name InteractButton extends Control`, TEMPORARY, about 40x16, handles touches itself and ignores mouse clicks, like `InventoryButton`): `signal pressed`, `@export var require_touchscreen: bool = true`, `set_available(available: bool)` (visible only if `available` and, when `require_touchscreen`, `TouchJoystick.should_show()`), `handle_touch(screen_position) -> bool`.
- `main.tscn` gets three `Lectern` instances at the Global Constraints positions and an `InteractButton` in the `Hud` above the spell bar, centred. `Main._ready` connects `player.interaction.target_changed` to `InteractButton.set_available(target != null)`, `InteractButton.pressed` to `player.interaction.try_interact(player)`, and hides the button on `died`. For this task `Main` does not open anything yet.

- [ ] **Step 1: Write the failing tests.** `test_physics_layers.gd`: add `"interactable"` as layer 7 and `INTERACTABLE == 64`. `test_lectern.gd`: `test_lectern_is_passive_on_the_interactable_layer`, `test_interact_emits_with_the_actor`, `test_prompt_starts_hidden_and_toggles`, `test_lectern_joins_the_group`. `test_interaction_component.gd` (a `Player` under a per-test root, Lecterns placed at known offsets, `await wait_physics_frames(4)`): `test_nearest_lectern_becomes_the_target_and_shows_its_prompt` (two Lecterns in range: the nearer is the target, only its prompt shows), `test_out_of_range_is_no_target` (target null, `try_interact` false), `test_walking_away_clears_the_target_and_hides_the_prompt`, `test_interact_calls_the_target_and_emits` (`interacted` on both the Lectern and the component), `test_dead_player_cannot_interact` (kill the player first: target null, `try_interact` false, the Lectern is not signalled), `test_target_changed_emits_only_on_change`. `test_interact_button.gd`: `test_unavailable_and_without_touchscreen_stays_hidden` (default `require_touchscreen` true on a desktop test run stays hidden even when available; with it set false it shows), `test_touch_inside_emits_pressed`, `test_touch_outside_and_hidden_do_nothing`, `test_mouse_clicks_are_ignored`. `test_player.gd`: `test_player_has_an_interaction_component`, and `test_interact_action_uses_the_nearest_lectern` (call `_unhandled_input` with an `InputEventAction` for `interact`). `test_main.gd`: `test_main_has_three_lecterns_off_screen_from_the_start` (three in the group, each farther than 135 px from the player's start), `test_button_follows_the_interaction_target`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures for the missing classes and layer.
- [ ] **Step 3: Implement** the layer, `Lectern` and its scene, `InteractionComponent` and its player node, `InteractButton` and its scene, the three Lecterns and the button in `main.tscn`, and the `Main` wiring.
- [ ] **Step 4: Run to verify they pass.** Full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** and a godot MCP run. Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: Arcane Lecterns and player interaction"`, with the trailer.

---

### Task 7: CraftingSession

**Files:**
- Create: `scripts/crafting/crafting_session.gd`, `tests/test_crafting_session.gd`

**Interfaces:**
- Consumes: `CraftingSystem`, `CraftingRequest`, `CraftingResult`, `CraftingRules`, `SpellBuilder`, `ScrollInventory`, `SpellLoadout`.
- Produces `CraftingSession` (`class_name CraftingSession extends RefCounted`): `_init(rules: CraftingRules, inventory: ScrollInventory, loadout: SpellLoadout)`; `signal changed`; public state `base: ScrollData`, `area: ScrollData`, `option_index: int` (starts at `rules.normal_index()`), `slot_index: int` (starts at the selected slot if unlocked, else the first unlocked slot); `select_base(scroll: ScrollData) -> bool` and `select_area(scroll) -> bool` (reject null, the wrong category, or a scroll the player does not own; selecting the same scroll again clears it), `select_range(index: int) -> bool` (rejects a bad index), `select_slot(index: int) -> bool` (rejects locked or out-of-range); `owned_bases() -> Array[ScrollData]`, `owned_areas() -> Array[ScrollData]`, `owned_buffs() -> Array[ScrollData]` (read only, shown locked); `request() -> CraftingRequest`; `preview() -> SpellData`; `validation() -> CraftingResult`; `can_confirm() -> bool`; `confirm() -> CraftingResult` (calls `CraftingSystem.craft`, then clears a selected Base or Area the player no longer owns, and emits `changed`); `new_stats() -> Dictionary` and `current_stats() -> Dictionary` (via `SpellBuilder.describe`, empty when there is no preview or no spell in the target slot); `replace_note() -> String` ("Replaces Fire Missile (12 / 100 mana left)" when the slot holds a spell with mana left, "Replaces Fire Missile (empty)" when it is dry, "Empty slot" when nothing is there); `message() -> String` (the validation reason when not confirmable, else an empty string).

- [ ] **Step 1: Write the failing tests.** `test_crafting_session.gd`: `test_defaults` (Normal range, the selected unlocked slot, nothing chosen, `can_confirm()` false, `message()` is the no-Base reason), `test_empty_inventory_still_works` (owned lists empty, preview null, `message()` non-empty, nothing errors), `test_selecting_rules` (a scroll the player lacks, the wrong category and null are rejected, selecting the same scroll again clears it, `changed` emits only on real changes), `test_select_range_and_slot_reject_bad_values` (a bad range index, a locked slot, an out-of-range slot), `test_preview_follows_the_choices` (Thunder plus Wave at Long: the preview spell's cost, pool and range match `SpellBuilder`, and `new_stats()` matches `describe`), `test_current_stats_show_the_target_slot` (slot 0 holds Fire Missile: `current_stats()["name"]` is "Fire Missile"), `test_replace_note_variants` (mana left, dry, empty slot), `test_confirm_crafts_and_clears_spent_choices` (own one Fire and two Missile: after confirm the Base choice is cleared and the Area choice stays, and the slot holds the new spell), `test_confirm_when_invalid_changes_nothing` (no Area chosen: `ok` false, inventory unchanged), `test_owned_buffs_are_listed_but_never_craftable` (a Buff scroll in the inventory appears in `owned_buffs()`, and a request can never include it).
- [ ] **Step 2: Run to verify they fail.** Expected: fail, class missing.
- [ ] **Step 3: Implement** `CraftingSession`.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, the file, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: CraftingSession holds the workbench choices and previews"`, with the trailer.

---

### Task 8: The crafting screen, touch bridge, and wiring

**Files:**
- Create: `scripts/ui/touch_bridge.gd`, `scripts/ui/crafting_screen.gd`, `scenes/ui/crafting_screen.tscn`, `tests/test_touch_bridge.gd`, `tests/test_crafting_screen.gd`
- Modify: `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `CraftingSession`, `GamePause`, `Player.require_cast_release`, `Lectern.interacted`, `CraftingRules.default_rules()`.
- Produces `TouchBridge` (`class_name TouchBridge extends RefCounted`): `static to_mouse_button(event: InputEventScreenTouch) -> InputEventMouseButton` (left button, `pressed` and `position` copied, `global_position` set).
- Produces `CraftingScreen` (`class_name CraftingScreen extends CanvasLayer`, TEMPORARY look, `process_mode = Node.PROCESS_MODE_ALWAYS`, hidden at start): `signal closed`; `@export var pause_tree: bool = true`; `open(inventory: ScrollInventory, loadout: SpellLoadout) -> void` (builds a `CraftingSession`, rebuilds the widgets, pauses through `GamePause` when `pause_tree` is true, shows itself); `close() -> void` (unpauses the same way, hides, emits `closed`; does nothing if already closed); `is_open() -> bool`; `session: CraftingSession`; test-friendly actions `choose_base(scroll)`, `choose_area(scroll)`, `choose_range(index)`, `choose_slot(index)`, `confirm()` (crafts and closes if it worked, else shows the reason), `cancel()`; read-outs `preview_text() -> String`, `message_text() -> String`, `confirm_enabled() -> bool`. Layout at 480x270: a dim background; the five slot buttons across the top (spell name, colour swatch, mana, "locked" for locked slots, the target slot highlighted); three columns of buttons below for owned Base scrolls, owned Area scrolls and the four range options (selected ones highlighted); a locked Buff row (owned Buff scrolls shown disabled with a "locked" note); a right panel with the new spell's numbers (damage, interval, mana per cast, pool, casts, range) beside the current spell's, the replace note and the message; Confirm (disabled with the reason when invalid) and Cancel. All widgets are standard `Button`s and `Label`s, so mouse and keyboard or controller focus work. Cancel is also `ui_cancel` and the `pause` action. `_input` converts each `InputEventScreenTouch` while open through `TouchBridge` and `Input.parse_input_event`, then marks the event handled.
- `main.tscn` gets a `CraftingScreen` node. `Main._ready` connects every node in the `lecterns` group's `interacted` to `_open_crafting`, which does nothing if the player is dead, else opens the screen with the player's inventory and loadout. `CraftingScreen.closed` calls `_player.require_cast_release()`. `Main` hides the spell bar and the inventory button while the screen is open only if they would overlap the screen (they are inside the dim layer, so leave them as they are unless a manual check shows a problem).

- [ ] **Step 1: Write the failing tests.** `test_touch_bridge.gd`: `test_touch_becomes_a_left_mouse_press` and `test_release_becomes_a_left_mouse_release` (position preserved, `button_index` left, `pressed` copied). `test_crafting_screen.gd` (an inventory, a loadout and a screen built per test, `pause_tree = false` except in the one pause test, and `get_tree().paused = false` plus `GameTime.reset()` in `after_each`): `test_starts_closed_and_hidden`, `test_open_shows_it_and_close_hides_it_and_emits_closed`, `test_open_pauses_and_close_unpauses_when_enabled` (no awaits, restore the tree before the test ends), `test_empty_inventory_opens_with_confirm_disabled_and_a_reason` (`confirm_enabled()` false, `message_text()` non-empty), `test_preview_matches_the_builder` (choose Thunder, Wave and Long: `preview_text()` contains the builder's name, cost and pool), `test_current_spell_is_shown_beside_the_preview` (the text contains "Fire Missile" for slot 0), `test_confirm_crafts_consumes_and_closes` (the slot holds the new spell, counts drop by one each, the screen is closed), `test_confirm_when_invalid_shows_the_reason_and_changes_nothing`, `test_cancel_changes_nothing_and_closes`, `test_locked_slot_cannot_be_chosen`, `test_buffs_are_shown_locked` (an owned Buff scroll appears disabled and cannot be chosen), `test_ui_cancel_and_pause_actions_close_it` (send each `InputEventAction` through `_unhandled_input`), `test_touch_is_bridged_while_open` (an `InputEventScreenTouch` handed to `_input` while open is converted and handled; while closed it is ignored). `test_main.gd`: `test_interacting_with_a_lectern_opens_the_crafting_screen` (set the screen's `pause_tree` false, emit a Lectern's `interacted`: open), `test_dead_player_cannot_open_the_screen`, `test_closing_the_screen_blocks_casting_until_release` (after `closed`, holding `cast` fires nothing until released), `test_full_craft_through_main` (give scrolls through F10, open, choose Fire, Missile, Normal, confirm: the player's slot 0 is the new spell and the spell bar's widget shows it).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures for the missing classes.
- [ ] **Step 3: Implement** `TouchBridge`, `CraftingScreen` and its scene, and the `main.tscn` and `Main` wiring.
- [ ] **Step 4: Run to verify they pass.** Full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** and a godot MCP run (`run_project`, `get_debug_output`, `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: the crafting workbench screen, touch bridge and Lectern wiring"`, with the trailer.

---

### Task 9: Docs, stress check, wrap-up

**Files:**
- Modify: `README.md` (Lectern and crafting text: one starting spell, range choice, slots unlock with levels), `technical-design.md` (section 7: built notes for the builder, system, session and pause clock), `sprint-development.md` (tick Sprint 6 boxes and add a Built note), `CLAUDE.md` (Project State and a "Crafting (Sprint 6)" section), `development-log.md`, `docs/sprints/sprint-6-design.md` (Status: Built)

**Interfaces:** none (documentation and measurement).

- [ ] **Step 1: Run the stress test** at 300 enemies for the default Missile, `--area=wave` and `--area=zone`, each also with `--drops`: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=10` (plus `--area=<name>` and `--drops`). Record the six `STRESS` lines. Expected: `avg_fps` of at least 60 for all. If any is below 60, stop and report it before continuing.
- [ ] **Step 2: Update the docs** listed above. In `development-log.md` add a "Sprint 6 (crafting)" entry: the decisions and calls from `docs/sprints/sprint-6-design.md`, the baselines, multipliers and range options, the opening-ease change (pool 100 and 10% drops) with a note that it needs play-testing, the known limitations (buffs locked until Sprint 7, the F10 and F11 debug keys to delete later, the touch bridge needs a real-device check, no general pause menu), and the stress table beside the Sprint 5 numbers.
- [ ] **Step 3: Run the full suite** and the smoke run. Expected: all pass, no errors.
- [ ] **Step 4: Commit.** `git add -A && git commit -m "docs: Sprint 6 complete"`, with the trailer.
