# Sprint 9 Gold, Equipment and the Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enemies drop Gold that is banked and saved, the player buys and equips Robes, Wands, Staffs, Hats and Hoods in a shop on the death screen, equipment modifiers (element damage, spell damage, casting speed, cast-twice and double-damage chances) reach every cast through one modifier path, and starting-spell buffs are picked or re-rolled every run instead of being saved.

**Architecture:** `StatBonuses` (the Sprint 8 modifier object) gains the new stats, and level rewards plus equipped items add into one object that `Player.apply_stat_bonuses` pushes to the player and the loadout. A static `CastMath` holds the damage, interval and pool formulas, shared by the loadout and the crafting preview. `SpellLoadout.try_cast` sets a per-cast `damage_scale` on each effect and rolls the two chance effects. XP gems and Gold coins share one `ValueGem` pickup and one `ValueDropper`. Equipment is data (`EquipmentData` in an `EquipmentCatalog`), the rules live in a static `ShopSystem`, and a `ShopScreen` opens from a Shop button on the death screen. Starting-spell buffs move from the saved profile into an in-memory `RunBuffs`.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-9-design.md` (approved). Also `docs/sprints/sprint-8-design.md`, `CLAUDE.md` and `technical-design.md` sections 10 and 11.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, and zsh does not word-split unquoted variables.
- Work on branch `sprint-9-gold-equipment` (already cut from `main`, design committed). Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`). Use `git mv` for renames.
- Delete files only by literal full path. Scratch files go in the session scratchpad. Generate `.tres` files with a throwaway `venv/bin/python` script kept in the scratchpad, not the repo.
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, **no new autoloads**, Input Map actions only (device -1 on every event). Don't name a parameter `position` in a `Node2D` subclass or a local `owner`. A parameter must not share a name with a method of its own class (a Sprint 8 MCP warning). Every HUD or world `Control` that is not a button keeps `mouse_filter` IGNORE (`tests/test_world_input.gd`). In headless GUT runs pointer events never reach `_unhandled_input`, so touch behaviour is proven with a real-window script, not a headless test.
- **No code branches on an equipment id, a buff id or a level.** Bonuses are never written into a shared `SpellData` or `EnemyData`. Elemental rules stay in `DamageSystem`/`ElementTable`.
- **Tests never touch the real save** (`user://save.json`, the user plays with it). `SaveGame` calls take a path, and tests use a folder inside `res://.godot/save_tests/` that they create and remove. Every test that instantiates `main.tscn` sets `main.save_path` (an empty string means "do not load or save") and the pick and shop screens' `pause_tree` where they have one, before `add_child`. Compare the real save's checksum before and after a full suite run and report any difference.
- Existing behaviour must not change for a fresh profile with nothing equipped: no bonuses, damage scale 1.0, interval unchanged, one launch per cast, level-1 stats, Fire Missile unmodified.
- Mana still never regenerates and `SpellInstance` owns mana. A failed purchase or equip never changes the profile.
- **Save format** (version stays 1; missing optional fields take their defaults): `{"version": 1, "total_xp": int, "gold": int, "owned": ["robe_ember", ...], "equipped": {"0": "robe_ember", "1": "wand_quick", "2": "hat_mana"}}`. Slot keys: 0 ROBE, 1 WEAPON, 2 HEADWEAR. `total_xp` and `gold` must be whole numbers from 0 to 2^53 (9007199254740992), and a whole number means `value == floorf(value)` exactly. `buff_picks` in an old file is ignored (and gone after the next save). A wrongly typed present field makes the file unusable (renamed to `.bak`, fresh profile, as in Sprint 8). An `equipped` entry whose id is not in `owned` is dropped on load. Unknown ids are skipped where used.
- **Modifier stats** (`StatBonuses.Stat`, appended after the existing three, in this order): SPEED, HEALTH, SPELL_MANA, DAMAGE_FIRE, DAMAGE_THUNDER, DAMAGE_LAND, DAMAGE_SEA, SPELL_DAMAGE, CAST_SPEED, CAST_TWICE_CHANCE, DOUBLE_DAMAGE_CHANCE. `StatBonuses.damage_stat(element: int) -> int` maps `SpellData.Element` FIRE, THUNDER, LAND, SEA to the four damage stats and anything else to -1.
- **Cast math** (`CastMath`, all static, taking fractions): damage scale = `(1 + spell damage)` times the mean over the spell's elements of `(1 + that element's bonus)` (no elements: 1.0), never below 0.1, times 2.0 when double damage rolls. Interval = `base / max(1 + casting speed, 0.1)`, never below `min(0.05, base)`. Pool = `base * (1 + spell mana)`. A chance is clamped to 0..1, and `chance >= 1` always succeeds and `chance <= 0` never does.
- **Cast effects.** One roll each per cast, from the loadout's `rng`. Double damage multiplies the damage scale of every shot of that cast by 2. Cast twice launches every shot a second time at once: no extra mana, no cooldown change, no second roll.
- **Gold rewards:** plain 1, Fire 1, Thunder 1, Sea 2, Land 3. Gold coins use the Sprint 8 gem rules: cap 150, a new drop merges into the oldest at the cap, nothing is lost.
- **Catalog** (`resources/equipment/items/<id>.tres`, in this order in the catalog):

  | id | name | category | price | modifiers |
  |---|---|---|---|---|
  | robe_ember | Ember Robe | ROBE | 100 | DAMAGE_FIRE +0.15 |
  | robe_storm | Storm Robe | ROBE | 100 | DAMAGE_THUNDER +0.15 |
  | robe_stone | Stone Robe | ROBE | 100 | DAMAGE_LAND +0.15 |
  | robe_tide | Tide Robe | ROBE | 100 | DAMAGE_SEA +0.15 |
  | robe_warded | Warded Robe | ROBE | 120 | HEALTH +0.30 |
  | hat_mana | Mana Hat | HAT | 80 | SPELL_MANA +0.10 |
  | hat_swift | Swift Hat | HAT | 80 | SPEED +0.10 |
  | hat_hardy | Hardy Hat | HAT | 80 | HEALTH +0.20 |
  | hood_mana | Mana Hood | HOOD | 80 | SPELL_MANA +0.10 |
  | hood_swift | Swift Hood | HOOD | 80 | SPEED +0.10 |
  | hood_hardy | Hardy Hood | HOOD | 80 | HEALTH +0.20 |
  | wand_quick | Quickwand | WAND | 200 | CAST_SPEED +0.25, SPELL_DAMAGE -0.15, CAST_TWICE_CHANCE +0.10 |
  | wand_flicker | Flickerwand | WAND | 350 | CAST_SPEED +0.40, SPELL_DAMAGE -0.30, CAST_TWICE_CHANCE +0.15 |
  | staff_oak | Oak Staff | STAFF | 200 | SPELL_DAMAGE +0.25, CAST_SPEED -0.15, DOUBLE_DAMAGE_CHANCE +0.10 |
  | staff_elder | Elder Staff | STAFF | 350 | SPELL_DAMAGE +0.45, CAST_SPEED -0.30, DOUBLE_DAMAGE_CHANCE +0.15 |

  Slots: ROBE is slot 0, WAND and STAFF are slot 1 (WEAPON), HAT and HOOD are slot 2 (HEADWEAR). Each item has a one-line description and a placeholder colour (Robes use their element's colour, the rest are neutral).
- Level rewards are unchanged, except these `description` texts in `level_track.tres`: levels 7 and 17 "Next run: a random buff for your starting spell" (level 17: "second spell"), levels 12 and 19 "Next run: choose a buff for your starting spell" (level 19: "second spell").
- Perf gate: `stress_test.tscn --enemies=300 --seconds=8 --drops` (now dropping XP gems and Gold coins) stays at or above 60 fps. The Sprint 8 medians with gems were Missile 472.3, Wave 129.7 and Zone 211.2 fps. Report the new medians.

## Review Focus

- A purchase with exactly enough Gold succeeds, with one Gold too few it fails, buying twice or buying an unknown id fails, and every failure changes neither Gold, the owned list nor the equipped items. Pinned in Task 6.
- A tap or key on the death screen's Shop button never restarts the run, and the restart is ignored while the shop is open. Pinned in Task 9 (and checked on a real window).
- Equipment bonuses are neither lost nor applied twice across run start, a restart and mid-run level-ups. Pinned in Task 8.
- An old save (with `buff_picks`, without `gold`, `owned` and `equipped`), a save that equips an item it does not own, huge or wrongly typed values and a newer version never crash and never lose Gold silently. Pinned in Task 2.
- Cast chances of 0, 1, above 1 and below 0, a damage scale driven to its floor, and a cast twice with no mana left for a second cast all give defined results (one mana payment, one cooldown). Pinned in Task 7.

---

### Task 1: Starting-spell buffs are picked or re-rolled every run

**Files:**
- Create: `scripts/progression/run_buffs.gd`, `tests/test_run_buffs.gd`
- Modify: `scripts/progression/starting_buffs.gd`, `scripts/progression/run_start.gd`, `scripts/progression/player_profile.gd`, `scripts/components/run_progress.gd`, `scripts/main/main.gd`, `scripts/ui/level_toast.gd`, `resources/progression/level_track.tres`, `tests/test_starting_buffs.gd`, `tests/test_run_start.gd`, `tests/test_player_profile.gd`, `tests/test_save_game.gd`, `tests/test_run_progress.gd`, `tests/test_main_progression.gd`, `tests/test_level_toast.gd`

**Interfaces:**
- Produces `RunBuffs` (`class_name RunBuffs extends RefCounted`): `var picks: Dictionary = {}` (reward level int to buff scroll id `StringName`); `set_pick(level: int, buff_id: StringName)`; `pick(level: int) -> StringName` (`&""` if none).
- `StartingBuffs` takes a `RunBuffs` where it took a `PlayerProfile`, and `settle_random` is renamed `roll_random`: `unresolved_levels(buffs: RunBuffs, track, level, kind) -> Array[int]`, `roll_random(buffs: RunBuffs, track, level, rng) -> Array[int]`, `options_for(buffs: RunBuffs, track, reward_level) -> Array[ScrollData]`, `buffs_for_spell(buffs: RunBuffs, track, level, spell_index) -> Array[ScrollData]`, `find_scroll(track, id)` unchanged. Same rules as Sprint 8, with the stack caps counting only this run's picks.
- `PlayerProfile` loses `buff_picks`, `set_pick` and `pick`. `to_dict` no longer writes `buff_picks`, and `from_dict` no longer requires it (an old file's `buff_picks` is ignored).
- `RunStart.prepare(player: Player, profile: PlayerProfile, track: LevelTrack, run_buffs: RunBuffs) -> void` (the profile gives the level; the buffs come from `run_buffs`).
- `RunProgress` loses `starting_buffs_hook`: reaching a RANDOM_BUFF, CHOSEN_BUFF or SECOND_SPELL level mid-run changes nothing.
- `LevelToast.show_message(text: String)`: appends a line (same list, cap and timing as `show_level_up`) without the "Level N!" prefix.
- `Main` flow at every run start: new `RunBuffs`; `roll_random` for the profile's level; for each unresolved CHOSEN_BUFF level in order, if `options_for` is not empty open the pick screen and store the pick in the `RunBuffs` (no saving); `RunStart.prepare(...)`; then one toast line per rolled buff ("Starting spell gains <name>" or "Second spell gains <name>", chosen by the reward's `spell_index`). Nothing is saved for buffs.

- [ ] **Step 1: Write the failing tests.** `test_run_buffs.gd`: `test_fresh_run_buffs_have_no_picks`, `test_set_and_read_a_pick`, `test_picks_are_per_instance` (two instances never share). Migrate `test_starting_buffs.gd` and `test_run_start.gd` to `RunBuffs` and `roll_random` (same cases as Sprint 8, including the stack-cap, no-options, deterministic-seed and unknown-id cases). `test_player_profile.gd`: remove the pick cases, add `test_old_save_with_buff_picks_still_loads_and_the_field_is_dropped` (a dictionary with `buff_picks` loads, and `to_dict` has no `buff_picks` key) and `test_from_dict_does_not_require_buff_picks`. `test_save_game.gd`: the round-trip test no longer sets a pick, and add `test_saved_file_has_no_buff_picks`. `test_run_progress.gd`: drop the hook test and add `test_random_buff_level_changes_nothing_mid_run` (reaching level 7 makes no pick object and no spell change). `test_level_toast.gd`: `test_show_message_appends_a_line_without_a_level_prefix` and `test_messages_and_level_ups_share_the_four_line_cap`. `test_main_progression.gd`: replace the stored-pick tests with `test_random_buff_reward_mid_run_changes_nothing_until_next_run`, `test_random_buffs_are_rolled_every_run_and_never_saved` (a level-7 save loaded twice: each run's first spell has buff stacks, and the file has no `buff_picks`), `test_chosen_buff_is_asked_every_run_even_after_choosing` (choose in run one, run two opens the screen again), update the owned-chosen test (after choosing, the first spell carries the pick and the file has no `buff_picks`), keep `test_unchosen_buff_is_asked_again_next_run`, and add `test_run_start_toast_names_the_rolled_buff`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files. Expected: parse errors for `RunBuffs`, `roll_random` and `show_message`.
- [ ] **Step 3: Implement** the classes and the `Main` flow, update the five `level_track.tres` descriptions, and delete `_on_random_buff_reached` and `_buff_notice` from `Main`.
- [ ] **Step 4: Run to verify they pass**, then the full suite.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors or warnings.
- [ ] **Step 6: Commit** `feat: starting-spell buffs are picked or re-rolled every run` with the trailer.

---

### Task 2: The profile holds Gold, owned and equipped items

**Files:**
- Modify: `scripts/progression/player_profile.gd`, `scripts/progression/save_game.gd` (only if a path needs it), `tests/test_player_profile.gd`, `tests/test_save_game.gd`

**Interfaces:**
- Consumes: the Task 1 `PlayerProfile` (no `buff_picks`).
- Produces on `PlayerProfile`: `const MAX_VALUE := 9007199254740992`; `var gold: int = 0`; `var owned: Array[StringName] = []`; `var equipped: Dictionary = {}` (slot int to id `StringName`); `add_gold(amount: int)` (ignores amounts at or below 0, clamps at `MAX_VALUE`); `spend_gold(amount: int) -> bool` (false and no change if `amount <= 0` or it exceeds `gold`); `owns(id: StringName) -> bool`; `grant(id: StringName)` (no duplicates); `equip(slot: int, id: StringName)`; `unequip(slot: int)`; `equipped_id(slot: int) -> StringName` (`&""` if none). `add_xp` also clamps at `MAX_VALUE`. `from_dict` and `to_dict` follow the Save format in the Global Constraints.

- [ ] **Step 1: Write the failing tests.** `test_player_profile.gd`: `test_fresh_profile_has_no_gold_or_items`, `test_add_gold_ignores_zero_and_negative_and_clamps`, `test_spend_gold_succeeds_with_exactly_enough`, `test_spend_gold_fails_with_one_too_few_and_changes_nothing`, `test_spend_gold_rejects_zero_and_negative`, `test_grant_never_duplicates`, `test_equip_and_unequip_a_slot`, `test_gold_items_and_equipment_round_trip_through_a_dictionary`, `test_old_save_without_gold_owned_equipped_loads_with_defaults`, `test_equipped_item_that_is_not_owned_is_dropped_on_load`, `test_from_dict_rejects_bad_shapes` extended with: string gold, fractional gold, negative gold, gold above 2^53, `total_xp` above 2^53, `owned` not an array, an `owned` entry that is not a string, `equipped` not a dictionary, an `equipped` key that is not 0, 1 or 2, a non-string `equipped` value, version 1.0000000001 and `total_xp` 30.000001 (each null), plus `test_add_xp_clamps_at_the_limit`. `test_save_game.gd`: `test_gold_and_equipment_survive_save_and_load`, `test_large_gold_survives_exactly`.
- [ ] **Step 2: Run to verify they fail.** Expected: failures for the missing members.
- [ ] **Step 3: Implement** the members and the stricter `_is_whole_number` (`value == floorf(value)` and within 0..`MAX_VALUE` where a range applies).
- [ ] **Step 4: Run to verify they pass**, then the full suite.
- [ ] **Step 5: Commit** `feat: profile holds Gold, owned and equipped items` with the trailer.

---

### Task 3: Gold coins share the gem pickup and dropper

**Files:**
- Rename (`git mv`): `scripts/progression/xp_gem.gd` to `value_gem.gd`, `scripts/systems/xp_dropper.gd` to `value_dropper.gd`, `tests/test_xp_gem.gd` to `test_value_gem.gd`, `tests/test_xp_dropper.gd` to `test_value_dropper.gd`
- Create: `scenes/progression/gold_coin.tscn`
- Modify: `scenes/progression/xp_gem.tscn`, `scripts/components/pickup_collector.gd`, `resources/enemies/enemy_data.gd`, the five `resources/enemies/*_enemy.tres`, `scenes/main/main.tscn`, `scripts/main/main.gd`, `scenes/world/stress_test.tscn`, `scripts/dev/stress_test.gd`, `tests/test_pickup_collector.gd`, `tests/test_main_progression.gd`, `tests/test_level_track.gd`

**Interfaces:**
- Produces `ValueGem` (`class_name ValueGem extends Area2D`, the former `XpGem`): `enum Kind { XP, GOLD }`, `@export var kind: Kind = Kind.XP`; the same `value`, `setup(amount)`, `add_value(amount)` and `collect() -> int`. XP keeps its pale-gold triangle and group `xp_gems`. GOLD is a small yellow-orange diamond in group `gold_coins`. `xp_gem.tscn` has kind XP and the new `gold_coin.tscn` kind GOLD, both passive on layer 32.
- Produces `ValueDropper` (`class_name ValueDropper extends Node`, the former `XpDropper`): `@export var kind: ValueGem.Kind`, `gem_scene`, `max_gems = 150`, `drop_root`; `on_enemy_died(enemy: Enemy) -> ValueGem` reads `xp_reward` for XP and `gold_reward` for GOLD; `place(amount, world_position)` and `gem_count()` as before.
- `EnemyData.gold_reward: int = 1` (values in the Global Constraints).
- `PickupCollector` gains `signal gold_collected(amount: int)` and emits `xp_collected` or `gold_collected` by the pickup's kind.
- `main.tscn` has `XpDropper` (kind XP, `xp_gem.tscn`) and `GoldDropper` (kind GOLD, `gold_coin.tscn`), both connected to `enemy_died` in `Main`. The stress scene gets both when `--drops` is set.

- [ ] **Step 1: Write the failing tests.** Rename and extend the two gem tests for `ValueGem` and `ValueDropper` (every Sprint 8 case still passes under the new names, run once for each kind where it makes sense): `test_gold_coin_is_passive_on_the_pickup_layer_in_its_own_group`, `test_gold_dropper_uses_the_enemys_gold_reward` (Land gives 3, Sea 2, plain 1), `test_xp_dropper_ignores_gold_and_the_reverse`, `test_gold_cap_merges_and_loses_nothing`. `test_pickup_collector.gd`: `test_walking_over_a_coin_emits_gold_collected_with_its_value`, `test_a_coin_does_not_emit_xp_collected`, `test_a_dead_player_collects_no_coins`. `test_level_track.gd`: `test_every_enemy_has_a_gold_reward` (1, 1, 1, 2, 3 for plain, Fire, Thunder, Sea, Land). `test_main_progression.gd`: update the gem group check and add `test_killing_an_enemy_drops_both_a_gem_and_a_coin`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the rename, the kind handling, the scenes, the collector change, the enemy data and the wiring.
- [ ] **Step 4: Run to verify they pass**, then the full suite.
- [ ] **Step 5: Smoke run, then the stress test** (`--enemies=300 --seconds=8 --drops`). Expected: no errors, at or above 60 fps.
- [ ] **Step 6: Commit** `feat: Gold coins share the gem pickup and dropper` with the trailer.

---

### Task 4: Banking Gold and showing it

**Files:**
- Create: `scripts/ui/gold_counter.gd`, `scenes/ui/gold_counter.tscn`, `tests/test_gold_counter.gd`
- Modify: `scripts/components/run_progress.gd`, `scripts/ui/death_screen.gd`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_run_progress.gd`, `tests/test_death_screen.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: `PlayerProfile.gold`/`add_gold` (Task 2), `PickupCollector.gold_collected` (Task 3).
- `RunProgress`: `signal gold_changed(total_gold: int)`, `var run_gold: int = 0`, `add_gold(amount: int)` (ignores amounts at or below 0 and a dead player; adds to the profile and `run_gold`, emits `gold_changed`).
- Produces `GoldCounter` (`class_name GoldCounter extends Label`, TEMPORARY look, `mouse_filter` IGNORE): `bind(progress: RunProgress)`; `gold_text() -> String` ("Gold N"). It sits under the level text, at about (92, 15).
- `DeathScreen.set_run_summary(run_xp: int, level: int, run_gold: int = 0)` shows "+N XP, +N Gold this run, level L" (the Sprint 8 line with Gold added), and `summary_text()` returns it.
- `Main`: `collector.gold_collected` to `progress.add_gold`, `gold_changed` to `saver.mark_dirty`, and the death summary passes `run_gold`.

- [ ] **Step 1: Write the failing tests.** `test_run_progress.gd`: `test_add_gold_banks_it_in_the_profile_and_this_run`, `test_zero_negative_and_dead_player_bank_no_gold`, `test_gold_changed_reports_the_total`. `test_gold_counter.gd`: `test_fresh_profile_shows_gold_zero`, `test_follows_gold_changed`, `test_ignores_the_mouse`. `test_death_screen.gd`: update the summary tests to the new text and add `test_summary_includes_gold`. `test_main_progression.gd`: `test_collecting_a_coin_banks_gold_and_marks_the_profile_for_saving`, `test_gold_survives_death_and_a_new_run` (die, load the same save in a new `Main`: gold is still there), update `test_death_saves_the_profile_and_shows_the_summary` to the new text.
- [ ] **Step 2: Run to verify they fail.** Expected: failures or parse errors.
- [ ] **Step 3: Implement** the component, the label, the death summary, and the `Main` wiring and nodes.
- [ ] **Step 4: Run to verify they pass**, then the full suite and `tests/test_world_input.gd`.
- [ ] **Step 5: Smoke run, then an MCP run** (`run_project`, `get_debug_output`, `stop_project`) to catch warnings headless hides.
- [ ] **Step 6: Commit** `feat: Gold is banked, saved and shown` with the trailer.

---

### Task 5: Equipment data and the new modifier stats

**Files:**
- Create: `resources/equipment/equipment_modifier.gd`, `resources/equipment/equipment_data.gd`, `resources/equipment/equipment_catalog.gd`, `resources/equipment/equipment_catalog.tres`, the 15 `resources/equipment/items/*.tres`, `tests/test_equipment_data.gd`
- Modify: `scripts/progression/stat_bonuses.gd`, `tests/test_player_profile.gd` (only for `StatBonuses` cases)

**Interfaces:**
- Consumes: the Sprint 8 `StatBonuses`.
- `StatBonuses` per the Global Constraints: the extended `Stat` enum, `static damage_stat(element: int) -> int`, `add_all(other: StatBonuses)` (adds every fraction of `other` into this one), and `static combined(first: StatBonuses, second: StatBonuses) -> StatBonuses` (a new object, neither input changed).
- Produces `EquipmentModifier` (`class_name EquipmentModifier extends Resource`): `@export var stat: StatBonuses.Stat`, `@export var amount: float`.
- Produces `EquipmentData` (`class_name EquipmentData extends Resource`): `enum Category { ROBE, WAND, STAFF, HAT, HOOD }`, `enum Slot { ROBE, WEAPON, HEADWEAR }`; `@export var id: StringName`, `display_name: String`, `description: String`, `category: Category`, `price: int`, `modifiers: Array[EquipmentModifier]`, `color: Color`; `slot() -> Slot` (ROBE to ROBE, WAND and STAFF to WEAPON, HAT and HOOD to HEADWEAR).
- Produces `EquipmentCatalog` (`class_name EquipmentCatalog extends Resource`): `@export var items: Array[EquipmentData]`; `static default_catalog() -> EquipmentCatalog`; `find(id: StringName) -> EquipmentData` (null if unknown); `items_for_slot(slot: EquipmentData.Slot) -> Array[EquipmentData]` (catalog order).

- [ ] **Step 1: Write the failing tests** in `test_equipment_data.gd`: `test_catalog_matches_the_spec_table` (15 items; for each, id, name, category, price and every modifier stat and amount from the table), `test_ids_are_unique_and_every_item_has_a_description`, `test_slot_mapping` (ROBE, WAND and STAFF, HAT and HOOD), `test_find_returns_the_item_or_null`, `test_items_for_slot_in_catalog_order` (5 robes, 4 weapons, 6 headwear), `test_hats_and_hoods_differ_only_in_name_id_and_colour` (same price and modifiers pairwise), `test_wands_trade_damage_for_speed_and_staffs_the_reverse`. Add `StatBonuses` cases: `test_damage_stat_maps_the_four_elements`, `test_damage_stat_is_minus_one_for_none_and_unknown`, `test_combined_adds_every_stat_and_changes_neither_input`, `test_add_all_adds_into_this_object`, `test_new_stats_default_to_zero`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then `-gselect=test_equipment_data` and the profile file.
- [ ] **Step 3: Implement** the classes, then generate the 15 item files and the catalog with a scratchpad script.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: equipment data and the new modifier stats` with the trailer.

---

### Task 6: The shop rules

**Files:**
- Create: `scripts/shop/shop_system.gd`, `scripts/shop/shop_result.gd`, `tests/test_shop_system.gd`

**Interfaces:**
- Consumes: `PlayerProfile` (Task 2), `EquipmentCatalog` and `EquipmentData` (Task 5), `StatBonuses`.
- Produces `ShopResult` (`class_name ShopResult extends RefCounted`): `var ok: bool`, `var reason: String`, `var item: EquipmentData`.
- Produces `ShopSystem` (`class_name ShopSystem extends RefCounted`, all static): constants `REASON_UNKNOWN := "That item is not for sale."`, `REASON_OWNED := "You already own that."`, `REASON_BROKE := "Not enough Gold."`, `REASON_NOT_OWNED := "You don't own that."`; `buy(profile, catalog, id: StringName) -> ShopResult` (checks the item exists, is not owned and is affordable, then spends the Gold, grants the item and equips it into its slot, replacing whatever was there, which stays owned; nothing changes on any failure); `equip(profile, catalog, id) -> ShopResult` (owned items only, free); `unequip(profile, slot: int) -> bool` (false if nothing was equipped there); `bonuses(profile, catalog) -> StatBonuses` (the sum of every equipped item's modifiers, skipping unknown ids and ids the profile does not own); `can_afford(profile, item) -> bool`.

- [ ] **Step 1: Write the failing tests** in `test_shop_system.gd`: `test_buy_with_exactly_enough_gold_succeeds` (Gold ends at 0, owned, equipped), `test_buy_with_one_gold_too_few_fails_and_changes_nothing`, `test_buying_twice_fails_and_charges_nothing_more`, `test_buying_an_unknown_id_fails_and_changes_nothing`, `test_buy_equips_into_the_items_slot_and_keeps_the_replaced_item_owned`, `test_hat_and_hood_share_one_slot`, `test_wand_and_staff_share_one_slot`, `test_equip_requires_ownership_and_costs_nothing`, `test_equip_an_unknown_id_fails`, `test_unequip_empties_the_slot_and_keeps_the_item`, `test_unequip_an_empty_slot_returns_false`, `test_bonuses_sum_the_equipped_items` (a Robe, a Wand and a Hat: all stats add), `test_bonuses_are_empty_with_nothing_equipped`, `test_bonuses_skip_unowned_and_unknown_equipped_ids`, `test_failed_actions_never_touch_the_profile` (the whole profile dictionary is identical before and after every failure).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then `-gselect=test_shop_system`.
- [ ] **Step 3: Implement** the two classes.
- [ ] **Step 4: Run to verify they pass**, then the full suite.
- [ ] **Step 5: Commit** `feat: shop rules` with the trailer.

---

### Task 7: Casting speed, damage scale and the two chance effects

**Files:**
- Create: `scripts/spells/cast_math.gd`, `tests/test_cast_math.gd`
- Modify: `scripts/spells/spell_instance.gd`, `scripts/components/spell_loadout.gd`, `scripts/spells/area_effect.gd`, `scripts/entities/player.gd`, `tests/test_spell_instance.gd`, `tests/test_spell_loadout.gd`, `tests/test_missile_area.gd`, `tests/test_player.gd`

**Interfaces:**
- Consumes: `StatBonuses` with the new stats (Task 5).
- Produces `CastMath` (`class_name CastMath extends RefCounted`, all static, per the Global Constraints): `const MIN_INTERVAL := 0.05`, `const MIN_DAMAGE_SCALE := 0.1`; `damage_scale(elements: Array, bonuses: StatBonuses) -> float`; `interval(base: float, cast_speed: float) -> float`; `pool(base: float, spell_mana: float) -> float`; `chance(bonuses: StatBonuses, stat: StatBonuses.Stat) -> float`.
- `AreaEffect`: `var damage_scale: float = 1.0`, and `_configure_hitbox` sets `hitbox.damage = spell.damage * damage_scale`. `launch` is unchanged and no Area scene is edited.
- `SpellInstance`: `var cast_speed_bonus: float = 0.0`; `effective_interval() -> float` (`CastMath.interval(data.cast_interval, cast_speed_bonus)`); `set_cast_speed_bonus(bonus: float)`; `cast()` starts the cooldown at `effective_interval()`. The mana-bonus members are unchanged.
- `SpellLoadout`: `var bonuses: StatBonuses = StatBonuses.new()`, `var rng := RandomNumberGenerator.new()` (randomised in `_ready`); `set_bonuses(new_bonuses: StatBonuses)` (stores it, calls `set_mana_bonus` with its SPELL_MANA fraction, and `set_cast_speed_bonus` on every instance); every new instance gets both bonuses; `try_cast` rolls DOUBLE_DAMAGE_CHANCE once (scale times 2 on success), rolls CAST_TWICE_CHANCE once (a second pass over every shot on success), and sets `effect.damage_scale = CastMath.damage_scale(spell.data.elements, bonuses)` (times 2 when doubled) before `launch`. Mana is spent and the cooldown started once.
- `Player.apply_stat_bonuses` ends with `loadout.set_bonuses(bonuses)` in place of `set_mana_bonus`.

- [ ] **Step 1: Write the failing tests.** `test_cast_math.gd`: `test_no_bonuses_give_a_scale_of_one_and_an_unchanged_interval_and_pool`, `test_spell_damage_and_element_bonus_multiply`, `test_hybrid_element_bonus_is_the_mean` (Fire +0.2 and Sea +0.0 on a Fire+Sea spell gives 1.1), `test_a_bonus_for_another_element_does_not_apply`, `test_scale_is_floored_at_a_tenth`, `test_no_elements_use_only_spell_damage`, `test_interval_divides_by_one_plus_cast_speed`, `test_negative_cast_speed_slows_the_spell`, `test_interval_floor_and_extreme_negative_speed` (speed -2.0 does not divide by zero or go negative), `test_pool_scales_with_spell_mana`, `test_chance_is_clamped_to_zero_and_one`. `test_spell_instance.gd`: `test_cast_speed_shortens_the_cooldown_after_a_cast`, `test_slower_casting_lengthens_it`, `test_two_instances_never_share_a_cast_speed`. `test_missile_area.gd`: `test_damage_scale_multiplies_the_hit_damage`. `test_spell_loadout.gd` (use the existing stub Area pattern in `tests/stub_area_effect.gd` and `tests/area_test_base.gd` to read what each launched effect received): `test_default_cast_launches_once_with_a_scale_of_one`, `test_cast_twice_at_certain_chance_launches_every_shot_twice_for_one_mana_payment`, `test_cast_twice_at_zero_chance_launches_once`, `test_cast_twice_does_not_lengthen_the_cooldown`, `test_double_damage_at_certain_chance_doubles_the_scale_of_every_shot`, `test_double_damage_at_zero_chance_leaves_the_scale`, `test_chances_above_one_and_below_zero_are_clamped`, `test_both_effects_together` (two launches, each with the doubled scale), `test_a_spell_with_copies_launches_copies_times_two_when_casting_twice`, `test_element_bonus_reaches_the_launched_effect`, `test_loadout_bonuses_apply_to_spells_equipped_later`, `test_two_loadouts_never_share_bonuses`. `test_player.gd`: `test_apply_stat_bonuses_reaches_the_loadout_cast_stats`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the changes.
- [ ] **Step 4: Run to verify they pass**, then the full suite.
- [ ] **Step 5: Smoke run, then the stress test** (`--enemies=300 --seconds=8`, no `--drops`) to confirm the per-cast scale costs nothing measurable. Expected: no worse than the Sprint 8 baseline.
- [ ] **Step 6: Commit** `feat: casting speed, damage scale and the Wand and Staff effects` with the trailer.

---

### Task 8: Equipment at run start, mid-run, and in the crafting preview

**Files:**
- Modify: `scripts/progression/run_start.gd`, `scripts/components/run_progress.gd`, `scripts/main/main.gd`, `scripts/crafting/spell_builder.gd`, `scripts/crafting/crafting_session.gd`, `tests/test_run_start.gd`, `tests/test_run_progress.gd`, `tests/test_spell_builder.gd`, `tests/test_crafting_session.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: `ShopSystem.bonuses` (Task 6), `CastMath` and `SpellLoadout.bonuses` (Task 7), `StatBonuses.combined` (Task 5).
- `RunStart.prepare(player, profile, track, run_buffs: RunBuffs, catalog: EquipmentCatalog)`: the stat bonuses applied are `StatBonuses.combined(StatBonuses.for_level(track, level), ShopSystem.bonuses(profile, catalog))`, with `heal_difference` false, before the starting spells are equipped.
- `RunProgress.equipment_bonuses: StatBonuses = StatBonuses.new()` (set by `Main` from the profile at run start); `_apply` for a stat reward applies `StatBonuses.combined(StatBonuses.for_level(track, reached), equipment_bonuses)`.
- `SpellBuilder.describe(spell: SpellData, bonuses: StatBonuses = null) -> Dictionary`: with `bonuses`, `damage` is `spell.damage * CastMath.damage_scale(spell.elements, bonuses)`, `interval` is `CastMath.interval(spell.cast_interval, cast speed)`, `pool` is `CastMath.pool(spell.max_mana, spell mana)`, and `casts` and `whole_casts` use that pool. Without `bonuses` the result is exactly as before.
- `CraftingSession.new_stats()` and `current_stats()` pass `_loadout.bonuses`.
- `Main` loads `EquipmentCatalog.default_catalog()` into a `catalog` variable, sets `progress.equipment_bonuses`, and passes everything to `RunStart.prepare`.

- [ ] **Step 1: Write the failing tests.** `test_run_start.gd`: `test_equipped_robe_adds_its_bonus_at_run_start` (Ember Robe: the loadout's bonuses carry DAMAGE_FIRE 0.15), `test_level_and_equipment_bonuses_add_together` (level 20 plus Hardy Hat: health 100 x (1 + 0.8 + 0.2) = 200), `test_equipment_applies_before_the_starting_spells_are_equipped` (a Mana Hat: the first spell's pool includes the +10%), `test_prepare_twice_with_equipment_equals_once`, `test_nothing_equipped_changes_nothing`. `test_run_progress.gd`: `test_level_up_keeps_the_equipment_bonuses` (a Swift Hat's +10% speed survives the level-2 speed reward: 90 x (1 + 0.08 + 0.10)), `test_equipment_never_applies_twice_across_several_level_ups`, `test_health_level_up_with_equipment_heals_by_the_gain`. `test_spell_builder.gd`: `test_describe_without_bonuses_is_unchanged`, `test_describe_with_bonuses_scales_damage_interval_pool_and_casts`, `test_describe_whole_casts_use_the_bonus_pool`. `test_crafting_session.gd`: `test_new_and_current_stats_include_the_loadouts_bonuses`. `test_main_progression.gd`: `test_equipped_items_are_applied_when_a_run_starts` (a saved profile owning and equipping an Ember Robe and a Quickwand: the player's loadout bonuses carry both), `test_restart_does_not_apply_equipment_twice` (two runs from one save give identical stats).
- [ ] **Step 2: Run to verify they fail.** Expected: failures or parse errors.
- [ ] **Step 3: Implement** the changes and update every `RunStart.prepare` caller.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: equipment applies at run start, mid-run and in the crafting preview` with the trailer.

---

### Task 9: The shop screen and the death screen's Shop button

**Files:**
- Create: `scripts/ui/shop_screen.gd`, `scenes/ui/shop_screen.tscn`, `tests/test_shop_screen.gd`
- Modify: `scripts/ui/death_screen.gd`, `scenes/ui/death_screen.tscn`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_death_screen.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: `ShopSystem`, `EquipmentCatalog`, `PlayerProfile`.
- Produces `ShopScreen` (`class_name ShopScreen extends CanvasLayer`, TEMPORARY look, `process_mode` Always, layer 12, hidden at start): `signal changed` (after every successful buy, equip or unequip), `signal closed`; `open(profile: PlayerProfile, catalog: EquipmentCatalog)`; `close()`; `is_open() -> bool`; `buy(id: StringName)`, `equip(id: StringName)`, `unequip(slot: int)` (each calls `ShopSystem`, shows the reason on failure and emits `changed` on success); `gold_text() -> String` ("Gold N"); `message_text() -> String`; `item_button_count() -> int`. It lists items by slot with price and an owned or equipped marker, a Buy, Equip or Unequip button per row, and Close. `ui_cancel` closes it. Touch is bridged through `TouchBridge` exactly as `CraftingScreen.handle_input` does. Every non-button `Control` ignores the mouse.
- `DeathScreen`: gains a Shop `Button` (hidden until death, gets focus when death shows so `ui_accept`, Enter or controller A opens it), `signal shop_requested`, `set_shop_open(open: bool)`. While the shop is open, `handle_event` never restarts. A touch inside the Shop button's global rectangle never restarts (it is left to the button). A touch elsewhere, and the `restart` action, still restart after the existing input delay.
- `Main`: a `ShopScreen` node; `death_screen.shop_requested` opens it (`set_shop_open(true)`), `shop_screen.changed` calls `saver.save_now()`, and `shop_screen.closed` calls `death_screen.set_shop_open(false)`.

- [ ] **Step 1: Write the failing tests.** `test_shop_screen.gd` (with `pause_tree`-free screens and a profile on a throwaway save): `test_starts_closed_and_hidden`, `test_open_lists_every_catalog_item`, `test_buy_through_the_screen_spends_gold_and_emits_changed`, `test_failed_buy_shows_the_reason_and_emits_nothing`, `test_equip_and_unequip_through_the_screen`, `test_gold_text_follows_purchases`, `test_close_emits_closed_and_cancel_closes`, `test_touch_event_is_bridged_while_open`, `test_buttons_exist_for_owned_and_unowned_items_with_the_right_labels`, `test_every_non_button_control_ignores_the_mouse`. `test_death_screen.gd`: `test_shop_button_is_hidden_until_death_and_then_focused`, `test_pressing_the_shop_button_emits_shop_requested`, `test_restart_action_is_ignored_while_the_shop_is_open`, `test_touch_outside_the_shop_button_still_restarts`, `test_touch_inside_the_shop_button_does_not_restart`, `test_touch_anywhere_is_ignored_for_restart_while_the_shop_is_open`, `test_restart_works_again_after_the_shop_closes`. `test_main_progression.gd`: `test_death_screen_shop_opens_the_shop_and_a_purchase_is_saved_immediately` (a saved profile with 500 Gold: die, request the shop, buy the Ember Robe, load the file: Gold 400, owned and equipped), `test_next_run_after_buying_applies_the_item`, `test_shop_cannot_be_opened_while_alive`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the screen, the death-screen changes and the `Main` wiring. Hand-written `.tscn` rules from CLAUDE.md apply.
- [ ] **Step 4: Run to verify they pass**, then the full suite and `tests/test_world_input.gd`.
- [ ] **Step 5: Real-window touch check.** With a throwaway script in the scratchpad run in a real window (not headless): send `InputEventScreenTouch` events (window coordinates = game position times `root.get_final_transform()`) on the Shop button and elsewhere on the death screen, confirm the shop opens on the button tap and a tap elsewhere restarts, and delete the script afterwards. Record the result in the ledger. If a real window cannot be driven, say so in the final message instead of claiming it.
- [ ] **Step 6: MCP run** and a smoke run. Expected: no errors or warnings.
- [ ] **Step 7: Commit** `feat: shop screen and the death screen's Shop button` with the trailer.

---

### Task 10: Stress gate, docs and the manual check

**Files:**
- Modify: `scripts/dev/stress_test.gd` (only if Task 3 left anything), `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `docs/sprints/sprint-9-design.md` (Status: Built), `docs/sprints/sprint-8-design.md` (a short note), the memory file `sprint-0-decisions.md`

- [ ] **Step 1: Measure.** Run `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --area=<missile|wave|zone>` three times each and take the median. Expected: at or above 60 fps. If a median is more than 10% below the Sprint 8 figure, profile before changing anything and record the finding as a ruling.
- [ ] **Step 2: Docs.** `sprint-development.md`: tick the Sprint 9 boxes (Gold persistence now means the Gold field in the Sprint 8 profile), add the Built note, and add a note under Sprint 8 that its saved buff picks were replaced (buffs are picked or re-rolled every run). `README.md`: the buff-each-run rule in 6.1 (random rewards re-roll every run, chosen rewards are picked every run, nothing saved), the Gold rewards, the equipment table with the modifier numbers, the two effects, and that the shop is on the death screen. `technical-design.md`: the new save fields. `CLAUDE.md`: a "Gold and equipment (Sprint 9)" section (one modifier path, `CastMath`, the per-cast `damage_scale`, the two chance effects, `ValueGem`/`ValueDropper`, the catalog and `ShopSystem`, the death-screen shop and its tap rule, the save format, buffs picked every run through `RunBuffs`) and the Project State line. `development-log.md`: "2026-11-20: Sprint 9 (Gold, equipment and the shop)" with decisions, rulings, migration notes (`PlayerProfile.buff_picks` gone, `StartingBuffs` takes `RunBuffs` and `settle_random` became `roll_random`, `XpGem` and `XpDropper` renamed to `ValueGem` and `ValueDropper`, `RunStart.prepare` signature), limitations (the shop is only on the death screen so equipment changes at the next run, chance effects are per cast, TEMPORARY looks, balance untested, the other Wand and Staff effects wait) and the stress table. Mark `docs/sprints/sprint-9-design.md` Status: Built, and add to `docs/sprints/sprint-8-design.md` that its "random buff is saved" rule was replaced in Sprint 9.
- [ ] **Step 3: Manual test notes** for the final message: play, collect Gold, die, open the shop, buy an item, restart and check its effect (a Quickwand's faster casting, an Ember Robe's damage), confirm tapping Shop does not restart, confirm chosen buffs are asked every run and random ones change between runs, and delete `save.json` to reset.
- [ ] **Step 4: Full suite and smoke run.** Expected: all pass, no errors, and the real save's checksum unchanged by the suite.
- [ ] **Step 5: Commit** `docs: Sprint 9 complete` with the trailer.
