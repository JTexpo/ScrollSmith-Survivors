# Sprint 12d: Points of Interest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put five kinds of point of interest on the first map (Health Shrine, Mana Shrine, Treasure Chest, Rare scroll spot, Merchant), all driven by one data resource, free to use except the merchant, each refreshing after a delay.

**Architecture:** `PointOfInterestData` (a resource with a `kind` and numbers) describes a kind. One `PointOfInterest` node (an `Area2D` like a Lectern) holds the shared state, a pausable refresh timer and the prompt, and only emits `used`. A static `PointOfInterestSystem` holds the rules (refusals, effects, loot rolls). `Main` routes a use: apply an effect, add Gold, place scrolls through the existing dropper, or open a `MerchantScreen`, which sells potions through `ShopSystem` with a price multiplier and per-merchant stock.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1.

**Spec:** `sprint-12d-design.md` (repo root). Read it first.

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit </dev/null` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, and zsh does not word-split unquoted variables.
- Shrines and chests are **free**. Only the merchant costs Gold, and it sells **potions only** (no scrolls, no equipment). Every point of interest **refreshes after a delay**, on a timer that freezes while the game is paused and starts ready every run (nothing about a point of interest is saved, except the potions and Gold a merchant sale changes, which are saved at once).
- Behaviour comes from `PointOfInterestData.kind` and its numbers. No code branches on a point of interest's id or name. Numbers (all data, my calls): Health Shrine heals 0.5 of maximum health, refresh 180 s; Mana Shrine restores 0.5 of every pool, 240 s; Chest 20 to 40 Gold plus 1 scroll from `chest_drops.tres`, 300 s; Rare scroll spot 1 scroll from `resources/bosses/boss_scrolls.tres` and no Gold, 300 s; Merchant `price_multiplier` 1.5, `stock_per_potion` 2, restock 300 s.
- A refused use changes nothing and starts no timer. The merchant's sale is all-or-nothing: Gold, potion count and stock change together or not at all.
- World nodes (the point's body and ring) must not stop touches: `mouse_filter = 2` on any Control. Hand-written `.tscn`/`.tres` need `node_paths=PackedStringArray("prop")` on the `[node]` line for any Node-typed export set by NodePath.
- Tests that instantiate `main.tscn` set `save_path = ""` (or a folder in `res://.godot/save_tests/`) and the pick screen's `pause_tree = false` before `add_child`, and never touch the real save. Screens that pause the tree take a `pause_tree` export that tests turn off. No test depends on an unseeded random roll.
- The Sprint 12a to 12c systems (map data, obstacles, flow field, mazes) are not edited. Placements go through the existing `MapPlacement`.
- Conventions: PascalCase classes, snake_case members, UPPER_SNAKE constants, typed GDScript, `##` doc comments, gameplay values in Resources or `@export`s. Match surrounding code's comment density.
- Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`, never `;`, so a failing test stops the commit. Commit generated `.uid` files with their scripts.

## Review Focus

- A refused use (Health Shrine at full health, Mana Shrine with every spell full, a dead player, one still refreshing) never consumes the point or starts its timer, and a used point cannot be used again before it refreshes (Tasks 2, 6).
- Timers freeze while the tree is paused, every point starts each run ready, and two points built from one data resource never share a timer or stock (Tasks 3, 4).
- The merchant never sells with too little Gold, never takes stock below zero, and never takes Gold when the potion stack is full; the sale, the Gold, the potion count and the stock stay in step, and the sale is saved (Tasks 3, 5, 6).
- Loot lands where it can be collected: the Gold is added once, each scroll is placed beside the point and not inside a wall, and a Rare scroll is not evicted by the pickup cap before it can be reached (Task 6).
- On the first map every point is reachable, at least 24 px from every wall, not blocking a corridor or gate, every kind appears, and the two Rare scroll spots sit at the maze centres (Task 7).

---

### Task 1: Data and results

**Files:**
- Create: `resources/points_of_interest/point_of_interest_data.gd`, `resources/points_of_interest/health_shrine.tres`, `mana_shrine.tres`, `treasure_chest.tres`, `rare_scroll_spot.tres`, `merchant.tres`, `resources/drops/chest_drops.tres`, `scripts/points_of_interest/point_of_interest_result.gd`
- Test: `tests/test_point_of_interest_data.gd`

**Interfaces:**
- Produces:
  - `PointOfInterestData` (`Resource`): `enum Kind { HEAL, RESTORE_MANA, LOOT, MERCHANT }`, `id: StringName`, `display_name: String`, `kind: Kind`, `amount: float` (a fraction), `gold_min: int`, `gold_max: int`, `scroll_count: int`, `scroll_table: DropTable`, `stock_per_potion: int`, `price_multiplier: float`, `refresh_seconds: float`, `color: Color`.
  - `PointOfInterestResult` (`RefCounted`): `message: String`, `gold: int`, `scrolls: Array[ScrollData]`.
  - The five `.tres` with the numbers in Global Constraints and distinct colours, and `chest_drops.tres` (a `DropTable`, `drop_chance` 1.0, all 15 scrolls from `resources/scrolls/`, weight 6 for Common, 3 for Uncommon, 1 for Rare, read from each scroll's `rarity`).

- [ ] **Step 1: Write the failing tests** (`tests/test_point_of_interest_data.gd`, loading each `.tres`): `test_there_are_five_kinds_with_distinct_ids_and_colors`; `test_each_kind_has_the_numbers_it_needs` (HEAL and RESTORE_MANA: `amount` between 0 and 1; LOOT: `gold_max >= gold_min >= 0`, `scroll_count >= 0`, a `scroll_table` when `scroll_count > 0`; MERCHANT: `stock_per_potion >= 1`, `price_multiplier >= 1.0`; all: `refresh_seconds > 0`); `test_the_numbers_are_the_designed_ones` (the values in Global Constraints); `test_the_rare_scroll_spot_uses_the_rare_only_table` (every pickable entry of its table is `ScrollData.Rarity.RARE`, no Gold); `test_the_chest_table_has_all_15_scrolls_weighted_by_rarity` (15 entries, weights 6, 3, 1 by rarity, `drop_chance == 1.0`).
- [ ] **Step 2: Run** `-gselect=test_point_of_interest_data`. Expected: FAIL.
- [ ] **Step 3: Implement** the scripts, then hand-write the `.tres` files (typed arrays as in `resources/drops/basic_drops.tres`). Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_point_of_interest_data`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: point of interest data, results and the five kinds`.

### Task 2: The rules

**Files:**
- Create: `scripts/points_of_interest/point_of_interest_system.gd`
- Test: `tests/test_point_of_interest_system.gd`

**Interfaces:**
- Consumes: `PointOfInterestData`, `PointOfInterestResult` (Task 1), `Player` (`health`, `loadout`), `DropTable.roll(rng, luck, chance_scale)`.
- Produces: `PointOfInterestSystem` (`RefCounted`, static): `const REASON_DEAD`, `REASON_REFRESHING`, `REASON_FULL_HEALTH`, `REASON_FULL_MANA` (strings; reuse the wording of `PotionSystem`'s where it matches); `static func refusal(data: PointOfInterestData, player: Player, cooldown_left: float) -> String` (empty when allowed; checked in order: dead, refreshing (`cooldown_left > 0`, never for a MERCHANT), full health for HEAL, every spell full for RESTORE_MANA); `static func apply(data, player: Player, rng: RandomNumberGenerator, luck: float = 0.0) -> PointOfInterestResult` (HEAL heals `amount * max_health`, RESTORE_MANA restores `amount * max_mana()` on every filled slot, LOOT rolls `rng.randi_range(gold_min, gold_max)` Gold and `scroll_count` scrolls from `scroll_table.roll(rng, luck)` skipping nulls; each returns a short `message`: "Healed 50%", "Restored 50% mana", "+25 Gold" and "Found: <scroll name>" lines as appropriate; a MERCHANT returns an empty result).

- [ ] **Step 1: Write the failing tests** (a real `Player` from `res://scenes/player/player.tscn` in a `Node2D`, as `test_potion_system.gd` does, data built in code):
  - `test_refusal_when_dead_or_refreshing_and_never_for_a_merchant_that_is_refreshing`, `test_a_health_shrine_refuses_at_full_health_and_allows_when_hurt`, `test_a_mana_shrine_refuses_when_every_spell_is_full_and_allows_when_one_is_not`, `test_a_chest_is_never_refused_by_health_or_mana`.
  - `test_heal_restores_the_fraction_of_maximum_health_and_never_above_it`, `test_restore_mana_fills_the_fraction_on_every_filled_slot`.
  - `test_loot_rolls_gold_in_range_and_the_scroll_count` (a seeded rng, 40 rolls: Gold within `[gold_min, gold_max]`, exactly `scroll_count` scrolls from the table), `test_a_rare_spot_gives_only_rare_scrolls_and_no_gold`, `test_luck_is_passed_to_the_table` (with a mixed-rarity table, a high luck gives more Rare scrolls than luck 0 over 300 seeded rolls), `test_a_table_that_rolls_nothing_gives_an_empty_loot_without_error`.
  - `test_a_refused_use_leaves_health_and_mana_unchanged`.
- [ ] **Step 2: Run** `-gselect=test_point_of_interest_system`. Expected: FAIL.
- [ ] **Step 3: Implement** as specified. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_point_of_interest_system`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the rules of using a point of interest`.

### Task 3: Merchant stock and the price multiplier

**Files:**
- Create: `scripts/points_of_interest/merchant_stock.gd`
- Modify: `scripts/shop/shop_system.gd`
- Test: `tests/test_merchant_stock.gd`, `tests/test_shop_system.gd` (additions)

**Interfaces:**
- Produces:
  - `MerchantStock` (`RefCounted`): `setup(catalog: PotionCatalog, per_potion: int) -> void`, `count(id: StringName) -> int`, `take(id: StringName) -> bool` (false at zero, never negative; starts the restock timer on the first take), `tick(delta: float, restock_seconds: float) -> void` (counts down only while some stock is missing, refills every potion to `per_potion` when it elapses), `restock_left() -> float`, `is_full() -> bool`.
  - `ShopSystem.buy_potion(profile, catalog, id, price_multiplier: float = 1.0) -> ShopResult` and `ShopSystem.can_afford_potion(profile, potion, price_multiplier: float = 1.0) -> bool`, and `static func potion_price(potion: PotionData, price_multiplier: float) -> int` (`ceili(price * multiplier)`, at least 1 when the base price is above 0). With the default multiplier every existing behaviour and test is unchanged.

- [ ] **Step 1: Write the failing tests:**
  - `test_merchant_stock.gd`: `test_setup_fills_every_potion_to_the_count`, `test_take_lowers_the_count_and_refuses_at_zero`, `test_the_restock_timer_starts_on_the_first_take_and_refills_everything`, `test_the_timer_does_not_run_while_stock_is_full`, `test_two_stocks_never_share_state`.
  - `test_shop_system.gd`: `test_a_multiplied_price_is_rounded_up` (base 10, 1.5: 15; base 3, 1.5: 5), `test_buy_potion_with_a_multiplier_spends_the_multiplied_price_and_grants_one`, `test_a_multiplied_purchase_refuses_when_the_gold_is_below_the_multiplied_price_and_changes_nothing`, `test_a_full_potion_stack_refuses_without_taking_gold_at_any_multiplier`, `test_the_default_multiplier_is_the_old_price`.
- [ ] **Step 2: Run** both. Expected: FAIL.
- [ ] **Step 3: Implement** both. Run `godot --headless --import`.
- [ ] **Step 4: Run** both files and `-gselect=test_shop_screen`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: merchant stock and a price multiplier for potions`.

### Task 4: The node and its five scenes

**Files:**
- Create: `scripts/points_of_interest/point_of_interest.gd`, `scenes/interactables/point_of_interest.tscn`, `scenes/interactables/health_shrine.tscn`, `mana_shrine.tscn`, `treasure_chest.tscn`, `rare_scroll_spot.tscn`, `merchant.tscn`
- Modify: `tests/test_world_input.gd` (add the five scenes)
- Test: `tests/test_point_of_interest.gd`

**Interfaces:**
- Consumes: `PointOfInterestData` (Task 1), `MerchantStock` (Task 3), `PhysicsLayers.INTERACTABLE`.
- Produces: `PointOfInterest` (`Area2D`, collision layer 64 and mask 0 like the Lectern, group `points_of_interest`): `signal used(point: PointOfInterest, actor: Node)`, `@export var data: PointOfInterestData`, `var cooldown_left: float`, `var stock: MerchantStock` (null unless MERCHANT, set up from `PotionCatalog.default_catalog()` in `_ready`), `interact(actor: Node)` (emits `used`), `is_ready() -> bool`, `start_cooldown() -> void` (sets `cooldown_left = data.refresh_seconds`), `refresh_progress() -> float` (0 just used, 1 ready), `prompt_text() -> String` ("Health Shrine (E)" when ready, "Health Shrine 2:15" while refreshing, "Merchant (E)" always for a merchant), `set_prompt_visible(value: bool)`, `loot_spot(index: int, count: int) -> Vector2` (a world position on a 20 px ring around the point, evenly spread). `_process(delta)` counts the cooldown down and ticks the stock. A body and a ring that fills while refreshing are drawn in `_draw` (the point's `color`). The base scene has a `Prompt` label like the Lectern's, a 24 px circle shape, and every Control ignores the mouse. Each of the five scenes instances the base with its `.tres`.

- [ ] **Step 1: Write the failing tests:**
  - `test_interact_emits_used_with_the_point_and_the_actor`.
  - `test_a_new_point_is_ready_and_start_cooldown_makes_it_refresh_then_ready`.
  - `test_the_timer_counts_down_with_process_and_stops_at_zero` (call `_process` directly).
  - `test_the_timer_freezes_while_the_tree_is_paused` (async: pause the tree, `await wait_physics_frames`/frames, `cooldown_left` unchanged, unpause in the test's end).
  - `test_two_points_from_one_data_never_share_a_timer_or_stock`.
  - `test_refresh_progress_and_the_prompt_text_follow_the_state` (ready, refreshing "2:15"-style text, merchant always "(E)").
  - `test_a_merchant_has_stock_and_the_others_do_not`.
  - `test_loot_spots_lie_on_the_ring_and_differ` (for count 1 and 3).
  - `test_each_scene_loads_with_its_data_and_the_right_kind` (the five scenes: kinds HEAL, RESTORE_MANA, LOOT, LOOT, MERCHANT; the Rare scroll spot's table is Rare-only).
  - `test_the_player_interaction_finds_a_point_like_a_lectern` (a `Player`, a point in range on the interactable layer: `InteractionComponent` selects it after a physics frame and shows its prompt).
- [ ] **Step 2: Run** `-gselect=test_point_of_interest`. Expected: FAIL.
- [ ] **Step 3: Implement** the script and the scenes (hand-written `.tscn`, as `lectern.tscn`). Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_point_of_interest` and `-gselect=test_world_input`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: PointOfInterest, one node and five scenes`.

### Task 5: The merchant screen

**Files:**
- Create: `scripts/ui/merchant_screen.gd`, `scenes/ui/merchant_screen.tscn`
- Test: `tests/test_merchant_screen.gd`

**Interfaces:**
- Consumes: `ShopSystem` with a multiplier and `MerchantStock` (Task 3), `PointOfInterest` (Task 4), `PotionCatalog`, `PlayerProfile`, `GamePause`.
- Produces: `MerchantScreen` (`CanvasLayer`, TEMPORARY look, modelled on `ShopScreen` and `CraftingScreen`): `signal changed` (a purchase happened: `Main` saves and refreshes the potion bar), `signal closed`, `@export var pause_tree: bool = true`, `open(profile: PlayerProfile, potion_catalog: PotionCatalog, merchant: PointOfInterest) -> void` (pauses the world through `GamePause` when `pause_tree`), `close()`, `is_open() -> bool`, and for tests `potion_button_count() -> int`, `button_text(id: StringName) -> String` (the potion's name, the multiplied price, the stock left and how many are owned), `gold_text() -> String`, `message_text() -> String`, `activate(id: StringName) -> void` (the same as pressing it). A press checks stock first ("Sold out"), then calls `ShopSystem.buy_potion` with the merchant's multiplier, and only on success takes one from the merchant's stock and emits `changed`; a refusal shows its reason and changes nothing. Cancel, the pause action and a close button close it. It handles its own touches and clicks (mouse emulation is off), as `ShopScreen` does. The `process_mode` is Always while open.

- [ ] **Step 1: Write the failing tests** (`pause_tree = false`, a `PlayerProfile` with Gold, a merchant node from `merchant.tscn`):
  - `test_it_lists_every_potion_with_the_multiplied_price_stock_and_owned_count`.
  - `test_a_purchase_spends_the_multiplied_gold_adds_the_potion_lowers_the_stock_and_emits_changed`.
  - `test_a_sold_out_potion_refuses_and_changes_nothing` (buy until stock 0, one more: "Sold out", Gold and potions unchanged).
  - `test_not_enough_gold_refuses_and_changes_nothing`.
  - `test_a_full_potion_stack_refuses_without_taking_gold_or_stock`.
  - `test_the_stock_restocks_while_the_screen_is_closed` (tick the merchant's stock to its restock time, reopen: counts are full).
  - `test_open_and_close_emit_closed_and_cancel_closes_it`.
  - `test_a_touch_on_a_potion_button_buys_exactly_one` (send an `InputEventScreenTouch` press and release at the button's position through the screen's input handler; one potion bought).
- [ ] **Step 2: Run** `-gselect=test_merchant_screen`. Expected: FAIL.
- [ ] **Step 3: Implement** the script and scene (a `ShopScreen`-style build in code). Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_merchant_screen`, `-gselect=test_shop_screen`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the merchant screen`.

### Task 6: Main routes a use

**Files:**
- Modify: `scripts/main/main.gd`, `scenes/main/main.tscn` (a `MerchantScreen` instance)
- Test: `tests/test_main_points_of_interest.gd`

**Interfaces:**
- Consumes: everything above, `ScrollDropper.place`, `RunProgress.add_gold`, `LevelToast.show_message`, `PotionBelt`/`PotionBar` refresh, `SaveGame` through `ProfileSaver.save_now`, `Player.require_cast_release`.
- Produces: in `Main._ready`, every node in the group `points_of_interest` that is a descendant of `Main` is passed to `Main.connect_point_of_interest(point: PointOfInterest)` (public, so tests can attach a point added later). Using a point does: refuse (`PointOfInterestSystem.refusal`) with the reason in the toast and nothing else; for a MERCHANT open the `MerchantScreen` (not while dead or while it is open); otherwise `PointOfInterestSystem.apply` with the Main's rng and `ScrollDropper.luck`, add the Gold through `RunProgress.add_gold`, place each scroll through `ScrollDropper.place(scroll, point.loot_spot(i, count))`, show the message in the toast, and `point.start_cooldown()`. A purchase (`MerchantScreen.changed`) refreshes the potion belt and bar (as `debug_give_potions` does) and saves at once. The screen's `closed` calls `Player.require_cast_release`.

- [ ] **Step 1: Write the failing tests** (a `Main` with `save_path = ""` and the pick screen's `pause_tree = false`, the merchant screen's `pause_tree = false`, points from the five scenes added under it and attached with `connect_point_of_interest`):
  - `test_using_a_health_shrine_heals_and_starts_its_timer_and_a_second_use_is_refused` (the player hurt first; the second `interact` shows the refreshing reason and changes no health).
  - `test_a_health_shrine_at_full_health_is_refused_and_not_consumed`.
  - `test_a_mana_shrine_restores_and_a_full_one_is_refused`.
  - `test_a_chest_adds_gold_once_places_a_scroll_beside_it_and_starts_its_timer` (the Gold equals the profile change; exactly one `ScrollPickup` appears within 25 px of the chest).
  - `test_a_rare_scroll_spot_places_a_rare_scroll_and_no_gold`.
  - `test_the_chest_is_ready_again_after_its_refresh_time` (step `_process` past `refresh_seconds`, a second use works).
  - `test_the_merchant_opens_its_screen_and_a_purchase_is_saved` (a throwaway save folder as in `test_main_progression.gd`: buy a potion, reload the profile from the file, the potion and the lower Gold are there).
  - `test_a_dead_player_cannot_use_a_point`.
  - `test_the_first_use_after_a_pause_still_counts_the_timer_correctly` (pause the tree for several frames after a use: `cooldown_left` unchanged).
  - `test_a_scroll_dropped_by_a_point_is_not_evicted_by_the_next_one` (with `max_pickups` set low to 2, place from two points: the first scroll survives while there is room, and the cap behaviour is the existing one: oldest evicted only past the cap).
- [ ] **Step 2: Run** `-gselect=test_main_points_of_interest`. Expected: FAIL.
- [ ] **Step 3: Implement** the Main changes and add the `MerchantScreen` to `main.tscn`.
- [ ] **Step 4: Run** `-gselect=test_main_points_of_interest`, `-gselect=test_main_map`, `-gselect=test_main_progression`, then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: Main routes the use of a point of interest`.

### Task 7: The first map's points of interest

**Files:**
- Modify: `resources/maps/first_map.tres`
- Test: `tests/test_first_map_points_of_interest.gd`

**Interfaces:**
- Consumes: the five scenes (Task 4), `MapPlacement`, `MapMaze.center_room_center()`.
- Produces: `first_map.tres` gains `MapPlacement`s: a Rare scroll spot at each maze's `center_room_center()` ((380, 300) and (1540, 780)), a Treasure Chest and a Mana Shrine inside the island (the island zone is `Rect2(1360, 40, 420, 330)`, its walls enclose x 1396 to 1740, y 76 to 332, its gates are at x 1530 to 1610 on the south and y 210 to 290 on the west; place them clear of both gates and any route through), a Health Shrine in the long corridor (walls at y 930 and y 1010, x 480 to 1040: in the middle, at (760, 970)) and the Merchant in the south-west open area (around (520, 760), clear of groves and Lecterns). Exact coordinates are the builder's, judged by the F7 overlay, tuned by the user in play.

- [ ] **Step 1: Write the failing tests** (loading `first_map.tres`; the node instances are built from the placements' scenes):
  - `test_every_kind_appears_on_the_first_map` (two Rare scroll spots, one chest, one Mana Shrine, one Health Shrine, one Merchant, and still three Lecterns).
  - `test_the_map_has_no_problems_and_every_placement_is_reachable` (`MapData.problems()` and `ObstacleGrid.reachability_problems`, both empty: they already check placements against shapes by 24 px).
  - `test_the_rare_scroll_spots_are_at_the_maze_centres` (within 4 px of each maze's `center_room_center()`).
  - `test_the_island_points_are_inside_the_island_and_clear_of_both_gates`.
  - `test_the_corridor_shrine_is_between_the_corridor_walls_and_does_not_block_it` (its position is inside the corridor; the corridor stays two free grid cells wide, since an `Area2D` is not solid this is the existing layout test, which must still pass).
  - `test_the_merchant_is_in_the_open_south_west_and_not_near_a_lectern` (at least 150 px from every Lectern and from the start).
  - `test_no_two_points_of_interest_are_closer_than_80_px` (so the interaction always picks the right one).
  - The existing `test_first_map_layout.gd`, `test_first_map_regions.gd`, `test_map_data.gd` and `test_main_map.gd` still pass unchanged.
- [ ] **Step 2: Run** `-gselect=test_first_map_points_of_interest`. Expected: FAIL.
- [ ] **Step 3: Author the placements** in `first_map.tres` (new `MapPlacement` sub-resources and ext_resources for the five scenes). Run `godot --headless --import`, press F7 and look at a real-window whole-map screenshot to place them well.
- [ ] **Step 4: Run** the new file, `-gselect=test_first_map_layout`, `-gselect=test_first_map_regions`, `-gselect=test_map_data`, `-gselect=test_main_map`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the first map's points of interest`.

### Task 8: Verify and document

**Files:**
- Modify: `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `sprint-12d-design.md` (Status: Built)

- [ ] **Step 1: Smoke and MCP run.** `godot --headless --quit-after 60` is clean. Run the project with `mcp__godot__run_project`, read `get_debug_output` for warnings (load with `ToolSearch select:`), then `stop_project`.
- [ ] **Step 2: Stress.** `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles`, three or four runs, median. Expected: within about 15% of Sprint 12c (about 186 fps), since the stress scene builds the first map (and so the new nodes).
- [ ] **Step 3: Real-window check.** A throwaway scratchpad script (extends `SceneTree`, `save_path` empty so the real save is untouched, set up on the first frame, deleted afterwards): walk or place the player at a Health Shrine (hurt first), press E with a real key event, check health rose and the prompt shows the timer; use the chest and see a Gold change and a scroll pickup beside it; open the merchant, click a potion button with a real mouse event and a real touch event and check exactly one potion bought, the Gold lower, and that the world is paused while the screen is open and resumes on close; screenshot the merchant screen and a shrine with its ring. Look at the screenshots.
- [ ] **Step 4: Docs.** `sprint-development.md`: tick the five 12d items and add a Built note. `README.md`: the points of interest, their numbers and the merchant. `technical-design.md`: the new files. `CLAUDE.md`: a "Points of interest (Sprint 12d)" section (one generic node and data, `PointOfInterestSystem`, how `Main` routes a use, the merchant's stock and multiplier, refresh timers, the placement rules) and the changed shop facts. `development-log.md`: the 12d entry with the stress numbers. Set the design doc's status to Built.
- [ ] **Step 5: Full suite and commit.** Run the whole suite, then commit `docs: Sprint 12d complete`.
