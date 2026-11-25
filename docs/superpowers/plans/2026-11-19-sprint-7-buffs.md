# Sprint 7 Buff System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** All six buff scrolls change a spell: they stack, every stack costs more mana, a spell can have several elements (a hit uses the best match), Duplicate Area launches a ring of copies, and the crafting screen shows the result and its drawbacks.

**Architecture:** A `BuffEffect` resource on each Buff scroll holds a buff's numbers. `SpellBuilder` folds the chosen Base scrolls and buff stacks into a `SpellData` that now also carries `copies`, `vulnerability_scale` and `ignores_resistance`. `DamageSystem.resolve` is the one place that picks the best element and applies the vulnerability and resistance rules, fed by an `AttackProfile` that rides on the hitbox. A static `CastPattern` turns one cast into a list of shots, and `SpellLoadout.try_cast` launches each through the unchanged `launch` call. `CraftingSystem`, `CraftingSession` and `CraftingScreen` move from one Base scroll to a list, and gain buff stacks.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-7-design.md` (approved). Also `docs/sprints/sprint-6-design.md`, `CLAUDE.md`, `technical-design.md` sections 5, 7 and 8.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python` (never bare `python3`, not even for a version check or an empty heredoc). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, and remember zsh does not word-split unquoted variables.
- Work on branch `sprint-7-buffs`, cut from `main`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`).
- Delete files only by literal full path (no variables or wildcards in `rm`). Keep scratch files in the session scratchpad, never installed into home folders.
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, no new autoloads, Input Map actions only (device -1 on every event). Don't name a parameter `position` in a `Node2D` subclass or a local `owner`. In headless GUT runs, pointer events never reach `_unhandled_input`, so touch behaviour is proven with a real-window script, not a headless test.
- **No code anywhere branches on a buff id.** Buff behaviour comes only from `BuffEffect` numbers. Elemental math lives only in `ElementTable` and `DamageSystem`. No Area scene is edited for Duplicate Area. World scenes keep every `Control` at `mouse_filter` IGNORE (see `tests/test_world_input.gd`).
- Existing single-Base, buff-free behaviour must not change: a recipe with one Base scroll and no buffs builds exactly the Sprint 6 spell, and single-element hits deal exactly the Sprint 4 damage.
- Mana still never regenerates, and a failed craft never changes the inventory or the loadout.
- **Buff numbers** (`BuffEffect`, per stack, tune by playing). `max_stacks` 0 means unlimited. Folding: multipliers multiply per stack, `vulnerability_bonus` and the extra counts add per stack, `ignores_resistance` is true if any stack sets it.

  | scroll file | damage_multiplier | max_mana_multiplier | cost_multiplier | vulnerability_bonus | ignores_resistance | extra_copies | extra_bases | max_stacks |
  |---|---|---|---|---|---|---|---|---|
  | `buff/damage.tres` | 1.5 | 1.0 | 1.5 | 0.0 | false | 0 | 0 | 0 |
  | `buff/max_mana.tres` | 1.0 | 1.5 | 1.25 | 0.0 | false | 0 | 0 | 0 |
  | `buff/double_vulnerability.tres` | 1.0 | 1.0 | 1.25 | 1.0 | false | 0 | 0 | 0 |
  | `buff/ignore_resistance.tres` | 1.0 | 1.0 | 1.25 | 0.0 | true | 0 | 0 | 1 |
  | `buff/duplicate_area.tres` | 1.0 | 1.0 | 2.0 | 0.0 | false | 1 | 0 | 4 |
  | `buff/additional_base.tres` | 1.0 | 1.0 | 1.8 | 0.0 | false | 0 | 1 | 3 |

  The effect files live in `resources/crafting/buff_effects/` (`damage.tres`, `max_mana.tres`, `double_vulnerability.tres`, `ignore_resistance.tres`, `duplicate_area.tres`, `additional_base.tres`), and each buff scroll references its own through the new `ScrollData.buff`.
- **Spell rule.** With one or more Base scrolls, an Area, a range option and buff stacks: damage, interval, speed and knockback are the Area baseline times the **mean** of the Base multipliers (times the damage multiplier of each buff stack for damage). `mana_cost` is baseline times the mean Base cost multiplier times the range option's cost multiplier times every buff stack's `cost_multiplier`. `max_mana` is baseline times the mean Base pool multiplier times every buff stack's `max_mana_multiplier`. `copies` is 1 plus the sum of `extra_copies`. `vulnerability_scale` is 1 plus the sum of `vulnerability_bonus`. `ignores_resistance` is true if any stack sets it. A spell with one Base and no buffs equals the Sprint 6 result exactly.
- **Best match.** For every element of the attacker, take the table's multiplier against the defender. A strong (vulnerable) multiplier becomes `neutral + max(multiplier - neutral, 0) * vulnerability_scale`. A weak (resisted) multiplier becomes `neutral`, and its effect becomes NEUTRAL, if `ignores_resistance`. The hit uses the largest resulting multiplier (the first element wins a tie) and reports that element's effect. An empty element list, `NO_ELEMENT` and unknown values are neutral. Damage is `max(base_damage * multiplier, 0)`.
- **Crafting rules.** A request holds `bases` (a list) and `buffs` (a list where repeats are stacks). It is valid only if: there is at least one Base and all are Base scrolls; the Base count is exactly 1 plus the sum of the buffs' `extra_bases`; no element repeats; every buff entry is a Buff scroll with a `buff` effect and no buff exceeds its `max_stacks`; the range option exists; the slot is unlocked; every scroll is owned in the quantity used; the spell can be built; and its `mana_cost` is no more than its `max_mana`.
- Ring shots. For `copies` c of 1 or fewer there is one shot. Aimed Areas (`needs_ground_target` false): shot i has the aim direction rotated by `TAU * i / c` (copy 0 is the aim). Ground-targeted Areas: shot 0 at the clamped target, the other `c - 1` shots at `clamped_target + Vector2.from_angle(aim_angle + TAU * (i - 1) / (c - 1)) * (effective_size * 1.5)`. Every shot starts at the player's origin. One cast spends mana once.
- Perf gate: with a five-copy spell of each Area (`--copies=5`) the stress test is reported at the stress test's 0.05 s interval, and if any is below 60 fps also at that Area's real interval. Sprint 6 baselines: Missile 677, Wave 188, Zone 416 fps (with `--drops`: 460, 131, 292).

## Review Focus

- A failed craft (too many or too few Bases, a repeated element, a buff scroll the player doesn't own or owns too few of, a stack over its cap, a spell that could never cast) leaves the inventory and loadout exactly as they were. Pinned in Task 5.
- Best match with an empty element list, `NO_ELEMENT`, an unknown element value, equal multipliers and a vulnerability scale below 1 gives a defined result with no error. Pinned in Task 2.
- Copies of 0, 1 and negative values spawn exactly one shot, copies of 2 to 5 give an exact ring, and mana is spent once per cast. Pinned in Task 3.
- Removing an Additional Base stack trims the extra Base choices, and Confirm is never enabled for an incomplete recipe. Pinned in Tasks 6 and 7.
- A very large stack count (for example 40 Increased Damage) produces no infinity or NaN, and the preview and damage numbers stay readable. Pinned in Tasks 4 and 7.

---

### Task 1: Buff data and the spell's new fields

**Files:**
- Create: `resources/crafting/buff_effect.gd`, `resources/crafting/buff_effects/{damage,max_mana,double_vulnerability,ignore_resistance,duplicate_area,additional_base}.tres`, `tests/test_buff_effects.gd`
- Modify: `resources/scrolls/scroll_data.gd`, the six `resources/scrolls/buff/*.tres`, `resources/spells/spell_data.gd`, `tests/test_data_resources.gd` (only if it checks `SpellData` defaults)

**Interfaces:**
- Produces `BuffEffect` (`class_name BuffEffect extends Resource`): `@export var damage_multiplier: float = 1.0`, `max_mana_multiplier: float = 1.0`, `cost_multiplier: float = 1.0`, `vulnerability_bonus: float = 0.0`, `ignores_resistance: bool = false`, `extra_copies: int = 0`, `extra_bases: int = 0`, `max_stacks: int = 0`.
- `ScrollData.buff: BuffEffect` (Buff scrolls only; Base and Area scrolls leave it null).
- Produces on `SpellData`: `@export var copies: int = 1`, `@export var vulnerability_scale: float = 1.0`, `@export var ignores_resistance: bool = false`, `var buff_stacks: Dictionary = {}` (buff scroll id to stack count, for display), and `attack_profile() -> AttackProfile` is added in Task 2, not here.

- [ ] **Step 1: Write the failing tests.** `test_buff_effects.gd`: `test_each_buff_scroll_references_its_effect_with_the_table_numbers` (for each of the six scrolls: `scroll.buff` is non-null and all eight numbers match the table), `test_other_scrolls_have_no_buff_effect` (Base and Area scrolls have `buff == null`), `test_damage_and_copies_never_cost_less_than_what_they_buy` (Increased Damage: `cost_multiplier >= damage_multiplier`; Duplicate Area: for stacks 1 to 4, `cost_multiplier ** stacks >= stacks + 1`, the number of shots), `test_stack_caps` (`duplicate_area` 4, `additional_base` 3, `ignore_resistance` 1, the other three unlimited), `test_spell_data_defaults` (`copies == 1`, `vulnerability_scale == 1.0`, `ignores_resistance == false`, `buff_stacks.is_empty()`).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures or parse errors for the missing class and fields.
- [ ] **Step 3: Implement** the class and fields, then write the six effect files and add `buff = ExtResource(...)` to each buff scroll (fix `load_steps`). Generate the `.tres` edits with a throwaway script run by `venv/bin/python` and kept in the scratchpad, not the repo.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: buff effect data and the spell's new fields"`, with the trailer.

---

### Task 2: Best-match damage and the attack profile

**Files:**
- Create: `scripts/systems/attack_profile.gd`, `scripts/systems/hit_result.gd`, `tests/test_best_match.gd`
- Modify: `scripts/systems/damage_system.gd`, `scripts/components/hitbox_component.gd`, `scripts/components/hurtbox_component.gd`, `scripts/spells/area_effect.gd`, `resources/spells/spell_data.gd`, `tests/test_area_data.gd` or `tests/test_missile_area.gd` (one wiring test each, see below)

**Interfaces:**
- Consumes: `SpellData.elements`, `vulnerability_scale`, `ignores_resistance` from Task 1; `ElementTable`.
- Produces `AttackProfile` (`class_name AttackProfile extends RefCounted`): `var elements: Array[int] = []`, `var vulnerability_scale: float = 1.0`, `var ignores_resistance: bool = false`.
- Produces `HitResult` (`class_name HitResult extends RefCounted`): `var amount: float`, `var effect: int` (an `ElementTable.Effect`).
- Produces `DamageSystem.resolve(base_damage: float, attacker_elements: Array, defender_element: int, vulnerability_scale: float = 1.0, ignores_resistance: bool = false, table: ElementTable = null) -> HitResult` per the Best match rule. `calculate` and `effect` keep their signatures and now delegate to `resolve` with a single element.
- Produces `SpellData.attack_profile() -> AttackProfile`: built once from `elements`, `vulnerability_scale` and `ignores_resistance` and cached, so a cast allocates nothing (not exported, and not copied by `duplicate()`).
- `HitboxComponent` gains `var profile: AttackProfile = null`, and `try_hit` passes it on. `HurtboxComponent.receive_hit(damage, source_position, knockback := 0.0, attacker_element := NO_ELEMENT, profile: AttackProfile = null)` uses `resolve` with the profile's elements and flags when a profile is given, and with `[attacker_element]` otherwise (so every existing caller behaves as before), then emits the same signal with the resulting amount and effect. `AreaEffect._configure_hitbox` also sets `hitbox.profile = spell.attack_profile()` (it keeps setting `element` too).

- [ ] **Step 1: Write the failing tests.** `test_best_match.gd` (fixed `ElementTable.new()`): `test_single_element_matches_the_old_calculation` (all 16 attacker and defender pairs plus `NO_ELEMENT`: `resolve(10, [a], d).amount == calculate(10, a, d)` and the effect equals `effect(a, d)`), `test_hybrid_uses_the_best_element` (attackers [FIRE, SEA]: against FIRE amount 15 and VULNERABLE, against LAND 15 and VULNERABLE, against THUNDER 10 and NEUTRAL, against SEA 10 and NEUTRAL; the same list in the other order gives the same amounts), `test_a_hybrid_is_never_resisted_when_another_element_is_neutral` (FIRE+SEA against SEA is 10, not 5), `test_tie_picks_the_first_element` (equal multipliers report the first element's effect), `test_double_vulnerability_scales_only_the_bonus` (FIRE vs LAND with scale 2.0 gives 20 and VULNERABLE, scale 3.0 gives 25, a neutral hit is unchanged by any scale, a resisted hit is unchanged by any scale), `test_scale_below_one_never_makes_the_bonus_negative_or_a_bonus_a_penalty` (scale 0.0 on a strong hit gives exactly the neutral amount, scale -1.0 too), `test_ignore_resistance_makes_a_resisted_hit_neutral` (FIRE vs SEA gives 10 and NEUTRAL, and a strong hit stays strong), `test_empty_and_unknown_elements_are_neutral` (empty list, `[NO_ELEMENT]`, `[99]`, and `defender 99` give the neutral amount and NEUTRAL, with no error), `test_a_table_with_a_strong_multiplier_at_or_below_neutral_gives_no_bonus` (a custom table with `strong_multiplier = 1.0` or `0.8` and scale 3.0 gives no more than neutral), `test_amount_never_goes_below_zero`. Wiring tests: in `test_hurtbox_hitbox.gd`, `test_receive_hit_with_a_profile_uses_the_best_match` (hurtbox element SEA, a profile `[FIRE, THUNDER]`... use `[FIRE, SEA]` against defender FIRE: 15 damage and VULNERABLE in the emitted signal) and `test_receive_hit_without_a_profile_is_unchanged`; in `test_missile_area.gd`, `test_the_hitbox_carries_the_spells_profile` (a spell with elements [FIRE, SEA], `vulnerability_scale` 2.0 and `ignores_resistance` true: the missile's `Hitbox.profile` has the same elements and flags, and `hitbox.element` is still the first element); in `test_buff_effects.gd` or `test_spell_data`, `test_attack_profile_is_built_once_per_spell` (`spell.attack_profile() == spell.attack_profile()`).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures for the missing classes and methods.
- [ ] **Step 3: Implement** `AttackProfile`, `HitResult`, `DamageSystem.resolve` (with `calculate` and `effect` delegating), the hitbox and hurtbox changes, `SpellData.attack_profile()` and the `_configure_hitbox` line.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass, including every earlier damage test.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: best-match damage with vulnerability and ignore-resistance"`, with the trailer.

---

### Task 3: Duplicate Area at the cast layer

**Files:**
- Create: `scripts/spells/cast_shot.gd`, `scripts/spells/cast_pattern.gd`, `tests/test_cast_pattern.gd`
- Modify: `scripts/components/spell_loadout.gd`, `tests/test_spell_loadout.gd`, `scripts/dev/stress_test.gd`

**Interfaces:**
- Consumes: `SpellData.copies`, `AreaData.needs_ground_target`, `SpellData.clamp_target`, `effective_size`.
- Produces `CastShot` (`class_name CastShot extends RefCounted`): `var direction: Vector2`, `var target: Vector2`.
- Produces `CastPattern.shots(spell: SpellData, origin: Vector2, direction: Vector2, target: Vector2) -> Array[CastShot]` per the Ring shots rule (`class_name CastPattern extends RefCounted`, static).
- `SpellLoadout.try_cast` asks `CastPattern.shots` for the list and launches one Area effect per shot through the existing `launch(spell, origin, shot.direction, shot.target)`. The mana gate, the cooldown, `cast()` (once) and `cast_fired` stay as they are.
- Stress test: a `--copies=N` option sets `copies = N` on the duplicated stress spell (with `--area=<name>` as before).

- [ ] **Step 1: Write the failing tests.** `test_cast_pattern.gd` (spells built with `SpellData.new()` and an `AreaData` set to aimed or `needs_ground_target`, range and size known): `test_one_copy_is_one_shot_with_the_given_direction_and_target`, `test_zero_and_negative_copies_are_one_shot`, `test_aimed_ring_directions` (aim RIGHT: 2 copies give directions RIGHT and LEFT, 3 give angles 0, 120 and 240 degrees, 4 give 0, 90, 180, 270, 5 give multiples of 72, each compared with `is_equal_approx` on the angle), `test_aimed_ring_rotates_with_the_aim` (aim DOWN, 2 copies: DOWN and UP), `test_every_aimed_shot_has_a_unit_direction`, `test_ground_ring_first_zone_is_at_the_clamped_target` (range 100, target 300 away: shot 0 at 100 along the aim), `test_ground_ring_places_the_others_around_it` (3 copies: shots 1 and 2 are exactly `effective_size * 1.5` from shot 0's target, 180 degrees apart, starting at the aim's angle), `test_ground_ring_with_the_target_on_the_player` (target equal to origin: no NaN, shot 0 on the player), `test_shots_start_count_matches_copies_for_one_to_five`. In `test_spell_loadout.gd`, using the existing `StubAreaEffect` scene helper: `test_a_three_copy_spell_launches_three_effects_with_ring_directions` (three stubs recorded, directions 120 degrees apart, the same spell and origin), `test_mana_is_spent_once_for_all_copies` (mana drops by exactly one `mana_cost`), `test_a_one_copy_spell_launches_exactly_one_effect` (the Sprint 6 behaviour).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures for the missing classes.
- [ ] **Step 3: Implement** `CastShot`, `CastPattern`, the `try_cast` loop, and the `--copies=N` option (parse it next to `--area=` and apply it in `_stress_spell`).
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60` and a godot MCP run (`run_project`, `get_debug_output`, `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: Duplicate Area through a cast pattern"`, with the trailer.

---

### Task 4: SpellBuilder with several Bases and buff stacks

**Files:**
- Modify: `scripts/crafting/spell_builder.gd`, `tests/test_spell_builder.gd`

**Interfaces:**
- Consumes: `BuffEffect`, `ScrollData.buff`, the new `SpellData` fields.
- Produces `SpellBuilder.build(bases: Array[ScrollData], area: ScrollData, option: RangeOption, buffs: Array[ScrollData] = []) -> SpellData` per the Spell rule (the single-scroll signature is replaced). It returns null if `bases` is empty, any Base is not a Base scroll or has no `modifiers`, the Area scroll is unusable, the option is null, or any buff entry is not a Buff scroll with a `buff` effect. `elements` lists each Base's element in order; `buff_stacks` maps each buff scroll's `id` to its count; `id` includes the Base ids, the Area id, the range label and the buff ids with counts, so two different crafts never share an id; `color` is the first Base's colour.
- `SpellBuilder.display_name(bases, area, option) -> String`: Base names joined with "+", then the Area name, then the " (Label)" suffix as before ("Fire+Sea Missile (Long)").
- `SpellBuilder.describe(spell)` gains `elements` (String, the element names joined with "+"), `copies` (int), `vulnerability` (float, the scale) and `ignores_resistance` (bool).
- `SpellBuilder.can_cast(spell) -> bool` is `spell.mana_cost <= spell.max_mana`.
- `SpellBuilder.element_name(element: int) -> String` ("Fire", "Thunder", "Land", "Sea", "None").

- [ ] **Step 1: Write the failing tests.** Update `test_spell_builder.gd` so every existing call passes a one-element Base list (`[base]`) and keeps its assertions (this is the Sprint 6 regression: `test_fire_missile_at_normal_equals_the_starting_spell_except_its_bigger_pool`, `test_every_base_and_area_pair_builds`, the range tests, the name and id tests and `test_bad_inputs_return_null` all still pass). Add: `test_no_buffs_equals_the_sprint_6_result` (for every Base and Area pair, `build([base], area, option)` and `build([base], area, option, [])` have identical numbers), `test_each_buff_folds_alone` (Increased Damage: damage x1.5 and cost x1.5; Max Mana: pool x1.5 and cost x1.25; Double Vulnerability: `vulnerability_scale` 2.0 and cost x1.25; Ignore Resistance: flag true and cost x1.25; Duplicate Area: `copies` 2 and cost x2.0; Additional Base alone with one Base: cost x1.8 and no element change), `test_stacks_multiply_and_add` (two Increased Damage: damage x2.25 and cost x2.25; two Double Vulnerability: scale 3.0; three Duplicate Area: `copies` 4 and cost x8.0), `test_buffs_combine` (Increased Damage + Duplicate Area + Ignore Resistance: damage x1.5, copies 2, flag true, cost x1.5 x2.0 x1.25), `test_damage_per_mana_never_improves_from_damage_or_copies` (for 1 to 6 Increased Damage stacks, `damage / mana_cost` is no better than with none, within a small tolerance; for 1 to 4 Duplicate stacks, `mana_cost` is at least `copies` times the unbuffed cost), `test_hybrid_uses_the_mean_of_the_bases` (FIRE+THUNDER Missile: damage is the baseline times the mean of 1.0 and 0.7, cost mean of 1.0 and 1.0, pool mean of 1.0 and 1.5), `test_hybrid_elements_name_color_and_id` (elements `[FIRE, SEA]` in order, name "Fire+Sea Missile", colour is Fire's, ids differ between FIRE+SEA and SEA+FIRE and between buffed and unbuffed), `test_buff_stacks_are_recorded` (`buff_stacks` maps `buff_damage` to 2), `test_describe_reports_the_new_numbers` (elements "Fire+Sea", copies, vulnerability, ignore flag), `test_can_cast` (cost at most pool is true, a 40-stack Increased Damage spell is false), `test_huge_stacks_stay_finite` (40 Increased Damage stacks: `damage` and `mana_cost` are finite, not NaN), `test_bad_buffs_return_null` (a Base scroll in the buff list, an Area scroll, a Buff scroll whose `buff` is null).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the file. Expected: failures for the changed signature and new behaviour.
- [ ] **Step 3: Implement** the new `build`, `display_name`, `describe`, `can_cast` and `element_name`. Update the one existing caller, `CraftingSystem.preview`, to pass `request.bases` and `request.buffs` (its behaviour for single Base scrolls is unchanged until Task 5 changes the request).
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass (the Task 5 request change is not made yet, so keep `CraftingRequest.base` working by building `[request.base]` in `preview` for now).
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: SpellBuilder folds several Bases and buff stacks"`, with the trailer.

---

### Task 5: CraftingSystem with Base lists and buff stacks

**Files:**
- Modify: `scripts/crafting/crafting_request.gd`, `scripts/crafting/crafting_system.gd`, `tests/test_crafting_system.gd`, `tests/test_crafting_session.gd` (only the lines that build requests), `tests/test_main.gd` (only if it builds requests)

**Interfaces:**
- Produces `CraftingRequest.bases: Array[ScrollData]` (replaces `base`) and keeps `area`, `option_index`, `buffs` (repeats are stacks) and `slot_index`.
- Produces on `CraftingSystem` (reasons, in this checking order, after the existing no-Area, wrong-Area and bad-range checks): `REASON_NO_BASE` when `bases` is empty, `REASON_WRONG_BASE` for any non-Base entry, `REASON_BAD_BUFF := "That is not a usable buff scroll."`, `REASON_STACK_CAP := "That buff cannot be stacked any further."`, `static need_bases_reason(count: int) -> String` ("Pick %d more Base scroll(s) for your Additional Base." with the right plural), `REASON_TOO_MANY_BASES := "Add an Additional Base scroll to use a second element."`, `REASON_DUPLICATE_ELEMENT := "A spell can't use the same element twice."`, then the existing `REASON_LOCKED_SLOT`, `REASON_MISSING` (now checking every Base, the Area and every buff scroll in the quantity used), `REASON_CANNOT_BUILD`, and last `REASON_TOO_COSTLY := "Too costly: this spell could never cast."`. `REASON_BUFFS_LOCKED` is removed.
- `preview(request, rules)` builds with `request.bases`, `request.area`, the option and `request.buffs`. `craft` removes every Base scroll (one each), the Area scroll (one) and every buff scroll (one per stack) only after full validation, then equips, and a failed craft changes nothing.

- [ ] **Step 1: Write the failing tests.** Update `test_crafting_system.gd` so its `_request(base, area, ...)` helper sets `bases = [base]` (empty when `base` is null) and keeps its assertions: every Sprint 6 case still passes, with the one change that the "buffs given" case is replaced (below). Add: `test_a_buff_craft_consumes_every_scroll_used` (own 2 Fire, 1 Missile, 3 Increased Damage: crafting with two damage stacks leaves Fire 1, Missile 0, damage scrolls 1, and the equipped spell has `buff_stacks` `{buff_damage: 2}`), `test_a_hybrid_craft_consumes_both_bases_and_the_additional_base_scroll` (Fire, Sea, Additional Base, Missile all used, the spell's elements are `[FIRE, SEA]`), `test_base_count_must_match_the_additional_base_stacks_exactly` (one Additional Base stack with one Base gives `need_bases_reason(1)`, two Bases without the buff give `REASON_TOO_MANY_BASES`, two stacks with two Bases give `need_bases_reason(1)`), `test_repeated_elements_are_refused` (Fire twice, or two different Fire scrolls with the same element, give `REASON_DUPLICATE_ELEMENT`), `test_stack_caps_and_ownership` (five Duplicate Area stacks give `REASON_STACK_CAP`, a second Ignore Resistance gives `REASON_STACK_CAP`, three damage stacks with two owned give `REASON_MISSING`), `test_bad_buff_entries` (a Base scroll, an Area scroll, or a Buff scroll whose `buff` is null in the buff list gives `REASON_BAD_BUFF`), `test_a_spell_that_could_never_cast_is_refused` (so many damage stacks that cost exceeds the pool gives `REASON_TOO_COSTLY`), `test_every_invalid_buff_case_changes_nothing` (loop over all of the cases above plus the Sprint 6 list: inventory counts, every loadout slot and mana unchanged, and no `changed` or `slot_changed` signal), `test_validate_never_consumes_with_buffs`. Update `test_crafting_session.gd` and `test_main.gd` only where they construct a `CraftingRequest` or read `request.base` (the session itself is migrated in Task 6, so keep its `base` working by mapping it to `[base]` in `request()` for now).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures for the missing members.
- [ ] **Step 3: Implement** the request change and the validation and consumption described. Keep every old reason string unchanged.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: CraftingSystem validates and consumes Base lists and buff stacks"`, with the trailer.

---

### Task 6: CraftingSession with multi-select Bases and buff stacks

**Files:**
- Modify: `scripts/crafting/crafting_session.gd`, `tests/test_crafting_session.gd`

**Interfaces:**
- Consumes: `CraftingSystem` (new reasons), `SpellBuilder` (new `describe`, `can_cast`).
- Produces on `CraftingSession`: `bases: Array[ScrollData]` and `buffs: Array[ScrollData]` replace `base`; `max_bases() -> int` (1 plus the sum of the chosen buffs' `extra_bases`); `select_base(scroll) -> bool` (rejects null, non-Base and unowned scrolls; choosing a chosen Base removes it; choosing a new Base at the limit replaces the oldest choice; emits `changed`); `add_buff(scroll) -> bool` (rejects non-Buff scrolls, scrolls with no `buff`, a stack beyond the owned count or beyond `max_stacks`); `remove_buff(scroll) -> bool` (removes one stack, then trims the Base choices down to `max_bases()` by dropping the newest first); `buff_stacks(scroll) -> int`; `owned_bases()`, `owned_areas()`, `owned_buffs()` as before; `request()` copies `bases` and `buffs`; `new_stats()` and `current_stats()` as before with the extended `describe` keys; `drawbacks() -> Array[String]`; `message()` unchanged in meaning. After `confirm()` the session drops chosen Bases, the Area and buff stacks the player no longer owns enough of (trimming buffs to the owned count first, then Bases to `max_bases()`).
- `drawbacks()` returns plain-words lines: when buffs are chosen and the spell builds, the first is `"Buffs: costs %.1fx per cast, %d casts become %d."` (the multiplier is `mana_cost` with buffs over `mana_cost` without, the casts are pool over cost without and with buffs, rounded); when `can_cast` is false it also contains `"Too costly: this spell could never cast."`. With no buffs it returns an empty list.

- [ ] **Step 1: Write the failing tests.** Update `test_crafting_session.gd` so `session.base` assertions become `session.bases` assertions and every Sprint 6 case still passes (a single choice replaces the previous one at the default limit of 1). Add: `test_bases_are_multi_select_up_to_the_limit` (with one Additional Base stack owned and chosen, two Bases can be chosen, a third replaces the first), `test_the_limit_is_one_without_additional_base` (choosing a second Base replaces the first), `test_choosing_a_chosen_base_clears_it`, `test_buff_stacks_respect_ownership_and_caps` (own 2 damage scrolls: the third `add_buff` is false; own 5 Duplicate scrolls: the fifth is false; a second Ignore Resistance is false), `test_removing_additional_base_trims_the_extra_bases` (two Bases chosen with one stack, remove the stack: one Base left, the first), `test_bad_buff_choices_are_rejected` (a Base scroll, an Area scroll and a Buff scroll with no effect), `test_the_request_carries_bases_and_buff_stacks_as_copies` (changing the session afterwards doesn't change an earlier request), `test_confirm_with_buffs_uses_the_scrolls_and_trims_choices` (own 1 Fire, 1 Missile, 1 damage scroll; choose all and confirm: the damage stack, the Fire choice and the Missile choice are cleared), `test_drawbacks_describe_the_cost` (Fire Missile Normal with two Increased Damage: the line is "Buffs: costs 2.3x per cast, 100 casts become 44." and no buffs gives an empty list), `test_drawbacks_flag_a_spell_that_could_never_cast`, `test_message_asks_for_the_missing_base` (one Additional Base stack and one Base: the message is `CraftingSystem.need_bases_reason(1)`), `test_huge_stacks_keep_the_numbers_finite` (own and add 40 damage scrolls: `new_stats()` values are finite).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the file. Expected: failures for the missing members.
- [ ] **Step 3: Implement** the session changes. Update `CraftingScreen`'s `choose_base`, `buffs_text` and `_rebuild` just enough to compile against the new session (the full screen work is Task 7): `choose_base` calls `select_base`, and the Base column highlights every chosen Base.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: CraftingSession with multi-select Bases, buff stacks and drawbacks"`, with the trailer.

---

### Task 7: The crafting screen

**Files:**
- Modify: `scripts/ui/crafting_screen.gd`, `tests/test_crafting_screen.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: the Task 6 session.
- Produces on `CraftingScreen`: test-friendly `add_buff(scroll) -> bool` and `remove_buff(scroll) -> bool` (calling the session), `buff_button_count() -> int`, `buffs_text()` now describing the chosen buffs (for example "Buffs: Increased Damage x2, Duplicate Area x1" or "Buffs: none"), and `preview_text()` extended: after the existing stat lines it shows `Elements`, `Shots` (the copies), `Vulnerable bonus x%.1f` (only when above 1), `Ignores resistance` (only when set), then the session's `drawbacks()` lines, then the current spell's casts for comparison and the replace note.
- The buff row replaces the locked-buffs label. It shows, for each buff scroll the player owns, the scroll's name with a minus button, the chosen stack count over the owned count, and a plus button, laid out in two columns inside the band between the lists and the message (use `clip_text` and compact styles, and keep every existing control inside the 480x270 canvas without overlap). The Base column is multi-select, and the Base heading shows "Base (n of N)" where N is `max_bases()`. Confirm stays disabled with the session's reason until the recipe is complete.

- [ ] **Step 1: Write the failing tests.** Update `test_crafting_screen.gd` and `test_main.gd` for the session change (`choose_base` still toggles, `session.base` becomes `session.bases`) so every Sprint 6 test passes, and replace the Sprint 6 "buffs are shown locked" test. Add: `test_buff_buttons_exist_for_owned_buff_scrolls` (own two buff scroll types: `buff_button_count()` is 2 rows of controls, or the count the layout defines, matching the owned types), `test_buff_stepper_respects_ownership_and_caps` (own 2 damage scrolls: three `add_buff` calls give true, true, false; `remove_buff` lowers the stack), `test_preview_shows_elements_shots_and_drawbacks` (Fire plus Sea with Additional Base, Missile, Duplicate Area and two Increased Damage: `preview_text()` contains "Fire+Sea", the shot count 2, "casts become", and the current spell's name), `test_preview_hides_unused_lines` (a plain recipe has no "Ignores resistance" or "Vulnerable bonus" line), `test_base_heading_shows_the_limit` (the screen's Base heading text contains "1 of 1", and "1 of 2" after adding an Additional Base stack), `test_confirm_is_disabled_until_the_extra_base_is_picked` (Additional Base stack and one Base: `confirm_enabled()` false and `message_text()` is `CraftingSystem.need_bases_reason(1)`; add the second Base: enabled), `test_removing_additional_base_updates_the_screen` (the Base choice count drops), `test_full_hybrid_craft_through_the_screen` (own the scrolls, choose, confirm: the slot holds the hybrid spell with the expected elements and copies, every scroll is consumed and the screen closes), `test_huge_stacks_keep_the_preview_readable` (40 damage stacks: `preview_text()` contains no "inf" or "nan"). `test_main.gd`: `test_full_buffed_craft_through_main` (give scrolls with F10, open through a Lectern, add two Increased Damage, confirm: the player's slot spell has `buff_stacks` for damage 2, the inventory has one damage scroll left, and the spell bar widget matches).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures for the missing members.
- [ ] **Step 3: Implement** the buff row, the multi-select Base column with the heading, and the extended preview. Then run the screenshot check below.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Look at the screen in a real window.** Write a throwaway script in the scratchpad (like Sprint 6's) that opens the game, gives scrolls, opens the workbench, chooses a hybrid recipe with buffs, and saves a screenshot to the scratchpad. Read the image and fix any overlap or clipped text (the previous workbench overflowed until compact styles were used). Run the game once through the godot MCP (`run_project`, `get_debug_output`, `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: the crafting screen shows buffs, extra Bases and drawbacks"`, with the trailer.

---

### Task 8: Docs, stress check, wrap-up

**Files:**
- Modify: `README.md` (Multiple Base Types, Duplicate Area, buff stacking and costs), `technical-design.md` (section 8.3 and the crafting notes), `sprint-development.md` (tick Sprint 7 boxes, add a Built note), `CLAUDE.md` (Project State; replace "The rules for combining multiple Base types are undecided, so settle them before implementing Additional Base" with the best-match rule; add a "Buffs (Sprint 7)" section), `development-log.md`, `docs/sprints/sprint-7-design.md` (Status: Built)

**Interfaces:** none (documentation and measurement).

- [ ] **Step 1: Run the stress test** with a five-copy spell for each Area at 300 enemies, three runs each and the median: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --area=<missile|wave|zone> --copies=5` (and the same without `--copies` for the comparison). Record the medians. If any five-copy run is below 60 fps, also measure that Area at its real cast interval (set the stress spell's `cast_interval` to the Area's real one from the Global Constraints baselines) and report both. Report the numbers either way.
- [ ] **Step 2: Update the docs** listed above. In `development-log.md` add a "Sprint 7 (buffs)" entry: the decisions and calls from `docs/sprints/sprint-7-design.md`, the buff numbers, the best-match rule, the ring rule, the cost rules and why Increased Max Mana is the deliberate exception, the known limitations (balance untested in play, a hybrid is tinted with its first element, the screen is TEMPORARY in look), the migration notes, any findings during the build, and the stress table beside the Sprint 6 numbers.
- [ ] **Step 3: Run the full suite** three times and the smoke run. Expected: all pass, no errors.
- [ ] **Step 4: Commit.** `git add -A && git commit -m "docs: Sprint 7 complete"`, with the trailer.
