# Spring cleaning 2: design and plan

**Status:** Approved by the user in conversation ("I approve this plan"). Branch `chore/spring-cleaning-2`, cut from `main` after the first spring cleaning (PR #39).

**Scope (the user's, items 1 to 5 of the follow-up list):** slim `CLAUDE.md`, move the sprint design documents, finish the test cleanup, remove the decoration system completely, and review the test-only accessors. Nothing else is touched: not the plugin, not `.superpowers/`, not historical plan content beyond link paths.

**Rules for the whole cleanup**
- The full suite is green before the first change (2472) and after every item; a smoke run (`godot --headless --quit-after 60`) shows only the known exit-leak warnings. One commit per item. One Godot process at a time. Commands run in the venv.
- A removal that a test pins is a removal of that test too, never a weakened test, and each is named in the plan.
- Facts are moved, not deleted: a rule that is still true stays somewhere a reader can find it.

## Items

1. **Move the 31 `sprint-*-design.md` files to `docs/sprints/`.** The repo root keeps `README.md`, `technical-design.md`, `sprint-development.md`, `development-log.md`, `CLAUDE.md` and `claude-prompt.txt`. Every mention of a moved file (about 50 files: `CLAUDE.md`, the development log, `sprint-development.md`, `docs/release-planning/README.md`, the old plans and the moved designs) gets the new path. A new test fails on a mention that does not resolve.
2. **Remove the decoration system.** `MapDecor`, `MapDecorLayer`, `MapData` and `MapZone` decoration fields (`decoration_count`, `decoration_seed`, `decoration_colors`, `decoration_size`, `decoration_styles`), the decoration drawing in `DrawChunk` and `WorldArt.decor_set`, the `Decor` node of `GameMap`, the four `decor_*` sprites and their built files, `test_map_decor` and the decoration cases elsewhere. The maps keep their floors, zones and walls (every decoration count was already 0). A new guard test fails if decoration returns by any of those names.
3. **Finish the test cleanup.** Move the four checks copied word for word in `test_forest_map_layout` and `test_maze_map_layout` into `tests/map_layout_checks.gd`; move the helpers copied in three or more files (`_damaged`, `_touch`, `_new_main`, `_scroll`, `_enemy`, `_frame_difference`, `_files`) into `tests/helpers/`. Both are pure moves. Then a mutation sample (about 40 deliberate breaks of production code) reports what the suite does not catch. **The report is the output: no test is deleted or added because of it without the user's approval.**
4. **Review the test-only accessors.** A report of every production member that only a test uses, with a decision for each (keep as a seam, make real, or remove) and a reason. **Nothing is removed until the user has seen the report.**
5. **Slim `CLAUDE.md`.** From 120 KB to under 25 KB: the always-needed rules stay (project state, commands, workflow, architecture, design rules, conventions, web build, touch gotchas) and each per-sprint section moves word for word into `docs/architecture/<topic>.md` (about ten topics), with an index of one line per topic in `CLAUDE.md`. A test fails if `CLAUDE.md` passes the size limit or a link in it does not resolve. Done after items 1 and 2 so the moved text is already correct.

## Approaches considered
- **CLAUDE.md:** (a) move the detail into topic docs (chosen by the user's approval, keeps the "why"), (b) cut it down to rules and lose history, (c) leave it. (b) loses the reasoning behind rules; (c) costs every session about 30k tokens.
- **Accessors:** remove on sight (rejected: some are the only seam into code that has no public path, and removing them would make it untestable) versus report first (chosen).

## Left to the builder
- The exact topic grouping of the 38 sections (proposed in the plan), and which duplicated helpers have identical enough behaviour to share.

## Non-goals and limits
- No gameplay, art or balance change. No test deleted by this cleanup except those that pin removed things. The mutation sample is evidence for a later decision, not a gate.
