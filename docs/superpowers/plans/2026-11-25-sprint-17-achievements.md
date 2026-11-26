# Sprint 17: Achievements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Twelve data-driven achievements (3 boss, 4 level, 1 lifetime Gold, 4 survival) that unlock from events the game already announces, show a toast, persist in the save, appear on a home-screen Achievements screen (earned in colour, unearned greyed), and give each boss a starting spell in a fixed slot (Tempest Dragon slot 3, Ember Titan slot 4, Dire Minotaur slot 5).

**Architecture:** `AchievementData` resources in an `AchievementCatalog`; a listening `AchievementTracker` node (per run, created by `Main`, never called by gameplay) that decides unlocks through pure `AchievementRules`, saves at once and emits `unlocked`; two optional `PlayerProfile` fields (`achievements`, `lifetime_gold`); a static `AchievementRewards` that `RunStart.prepare` calls; an `AchievementToast` in the HUD; an `AchievementsScreen` child scene of the home screen.

**Tech Stack:** Godot 4.7 GDScript, GUT, the art tool (`tools/art/art_builder.gd`), the audio pipeline.

**Spec:** `docs/sprints/sprint-17-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first; scratch files in the scratchpad directory, never `/tmp`; `rm` takes full literal paths. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (2460 before this sprint); one file: add `-gselect=<name>`; after a `class_name` change run `godot --headless --import`; after a `.sprite` or `.sfx` change run `godot --headless -s tools/art/art_builder.gd` then `--import`. **Never run two Godot processes at once**; run the full suite alone, in the background for `task-done`.
- Test rules (from `CLAUDE.md`): a test that instantiates a run scene sets `save_path = ""` and the pick screen's `pause_tree = false` before `add_child` (use `tests/helpers/main_helpers.gd`); a home-screen test that presses Play sets `HomeScreen.scene_changer`; shared helpers live in `tests/helpers/`; **no test touches the real save or settings**; hand-written `.tscn` need `node_paths=PackedStringArray("prop")` for Node-typed exports.
- No gameplay system (spawner, director, progress, player, bosses) names the tracker. Only `Main`, the sound board's `bind`, the screens and tests do; a guard test pins it.
- Established rules: mana never regenerates and every spell instance owns its pool; starting-spell rewards apply at the **next run start**, never mid-run; slot unlock levels (5, 10, 15, 20 for slots 2 to 5) are not changed; the save stays version 1 with optional fields; the interface uses green for go and red for stop; every sprite is drawn at one pixel size (never scaled or rotated); art is bright, simple, cartoon.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Double unlocks and lost unlocks:** an achievement that fires twice (two events in one frame, a restart, a save round trip) or is lost (a crash right after an unlock, an unlock while the profile is not yet bound).
- **Reward placement:** a reward spell equipped into a locked slot, into a slot holding a crafted spell, with starting buffs, or sharing mana between two instances.
- **Crafting with no free slot:** a fully rewarded player's crafts replace a starter or boss spell (accepted); nothing in `AchievementRewards` may ever write a spell mid-run or into a slot a craft has used.
- **Paused and dead states:** the survival check advancing while paused, or unlocking after the player died.
- **Save corruption paths:** a wrong-typed `achievements` entry, a negative or huge `lifetime_gold`, an unknown achievement id, an old save with neither field.
- **Home layout and input:** the new Achievements button overlapping the Full screen button or being swallowed by the touch bridge; Esc closing the wrong screen; a touch acting twice.

---

### Task 1: The three boss spells

**Files:**
- Create: `resources/spells/thunder_zone.tres`, `resources/spells/ember_wave.tres`, `resources/spells/land_line.tres`, `tests/test_boss_reward_spells.gd`
- Reference: `resources/spells/sea_cone.tres`, `resources/spells/sea_wave.tres` (authoring style), `resources/spells/areas/{zone_area,wave_area,line_area}.tres`, `scripts/crafting/spell_builder.gd` (`can_cast`), `scripts/systems/spell_audit.gd`

**Interfaces:**
- Produces: `SpellData` resources with ids `thunder_zone` (Thunder, Zone area), `ember_wave` (Fire, Wave area), `land_line` (Land, Line area), names "Thunder Zone", "Ember Wave", "Land Line", each with its own pool and cost, a pool of 1000 mana and a cost like the Sea Cone's (about 2 to 3), with damage and cast interval chosen so each spell's **modelled damage per second against a group of 8 and its damage per pool are within 1.5 times the Sea Cone's** (the design's balance target; a Zone ticks, so its per-hit damage will be far lower than the Sea Cone's).

- [ ] **Step 1: Write the failing test** `test_boss_reward_spells`: `test_the_three_spells_load_with_the_right_element_and_area` (element enums Thunder, Fire, Land; `area_data` is the zone, wave and line `AreaData`), `test_each_spell_can_cast_and_has_its_own_pool` (`SpellBuilder.can_cast(spell)`, `max_mana > 0`, `mana_cost > 0`, `mana_cost <= max_mana`; two `SpellInstance`s of one spell never share mana), `test_ids_and_names_are_unique_and_distinct_from_the_starting_spells`. Run. Expected: FAIL (files missing).
- [ ] **Step 2: Author the three `.tres`** like `sea_cone.tres` (script `spell_data.gd`, id, name, elements, area, pool, cost, damage, interval, projectile speed, knockback, `max_hits`, colour). Compute, with the Sprint 14b audit's model constants (`scripts/systems/spell_audit.gd`: group radius, targets per Area, a Zone hitting every tick), each new spell's damage per second against 8 enemies and its damage per pool, and the Sea Cone's, and ledger them in a table. Adjust damage and interval until every new figure is within 1.5 times the Sea Cone's (then record the final table in the development log). Add `test_the_spells_match_the_balance_target` that recomputes the same model and asserts the ratio between 0.67 and 1.5. These are starting values for the user to tune by play.
- [ ] **Step 3: Run** `test_boss_reward_spells` then the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: the three boss reward spells`.

---

### Task 2: Achievement data and the catalog

**Files:**
- Create: `resources/achievements/achievement_data.gd`, `resources/achievements/achievement_catalog.gd`, `resources/achievements/achievement_catalog.tres`, twelve `resources/achievements/*.tres`, `tests/test_achievement_catalog.gd`
- Modify: `resources/progression/level_track.gd` (add `level_for_slot`), `tests/test_level_track.gd` (or the file that tests the track; find with `grep -ln slot_count tests`)

**Interfaces:**
- Produces:
  - `AchievementData` (Resource): `enum Kind { BOSS, LEVEL, GOLD_TOTAL, SURVIVE_SECONDS }`; exports `id: StringName`, `display_name: String`, `description: String` (a lower-case goal phrase such as `defeat the Tempest Dragon`, `reach level 10`, `survive 10 minutes`, `earn 1000 Gold`), `kind: Kind`, `threshold: int` (level, Gold or seconds; 0 for BOSS), `boss_id: StringName`, `icon: StringName` (a sprite name), `reward_spell: SpellData`, `reward_slot: int` (3 to 5, 0 for none); `func has_reward() -> bool`; `func toast_text() -> String` (`"Achievement unlocked: " + description`); `func goal_text() -> String` (description with the first letter capitalised); `func reward_text(track: LevelTrack) -> String` (`"Reward: Thunder Zone in slot 3 (level 10)"`, empty without a reward); `func problems() -> PackedStringArray` (empty id, a threshold at or below 0 for a non-BOSS, a BOSS with no `boss_id`, a reward spell without a slot or a slot outside 3 to 5, a non-castable reward spell, an empty `icon`).
  - `AchievementCatalog` (Resource): `@export var achievements: Array[AchievementData]`; `static func default_catalog() -> AchievementCatalog` (loads the `.tres`); `func find(id: StringName) -> AchievementData`; `func ids() -> Array[StringName]`; `func problems() -> PackedStringArray` (every entry's problems, duplicate ids, a reward slot used twice, a boss id used twice).
  - `LevelTrack.level_for_slot(slot: int) -> int`: the level at which spell slot `slot` (1 to 5) unlocks (1 for slot 1, 0 when the track never unlocks it).
- The twelve entries, in screen order, with ids and thresholds: `defeat_tempest_dragon` (boss `tempest_dragon`, reward `thunder_zone` slot 3), `defeat_ember_titan` (boss `ember_titan`, `ember_wave` slot 4), `defeat_dire_minotaur` (boss `dire_minotaur`, `land_line` slot 5), `reach_level_5`, `reach_level_10`, `reach_level_15`, `reach_level_20`, `earn_gold_1000` (GOLD_TOTAL 1000), `survive_5_minutes` (300), `survive_10_minutes` (600), `survive_15_minutes` (900), `survive_20_minutes` (1200). Icons: `icon_ach_boss_tempest_dragon`, `icon_ach_boss_ember_titan`, `icon_ach_boss_dire_minotaur`, `icon_ach_star` (level), `icon_coin` (Gold), `icon_ach_hourglass` (survival). Names are unique and pleasant (the builder chooses, for example "Dragonbane").

- [ ] **Step 1: Write the failing tests.** `test_level_track`: `test_level_for_slot_matches_the_slot_rewards` (slots 1 to 5 give 1, 5, 10, 15, 20 on the shipped track; slot 6 and 0 give 0). `test_achievement_catalog`: `test_the_shipped_catalog_has_twelve_valid_achievements` (`problems()` empty, 12 entries, unique ids, the ids and thresholds above, kinds per group), `test_every_boss_id_names_a_real_boss` (each BOSS `boss_id` equals the `id` of a `BossData` in `resources/bosses/`), `test_boss_rewards_use_slots_three_to_five_once_each` (slots 3, 4, 5 with the right spells), `test_text_helpers` (`toast_text`, `goal_text`, `reward_text` with the shipped track: `"Reward: Thunder Zone in slot 3 (level 10)"`), `test_problems_catch_each_kind_of_fault` (a throwaway `AchievementData` per fault reports a message; a duplicate id and a reused slot are reported by the catalog). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `LevelTrack.level_for_slot`, `AchievementData`, `AchievementCatalog` and author the twelve `.tres` and the catalog `.tres`. Run `godot --headless --import`.
- [ ] **Step 3: Run** both test files, then the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: achievement data, the catalog and the twelve achievements`.

---

### Task 3: Save fields and lifetime Gold

**Files:**
- Modify: `scripts/progression/player_profile.gd`, `scripts/components/run_progress.gd`, `tests/test_player_profile.gd`, `tests/test_run_progress.gd`

**Interfaces:**
- Produces on `PlayerProfile`: `var achievements: Array[StringName]`; `var lifetime_gold: int`; `func has_achievement(id: StringName) -> bool`; `func grant_achievement(id: StringName) -> bool` (false when already held); `func earn_gold(amount: int) -> void` (adds to `gold` exactly like `add_gold` and to `lifetime_gold`, both clamped like `_added`); `func best_seconds_overall() -> int` (the largest `bests[...]["seconds"]`, 0 with none). `to_dict` writes `achievements` (an array of strings) only when non-empty and `lifetime_gold` only when above 0; `from_dict` reads both as optional fields (a non-array or a non-string entry in `achievements`, or a `lifetime_gold` that is not a whole number in range, is a bad save: returns null); a save **without** `lifetime_gold` loads with `lifetime_gold = gold` (the best known figure); unknown ids are kept. `RunProgress.add_gold` calls `profile.earn_gold(amount)` instead of `add_gold`. `PlayerProfile.add_gold` is unchanged (refunds and cash-ins do not count as earned).

- [ ] **Step 1: Write the failing tests** in `test_player_profile`: `test_achievements_and_lifetime_gold_round_trip`, `test_an_old_save_loads_with_lifetime_gold_equal_to_its_gold_and_no_achievements`, `test_grant_achievement_is_idempotent`, `test_a_bad_achievements_field_is_a_bad_save` (not an array, a number entry), `test_a_bad_lifetime_gold_is_a_bad_save` (negative, fractional, above `MAX_VALUE`, a string), `test_unknown_ids_are_kept_in_a_round_trip`, `test_earn_gold_raises_both_and_add_gold_only_gold`, `test_best_seconds_overall_is_the_largest_over_maps`, `test_new_game_erases_achievements_with_the_save` (through `SaveGame.erase` on a scratch path: a fresh profile after reload). In `test_run_progress`: `test_collected_gold_counts_as_earned` and `test_a_purchase_notification_does_not` (the Gold path used by `ShopSystem` leaves `lifetime_gold` alone). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the fields, methods, `to_dict`/`from_dict` changes and the `RunProgress.add_gold` change.
- [ ] **Step 3: Run** the two files and the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: save achievements and lifetime Gold`.

---

### Task 4: Rules and the tracker

**Files:**
- Create: `scripts/progression/achievement_rules.gd`, `scripts/progression/achievement_facts.gd`, `scripts/progression/achievement_tracker.gd`, `tests/test_achievement_rules.gd`, `tests/test_achievement_tracker.gd`, `tests/test_achievement_guards.gd`

**Interfaces:**
- Consumes: Task 2 (`AchievementData`, `AchievementCatalog`), Task 3 (`PlayerProfile` fields).
- Produces:
  - `AchievementFacts` (RefCounted): `level: int`, `lifetime_gold: int`, `seconds: float`, `boss_id: StringName`.
  - `AchievementRules` (static): `is_met(data: AchievementData, facts: AchievementFacts) -> bool` (BOSS: `facts.boss_id == data.boss_id` and not empty; LEVEL: `level >= threshold`; GOLD_TOTAL: `lifetime_gold >= threshold`; SURVIVE_SECONDS: `seconds >= threshold`).
  - `AchievementTracker` (Node): `signal unlocked(data: AchievementData)`; `func bind(catalog: AchievementCatalog, profile: PlayerProfile, track: LevelTrack, spawner: EnemySpawner, progress: RunProgress, saver: ProfileSaver) -> void` (connects `spawner.boss_died`, `progress.leveled_up`, `progress.gold_changed`); `func sync() -> void` (silently grants, with **no** `unlocked` signal and no toast, every LEVEL, GOLD_TOTAL and SURVIVE_SECONDS achievement the profile already proves: `profile.level(track)`, `lifetime_gold`, `best_seconds_overall()`; then saves once if anything was granted); `func earned_count() -> int`; `func stop() -> void` (no further unlocks; `Main` calls it when the player dies); the run clock is checked once a second in `_process` (accumulated delta, `RunClock.seconds()` as the facts' `seconds`), so it freezes while the tree is paused. Every unlock goes through one private `_try_unlock(data, facts)`: skip when already earned, otherwise `profile.grant_achievement`, `saver.save_now()`, `unlocked.emit(data)`.

- [ ] **Step 1: Write the failing tests.** `test_achievement_rules`: each kind meets at its threshold and not one below; a BOSS meets only for its own id and never for an empty id. `test_achievement_tracker` (a real `AchievementTracker` with a stub spawner/progress built the way `test_run_stats` builds its sources, a scratch profile and a saver with an empty path): `test_a_boss_death_unlocks_only_that_boss`, `test_a_level_up_unlocks_each_threshold_it_crosses_in_order` (a jump to level 20 unlocks 5, 10, 15, 20 in that order), `test_lifetime_gold_unlocks_at_1000_on_the_next_gold_event`, `test_survival_unlocks_as_the_clock_passes_each_threshold` (drive `RunClock` and `_process`), `test_an_unlocked_achievement_never_unlocks_again` (repeat events, two trackers over one profile, a save round trip), `test_every_unlock_is_saved_at_once` (the saver's file holds the id before the next frame), `test_the_survival_clock_freezes_while_paused` (`get_tree().paused`), `test_stop_prevents_further_unlocks` (after `stop()` a boss death or level-up unlocks nothing), `test_sync_grants_level_survival_and_gold_silently` (no `unlocked` signal, one save), `test_sync_grants_no_boss_achievement`. `test_achievement_guards`: no script under `scripts/` other than `scripts/progression/achievement_*.gd`, `scripts/main/main.gd`, `scripts/audio/sound_board.gd` and `scripts/ui/achievement*.gd` and `scripts/home/home_screen.gd` names `AchievementTracker` (a scan like `test_run_stats`'s guard). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the three scripts. Run `godot --headless --import`.
- [ ] **Step 3: Mutation check** (ledger the results): remove the already-earned check, remove `stop()`, and make the clock ignore the pause; each must fail a named test; restore each file with `git checkout -- <exact path>`.
- [ ] **Step 4: Run** the three files and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the achievement rules and tracker`.

---

### Task 5: Rewards at run start

**Files:**
- Create: `scripts/progression/achievement_rewards.gd`, `tests/test_achievement_rewards.gd`
- Modify: `scripts/progression/run_start.gd`, `tests/test_run_start.gd` (find with `grep -ln RunStart.prepare tests`)

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: `AchievementRewards.apply(loadout: SpellLoadout, profile: PlayerProfile, catalog: AchievementCatalog) -> void`: for each catalog entry the profile holds that has a reward, with `index = reward_slot - 1`, if `loadout.is_unlocked(index)` and `loadout.slots[index] == null`, then `loadout.equip(index, reward_spell)` (a fresh full-mana instance, no starting buffs). `RunStart.prepare(player, profile, track, run_buffs, catalog, achievements: AchievementCatalog = null)`: when `achievements` is not null it calls `AchievementRewards.apply(loadout, profile, achievements)` after the level spells; every existing caller keeps working unchanged.

- [ ] **Step 1: Write the failing tests.** `test_achievement_rewards`: `test_a_reward_fills_its_slot_when_unlocked_and_empty`, `test_a_locked_slot_gets_nothing_and_the_spell_waits` (level 9 with the Dragon achievement: slot 3 stays empty; the same profile at level 10 equips it), `test_a_slot_already_holding_a_spell_is_never_replaced`, `test_no_starting_buffs_are_applied`, `test_two_runs_get_separate_mana_pools` (equip, spend mana on one loadout, a second loadout starts full), `test_an_unearned_achievement_gives_nothing`, `test_all_three_bosses_fill_slots_three_four_five_at_level_twenty`. `test_run_start`: `test_prepare_applies_boss_rewards_after_the_level_spells_and_without_them_by_default` (the default `null` leaves slots 3 to 5 empty). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `AchievementRewards` and the optional `RunStart.prepare` parameter.
- [ ] **Step 3: Run** both files and the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: boss achievement spells fill their slots at run start`.

---

### Task 6: The toast and the sound

**Files:**
- Create: `scripts/ui/achievement_toast.gd`, `scenes/ui/achievement_toast.tscn` if the existing toasts are scenes (copy how `LevelToast` is placed in `scenes/main/main.tscn`), `audio/sounds/achievement.sfx`, `tests/test_achievement_toast.gd`
- Modify: `scripts/audio/sound_id.gd`, `resources/audio/sound_catalog.tres`, `scripts/audio/sound_board.gd` (bind), `tests/test_sound_catalog.gd` (it must stay green), `tests/test_sound_routes.gd` (add a route test)
- Reference: `scripts/ui/level_toast.gd`, `audio/sounds/level_up.sfx`, `docs/architecture/interface-and-audio.md`

**Interfaces:**
- Produces: `AchievementToast` (a Label like `LevelToast`, theme variation `HudToast`, ignores touches, hidden until used): `func show_unlocked(data: AchievementData) -> void` (queues; each shows `data.toast_text()` for `DURATION` 3.0 s plus a 0.5 s fade; the next starts when the previous ends; time counts `_process` deltas so it freezes while paused); `func is_showing() -> bool`; `func queued_count() -> int`. Sound id `achievement` (`SoundId.ACHIEVEMENT`), a short two-note chime (the audio pipeline; **not judged by ear**), played by `SoundBoard` when it is told about an unlock: `SoundBoard.bind(main)` connects `main.achievement_tracker.unlocked` (the property `Main` gains in Task 7; until then bind skips a null tracker).

- [ ] **Step 1: Write the failing tests.** `test_achievement_toast`: `test_it_shows_the_text_of_an_unlock`, `test_several_unlocks_queue_and_show_one_after_another`, `test_it_freezes_while_the_tree_is_paused`, `test_it_never_takes_a_touch` (mouse filter ignore), `test_it_hides_after_its_duration_and_fade`. `test_sound_routes`: `test_an_unlock_plays_the_achievement_sound` (a fake tracker emitting `unlocked`, `SoundBoard.requested` records `achievement`). `test_sound_catalog` must fail until the catalog entry exists. Run. Expected: FAIL.
- [ ] **Step 2: Implement** the toast, the `.sfx` recipe (two voices, a rising third, length about 0.5 s, like `level_up.sfx`), the `SoundId` constant, the catalog entry (`pausable` false is wrong here: it is a world event, so pausable true; priority NORMAL, `max_voices` 2) and the board's bind. Run the art tool then `--import`; `test_audio_assets` and `test_sound_catalog` must pass.
- [ ] **Step 3: Run** the touched tests and the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: the achievement toast and chime`.

---

### Task 7: Wire it into the run

**Files:**
- Modify: `scripts/main/main.gd`, `scenes/main/main.tscn` (the `AchievementTracker` and `AchievementToast` nodes), `scripts/progression/run_start.gd` call in `Main`, `tests/test_main.gd` or a new `tests/test_main_achievements.gd`
- Reference: `scripts/main/main.gd` lines near `run_stats` (creation and `bind`), `_on_player_died`, `_begin_progression`

**Interfaces:**
- Consumes: Tasks 2 to 6.
- Produces: `Main.achievement_tracker: AchievementTracker` (public, for the sound board and tests); `Main` loads `AchievementCatalog.default_catalog()`, binds the tracker with the profile, track, spawner, progress and saver, calls `tracker.sync()` right after the profile loads (before `RunStart.prepare`), passes the catalog to `RunStart.prepare`, connects `tracker.unlocked` to `AchievementToast.show_unlocked`, and calls `tracker.stop()` when the player dies. A run started with `save_path = ""` still works (the tracker saves nothing; unlocks live in memory).

- [ ] **Step 1: Write the failing tests** (`test_main_achievements`, every `Main` made through `MainHelpers.new_main`): `test_a_boss_defeat_in_main_unlocks_toasts_and_saves` (a scratch `save_path`: kill a spawned boss through the spawner's `boss_died` path used by `test_boss_defeat` tests, assert the achievement is in the profile, the toast shows its text and the scratch file holds the id), `test_a_run_applies_earned_boss_spells_at_the_start` (a scratch save with the Dragon achievement and enough XP for level 10: slot 3 holds Thunder Zone), `test_a_level_nine_run_does_not_get_it`, `test_an_old_save_is_synced_silently_at_load` (a scratch save with XP for level 10 and a best of 700 s: level 5 and 10 and survive 5 and 10 are earned, no toast), `test_dying_stops_further_unlocks`, `test_two_runs_in_a_row_do_not_unlock_twice` (restart the scene logic by creating a second `Main` on the same scratch save). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the wiring and the scene nodes (place the toast under the level toast so they never overlap; check by screenshot).
- [ ] **Step 3: Real-window check** (scratch script, windowed, scratch `HOME`): a forced boss death shows the toast and a second saved launch holds the achievement; take screenshots of the toast and read them. Record in the ledger.
- [ ] **Step 4: Run** the new tests, `test_run_stats`, `test_main_progression` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: achievements in the run`.

---

### Task 8: The six icons

**Files:**
- Create: `art/sprites/icon_ach_star.sprite`, `icon_ach_hourglass.sprite`, `icon_ach_boss_tempest_dragon.sprite`, `icon_ach_boss_ember_titan.sprite`, `icon_ach_boss_dire_minotaur.sprite` and their built outputs in `assets/sprites/` (committed), `tests/test_achievement_icons.gd`
- Reference: `art/sprites/icon_coin.sprite`, `icon_heart.sprite`, `docs/architecture/art.md` (pipeline, margin and palette rules), the boss sprites `boss_*.sprite` for each boss's look, `art/palette.txt`

**Interfaces:**
- Produces: sprites `icon_ach_star` (a star), `icon_ach_hourglass` (an hourglass), `icon_ach_boss_tempest_dragon` (a blue dragon head with a lightning horn), `icon_ach_boss_ember_titan` (a fiery titan head), `icon_ach_boss_dire_minotaur` (a horned minotaur head), each **16 by 16**, one frame `idle` (`anim idle 0 0 1 loop`), fixed palette colours only (no new letters unless truly needed; the palette sits near its 64 limit), a 1 px transparent margin, facing the player (symmetric front view, so the facing convention does not apply). `icon_coin` is reused for Gold.

- [ ] **Step 1: Write the failing test** `test_achievement_icons`: every `icon` name used by the catalog resolves through `SpriteLibrary.find(name, &"base")` with a frame size of at most 16 by 16 and at least one frame, and each boss icon differs from the other two by at least 20 pixels. Run. Expected: FAIL (sprites missing).
- [ ] **Step 2: Compose the five sprites** with a scratchpad Python generator (shapes plus an automatic 1 px outline), write the `.sprite` grids, run the art tool and `--import`.
- [ ] **Step 3: Look at them.** A scratchpad GDScript contact sheet at 5x on a cream card colour and on grey: read the image; redraw anything that reads badly (the three heads must be told apart at 16 px and read as their boss; the hourglass and star must read at once). Record what the images showed.
- [ ] **Step 4: Run** `test_achievement_icons`, `test_art_assets`, `test_animation_frames` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the achievement icons`.

---

### Task 9: The Achievements screen and the home button

**Files:**
- Create: `scripts/ui/achievements_screen.gd`, `scenes/ui/achievements_screen.tscn` (follow how `TutorialScreen` is built and instanced in `scenes/home/home.tscn`), `tests/test_achievements_screen.gd`
- Modify: `scripts/home/home_screen.gd`, `scenes/home/home.tscn`, `tests/test_home_screen.gd`
- Reference: `scripts/ui/tutorial_screen.gd` (process Always, `TouchBridge`, input guard, explicit focus neighbours, Esc handling in `_input`), `scripts/ui/ui_kit.gd`, `docs/architecture/front-door.md`

**Interfaces:**
- Consumes: Tasks 2, 3, 8.
- Produces: `AchievementsScreen`: `func bind(catalog: AchievementCatalog, profile: PlayerProfile, track: LevelTrack) -> void`; `func open() -> void` (rebuilds from the profile so it is current; pauses nothing since it lives on the home screen; ignores the press that opened it for `input_guard_msec` 300); `func close() -> void`; `func is_open() -> bool`; `func card_count() -> int` (12); `func card_earned(index: int) -> bool`; `func card_text(index: int) -> String` (name, goal, reward line); `func count_text() -> String` (`"3 of 12"`); `func handle_event(event: InputEvent) -> void` (a tap or click on Close or outside closes; Esc and the `ui_cancel`/back action close; mirrors `TutorialScreen`). A 2-column grid of cards (icon, name, goal text; the reward line only for entries with a reward), earned cards in colour, unearned cards with a **grey (no hue) icon** and muted text; a red Close button of at least `UiKit.ACTION_SIZE`; read-only. `HomeScreen`: a new button "Achievements" at the top left (position (8, 8), minimum size 100 by 28, mirroring Full screen), `func open_achievements()` and `func achievements_screen() -> AchievementsScreen`; it loads the profile it already holds and `AchievementCatalog.default_catalog()`; closing returns focus to Play; `HomeScreen` never names `main.tscn` (the existing guard).

- [ ] **Step 1: Write the failing tests.** `test_achievements_screen`: `test_it_shows_twelve_cards_in_catalog_order`, `test_earned_and_unearned_cards_differ` (`card_earned`, the icon of an unearned card has a grey self-modulate or material, an earned one none), `test_the_count_line_follows_the_profile` (0, 3 and 12 earned), `test_a_boss_card_shows_its_reward_line_and_others_do_not`, `test_a_new_data_entry_appears_with_no_code_change` (append a throwaway `AchievementData` to a copied catalog: 13 cards), `test_esc_back_a_tap_outside_and_close_close_it`, `test_the_opening_press_is_ignored_for_the_guard_time`, `test_a_touch_acts_exactly_once` (`handle_event` with one `InputEventScreenTouch`), `test_it_runs_while_the_tree_is_paused`. `test_home_screen`: `test_the_home_screen_has_an_achievements_button_that_opens_the_screen`, `test_the_button_does_not_overlap_full_screen_or_the_main_buttons` (rect checks), `test_closing_returns_focus_to_play`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** the screen and the home changes. Keep every control a child with `mouse_filter` handled like the other screens (touches reach `handle_event`; the `test_world_input` and `test_ui_look` guards stay green).
- [ ] **Step 3: Real-window check** (scratch script, windowed, scratch `HOME`, a scratch save with a few achievements): open the screen by a touch and by a left click, read screenshots (cards fit inside the 480 by 270 screen, text inside its card, icons grey or coloured), close by Esc, Close and a tap outside, and confirm the button never also pressed something beneath. Record in the ledger.
- [ ] **Step 4: Run** the new tests, `test_ui_look`, `test_front_door_guards`, `test_world_input` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the Achievements screen`.

---

### Task 10: Docs and the close

**Files:**
- Modify: `docs/architecture/progression-and-economy.md` (a new `## Achievements (Sprint 17)` section), `tests/fixtures/claude_md_sections.txt` (add that heading), `CLAUDE.md` (the index line for progression-and-economy lists Sprint 17; the Project State line), `development-log.md`, `sprint-development.md` (mark Sprint 17 done), `docs/sprints/sprint-17-design.md` (status `Implemented`, with deviations), `docs/release-planning/future-roadmap.md` (item 2 built)

- [ ] **Step 1: Write the section** in the architecture doc: the data, the tracker and its listening rule, the save fields and the old-save sync, rewards at run start (fixed slots, level-gated, empty slots only, no buffs), the toast and chime (not judged by ear), the screen and home button, the guard tests, the three spell numbers as starting values, how to add an achievement (a `.tres` plus a catalog entry), and the limit that boss achievements start from zero on an old save.
- [ ] **Step 2: Log** in `development-log.md` what was built, the audit numbers for the three spells, the real-window checks and the rulings.
- [ ] **Step 3: Whole suite and smoke run** (`task-done`), then the soak test (`godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=12 --frames=600`) and a stress run (`godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --obstacles --drops`): record both; neither should change.
- [ ] **Step 4: Commit** `docs: record Sprint 17`.
