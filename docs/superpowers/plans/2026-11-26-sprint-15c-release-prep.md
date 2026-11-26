# Sprint 15c Release Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ScrollSmith Survivors ready for a free, public itch.io launch: an icon, a version, licence notices, a web page that says what it is, a rotate hint for upright phones, a checked and zipped upload built by GitHub Actions, and the page's words and pictures.

**Architecture:** Small, separate pieces: a `GameVersion` reader of one project setting, `CreditsText` and a generated `licences.txt`, an icon built by the art tool, an export-preset `head_include`, a `RotateHint` overlay with a pure decision function, an `ItchZipRules` checker run from the existing deploy workflow's build job, and documents and pictures under `docs/release-planning/`. No gameplay code changes.

**Tech Stack:** Godot 4.7.2 GDScript, GUT 9.7.1, GitHub Actions, the repo's art tool (`tools/art/art_builder.gd`), Pillow in the gitignored `venv` (only if the GIF needs it).

**Spec:** `docs/sprints/sprint-15c-design.md` (sections 1 to 5; section 5 holds the builder-check rulings).

## Global Constraints

- Run everything with the venv active (`source venv/bin/activate`); Python only as `venv/bin/python`, never bare `python3`, never `perl` for edits (use the Edit tool first). No installs into home or global folders; a Python package only into `venv/`. Give `rm` full literal paths, no variables or wildcards. Never run two Godot processes at once.
- Tests: full suite `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file adds `-gselect=<name>`. After adding or renaming a `class_name` script run `godot --headless --import`. A test that instantiates a run scene sets `save_path = ""` and the pick screen's `pause_tree = false` (`tests/helpers/main_helpers.gd` does both); a home-screen test sets `HomeScreen.scene_changer` and saves settings to a scratch path; nothing touches the real save or settings.
- The UI font is ASCII only (a test fails on any other character): write "Copyright", never the copyright sign.
- Every in-game sprite is drawn at one pixel size, never scaled or rotated; the icon file and promotional pictures are the only places scaled, and only by whole numbers with nearest-neighbour (never smoothed).
- No gameplay, balance, map, enemy or spell change. The project has no autoloads (`test_front_door_guards` fails if one appears). The home screen never names `main.tscn`.
- Licence: all rights reserved (the user's decision). Free to play. Notices are generated from or copied from files the projects ship, never written from memory.
- No secret, API key or email in any committed file. Nothing is uploaded to itch.io or made public by the builder; the user does the upload.
- A new sprint-notes heading goes in `docs/architecture/front-door.md` and in `tests/fixtures/claude_md_sections.txt`; `tests/test_doc_links.gd` fails on a docs mention that does not resolve.
- Accepted web limits: the iPhone browser toolbar and full-screen limits are not worked on. Pages stays live as the test build.

## Review Focus

- **Rotate card stuck or wrong:** the game left paused after turning landscape again, the card un-pausing a pause the player or a pick screen had made, the card on a desktop or a narrow desktop window, a hidden full-window control that still blocks touches in landscape.
- **Two versions:** `project.godot`, Credits, the home screen and the page document disagreeing, or a version string that is not `major.minor.patch`.
- **A zip itch.io would reject:** `index.html` not at the zip root (the export folder nested inside), more than 1000 files, a file over 200 MB, names differing only by case, `licences.txt` missing; a checker that passes on an empty or missing folder.
- **Licence text:** a missing or invented notice, `licences.txt` not in the zip, a non-ASCII character reaching the UI font, Credits overflowing its 20 lines.
- **Promotional pictures:** a frame that shows an overlay, a debug aid or the user's real save, a wrong size, a smoothed (non-integer or filtered) scale, a GIF over itch.io's size limit, or a scene that is not real play.

---

### Task 1: Version and the copyright line

**Files:**
- Create: `scripts/utilities/game_version.gd`, `LICENSE`, `tests/test_release_info.gd`
- Modify: `project.godot` (`config/version="1.0.0"` under `[application]`), `scripts/ui/credits_text.gd`, `scripts/ui/settings_screen.gd` (use the new function), `scripts/home/home_screen.gd` (a small version label), `tests/test_home_layout.gd`

**Interfaces:**
- Produces: `GameVersion.current() -> String` (reads `ProjectSettings.get_setting("application/config/version")`, `""` if unset); `GameVersion.is_valid(text: String) -> bool` (exactly `major.minor.patch`, digits only); `CreditsText.lines() -> Array[String]` (replaces the `LINES` constant); `HomeScreen.VERSION_RECT: Rect2` and `HomeScreen.version_label() -> Label`.

- [ ] **Step 1: Write the failing tests** in `tests/test_release_info.gd`: `test_the_project_has_a_valid_version` (`GameVersion.is_valid(GameVersion.current())`); `test_is_valid_accepts_and_rejects` (valid: "1.0.0", "0.12.3"; invalid: "", "1.0", "1.0.0.0", "v1.0.0", "1.0.x", "1.0.0-beta"); `test_credits_show_the_version_and_the_rights_line` (`CreditsText.lines()` contains "Version " + current and the exact line "Copyright 2026 JTexpo. All rights reserved."); `test_credits_fit_the_page_and_are_ascii` (at most 14 lines, every character code below 128); `test_credits_point_at_the_licences_file` (some line contains "licences.txt"); `test_credits_name_the_engine_licence` (some line contains "Godot" and "MIT"); `test_a_license_file_states_all_rights_reserved_and_names_gut` (reads `res://LICENSE`: contains "All rights reserved" and "addons/gut"). In `tests/test_home_layout.gd` add `test_the_version_label_shows_the_version_and_clears_everything` (label text contains the version, `VERSION_RECT` inside `Rect2(0, 0, 480, 270)` and not intersecting the banner, the five buttons, the message rect, or either corner button).
- [ ] **Step 2: Run them to see them fail** (`-gselect=test_release_info` and `-gselect=test_home_layout`). Expected: FAIL (`GameVersion` and `lines()` missing).
- [ ] **Step 3: Implement** the version setting, `GameVersion`, `CreditsText.lines()` (the existing lines plus "Version <current>", the rights line, "Made with Godot 4 (MIT licence) and GUT", "Full licences: licences.txt" and the thanks line; keep it at most 14 lines), the settings screen call, the `LICENSE` file ("Copyright 2026 JTexpo. All rights reserved." and a paragraph saying `addons/gut` is third-party code under its own MIT licence in `addons/gut/LICENSE.md`), and the home screen's small `Muted` label at the bottom right showing `v<version>` that clears the button row (pick the rectangle from the layout constants and let the test prove it).
- [ ] **Step 4: Run the two files and `test_settings_screen`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: version, copyright line and LICENSE`.

### Task 2: licences.txt

**Files:**
- Create: `scripts/release/licence_file.gd`, `tools/release/write_licences.gd`, `tests/test_licence_file.gd`
- Modify: `tests/test_export_filter.gd` (add `res://scripts/release/licence_file.gd` to `BUILD_TIME_ONLY`)

**Interfaces:**
- Produces: `LicenceFile.text() -> String` (the game's rights line, then `Engine.get_license_text()`, then every entry of `Engine.get_license_info()` as a heading and its text, then the engine's `Engine.get_copyright_info()` entries as component name, then each part's files, copyright lines and licence name); `tools/release/write_licences.gd` (a `SceneTree` script; `godot --headless -s tools/release/write_licences.gd -- <output file>` writes `LicenceFile.text()` there and exits non-zero if it cannot).

- [ ] **Step 1: Write the failing tests:** `test_it_starts_with_the_rights_line` ("Copyright 2026 JTexpo. All rights reserved." in the first 200 characters); `test_it_contains_the_engine_licence_text` (contains the first non-empty line of `Engine.get_license_text()`); `test_it_names_every_bundled_licence` (every key of `Engine.get_license_info()` appears); `test_it_names_every_bundled_component` (every `name` in `Engine.get_copyright_info()` appears); `test_it_is_not_tiny` (more than 10000 characters).
- [ ] **Step 2: Run** `-gselect=test_licence_file`. Expected: FAIL (class missing).
- [ ] **Step 3: Implement** `LicenceFile.text()` and the tool script (path from the arguments after `--`, `FileAccess.open` for writing, an error print and exit code 1 on failure).
- [ ] **Step 4: Run** `test_licence_file` and `test_export_filter`; then `godot --headless -s tools/release/write_licences.gd -- <scratchpad>/licences.txt` and look at the head of the file. Expected: PASS and a readable file.
- [ ] **Step 5: Commit** `feat: licences.txt from the engine's own notices`.

### Task 3: The icon and the web page head

**Files:**
- Create: `art/sprites/app_icon.sprite` (32 by 32, a wizard and a scroll, bright and simple, palette letters only, a 1 px transparent margin), `tests/test_release_assets.gd`
- Modify: `tools/art/art_builder.gd` and `scripts/art/art_builder.gd` (or a small new `scripts/art/icon_builder.gd`) so the tool also writes `assets/icon.png` (the sprite's first frame scaled by a whole number, 8, to 256 by 256, nearest-neighbour), `project.godot` (`config/icon="res://assets/icon.png"`), `export_presets.cfg` (`html/head_include`), the built assets under `assets/sprites/`

**Interfaces:**
- Produces: `assets/icon.png`; a `head_include` string with `<meta name="description" ...>`, `<meta name="theme-color" ...>`, `<meta property="og:title" ...>`, `<meta property="og:description" ...>`, `<meta property="og:type" content="website">`.

- [ ] **Step 1: Write the failing tests** in `tests/test_release_assets.gd`: `test_the_project_icon_is_a_square_png_that_exists` (`config/icon` resolves to a file, the loaded image is square and 256 by 256); `test_the_icon_equals_what_the_tool_builds` (like the other "committed equals built" tests); `test_the_icon_is_the_sprite_scaled_by_exactly_eight_with_no_new_colours` (every 8 by 8 block is one colour and the set of colours is a subset of the sprite's); `test_the_web_preset_uses_the_project_icon` (`html/export_icon` is true); `test_the_head_include_has_the_page_tags` (reads the Web preset: description, theme-color and the three og tags present, no `<title>`, no `og:url`, no `og:image`, no non-ASCII).
- [ ] **Step 2: Run** `-gselect=test_release_assets`. Expected: FAIL.
- [ ] **Step 3: Draw the icon source and build.** Write `app_icon.sprite` in the existing format (see `art/sprites/bush.sprite`), build a contact sheet with the scratchpad `sheet.gd` pattern and look at it at its real size and at 8x; iterate until it reads as a wizard with a scroll. Add the icon writing to the art tool, run `godot --headless --import`, `godot --headless -s tools/art/art_builder.gd`, `godot --headless --import`. Set `config/icon` and the `head_include` (a description of one or two sentences about the game, the game's loading background as theme colour).
- [ ] **Step 4: Run** `test_release_assets`, `test_art_assets`, `test_export_filter`. Expected: PASS. Look at the icon file.
- [ ] **Step 5: Commit** `feat: the icon and the web page head`.

### Task 4: The rotate hint

**Files:**
- Create: `scripts/ui/rotate_hint.gd`, `tests/test_rotate_hint.gd`
- Modify: `scenes/home/home.tscn`, `scenes/main/main.tscn` (one `RotateHint` child each), `tests/test_world_input.gd` only if it lists scenes to check

**Interfaces:**
- Produces: `RotateHint.should_show(window_size: Vector2, is_web: bool, has_touch: bool) -> bool` (true only when `is_web`, `has_touch` and the window is taller than wide); `RotateHint` (a `CanvasLayer`, layer above every screen, process mode Always): `is_showing() -> bool`, `update_for(window_size: Vector2, is_web: bool, has_touch: bool) -> void` (the node's `_process` calls it with the real values), which shows the card, and **pauses the tree only if it was not already paused**, remembering that it did; on hide it un-pauses only if it paused (through `GamePause.set_paused`). The card is `visible = false` (not merely transparent) whenever not showing, and its control ignores touches (`mouse_filter` IGNORE) so a hidden or stale card can never swallow a tap.

- [ ] **Step 1: Write the failing tests:** `test_should_show_only_for_a_touch_browser_in_portrait` (the table: portrait+web+touch true; landscape+web+touch false; square false; portrait desktop-web (no touch) false; portrait touch non-web false); `test_the_card_shows_and_pauses_in_portrait` (`update_for(Vector2(300, 600), true, true)`: showing, `get_tree().paused`); `test_turning_back_hides_it_and_resumes` (then `Vector2(600, 300)`: not showing, not paused, `GameTime` unfrozen); `test_it_does_not_unpause_what_it_did_not_pause` (pause with `GamePause.set_paused(tree, true)` first, show, hide: still paused); `test_it_does_not_pause_twice_then_unpause_wrongly` (two portrait updates, one landscape: not paused); `test_it_never_shows_on_a_desktop` (`update_for(Vector2(300, 600), false, false)`); `test_the_card_ignores_touches_and_is_hidden_when_not_showing`. Free the node and unpause in `after_each`.
- [ ] **Step 2: Run** `-gselect=test_rotate_hint`. Expected: FAIL.
- [ ] **Step 3: Implement** `RotateHint` with a themed card ("Turn your phone sideways to play", drawn in the existing theme, no new art), computing the real window size from `get_window().size`, `OS.has_feature("web")` and `DisplayServer.is_touchscreen_available()`; add one instance to `home.tscn` and to `main.tscn`.
- [ ] **Step 4: Run** `test_rotate_hint`, `test_world_input`, `test_front_door_guards`, `test_home_screen`. Expected: PASS. Then a real-window check: a scratch script that sets the window portrait and landscape and takes two screenshots through `update_for` (the real values are false on a desktop, so the check calls `update_for` directly) and confirms a touch on a home button works in landscape after the card has been shown and hidden.
- [ ] **Step 5: Commit** `feat: a rotate hint for phones held upright`.

### Task 5: The upload package

**Files:**
- Create: `scripts/release/itch_zip_rules.gd`, `tools/release/check_itch_zip.gd`, `tests/test_itch_zip_rules.gd`, `tests/test_release_workflow.gd`
- Modify: `.github/workflows/deploy-web.yml`, `tests/test_export_filter.gd` (`BUILD_TIME_ONLY` gains `res://scripts/release/itch_zip_rules.gd`)

**Interfaces:**
- Produces: `ItchZipRules.MAX_FILES := 1000`, `MAX_FILE_BYTES := 200 * 1024 * 1024`, `MAX_TOTAL_BYTES := 500 * 1024 * 1024`, `ItchZipRules.problems(files: Dictionary) -> Array[String]` (`files` maps a path relative to the zip root to its size in bytes; returns an empty array when clean); `tools/release/check_itch_zip.gd` (`godot --headless -s tools/release/check_itch_zip.gd -- <folder>` walks the folder, calls `problems`, prints `ITCH OK: <n> files, <mb> MB` or one `ITCH ERROR:` line per problem, exits non-zero on any problem or an unreadable folder).

- [ ] **Step 1: Write the failing tests.** `tests/test_itch_zip_rules.gd`: a clean set (`index.html`, `index.js`, `index.pck`, `index.wasm`, `licences.txt`) has no problems; `test_missing_index_html_is_reported`; `test_a_nested_index_html_is_not_the_root_one` (`web/index.html` only); `test_more_than_1000_files_is_reported` (1001 files) and exactly 1000 is fine; `test_a_file_over_200_mb_is_reported` and exactly 200 MB is fine; `test_a_total_over_500_mb_is_reported`; `test_names_that_differ_only_by_case_are_reported` (`Index.js` and `index.js`); `test_a_missing_licences_file_is_reported`; `test_an_empty_set_reports_the_missing_files`. `tests/test_release_workflow.gd` reads `.github/workflows/deploy-web.yml` and asserts: it triggers on `pull_request` as well as `push` to `main` and `workflow_dispatch`; the deploy job is skipped for pull requests (an `if` naming `pull_request`); the build job runs `tools/release/write_licences.gd` and `tools/release/check_itch_zip.gd` and a `zip` of the build folder from inside it (so `index.html` is at the zip's root, e.g. `cd build/web && zip`), and uploads it with `actions/upload-artifact` with `retention-days: 14`; the check runs before the zip; no line contains `secrets.` or `butler`.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement** `ItchZipRules`, the checker tool (a file's size from `FileAccess.get_file_as_bytes(...)` length or `FileAccess.open(...).get_length()`), and the workflow changes: the extra trigger, `if: github.event_name != 'pull_request'` on the deploy job, and after the export step: write `build/web/licences.txt`, run the checker, create `scrollsmith-survivors-<version>-itch.zip` (the version read from `project.godot` with `grep`) from inside `build/web`, and upload it as an artifact.
- [ ] **Step 4: Run** the two test files and `test_export_filter`; run the tools locally against a throwaway folder in the scratchpad (a clean folder passes, an empty folder and one with a nested `index.html` fail with non-zero exit). Expected: PASS.
- [ ] **Step 5: Commit** `feat: build, check and zip the itch.io upload in the workflow`.

### Task 6: The page document

**Files:**
- Create: `docs/release-planning/itchio-page.md`, `tests/test_itchio_page.gd`
- Modify: `docs/release-planning/itchio-notes.md` (the exact draft-upload steps and the confirmed itch.io limits, each marked verified or still to verify)

**Interfaces:**
- Consumes: `GameVersion.current()`, `ControlsText.lines()` and `ControlsText.ENTRIES`, `ControlsText.key_for`.
- Produces: `itchio-page.md` with these headings: Title, Tagline, Description, Controls, Features, Genre and tags, Made with, Licence, Embed and page settings, Version.

- [ ] **Step 1: Write the failing tests:** `test_the_page_document_has_every_section` (each heading above); `test_the_page_version_matches_the_game` (the Version section contains `GameVersion.current()`); `test_the_controls_table_lists_every_control` (for every entry of `ControlsText.ENTRIES` the label and its `key_for` text appear in the Controls section); `test_the_page_is_ascii_and_names_godot_and_the_rights_line`; `test_the_embed_size_is_a_whole_multiple_of_480_by_270`.
- [ ] **Step 2: Run** `-gselect=test_itchio_page`. Expected: FAIL (file missing).
- [ ] **Step 3: Write the document** in the user's voice from the game's real features (the README design document and the sprint log are the source): a tagline under 80 characters; a description of about 150 words (what it is, the spell crafting hook, three maps and bosses, achievements, touch and keyboard play, free); features as a short list; tags (for example roguelite, survivors-like, pixel-art, 2D, top-down, magic, singleplayer, touch, Godot); the embed size 960 by 540 with the mobile-friendly and fullscreen settings ticked (check these option names against itch.io's current documentation and note what was verified). Verify the itch.io limits and the draft-visibility steps from itch.io's own documentation (`WebFetch` of itch.io/docs/creators/html5 and the page-visibility help) and record the result in `itchio-notes.md`.
- [ ] **Step 4: Run** `test_itchio_page` and `test_doc_links`. Expected: PASS.
- [ ] **Step 5: Commit** `docs: the itch.io page text and the verified upload steps`.

### Task 7: Promotional pictures

**Files:**
- Create: `docs/release-planning/promo/cover.png`, `docs/release-planning/promo/shot_1.png` to `shot_5.png`, `docs/release-planning/promo/fight.gif`, `tests/test_promo_assets.gd`
- Modify: `docs/release-planning/itchio-page.md` (a list of the files with their sizes)

**Interfaces:**
- Produces: PNGs and one GIF built by throwaway scratchpad scripts (a real-window Godot script that stages real scenes with a throwaway `HOME`, throwaway save and settings, and writes frames; a `venv/bin/python` script that assembles the GIF and the cover, installing Pillow into `venv/` only if needed).

- [ ] **Step 1: Write the failing test** `tests/test_promo_assets.gd`: each file exists; `cover.png` is 630 by 500 (itch.io's recommendation, confirmed in Task 6 or the size noted there); each screenshot is a whole multiple of 480 by 270 (960 by 540 or 1440 by 810); `fight.gif` is under 3 MB (the limit noted in Task 6) and its first bytes are `GIF89a`; no image is larger than 3 MB.
- [ ] **Step 2: Run** `-gselect=test_promo_assets`. Expected: FAIL.
- [ ] **Step 3: Make the pictures.** Screenshots of real play at 960 by 540 or 1440 by 810 (window sized with `--resolution`, nearest scaling): the home screen, a fight with several spells and enemies, the Lectern with crafting open, a boss fight, the map select; the GIF: about 4 seconds of a fight at the real size, looped, under the size limit (a limited palette suits the art); the cover composed from the game's own sprites (the banner, the wizard, enemies, a spell) at whole-number scale on a flat or simple background. No overlay, no performance overlay, no cheat or debug aid, no real save. Look at every picture (read the PNGs) and the GIF's first, middle and last frames.
- [ ] **Step 4: Run** `test_promo_assets`. Expected: PASS. Show the pictures to the user as part of the final message; they judge the art.
- [ ] **Step 5: Commit** `docs: the itch.io screenshots, cover and fight GIF`.

### Task 8: Docs, the stale address and the close

**Files:**
- Modify: `CLAUDE.md` (the published address, the Project State line, the front-door index line adds Sprint 15c), `docs/architecture/front-door.md` (a new `## Release preparation (Sprint 15c)` section), `tests/fixtures/claude_md_sections.txt` (that heading), `docs/release-planning/release-checklist.md` (tick what is done; leave the user-only items open), `docs/release-planning/itchio-notes.md`, `docs/release-planning/future-roadmap.md`, `docs/release-planning/README.md` if it lists status, `development-log.md`, `sprint-development.md` (mark 15c built), `docs/sprints/sprint-15c-design.md` (status `Implemented`, with deviations)

- [ ] **Step 1: Fix the address:** search the repository (not `venv/` or `.git`) for `GODOT-SpellCraft-Survivors`; replace the published address in `CLAUDE.md` and elsewhere with `https://jtexpo.github.io/ScrollSmith-Survivors/` where it is the Pages address; leave the project-folder and repository-name mentions that are accurate history. Add a test line to `tests/test_release_assets.gd`: `test_the_docs_use_the_current_pages_address` (no `jtexpo.github.io/GODOT-SpellCraft-Survivors` anywhere in `CLAUDE.md` or `docs/`).
- [ ] **Step 2: Write the architecture section:** the version setting, the licence approach and why `licences.txt`, the icon pipeline and the one allowed scale, the `head_include`, the rotate hint and its pause rule, the package checker and its limits, the PR trigger, the page document and promo files, how to cut a release (bump the version, merge, run the workflow, download and check the zip, upload to a draft page, test, publish), the guards, and what the user does by hand.
- [ ] **Step 3: Measure what changed:** `godot --headless --quit-after 60` is clean; the soak test (`godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=12 --frames=600`) still passes; do a web export from a throwaway copy as `CLAUDE.md` describes, run `tools/release/check_itch_zip.gd` on it, and record the file count and total size; note the machine's power state (`pmset -g batt`).
- [ ] **Step 4: Log** in `development-log.md`: what was built, the checks, the rulings and what the user still does (hear the sound on the live site and in itch.io's frame, phone playtest through the manual checklist, create the page, draft upload, publish).
- [ ] **Step 5: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 6: Commit** `docs: record Sprint 15c`.
