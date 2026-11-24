# Sprint 15b Design: Onboarding and run statistics

**Status:** Built (Sprint 15b).

Sprint 15 is three parts: **15a** the front door (done), **15b** onboarding and run statistics (this doc), **15c** release preparation. Scope comes from the Sprint 15 list in `sprint-development.md`, `CLAUDE.md` and the user's answers in conversation. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

A new player lands on a home screen with a dimmed Tutorial button and, after dying, sees one line of numbers. 15b makes the **Tutorial** real (a few pages with pictures), and turns the **game-over card** into a short run recap that **remembers the player's bests**.

**Goals (user decisions)**
- **Tutorial pages** over three or four pages with pictures: moving and casting, scrolls and the Lectern, potions and the shop (my call: a fourth page for the home screen's other features is not needed, so four pages are: the goal and moving, casting and spells, scrolls and the Lectern, potions and the shop).
- **A run recap on the death screen** with the run's headline numbers.
- **Bests saved in the progress save**, so the card can say "New best". New game erases them with the rest of progress.
- **Approach A:** a small `RunStats` tally that listens to events the game already announces and never changes gameplay.

**My calls**
- **Stats on the card:** time survived, enemies defeated, bosses defeated, level reached, XP earned, Gold earned, scrolls collected, spells crafted, potions drunk.
- **Saved bests:** longest survival (seconds), most enemies defeated, highest level reached. They live in `PlayerProfile` as one optional field (`bests`, an object with three whole numbers), so older saves load unchanged and a save without it means no bests yet.
- **"New best" rule:** a stat that beats a **non-zero** saved best gets a "New best!" mark. On the very first run every best is zero, so the card shows the best without the label (no "New best!" for the first record). Ties are not new bests.
- **Death card look:** a cream card with two columns of "label  number" rows, the best next to the three that have one ("best 4:12"), and the Shop and Home buttons below as now. Restarting is unchanged (R, a controller button, or a tap elsewhere).
- **The Tutorial opens only from the home screen's Tutorial button** (now active). It never pops up by itself. It reuses the page structure of the Controls and Credits pages: a heading, a picture row, a few short lines (keyboard and touch both), Back and Next buttons, and a page counter.
- **Pictures are the game's existing sprites** (the wizard, a scroll, the Lectern, the potions, a shop robe), drawn 1:1 and never scaled. No new art.

**Non-goals**
- Achievements (a later sprint, which the saved bests prepare for), a guided first run, statistics that need new gameplay events (damage dealt or taken, kills per spell), a statistics screen on the home screen, per-run history.
- Changing gameplay, balance or run start.

**Anti-goals** (a failure even if it technically works)
- A tally that changes what it counts (it must only listen), or that counts twice (one kill, one enemy defeated; a boss counts as a boss and not also as an enemy).
- A "New best!" that appears on a first run, on a tie, or when the save could not be written; bests that survive New game.
- A save that fails to load because of the new field (an old save without `bests`, or a bad `bests` value, must not break loading: a bad value makes the save unusable only like any other bad field, and the old behaviour for old saves is unchanged).
- A death card that does not fit 480 by 270 or whose text overflows, or a Tutorial page whose text overflows (tests measure it as for the other screens), or that cannot be used by touch, keyboard or controller.
- A tutorial that is wrong about the controls (the keys come from the Input Map as on the Controls page).

## 2. Approaches

- **A. A tally that listens (chosen by the user).** `RunStats` connects to existing announcements; `RunRecords` compares with the saved bests at death. Cost: a few connections in `Main`.
- **B. Each system keeps its own counter.** Spreads a stats job over the spawner, the crafting screen and more, and the death card has to collect from all of them. Not chosen.
- **C. Work it out from the save alone.** Cannot count kills or scrolls. Not chosen.

## 3. Decisions

| Area | Decision |
|---|---|
| The tally | `RunStats` (`RefCounted`, `scripts/progression/run_stats.gd`): counters `enemies`, `bosses`, `scrolls`, `crafts`, `potions`, `xp`, `gold` and `level` (the highest reached), with `bind(main_parts)` connecting to `EnemySpawner.enemy_died` (an enemy that is not a boss), `RunDirector.boss_defeated`, `PickupCollector.collected` (scroll) and `xp_collected` and `gold_collected` (their amounts), `CraftingScreen.crafted`, `PotionBelt.used`, and `RunProgress.leveled_up`. It has `seconds` read from `RunClock` when asked. It is created by `Main` at each run start and never saved. |
| Records | `RunRecords` (static): `update(profile, stats, seconds) -> Dictionary` compares the three bests with the run, writes any that were beaten into `profile.bests` and returns `{"seconds": bool, "enemies": bool, "level": bool}` (true only for a beaten non-zero best); `PlayerProfile.bests` (`best_seconds`, `best_enemies`, `best_level`, whole numbers, default 0), saved in `to_dict` only when any is above 0 (so an old reader and an old save are unaffected) and read in `from_dict` with the usual whole-number checks. `Main` calls `update` when the player dies, saves at once (`_saver.save_now`) and hands the result to the death screen. A failed save is not hidden: the card still shows the run, and "New best!" is only shown when the save succeeded (`SaveGame.save_profile` returns true). |
| Death card | `DeathScreen.set_run_summary` is replaced by `set_recap(rows: Array[RecapRow])`, where a row is a label, a value text and an optional best text and new-best flag, built by `RunRecap` (static: `rows(stats, seconds, bests_before, flags)`). The card shows two columns of rows with the theme's `Heading` for the title and `Muted` for the bests, the Shop and Home buttons and the restart hint. Old callers and tests that used the one-line summary are updated. |
| Tutorial | `TutorialScreen` (`CanvasLayer`, process Always, `scenes/ui/tutorial_screen.tscn`), opened by the home screen. `TutorialPages.pages() -> Array[TutorialPage]`: four pages, each a title, one to three lines of text and one to four sprite names. Navigation: Back, Next and Close (Esc, back and a tap outside nothing; the page counter "1 of 4"), left and right on the keyboard and controller, touch by the bridge as the settings screen does. The keys in the text come from `ControlsText`'s Input Map reading, so the tutorial cannot disagree with the real bindings. |
| Home screen | The Tutorial button loses its "(soon)" and its disabled state and opens the screen; the home guard tests are updated. |
| Pause | Opening the Tutorial from the home screen needs no pause (nothing is running). |

## 4. What is left to the builder
- The exact wording of the four tutorial pages (short, in the game's tone), and which sprites go on which page.
- The recap card's exact layout and the label wording.
- Whether `RunRecap` rows are a small class or dictionaries.
- Where in the card the "New best!" mark sits and what colour (green means good, per the theme rules).

## 5. Verification plan
- **Tally tests:** each event adds exactly one to the right counter; a boss counts as a boss only; level keeps the highest; XP and Gold add the announced amounts; the tally counts nothing before it is bound and nothing after the run's player died (the death freezes it); two tallies never share state.
- **Records tests:** a first run (all bests zero) sets the bests and flags nothing; a better run flags exactly the beaten stats; a tie flags nothing; a worse run changes nothing; bests save and load; an old save without `bests` loads with zero bests; a bad `bests` value is handled like any bad field; New game erases the bests (the save is renamed); a failed save shows no "New best!".
- **Recap tests:** rows and formatting (time as m:ss, thousands not needed), the bests shown only for the three that have one, the card text fits, and it works by touch (a tap elsewhere restarts, the Shop and Home buttons still do not).
- **Tutorial tests:** four pages, each with a title, text that fits and sprites that exist; Back, Next and the page counter; keyboard and controller navigation (focus reaches Next and Back); the key names come from the Input Map; touch is bridged; it works from the home screen and closes back to it.
- **Real window (touch rule):** screenshots of every tutorial page and the death card (with and without a new best, using a throwaway save), and by touch and mouse: open the Tutorial from the home screen, page forward and back, close; die and read the card, tap Home. Not checked on a phone.
- `godot --headless --import` after adding a `class_name`, then the full suite, a smoke run and the soak tool once (the run scene gains a tally).

## 6. Revisions during the build

- The card's XP, Gold and level come from `RunProgress` at death (copied into the tally after it is frozen), not from the tally's own event counts.
- `ProfileSaver.save_now` already returned a bool, so no saver change was needed.
- The recap is one column of nine rows (label, value, best or mark) on a 400 by 186 card, with a separate hint line.
