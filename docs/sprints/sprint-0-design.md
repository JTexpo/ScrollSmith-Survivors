# Sprint 0 Design: Project Foundation

**Status:** Approved by the user, except the touch-scope addition below, which needs a quick confirmation. Nothing in this document has been built yet.

Scope comes from `sprint-development.md` (Sprint 0). Architecture follows `technical-design.md` and `CLAUDE.md`.

## 1. Goal and deliverable

A blank playable environment with a controllable placeholder wizard, a following camera, a placeholder enemy, and a working automated test run. It must leave a playable build and use no systems from later sprints.

## 2. Decisions

| Area | Decision |
|---|---|
| Engine | Godot 4.7.2 (Homebrew, `/opt/homebrew/bin/godot`). The version is pinned in CI later, not locally. |
| Language | Typed GDScript |
| Renderer | Compatibility (needed for reliable web export) |
| Internal resolution | 480×270 |
| Scaling | Stretch mode `viewport`, aspect `keep`, integer scale |
| Filtering | Nearest-neighbor default texture filter, 16px sprites, pixel snap on |
| Placeholders | Colored shapes (no art assets) |
| Tests | GUT, vendored and committed in `addons/gut/` (from the release zip), tests in `tests/test_*.gd` |
| Autoloads | None in Sprint 0 |
| Web | Web export preset checked in. No deploy workflow yet. |
| Touch | Virtual joystick for movement only, feeding the same Input Map actions. Touch aiming/casting is deferred and needs a design decision (see 4). |

## 3. Files to create

```
project.godot
export_presets.cfg                  # Web preset only
.gutconfig.json                     # GUT test directory and prefix
addons/gut/                         # vendored GUT release
scenes/main/main.tscn               # root scene: arena + player + enemy
scenes/player/player.tscn
scenes/enemies/base_enemy.tscn
scenes/world/test_arena.tscn        # flat floor, bounds
scripts/entities/player.gd          # input to velocity, delegates to components
scripts/entities/enemy.gd
scripts/components/move_component.gd
scripts/components/health_component.gd   # reusable for player and enemy
scripts/utilities/scene_switcher.gd      # basic scene management (see 5)
scenes/ui/touch_controls.tscn       # virtual joystick, shown only on touch devices
scripts/ui/virtual_joystick.gd
resources/spells/spell_data.gd           # SpellData stub
resources/scrolls/scroll_data.gd         # ScrollData stub
tests/test_input_map.gd
tests/test_health_component.gd
tests/test_data_resources.gd
development-log.md                  # first entry records these decisions
```

Only directories that hold files are created. `.gitignore` is updated for Godot (see section 8).

## 4. Input Map (logical actions only)

| Action | Keyboard / mouse | Controller |
|---|---|---|
| `move_up/down/left/right` | WASD | Left stick, D-pad |
| `interact` | E | Face button (A / Cross) |
| `pause` | Esc | Start |
| `spell_slot_1`..`spell_slot_5` | 1–5 | Bumpers and triggers/D-pad, final mapping deferred to Sprint 1 |
| `cast` | LMB | Right trigger |
| Aim | Mouse position | Right stick (aim vector helper) |

### Touch (phones and tablets)

- A left-thumb virtual joystick on `touch_controls.tscn` presses the same `move_*` actions through `Input.action_press` or `Input.parse_input_event`, so the Player needs no touch-specific code.
- It shows only when a touchscreen is present (`DisplayServer.is_touchscreen_available()`) and is hidden on desktop. Touch is also tested by emulating it in the editor (Project Settings → Input Devices → Pointing → Emulate Touch From Mouse).
- Sprint 0 does not handle aiming, casting, spell slot buttons or the pause button on touch. Those need a gameplay decision first (for example auto-aim at the nearest enemy, versus a second aim stick, versus tap-to-aim). Casting currently relies on mouse aim and LMB, so the choice affects established mechanics. I'll raise it as a question in Sprint 1 and won't decide it myself.
- 480×270 at 16:9 fits phone landscape. Portrait is not supported, and the layout assumes landscape.
- Web export caveats on phones: browsers start audio only after a user tap, and iOS Safari has tighter memory limits. Both are expected to be fine for this game but must be tested on real devices before release (Sprint 15).

Gameplay reads only actions, so keyboard, mouse and controller share one implementation. Movement uses `Input.get_vector` with the stick deadzone set in the Input Map. Spell slot, cast and aim actions are defined now but nothing consumes them until Sprint 1.

## 5. Structure

- **Entity/component structure:** an entity (a `CharacterBody2D` scene) owns small component nodes. `MoveComponent` applies a velocity and speed, and `HealthComponent` holds HP and emits `health_changed` and `died`. The Player and Enemy reuse both. The Player holds no spell, enemy or crafting logic.
- **Camera:** `Camera2D` as a child of the player, position smoothing on, limits set from the arena bounds.
- **Scene management:** `main.tscn` is the entry scene and `SceneSwitcher` is a small utility class that changes scenes through the `SceneTree`. It is not an autoload, because Sprint 0 has no global state. If a later sprint needs one, we will ask first.
- **Placeholder enemy:** a colored square that stands still or drifts toward the player. There is no combat, since damage belongs to Sprint 1.
- **Data stubs:** `SpellData` and `ScrollData` are `Resource` subclasses with a few `@export` fields only (for example `id`, `display_name`, element and area enums). There is no builder, crafting or mana logic. The point is to fix the "definitions are Resources" pattern. The runtime spell-instance concept comes later.

## 6. Web export notes

- Compatibility renderer, no threads, no GDExtension, no features that need `SharedArrayBuffer`.
- Godot 4.7 is expected to export single-threaded by default. I will confirm this in the export dialog and record the result in `development-log.md`.
- Export templates for 4.7.2 are not installed locally. Installing them (Editor → Manage Export Templates) is needed before the first web export. I will ask before doing it.
- The preset is checked in so CI can use it later. Nothing is exported or deployed in Sprint 0.

## 7. Testing and verification

- GUT runs headless, with the exact command recorded in `CLAUDE.md` once it works: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. I'll verify it on this machine before documenting it.
- Automated tests cover the Input Map actions existing, `HealthComponent` behavior (damage, death signal, no negative HP), and the data resources loading with defaults.
- `tests/test_touch_controls.gd`: the joystick drives the `move_*` actions, and is hidden when no touchscreen is present.
- Manual test (in the Godot editor, F5):
  1. Project starts with no errors or warnings in the Output panel.
  2. WASD moves the wizard, and a connected controller does the same.
  3. The camera follows and stays inside the arena limits.
  4. Resizing the window keeps pixels crisp and the 16:9 view intact.
  5. The enemy placeholder is visible.
  6. With touch emulation on, the joystick appears and moves the wizard.
- I can also run the project through the `godot` MCP server and read the debug output.

## 8. Repo and `.gitignore`

Add Godot entries: `.godot/`, `export/` and `build/` for web output, `export_credentials.cfg`, `*.translation`, `.import/` and the `.mono/` folders. `export_presets.cfg`, `project.godot`, `addons/gut/` and `.uid` files are committed. The Python-template entries already present stay as they are.

## 9. Risks

| Risk | Mitigation |
|---|---|
| GUT release may not support Godot 4.7 yet | Check the GUT release notes before vendoring. If unsupported, fall back to a minimal in-repo test runner and say so. |
| Web export differences found late | The Web preset exists from Sprint 0, and the settings stay web-safe. |
| Sprint 0 scope creep (spell logic, autoloads) | Stubs only. The Sprint 1 and later items stay out. |
| Controller mapping is untestable without hardware | Define the actions now and finalize bindings when a pad is available. |
| Touch can only be fully tested on a real device | Emulate touch in the editor now. Do a real-device check of the web build once a deploy exists. |
| Mobile performance in browsers (many enemies and projectiles) | Compatibility renderer, simple shapes. Revisit with profiling in Sprint 14, with pooling as the first optimization. |

## 10. Out of scope (later sprints)

Touch aiming/casting/buttons, combat, spells, casting, mana, crafting, Lectern, scroll inventory, XP and progression, save system, autoloads, real art and audio, deploy workflow.

## 11. Approval needed

1. Approve this plan and the file list.
2. ~~GUT download~~ Done: GUT 9.7.1 (the release notes for 9.7.0 cover Godot 4.7) is in `addons/gut/`. A real run is verified once `project.godot` exists.
