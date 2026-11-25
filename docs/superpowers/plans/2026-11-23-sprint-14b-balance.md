# Sprint 14b: Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Missile bursts where it ends and casts more slowly; potions become run-only (at most 3 of each, sold only by the in-run merchant, lost when the run ends); a spell audit tool measures every Base, Area and buff combination.

**Architecture:** The burst is Area data (`AreaData.burst_radius`, `burst_damage_share`) read by `MissileArea`, which spawns one `MissileBurst` effect (an `AreaEffect` with a circular hitbox) through the shared `_configure_hitbox`. Run potions move out of `PlayerProfile` into an in-memory `RunPotions` with the same method names, so the belt, `PotionSystem`, merchant screen and `ShopSystem` change their type, not their logic. The audit is a pure `SpellAudit` plus a printing script.

**Tech Stack:** Godot 4.7 GDScript, GUT, `.tres` data.

**Spec:** `docs/sprints/sprint-14b-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file>` (one file only). After adding a `class_name`, run `godot --headless --import`.
- Never branch on an Area type in the loadout, player or damage code; the burst is data. Elemental maths stays in `DamageSystem`/`HurtboxComponent`; the burst only builds a hitbox through `AreaEffect._configure_hitbox`.
- Starting values: burst radius 36 px, damage share 0.5, Missile cast interval 0.35 s to 0.6 s, damage per hit stays 10, potion cap 3 per type, merchant stock 2 of each.
- A crafted Fire plus Missile at Normal range must still equal `fire_missile.tres` in every number except the pool (an existing test pins it), so both change together.
- Enemy, spawn, XP, Gold and boss numbers are untouched. The spell audit changes **no** balance number; outliers are reported to the user (the design says the table is shown first).
- Tests that instantiate `main.tscn` set `save_path = ""` and the pick screen's `pause_tree = false`; tests never touch the real save.
- Everything in the UI is ASCII and uses the theme (no fonts or styles by hand).

## Review Focus

- A burst that hits more than it should: the same enemy twice in one burst, enemies out of range, the player, or enemies behind obstacles; and a burst for a spell whose `burst_radius` is 0 (every other Area). Expected: one hit per enemy in the radius, none outside, no burst for other Areas.
- A Missile that never frees or bursts twice (it hits two enemies in one physics frame, hits and runs out of life in the same frame, or `max_hits` above 1). Expected: exactly one burst per Missile.
- Duplicate Area and wand "cast twice": each launched Missile bursts once and the damage scale applies to the burst.
- A potion that survives a run: a fresh `Main` (restart after death) must hold no potions, the old save's potions are cashed in once and never written again, and no code path still reads `PlayerProfile.potions`.
- A merchant sale or a drink that corrupts Gold or the cap: all-or-nothing, never above 3 of a type, Gold spent only on success, the HUD updated.

---

### Task 1: The Missile burst

**Files:**
- Modify: `resources/spells/area_data.gd`, `resources/spells/areas/missile_area.tres`, `scripts/spells/areas/missile_area.gd`
- Create: `scripts/spells/areas/missile_burst.gd`, `scenes/spells/areas/missile_burst.tscn`, `tests/test_missile_burst.gd`

**Interfaces:**
- Produces: `AreaData.burst_radius: float = 0.0`, `AreaData.burst_damage_share: float = 0.0`; `MissileBurst` (`class_name`, `extends AreaEffect`) with `launch(spell, origin, direction, target)` (direction and target unused) that builds a circular `Hitbox` of `spell.area_data.burst_radius`, hits every enemy hurtbox inside it once with `spell.damage * damage_scale * burst_damage_share`, announces each hit through the shared path, then frees itself after 0.12 s. `MissileArea` spawns exactly one when it ends (first hit that reaches `max_hits`, end of life, or an obstacle) if its spell's `burst_radius > 0`.
- Consumes: `AreaEffect._configure_hitbox(hitbox, spell, hit_cooldown)`; model the burst's scene on `zone_area.tscn` (a circular `Hitbox` with a `Shape`).

- [ ] **Step 1: Write `tests/test_missile_burst.gd` (RED).** Use the pattern of `tests/test_missile_area.gd` (spawn enemies at set positions; read it first). Tests: `test_a_missile_bursts_once_where_it_hits` (a burst appears at the hit enemy's position, exactly one), `test_the_burst_hits_every_enemy_in_the_radius_once` (three enemies inside 36 px each take burst damage once, an enemy at 60 px takes none), `test_the_burst_damage_is_the_share_of_the_spells_damage_times_the_damage_scale` (damage 10, share 0.5, scale 2 gives 10), `test_a_missile_bursts_at_the_end_of_its_range` (no enemy: one burst after its life ends), `test_a_missile_with_no_burst_radius_makes_no_burst` (`burst_radius` 0 on the spell's `AreaData` copy), `test_a_missile_that_hits_two_enemies_in_one_frame_bursts_once`, `test_the_burst_uses_the_spells_element` (a Fire burst on a Sea enemy takes the vulnerable multiplier), `test_duplicate_area_bursts_once_per_copy` (a spell with `copies = 3` through `SpellLoadout.try_cast` makes three bursts), `test_the_burst_announces_its_hits` (an `ImpactEvents.bus.hit` per enemy hit). Also in the same file `test_the_missile_area_data_has_the_burst_numbers` (36 and 0.5) and `test_no_other_area_has_a_burst` (the other four `AreaData` files have 0 and 0). Run. Expected: FAIL (fields and class missing).
- [ ] **Step 2: Add the two fields to `AreaData`** (with doc comments) and set `burst_radius = 36.0`, `burst_damage_share = 0.5` in `missile_area.tres`; run `godot --headless --import`.
- [ ] **Step 3: Implement `MissileBurst` and its scene**, and change `MissileArea`: store the launching `spell`; add one `_end()` that spawns the burst (deferred, because a hit lands inside a physics callback: `get_parent().add_child.call_deferred(burst)` then set `global_position` and call `launch` once it is in the tree) and frees the Missile, guarded by a `_ended` flag so it runs once. Call `_end()` from the hit handler when `hits >= _max_hits`, from `_physics_process` when life runs out, and when the step crosses an obstacle if the Missile already stops at obstacles (it does not today: do not add obstacle collision; spells pass over obstacles per CLAUDE.md, so the burst happens only on hit or range end, and the design's "obstacle" case is a ledgered ruling). The burst gets `damage_scale` from the Missile. Use `spell.area_data.burst_radius` and `burst_damage_share`; build the shape radius at launch.
- [ ] **Step 4: Run** `-gselect=test_missile_burst` and `-gselect=test_missile_area`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the Missile bursts where it ends`.

---

### Task 2: The Missile's slower cast

**Files:**
- Modify: `resources/crafting/area_stats/missile.tres`, `resources/spells/fire_missile.tres`, tests that pin 0.35

**Interfaces:**
- Consumes: Task 1. Produces: Missile baseline `cast_interval` 0.6 in both files.

- [ ] **Step 1: Find what pins 0.35:** `grep -rn "0.35" tests resources scripts` for the Missile (tests such as `test_spell_builder`, `test_fire_missile`, `test_crafting_system`, the stress scene's constants). Write the new expectation first (change those assertions to 0.6) and run them. Expected: FAIL.
- [ ] **Step 2: Set `cast_interval = 0.6`** in `area_stats/missile.tres` and `fire_missile.tres`. Run the `grep` again and fix any other reader (the crafting preview text reads data, so nothing else should change).
- [ ] **Step 3: Run** the files from Step 1, `-gselect=test_spell_builder` and the full suite. Expected: PASS, including the test that a crafted Fire plus Missile equals `fire_missile.tres` apart from the pool.
- [ ] **Step 4: Commit** `feat: the Missile casts every 0.6 s`.

---

### Task 3: `RunPotions`

**Files:**
- Create: `scripts/potions/run_potions.gd`, `tests/test_run_potions.gd`

**Interfaces:**
- Produces: `RunPotions` (`RefCounted`): `const MAX_POTIONS := 3`; `potion_count(id: StringName) -> int`; `add_potion(id: StringName, amount: int = 1) -> int` (never past the cap, returns how many were added, ignores amounts at or below 0); `use_potion(id: StringName) -> bool` (false with nothing changed when there is none); `is_empty() -> bool`; `clear() -> void`. The same names as the old `PlayerProfile` potion methods, so callers change type only.

- [ ] **Step 1: Write the tests (RED):** `test_a_new_stock_is_empty`, `test_add_and_use_one_potion`, `test_the_cap_is_three_per_type`, `test_add_returns_how_many_were_added` (adding 5 to an empty stack returns 3), `test_using_a_missing_potion_changes_nothing`, `test_amounts_at_or_below_zero_are_ignored`, `test_types_are_counted_separately`, `test_clear_empties_everything`. Run. Expected: FAIL.
- [ ] **Step 2: Implement `RunPotions`** (a plain `Dictionary` of id to count; erase a key at zero). Run `godot --headless --import` and the tests. Expected: PASS.
- [ ] **Step 3: Commit** `feat: RunPotions, a run-only potion stock capped at three`.

---

### Task 4: Run-only potions everywhere

**Files:**
- Modify: `scripts/potions/potion_system.gd` (`refusal` takes `RunPotions` instead of `PlayerProfile`), `scripts/components/potion_belt.gd` (`bind(player, potions: RunPotions, catalog)`; header comment), `scripts/shop/shop_system.gd` (`buy_potion(profile: PlayerProfile, potions: RunPotions, catalog, id, price_multiplier := 1.0)`: Gold from the profile, count and cap from the stock, `REASON_FULL` at 3; add `cash_in_legacy_potions(profile, catalog) -> int`), `scripts/ui/merchant_screen.gd` (`open(profile, potions: RunPotions, catalog, merchant)`, "own n/3" text and a detail line "Potions last one run."), `scripts/ui/shop_screen.gd` (remove the Potions row, its buttons, text, `buy_potion` and the `potion_catalog` argument of `open`), `scripts/progression/player_profile.gd` (remove `MAX_POTIONS`, `potions` and the three potion methods; `from_dict` still accepts a `potions` field but stores it in `legacy_potions: Dictionary` (id to count) and never errors on it; `to_dict` writes no potions), `scripts/main/main.gd` (a `run_potions := RunPotions.new()` created in `_begin_progression`; the belt, merchant screen and `F8` use it; `_on_potion_used` no longer saves; `_begin_progression` cashes in `profile.legacy_potions` once through `ShopSystem.cash_in_legacy_potions` and saves; the shop screen is opened without potions), and every test that used `profile.add_potion`/`potion_count`/`use_potion` (`test_potion_system`, `test_potion_belt`, `test_merchant_screen`, `test_shop_system`, `test_shop_screen`, `test_player_profile`, `test_save_game`, `test_main_points_of_interest`, `test_main_progression`, `test_player`, `test_active_effects`, `test_potion_bar`, `test_potion_slot_widget`, `test_sound_routes`, `test_merchant_stock`, `test_point_of_interest` as `grep` finds).
- Create: tests in the existing files plus `tests/test_legacy_potions.gd`.

**Interfaces:**
- Consumes: `RunPotions` (Task 3). Produces: `ShopSystem.cash_in_legacy_potions(profile: PlayerProfile, catalog: PotionCatalog) -> int` (adds each legacy potion's list price times its count to `profile.gold`, ignores unknown ids, clears `legacy_potions`, returns the Gold added).

- [ ] **Step 1: Write the failing tests first:** in `test_shop_system`: `test_buying_a_potion_spends_gold_and_adds_to_the_run_stock`, `test_buying_refuses_at_three_of_a_type_and_spends_nothing`, `test_buying_refuses_when_too_poor`; in `test_merchant_screen`: `test_the_screen_shows_own_over_three_and_the_one_run_line`; in `test_shop_screen`: `test_the_shop_has_no_potions_row` (`potion_button_count` gone, no button named for a potion); in `test_player_profile`/`test_save_game`: `test_the_profile_writes_no_potions`, `test_an_old_save_with_potions_still_loads_and_keeps_them_as_legacy`; `tests/test_legacy_potions.gd`: `test_legacy_potions_are_cashed_in_at_list_price_once` (Gold added equals the sum, a second call adds 0, unknown ids ignored, nothing saved again); in `test_main_progression`: `test_a_fresh_run_has_no_potions` (a second `Main` after the first drank and bought has empty `run_potions`), `test_a_drink_does_not_save` (the saver's save count does not change on `belt.used`), `test_f8_fills_three_of_each_without_saving`; in `test_potion_belt`/`test_potion_system`: use `RunPotions`. Update the other listed tests to build a `RunPotions`. Run them. Expected: FAIL (they reference the new API).
- [ ] **Step 2: Implement** the changes listed under Files. Keep the merchant screen's message lines and all-or-nothing behaviour; `ShopSystem.buy_potion` spends Gold on the profile and adds to the stock only on success.
- [ ] **Step 3: Run** `godot --headless --import`, each changed test file, then the whole suite. Expected: PASS. Also `grep -rn "\.potions\b\|potion_count\|add_potion\|use_potion" scripts` returns only `RunPotions`, the belt, `PotionSystem`, `ShopSystem` and the merchant screen (no `PlayerProfile` use).
- [ ] **Step 4: Commit** `feat: potions last one run, three per type, sold only by the merchant`.

---

### Task 5: The spell audit

**Files:**
- Create: `scripts/dev/spell_audit.gd` (the printing script, `extends SceneTree`... run as `godot --headless -s scripts/dev/spell_audit.gd`), `scripts/systems/spell_audit.gd` (`class_name SpellAudit`, pure), `tests/test_spell_audit.gd`

**Interfaces:**
- Consumes: `SpellBuilder.build(bases, area, option, buffs)`, `CastMath`, the scroll resources in `resources/scrolls/`, `RangeOption` Normal from `crafting_rules.tres`.
- Produces: `SpellAudit.damage_per_pool(spell: SpellData, targets: int) -> float` (casts in a full pool times damage times `copies` times the hits one cast makes on `targets` enemies standing together: Missile 1 plus the burst share on each target in the burst, Line and Cone and Wave once each, Zone ticks `duration / tick_interval` times each), `SpellAudit.rows() -> Array[Dictionary]` (id, name, per-pool damage at 1 and 8 targets, damage per second at 8, casts per pool, cost), `SpellAudit.flagged(rows, factor := 3.0) -> Array[Dictionary]` (rows whose 8-target value is above `factor` times the median or below the median divided by `factor`).

- [ ] **Step 1: Write the tests (RED):** `test_a_missile_without_a_burst_hits_one_target_per_cast`, `test_a_zone_hits_each_target_once_per_tick`, `test_a_burst_adds_its_share_on_every_target_in_range`, `test_damage_per_pool_scales_with_casts_in_the_pool`, `test_rows_cover_every_base_and_area_pair` (4 Bases times 5 Areas, plus one row per buff on its own with Fire Missile, plus the starting spells), `test_flagged_finds_a_known_outlier` (a synthetic row set), `test_the_median_row_is_not_flagged`. Run. Expected: FAIL.
- [ ] **Step 2: Implement `SpellAudit` and the script.** The script prints one line per row sorted by 8-target value and a final "FLAGGED:" block. Run `godot --headless --import`, the tests, then `godot --headless -s scripts/dev/spell_audit.gd > <scratchpad>/audit.txt` and read it.
- [ ] **Step 3: Record the table** (the flagged rows and the ten highest and lowest) in the ledger and in `development-log.md` (Task 6), and **change no balance number**: the user sees the table first. If the Missile with its burst is itself flagged as too strong or too weak, say so in the final message.
- [ ] **Step 4: Commit** `feat: the spell audit tool`.

---

### Task 6: Real-window checks, performance and docs

**Files:**
- Modify: `CLAUDE.md` (Sprint 8 "Run start" and Sprint 9/10 sections where potions are saved and shop-sold: update the Potions section, the Project State line, Spell architecture's Missile line), `README.md` (potions and Missile text), `sprint-development.md` (14b note), `development-log.md`, `docs/sprints/sprint-14b-design.md` (Status: Built, revisions), `technical-design.md` if it names the profile's potions.

- [ ] **Step 1: Real window** (scratchpad script, `save_path = ""`, `await process_frame` first): screenshot a Missile burst on a crowd and at max range, the merchant screen (own n/3, the one-run line) and the shop screen (no potions row). Stress: `--area=missile --enemies=300 --seconds=8` three times, compared with `git stash`-free main numbers noted in the log; expected within noise.
- [ ] **Step 2: Update the docs** and state clearly: the Missile numbers (36 px, 50%, 0.6 s) are starting values, whether it feels right and the audit's flagged rows are the user's call.
- [ ] **Step 3: Run the whole suite and `godot --headless --quit-after 60`.** Expected: PASS, no new warnings.
- [ ] **Step 4: Commit** `docs: Sprint 14b complete`.
