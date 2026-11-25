# Spring Cleaning 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the sprint design docs, remove the decoration system, finish the test cleanup, report on the test-only accessors, and slim `CLAUDE.md` to under 25 KB by moving each sprint section into topic docs.

**Architecture:** Documents and dead code only; no gameplay, art or balance change. Order matters: links first (Task 1), dead code next (Task 2), tests (Task 3) and the accessor report (Task 4), and the `CLAUDE.md` split last (Task 5) so it moves final text.

**Tech Stack:** Godot 4.7 GDScript, GUT, venv Python for scripted edits and checks.

**Spec:** `docs/spring-cleaning-2-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first; scratch files in the scratchpad directory, never `/tmp`; `rm` takes full literal paths, no variables or wildcards; delete only what a list names. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (2472 before); one file: `-gselect=<name>`; after a `class_name` change run `godot --headless --import`; after a `.sprite` change run `godot --headless -s tools/art/art_builder.gd` then `--import`. **Never run two Godot processes at once**; run the full suite alone, in the background for `task-done`.
- No gameplay, art or balance change. Moves are word for word. A test pinning a removed thing is removed with it, never weakened.
- The root keeps `README.md`, `technical-design.md`, `sprint-development.md`, `development-log.md`, `CLAUDE.md`, `claude-prompt.txt`.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Dead links:** a moved file mentioned by a path form the script missed (a relative `../sprint-9-design.md`, a mention in a `.tres` or script comment, a backtick-less mention).
- **Facts lost in the split:** a `CLAUDE.md` rule that was only stated inside a section and is no longer discoverable; the split must be a pure move (a test compares the sections' text).
- **Decoration leftovers:** an old saved `.tres` still carrying `decoration_*` fields (Godot ignores unknown fields, but the guard must see none), the `Decor` node name in tests or `DrawChunk` callers, `decor_` names in tools or the palette.
- **Helper moves that change behaviour:** a shared helper that two files used with slightly different bodies.
- **Mutation report honesty:** a mutation that a test catches only by accident (a crash) counted as caught.

---

### Task 1: Move the sprint design docs to `docs/sprints/`

**Files:**
- Move: the 31 `sprint-*-design.md` in the root (`git mv`), to `docs/sprints/`
- Modify (paths only): every file that mentions one (about 50: `CLAUDE.md`, `development-log.md`, `sprint-development.md`, `docs/release-planning/README.md`, `docs/superpowers/plans/*.md`, and the moved designs themselves)
- Create: `tests/test_doc_links.gd`

**Interfaces:**
- Produces: `docs/sprints/sprint-<id>-design.md`; every mention of `sprint-<id>-design.md` in a `.md` file is the path `docs/sprints/sprint-<id>-design.md` (inside a moved design, a mention of a sibling is the bare file name relative to its folder, which also resolves).

- [ ] **Step 1: Write the failing test** `test_doc_links`: `test_every_mentioned_sprint_design_exists` (walk every `.md` under the repo root, `docs/` and `docs/**` excluding `.superpowers`, `venv`, `.godot`, `addons`; for each regex match of `(docs/sprints/)?sprint-[0-9a-z]+-design\.md`, assert the file exists at `docs/sprints/<name>` and the mention is the full `docs/sprints/` path unless the mentioning file is itself inside `docs/sprints/`); `test_the_root_keeps_only_the_core_documents` (the `.md` and `.txt` files in the root are exactly the six listed in Global Constraints). Run. Expected: FAIL.
- [ ] **Step 2: Move and rewrite.** Record in the ledger the list of files that mention a design (a venv Python scan). `git mv` each design with literal paths from a generated list file. With a venv Python script replace every bare `sprint-<id>-design.md` mention that is not already prefixed by `docs/sprints/` with the prefixed form, in every mentioning file except the moved designs, which keep bare names. Print the count of replacements per file and read it.
- [ ] **Step 3: Run** `test_doc_links`, then the whole suite and a smoke run (`task-done`). Expected: PASS.
- [ ] **Step 4: Commit** `chore: move the sprint design documents to docs/sprints`.

---

### Task 2: Remove the decoration system

**Files:**
- Delete: `scripts/world/map_decor.gd` (+ `.uid`), `scripts/world/map_decor_layer.gd` (+ `.uid`), `tests/test_map_decor.gd` (+ `.uid`), `art/sprites/decor_{cracks,flowers,mushrooms,pebbles}.sprite` and every `assets/sprites/decor_*` file (png, `.png.import`, `.tres`, silhouettes do not exist)
- Modify: `scripts/world/game_map.gd` (the `Decor` node, `MapDecorLayer`, `MapDecor` use, comments), `scripts/world/draw_chunk.gd` (the decoration art cache, `art_decor_count`, the decoration drawing; obstacles stay), `scripts/world/world_art.gd` (`decor_set` and comments), `resources/maps/map_data.gd` and `map_zone.gd` (the decoration fields), `resources/maps/first_map.tres`, `forest_map.tres`, `maze_map.tres` (their `decoration_*` lines), `tests/test_game_map.gd`, `tests/test_first_map_regions.gd`, `tests/test_world_art.gd` (`test_every_decoration_style_in_first_map_has_art`), `tests/test_map_data.gd`, whichever other test `grep` finds, `CLAUDE.md`
- Create: `tests/test_no_decoration.gd`

**Interfaces:**
- Produces: `MapData` and `MapZone` with no property starting `decoration_`; `GameMap` with no `Decor` child; `DrawChunk` that draws obstacles only (find its callers with `grep` first and keep `ObstacleLayer` working); no `decor_*` sprite source.

- [ ] **Step 1: Write the failing guard** `test_no_decoration`: `test_map_data_and_zone_have_no_decoration_fields` (no `get_property_list()` name begins `decoration_` on `MapData.new()` and `MapZone.new()`); `test_the_game_map_has_no_decor_layer` (instantiate `scenes/world/game_map.tscn` with the first map: no child named `Decor`); `test_no_decor_sprite_sources_or_scripts_remain` (no `art/sprites/decor_*.sprite`, no `scripts/world/map_decor*.gd`); `test_the_map_files_name_no_decoration` (the three map `.tres` texts contain no `decoration_`). Run. Expected: FAIL.
- [ ] **Step 2: Prove what uses what.** `grep -rn "MapDecor\|decoration_\|decor_set\|art_decor_count\|decor_" scripts scenes resources tests tools art` and record the lines in the ledger; read every hit so no caller is missed (including `tools/` and any stress scene).
- [ ] **Step 3: Remove** per the Files list. In `DrawChunk` keep the obstacle drawing and its two-pass behaviour unchanged (tests `test_world_art` and `test_game_map` cover it). Delete the decoration cases of the older tests (named when found, each recorded in the ledger as pinning removed behaviour). Run `godot --headless --import`, the art tool (no remaining `decor_` output; `git status` shows only deletions among `assets/`).
- [ ] **Step 4: Run** `test_no_decoration`, `test_game_map`, `test_world_art`, `test_map_data`, `test_first_map_regions`, `test_art_assets`; then a real-window screenshot of the ruins and the forest near the start (scratchpad script, scratch `HOME`) confirming floors and walls are unchanged. Expected: PASS.
- [ ] **Step 5: Docs.** `CLAUDE.md`: remove or correct every sentence about decorations, `MapDecor`, `decoration_*`, `decor_*` sprites, evenly spread scatter, the 13d "no scattered decoration" note (state that the decoration system was removed in this cleanup).
- [ ] **Step 6: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 7: Commit** `chore: remove the decoration system`.

---

### Task 3: Finish the test cleanup and the mutation sample

**Files:**
- Modify: `tests/map_layout_checks.gd`, `tests/test_forest_map_layout.gd`, `tests/test_maze_map_layout.gd`, and the files that hold the copied helpers (found by scanning)
- Create: `tests/helpers/` (shared helper scripts, no `class_name`, preloaded like `map_layout_checks.gd`), `docs/test-mutation-report.md`

**Interfaces:**
- Produces: shared checks `no_gap_narrower_than_two_cells(map)`, `every_free_cell_reachable_from_start(map)`, `same_points_of_interest_as_the_ruins(map)`, `spacing_rules(map)` on `map_layout_checks.gd` taking the test (`GutTest`) as the first argument for assertions, each called by one thin test per map; shared helpers under `tests/helpers/` for `_damaged`, `_touch`, `_new_main`, `_scroll`, `_enemy`, `_frame_difference`, `_files`, kept with their exact current behaviour.

- [ ] **Step 1: Record the baseline.** Test count and failing count of the full suite from the ledger (2472 minus Task 2's removals); the scan that lists each duplicated helper with every copy's file and body.
- [ ] **Step 2: Diff the copies.** For each helper, show whether every copy's body is identical after whitespace; a helper whose copies differ stays where it is and is ledgered with the reason (do not unify behaviour).
- [ ] **Step 3: Move.** The four map checks into `map_layout_checks.gd` (the two map tests keep one test per check, now one line each); each identical helper into `tests/helpers/<name>.gd` as a static function (arguments added only where a copy used the test instance), the old copies deleted, each caller changed to the shared one. The number of tests must not change in this step; run the whole suite and compare to the baseline count.
- [ ] **Step 4: Mutation sample.** Ledger a list of about 40 mutations first (file, line, change, the test file expected to catch it), spread across spell building and casting, damage and elements, crafting validation, buffs, the spawner, the boss state machine and chained charges, saving, the shop and potions. For each: apply it, run only the expected test file plus `-gselect` of one neighbour, record caught or not and the first failing test name, then restore the file with `git checkout -- <exact path>` and check `git status` is clean. A mutation that a test catches only by crashing (a script error, not an assertion) is recorded as "caught by crash". Never run two Godot processes at once.
- [ ] **Step 5: Write `docs/test-mutation-report.md`:** the table (mutation, caught by, how), the survivors with a one-line reading of why no test caught each, and a recommendation. No test is added or deleted because of it.
- [ ] **Step 6: Whole suite and smoke run** (`task-done`). Expected: PASS, the same test count as Step 3 (the helper moves change no count).
- [ ] **Step 7: Commit** `chore: share duplicated test code and report a mutation sample`.

---

### Task 4: Report on the test-only accessors

**Files:**
- Create: `docs/test-accessor-report.md`

- [ ] **Step 1: Find them.** A venv Python scan lists every `func` in `scripts/` whose name or doc comment says it is for tests (`for tests`, `for a test`, `test seam`, `for the tests`) plus every public function in `scripts/` that no file under `scripts/`, `scenes/`, `tools/` or `resources/` calls but a file under `tests/` does. Keep the raw list in the ledger.
- [ ] **Step 2: Decide each** (read the function and its test callers): **seam** (the only way to observe or inject something; keep), **make real** (the test shows a behaviour that deserves a documented public method), **remove** (a test can reach the fact through public behaviour, or the test is the only caller of dead code), with one line of reason.
- [ ] **Step 3: Write the report** `docs/test-accessor-report.md`: counts per decision, the table, and for each "remove" the test that would change. **Change no code.** The user chooses what to remove.
- [ ] **Step 4: Commit** `docs: report on the test-only accessors`.

---

### Task 5: Slim `CLAUDE.md` into topic docs

**Files:**
- Modify: `CLAUDE.md`
- Create: `docs/architecture/` with `combat-and-spells.md`, `scrolls-and-crafting.md`, `progression-and-economy.md`, `enemies-and-bosses.md`, `maps-and-world.md`, `map-content.md`, `art.md`, `interface-and-audio.md`, `polish-and-performance.md`, `front-door.md`; `tests/test_claude_md.gd`

**Interfaces:**
- Produces: `CLAUDE.md` under 25,000 bytes holding Project State, Commands, Required Workflow, Architecture (big picture), Established Design Rules, Conventions, Web build and GitHub Pages, Touch and input gotchas, and a section "Where the detail lives" with one line per topic doc (name, link, the sprints it covers). Each per-sprint section moves word for word, in order, under its original `##` heading as a `##` heading in its topic doc: combat-and-spells = Sprints 1 to 4; scrolls-and-crafting = 5 to 7; progression-and-economy = 8 to 10; enemies-and-bosses = 11; maps-and-world = 12a to 12d, 14a and 16a; map-content = 16b to 16d; art = 13a to 13c; interface-and-audio = 13d and 13e; polish-and-performance = 13f, 14b and 14c; front-door = 15a and 15b.

- [ ] **Step 1: Write the failing test** `test_claude_md`: `test_claude_md_stays_under_25_kb`; `test_every_link_in_claude_md_resolves` (each `docs/...md` path mentioned exists); `test_every_per_sprint_section_is_kept_word_for_word` (read every `## ` heading ending in `(Sprint ...)` that the ten topic docs hold, assert each topic doc has at least one section, and assert the set of headings across the topic docs equals the 30 headings recorded in `tests/fixtures/claude_md_sections.txt`, a list written in Step 2 from the pre-split file); `test_core_sections_stay_in_claude_md` (the eight core headings are present). Run. Expected: FAIL.
- [ ] **Step 2: Split with a venv Python script**, no hand copying: split the old file at every `\n## `, record the headings and a SHA-256 of each per-sprint section's text to the ledger and the headings to `tests/fixtures/claude_md_sections.txt`; write each topic doc as a title, a one-line summary and its sections in order; write the new `CLAUDE.md` from the core sections plus the index section. Then verify with a second script that the concatenated topic-doc section texts hash-match the recorded ones (a pure move).
- [ ] **Step 3: Read the new `CLAUDE.md` end to end.** It must still say how to run tests, the workflow, the design rules and the conventions; fix any core sentence that pointed at a moved sentence ("see Sprint 12b below") to name the topic doc. Update the Project State line to mention the cleanup and the topic docs.
- [ ] **Step 4: Run** `test_claude_md`, `test_doc_links`, then the whole suite and a smoke run (`task-done`). Expected: PASS.
- [ ] **Step 5: Commit** `docs: slim CLAUDE.md and move the sprint detail into docs/architecture`.

---

### Task 6: Record the cleanup and finish

**Files:**
- Modify: `development-log.md`, `docs/spring-cleaning-2-design.md` (status "Implemented")

- [ ] **Step 1: Log.** A "Spring cleaning 2" entry in `development-log.md`: what moved and where, the decoration removal (files, sprites and bytes deleted), the helper and test moves with the unchanged count, the mutation sample result in two lines and the accessor report's counts, `CLAUDE.md` before and after bytes, and what is left for the user (the accessor removals, any mutation survivors).
- [ ] **Step 2: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 3: Commit** `docs: record spring cleaning 2`.
