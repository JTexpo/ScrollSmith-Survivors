# Sprint 0 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable Godot project with a controllable placeholder wizard, a following camera, a placeholder enemy, a touch joystick, spell and scroll data stubs, and a working GUT test run.

**Architecture:** Entities are `CharacterBody2D` scenes that own small reusable component nodes (`MoveComponent`, `HealthComponent`). Input goes only through Input Map actions. The touch joystick injects those same actions. Data definitions are `Resource` subclasses. There are no autoloads.

**Tech Stack:** Godot 4.7.2 (Homebrew), typed GDScript, GUT 9.7.1 (already vendored in `addons/gut/`), Compatibility renderer.

**Spec:** `docs/sprints/sprint-0-design.md` (approved). Scope also follows `sprint-development.md` (Sprint 0), `technical-design.md` and `CLAUDE.md`.

## Global Constraints

- All shell commands run with the project venv active (`source venv/bin/activate`). Any Python is `venv/bin/python`.
- Godot 4.7.2 at `/opt/homebrew/bin/godot`. Renderer: Compatibility (`gl_compatibility`). No threads, no GDExtension.
- Internal resolution 480×270. Stretch mode `viewport`, scale mode `integer`, aspect `keep`. Default texture filter nearest. 2D transform snap on. Window override 1440×810.
- Typed GDScript. PascalCase classes, snake_case variables/functions/signals, UPPER_SNAKE_CASE constants. One responsibility per script.
- No autoloads. No combat, spells, casting, mana, crafting, or touch aiming/casting/buttons (all later sprints).
- Gameplay reads only Input Map actions. Keyboard, mouse and controller share one implementation.
- Tests live in `tests/test_*.gd`. Every task commits when its tests pass. Don't create directories before they hold files.
- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

- Diagonal movement (W+D) must not be faster than straight movement. Test in Task 3.
- Healing above max HP or damaging below zero must clamp, and `died` must emit exactly once. Test in Task 2.
- Joystick released, or a second finger touching while the first is held, must not leave stuck movement or jump to the second finger. Test in Task 6.
- A negative or zero damage/heal amount must not change HP. Test in Task 2.
- Switching to a missing scene path must return an error and leave the current scene alone. Test in Task 7.

## File Structure

| File | Responsibility |
|---|---|
| `project.godot`, `export_presets.cfg` | Settings, Input Map, Web preset |
| `.gutconfig.json` | GUT test directory, prefix, exit |
| `scripts/components/health_component.gd` | HP, damage, heal, `died` |
| `scripts/components/move_component.gd` | Velocity from direction and speed |
| `scripts/entities/player.gd`, `enemy.gd` | Entity wiring, no game rules |
| `scripts/ui/virtual_joystick.gd` | Touch input to actions |
| `scripts/utilities/scene_switcher.gd` | Safe scene changes |
| `resources/spells/spell_data.gd`, `resources/scrolls/scroll_data.gd` | Data stubs |
| `scenes/...` | main, player, base_enemy, test_arena, touch_controls |
| `tests/test_*.gd` | One test file per script |
| `development-log.md` | Decisions record |

---

### Task 1: Project skeleton and GUT running

**Files:**
- Create: `project.godot`, `.gutconfig.json`, `tests/test_smoke.gd`, `scenes/main/main.tscn`, `development-log.md`
- Modify: `CLAUDE.md` (Project State and test command)

**Interfaces:**
- Produces: a project that opens and imports headless, and the verified test command `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (used by every later task).

- [ ] **Step 1: Create `project.godot`** (config_version 5) with: name "SpellCraft Survivors", main scene `res://scenes/main/main.tscn`, features `("4.7", "GL Compatibility")`, rendering method `gl_compatibility` for both desktop and mobile, the display and filter values from Global Constraints, and the GUT editor plugin enabled (`res://addons/gut/plugin.cfg`).
- [ ] **Step 2: Create `scenes/main/main.tscn`** with a single `Node2D` root named `Main`, and `.gutconfig.json` with `{"dirs": ["res://tests/"], "prefix": "test_", "suffix": ".gd", "should_exit": true}`.
- [ ] **Step 3: Write the failing test** `tests/test_smoke.gd` (`extends GutTest`): `test_resolution_settings()` asserts `ProjectSettings.get_setting("display/window/size/viewport_width") == 480`, height `== 270`, stretch mode `== "viewport"`, scale mode `== "integer"`, and the default texture filter is `0` (nearest).
- [ ] **Step 4: Import and run to confirm the harness works**

Run: `godot --headless --import` then `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: GUT starts and the smoke test passes. If the settings are wrong the test fails first. Fix `project.godot` until it passes. If GUT fails to load on 4.7.2, stop and report the error. Don't work around it silently.
- [ ] **Step 5: Run the project once** with `godot --headless --quit-after 60` and expect no errors or warnings in the output.
- [ ] **Step 6: Record** the verified test command in `CLAUDE.md` (replace the "no commands exist" statements that are now false, and keep the rest), and write the first `development-log.md` entry (date, decisions from `docs/sprints/sprint-0-design.md`, GUT 9.7.1).
- [ ] **Step 7: Commit** `project.godot`, `.gutconfig.json`, `tests/`, `scenes/`, `addons/gut/`, `.gitignore`, `docs/sprints/sprint-0-design.md`, `docs/`, `development-log.md`, `CLAUDE.md` with `chore: Godot project skeleton, GUT 9.7.1, Sprint 0 design`.

---

### Task 2: HealthComponent

**Files:**
- Create: `scripts/components/health_component.gd`
- Test: `tests/test_health_component.gd`

**Interfaces:**
- Produces: `class_name HealthComponent extends Node`, with `@export var max_health: float = 10.0`, `var current_health: float`, `signal health_changed(current: float, maximum: float)`, `signal died`, `func take_damage(amount: float) -> void`, `func heal(amount: float) -> void`, `func is_dead() -> bool`. `current_health` starts at `max_health` in `_ready()`.

- [ ] **Step 1: Write the failing tests** (`extends GutTest`, each builds the component with `add_child_autofree` and calls `_ready` through the tree): `test_starts_at_max`, `test_damage_reduces_health_and_emits_changed` (10 → 7 after 3, uses `watch_signals`, `assert_signal_emitted_with_parameters(c, "health_changed", [7.0, 10.0])`), `test_damage_clamps_at_zero_and_emits_died_once` (damage 100 twice, `assert_signal_emit_count(c, "died", 1)`), `test_heal_clamps_at_max`, `test_non_positive_amounts_ignored` (damage 0, damage -5, heal -5 leave HP unchanged and emit no `health_changed`), `test_heal_after_death_ignored`.
- [ ] **Step 2: Run** the single file with `-gselect=test_health_component`. Expect FAIL (class missing).
- [ ] **Step 3: Implement `HealthComponent`** as above. Non-positive amounts return early, and heal does nothing when dead.
- [ ] **Step 4: Run** the single file. Expect all PASS.
- [ ] **Step 5: Commit** `feat: HealthComponent`.

---

### Task 3: Input Map, MoveComponent, Player, camera and arena

**Files:**
- Create: `scripts/components/move_component.gd`, `scripts/entities/player.gd`, `scenes/player/player.tscn`, `scenes/world/test_arena.tscn`, a one-off setup script in the scratchpad (not committed)
- Modify: `project.godot` (Input Map), `scenes/main/main.tscn`
- Test: `tests/test_input_map.gd`, `tests/test_move_component.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: actions `move_up`, `move_down`, `move_left`, `move_right`, `interact`, `pause`, `spell_slot_1`..`spell_slot_5`, `cast`. `class_name MoveComponent extends Node` with `@export var speed: float = 90.0` and `func apply(body: CharacterBody2D, direction: Vector2) -> void` (sets `body.velocity = direction.limit_length(1.0) * speed`, then `body.move_and_slide()`). `Player` is in group `"player"` and has child nodes `MoveComponent`, `HealthComponent`, `Camera2D`.

- [ ] **Step 1: Write the failing tests.** `test_input_map.gd`: `test_all_actions_exist` iterates the 14 names and asserts `InputMap.has_action(name)`, and `test_movement_has_keyboard_and_joypad_events` asserts each `move_*` has at least one `InputEventKey` and one `InputEventJoypadMotion` or `InputEventJoypadButton`. `test_move_component.gd`: `test_diagonal_not_faster` calls `apply` on a `CharacterBody2D` with `Vector2(1, 1)` and asserts `body.velocity.length()` is within 0.01 of `speed`. `test_zero_direction_stops` asserts velocity `== Vector2.ZERO`.
- [ ] **Step 2: Run** the two files. Expect FAIL.
- [ ] **Step 3: Define the Input Map** with a headless script (`godot --headless -s <script>`) that builds each action with `ProjectSettings.set_setting("input/<name>", {"deadzone": 0.5, "events": [...]})` and calls `ProjectSettings.save()`. Bindings per `docs/sprints/sprint-0-design.md` section 4. `cast` is left mouse button, the pause is Esc and Start, and `spell_slot_n` is keys 1–5 only (controller bindings deferred). Run it once and check `project.godot` contains the actions.
- [ ] **Step 4: Implement `MoveComponent`**, then `player.gd` (`class_name Player extends CharacterBody2D`): `_physics_process` reads `Input.get_vector("move_left", "move_right", "move_up", "move_down")` and calls the `MoveComponent`. `player.tscn` is a colored `ColorRect`/`Polygon2D` 12×12 placeholder, a `CollisionShape2D`, `Camera2D` with `position_smoothing_enabled = true`, and the two components. The arena is a 960×540 floor with four static wall bodies, and `Camera2D` limits are set to the arena rectangle. `main.tscn` instances the arena and player.
- [ ] **Step 5: Run** the tests. Expect PASS. Run the project headless for 60 frames and expect no errors.
- [ ] **Step 6: Commit** `feat: Input Map, MoveComponent, Player, arena`.

---

### Task 4: Enemy placeholder

**Files:**
- Create: `scripts/entities/enemy.gd`, `scenes/enemies/base_enemy.tscn`
- Modify: `scenes/main/main.tscn`
- Test: `tests/test_enemy.gd`

**Interfaces:**
- Consumes: `MoveComponent.apply`, `HealthComponent`, group `"player"`.
- Produces: `class_name Enemy extends CharacterBody2D` with `@export var speed_scale: float = 0.33` and `func direction_to_target() -> Vector2` (normalized direction to the first node in group `"player"`, or `Vector2.ZERO` if none).

- [ ] **Step 1: Write the failing tests:** `test_direction_points_at_player` (player stub in group at `(100, 0)`, enemy at origin gives `Vector2.RIGHT`), `test_no_player_returns_zero`.
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement.** `base_enemy.tscn` is a red 12×12 placeholder with a `MoveComponent` (speed 30) and a `HealthComponent`. It drifts toward the player and has no damage or combat. Instance one in `main.tscn`.
- [ ] **Step 4: Run** the tests. Expect PASS.
- [ ] **Step 5: Commit** `feat: enemy placeholder`.

---

### Task 5: SpellData and ScrollData stubs

**Files:**
- Create: `resources/spells/spell_data.gd`, `resources/scrolls/scroll_data.gd`
- Test: `tests/test_data_resources.gd`

**Interfaces:**
- Produces: `class_name SpellData extends Resource` with `enum Element { FIRE, THUNDER, LAND, SEA }`, `enum AreaType { LINE, CONE, AREA, MISSILE }`, `@export var id: StringName`, `@export var display_name: String`, `@export var elements: Array[Element] = []`, `@export var area: AreaType = AreaType.MISSILE`. `class_name ScrollData extends Resource` with `enum Category { BASE, AREA, BUFF }` and `@export var id: StringName`, `@export var display_name: String`, `@export var category: Category = Category.BASE`. Stubs only: no builder, crafting or mana logic.

- [ ] **Step 1: Write the failing tests:** `test_spell_data_defaults` (empty elements, area `MISSILE`), `test_scroll_data_defaults` (category `BASE`), `test_resources_round_trip` (save a `SpellData` to `user://` with `ResourceSaver`, reload it, and assert `id`, `elements` and `area` survive).
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement both stubs.**
- [ ] **Step 4: Run** and expect PASS.
- [ ] **Step 5: Commit** `feat: SpellData and ScrollData stubs`.

---

### Task 6: Touch controls (virtual joystick)

**Files:**
- Create: `scripts/ui/virtual_joystick.gd`, `scenes/ui/touch_controls.tscn`
- Modify: `scenes/main/main.tscn`
- Test: `tests/test_virtual_joystick.gd`

**Interfaces:**
- Consumes: the `move_*` actions from Task 3.
- Produces: `class_name VirtualJoystick extends Control` with `@export var radius: float = 40.0`, `var touch_index: int = -1`, `func handle_touch(index: int, pressed: bool, position: Vector2) -> void`, `func handle_drag(index: int, position: Vector2) -> void`, and `static func should_show() -> bool` (`DisplayServer.is_touchscreen_available()`). `_input` forwards `InputEventScreenTouch`/`InputEventScreenDrag` to those methods. The joystick centre is the control's own centre in screen space. Movement is applied with `Input.action_press("move_x", strength)`, and a release calls `Input.action_release` for all four.

- [ ] **Step 1: Write the failing tests** (each ends with `Input.action_release` cleanup): `test_drag_right_presses_move_right` (touch down at centre, drag to `centre + Vector2(radius, 0)`, assert `Input.get_vector(...)` is about `Vector2.RIGHT`), `test_drag_beyond_radius_is_clamped` (vector length at most 1.0), `test_release_clears_all_movement` (vector is `Vector2.ZERO`), `test_second_finger_ignored_while_first_held` (finger 1 held, finger 2 touch and drag leave the vector unchanged, and releasing finger 2 does not clear movement), `test_touch_controls_hidden_without_touchscreen` (`touch_controls.tscn` instance has `visible == VirtualJoystick.should_show()` after `_ready`).
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement.** `touch_controls.tscn` is a `CanvasLayer` with the joystick in the bottom-left (a ring and a knob drawn as `Control` shapes), hidden when `should_show()` is false. Instance it in `main.tscn`. Keep `emulate_mouse_from_touch` at its default, since it's harmless here.
- [ ] **Step 4: Run** and expect PASS. Then verify manually with `Emulate Touch From Mouse` enabled in the editor (the joystick appears and drives the wizard).
- [ ] **Step 5: Commit** `feat: virtual joystick touch controls`.

---

### Task 7: SceneSwitcher and Web export preset

**Files:**
- Create: `scripts/utilities/scene_switcher.gd`, `export_presets.cfg`
- Test: `tests/test_scene_switcher.gd`

**Interfaces:**
- Produces: `class_name SceneSwitcher extends RefCounted` with `static func change_to(tree: SceneTree, path: String) -> Error`. Returns `ERR_FILE_NOT_FOUND` without touching the current scene if `ResourceLoader.exists(path)` is false. Otherwise returns the result of `tree.change_scene_to_file(path)`.

- [ ] **Step 1: Write the failing tests:** `test_missing_path_returns_error_and_keeps_scene` (path `res://nope.tscn` gives `ERR_FILE_NOT_FOUND`, and `get_tree().current_scene` is unchanged), `test_empty_path_returns_error`.
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement `SceneSwitcher`.**
- [ ] **Step 4: Run** and expect PASS.
- [ ] **Step 5: Create the Web export preset** (`export_presets.cfg`, Web platform, threads off, output `export/web/index.html`). Confirm in the export dialog or the Godot docs that single-threaded is the 4.7 default, and record the result in `development-log.md`. Don't export. Templates aren't installed, so ask the user before installing them.
- [ ] **Step 6: Commit** `feat: SceneSwitcher and Web export preset`.

---

### Task 8: Final verification

- [ ] **Step 1: Run the full suite:** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Expect 0 failing tests.
- [ ] **Step 2: Run the project** headless for 60 frames, and via the `godot` MCP server (`run_project`, then `get_debug_output`). Expect no errors or warnings.
- [ ] **Step 3: Ask the user to run the manual checklist** from `docs/sprints/sprint-0-design.md` section 7 (movement, controller, camera limits, resize crispness, enemy visible, touch emulation).
- [ ] **Step 4: Tick the Sprint 0 boxes** in `sprint-development.md` that are done, update the memory notes, and commit `docs: Sprint 0 complete`.

## Self-review notes

- Spec coverage: resolution/filtering (Task 1), Input Map and controller (Task 3), touch (Task 6), camera/player/arena (Task 3), enemy (Task 4), components (Tasks 2–3), data stubs (Task 5), scene management and Web preset (Task 7), tests and log (Tasks 1, 8).
- The component reuse is covered, since the Player and Enemy both use `MoveComponent`, and `HealthComponent` is on both scenes.
