# Sprint 5 Spell Scroll Collection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enemies drop scrolls from themed per-enemy drop tables, the player picks them up by walking over them, and a per-run inventory stores them, with a toast on pickup and a toggleable panel to view them.

**Architecture:** `ScrollData` (one class, optional category fields) describes each of 15 scrolls. `DropTable` resources hang off `EnemyData`. `EnemySpawner` re-emits `enemy_died`, and a `ScrollDropper` rolls the table and places a passive `ScrollPickup`. A single active `PickupCollector` on the player collects overlapping pickups into a `ScrollInventory` component. A toast and an inventory panel (plus a touch button) read the inventory.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `docs/sprints/sprint-5-design.md` (approved). Also `docs/sprints/sprint-4-design.md`, `CLAUDE.md`, `technical-design.md` sections 6 and 7.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, and prefer the Edit tool for multi-line edits.
- Work on branch `sprint-5-scroll-collection`, cut from `main`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`).
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, no new autoloads, Input Map actions only (device -1 on every event). Hand-written `.tscn` needs `node_paths=PackedStringArray("prop")` for exported Node refs. Don't name a parameter `position` in a `Node2D` subclass (it shadows `Node2D.position` and warns).
- Enemies carry data only. No drop, scroll or inventory logic in `Player` or `Enemy` beyond owning components and data. No hardcoded scroll lists in scripts (the only list is `Main.debug_scrolls`, marked DEBUG).
- No crafting, Lectern, consuming scrolls in play, buff effects, scroll art, XP or Gold, world-found scrolls, inventory limits, or persistence across runs. The inventory lives on the player, so a death or restart resets it.
- Collision layers 1-5 are unchanged. New layer 6 `pickup` = bit 32.
- The 15 scrolls. `color` for Base is the spell's element colour (Fire `Color(1, 0.45, 0.1)`, Thunder `Color(1, 0.9, 0.2)`, Land `Color(0.6, 0.4, 0.2)`, Sea `Color(0.2, 0.55, 1)`), every Area `Color(0.85, 0.85, 0.9)`, every Buff `Color(0.75, 0.4, 0.9)`. `description` is one sentence (use the README text).

  | file | id | display_name | category | rarity | payload |
  |---|---|---|---|---|---|
  | `base/fire.tres` | `base_fire` | Fire | BASE | COMMON | element FIRE (0) |
  | `base/thunder.tres` | `base_thunder` | Thunder | BASE | COMMON | element THUNDER (1) |
  | `base/land.tres` | `base_land` | Land | BASE | COMMON | element LAND (2) |
  | `base/sea.tres` | `base_sea` | Sea | BASE | COMMON | element SEA (3) |
  | `area/line.tres` | `area_line` | Line | AREA | COMMON | `areas/line_area.tres` |
  | `area/cone.tres` | `area_cone` | Cone | AREA | COMMON | `areas/cone_area.tres` |
  | `area/area.tres` | `area_area` | Area | AREA | UNCOMMON | `areas/zone_area.tres` |
  | `area/missile.tres` | `area_missile` | Missile | AREA | COMMON | `areas/missile_area.tres` |
  | `area/wave.tres` | `area_wave` | Wave | AREA | UNCOMMON | `areas/wave_area.tres` |
  | `buff/max_mana.tres` | `buff_max_mana` | Increased Max Mana | BUFF | UNCOMMON | buff_id `max_mana` |
  | `buff/damage.tres` | `buff_damage` | Increased Damage | BUFF | UNCOMMON | buff_id `damage` |
  | `buff/double_vulnerability.tres` | `buff_double_vulnerability` | Double Vulnerability Damage | BUFF | RARE | buff_id `double_vulnerability` |
  | `buff/ignore_resistance.tres` | `buff_ignore_resistance` | Ignore Resistance | BUFF | RARE | buff_id `ignore_resistance` |
  | `buff/duplicate_area.tres` | `buff_duplicate_area` | Duplicate Area | BUFF | RARE | buff_id `duplicate_area` |
  | `buff/additional_base.tres` | `buff_additional_base` | Additional Base | BUFF | RARE | buff_id `additional_base` |

  All under `resources/scrolls/`. Area payload files are under `resources/spells/areas/`.
- Drop tables in `resources/drops/` (`basic_drops.tres`, `fire_drops.tres`, `thunder_drops.tres`, `land_drops.tres`, `sea_drops.tres`), each with `drop_chance = 0.06`. Entry weights (tune by playing): in an elemental enemy's table its own Base scroll 12 and each other Base 1. In the plain table every Base 3. In all tables: Line 2, Cone 2, Missile 2, Area 1, Wave 1, Increased Max Mana 1, Increased Damage 1, Double Vulnerability 0.5, Ignore Resistance 0.5, Duplicate Area 0.5, Additional Base 0.25. Each of the five enemy `.tres` gets `drop_table` pointing at its own file (`basic_enemy` to `basic_drops`, `fire_enemy` to `fire_drops`, and so on).
- Pickup cap 100. Collector radius about 14 px. Toast lasts about 1.2 s. Panel key `I` (physical keycode 73) and controller button 3, debug key F10 (physical keycode 4194341).
- Perf gate: the stress test (300 enemies) must stay at or above 60 fps, including with `--drops` (Sprint 4 baseline: 673 fps Missile, 191 Wave, 440 Zone).

## Review Focus

- Several pickups overlapping the collector in one frame must each be collected exactly once, and a pickup must never be collected twice. Pinned in Task 3.
- A dead player must collect nothing, and the panel must not open or must close when the player is dead. Pinned in Tasks 3 and 5.
- An empty drop table, or one with only null, scroll-less or zero-weight entries, must drop nothing without errors. An enemy with no drop table (or no data) must drop nothing. Pinned in Tasks 1 and 4.
- The 100-pickup cap must remove the oldest pickup so the newest always appears, and the count never exceeds 100. Pinned in Task 4.
- `remove` of more than is owned must change nothing, and removing the last of a scroll must leave no empty row in `by_category` or the panel. Pinned in Tasks 2 and 5.

---

### Task 1: Scroll data, catalog and drop tables

**Files:**
- Modify: `resources/scrolls/scroll_data.gd`, `resources/enemies/enemy_data.gd`, the five `resources/enemies/*_enemy.tres` files (including `basic_enemy.tres`), `tests/test_data_resources.gd` (only if it needs the new fields)
- Create: `resources/scrolls/drop_entry.gd`, `resources/scrolls/drop_table.gd`, the 15 scroll files in the table, the five drop tables, `tests/test_scroll_catalog.gd`, `tests/test_drop_table.gd`

**Interfaces:**
- Produces on `ScrollData`: keep `id`, `display_name`, `category` and `enum Category { BASE, AREA, BUFF }`; add `enum Rarity { COMMON, UNCOMMON, RARE }`, `@export_multiline var description: String`, `@export var rarity: Rarity = Rarity.COMMON`, `@export var color: Color = Color.WHITE`, `@export_enum("None:-1", "Fire:0", "Thunder:1", "Land:2", "Sea:3") var element: int = -1`, `@export var area_data: AreaData`, `@export var buff_id: StringName`.
- Produces `DropEntry` (`class_name DropEntry extends Resource`): `@export var scroll: ScrollData`, `@export var weight: float = 1.0`.
- Produces `DropTable` (`class_name DropTable extends Resource`): `@export_range(0.0, 1.0) var drop_chance: float = 0.06`, `@export var entries: Array[DropEntry] = []`, and `roll(rng: RandomNumberGenerator) -> ScrollData`: null if `drop_chance <= 0`; entries that are null, have no scroll, or have weight at or below 0 are never picked; null if nothing is pickable; otherwise, if `drop_chance < 1.0` and `rng.randf() >= drop_chance` null; else a weighted pick (fall back to the last pickable entry so rounding never returns a skipped one).
- Produces `EnemyData.drop_table: DropTable`.

- [ ] **Step 1: Write the failing tests.** `test_scroll_catalog.gd`: `test_all_fifteen_scrolls_match_the_catalog` (each file loads; id, display_name, category, rarity and colour match the table; Base has `element` 0-3 and no `area_data`; Area has an `area_data` whose `type` matches (line LINE, cone CONE, area AREA, missile MISSILE, wave WAVE) and `element == -1`; Buff has the `buff_id` and no area data; description is non-empty), `test_ids_are_unique`. `test_drop_table.gd`: `test_chance_zero_never_drops_and_one_always_drops` (a table with one entry: 200 rolls at 0.0 are all null, at 1.0 none are null), `test_weights_are_respected` (weights 1 and 3, chance 1.0, 2000 rolls with a seeded rng: the heavier appears more than twice as often), `test_unpickable_entries_are_never_picked` (null entry, entry with no scroll, weight 0, weight negative, mixed with one good entry: always the good one), `test_empty_and_all_unpickable_tables_return_null` (chance 1.0), `test_every_enemy_has_a_themed_table` (for each of Fire, Thunder, Land, Sea: load `<element>_enemy.tres`, its `drop_table` duplicated with `drop_chance = 1.0`, 6000 seeded rolls: among Base scrolls the enemy's own element is between 75% and 85% and is never 100%, and own-element drops are between 35% and 55% of all drops; for `basic_enemy.tres` the four Base scrolls each get between 20% and 30% of the Base drops), `test_every_catalog_scroll_can_drop` (the union of scrolls appearing in the five tables covers all 15), `test_drop_chance_is_six_percent_everywhere`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the full suite. Expected: failures or parse errors for the missing fields and files.
- [ ] **Step 3: Implement** the interfaces, then write the 15 scrolls and the five drop tables. Generate the `.tres` files with a throwaway script run by `venv/bin/python` and kept in the scratchpad (not in the repo), writing the exact table values above. Point each enemy `.tres` at its drop table (add an `ext_resource` and a `drop_table = ExtResource(...)` line, and fix `load_steps`).
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Expected: no errors.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: scroll data, catalog and themed drop tables"`, with the trailer.

---

### Task 2: ScrollInventory

**Files:**
- Create: `scripts/components/scroll_inventory.gd`, `tests/test_scroll_inventory.gd`
- Modify: `scripts/entities/player.gd`, `scenes/player/player.tscn`, `tests/test_player.gd`

**Interfaces:**
- Consumes: `ScrollData` from Task 1.
- Produces `ScrollInventory` (`class_name ScrollInventory extends Node`): `signal changed(scroll: ScrollData)`; `add(scroll: ScrollData, amount: int = 1) -> void` (ignores a null scroll and an amount at or below 0); `remove(scroll: ScrollData, amount: int = 1) -> bool` (all-or-nothing: false and no change if the scroll is null, the amount is at or below 0, or fewer are owned; removing the last one drops the row); `count(scroll) -> int`; `has(scroll, amount: int = 1) -> bool`; `by_category(category: ScrollData.Category) -> Array[ScrollData]` (scrolls with a count above 0, in the order they were first collected); `total_count() -> int` (sum of counts). Counts are keyed by `scroll.id`, so two loads of one scroll stack. `changed` emits on every successful add or remove.
- Produces `Player.inventory: ScrollInventory` (`@onready`, child node `ScrollInventory`).

- [ ] **Step 1: Write the failing tests.** `test_scroll_inventory.gd`: `test_add_stacks_identical_scrolls` (add fire twice and thunder once: count fire 2, thunder 1, total 3), `test_stacking_is_by_id` (two `ScrollData` instances with the same id stack), `test_add_ignores_null_and_non_positive_amounts`, `test_remove_is_all_or_nothing` (own 2, `remove(fire, 3)` is false and the count stays 2, `remove(fire, 2)` is true and the count is 0), `test_removing_the_last_one_leaves_no_row` (`by_category` no longer lists it, `has` is false), `test_by_category_groups_and_keeps_first_collected_order` (add thunder, fire, then an Area: Base lists thunder then fire, Area lists the area scroll, Buff is empty), `test_changed_emits_on_add_and_remove_only_when_something_changed` (a failed remove does not emit), `test_has_with_amounts`. `test_player.gd`: `test_player_has_a_scroll_inventory`.
- [ ] **Step 2: Run to verify they fail.** Expected: fail, class missing.
- [ ] **Step 3: Implement** `ScrollInventory`, add the node to `player.tscn`, and the `inventory` onready in `player.gd`.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: scroll inventory component"`, with the trailer.

---

### Task 3: Pickups and the collector

**Files:**
- Create: `scripts/scrolls/scroll_pickup.gd`, `scenes/scrolls/scroll_pickup.tscn`, `scripts/components/pickup_collector.gd`, `tests/test_scroll_pickup.gd`, `tests/test_pickup_collector.gd`
- Modify: `scripts/utilities/physics_layers.gd`, `project.godot` (layer name), `scenes/player/player.tscn`, `scripts/entities/player.gd`, `tests/test_physics_layers.gd`, `tests/test_player.gd`

**Interfaces:**
- Consumes: `ScrollData`, `ScrollInventory`, `HealthComponent.is_dead()`.
- Produces `PhysicsLayers.PICKUP := 32` and `2d_physics/layer_6="pickup"` in `project.godot`.
- Produces `ScrollPickup` (`class_name ScrollPickup extends Area2D`, scene root `Area2D` with `collision_layer = 32`, `collision_mask = 0`, `monitoring = false`, a circle `CollisionShape2D` of radius 6, and a `Polygon2D` child named `Shape`): `var scroll: ScrollData`; `setup(scroll: ScrollData) -> void` (sets the shape's polygon and colour and starts a gentle looping bob); `collect() -> ScrollData` (returns the scroll the first time and null every time after, makes itself non-monitorable and queues itself for deletion); `static shape_points(category: ScrollData.Category) -> PackedVector2Array` (Base: a 12-point circle of radius 5, Area: a square of side 8, Buff: a diamond with points at radius 6). It joins the group `scroll_pickups`.
- Produces `PickupCollector` (`class_name PickupCollector extends Area2D`, script `scripts/components/pickup_collector.gd`): `@export var inventory: ScrollInventory`, `@export var health: HealthComponent`, `signal collected(scroll: ScrollData)`. Each `_physics_process` it does nothing if `health` is dead, else for each overlapping `ScrollPickup` it calls `collect()`, and for a non-null result calls `inventory.add` and emits `collected`.
- Produces `Player.collector: PickupCollector` (`@onready`), and a `PickupCollector` node in `player.tscn` (`collision_layer = 0`, `collision_mask = 32`, `monitoring = true`, a circle of radius 14, `node_paths=PackedStringArray("inventory", "health")` pointing at `../ScrollInventory` and `../HealthComponent`).

- [ ] **Step 1: Write the failing tests.** `test_physics_layers.gd`: add `"pickup"` as layer 6 and `PhysicsLayers.PICKUP == 32`. `test_scroll_pickup.gd`: `test_pickup_is_passive_on_the_pickup_layer` (`monitoring` false, `collision_layer == 32`, `collision_mask == 0`), `test_setup_tints_the_shape_with_the_scroll_colour`, `test_shapes_differ_by_category` (the three `shape_points` results are all different, and Base has 12 points), `test_collect_returns_the_scroll_once` (first call is the scroll, the second null, the node is queued for deletion), `test_pickup_joins_the_group`. `test_pickup_collector.gd` (builds a `Player` under a per-test root, places pickups with `setup(fire)` at the player's position, `await wait_physics_frames(4)` after each placement): `test_walking_over_a_pickup_collects_it` (inventory count 1, the pickup freed or queued, `collected` emitted once with the scroll), `test_pickups_outside_the_radius_are_left_alone` (one at 60 px away is still there), `test_several_pickups_in_one_frame_are_each_collected_once` (five pickups at the player's position: total 5, `collected` emitted 5 times), `test_a_pickup_is_never_collected_twice` (after collection, 10 more frames leave the count at 1), `test_dead_player_collects_nothing` (kill the player first: a pickup in range stays and the inventory stays empty). `test_player.gd`: `test_player_has_a_pickup_collector`.
- [ ] **Step 2: Run to verify they fail.** Expected: fail, classes and layer missing.
- [ ] **Step 3: Implement** the layer constant and name, `ScrollPickup`, its scene, `PickupCollector`, and the player node and onready.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: scroll pickups and the player's pickup collector"`, with the trailer.

---

### Task 4: Drops

**Files:**
- Create: `scripts/systems/scroll_dropper.gd`, `tests/test_scroll_dropper.gd`
- Modify: `scripts/systems/enemy_spawner.gd`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_enemy_spawner.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `DropTable.roll`, `EnemyData.drop_table`, `ScrollPickup.setup`, the scene `scenes/scrolls/scroll_pickup.tscn`.
- Produces `EnemySpawner.enemy_died(enemy: Enemy)`, emitted from the spawner's existing death handler.
- Produces `ScrollDropper` (`class_name ScrollDropper extends Node`): `@export var pickup_scene: PackedScene`, `@export var max_pickups: int = 100`, `var rng := RandomNumberGenerator.new()` (randomized in `_ready`), `var drop_root: Node` (defaults to the parent), and `on_enemy_died(enemy: Enemy) -> ScrollPickup`: returns null if the enemy or its `data` or `data.drop_table` is null, or the roll is null. Otherwise, while the tracked pickups (oldest first, with freed or queued ones pruned) number `max_pickups` or more, it frees the oldest, then instantiates the pickup, calls `setup`, adds it to `drop_root`, puts it at `enemy.global_position`, tracks it and returns it.
- `main.tscn` gets a `ScrollDropper` node (`pickup_scene` = the pickup scene). `Main._ready` connects `EnemySpawner.enemy_died` to `ScrollDropper.on_enemy_died`.

- [ ] **Step 1: Write the failing tests.** `test_enemy_spawner.gd`: `test_enemy_died_is_re_emitted` (spawn one, `watch_signals(spawner)`, kill it with `receive_hit(1000.0, ZERO)`: `enemy_died` emitted once with that enemy). `test_scroll_dropper.gd` (a dropper under a per-test root with `drop_root` set; enemies from `base_enemy.tscn` set up with data whose `drop_table` is a duplicate with `drop_chance = 1.0` and one entry): `test_a_drop_places_one_pickup_at_the_enemys_position` (returns a pickup whose `scroll` is the entry's scroll and whose `global_position` equals the enemy's, and the root gains exactly one pickup), `test_no_drop_places_nothing` (chance 0.0), `test_enemy_without_a_table_or_data_drops_nothing` (`drop_table` null, and `data` null, both return null with no errors), `test_unpickable_table_drops_nothing` (a table of null and zero-weight entries), `test_cap_removes_the_oldest_and_keeps_the_newest` (cap 3, five drops with distinct positions: three pickups remain, they are the last three, and the first two are freed or queued), `test_pickup_count_never_exceeds_the_cap` (cap 5, 40 drops: never more than 5 valid pickups at any step), `test_freed_pickups_do_not_count_against_the_cap` (collect one with `collect()` and `await` a frame, then a drop does not evict another). `test_main.gd`: `test_killing_an_enemy_can_drop_a_scroll` (instantiate `main.tscn`, give the `ScrollDropper` a table with chance 1.0 through a duplicate of the spawned enemy's data, spawn and kill an enemy: a `scroll_pickups` group member appears).
- [ ] **Step 2: Run to verify they fail.** Expected: fail, signal and class missing.
- [ ] **Step 3: Implement** the relay, `ScrollDropper`, the `main.tscn` node, and the `Main` connection.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Then run the game once through the godot MCP (`run_project`, `get_debug_output`, `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: themed scroll drops from enemy deaths"`, with the trailer.

---

### Task 5: Toast, panel, button, input and wiring

**Files:**
- Create: `scripts/ui/scroll_toast.gd`, `scenes/ui/scroll_toast.tscn`, `scripts/ui/inventory_panel.gd`, `scenes/ui/inventory_panel.tscn`, `scripts/ui/inventory_button.gd`, `scenes/ui/inventory_button.tscn`, `tests/test_scroll_toast.gd`, `tests/test_inventory_panel.gd`, `tests/test_inventory_button.gd`
- Modify: `project.godot` (actions `toggle_inventory` and `debug_give_scrolls`), `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_input_map.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `ScrollInventory` (`changed`, `by_category`, `count`, `total_count`), `PickupCollector.collected`, `Player.died`, `Player.health`.
- Produces input actions `toggle_inventory` (key `I`, physical keycode 73, and joypad button 3) and `debug_give_scrolls` (key F10, physical keycode 4194341), all events with device -1.
- Produces `ScrollToast` (`class_name ScrollToast extends Control`, TEMPORARY): `show_scroll(scroll: ScrollData) -> void` sets a label to `"+ %s Scroll" % display_name` in the scroll's colour, shows it fully opaque for about 1.2 s then fades and hides; a newer pickup replaces the text and restarts the timer; `is_showing() -> bool`; `text() -> String`. It only processes while showing.
- Produces `InventoryPanel` (`class_name InventoryPanel extends Control`, TEMPORARY): `bind(inventory: ScrollInventory) -> void`, `toggle() -> void`, `set_open(value: bool) -> void`, `is_open() -> bool`, `entries() -> Array[String]`. The panel starts closed. `entries()` lists, in display order, the headings `"Base"`, `"Area"`, `"Buff"`, each followed by its rows formatted `"%s (%s) x%d"` (display name, rarity as `Common`/`Uncommon`/`Rare`, count) or a single `"-"` when the category is empty. The visible rows (swatch, name, rarity, count) are rebuilt on `changed` and when opened.
- Produces `InventoryButton` (`class_name InventoryButton extends Control`, TEMPORARY, about 28x14): `signal pressed`, `set_total(total: int)`, `handle_touch(screen_position: Vector2) -> bool` (like `SpellSlotWidget`: emits `pressed` and returns true only when visible and the point is inside it), handling `InputEventScreenTouch` itself and ignoring mouse clicks.
- `main.tscn`: a `ScrollToast` at the top centre and an `InventoryButton` at the top right in the `Hud` layer, and an `InventoryPanel` centred in `Hud` (all `mouse_filter` ignoring the mouse). `Main` gets `@export var debug_scrolls: Array[ScrollData]` (the 15 scrolls, set in `main.tscn`, marked DEBUG). `Main._ready` binds the panel, connects `_player.collector.collected` to the toast, the inventory's `changed` to `InventoryButton.set_total(inventory.total_count())` (and sets it once), `InventoryButton.pressed` to the panel's toggle, and `_player.died` to close the panel. `Main._unhandled_input` handles `toggle_inventory` (ignored when the player is dead) and `debug_give_scrolls` (adds 3 of every `debug_scrolls` entry).

- [ ] **Step 1: Write the failing tests.** `test_input_map.gd`: add both actions to `ACTIONS` (so the all-events-match-any-device test covers them), `test_toggle_inventory_has_key_and_joypad` and `test_debug_give_scrolls_is_a_key`. `test_scroll_toast.gd`: `test_toast_shows_text_and_colour`, `test_toast_fades_and_hides_and_stops_processing` (after `_process(1.3)`: not showing, not processing), `test_a_new_pickup_replaces_the_text_and_restarts_the_timer`, `test_toast_starts_hidden_and_idle`. `test_inventory_panel.gd`: `test_panel_starts_closed`, `test_toggle_opens_and_closes`, `test_entries_group_by_category_with_counts` (bind an inventory, add fire x3, line x1, double vulnerability x2: entries are `["Base", "Fire (Common) x3", "Area", "Line (Common) x1", "Buff", "Double Vulnerability Damage (Rare) x2"]`), `test_empty_categories_show_a_dash` (empty inventory: `["Base", "-", "Area", "-", "Buff", "-"]`), `test_panel_updates_when_the_inventory_changes_while_open`, `test_removed_scrolls_leave_no_row` (add then remove the last one: back to the dash). `test_inventory_button.gd`: `test_touch_inside_emits_pressed`, `test_touch_outside_and_hidden_do_nothing`, `test_mouse_clicks_are_ignored`, `test_set_total_updates_the_label`. `test_main.gd`: `test_collecting_a_scroll_shows_the_toast_and_updates_the_button` (put a pickup on the player in `Main` and wait for physics frames), `test_toggle_action_opens_the_panel_and_a_dead_player_cannot` (call `main._unhandled_input` with an `InputEventAction` for `toggle_inventory`; after the player dies, the panel is closed and stays closed), `test_debug_key_gives_three_of_every_scroll` (inventory total 45, each scroll 3), `test_player_death_closes_the_panel`.
- [ ] **Step 2: Run to verify they fail.** Expected: failures for the missing actions and classes.
- [ ] **Step 3: Implement** the three UI classes and scenes, the input actions (add them to `project.godot` in the same format as `debug_restore_mana`), and the `Main` wiring and `main.tscn` nodes.
- [ ] **Step 4: Run to verify they pass.** `godot --headless --import`, then the full suite. Expected: all pass.
- [ ] **Step 5: Smoke run** `godot --headless --quit-after 60`. Then run the game once through the godot MCP. Expected: no errors or warnings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: scroll toast, inventory panel and button"`, with the trailer.

---

### Task 6: Stress check, docs, wrap-up

**Files:**
- Modify: `scenes/world/stress_test.tscn`, `scripts/dev/stress_test.gd`, `README.md` (Area Scrolls and the crafting-possibility list: five Areas, Wave scroll), `technical-design.md` (the Area scroll list gains Wave, and section 6 notes that scrolls are one `ScrollData` class with category fields), `sprint-development.md` (tick Sprint 5 boxes and add a Built note), `CLAUDE.md` (Project State and a "Scrolls (Sprint 5)" section), `development-log.md`, `docs/sprints/sprint-5-design.md` (Status: Built)

**Interfaces:**
- Produces a `--drops` flag for the stress test: the stress scene gets a `ScrollDropper` node and the flag connects `EnemySpawner.enemy_died` to it, so kills drop real scrolls and the pickup cap is exercised. Without the flag nothing changes.

- [ ] **Step 1: Add the `--drops` flag** to `stress_test.gd` and the node to `stress_test.tscn`. Run the full suite and the smoke run. Expected: all pass, no errors.
- [ ] **Step 2: Run the stress test** at 300 enemies for the default Missile, `--area=wave` and `--area=zone`, each also with `--drops`: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=10` (plus `--area=<name>` and `--drops`). Record the six `STRESS` lines. Expected: `avg_fps` of at least 60 for all. If any is below 60, stop and report it before continuing.
- [ ] **Step 3: Update the docs** listed above. In `development-log.md` add a "Sprint 5 (scroll collection)" entry: the decisions and calls from `docs/sprints/sprint-5-design.md`, the starting drop numbers, the known limitations (the panel does not pause the game, no inventory limit, F10 debug key to delete later), and the stress table beside the Sprint 4 numbers.
- [ ] **Step 4: Run the full suite** and the smoke run. Expected: all pass, no errors.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "docs: Sprint 5 complete"`, with the trailer.
