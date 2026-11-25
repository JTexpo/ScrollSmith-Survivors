# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project State

ScrollSmith Survivors (formerly Wizard Survivor; repo: GODOT-SpellCraft-Survivors until it is renamed) is an 8-bit, top-down survival roguelite in the style of Vampire Survivors, built with **Godot 4.x and GDScript** (2D). Sprints 0 to 16d are done (the sprint list is in `sprint-development.md`), which completes Sprint 16: three maps, each with its own enemies and boss. Sprint 15c (release preparation, including an itch.io page) is parked: see `docs/release-planning/`, which also holds the roadmap of what comes first. The design of each sprint is in `docs/sprints/` (`sprint-<id>-design.md`) and its implementation plan in `docs/superpowers/plans/`; decisions and measurements are in `development-log.md`; the rules each system follows, with their reasons, are in `docs/architecture/` (see "Where the detail lives" at the end of this file). The spring cleanings (2026-11-24) removed the debug cheat keys, the decoration system and unused art, and moved this file's per-sprint sections into `docs/architecture/`.

## Commands

Run everything with the venv active (`source venv/bin/activate`). Godot is the Homebrew `godot` (4.7.2). After adding or renaming a `class_name` script, run `godot --headless --import` once so the class cache updates.

- Run all tests (GUT 9.7.1, vendored in `addons/gut/`): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Run one test file: add `-gselect=test_health_component` (file name without `.gd`)
- Run one test: add `-gunit_test_name=test_name`
- Smoke-run the project: `godot --headless --quit-after 60`
- Run the game: `godot --path .` (or open `project.godot` in the editor and press F5)
- Art, theme, fonts and sounds are built from text sources by `godot --headless -s tools/art/art_builder.gd` (`art/sprites/*.sprite`, `art/palette.txt`, `art/fonts`, `audio/`); run `godot --headless --import` before it after a new `class_name` and again after it. Edit a source and forget the tool, and `test_art_assets` or `test_audio_assets` fails. Committed outputs are in `assets/`.
- Soak test: `godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=12 --frames=600`. Spell audit: `godot --headless -s scripts/dev/spell_audit.gd`. Stress-scene options beyond the ones below (`--obstacles`, `--map=<id>`, `--boss`, `--minutes=N`, `--fx`, `--sound`) are in `docs/architecture/polish-and-performance.md` and `maps-and-world.md`.
- Stress test (windowed): `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=10` prints one `STRESS` line with fps and frame times. Target is 60 fps at 300 enemies. Options: `--area=missile|cone|zone|line|wave`, `--drops`, `--copies=N` (Duplicate Area shots) and `--interval=SECONDS` (the default 0.05 s torture rate is far faster than any real spell).

The `godot` MCP server (`@coding-solo/godot-mcp`, launched via `npx`) is configured in `.mcp.json`. Node and `npx` live only in the gitignored `venv/` (installed with `nodeenv`), so start Claude Code from a shell where you ran `source venv/bin/activate`, or the server fails to connect. Godot itself (4.7.2) comes from Homebrew.

Established in Sprint 0: 480×270 internal resolution with integer scaling, Compatibility renderer, a checked-in single-threaded Web export preset, published to GitHub Pages by `.github/workflows/deploy-web.yml` (see Web build below), GUT for tests (`tests/test_*.gd`), and a `TouchJoystick` for touch movement (Godot 4.7 has a native `VirtualJoystick`, so don't reuse that name).

## Required Workflow

The design docs are the source of truth. Read them before changing anything:

- `README.md`: game design document (GDD). Mechanics, progression tables, enemy and equipment design.
- `technical-design.md`: architecture, proposed directory layout, coding standards.
- `sprint-development.md`: Sprints 0–16 plus the MVP definition. Find the current sprint here.
- `docs/architecture/`: how each system works and why, one doc per subsystem (index at the end of this file). **Read the one for the system you are about to change.**
- `claude-prompt.txt`: the user's per-task prompt template.

Per `claude-prompt.txt`, for every task:

1. Inspect the project, then propose the plan before writing code. List files to create or modify, dependencies, and architectural risks. **Wait for approval.**
2. Implement only the requested task. Follow existing conventions and avoid unrelated refactoring.
3. **Don't build features from future sprints.** Each sprint must leave a playable build.
4. Test the work. List the files changed and give manual test steps to run in Godot.
5. **Don't change game design decisions without asking.** Ask before changes that affect established mechanics.

## Architecture (big picture)

The core idea is that spells are **assembled at runtime from data**, never hardcoded per combination. A spell is a **Base** (one or more elements: Fire/Thunder/Land/Sea), exactly one **Area** (Line/Cone/Area/Missile), and optional **Buffs**.

Layering, per `technical-design.md`:

- **Scenes** are physical objects and UI (Player, Enemy, Projectile, Lectern, HUD, crafting menu).
- **Scripts** hold logic and systems.
- **Custom `Resource`s** hold all data definitions: `SpellData`, scroll, `EnemyData`, equipment and potion definitions.
- **Autoloads** are only for truly global state, and the project has no autoloads: static classes and nodes in the run scene do that job, and `test_front_door_guards` and `test_audio_guards` fail if one appears.

Systems that must stay separate and reusable:

- **Spell Definition vs. Spell Instance.** `SpellData` is static configuration. A spell instance is the equipped runtime object with its own mana pool. Two instances of the same definition must never share mana.
- **Spell Builder.** It computes final damage, max mana, mana cost, cast interval, area dimensions, and buff effects. It must be independent of the crafting UI and the Lectern scene.
- **Crafting System.** It validates a combination, consumes scrolls, and creates or equips the spell. Invalid combinations must not consume scrolls. The Lectern is only the interaction point.
- **Damage System.** Elemental math is centralized in one place. Spells and enemies must not compute their own. Multipliers are configurable, not hardcoded. Several Base types combine by **best match**: a hit uses whichever of the spell's elements does best against the enemy (strong beats neutral beats weak, the first wins a tie), computed only in `DamageSystem.resolve`.
- **Area behaviors.** Each Area is an interchangeable implementation behind one casting interface. Modifiers like Duplicate Area must not require editing individual Areas.
- **Progression.** Run progression (XP, levels, slot unlocks) is separate from permanent progression (Gold, equipment, saves).
- **Equipment.** Effects go through one central modifier system, not direct edits to player stats. Hats and Hoods differ only visually.
- **Player, UI, and inventory.** The Player delegates to systems and holds no spell, enemy, or crafting logic. UI reads from systems and never mutates gameplay data directly. The scroll inventory is independent of the crafting UI.

## Established Design Rules (do not change without asking)

- **Mana never regenerates naturally.** Each spell has its own pool. A depleted spell can't be cast until something explicitly restores mana (potions or future effects). Spells must not cast with insufficient mana.
- Crafting needs at least one Base and exactly one Area. Buffs are optional. Every buff and every increase in range or area raises mana cost. Hybrid (multi-Base) spells drain mana faster.
- Elements: Fire > Land > Thunder > Sea > Fire. Each element is strong against the one it beats and weak against the one that beats it. Enemies without an affinity take normal damage.
- XP feeds a permanent 20-level wizard track (reward table in the README). Gold buys equipment between runs. Spell slots go from 1 to 5.
- **User rulings, kept here because they are easy to undo by accident** (the reasons are in `docs/architecture/`): every player spell passes over obstacles (only movement and enemy projectiles are blocked); an element never changes a stat (archetype and element are picked independently); potions last one run and are sold only by the in-run merchant, and scrolls are never sold or saved; the run continues after a boss, and every boss attack has a warning a player at base speed can always escape; starting-spell buffs are rolled or picked again at every run start and never saved; every sprite is drawn at one pixel size, never scaled or rotated; green means go and red means stop in the interface; everything but layout and art is the same on every map.
- Inputs go through the Godot Input Map using logical actions. Keyboard, mouse, and controller share one gameplay implementation (WASD, E interact, 1–5 spell slots, mouse aim, LMB cast, Esc pause, M mute).

## Conventions

- Naming: PascalCase classes. snake_case variables, functions, and signals. UPPER_SNAKE_CASE constants.
- Use typed GDScript where practical. One responsibility per script. Prefer composition over inheritance. Avoid circular dependencies. Use signals between independent systems.
- Gameplay and balance values belong in Resources or `@export` properties, not scattered through scripts.
- Directories from the proposed layout (`scenes/`, `scripts/{autoload,systems,utilities}/`, `resources/`, `assets/`, `tests/`) are created only as their systems are built.
- **Writing tests.** A test that instantiates a run scene (`main.tscn`, the forest or maze scene) sets `save_path = ""` (so the real save is never touched) and the pick screen's `pause_tree = false` before `add_child` (`tests/helpers/main_helpers.gd` does both). A test of the home screen's Play sets `HomeScreen.scene_changer`; one that really changes scene breaks every later test. Hand-written `.tscn` files need `node_paths=PackedStringArray("prop")` on the `[node]` line for any Node-typed export set by NodePath, or it stays null silently. Never run two Godot processes at once (false failures). Shared test code lives in `tests/helpers/` and `tests/map_layout_checks.gd`.
- **New sprint notes** go in the matching `docs/architecture/<topic>.md` under a `## <title> (Sprint <id>)` heading, and that heading is added to `tests/fixtures/claude_md_sections.txt`; a new topic doc is also listed in the index below and in `TOPICS` of `tests/test_claude_md.gd`.
- Don't optimize prematurely. Profile first. Object pooling for projectiles is the likely first optimization.
- Record significant architectural decisions and measurements in `development-log.md`.

## Web build and GitHub Pages

- `.github/workflows/deploy-web.yml` builds the `Web` export preset with Godot 4.7.2 and publishes it with GitHub Pages. It runs when `main` changes and from the Actions tab ("Run workflow"). It downloads the Godot editor and the export templates for the version pinned in the workflow's `GODOT_RELEASE`, checks them against Godot's published SHA-512 sums, and caches the editor and the two web templates it needs. **When the project moves to a new Godot version, change `GODOT_VERSION` and `GODOT_RELEASE` there.**
- One-time setup (a repository setting, not code): Settings > Pages > Build and deployment > Source: **GitHub Actions**. The game is then at `https://jtexpo.github.io/GODOT-SpellCraft-Survivors/` (the last part changes if the repository is renamed).
- The preset is single-threaded (`variant/thread_support=false`, no extensions), because GitHub Pages cannot send the cross-origin isolation headers a threaded web build needs. PWA mode is off on purpose, so a phone never serves a stale cached build while testing. `exclude_filter` keeps GUT, the tests, the docs, `.github`, `venv` and `export` out of the package.
- Web builds need the `gl_compatibility` renderer, which the project already uses. The exported package is small (about 225 KB) and the engine file (`index.wasm`) is about 39 MB uncompressed.
- The `export/` folder is gitignored. To check an export on a machine **without installing templates into Godot's own folder**, make a throwaway copy of the project (for example with `rsync`, leaving out `.git`, `venv`, `.godot` and `export`), unpack only `templates/web_nothreads_release.zip` and `web_nothreads_debug.zip` from the `.tpz` into a scratch folder, and in the copy's `export_presets.cfg` set `custom_template/release` and `custom_template/debug` to those zip paths. Then run `godot --headless --path <copy> --import` and `godot --headless --path <copy> --export-release "Web" <copy>/export/web/index.html`, and serve that folder with `python -m http.server` on 127.0.0.1. Delete the copy afterwards.
- There are no debug keys any more, so touch testing means playing for drops.

## Touch and input gotchas

- A `ColorRect` (like any `Control`) stops mouse and touch input by default (`mouse_filter` STOP), and a visible one swallows the event before `_unhandled_input` sees it. World decorations (the arena floor, the player and enemy bodies, Lectern parts, projectile bodies) must set `mouse_filter = 2` (IGNORE). `tests/test_world_input.gd` fails if a world scene gets a Control that stops touches. A phone's "tap to restart" was broken for exactly this reason: the arena floor covered the whole screen.
- Anything that must react to a tap anywhere (the death screen) listens in `_input`, which runs before any control, not in `_unhandled_input`. Widgets that handle their own touches (`SpellSlotWidget`, the Inventory and Interact buttons, `TouchJoystick`) already do.
- In headless GUT runs pointer events (mouse and touch) reach `_input` but never `_unhandled_input`, while keys reach both. So a headless test cannot show a swallowed tap. Check touch behaviour with a throwaway real-window script that sends `Input.parse_input_event` touches in window coordinates (multiply the game position by `root.get_final_transform()`), as was done for the touch bridge and for this bug.

## Where the detail lives

Each sprint's decisions, with their reasons, were moved word for word out of this file into topic docs (this file is loaded into every session, so it keeps only the rules that always apply). **Read the topic doc before changing the system it covers.** The design of every sprint is in `docs/sprints/`, the decisions and measurements in `development-log.md`.

- [Combat and spells](docs/architecture/combat-and-spells.md): The component-based combat, the spell data and loadout, the five Areas and the elemental rules. (Sprint 1, Sprint 2, Sprint 3, Sprint 4)
- [Scrolls and crafting](docs/architecture/scrolls-and-crafting.md): Scroll data, drops and pickups, the Lectern and the crafting rules, and buffs. (Sprint 5, Sprint 6, Sprint 7)
- [Progression and economy](docs/architecture/progression-and-economy.md): XP, levels and saving, Gold and equipment, and potions. (Sprint 8, Sprint 9, Sprint 10)
- [Enemies and bosses](docs/architecture/enemies-and-bosses.md): Archetypes and elements, difficulty, the brains and the boss state machine. (Sprint 11)
- [Maps and the world](docs/architecture/maps-and-world.md): Maps as data, obstacles and navigation, the maze and regions, points of interest, the world pass and the map select. (Sprint 12a, Sprint 12b, Sprint 12c, Sprint 12d, Sprint 14a, Sprint 16a)
- [The three maps' content](docs/architecture/map-content.md): The forest and the Tempest Dragon, the ruins' art refresh, the maze and the Dire Minotaur. (Sprint 16b, Sprint 16c, Sprint 16d)
- [Art](docs/architecture/art.md): The art pipeline, the world art and the spell and equipment art. (Sprint 13a, Sprint 13b, Sprint 13c)
- [Interface and audio](docs/architecture/interface-and-audio.md): The theme, fonts and screens, and the sound and music system. (Sprint 13d, Sprint 13e)
- [Polish, balance and performance](docs/architecture/polish-and-performance.md): Impact weight and effects, the balance pass, the performance overlay, the soak test and test coverage. (Sprint 13f, Sprint 14b, Sprint 14c)
- [The front door](docs/architecture/front-door.md): The home screen, settings, pause, the tutorial and the run statistics. (Sprint 15a, Sprint 15b)
