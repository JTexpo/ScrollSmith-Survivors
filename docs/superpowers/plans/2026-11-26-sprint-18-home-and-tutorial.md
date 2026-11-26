# Sprint 18: A Livelier Home Screen and Tutorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A bright, welcoming home screen (a title banner on top, a wide animated stage in the middle where the wizard fights enemies, the five menu buttons in one row at the bottom, and a new menu tune), and four tutorial pages that each show a small animated vignette, all built on one small scripted `Stage` system.

**Architecture:** A scene is a `StageScript` resource (actors, timed beats, scenery) played by a `Stage` control over sprites the game already has (`BodyView`, `EffectSprite`); five scripts (the home fight and four vignettes). The home screen gets its own `SoundBoard` for a new `music_menu` tune and UI sounds. Reduce motion and the particles switch are respected; the stage stops when hidden.

**Tech Stack:** Godot 4.7 GDScript, GUT, the art tool (`tools/art/art_builder.gd`), the audio pipeline.

**Spec:** `docs/sprints/sprint-18-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first; scratch files in the scratchpad directory, never `/tmp`; `rm` takes full literal paths. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (2569 before this sprint); one file: add `-gselect=<name>`; after a `class_name` change run `godot --headless --import`; after a `.sprite`, `.sfx` or `.tune` change run `godot --headless -s tools/art/art_builder.gd` then `--import`. **Never run two Godot processes at once**; run the full suite alone, in the background for `task-done`.
- Test rules (from `CLAUDE.md`): tests never touch the real save or settings (`HomeScreen.save_path` and `settings_path` point at a scratch folder, `scene_changer` is set so no test really changes scene); a test that instantiates a run scene sets `save_path = ""` and the pick screen's `pause_tree = false`; shared helpers live in `tests/helpers/`; hand-written `.tscn` need `node_paths=PackedStringArray("prop")` for Node-typed exports.
- Rules that stay: every sprite is drawn at one pixel size (never scaled or rotated at run time; the banner lettering is baked at its real size); art is bright, simple, cartoon; the interface uses green for go and red for stop; main buttons are at least `UiKit.ACTION_SIZE` (72 by 28); the home screen never names `main.tscn`; gameplay is untouched; `test_audio_guards` and `test_fx_guards` stay meaningful (only the home script, `Main` and the audio code name the board; nothing outside `scripts/fx` names the burst layer, shake, flash, warning or indicator).
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Stage leaks and growth:** orbs or sparks left behind at a loop wrap, effects exceeding the cap (`EffectSprite.MAX_LIVE` is shared and global), actors not reset at the wrap, the stage running while hidden behind a full screen or after the home screen is freed.
- **Music:** the menu tune playing twice or after leaving the menu, starting before the web unlock, ignoring the Music slider or the saved mute, the board missing on the home scene, the run's board changing behaviour.
- **Layout:** banner, stage, button row and the two corner buttons overlapping or leaving the 480 by 270 screen; buttons under 72 by 28; touches swallowed by the stage (it must ignore touches) or bridged twice.
- **Tutorial:** vignette not restarting on Next and Back, still running after close, text overlapping the stage frame, the pinned rules ("Mana never comes back", potions last one run) lost.
- **Reduce motion and particles:** motion or sparks still playing when the player turned them off. Reduce motion is a preset, not a stored flag, so the stage uses `FxSettings.is_reduced()` (shake 0, flash 0, hurt flash off), the design's settled definition.
- **Mute:** the M key on the home screen changing the shared bus without saving, so a run starts with the bus and its board disagreeing.

---

### Task 1: The stage engine

**Files:**
- Create: `resources/stage/stage_actor.gd`, `stage_beat.gd`, `stage_scenery.gd`, `stage_script.gd`, `scripts/stage/stage.gd`, `tests/test_stage_script.gd`, `tests/test_stage.gd`
- Modify: `scripts/fx/fx_settings.gd` (add `is_reduced()`), `tests/test_fx_settings.gd`
- Reference: `scripts/entities/body_view.gd` (`set_look`, `play`, `set_facing`, `has_art`, `shadow_enabled`, `animation_done`), `scripts/entities/player_look.gd` (`apply(body, profile, catalog)`), `scripts/spells/effect_sprite.gd` (`spawn(parent, sprite_name, at, delay, fade_time)`, `MAX_LIVE`), `scripts/ui/tutorial_screen.gd` (`_picture`)

**Interfaces:**
- Produces:
  - `StageActor` (Resource): `id: StringName`, `sprite: StringName`, `variant: StringName = &"base"`, `start: Vector2`, `facing: float = 1.0` (+1 right, -1 left), `shadow: bool = true`, `wizard: bool = false` (draws the equipped wizard look on `player`), `visible_at_start: bool = true`, `animation: StringName = &"idle"` (played at the start of each loop).
  - `StageBeat` (Resource): `enum Action { WALK_TO, PLAY, FACE, SHOW, HIDE, SHOOT, BURST }`; `time: float` (seconds into the loop), `actor: StringName`, `action: Action`, `to: Vector2` (WALK_TO destination, SHOOT target, BURST position), `duration: float` (WALK_TO and SHOOT travel seconds), `animation: StringName` (PLAY; also the animation WALK_TO plays while moving, default `move`; after arriving the actor returns to the actor's `animation`), `effect: StringName` (SHOOT: the orb sprite such as `fx_fire_orb_16`; BURST: the spark sprite such as `fx_fire_burst`), `facing: float` (FACE). WALK_TO also faces the actor toward its destination.
  - `StageScenery` (Resource): `sprite: StringName`, `variant: StringName = &"base"`, `position: Vector2`.
  - `StageScript` (Resource): `size: Vector2i`, `loop_seconds: float`, `still_time: float`, `sky_color: Color`, `ground_style: StringName` (a `tile_<style>` floor name, empty for none), `ground_top: float` (y where the ground starts), `scenery: Array[StageScenery]`, `actors: Array[StageActor]`, `beats: Array[StageBeat]`; `func problems() -> PackedStringArray` (a loop of 0 seconds or less, `still_time` outside the loop, an actor with no id or a duplicate id, a beat naming no actor (BURST needs none), a beat before 0 or after the loop, beats not in time order, a missing sprite for an actor, scenery or an effect, a SHOOT or BURST with no effect, a WALK_TO or SHOOT with a duration of 0 or less).
  - `Stage` (a `Control`, `mouse_filter` IGNORE, `clip_contents = true`): `func play(script: StageScript, profile: PlayerProfile = null, catalog: EquipmentCatalog = null) -> void` (builds sky, ground, scenery and actors, starts at 0, honours reduced motion: when `FxSettings.is_reduced()` it builds the `still_time` frame and does not process); `func stop() -> void` (no processing, no effects); `func advance(delta: float) -> void` (what `_process` calls; tests call it by hand); `func seek(time: float) -> void` (resets, then advances to `time`, deterministic for actors and orbs); `func elapsed() -> float`; `func actor(id: StringName) -> BodyView`; `func orb_count() -> int`; `func effect_count() -> int`; `func is_playing() -> bool`; `const MAX_ORBS := 8`, `const MAX_EFFECTS := 24`. At the wrap (`elapsed >= loop_seconds`) every actor is reset (position, facing, animation, visibility) and every orb and spark made by this stage is freed. Sparks use `EffectSprite.spawn` and are skipped when `FxSettings.particles` is false or the cap is reached; orbs are `BodyView`s on the effect's `fly` animation moved by the beat. `FxSettings.is_reduced() -> bool` is true when `shake_scale` and `flash_scale` are both 0 and `hurt_feedback` is false (exactly what the Reduce motion preset sets: the preset is not a stored flag, so this combination is the definition; no new setting is added, and raising any of the three brings the animation back).

- [ ] **Step 1: Write the failing tests.** `test_stage_script`: `test_a_good_script_has_no_problems` (a small throwaway script with real sprites `player`, `enemy_standard`, `fx_fire_orb_16`, `fx_fire_burst`), and one test per fault in `problems()`. `test_stage` (every test builds a `Stage` in the test tree with a throwaway script, no scene change): `test_an_actor_starts_where_the_script_puts_it`, `test_walk_to_moves_an_actor_linearly_and_faces_it_that_way` (position at half the duration is the midpoint, facing follows the direction), `test_a_play_beat_changes_the_animation_and_a_walker_returns_to_its_own_after_arriving`, `test_show_and_hide_toggle_an_actor`, `test_shoot_launches_an_orb_that_arrives_at_its_target_and_is_gone_after` (orb_count 1 mid-flight, 0 after arrival), `test_burst_spawns_a_spark_unless_particles_are_off`, `test_the_wrap_resets_every_actor_and_frees_every_orb_and_spark` (after `loop_seconds` the actor positions equal the start and the counts are 0), `test_many_loops_do_not_grow_the_node_count` (advance through 20 loops and compare `get_child_count()` and the orphan count to loop 1), `test_orbs_and_sparks_never_exceed_their_caps`, `test_seek_is_deterministic` (seek twice to the same time gives the same positions and animations), `test_stop_halts_processing_and_clears_effects`, `test_reduced_motion_builds_the_still_frame_and_never_processes` (set the Reduce motion preset, `FxSettings.reset()` in `after_each`), `test_a_missing_sprite_falls_back_without_crashing` (an actor with `sprite = &"nothing_like_this"`), `test_the_wizard_actor_wears_the_equipped_look` (a profile with an equipped robe: the body has the layers `PlayerLook` adds, an empty profile shows the starter), `test_the_stage_ignores_touches` (mouse filter IGNORE on the stage and its children). `test_fx_settings`: `test_is_reduced_is_true_after_the_reduce_motion_preset_and_false_after_reset`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** the four resources, `Stage` and `FxSettings.is_reduced()`. Run `godot --headless --import`.
- [ ] **Step 3: Mutation check** (ledger the results): remove the wrap reset of orbs, remove the `MAX_EFFECTS` cap, and make `play` ignore reduced motion; each must fail a named test; restore each file with `git checkout -- <exact path>`.
- [ ] **Step 4: Run** the three test files and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the scripted stage engine`.

---

### Task 2: Stage art (banner, clouds, scenery)

**Files:**
- Create: `art/sprites/banner_title.sprite`, `art/sprites/cloud_small.sprite`, `art/sprites/cloud_large.sprite`, `art/sprites/bush.sprite` (more scenery sprites only if the scripts in Task 3 need them), their built outputs in `assets/sprites/` (committed), `tests/test_stage_art.gd`
- Reference: `art/sprites/post_tree.sprite`, `tile_grass.sprite`, `icon_star.sprite`, `docs/architecture/art.md` (pipeline, margin, palette, tile and 16-colour rules), `art/palette.txt` (63 of 64 colours used: reuse letters, add none unless truly needed), the UI font `art/fonts/ui.pixelfont` for letter shapes

**Interfaces:**
- Produces: `banner_title` (the title "ScrollSmith" in large bright lettering with "SURVIVORS" on a ribbon or scroll beneath, **at most 256 by 46 px**, a 4-frame `shimmer` animation of a travelling sparkle, `anim shimmer 0 3 6 loop`), `cloud_small` (about 28 by 12) and `cloud_large` (about 48 by 18) (one frame each, white and pale blue), `bush` (about 16 by 12, green). Fixed palette colours only, a 1 px transparent margin on every frame, bright, simple, cartoon, baked at their real size.

- [ ] **Step 1: Write the failing test** `test_stage_art`: every sprite above resolves through `SpriteLibrary.find(name, &"base")`, `banner_title` is at most 256 by 46 and has 4 frames with the `shimmer` animation, every frame of `banner_title` differs from the next by at least 4 pixels, the clouds and the bush are at most 48 by 18, and `banner_title` shows at least three distinct colours. Run. Expected: FAIL.
- [ ] **Step 2: Compose the sprites** with a scratch Python generator in the scratchpad (the banner lettering made by enlarging the UI font's glyphs a whole number of times in the generator, then adding a 1 px dark outline, a bright fill with a lighter top and a darker bottom, and the ribbon; a sparkle that moves across in the four frames), write the `.sprite` sources, run the art tool and `--import`.
- [ ] **Step 3: Look at them.** With the scratchpad contact-sheet script (`sheet.gd`, headless) save the sheets at 4x on the sky colour `#6fd3ff`: read the images, compare the four banner frames, redraw anything that reads badly (the title must be legible at 1x on a phone, bright and welcoming), rebuild and look again. Record what the images showed in the ledger.
- [ ] **Step 4: Run** `test_stage_art`, `test_art_assets`, `test_animation_frames` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the stage art (banner, clouds, scenery)`.

---

### Task 3: The five stage scripts

**Files:**
- Create: `resources/stage/home_fight.tres`, `resources/stage/tutorial_survive.tres`, `tutorial_cast.tres`, `tutorial_scrolls.tres`, `tutorial_potions.tres`, `tests/test_stage_scripts.gd`
- Reference: `art/sprites/` names (`player` with animations `idle`, `move`, `cast`; the plain enemies `enemy_standard`, `enemy_chaser`, `enemy_swarmer` with `move` and `death`; `enemy_forest_swarmer`; orbs `fx_fire_orb_12|16|24` with `fly`; `fx_fire_burst`; `pickup_xp`, `pickup_gold`, `scroll_base`, `lectern`, `poi_merchant`, `icon_potion`, `reticle`, `post_tree`, `tile_grass`; the clouds and bush from Task 2), `tests/helpers/`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: five valid `StageScript`s. **`home_fight`** (480 by 160, about 12 to 16 s loop, sky colour `#6fd3ff`, the `tile_grass` ground below a horizon, trees and bushes framing the edges, two drifting clouds that leave the screen before the wrap): the wizard (`wizard = true`) stands left and casts `fx_fire_orb_16` at a goblin, a wolf and rats that walk in from the right in different element colourways; each hit plays `death` and a `fx_fire_burst`; a tougher one takes two hits; a short calm pause, then the loop. **Vignettes** (each about 320 by 88, 6 to 10 s): `tutorial_survive` (the wizard walks, picks up `pickup_xp` and `pickup_gold` (hidden on arrival with a spark) while a goblin walks in), `tutorial_cast` (the `reticle` moves, the wizard casts, the target pops), `tutorial_scrolls` (an enemy pops, a `scroll_base` appears where it fell, the wizard walks to it, picks it up and walks to the `lectern`, a spark over it), `tutorial_potions` (the wizard drinks: an `icon_potion` shows above him, a heal spark, a `poi_merchant` and a `pickup_gold` beside him).

- [ ] **Step 1: Write the failing test** `test_stage_scripts`: `test_every_script_loads_and_has_no_problems` (each of the five `.tres`), `test_the_home_fight_has_a_wizard_and_enemies_that_are_shot_and_pop` (an actor with `wizard`, at least three enemy actors, at least three SHOOT beats, at least three `death` PLAY beats and three BURST beats, a loop of 10 to 18 s), `test_each_vignette_matches_its_page` (`survive`: a WALK_TO for the wizard and a HIDE of a pickup; `cast`: a SHOOT and a reticle actor; `scrolls`: a scroll actor SHOWn after an enemy's `death` and a lectern actor; `potions`: an `icon_potion` actor SHOWn and a merchant actor), `test_each_vignette_loops_cleanly` (play it on a `Stage`, advance through two loops, the actor positions and counts equal loop 1), `test_nothing_is_left_behind_at_the_wrap` (orb and spark counts are 0 just after the wrap), `test_a_still_frame_exists_inside_each_loop` (`still_time` is inside the loop and `seek(still_time)` shows at least one actor off its start position or an orb in flight, so the Reduce motion frame is not an empty field). Run. Expected: FAIL (the files do not exist).
- [ ] **Step 2: Author the five scripts** with a scratch Python generator that writes the `.tres` (actors, beats and scenery as sub-resources), keeping the timings in the generator so they are easy to retune; the committed `.tres` are the source.
- [ ] **Step 3: Look at them.** A scratchpad GDScript plays each script on a `Stage`, takes screenshots at four moments of its loop on a real window (scratch `HOME`) or headless frame dumps, and saves a sheet: read the images and redraw the choreography where it reads badly (enemies must not overlap the wizard, orbs must visibly reach their target, the loop must not jump at the wrap). Record what the images showed in the ledger.
- [ ] **Step 4: Run** `test_stage_scripts`, `test_stage`, `test_stage_script` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the home fight and the four tutorial vignettes`.

---

### Task 4: The home layout and the stage on the home screen

**Files:**
- Modify: `scripts/home/home_screen.gd`, `scenes/home/home.tscn` (if the stage or banner are scene nodes), `tests/test_home_screen.gd`
- Create: `tests/test_home_layout.gd`
- Reference: `docs/sprints/sprint-18-design.md` (layout), the current `_build()` in `home_screen.gd`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: `HomeScreen` with the layout: sky backdrop, the banner (a `BodyView` on `banner_title`, `shimmer`, centred at the top, at most 256 by 46 px so it clears the two 100-px corner buttons by 4 px, y about 6 to 52), the stage (`Stage` node, full width, 160 px tall, y about 58 to 218, playing `home_fight` with the loaded profile and the equipment catalog for the wizard's look), and a row of five buttons at the bottom (`Play` green first, `Shop`, `Tutorial`, `Settings`, `New game` red last; each about 88 by 28 with a 4 px gap, centred, y about 232 to 260), plus the existing Full screen and Achievements buttons. The small "Starting over." message label keeps working and sits in the gap between the stage and the buttons (y about 220 to 230). New constants replace `BUTTON_SIZE`, `FIRST_BUTTON_Y` and `BUTTON_STEP`. `HomeScreen.stage() -> Stage` for tests. The stage plays while no full screen is open (Shop, Settings, Tutorial, map select, Achievements and the confirm dialog) and stops when one opens; it resumes when it closes (the existing `closed` handlers and `_focus_play` give the place to hook). The stage and banner ignore touches.

- [ ] **Step 1: Write the failing tests.** `test_home_layout`: `test_the_five_buttons_are_one_row_in_order_and_big_enough` (same y within 1 px, increasing x in the order Play, Shop, Tutorial, Settings, New game, each at least 72 by 28), `test_everything_fits_inside_the_screen_and_nothing_overlaps` (rects of the banner, the stage, the row buttons and the two corner buttons inside `Rect2(0, 0, 480, 270)`, no two intersect except the banner and the stage may touch edges), `test_the_stage_plays_the_home_fight_on_open` (`stage().is_playing()`, the script's id), `test_the_stage_stops_while_a_full_screen_is_open_and_resumes_after` (open and close the Shop, Settings, Tutorial, Achievements and the confirm dialog), `test_reduce_motion_shows_the_still_frame` (preset on, the stage is not processing), `test_the_wizard_wears_the_saved_equipment` (a scratch save with an equipped robe), `test_the_stage_and_banner_do_not_take_touches`, `test_opening_and_freeing_the_home_screen_repeatedly_leaves_no_orphans` (ten times). Update `tests/test_home_screen.gd`: the old column test (`test_it_builds_its_buttons_in_order_and_the_tutorial_is_live`) becomes the row (x increasing, not y), keeping the checks that the Tutorial is enabled and Play is enabled. Run. Expected: FAIL.
- [ ] **Step 2: Implement** the new `_build()`, the stage hook and `stage()`. Keep `handle_input` (the touch bridge) and every existing screen hook exactly as they are.
- [ ] **Step 3: Real-window check** (scratch script, windowed, scratch `HOME` and save): take screenshots of the home screen at three moments of the loop and read them; send a touch and a left click (window coordinates) to each of the five buttons and the two corner buttons and confirm each acts exactly once (the Play button opens the map select; use `scene_changer` so nothing is loaded); confirm the stage keeps animating and that the screen is not overlapped. Record in the ledger.
- [ ] **Step 4: Run** `test_home_layout`, `test_home_screen`, `test_front_door_guards`, `test_ui_look` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the livelier home screen`.

---

### Task 5: Menu music

**Files:**
- Create: `audio/music/music_menu.tune`, `tests/test_menu_music.gd`
- Modify: `scripts/audio/sound_id.gd`, `resources/audio/sound_catalog.tres`, `scripts/audio/sound_board.gd`, `scenes/home/home.tscn` (a `SoundBoard` node), `scripts/home/home_screen.gd`, `tests/test_audio_guards.gd` (allowed list), `tests/test_audio_assets.gd` (`MAX_BYTES` 4 MB), `tests/test_sound_catalog.gd` (`DESIGN_IDS` gains `music_menu`)
- Reference: `audio/music/music_run.tune` (format, about 22 s), `scripts/audio/tune_source.gd`, `SoundBoard` (`_music` players keyed `run` and `boss`, `start_music`, `_start_loop`, `_state_wants`, `music_target_db`, the unlock in `_input`, `starts_unlocked`, `inherits_page_unlock`, `bind` and `_on_node_added`/`_wire_button`), `scripts/main/main.gd` (how the saved mute is applied to the board at run start)

**Interfaces:**
- Produces: `SoundId.MUSIC_MENU = &"music_menu"`; a `SoundData` entry `music_menu` (`music = true`, `pausable = false`, `max_voices = 1`, `volume_db` about 3 dB below the run tune's); `music_menu.tune` (a new bright major-key loop, 16 to 20 s, `loop`, pulse melody, quiet pulse arpeggio, triangle bass, light noise hat, every channel the same number of cells; **not judged by ear**); `SoundBoard`: a third music key `menu` (a player on the Music bus like the others), `func start_menu_music() -> void` (unlocked like `start_music`, state `menu`, starts the tune once), `func bind_home(home: Control, profile: PlayerProfile) -> void` (wires every `Button` under `home` and every button added later (click, back, hover) exactly as `bind` does, applies `profile.muted` **both ways** (`set_muted(profile.muted)`), connects the board's mute change so the M key on the home screen **saves** the new value in the progress save through the home screen's existing save path (as `Main._on_mute_changed` does in a run), and starts the menu music when allowed: on the desktop at once, on the web at the first press), `music_state()` returns `&"menu"` while it plays. Only the home script and `Main` name the board; the board is freed with the home screen so nothing plays after leaving.

- [ ] **Step 1: Write the failing tests.** `test_menu_music`: `test_the_menu_board_starts_the_tune_once_when_unlocked` (unlock, `start_menu_music()` twice: `music_starts()` 1, state `menu`), `test_it_waits_for_the_first_press_on_the_web_path` (the `starts_unlocked(true, ...)` false: nothing plays until a press reaches `_input`, then it plays), `test_it_uses_the_music_bus_and_follows_the_music_slider` (the bus volume changes with `GameSettings.music_volume` through `SettingsEvents`), `test_the_saved_mute_silences_it_and_a_saved_unmuted_state_unmutes_the_bus` (`profile.muted` true and false, with the bus left muted by an earlier test), `test_pressing_m_on_the_home_screen_saves_the_mute_in_the_scratch_save_and_a_run_then_starts_in_the_same_state`, `test_the_home_scene_has_a_board_that_plays_the_menu_tune_and_the_buttons_click` (a `HomeScreen` instance: its board's state, and `requested` records `ui_click` for a button press), `test_freeing_the_home_screen_stops_the_music` (after `queue_free` and a frame the player is not playing, no node of the board remains), `test_the_run_board_never_plays_the_menu_tune` (a `Main` run: its board's state is never `menu`), `test_no_other_script_names_the_board` (the `test_audio_guards` list now allows only `scripts/home/home_screen.gd` besides the audio code, `Main`, the sound test and the stress script). Add `&"music_menu"` to `DESIGN_IDS` and set `MAX_BYTES` to 4 MB first, so those fail until the files exist. Run. Expected: FAIL.
- [ ] **Step 2: Write the tune** (12 to 16 bars at about 120 bpm in a bright major key, a different melody and key from `music_run`, a welcoming rise and a gentle turn back to the start so it loops without a jump), the catalog entry, the `SoundId` constant, the board changes and the home node and script lines. Run the art tool, `--import`; `test_audio_assets` (stale, silent, clipping, the loop chunk) and `test_sound_catalog` must pass.
- [ ] **Step 3: Check the size.** Ledger the new WAV's bytes and the committed total; confirm it is under 4 MB. Note in the ledger that the tune could not be judged by ear.
- [ ] **Step 4: Run** the new tests, `test_sound_board`, `test_sound_routes`, `test_audio_guards`, `test_audio_assets`, `test_sound_catalog`, `test_home_screen` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: menu music`.

---

### Task 6: Tutorial vignettes

**Files:**
- Modify: `scripts/ui/tutorial_page.gd`, `scripts/ui/tutorial_pages.gd`, `scripts/ui/tutorial_screen.gd`, `tests/test_tutorial_screen.gd`, `tests/test_tutorial_pages.gd` (find with `grep -ln TutorialPages tests`)
- Reference: the current `_show_page`, `_picture`, `PICTURE_Y`, `LINES_Y` and the buttons' positions in `tutorial_screen.gd`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: `TutorialPage.vignette: StageScript` (null keeps the row of sprites) and `TutorialPage.make(title, lines, sprites, vignette = null)`; `TutorialPages.pages()` gives each of the four pages its vignette (`tutorial_survive`, `tutorial_cast`, `tutorial_scrolls`, `tutorial_potions`) with the text unchanged; `TutorialScreen` replaces the picture row with a `Stage` in a framed area (about 320 by 88, centred, near the top under the title; the lines move down to fit; the buttons and counter stay where they are) that plays the page's vignette from its start every time the page shows (Next, Back and open), stops on close, and keeps the old sprite row for a page with no vignette; `TutorialScreen.stage() -> Stage` for tests; `picture_count()` keeps working (0 when a vignette shows).

- [ ] **Step 1: Write the failing tests.** In `test_tutorial_screen`: `test_each_page_shows_its_vignette_and_restarts_it` (open: stage playing the first script from 0; Next: the second script from 0; Back: the first again from 0), `test_closing_stops_the_stage`, `test_a_page_without_a_vignette_keeps_the_sprite_row` (a throwaway `TutorialPage`), `test_the_stage_frame_the_lines_and_the_buttons_do_not_overlap_and_fit_the_screen`, `test_the_stage_takes_no_touches`, and update `test_the_page_shows_its_title_lines_and_pictures` so a vignette page has no pictures and a vignette stage. In the pages test: `test_every_page_has_a_valid_vignette`, `test_the_pinned_rules_are_still_on_the_pages` (the "Mana never comes back" and the one-run potions wording, as before). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the page field, the page data and the screen changes.
- [ ] **Step 3: Real-window check** (scratch script, windowed, scratch `HOME`): open the tutorial from the home screen by a left click, screenshot each of the four pages at two moments of their vignette and read them (the vignette matches its text, nothing overlaps); send a touch and a click to Next, Back and Close and confirm each acts once and the vignette restarts on a page change. Record in the ledger.
- [ ] **Step 4: Run** the tutorial tests, `test_ui_look`, `test_world_input` and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: animated tutorial vignettes`.

---

### Task 7: Docs, measurements and the close

**Files:**
- Modify: `docs/architecture/front-door.md` (a new `## A livelier home screen and tutorial (Sprint 18)` section), `tests/fixtures/claude_md_sections.txt` (add that heading), `docs/architecture/interface-and-audio.md` (a line on the menu board and tune), `CLAUDE.md` (the index line for front-door lists Sprint 18; the Project State line), `development-log.md`, `sprint-development.md` (mark Sprint 18 built), `docs/release-planning/future-roadmap.md` (item 3 built), `docs/sprints/sprint-18-design.md` (status `Implemented`, with deviations)

- [ ] **Step 1: Write the section** in the architecture doc: the stage system (the five resources, `Stage`, how a script is authored and tuned, the caps, the wrap reset, reduced motion through `FxSettings.is_reduced()`), the home layout and the stop-while-hidden rule, the menu board and tune (and the browser unlock), the tutorial vignettes, how to add a scene or change a vignette, the guards, the art, the 4 MB audio cap and why.
- [ ] **Step 2: Measure.** A scratchpad script instantiates the home screen, advances the stage for 600 frames and prints the average cost of `Stage.advance`; run the soak test (`godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=12 --frames=600`) and a stress run noting the machine's power state (`pmset -g batt`); record both in the log. Log the tune's size and that it was not judged by ear.
- [ ] **Step 3: Log** in `development-log.md` what was built, the measurements, the real-window findings and the rulings.
- [ ] **Step 4: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 5: Commit** `docs: record Sprint 18`.
