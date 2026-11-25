# Sprint 10 Potions and Consumables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Six potions (Health, Mana, Speed, Damage, Invulnerability, Luck) that the player buys in the death-screen shop, carries as a saved stock, and drinks from a potion bar during a run, with timed effects, cooldowns and usage restrictions.

**Architecture:** `PotionData` resources in a `PotionCatalog` describe each potion by kind and numbers. A `PotionBelt` Player component holds the cooldowns and drinks potions through static `PotionSystem` rules. Timed bonuses live in an `ActiveEffects` Player component that owns one temporary `StatBonuses` layer. The Player holds three bonus layers (level, equipment, temporary) and one `refresh_bonuses` function adds them and pushes the result, replacing the two places that combine level and equipment by hand. Luck is a new stat that `DropTable.roll` reads. The potion stock is saved in `PlayerProfile.potions`, the shop gets a Potions row, and a `PotionBar` in the HUD shows and triggers the six slots.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-10-design.md` (approved). Also `docs/sprints/sprint-9-design.md`, `CLAUDE.md` and `technical-design.md` section 12.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, and zsh does not word-split unquoted variables.
- Work on branch `sprint-10-potions` (already cut from `main`, design committed). Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`). Use `git mv` for renames.
- Delete files only by literal full path. Scratch files go in the session scratchpad (never `/tmp`). Generate `.tres` files with a throwaway `venv/bin/python` script kept in the scratchpad, not the repo.
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, **no new autoloads**, Input Map actions only (device -1 on every event). Don't name a parameter `position` in a `Node2D` subclass, a local `owner`, or a parameter after a method of its own class (a Sprint 8 MCP warning). Every HUD or world `Control` that is not a button keeps `mouse_filter` IGNORE (`tests/test_world_input.gd`). In headless GUT runs pointer events never reach `_unhandled_input`, so touch behaviour is proven with a real-window script, not a headless test.
- **No code branches on a potion id.** Behaviour comes from `PotionData.kind` and its numbers. Bonuses are never written into a shared `SpellData` or `EnemyData`.
- **Tests never touch the real save** (`user://save.json`, the user plays with it). `SaveGame` calls take a path, and tests use a folder inside `res://.godot/save_tests/` that they create and remove. Every test that instantiates `main.tscn` sets `main.save_path` (an empty string means "do not load or save") and the pick screen's `pause_tree` before `add_child`. Report any change to the real save's checksum around a full suite run and check whether it was the user's own play (the file's content and time say).
- Existing behaviour must not change for a fresh profile with no potions: no temporary bonuses, luck 0 gives the exact old drop roll, level 1 stats, nothing equipped changes nothing.
- A refused potion is never consumed and changes nothing. Mana still never regenerates by itself (a Mana Potion is the explicit way), and `SpellInstance` owns mana.
- **Save format** (version stays 1; `potions` is optional and defaults to empty): `{"version": 1, "total_xp": int, "gold": int, "owned": [...], "equipped": {...}, "potions": {"potion_health": 3, ...}}`. Potion counts are whole numbers from 0 to 99 (`PlayerProfile.MAX_POTIONS`). A wrongly typed `potions` field (not a dictionary, a non-string key, a fractional, negative or above-99 count, a non-number) makes the file unusable (renamed to `.bak`, fresh profile, as in Sprint 8). A potion id that is not in the catalog is skipped when used. Zero counts are not written.
- **Stat layers.** `StatBonuses.Stat` gets LUCK appended (value 11, after DOUBLE_DAMAGE_CHANCE at 10). The Player has `level_bonuses`, `equipment_bonuses` and `temporary_bonuses` (each a `StatBonuses`, empty by default) and `refresh_bonuses(heal_difference: bool = false)` calls `apply_stat_bonuses(sum of the three, heal_difference)` and emits `bonuses_changed(total: StatBonuses)`. Nothing else pushes bonuses to the player and loadout except `apply_stat_bonuses` (kept as the low-level push, still callable on its own in tests).
- **Luck.** `DropTable.roll(rng, luck := 0.0)`: an entry's effective weight is `weight * rarity factor`, where the factor is 1.0 for COMMON, `1 + luck` for UNCOMMON and `1 + 2 * luck` for RARE, never below 0. If the effective total is 0 or less the roll falls back to luck 0. The drop chance is unchanged. At luck 0 the rolls of a seeded generator are exactly what they were before.
- **The six potions** (`resources/potions/<id>.tres`, in bar order):

  | id | name | kind | magnitude | duration | cooldown | price | modifiers |
  |---|---|---|---|---|---|---|---|
  | potion_health | Health Potion | HEAL | 0.40 | 0 | 10 | 40 | none |
  | potion_mana | Mana Potion | RESTORE_MANA | 0.50 | 0 | 15 | 60 | none |
  | potion_speed | Speed Potion | TIMED_BONUS | 0 | 15 | 30 | 30 | SPEED +0.40 |
  | potion_damage | Damage Potion | TIMED_BONUS | 0 | 15 | 30 | 50 | SPELL_DAMAGE +0.50 |
  | potion_invulnerability | Invulnerability Potion | INVULNERABILITY | 0 | 5 | 60 | 100 | none |
  | potion_luck | Luck Potion | TIMED_BONUS | 0 | 60 | 90 | 40 | LUCK +1.00 |

  Each has a one-line description and a placeholder colour (red, blue, green, orange, white, gold). Heal and Mana magnitudes are fractions of the maximum health and of each spell's bonus-aware pool (`SpellInstance.max_mana()`).
- **Refusals** (`PotionSystem` constants, checked in this order, a refused potion is not consumed and starts no cooldown): `REASON_UNKNOWN := "That potion does not exist."`, `REASON_DEAD := "You can't drink while dead."`, `REASON_NONE := "You have none left."`, `REASON_COOLDOWN := "Still cooling down."`, `REASON_SHARED := "Wait a moment."`, `REASON_ACTIVE := "Its effect is already running."`, `REASON_FULL_HEALTH := "Health is already full."`, `REASON_FULL_MANA := "Every spell is already full."`.
- **Cooldowns.** Each potion type's cooldown starts when it is drunk, and a shared cooldown of 1.0 s (`PotionBelt.SHARED_COOLDOWN`) starts with any drink. Both tick in `_process`, so they freeze while the tree is paused.
- **Inputs.** New Input Map actions: `potion_1` to `potion_6` (physical keys Z, X, C, V, B, N), `potion_prev` (controller D-pad left, button 13), `potion_next` (D-pad right, 14), `potion_use` (D-pad up, 11), and `debug_give_potions` (F8, physical keycode 4194339). Potions in bar order are Health, Mana, Speed, Damage, Invulnerability, Luck.
- Perf gate: `stress_test.tscn --enemies=300 --seconds=8 --drops` stays at or above 60 fps. The Sprint 9 medians were Missile 469.7, Wave 105.4 and Zone 173.2 fps. Report the new medians.

## Review Focus

- A refused potion (none left, cooldown, shared cooldown, effect already active, full health, full mana, dead player, unknown id) is never consumed, starts no cooldown and changes nothing. Pinned in Task 6.
- Level-ups, run start and a potion starting or ending give the same stats in any order, and never drop or double a bonus (level, equipment, temporary layers). Pinned in Tasks 1 and 5.
- Invulnerability: a hit during the window does nothing and starts no per-hit window, the per-hit window can't shorten or cancel the potion's, and the window ends on time. Pinned in Task 5.
- Pause and death: nothing can be drunk while dead, and timers and cooldowns freeze while the tree is paused. Pinned in Tasks 5 and 6.
- Luck of 0, negative, or huge never makes a weight negative, never makes every weight zero, and at 0 the roll is exactly the old one. A bad `potions` save field never crashes or loses XP and Gold silently. Pinned in Tasks 2 and 4.

---

### Task 1: The Player's three bonus layers

**Files:**
- Modify: `scripts/entities/player.gd`, `scripts/progression/run_start.gd`, `scripts/components/run_progress.gd`, `scripts/main/main.gd`, `tests/test_player.gd`, `tests/test_run_start.gd`, `tests/test_run_progress.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: the Sprint 9 `StatBonuses.combined`, `Player.apply_stat_bonuses`.
- `Player`: `signal bonuses_changed(total: StatBonuses)`; `var level_bonuses := StatBonuses.new()`, `var equipment_bonuses := StatBonuses.new()`, `var temporary_bonuses := StatBonuses.new()`; `refresh_bonuses(heal_difference: bool = false) -> void` as in the Global Constraints. `apply_stat_bonuses` keeps its signature.
- `RunStart.prepare(...)` keeps its signature but sets `player.level_bonuses = StatBonuses.for_level(track, level)` and `player.equipment_bonuses = ShopSystem.bonuses(profile, catalog)` and calls `player.refresh_bonuses(false)` (the temporary layer is left as it is).
- `RunProgress._apply` for a stat reward sets `_player.level_bonuses = StatBonuses.for_level(track, reached)` and calls `_player.refresh_bonuses(true)`. `RunProgress.equipment_bonuses` is removed, and `Main` no longer sets it.

- [ ] **Step 1: Write the failing tests.** `test_player.gd`: `test_refresh_bonuses_adds_the_three_layers` (level speed 0.08, equipment 0.10, temporary 0.40: speed 90 x 1.58), `test_refresh_bonuses_with_empty_layers_changes_nothing`, `test_layers_can_be_set_in_any_order_with_the_same_result` (two Players, layers set in opposite orders, same speed, health and loadout bonuses), `test_changing_one_layer_leaves_the_others` (set temporary, refresh, clear temporary, refresh: back to level plus equipment exactly), `test_refresh_bonuses_emits_bonuses_changed_with_the_total`, `test_refresh_twice_equals_once`, `test_refresh_with_heal_difference_heals_by_the_gain`. Migrate `test_run_start.gd` and `test_run_progress.gd` so they read the layers from the Player (the equipment tests assert `player.equipment_bonuses` and the final stats), replacing the `_progress.equipment_bonuses` setup in `test_run_progress.gd` with `_player.equipment_bonuses = ...`. `test_main_progression.gd`: `test_a_level_up_in_a_run_keeps_the_saved_equipment` and the restart test still pass, and add `test_the_temporary_layer_starts_empty_every_run`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files. Expected: failures or parse errors for the missing members.
- [ ] **Step 3: Implement** the layers, `refresh_bonuses` and the signal, update `RunStart`, `RunProgress` and `Main`.
- [ ] **Step 4: Run to verify they pass**, then the full suite.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors or warnings.
- [ ] **Step 6: Commit** `refactor: the player holds three bonus layers and one refresh` with the trailer.

---

### Task 2: Luck

**Files:**
- Modify: `scripts/progression/stat_bonuses.gd`, `resources/scrolls/drop_table.gd`, `scripts/systems/scroll_dropper.gd`, `scripts/main/main.gd`, `tests/test_stat_bonuses.gd`, `tests/test_drop_table.gd`, `tests/test_scroll_dropper.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- `StatBonuses.Stat.LUCK` (value 11).
- `DropTable.roll(rng: RandomNumberGenerator, luck: float = 0.0) -> ScrollData` per the Global Constraints, plus `static func rarity_factor(rarity: int, luck: float) -> float` (never below 0).
- `ScrollDropper`: `var luck: float = 0.0`; `on_enemy_died` rolls with it.
- `Main` connects `player.bonuses_changed` to a handler that sets `_dropper.luck = total.fraction(StatBonuses.Stat.LUCK)`.

- [ ] **Step 1: Write the failing tests.** `test_stat_bonuses.gd`: `test_luck_is_the_last_stat_and_defaults_to_zero`. `test_drop_table.gd`: `test_rarity_factor_per_rarity` (luck 1.0 gives 1, 2 and 3), `test_rarity_factor_is_never_negative` (luck -5 gives 1, 0, 0), `test_luck_zero_gives_exactly_the_old_rolls` (the same seed gives the same 200 scrolls with and without the luck argument, and equal to an explicit copy of the pre-luck algorithm kept in the test), `test_luck_raises_uncommon_and_rare_drops` (a table of one Common, one Uncommon and one Rare entry of equal weight, a fixed seed and 6000 rolls: counts near 1 : 2 : 3 at luck 1.0, within 10%), `test_huge_luck_still_rolls_a_scroll`, `test_negative_luck_never_makes_every_weight_zero` (a table of only Rare entries at luck -1: still drops, falling back to the plain weights), `test_drop_chance_is_unchanged_by_luck`. `test_scroll_dropper.gd`: `test_the_dropper_rolls_with_its_luck`. `test_main_progression.gd`: `test_the_scroll_dropper_follows_the_players_luck` (set the temporary layer's LUCK and refresh: the dropper's luck follows, and back to 0 when cleared).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the stat, the roll and the wiring.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: luck weights scroll drops by rarity` with the trailer.

---

### Task 3: Potion data

**Files:**
- Create: `resources/potions/potion_data.gd`, `resources/potions/potion_catalog.gd`, `resources/potions/potion_catalog.tres`, the six `resources/potions/*.tres`, `tests/test_potion_data.gd`

**Interfaces:**
- Consumes: `EquipmentModifier` and `StatBonuses.Stat` (Sprint 9, Task 2 above).
- Produces `PotionData` (`class_name PotionData extends Resource`): `enum Kind { HEAL, RESTORE_MANA, TIMED_BONUS, INVULNERABILITY }`; `@export var id: StringName`, `display_name: String`, `description: String`, `price: int`, `kind: Kind`, `magnitude: float`, `duration: float`, `cooldown: float`, `modifiers: Array[EquipmentModifier]`, `color: Color`.
- Produces `PotionCatalog` (`class_name PotionCatalog extends Resource`): `@export var potions: Array[PotionData]`; `static func default_catalog() -> PotionCatalog`; `find(id: StringName) -> PotionData` (null if unknown); `index_of(id: StringName) -> int` (-1 if unknown).

- [ ] **Step 1: Write the failing tests** in `test_potion_data.gd`: `test_catalog_matches_the_spec_table` (six potions in order with every field and modifier from the table), `test_ids_are_unique_and_every_potion_has_a_description_and_a_price`, `test_find_and_index_of`, `test_every_potion_has_a_positive_cooldown_and_timed_ones_a_duration` (timed and invulnerability kinds have a duration above 0, instant kinds 0), `test_a_timed_potions_cooldown_is_longer_than_its_duration`, `test_only_timed_bonus_potions_carry_modifiers`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then `-gselect=test_potion_data`.
- [ ] **Step 3: Implement** the classes, then generate the six items and the catalog with a scratchpad script (the format of `resources/equipment/items/*.tres` is the model).
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: potion data` with the trailer.

---

### Task 4: The potion stock and buying potions

**Files:**
- Modify: `scripts/progression/player_profile.gd`, `scripts/shop/shop_system.gd`, `scripts/shop/shop_result.gd`, `tests/test_player_profile.gd`, `tests/test_save_game.gd`, `tests/test_shop_system.gd`

**Interfaces:**
- Consumes: `PotionData`, `PotionCatalog` (Task 3), `ShopResult`.
- `PlayerProfile`: `const MAX_POTIONS := 99`; `var potions: Dictionary = {}` (id `StringName` to count `int`); `potion_count(id: StringName) -> int`; `add_potion(id: StringName, amount: int = 1) -> int` (returns how many were really added, clamped so the count never passes `MAX_POTIONS`, ignoring amounts at or below 0); `use_potion(id: StringName) -> bool` (consumes one, false if none, and removes a zero count). `to_dict` writes `potions` (counts above 0, ids as strings) and `from_dict` reads it per the Save format.
- `ShopResult` gains `var potion: PotionData`.
- `ShopSystem`: `const REASON_FULL := "You can't carry any more."`; `buy_potion(profile: PlayerProfile, catalog: PotionCatalog, id: StringName) -> ShopResult` (unknown id: `REASON_UNKNOWN`; too little Gold: `REASON_BROKE`; already 99: `REASON_FULL`; otherwise spends the price and adds one, with nothing changed on any failure); `can_afford_potion(profile, potion) -> bool`.

- [ ] **Step 1: Write the failing tests.** `test_player_profile.gd`: `test_fresh_profile_has_no_potions`, `test_add_potion_counts_and_clamps_at_99`, `test_add_potion_ignores_zero_and_negative_and_reports_what_was_added`, `test_use_potion_consumes_one_and_removes_a_zero_count`, `test_use_potion_with_none_returns_false`, `test_potions_round_trip_through_a_dictionary`, `test_zero_counts_are_not_written`, `test_old_save_without_potions_loads_empty`, `test_from_dict_rejects_bad_potion_fields` (not a dictionary, a non-string key, a fractional count, a negative count, a count of 100, a string count, each null). `test_save_game.gd`: `test_potions_survive_save_and_load`, `test_a_save_with_a_bad_potions_field_is_kept_as_bak`. `test_shop_system.gd`: `test_buy_potion_spends_gold_and_adds_one`, `test_buy_potion_with_exactly_enough_gold_succeeds`, `test_buy_potion_with_one_gold_too_few_fails_and_changes_nothing`, `test_buy_potion_at_99_fails_and_changes_nothing`, `test_buy_an_unknown_potion_fails_and_changes_nothing`, `test_buying_a_potion_does_not_touch_equipment`, `test_buying_several_potions_stacks`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the profile members, the save format and `buy_potion`.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: potion stock and buying potions` with the trailer.

---

### Task 5: Timed effects and the invulnerability window

**Files:**
- Create: `scripts/components/active_effects.gd`, `tests/test_active_effects.gd`
- Modify: `scripts/components/hurtbox_component.gd`, `scripts/entities/player.gd`, `scenes/player/player.tscn`, `tests/test_hurtbox_hitbox.gd`

**Interfaces:**
- Consumes: `Player.temporary_bonuses` and `refresh_bonuses` (Task 1), `PotionData` (Task 3).
- `HurtboxComponent`: `grant_invulnerability(seconds: float)` (a window separate from the per-hit `_invulnerable_left`, keeping the longer remaining time if called again), `is_invulnerable()` is true while either window runs, a hit during either does nothing, and the per-hit window can neither shorten nor clear the potion's. It ticks in `_process` and so freezes while paused.
- Produces `ActiveEffects` (`class_name ActiveEffects extends Node`, a Player child named `ActiveEffects`, `@onready var effects: ActiveEffects = $ActiveEffects` on the Player): `signal changed`; `bind(player: Player)`; `start(potion: PotionData) -> bool` (false, changing nothing, if that potion is already active; otherwise records it with `potion.duration`, and for INVULNERABILITY calls the hurtbox's `grant_invulnerability`; then rebuilds the temporary layer, sets `player.temporary_bonuses`, calls `player.refresh_bonuses(true)` and emits `changed`); `is_active(id: StringName) -> bool`; `time_left(id: StringName) -> float`; `ratio(id: StringName) -> float` (time left over duration, 0 when not active); `clear()` (drops every effect, empties the layer and refreshes). `_process(delta)` counts down, and an expired effect is removed with the layer rebuilt and `changed` emitted. Only TIMED_BONUS potions contribute modifiers to the layer.

- [ ] **Step 1: Write the failing tests.** `test_hurtbox_hitbox.gd`: `test_granted_invulnerability_blocks_hits`, `test_a_blocked_hit_starts_no_per_hit_window`, `test_the_window_ends_on_time` (a hit lands just after it ends), `test_the_per_hit_window_does_not_shorten_the_granted_one`, `test_a_longer_grant_replaces_a_shorter_one_and_a_shorter_never_replaces_a_longer`, `test_grant_invulnerability_ignores_zero_and_negative_seconds`, `test_both_windows_expire_independently`. `test_active_effects.gd` (a Player in the tree): `test_starting_a_speed_potion_raises_speed_and_expiry_restores_it` (90 to 126 and back after `_process(15.1)`), `test_expiry_never_drops_level_or_equipment_bonuses` (level speed 0.08 and equipment 0.10 stay), `test_two_different_timed_potions_stack_in_the_layer` (Speed and Damage together), `test_starting_an_active_potion_again_is_refused_and_changes_nothing`, `test_changed_is_emitted_on_start_and_on_expiry`, `test_time_left_and_ratio_count_down`, `test_damage_potion_reaches_the_loadouts_bonuses`, `test_luck_potion_reaches_bonuses_changed`, `test_invulnerability_potion_blocks_hits_and_runs_for_its_duration`, `test_effects_are_not_carried_into_a_new_player` (a fresh Player has none), `test_clear_removes_everything_and_refreshes`, `test_effect_timers_use_a_pausable_process_mode` (parent the component under a plain Node whose `process_mode` is PAUSABLE, pause the tree and confirm `can_process()` is false, then unpause: do not rely on the GUT runner's own mode).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the hurtbox change, the component, and the node in `player.tscn`.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: timed effects and the invulnerability window` with the trailer.

---

### Task 6: Drinking potions

**Files:**
- Create: `scripts/potions/potion_system.gd`, `scripts/potions/potion_result.gd`, `scripts/components/potion_belt.gd`, `tests/test_potion_system.gd`, `tests/test_potion_belt.gd`
- Modify: `scripts/entities/player.gd`, `scenes/player/player.tscn`, `scripts/main/main.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: `PotionData`/`PotionCatalog` (Task 3), `PlayerProfile.potion_count`/`use_potion` (Task 4), `ActiveEffects` (Task 5), `SpellInstance.restore_mana`, `HealthComponent.heal`.
- Produces `PotionResult` (`class_name PotionResult extends RefCounted`): `var ok: bool`, `var reason: String`, `var potion: PotionData`.
- Produces `PotionSystem` (`class_name PotionSystem extends RefCounted`, all static, the reason constants from the Global Constraints): `refusal(potion: PotionData, player: Player, profile: PlayerProfile, cooldown_left: float, shared_left: float) -> String` (empty when the potion can be drunk, checked in the order listed; Mana is "full" when every filled slot has `current_mana >= max_mana()`, and a player with no spells counts as full); `apply(potion: PotionData, player: Player) -> void` (HEAL heals `magnitude * max_health`; RESTORE_MANA calls `restore_mana(magnitude * max_mana())` on every filled slot; TIMED_BONUS and INVULNERABILITY call `player.effects.start(potion)`).
- Produces `PotionBelt` (`class_name PotionBelt extends Node`, a Player child named `PotionBelt`, `@onready var belt: PotionBelt = $PotionBelt` on the Player): `const SHARED_COOLDOWN := 1.0`; `signal used(potion: PotionData)`, `signal refused(reason: String)`, `signal changed`; `bind(player: Player, profile: PlayerProfile, catalog: PotionCatalog)`; `use(id: StringName) -> PotionResult` (refuses through `PotionSystem.refusal`, emitting `refused` and consuming nothing; otherwise applies, calls `profile.use_potion`, starts the type cooldown and the shared cooldown, emits `used` and `changed`); `count(id) -> int`; `cooldown_left(id) -> float`; `cooldown_ratio(id) -> float` (left over the potion's cooldown); `shared_left() -> float`; `var selected_index: int`; `select(step: int)` (moves the controller selection through the catalog order, wrapping); `use_selected() -> PotionResult`. `_process(delta)` ticks the cooldowns.
- `Main` binds the belt after the profile loads (`player.belt.bind(player, profile, potion_catalog)`) and connects `belt.used` to `saver.save_now` (so a drunk potion is saved at once). `Main` keeps a `potion_catalog` variable.

- [ ] **Step 1: Write the failing tests.** `test_potion_system.gd`: one test per refusal with a Player, a profile and a catalog: `test_refuses_an_unknown_potion`, `test_refuses_when_dead`, `test_refuses_when_none_left`, `test_refuses_during_the_types_cooldown`, `test_refuses_during_the_shared_cooldown`, `test_refuses_a_timed_potion_whose_effect_is_active`, `test_refuses_health_at_full_health`, `test_refuses_mana_when_every_spell_is_full`, `test_refusal_order_is_the_documented_one`, `test_allows_a_valid_drink` (empty string). `apply` tests: `test_health_heals_forty_percent_of_max_health_and_never_overheals` (health 10 of 100 gives 50, health 90 gives 100), `test_health_uses_the_boosted_max_health`, `test_mana_restores_half_of_each_spells_pool` (a drained 1000 pool gives 500, two spells both restored, never above the pool, bonus pool respected), `test_speed_damage_and_luck_start_timed_effects`, `test_invulnerability_starts_the_window`. `test_potion_belt.gd`: `test_use_consumes_exactly_one_and_starts_the_cooldowns`, `test_a_refused_use_consumes_nothing_and_starts_no_cooldown` (for several reasons, with the profile and the cooldown values unchanged and `refused` emitted with the reason), `test_use_emits_used_and_changed`, `test_cooldown_ticks_down_and_allows_a_second_drink` (`_process`), `test_shared_cooldown_blocks_a_different_potion_for_one_second`, `test_each_type_has_its_own_cooldown`, `test_mashing_burns_only_one_potion` (ten rapid uses of Health at low health: one consumed), `test_cooldowns_use_a_pausable_process_mode`, `test_cooldown_ratio_goes_from_one_to_zero`, `test_select_wraps_through_the_catalog_and_use_selected_drinks_it`, `test_a_potion_id_missing_from_the_catalog_is_refused_and_skipped`, `test_count_follows_the_profile`. `test_main_progression.gd`: `test_drinking_a_potion_is_saved_at_once` (a saved profile with 2 Health Potions, the player hurt: after `belt.use`, the file holds 1), `test_a_refused_drink_does_not_change_the_save`, `test_a_new_run_has_fresh_cooldowns_and_no_effects_but_keeps_the_stock`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the three classes, the Player node and the `Main` wiring.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: drinking potions` with the trailer.

---

### Task 7: The potion bar and the inputs

**Files:**
- Create: `scripts/ui/potion_slot_widget.gd`, `scripts/ui/potion_bar.gd`, `scenes/ui/potion_bar.tscn`, `tests/test_potion_slot_widget.gd`, `tests/test_potion_bar.gd`
- Modify: `project.godot` (input map), `scripts/entities/player.gd`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_input_map.gd`, `tests/test_player.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: `PotionBelt` (Task 6), `ActiveEffects` (Task 5), `PotionCatalog`, `LevelToast.show_message`.
- Input Map: the actions in the Global Constraints (keys Z X C V B N, D-pad 13, 14, 11, F8). `Player._unhandled_input` (alive only) maps `potion_1` to `potion_6` to `belt.use(catalog potion at that index)`, `potion_prev` and `potion_next` to `belt.select(-1 or 1)`, and `potion_use` to `belt.use_selected()`. It does not handle them while dead.
- Produces `PotionSlotWidget` (`class_name PotionSlotWidget extends Control`, TEMPORARY look, built like `SpellSlotWidget`, `mouse_filter` IGNORE, handles its own touches in `_input` and marks them handled so a tap never casts): `signal pressed(index: int)`; `setup(index: int, potion: PotionData, key_text: String)`; `set_count(count: int)` (dimmed at 0); `set_cooldown(ratio: float)` (an overlay from full to empty); `set_effect(ratio: float)` (a shrinking timer bar, hidden at 0); `set_selected(selected: bool)`; `handle_touch(screen_position: Vector2) -> bool`.
- Produces `PotionBar` (`class_name PotionBar extends Control`, TEMPORARY look, `mouse_filter` IGNORE): `bind(belt: PotionBelt, effects: ActiveEffects, catalog: PotionCatalog)`; six widgets in catalog order in a column at the top right (below the inventory button); `signal slot_pressed(index: int)`; it refreshes counts and selection on the belt's `changed` and, only while any cooldown or effect is running, every frame; key hints Z, X, C, V, B, N.
- `Main`: `potion_bar.slot_pressed` calls `player.belt.use(...)` for that potion, `belt.refused` calls `_level_toast.show_message(reason)`, the bar hides on death (like the spell bar), and DEBUG F8 (`debug_give_potions`) adds 3 of every potion and saves.

- [ ] **Step 1: Write the failing tests.** `test_input_map.gd`: every new action exists with the right event type (keys for `potion_1` to `potion_6` and `debug_give_potions`, joypad buttons for `potion_prev`, `potion_next`, `potion_use`) and device -1. `test_potion_slot_widget.gd`: `test_setup_shows_the_key_and_colour`, `test_count_zero_dims_the_slot`, `test_cooldown_overlay_follows_the_ratio`, `test_effect_bar_shows_only_while_running`, `test_a_touch_on_the_widget_emits_pressed_and_is_handled`, `test_a_touch_elsewhere_is_ignored`, `test_ignores_the_mouse`. `test_potion_bar.gd`: `test_six_widgets_in_catalog_order_with_key_hints`, `test_counts_follow_the_profile`, `test_cooldown_and_effect_follow_the_belt_and_effects`, `test_a_tap_emits_slot_pressed_with_the_index`, `test_selection_highlight_follows_the_belt`, `test_the_bar_only_processes_while_something_is_running`, `test_every_control_ignores_the_mouse`. `test_player.gd`: `test_potion_key_actions_drink_the_matching_potion`, `test_controller_actions_select_and_use`, `test_a_dead_player_cannot_drink`. `test_main_progression.gd`: `test_tapping_a_slot_drinks_that_potion`, `test_a_refused_drink_shows_its_reason_in_the_toast`, `test_the_potion_bar_hides_on_death`, `test_f8_gives_three_of_every_potion_and_saves`, `test_a_potion_tap_does_not_cast_a_spell` (the spell's mana is unchanged).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the input map entries, the widgets, the bar, the Player handling and the `Main` wiring. Hand-written `.tscn` rules from CLAUDE.md apply.
- [ ] **Step 4: Run to verify they pass**, then the full suite and `tests/test_world_input.gd`.
- [ ] **Step 5: Real-window touch check.** With a throwaway script in the scratchpad run in a real window (not headless), as in Sprint 9: give the player potions (a throwaway profile, never the real save), send `InputEventScreenTouch` events (window position = game position times `root.get_final_transform()`) on a potion slot, confirm the potion is drunk exactly once and no spell fires, confirm a tap elsewhere still behaves as before, then delete the script. Record the result in the ledger. If a real window cannot be driven, say so in the final message.
- [ ] **Step 6: MCP run** (`run_project`, `get_debug_output`, `stop_project`) and a smoke run. Expected: no errors or warnings.
- [ ] **Step 7: Commit** `feat: the potion bar and its inputs` with the trailer.

---

### Task 8: The shop's Potions row

**Files:**
- Modify: `scripts/ui/shop_screen.gd`, `scripts/main/main.gd`, `tests/test_shop_screen.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: `ShopSystem.buy_potion` (Task 4), `PotionCatalog` (Task 3).
- `ShopScreen.open(profile: PlayerProfile, catalog: EquipmentCatalog, potion_catalog: PotionCatalog = null)` (null uses `PotionCatalog.default_catalog()`, so existing callers keep working); a Potions row of six buttons below the equipment columns, labelled "Health Potion 40g (x2)" (name, price, how many owned); pressing one calls a new `buy_potion(id: StringName)` (which shows the reason on failure, emits `changed` on success and refreshes the labels and Gold); `potion_button_count() -> int`; `potion_button_text(id: StringName) -> String`. The same `input_guard_msec` ignores presses right after the shop opens, and the detail text shows a potion's description on focus. Every non-button control keeps `mouse_filter` IGNORE.
- `Main` passes `potion_catalog` to the shop.

- [ ] **Step 1: Write the failing tests.** `test_shop_screen.gd`: `test_open_lists_the_six_potions`, `test_buy_potion_through_the_screen_spends_gold_adds_one_and_emits_changed`, `test_failed_potion_buy_shows_the_reason_and_emits_nothing`, `test_potion_labels_show_the_count_and_update`, `test_buying_a_potion_does_not_change_equipment`, `test_potion_presses_inside_the_input_guard_do_nothing`, `test_potion_buy_stops_at_99`, `test_the_equipment_list_still_has_fifteen_buttons`, `test_every_non_button_control_ignores_the_mouse` still passes. `test_main_progression.gd`: `test_a_potion_bought_in_the_death_screen_shop_is_saved_at_once`, `test_next_run_has_the_bought_potion_in_the_bar` (buy Health, free the Main, load again: the belt's count is 1 and the bar shows it).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the row and the `Main` change.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: the shop sells potions` with the trailer.

---

### Task 9: Stress gate, docs and the manual check

**Files:**
- Modify: `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `docs/sprints/sprint-10-design.md` (Status: Built), the memory file `sprint-0-decisions.md`

- [ ] **Step 1: Measure.** Run `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --area=<missile|wave|zone>` three times each and take the median. Expected: at or above 60 fps. If a median is more than 10% below the Sprint 9 figure, profile before changing anything and record the finding as a ruling.
- [ ] **Step 2: Docs.** `sprint-development.md`: tick the Sprint 10 boxes (potion inventory is the saved stock, cooldowns and usage restrictions as built) and add a Built note. `README.md`: the potion table with the numbers (price, effect, duration, cooldown), the refusal rules, carrying everything with a bar, and the keys and controller buttons. `technical-design.md`: the `potions` save field. `CLAUDE.md`: a "Potions (Sprint 10)" section (data-driven `PotionData`, `PotionSystem` rules, `PotionBelt` and `ActiveEffects`, the Player's three bonus layers and `refresh_bonuses` as the one place bonuses are pushed, luck in `DropTable.roll`, the potion bar and its own touch handling, the new inputs and F8) and the Project State line. `development-log.md`: "2026-11-22: Sprint 10 (potions)" with decisions, rulings, migration notes (`RunProgress.equipment_bonuses` removed, the Player's layers, `DropTable.roll` takes luck), limitations (potion effect numbers untested in play, TEMPORARY looks, potions only bought in the death-screen shop, controller uses D-pad select and use, no confirmation dialog) and the stress table. Mark `docs/sprints/sprint-10-design.md` Status: Built.
- [ ] **Step 3: Manual test notes** for the final message: press F8 for potions (or buy them on the death screen), drink each with Z to N or by tapping, check Health refuses at full health and Mana when full, check Speed and Damage timers on the bar, check Invulnerability blocks hits, check a refused potion is not used up, check potions survive death and a restart, and delete `save.json` to reset.
- [ ] **Step 4: Full suite and smoke run.** Expected: all pass, no errors.
- [ ] **Step 5: Commit** `docs: Sprint 10 complete` with the trailer.
