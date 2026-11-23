# Sprint 13e Design: Audio

**Status:** Proposed, awaiting approval.

Sprint 13 is six parts: **13a** art foundation, **13b** the world, **13c** spells and equipment, **13d** the interface (all done), **13e** audio (this doc), **13f** polish. Scope comes from the conversation, the Audio list in `sprint-development.md`, `CLAUDE.md` and the art pipeline of 13a to 13d. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The game is silent. Sprint 13e gives it the sound of its look: **chirpy, whimsical, bouncy chiptune** (user), made from the same kind of replaceable, text-defined sources as the art. Spells, hits, deaths, pickups, potions, shrines, the Lectern, the shop and the UI all answer with a sound; the run has a bouncy music loop and a boss fight a faster, tenser one. Nothing about gameplay changes.

**Goals (user decisions)**
- **Chirpy, whimsical, bouncy chiptune**, matching the cartoon art.
- **Approach A:** every sound and tune is built by a tool from a text recipe in the repo, the outputs are committed, and replacing a sound is overwriting its file (the art pipeline's idea).
- **A mute key and a HUD button now**, because testers on phones want one at once. The full audio settings (volumes and so on) stay in Sprint 15 (user).
- The nine items on the sprint list: background music, movement sounds, spell casting, spell impact, enemy sounds, enemy death, item pickup, UI and boss music.

**My calls**
- **About 40 sounds**, listed in section 3, with one cast and one impact sound per element (Fire, Thunder, Land, Sea).
- **Music:** one run loop and one boss loop, plus two short jingles (level up, death). The boss loop fades in when a boss spawns and out when it dies, and the run loop returns.
- **Busy fights:** each repeated sound has a cap on how many play at once and a minimum gap, plus a small random pitch wobble, so 300 enemies never become a wall of noise.
- **Pause:** while the game is paused (crafting, the shop, a pick screen) the music keeps going at a lower volume and gameplay sounds stop. UI sounds still play.
- **Web:** nothing plays until the first tap, click or key (browsers require it); then the music starts. Nothing errors before that.
- **Mute is saved** in the player's profile (one optional boolean, so old saves still load), so a phone player does not mute again every launch.
- **Movement:** a very quiet soft step tick while the wizard walks, at a fixed rhythm; the sound list marks it so it is easy to drop if it annoys.

**Non-goals (later sprints)**
- Volume sliders, separate music and effect volumes, and any audio settings screen (Sprint 15).
- Real recorded sound, voice, or a licensed music pack.
- Positional or stereo-panned sound, reverb and other effects.
- Reacting to the music (beat-synced effects).

**Anti-goals** (a failure even if it technically works)
- A sound that blocks the game: no hitch from loading or building audio during play, and no error when the browser has not unlocked audio yet.
- A crowd fight that is loud, clipped or that drops the important sounds (a boss warning, a level-up, a death) because hits and deaths fill every voice.
- Sound that keeps going when it should not: gameplay sounds while paused, boss music after the boss died, music restarting from the top on every pause, or a mute that still lets a sound through.
- Gameplay code that knows about sound. Systems keep emitting signals as they do today, and one audio node listens. No system calls "play a sound" directly.
- A new autoload (the project avoids them) or a hard dependency from the Player, spells or enemies on audio.
- A missing audio file that crashes or silently breaks a signal route. A missing sound is skipped and reported once.
- A web package that balloons: the music and sounds together stay small (a budget in section 3).

## 2. Approaches

- **A. Synthesise everything from text recipes in our pipeline.** A sound recipe gives wave shapes, pitch slides, volume curves and noise. A tune is a note pattern on a few channels. The tool builds WAVs, committed like sprite sheets, and a stale-output test fails if a recipe changed and the file did not. **Chosen by the user.** Cost: I cannot hear the result, so a small sound-test scene lets the user audition every sound and tune and say what to change.
- **B. Download free chiptune packs.** Quick and good-sounding, but inconsistent in character, licences to track, and no tune that fits this game. Not chosen.
- **C. Generate sound live in the game** (`AudioStreamGenerator`). No files, but it costs CPU on every device, risks the single-threaded web build, and is the hardest to test. Not chosen.

## 3. Decisions

| Area | Decision |
|---|---|
| Sources and outputs | `audio/sounds/<id>.sfx` (a recipe) and `audio/music/<id>.tune` (a pattern) are text. `tools/art/art_builder.gd` (the one tool, run as before) builds them into `assets/audio/<id>.wav` (22,050 Hz, mono, 16 bit), which are committed. `AudioBuilder` (pure, testable) renders; the same recipe always renders the same samples (a seeded generator for noise). A stale-output test compares every committed WAV with what the builder renders, and an orphan test fails on a WAV with no source. A recipe can be replaced by drawing nothing: overwrite the WAV and add a `hand_made` line (as `hand_drawn` works for sprites). |
| Recipe format (my call) | `.sfx`: `length <seconds>`, then one or more `voice` lines: `voice <wave> <start_hz> <end_hz> <volume> <attack> <decay> [vibrato <hz> <depth>] [delay <seconds>]` with `wave` one of square (pulse widths 12.5, 25, 50), triangle, saw, noise. Several voices add together (a chord or a sparkle). `.tune`: `tempo <bpm>`, `loop`, a `channel <wave> <volume> [duty]` line per voice, then bars of notes (`C4 E4 G4 .` and so on, one cell per step). Exact grammar is the builder's. |
| Loading | `SoundLibrary.find(id)` looks a sound up (like `SpriteLibrary`), and `SoundId` holds the ids as constants so a typo fails a test, not the game. Streams are loaded once, at start, before any fighting. |
| Playing | `SoundBoard` (a node in `main.tscn`, not an autoload) owns a fixed pool of `AudioStreamPlayer`s (no node per sound), the music players and the mute state. `play(id, pitch_wobble)` takes a free voice. `VoiceLimiter` (pure) decides: per-sound max at once and minimum gap in milliseconds from `SoundData` (a Resource per sound id for these numbers and its default volume), plus a global voice count; when the pool is full a low-priority sound (hit, step) is dropped and a high-priority one (boss, level-up, death, warnings) steals the oldest voice. |
| Who triggers a sound | Only `SoundBoard`, from signals that already exist: cast (`SpellLoadout.cast_fired`), hits (`HurtboxComponent.hit_received` and `Enemy.damaged`, by element), enemy death (`EnemySpawner.enemy_died`), player hurt and death, pickups (`PickupCollector`), `PotionBelt.used` and `refused`, `leveled_up`, `RunDirector.boss_spawned` and `boss_defeated`, `Boss.attack_started`, enemy shots and blast warnings, Lectern and point-of-interest `used`, the crafting, shop and merchant results, and every `Button` press (one connection through the theme's buttons). Where a signal is missing, the owner gains one small signal (no behaviour change). |
| Sound list (about 40, my call) | Casts: fire, thunder, land, sea. Impacts: fire, thunder, land, sea, plus a "strong hit" accent and a soft "resisted" one. Enemies: shot, blast warning, blast boom, death small, death big, elite death. Boss: spawn stinger, slam, charge, burst, death. Player: hurt, death jingle, level-up jingle, step. Pickups: scroll, XP, Gold. Potions: drink, refused. Interface: click, back, hover (keyboard focus move). Lectern: open. Crafting: confirm, fail. Shop: buy, fail, equip. Points of interest: heal shrine, mana shrine, chest, merchant open. Music: run loop, boss loop. |
| Music | The run loop plays from the first input and loops forever at the music volume. The boss loop crossfades in over about 1 s when a boss spawns and back out when it dies. While paused, music drops to a lower volume instead of stopping. Level-up and death jingles duck the music briefly. Music is on its own bus so Sprint 15 can add a slider. |
| Buses | `Master`, `Music` and `Sfx` buses, set up in code at start (no layout file to maintain). Volumes are numbers in one place. |
| Mute | `SoundBoard.muted` mutes the Master bus. Key `M` (input action `mute`, with the other actions in the Input Map, shown in the controls help if there is one) and a small speaker button on the HUD (a theme button, at least 28 by 28 px, with a speaker and a slashed speaker icon). The state is saved in the profile through the existing `ProfileSaver`. The button takes its own touches like the other HUD buttons. |
| Pause | `SoundBoard.process_mode` is Always. While `get_tree().paused`, gameplay sounds are not played and the Music bus is lowered; UI sounds still play. |
| Web | The board waits for the first `InputEventScreenTouch`, mouse press or key press, then starts the music; before that, play requests are ignored. A background tab or focus loss pauses the music (the same signals `ProfileSaver` listens to) and resumes it. |
| Size | Music at 22,050 Hz mono, each loop about 25 to 40 seconds; the committed audio stays within about 3 MB (a test checks the folder size), imported with Godot's compressed WAV mode if that stays clean. |
| The sound test | `scenes/world/sound_test.tscn` (like the stress scene): a list of every sound and tune as buttons with keyboard and touch, "play all", and the voice and cap numbers on screen, so the user can audition and give feedback by ear. A developer tool, not part of the game. |

## 4. What is left to the builder
- The exact recipe and tune grammar, the sound shapes, the tunes themselves (notes, tempo, key) and every number (volumes, caps, gaps, wobble). These are tuned by the user's ears through the sound-test scene, round by round.
- Which `Button` presses play which sound (click, back, equip) where the screens already distinguish them.
- Whether Godot's compressed WAV import is clean on the web build, otherwise plain WAV within the budget.

## 5. Verification plan
- **Builder tests:** a recipe parses, errors are collected not thrown, every wave shape renders the right length and range, a recipe renders the same samples every time, the committed WAVs equal the render, no orphan files, and the size budget.
- **Logic tests:** `VoiceLimiter` (per-sound cap, gap, global voices, priority stealing, the busy-fight case at the stress rate), mute (Master bus, saved and restored, an old save without the field loads), pause (gameplay sounds skipped, UI sounds kept, music lowered), boss music in and out, music starting only after the first input, and a test that every `SoundId` has a recipe and every recipe is used or listed as spare.
- **Route tests:** with a stub `SoundBoard`, each signal listed above produces the expected sound id (one test per route).
- **Real window:** the sound-test scene, then the game with a spell, a crowd and a boss, to confirm nothing hitches. The stress scene with sound on, compared with today's frame rate. Whether it sounds right is judged by the user's ears; I cannot hear it, and say so.
- `godot --headless --import` after adding a `class_name`, then the full suite.
