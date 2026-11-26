# Sprint 18 Design: A livelier home screen and tutorial

**Status:** Implemented (Sprint 18). Deviations: a `STOP` beat was added; trees are side-view sprites with grass at the base; scenery positions are base points and bushes always draw in the background; sparks appear at the base of what they hit; Reduce motion is `FxSettings.is_reduced()`; see `docs/architecture/front-door.md`. Branch `sprint-18-home-and-tutorial`.

Sprint 18 of the wishlist (`docs/release-planning/future-roadmap.md`, item 3). Scope comes from the user's answers in conversation; decisions marked "my call" are mine and open to correction.

## 1. Intent

The home screen is the first thing a player sees, on the web and later on itch.io, and today it is a small title, a small wizard and a column of buttons. Sprint 18 makes it **bright and welcoming**, with an **animated scene of the wizard fighting enemies**, a **title banner**, and **music** (the menu is silent today and only the run plays music). The four tutorial pages get a **small animated vignette each** instead of a row of tiny single sprites. Both use one new, small **stage** system that plays short scripted loops over the sprites the game already has.

**Goals (user decisions)**
- **Home layout "C":** a title banner on top, a wide animated stage in the middle, and the five menu buttons in one row at the bottom. The Achievements and Full screen buttons stay in the top corners.
- **The stage** shows the wizard casting spells at a stream of cartoon enemies who pop away in sparks, over a sunny grass scene with trees and clouds. It loops quietly and never gets in the way of the menu.
- **Music on the home screen:** **a new tune**, bright and welcoming (the user will audition it and say what to change; I cannot hear it).
- **Tutorial vignettes (option A):** each of the four pages shows a looping mini scene of what its text says, built on the same stage. The tutorial text stays as it is.
- **Approach A (the user's pick):** a small scripted stage that plays data-defined loops over existing sprites, not the real game systems and not pre-drawn sheets.

**My calls**
- **The stage is data.** A scene is a `StageScript` resource: actors (a sprite and where it starts) and timed beats (walk, play an animation, face, show, hide, shoot an orb, burst of sparks). The home stage and the four vignettes are five such scripts, so adding or tuning a scene is a data edit.
- **The wizard wears what the player has equipped** (the same layers the run uses, through `PlayerLook`), so the menu welcomes the player's own wizard. An empty profile shows the starter robe and hat.
- **Reduce motion is respected.** With `FxSettings` Reduce motion on, the stage shows one still frame (no movement, no sparks); with the particles switch off it shows no sparks.
- **It stops when it is hidden.** While a full screen (Shop, Settings, Tutorial, map select, Achievements, the confirm dialog) covers the home screen, the home stage does not run, so it costs nothing on a phone.
- **The menu gets a sound board of its own,** so the music plays and the buttons click and tick like the run's (a menu with music but silent clicks would feel broken). It honours the Music and Effects sliders and the saved mute setting. The board starts the tune on the first tap, click or key on the web (a browser rule) and at once on the desktop app. Leaving for a run frees the board; the run's board then starts the run music as today (no crossfade).
- **Audio size cap raised from 3 MB to 4 MB.** The committed audio is about 2.86 MB and one run tune is 977 KB, so a 16 to 20 second tune would break the old cap; the web package grows by only the compressed size of the tune. The test that guards the total stays, with the new number.
- **New art is small:** a title banner (at most 256 by 46 px, with a short sparkle animation), a few clouds, and whatever scenery the stage needs beyond the existing grass and tree sprites. Everything else (wizard, enemies, orbs, effects, pickups, Lectern, merchant) already exists. Every sprite stays at one pixel size, never scaled or rotated; the banner lettering is baked at its real size.

**Three details settled after a builder check (my calls, open to correction)**
- **What "Reduce motion" means for the stage.** The Settings screen's Reduce motion is a preset, not a stored flag: it sets shake strength to 0, flash strength to 0 and the hurt flash off. The stage treats exactly that combination as "reduced" (`FxSettings.is_reduced()`), so no new setting, saved field or Settings toggle is added. If the player later raises any of those three, the animation comes back, which matches what those controls mean; the Settings screen already shows them. The particles switch ("Sparks and dust") separately removes the sparks.
- **Mute on the home screen behaves as in a run.** The M key mutes the shared audio bus and saves the choice in the progress save (as the run's mute does), and the home screen applies the saved mute, on or off, when it opens, so a run never starts with the bus and the board disagreeing.
- **Layout numbers.** The banner is at most **256 by 46 px** (it clears both 100-px corner buttons by 4 px), the stage is 160 px tall, the buttons are a row at the bottom, and the small "Starting over." message line sits in the gap between the stage and the buttons.

**Non-goals**
- Any gameplay, run-scene, map, enemy, spell or balance change; the death screen; the look of the Shop, Settings, map select and Achievements screens; per-map home scenes; cutscenes; new tutorial pages or changed tutorial wording (the two pinned rules, "Mana never comes back" and "potions last one run", stay).
- A crossfade between menu and run music; a mute button on the home screen (the M key and the Settings sliders work).

**Anti-goals** (a failure even if it technically works)
- A stage that runs while hidden or drains a phone, motion that cannot be turned off, or a loop that leaves orbs or sparks behind and slowly grows.
- Art that overlaps the buttons, the corner buttons or the tutorial text, or a button row too small to hit on a phone (each button at least 72 by 28).
- Music that cannot be silenced, plays twice, or keeps playing after leaving the menu; a home screen that touches the save or plays gameplay sounds.
- A home screen that leaks nodes when opened and closed repeatedly, or breaks the existing guards (it never names `main.tscn`; the audio and fx guards stay meaningful).
- Any test that touches the real save or settings, or really changes scene.

## 2. Approaches

- **A. A small scripted stage (chosen by the user).** A looping script over existing sprites, driven by data, deterministic, nearly free at run time, and reused by the home screen and the four vignettes.
- **B. Run the real game in miniature.** The most authentic, but it drags in collisions, drops, damage, sounds and difficulty, is heavy on phones, is different every loop and is hard to test. Rejected.
- **C. Pre-drawn animation sheets.** Trivial at run time but a lot of hand-drawn art that cannot reuse the game's sprites, and every change means redrawing. Rejected.

## 3. Decisions

| Area | Decision |
|---|---|
| Stage data | `StageScript` (`resources/stage/`): `size`, `loop_seconds`, `still_time` (the frame shown with Reduce motion), `background` (a sky colour, an optional ground style and scenery list), `actors: Array[StageActor]` (`id`, `sprite`, `variant`, `start`, `facing`, `shadow`, `wizard` for the equipped look) and `beats: Array[StageBeat]` (`time`, `actor`, `action` WALK_TO, PLAY, FACE, SHOW, HIDE, SHOOT, BURST, with `to`, `duration`, `animation`, `effect`). `problems()` reports unordered beats, unknown actors, beats past the loop and missing sprites. |
| Stage node | `Stage` (`scripts/stage/`, a `Control` that clips to its rect): builds the actors as `BodyView`s, evaluates the script by time in `_process` (so it freezes with the tree and stops when `set_process(false)`), wraps at `loop_seconds` and **resets every actor and removes every orb and spark at the wrap**. At most a small fixed number of live effects (pooled or capped, like `EffectSprite.MAX_LIVE`). Hit sparks use `EffectSprite`; it names no part of the fx director (`test_fx_guards` stays as it is). |
| Home layout | Sky backdrop (existing colour) with drifting clouds, the banner centred at the top (at most 256 by 46 px, so it clears the two corner buttons), the stage (full width, about 160 px tall) in the middle, and a row of five buttons at the bottom (Play green, Shop, Tutorial, Settings, New game red; each about 88 by 28, with a 4 px gap, centred). Positions are constants like today's. The old column layout test (each button below the one before) becomes a row test. |
| Home scene | One script, about 12 to 16 seconds: the wizard stands on the left and casts Fire Missile orbs at goblins, wolves and rats walking in from the right (the plain forest sprites in a few element colourways); each hit plays the enemy's death animation and a spark; a tougher enemy takes two hits; a short pause, then it loops. Trees and bushes frame the stage. |
| Sound board on home | `home.tscn` gets a `SoundBoard`; `SoundBoard.bind_home(home)` wires the buttons (click, back, hover) and starts the menu tune; a third music key `menu` with its own state (`start_menu_music`), unlocked like the run music, stopped when the board is freed. `test_audio_guards`' allowed list gains `scripts/home/home_screen.gd` (the only non-run scene with a board); a test pins that no other script does. The saved mute and the Settings sliders apply as in the run (the M key on the home screen saves the mute). |
| The tune | `audio/music/music_menu.tune`, a new bright major-key loop (about 16 to 20 s) in the existing tune format (pulse melody, quiet pulse arpeggio, triangle bass, light noise hat), built by the art tool to `assets/audio/music_menu.wav` with its loop chunk, a `SoundData` entry (`music`, a volume a little under the run tune's) and `SoundId.MUSIC_MENU`. **Not judged by ear**; the user auditions it in the sound-test scene. `MAX_BYTES` in `test_audio_assets` becomes 4 MB. |
| Tutorial | `TutorialPage` gains a `vignette: StageScript`; `TutorialScreen` replaces the row of pictures with a `Stage` in a framed area above the lines (the lines move down a little to fit), playing the page's vignette from its start whenever the page shows, stopped on close. The four vignettes: **Survive** (the wizard walks, collects an XP gem and a coin while a goblin closes in), **Cast spells** (the reticle moves, he fires, the target pops), **Scrolls and the Lectern** (an enemy drops a scroll, he picks it up and walks to a glowing Lectern), **Potions and the shop** (he drinks a potion and a heal sparkle shows, the merchant and a coin beside him). A page with no vignette keeps today's row of sprites. |
| Art | Built in the art pipeline as `.sprite` sources: `banner_title` (with a sparkle animation), `cloud_*` (two or three), and any scenery sprites the stage needs; composed with a scratch generator, looked at on contact sheets (frames of each animation compared), checked on a real window. |
| Docs | `docs/architecture/front-door.md` gains "A livelier home screen and tutorial (Sprint 18)" (the section heading also goes into `tests/fixtures/claude_md_sections.txt`), `docs/architecture/interface-and-audio.md` a line on the menu board and tune, `development-log.md`, `sprint-development.md` marks 18 done, and the roadmap item 3 is closed. |

## 4. What is left to the builder
- The exact choreography and timings of the five scripts, the banner's lettering and sparkle, the clouds and scenery, the tune's notes and its exact length within the range, and the tutorial layout (the stage frame's size and the new line positions) inside the 480 by 270 screen.
- How `Stage` clips (`clip_contents` or another way), how effects are capped, and the exact beat vocabulary beyond the actions listed, as long as a script stays data.

## 5. Verification plan
- **Stage engine (deterministic):** at chosen times an actor is at its expected position and animation; the state just after the wrap equals the initial state; after many loops no orb or spark remains from earlier loops and the live count stays within its cap; with processing off nothing moves; Reduce motion shows exactly the `still_time` frame with no effects; the particles switch off removes sparks only; a missing sprite falls back to the coloured square and never crashes; `problems()` catches each fault.
- **Home:** the banner, stage, five buttons and two corner buttons fit inside 480 by 270 and overlap nothing; the five buttons are one row, in order, each at least 72 by 28; every button still works by mouse and by touch (checked in a real window, as in 15a, 16a and 17); opening a full screen stops the stage and closing it resumes; the equipped wizard look shows; opening and closing the home screen repeatedly leaves no orphan nodes; it never names `main.tscn`; no test touches the real save or settings.
- **Audio:** the new tune builds, is not silent or clipping and loops (the existing asset tests); the catalog and `SoundId` stay in step; the menu board starts the tune on unlock (not before, on the web path), uses the Music bus and honours volume and mute; it plays exactly once; freeing the home screen stops it; the run's board is unchanged; the guard test allows only the home script besides `Main`; the total is under 4 MB.
- **Tutorial:** every page has a valid vignette; the stage frame, lines and buttons do not overlap; Next and Back change and restart the vignette; closing stops it; a page without one keeps the sprite row; the pinned tutorial rules and the controls text tests stay green.
- **Art:** the banner is at most 256 by 46 px; the new sprites pass the palette, margin and frame-count tests; every animation's frames differ; contact sheets looked at.
- **Performance (reported, not asserted):** the stage's per-frame cost on the home screen (a small measuring script), the soak test, and a stress run noted with the machine's power state.
- **Real window:** screenshots of the home screen at three moments of the loop and of all four vignettes; touch and mouse on each button and on the tutorial's Back, Next and Close.
