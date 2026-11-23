# Sprint 13e: Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the game its sound: about 40 chirpy chiptune sound effects and a bouncy run loop, a faster boss loop and two jingles, all synthesised by the art tool from text recipes into committed WAV files, played by one signal-driven `SoundBoard` with voice caps, pause and web-unlock handling, and a mute key and HUD button.

**Architecture:** `SfxSource` and `TuneSource` parse text; `AudioBuilder` (pure) renders them to samples and a WAV file; the one art tool writes `assets/audio/*.wav`, and stale and orphan tests guard them. `SoundCatalog` (data) says how each sound behaves (volume, caps, priority, wobble); `VoiceLimiter` (pure) decides whether a play request is let through; `SoundBoard` (a node in `main.tscn`, not an autoload) owns a fixed player pool, the buses, the music and the mute state, and listens to signals that already exist (a few get a one-line signal added). A static `EnemyAttackEvents` emitter carries enemy shots and blast zones, which have no node to connect to. A sound-test scene lets the user audition everything by ear.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, the 13a to 13d art tool (`tools/art/art_builder.gd`).

**Spec:** `sprint-13e-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`, never Perl, and never a bare `python3 -` that waits on stdin). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file; GUT matches ONE file name per run). Run `godot --headless --import` after adding or renaming a `class_name` script and BEFORE and AFTER running the art tool (`godot --headless -s tools/art/art_builder.gd`). On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, zsh does not word-split unquoted variables, and `rm` takes the full literal path (delete only what you created). Wrap test and tool runs in `timeout` so a stuck process cannot hang a call.
- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`.
- **Chirpy, whimsical, bouncy chiptune** (user): square and pulse waves, triangle bass, short noise hits, quick pitch slides and arpeggios, major keys, staccato notes. Nothing harsh, nothing long, nothing grim. Sounds are short (most under 0.4 s); a hit or a death must not be tiring when heard hundreds of times.
- **I cannot hear.** Design recipes from chiptune idioms and the numbers in this plan, verify them with tests (length, range, determinism, no clipping, not silent), and say plainly in every report that the sound itself was not judged by ear. The user auditions through the sound-test scene (Task 4).
- Audio files: 22,050 Hz, mono, 16 bit WAV, built by the tool, committed. Total committed audio at most **3 MB** (a test pins it). Replacing a sound is overwriting its WAV and adding a `hand_made` line to its source; the tool then never rebuilds that file.
- **Gameplay does not change and gameplay code does not call audio.** Only `SoundBoard` plays sounds, from signals. The few new signals (listed per task) change no behaviour. No new autoload.
- A missing sound file, catalog entry or player never crashes and never blocks a signal route: the sound is skipped and reported once with `push_warning`. Nothing plays before the first input on the web (browsers require it) and nothing errors then.
- Tests never touch the real save (`save_path = ""`). Tests that instantiate `main.tscn` also set the pick screen's `pause_tree` to false, and must not leave `get_tree().paused` or the AudioServer's mute or bus volumes changed (restore them in `after_each`).
- Do not name a local or parameter after a `CanvasItem` or `Node` property (`name`, `scale`, `position`, `volume_db` on a node is fine only as the property itself): the MCP run flags it. Do not name a test helper `_set`. Run `mcp__godot__run_project` once per task that changes the running game, read `get_debug_output`, then `stop_project`.
- The stress scene: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles` (about 104 fps median now).

## Review Focus

- Nothing hitches or errors: all streams load once at start (never during a fight), a missing file or catalog entry is skipped with one warning, and nothing plays or errors before the browser's first input (Tasks 3, 6 and 7).
- A 300-enemy fight stays quiet and clear: the caps and gaps hold at the stress rate (an enemy dying about every frame), the pool never grows, and a boss warning, a level-up, a death or a blast warning is never dropped because hits and deaths filled the voices (Tasks 6 and 8).
- Sound stops when it should: gameplay sounds while paused, boss music after the boss died, music restarting from the top on every pause, any sound while muted, and the mute button's touches (Tasks 7, 8 and 9).
- Gameplay stays unaware: no system, spell, enemy or Player script calls `SoundBoard` or an audio node, no autoload was added, and the new signals only announce what already happened (Tasks 6, 8 and 10).
- Size and replaceability: the committed audio is under 3 MB, every `SoundId` has a source and WAV and every WAV has a source, the stale-output test really compares rendered samples, and a `hand_made` file is left alone by the tool (Tasks 1 to 3, 5 and 10).

---

## File Structure

- Pipeline: new `scripts/audio/{sfx_source,tune_source,audio_builder,wav_writer}.gd`, `audio/sounds/*.sfx`, `audio/music/*.tune`, `assets/audio/*.wav` (+ `.import`), `tools/art/art_builder.gd` (builds audio too), `tests/test_sfx_source.gd`, `test_tune_source.gd`, `test_audio_builder.gd`, `test_audio_assets.gd`.
- Data: new `resources/audio/{sound_data,sound_catalog}.gd`, `resources/audio/sound_catalog.tres`, `scripts/audio/{sound_id,sound_library}.gd`, `tests/test_sound_catalog.gd`.
- Playing: new `scripts/audio/{voice_limiter,sound_board,enemy_attack_events}.gd`, `scenes/audio/sound_board.tscn`, `scenes/main/main.tscn` (adds the board and the mute button), `tests/test_voice_limiter.gd`, `test_sound_board.gd`, `test_sound_routes.gd`.
- Small signals: `scripts/enemies/{enemy_projectile,blast_zone}.gd` (emit into `EnemyAttackEvents`), `scripts/ui/{crafting_screen,shop_screen,merchant_screen}.gd` (a `refused` or `crafted` signal), `scripts/main/main.gd` (a `point_effect_applied` signal).
- Mute: `scripts/ui/mute_button.gd`, `scenes/ui/mute_button.tscn`, `art/sprites/icon_sound.sprite` and `icon_muted.sprite`, `project.godot` (`mute` action), `scripts/progression/player_profile.gd` and `save_game.gd` (optional `muted`), `tests/test_mute_button.gd`.
- Dev tool and docs: `scenes/world/sound_test.tscn` and `scripts/world/sound_test.gd`; `CLAUDE.md`, `README.md`, `technical-design.md`, `sprint-development.md`, `development-log.md`.

---

### Task 1: Sound recipes and the renderer

**Files:**
- Create: `scripts/audio/sfx_source.gd`, `scripts/audio/audio_builder.gd`, `scripts/audio/wav_writer.gd`, `tests/test_sfx_source.gd`, `tests/test_audio_builder.gd`

**Interfaces:**
- Produces: the `.sfx` text format: `length <seconds>` and one or more `voice <wave> <start_hz> <end_hz> <volume> <attack> <decay>` lines, each optionally followed by `vibrato <hz> <depth_semitones>` and `delay <seconds>`. `wave` is `pulse12`, `pulse25`, `pulse50`, `triangle`, `saw` or `noise` (for noise the Hz values set how fast the noise steps; 0 means every sample). A voice starts at its `delay`, runs `attack + decay` seconds (amplitude ramps 0 to `volume` over `attack`, then to 0 over `decay`) and its pitch moves from `start_hz` to `end_hz` along that time (a straight line on a log scale). A line `hand_made` marks a file the tool must not rebuild. `#` starts a comment.
- `SfxSource.parse(text) -> SfxSource` with `errors: PackedStringArray` (collected, never thrown), `length: float`, `voices: Array[Dictionary]` (`wave`, `start_hz`, `end_hz`, `volume`, `attack`, `decay`, `vibrato_hz`, `vibrato_depth`, `delay`), `hand_made: bool`.
- `AudioBuilder.RATE := 22050`. `AudioBuilder.render_sfx(source) -> PackedFloat32Array` (voices mixed, samples clamped to -1..1, deterministic). `WavWriter.encode(samples: PackedFloat32Array, rate: int, loop: bool = false) -> PackedByteArray` (a 16 bit mono PCM WAV; with `loop` it adds a `smpl` chunk with one forward loop over the whole sample so Godot imports it as a loop).

- [ ] **Step 1: Write the failing tests.** `test_sfx_source`: `test_a_voice_line_parses_every_field`, `test_vibrato_and_delay_are_optional_and_parse`, `test_an_unknown_wave_is_an_error`, `test_a_negative_or_missing_number_is_an_error`, `test_a_recipe_with_no_voice_is_an_error`, `test_hand_made_marks_the_source`, `test_comments_and_blank_lines_are_ignored`. `test_audio_builder`: `test_the_render_is_length_times_rate_samples`, `test_every_sample_is_between_minus_one_and_one_even_with_many_loud_voices`, `test_the_same_recipe_renders_the_same_samples_twice` (noise included), `test_a_square_voice_swings_both_ways_and_a_silent_volume_is_silent`, `test_a_delayed_voice_is_silent_until_its_delay`, `test_pitch_slides_from_start_to_end` (count zero crossings in the first and last tenth of a rising slide: the last tenth has more), `test_the_envelope_starts_and_ends_at_zero`, `test_the_triangle_is_smoother_than_the_pulse` (smaller mean step between samples), `test_the_wav_has_a_riff_header_the_right_size_and_rate`, `test_a_loop_wav_has_a_smpl_chunk_covering_the_whole_sample_and_a_one_shot_has_none`. Run both files. Expected: FAIL (classes missing).
- [ ] **Step 2: Implement** the three classes. Pulse widths 12.5, 25 and 50 percent duty; the noise is a deterministic 15 bit linear-feedback shift register (the NES idea), never `randf`. Run `godot --headless --import`, then both test files. Expected: PASS.
- [ ] **Step 3: Run** the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: sound recipes and the chiptune renderer`.

---

### Task 2: Tunes

**Files:**
- Create: `scripts/audio/tune_source.gd`, `tests/test_tune_source.gd`
- Modify: `scripts/audio/audio_builder.gd`, `tests/test_audio_builder.gd`

**Interfaces:**
- Consumes: `AudioBuilder.RATE`, `WavWriter.encode`.
- Produces: the `.tune` format: `tempo <bpm>`, an optional `loop` line, then for each voice a line `channel <wave> <volume>` followed by one or more lines of cells separated by spaces (`|` is a bar line and is ignored). A cell is a note (`C4`, `F#3`, `Bb5`: letter, optional `#` or `b`, octave), `-` (a rest) or `.` (keep the previous note sounding). One cell is one sixteenth note (`60 / tempo / 4` seconds). On a `noise` channel any `x` is a short hit and `-` is a rest. `hand_made` and `#` comments work as in recipes. Every channel must have the same number of cells (the tune's length).
- `TuneSource.parse(text) -> TuneSource` with `errors`, `tempo: float`, `loops: bool`, `channels: Array[Dictionary]` (`wave`, `volume`, `cells: PackedStringArray`), `hand_made: bool`, `step_count() -> int`, `duration() -> float`, and static `TuneSource.note_hz(cell) -> float` (0 for a rest or hold; A4 is 440 Hz).
- `AudioBuilder.render_tune(source) -> PackedFloat32Array`. A note has a short attack and a staccato decay inside its step (the bounce); a held cell extends it. The tune loops cleanly: the last sample is silent or matches the first, so the loop point is not a click.

- [ ] **Step 1: Write the failing tests.** `test_tune_source`: `test_a_channel_and_its_cells_parse`, `test_bar_lines_are_ignored_and_cells_split_on_spaces`, `test_note_names_map_to_frequencies` (A4 440, C4 about 261.63, A5 880, C#4 and Db4 equal), `test_rests_and_holds_have_no_frequency`, `test_channels_of_different_lengths_are_an_error`, `test_a_bad_note_name_is_an_error`, `test_tempo_must_be_positive`, `test_duration_follows_tempo_and_steps` (120 bpm and 16 cells is 2.0 s), `test_loop_and_hand_made_lines_are_read`. `test_audio_builder`: `test_a_tune_renders_its_duration_in_samples`, `test_a_rest_is_silent_and_a_note_is_not`, `test_a_held_cell_keeps_sounding_across_the_step_boundary`, `test_two_channels_are_mixed_and_clamped`, `test_the_end_of_a_looping_tune_is_silent_so_it_loops_without_a_click`, `test_a_tune_renders_the_same_samples_twice`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** `TuneSource` and `render_tune`. Run `godot --headless --import` and the two files. Expected: PASS.
- [ ] **Step 3: Run** the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: chiptune tunes`.

---

### Task 3: Building, the catalog and the library

**Files:**
- Create: `resources/audio/sound_data.gd`, `resources/audio/sound_catalog.gd`, `resources/audio/sound_catalog.tres`, `scripts/audio/sound_id.gd`, `scripts/audio/sound_library.gd`, `tests/test_audio_assets.gd`, `tests/test_sound_catalog.gd`, `audio/sounds/ui_click.sfx`, `audio/music/music_run.tune` (one tiny placeholder each, replaced in Tasks 4 and 5)
- Modify: `scripts/audio/audio_builder.gd` (`build_all`), `tools/art/art_builder.gd`

**Interfaces:**
- Produces: `AudioBuilder.build_all(source_dir: String, out_dir: String) -> PackedStringArray` builds every `.sfx` and `.tune` under `source_dir` (`sounds/` and `music/` subfolders) into `<out_dir>/<id>.wav` (id is the file's base name; music loops when its tune says `loop`) and returns the problems. A `hand_made` source is skipped (its WAV must exist, else a problem). The tool calls it with `res://audio` and `res://assets/audio`, after the sprites, fonts and theme.
- `SoundData` (Resource): `id: StringName`, `volume_db: float = 0.0`, `max_voices: int = 4`, `min_gap_msec: int = 0`, `priority: Priority` (`LOW`, `NORMAL`, `HIGH`), `wobble: float = 0.0` (random pitch spread in semitones, plus or minus), `pausable: bool = true` (false for UI sounds), `music: bool = false`.
- `SoundCatalog` (Resource): `sounds: Array[SoundData]`, `find(id) -> SoundData` (null if unknown), static `default_catalog() -> SoundCatalog` (loads `res://resources/audio/sound_catalog.tres`).
- `SoundId` holds one `const NAME := &"name"` per sound (the full list is Task 4's table). `SoundLibrary.find(id) -> AudioStream` (loads `res://assets/audio/<id>.wav`, cached; null if missing), with a static `root` path tests can change, and `SoundLibrary.warn_once(id)` (one `push_warning` per missing id).

- [ ] **Step 1: Write the failing tests.** `test_audio_assets`: `test_every_source_parses_with_no_errors` (every `.sfx` and `.tune`), `test_each_committed_wav_equals_what_the_tool_renders` (compare the file's samples with `AudioBuilder` output, skipping `hand_made`), `test_no_wav_belongs_to_nothing`, `test_every_source_has_a_wav`, `test_the_committed_audio_is_under_three_megabytes`, `test_no_sound_is_silent` (peak above 0.05), `test_no_sound_clips_at_full_scale_everywhere` (a hard clip fraction below 2 percent), `test_music_loops_and_sounds_do_not` (tunes marked `loop` import as loops: check the WAV has a `smpl` chunk), `test_hand_made_sources_are_not_rebuilt` (build into a temp folder with an existing WAV and a `hand_made` source and check the file is untouched). `test_sound_catalog`: `test_find_returns_data_or_null`, `test_every_catalog_entry_has_a_wav_and_every_sound_id_a_catalog_entry`, `test_ids_are_unique`, `test_default_numbers_are_sane` (max_voices at least 1, gaps zero or more), `test_library_returns_null_for_a_missing_sound_and_warns_once`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** `build_all`, the classes, the two placeholder sources and a first catalog; wire the tool; run `godot --headless --import`, the tool, `--import` again (commit the `.wav.import` files like the other assets), then the new tests and the whole suite. If Godot's WAV import cannot keep the loop or breaks the committed audio, rule on the smallest fix and ledger it. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the audio build, the sound catalog and the library`.

---

### Task 4: The sounds and the sound-test scene

**Files:**
- Create: `audio/sounds/*.sfx` (one per `SoundId`, below), `assets/audio/*.wav`, `scenes/world/sound_test.tscn`, `scripts/world/sound_test.gd`
- Modify: `scripts/audio/sound_id.gd`, `resources/audio/sound_catalog.tres`, `tests/test_sound_catalog.gd`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: one `.sfx` and one catalog entry per id:
  - Casts: `cast_fire`, `cast_thunder`, `cast_land`, `cast_sea`. Impacts: `hit_fire`, `hit_thunder`, `hit_land`, `hit_sea`, `hit_strong` (accent for a vulnerable hit), `hit_resisted`.
  - Enemies: `enemy_shot`, `blast_warn`, `blast_boom`, `enemy_die`, `enemy_die_big`, `enemy_die_elite`. Boss: `boss_spawn`, `boss_slam`, `boss_charge`, `boss_burst`, `boss_die`.
  - Player: `player_hurt`, `player_die` (a short falling jingle), `level_up` (a short rising jingle), `step`. Pickups: `pickup_scroll`, `pickup_xp`, `pickup_gold`. Potions: `potion_drink`, `potion_refused`.
  - Interface: `ui_click`, `ui_back`, `ui_hover`, `lectern_open`, `craft_confirm`, `craft_fail`, `shop_buy`, `shop_fail`, `shop_equip`. Points of interest: `shrine_heal`, `shrine_mana`, `chest_open`, `merchant_open`.
  Starting catalog numbers (tune by ear later): `hit_*`, `enemy_die*` and `step` are `LOW` priority with `max_voices` 3 to 4, `min_gap_msec` 30 to 80 and `wobble` 1.5 (step 0.5); casts are `NORMAL`, `max_voices` 3, gap 40; pickups `NORMAL` with `max_voices` 3, gap 50; `blast_warn`, `enemy_shot` (NORMAL, gap 60), `boss_*`, `player_*`, `level_up`, `potion_*`, `shrine_*`, `chest_open`, `craft_*` and `shop_*` are `HIGH` or `NORMAL` with `max_voices` 1 or 2; `ui_*` and `lectern_open` and `merchant_open` are not `pausable`. `volume_db` runs from -12 (hits, steps, deaths, XP) to -4 (casts, level-up, boss) so the busy sounds sit under the rest.
- The sound-test scene: a window with a button per sound id (play it through a `SoundBoard`-free `AudioStreamPlayer`), a button per tune (play and stop), "play all sounds in a row", keys 1 to 9 and arrows for keyboard use, and on-screen text for each sound's length and peak. It sets nothing in the save and needs no map. Run with `godot --path . res://scenes/world/sound_test.tscn`.

- [ ] **Step 1: Write the failing tests.** `test_sound_catalog`: `test_the_catalog_lists_every_sound_in_the_design` (the ids above, exactly), `test_hits_deaths_and_steps_are_low_priority_and_capped` (the busy ones have a gap and at most 4 voices), `test_the_important_sounds_are_not_low_priority` (boss, player, level_up, blast_warn, potion_refused), `test_ui_sounds_do_not_stop_when_paused`. `test_audio_assets` gains: `test_every_sound_is_short` (under 1.5 s, jingles under 2.5 s), `test_the_busy_sounds_are_very_short` (hits, deaths and steps under 0.35 s). Run. Expected: FAIL.
- [ ] **Step 2: Author the recipes**, one at a time in a throwaway scratchpad generator or by hand, from chiptune idioms: a Fire cast is a quick rising square sweep with a noise puff; Thunder a zig-zag pulse12 with a short noise crack; Land a low triangle thump with a noise tick; Sea a bubbly rising pulse25 with vibrato. Hits are tiny and different per element; a strong hit adds a bright two-note blip, a resisted hit a dull one. Pickups are cheerful rising bleeps (scroll a magic sparkle of three notes, XP a tiny blip, Gold a coin "ding" of two notes). Level-up is a rising arpeggio, player death a falling one. UI click is a short high blip, back a lower one, hover tiny. Enemy deaths are short pops (small), a bigger two-voice pop (big) and a pop with a sparkle (elite). Boss sounds are lower and longer (a stinger, a thump, a rising whoosh, a burst). Check each with the Task 3 tests.
- [ ] **Step 3: Build the sound-test scene**, run the tool and the import, then the new tests and the whole suite. Run the sound-test scene once for a clean MCP run (no errors, every button plays).
- [ ] **Step 4: Commit** `feat: the chiptune sound effects and the sound-test scene`. In the report, list every sound with its length and say they were not judged by ear.

---

### Task 5: The music

**Files:**
- Create: `audio/music/music_boss.tune` and the real `audio/music/music_run.tune` (replacing Task 3's placeholder), `assets/audio/{music_run,music_boss}.wav` (the two jingles are the short `level_up` and `player_die` sounds from Task 4, not tunes)
- Modify: `scripts/audio/sound_id.gd`, `resources/audio/sound_catalog.tres`, `scenes/world/sound_test.tscn`, `tests/test_audio_assets.gd`

**Interfaces:**
- Produces: `SoundId.MUSIC_RUN := &"music_run"` and `SoundId.MUSIC_BOSS := &"music_boss"` (files `music_run.wav` and `music_boss.wav`, catalog entries with `music = true`, `pausable = false`, `volume_db` about -14). Both are looping tunes.
- `music_run`: a bouncy major-key loop, about 28 seconds (for example 130 bpm, 4 bars of 4 beats repeated into an AABA phrase): a pulse25 melody that hops and leaps, a pulse12 arpeggio, a triangle bass on the beats and a quiet noise hat on the offbeats.
- `music_boss`: faster (about 156 bpm), about 24 seconds, the same key family but with minor-feeling turns and a driving triangle bass, still chiptune and playful (a tense chase, not a threat).

- [ ] **Step 1: Write the failing tests.** `test_audio_assets`: `test_the_music_tunes_loop` (both have `loop` and a `smpl` chunk), `test_the_run_loop_is_between_20_and_45_seconds`, `test_the_boss_loop_is_faster_than_the_run_loop` (higher tempo), `test_the_music_is_quieter_than_a_loud_sound_effect` (catalog volume at least 6 dB below `cast_fire`), `test_the_music_leaves_the_audio_under_three_megabytes`. Run. Expected: FAIL.
- [ ] **Step 2: Compose** the two tunes (a throwaway scratchpad script may write the pattern text, but the committed source is the `.tune`). Keep melodies simple and repeating; check the end of each loop is silent (Task 2's test covers it). Run the tool, `--import`, the tests and the whole suite, and audition both from the sound-test scene (a clean run).
- [ ] **Step 3: Commit** `feat: the run and boss music`. Report the tempo, length and size of each tune and that they were not judged by ear.

---

### Task 6: The voice limiter and the sound board

**Files:**
- Create: `scripts/audio/voice_limiter.gd`, `scripts/audio/sound_board.gd`, `scenes/audio/sound_board.tscn`, `tests/test_voice_limiter.gd`, `tests/test_sound_board.gd`
- Modify: `scenes/main/main.tscn` (adds `SoundBoard`)

**Interfaces:**
- Consumes: `SoundCatalog`, `SoundData`, `SoundLibrary`, `SoundId`.
- Produces: `VoiceLimiter` (RefCounted, pure and clock-injected): `VoiceLimiter.new(voice_count: int)`; `request(data: SoundData, now_msec: int) -> int` returns the voice index to use (0 to count - 1), or `-1` to drop; rules: a sound's `min_gap_msec` since its last start, `max_voices` playing at once, a free voice else steal only when `priority` is HIGH (steal the oldest LOW voice, else the oldest), a NORMAL sound waits for a free voice, a LOW sound never steals. `started(index, data, now_msec)`, `finished(index)`, `playing_count()`, `playing_count_of(id)`.
- `SoundBoard` (Node, `process_mode` Always) in the scene `sound_board.tscn`: constants `VOICES := 12` (an `AudioStreamPlayer` pool built in `_ready`, none created later), buses `Master`, `Music` and `Sfx` created in `_ready` if missing (Music and Sfx send to Master), `catalog: SoundCatalog`, `muted: bool` (`set_muted(value)` mutes the Master bus and emits `mute_changed(value)`), `play(id: StringName, pitch: float = 1.0)` (a no-op while muted, before `unlock()`, for an unknown id or a missing stream, and for a `pausable` sound while the tree is paused; applies `volume_db` and a random pitch within `wobble` semitones from a seeded `rng`; reports a missing sound once), `unlock()` (called by the first input, see Task 7), `is_unlocked()`, `voices_in_use()`, and `calls_dropped() -> int` (a counter for tests and the stress scene). Streams are loaded once in `_ready` for every catalog entry. The board never emits or connects anything about gameplay yet (Task 8).

- [ ] **Step 1: Write the failing tests.** `test_voice_limiter`: `test_a_free_pool_lets_a_sound_through`, `test_the_gap_blocks_a_sound_that_is_too_soon`, `test_max_voices_of_one_sound_blocks_the_next`, `test_a_full_pool_drops_a_low_sound`, `test_a_full_pool_makes_a_normal_sound_wait` (returns -1), `test_a_high_sound_steals_the_oldest_low_voice_first_then_the_oldest`, `test_finished_voices_become_free`, `test_the_busy_fight_rate_never_exceeds_the_caps` (simulate 300 `enemy_die` requests over one simulated second at 60 Hz with a 60 ms gap and 3 voices: never more than 3 playing and never faster than the gap), `test_a_blast_warning_always_gets_through_a_pool_full_of_hits`. `test_sound_board`: `test_the_board_builds_a_fixed_pool_and_the_three_buses`, `test_nothing_plays_before_unlock_and_nothing_errors`, `test_play_takes_a_voice_after_unlock`, `test_an_unknown_id_or_missing_stream_is_skipped_and_warns_once`, `test_muting_silences_play_and_mutes_the_master_bus_and_emits_mute_changed`, `test_a_pausable_sound_is_skipped_while_paused_and_a_ui_sound_is_not`, `test_wobble_stays_inside_its_semitones`, `test_the_pool_never_grows_under_a_flood_of_requests`, `test_the_board_restores_nothing_it_did_not_change` (a test helper restores bus volume and mute in `after_each`). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `VoiceLimiter` and `SoundBoard`, and add the board to `main.tscn`. Run `godot --headless --import` and both files, then the whole suite and one MCP run (no errors, no sound before input). Expected: PASS.
- [ ] **Step 3: Commit** `feat: the voice limiter and the sound board`.

---

### Task 7: Music behaviour, pause and the web unlock

**Files:**
- Modify: `scripts/audio/sound_board.gd`, `tests/test_sound_board.gd`

**Interfaces:**
- Consumes: Task 6, `SoundId.MUSIC_RUN`, `SoundId.MUSIC_BOSS`.
- Produces on `SoundBoard`: `start_music()` (starts `music_run` looping on the `Music` bus if unlocked), `set_boss_music(active: bool)` (crossfades `music_boss` in or out over `CROSSFADE := 1.0` s and keeps both players' positions), `music_state() -> StringName` (`&"off"`, `&"run"`, `&"boss"`), `duck(seconds: float, amount_db: float)` (lowers the music for a jingle then restores), `PAUSED_MUSIC_DB := -9.0` (the music is this much lower while the tree is paused and returns after), and an `_input` that calls `unlock()` on the first `InputEventScreenTouch`, mouse button press or key press and then `start_music()`. Focus loss and a background tab (`NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT` and `NOTIFICATION_APPLICATION_PAUSED`) pause the music players, and the matching in-notifications resume them. A boss music start never restarts the run loop from the top: the run loop keeps its position under the boss loop and is faded back in at the same position.

- [ ] **Step 1: Write the failing tests.** `test_music_does_not_start_before_the_first_input` and `test_the_first_key_touch_or_click_unlocks_and_starts_the_run_loop` (one test per event type). `test_boss_music_fades_in_and_out_and_the_run_loop_returns` (state goes run to boss to run; volumes reach their targets after the crossfade), `test_boss_music_twice_in_a_row_does_not_restart_it`, `test_pausing_lowers_the_music_and_unpausing_restores_it_without_restarting_it` (the stream position keeps advancing and is not 0 after a pause cycle), `test_muting_while_music_plays_and_unmuting_resumes_it`, `test_duck_lowers_then_restores_the_music`, `test_losing_focus_pauses_the_music_and_gaining_it_resumes`, `test_play_music_with_a_missing_stream_is_skipped_and_reported_once`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** the music players (`AudioStreamPlayer`s in the pool scene, two for music), tweens for the fades and ducks (they use `create_tween` with `process_mode` always), and the notification handling. Run both test files, one MCP run and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: music, pause and the web unlock`.

---

### Task 8: The routes: signals to sounds

**Files:**
- Create: `scripts/audio/enemy_attack_events.gd`, `tests/test_sound_routes.gd`
- Modify: `scripts/audio/sound_board.gd`, `scripts/enemies/enemy_projectile.gd`, `scripts/enemies/blast_zone.gd`, `scripts/ui/crafting_screen.gd`, `scripts/ui/shop_screen.gd`, `scripts/ui/merchant_screen.gd`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_crafting_screen.gd`, `tests/test_shop_screen.gd`, `tests/test_merchant_screen.gd`

**Interfaces:**
- Consumes: Tasks 6 and 7.
- Produces: `EnemyAttackEvents` (RefCounted with `static var bus := EnemyAttackEvents.new()` and signals `shot_fired(position: Vector2)`, `blast_warned(position: Vector2, radius: float)`, `blast_detonated(position: Vector2)`); `EnemyProjectile.fire` emits `shot_fired`, `BlastZone` emits `blast_warned` when its fuse starts and `blast_detonated` when it goes off (both only announce, nothing else changes). `CraftingScreen` gains `signal crafted` (emitted when `confirm()` crafts) and `signal refused(reason: String)` (when it does not); `ShopScreen` and `MerchantScreen` gain `signal refused(reason: String)` (a failed buy, equip or purchase); `Main` gains `signal point_effect_applied(kind: PointOfInterestData.Kind)`, emitted from `_on_point_used` only when the effect was applied (not on a refusal) and for a merchant when its screen opens.
- `SoundBoard.bind(main: Node)` connects every route once (Main calls it in `_ready` after its own wiring). Routes (each `play` call passes the id; hits and deaths pass `wobble` through the catalog): `SpellLoadout.cast_fired` to the cast sound of the selected spell's first element (`cast_fire`, `cast_thunder`, `cast_land`, `cast_sea`, found through `ElementLooks.id_of`); `EnemySpawner.enemy_damaged(position, amount, effect)` to the hit sound of the **element of the last cast** (an approximation, ledger it) with `hit_strong` added for `VULNERABLE` and `hit_resisted` for `RESISTED`; `EnemySpawner.enemy_died` to `enemy_die`, `enemy_die_big` (body scale of 1.4 or more) or `enemy_die_elite`; the player's hurtbox `hit_received` to `player_hurt` and `Player.died` to `player_die` (and `duck`); `PickupCollector.collected`, `xp_collected` and `gold_collected` to the three pickup sounds; `PotionBelt.used` and `refused`; `RunProgress.leveled_up` to `level_up` (with `duck`); `EnemySpawner.boss_spawned` to `boss_spawn` and `set_boss_music(true)`, `EnemySpawner.boss_died` to `boss_die` and `set_boss_music(false)`, and each boss's `attack_started` to `boss_slam`, `boss_charge` or `boss_burst` by attack kind; `EnemyAttackEvents.bus` to `enemy_shot`, `blast_warn` and `blast_boom`; the Lectern's `interacted` to `lectern_open`; `Main.point_effect_applied` to `shrine_heal`, `shrine_mana`, `chest_open` or `merchant_open` by kind; `CraftingScreen.crafted` and `refused`, `ShopScreen.changed` (`shop_buy`; equips use `shop_equip` if the screen can tell, else `shop_buy`) and `refused`, `MerchantScreen.changed` and `refused`; and a soft `step` every 0.32 s while the player is moving and alive (a timer in the board reading the player's movement). Every `Button` in the tree, found through `get_tree().node_added` (and the nodes already there at bind time), plays `ui_click` on `pressed` (`ui_back` for a button whose `theme_type_variation` is `ButtonRed`) and `ui_hover` on `focus_entered`.

- [ ] **Step 1: Write the failing tests** in `tests/test_sound_routes.gd` with a recording stub board (a `SoundBoard` subclass whose `play` records ids; the real catalog and no audio): one test per route above, named for its signal (`test_a_cast_plays_the_cast_sound_of_the_spells_element` for each element, `test_a_vulnerable_hit_adds_the_strong_accent`, `test_a_resisted_hit_adds_the_soft_one`, `test_a_big_enemy_dies_with_the_big_sound`, `test_an_elite_dies_with_the_elite_sound`, `test_player_hurt_and_death`, `test_the_three_pickups`, `test_potion_used_and_refused`, `test_level_up`, `test_a_boss_spawn_starts_the_boss_music_and_its_death_ends_it`, `test_boss_attack_sounds_follow_the_attack_kind`, `test_enemy_shots_and_blast_zones_through_the_event_bus`, `test_the_lectern_opens`, `test_each_point_of_interest_kind_has_its_sound_and_a_refusal_has_none`, `test_crafting_confirm_and_refusal`, `test_shop_buy_and_refusal`, `test_merchant_buy_and_refusal`, `test_footsteps_only_while_moving_and_alive`, `test_buttons_click_back_and_hover_including_ones_added_later`). Plus in each screen's own test file: the new signal fires (`test_crafting_emits_crafted_on_success_and_refused_with_the_reason_on_failure`, the same for shop and merchant), and `test_enemy_attack_events_fire_for_a_shot_and_a_blast` (in the projectile and blast zone tests). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the signals, the events class, `SoundBoard.bind` and the routes; have `Main._ready` call `$SoundBoard.bind(self)` after its wiring. Gameplay scripts only gain the one-line signal emissions listed above. Run `godot --headless --import`, the files, then the whole suite and one MCP run (no warnings about missing sounds).
- [ ] **Step 3: Commit** `feat: the sound board listens to the game`.

---

### Task 9: The mute key and the speaker button

**Files:**
- Create: `scripts/ui/mute_button.gd`, `scenes/ui/mute_button.tscn`, `art/sprites/icon_sound.sprite`, `art/sprites/icon_muted.sprite`, `tests/test_mute_button.gd`
- Modify: `project.godot` (the `mute` action, key M), `scenes/main/main.tscn` (the button on the HUD), `scripts/main/main.gd`, `scripts/progression/player_profile.gd`, `scripts/progression/save_game.gd`, `tests/test_player_profile.gd`, `tests/test_save_game.gd`, `tests/test_input_map.gd`, `CLAUDE.md` (the controls sentence)

**Interfaces:**
- Consumes: `SoundBoard.muted` and `mute_changed`, `UiKit`, the HUD button pattern (`InteractButton`, `InventoryButton`: a `Face` Button child that takes no input, the widget handles taps in `_input`).
- Produces: input action `mute` (key M only; no gamepad button, the D-pad and face buttons are taken: a test already fails if two gameplay actions share one). `PlayerProfile.muted: bool` (optional in the JSON, false when absent, written when true or always; the save version does not change, so old saves load). `MuteButton` (Control): `SIZE := Vector2(32, 32)`, a themed button face showing `icon_sound` or `icon_muted` (two one-frame 11 by 11 sprites: a speaker with waves, a speaker with a slash), `signal pressed`, `handle_touch(screen_position) -> bool`, `set_muted(value)`; placed at the top right beside the Inventory button (below it if they would overlap; move the potion bar down as needed). `Main` toggles `SoundBoard.set_muted` on the `mute` action and on the button's `pressed`, keeps the button and the board in step through `mute_changed`, applies the profile's `muted` at start and saves it through the existing `ProfileSaver` when it changes.

- [ ] **Step 1: Write the failing tests.** `test_mute_button`: `test_the_button_is_at_least_32_by_32`, `test_a_touch_inside_emits_pressed_and_one_outside_does_not`, `test_mouse_clicks_are_ignored_like_the_other_touch_widgets` (taps only), `test_the_face_takes_no_input_and_no_focus`, `test_set_muted_swaps_the_icon`, `test_a_hidden_button_ignores_touches`. `test_player_profile` and `test_save_game`: `test_muted_round_trips`, `test_a_save_without_the_muted_field_loads_as_not_muted`, `test_a_wrongly_typed_muted_field_is_ignored_not_fatal`. `test_input_map`: `test_the_mute_action_is_the_m_key_and_no_gamepad_button_is_shared`. A Main test (in `test_sound_routes.gd` or `test_main.gd`): `test_pressing_mute_toggles_the_board_the_button_and_the_saved_profile` (with `save_path = ""` use an in-memory profile) and `test_a_muted_profile_starts_the_game_muted`. Run. Expected: FAIL.
- [ ] **Step 2: Draw the two icons** (11 by 11 sprites in the 13a pipeline, plum outline, cream and yellow), implement the button, the action, the profile field and the Main wiring; run the art tool and the import, the files, the whole suite and one MCP run. Take a real-window screenshot of the HUD with the button muted and unmuted.
- [ ] **Step 3: Commit** `feat: the mute key and the speaker button`.

---

### Task 10: Guards, performance, real-window checks and docs

**Files:**
- Create: `tests/test_audio_guards.gd`
- Modify: `CLAUDE.md` (a new "Audio (Sprint 13e)" section and the Project State line), `README.md`, `technical-design.md`, `sprint-development.md` (13e ticks and a Built note), `development-log.md`, `sprint-13e-design.md` (Status: Built, plus a "Revisions during the build" note per change of course)

**Interfaces:**
- Consumes: everything above. Produces nothing later tasks need.

- [ ] **Step 1: Write the failing guard tests** in `tests/test_audio_guards.gd`: `test_no_script_outside_the_audio_folder_references_the_sound_board_or_an_audio_player` (scan `scripts/` except `scripts/audio/`, `scripts/ui/mute_button.gd`, `scripts/main/main.gd` and `scripts/world/sound_test.gd` for `SoundBoard`, `AudioStreamPlayer` and `AudioServer`), `test_the_project_has_no_new_autoload` (the autoload list equals today's), `test_every_sound_id_is_used_by_a_route_or_listed_as_spare` (each `SoundId` appears in `sound_board.gd` or in a short `SPARE` list in the test with a reason), `test_every_gameplay_signal_route_is_bound_once` (calling `bind` twice does not double-connect), `test_the_stress_rate_of_events_keeps_the_pool_flat` (feed the board 300 simulated hits, deaths and pickups per second for 5 simulated seconds: voices in use never exceed `VOICES` and `calls_dropped()` is positive). Run. Expected: FAIL only on what Tasks 6 to 9 missed; fix and ledger each.
- [ ] **Step 2: Performance and web check.** Run the stress scene three times and once with `--boss` with the board active in `stress_test.tscn` only if the scene already includes it (otherwise add the board to the stress scene behind a `--sound` option and compare with and without); expected within about 5 percent of today (104 fps median). Check the committed audio size (under 3 MB) and the exported package size note (the web export is not run; say so).
- [ ] **Step 3: Real-window checks** in a scratchpad script (`save_path` empty): play the game for a minute with a spell, a crowd and the Ember Titan and confirm no warning, no hitch and that the caps held (the board's counters); press M and tap the button (the first input unlocks and starts the music, the second mutes); open the crafting screen and the shop (music lowered, UI sounds play) and close them; die and check the jingle ducks the music. State clearly that how it sounds was not judged.
- [ ] **Step 4: Update the docs** and delete nothing else. Run the whole suite and `godot --headless --quit-after 60`. Expected: PASS and no new warnings.
- [ ] **Step 5: Commit** `docs: Sprint 13e complete`.
