# Sprint 14c Design: Optimization, soak and a testing pass

**Status:** Proposed, awaiting approval.

Sprint 14 is three parts: **14a** the world pass and **14b** balance (done), **14c** optimization (this doc). Scope comes from the Sprint 14 list in `sprint-development.md`, the open items in `development-log.md` and the user's answers in conversation. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The game runs at about 93 to 102 fps on the development desktop with 300 enemies, the whole map, drops, a boss and the effects layer (target 60). **Nothing has ever been measured on a phone or in a browser**, which is where testers play, and nobody has checked that a long session stays flat in memory. 14c makes the game able to measure itself, proves a long run does not grow, fills any gaps in the combination tests, and optimizes only what the measurements show.

**Goals (user decisions)**
- **A performance overlay** testers can open on a phone and send a screenshot of.
- **A soak test** that plays a long simulated run and checks node, object and memory counts stay flat.
- **A testing pass** over the Sprint 14 test list, adding tests only for gaps.
- **Optimization where a measurement shows a problem**, with before and after numbers.
- **The cheap deferred minors** from 13d to 14b.

**My calls**
- **Overlay:** one small line (frames per second, frame time in ms, enemies alive, total node count) over the HUD. **F3** toggles it on a keyboard; **a long press (about 1 s) on the HUD's mute button** toggles it on a phone. Off by default, never saved. It reads engine counters only, gets a switch in `FxSettings` like the effects, and never touches gameplay.
- **Soak test:** a headless script (`scripts/dev/soak_test.gd`, run like the stress scene) plays a long simulated run and samples counts every simulated minute; a short version (about 2 simulated minutes) runs in the suite.
- **Minors fixed here:** the burst's deferred spawn keeping a freed parent, the stale docs from the 14b review, the spell audit's hardcoded paths, the merchant prompt width, and a message when an old save's potions are cashed in.

**Non-goals**
- Changing balance, including the Zones (the user decides from play), or any feature.
- Fractional screen scaling for phones (a standing user call), a native build, or threaded web builds (GitHub Pages cannot send the headers).
- The settings screen itself and saving the overlay's switch (Sprint 15).

**Anti-goals** (a failure even if it technically works)
- An overlay that costs frames, allocates every frame, or can be left on by accident (a long press that also toggles mute).
- A soak test that passes because it samples too little, or that is flaky (it must not depend on wall-clock time or frame rate).
- "Optimizing" without a number: a change that is not shown faster, or that makes something worse, is reverted.
- Pooling or caching that keeps stale state across a restart (a pooled node must reset fully).
- A phone-only fix that breaks desktop, or a change to how anything plays.

## 2. Approaches

- **Overlay on the real game (chosen).** It measures what players get, on any device, with no extra scene to reach. Cost: a few lines of HUD and a long-press on one button.
- **A separate benchmark scene in the web export.** Needs a way to reach it and does not measure real play. Not chosen.
- **Soak: a simulated run in a script (chosen).** Repeatable and automatable. Reading code for leaks alone misses what only shows in play. Not chosen as the only method.

## 3. Decisions

| Area | Decision |
|---|---|
| Overlay | `PerfOverlay` (a `CanvasLayer` node in `main.tscn`, a theme `HudLabel`, hidden by default, high layer, ignores touches). It shows `fps`, frame ms, enemies (`EnemySpawner.alive`), and `Performance.OBJECT_NODE_COUNT`, refreshed 4 times a second (not every frame). `FxSettings.perf_overlay` (a switch, default false, in `SWITCH_KEYS`) is the one source of truth; `F3` (`debug_perf_overlay`, handled in `Main`) flips it. It is invisible behind pause screens only if the switch is off. |
| Phone toggle | `MuteButton` gains hold detection: a press held for 1 s emits `long_pressed`, shows the overlay, and the release that follows does not toggle mute. A normal tap still toggles mute. Touch and left mouse both work. |
| Soak tool | `SoakRun` (pure helpers: samples, trend check) and `scripts/dev/soak_test.gd`: loads `Main` headless (`save_path` empty), drives time with a fixed step (no wall clock), and each simulated minute: spawns the crowd, runs spells of every Area, kills enemies, collects pickups, levels up, drinks and buys potions, spawns the boss, and every few minutes kills the player and restarts. It samples `OBJECT_COUNT`, `OBJECT_NODE_COUNT`, `OBJECT_ORPHAN_NODE_COUNT`, `MEMORY_STATIC` and the pooled counts. It prints `SOAK minute=N nodes=.. objects=.. orphans=.. static_mb=..` lines and a PASS or FAIL verdict. |
| Pass rule | After a 2-minute warm-up, each count stays within a band (my starting numbers: nodes and objects within 10% of their warm-up value, orphans 0 growth, static memory within 10%) and has no upward trend over the last half (a least-squares slope test). A restart returns the counts to within the band of a fresh start. |
| Suite test | `tests/test_soak.gd` runs a 2-simulated-minute version with a coarse band so it is stable, plus unit tests of the trend check on synthetic series. |
| Testing pass | First write the coverage table (each Sprint 14 test item against the existing test files that cover it) into the ledger and the log; then add tests only for the gaps (the likely ones: every Base and Area combination builds and casts without error, all buff combinations at their stack limits build, a full run completion path through boss and restart, and save and load with every field). |
| Optimization | Driven by numbers: the overlay and stress scene before and after, with candidates (enemy spawning, projectile and burst pooling, particle `_draw`, per-frame allocations) taken in the order the measurements justify. Each change keeps a test of the behaviour it touches, and the log records the numbers. Crowd separation is added only if a screenshot of a stacked crowd is judged unreadable by the user. |
| Minors | The deferred minors in section 1: spawn the burst safely (check the parent is still valid when the deferred call runs, and emit `burst_spawned` after the burst is in the tree), update the stale docs, make `SpellAudit` skip a missing scroll instead of crashing and find Normal range by label, widen the merchant prompt label so "Merchant (E) 5:00" fits, and show a toast when an old save's potions were cashed in ("Your old potions were sold for N Gold"). |

## 4. What is left to the builder
- The overlay's exact text layout and position (small, top centre, clear of the HUD), and the long-press timing details.
- The soak run's exact simulated actions and the band numbers (tuned so a healthy run passes comfortably and a deliberate leak fails; the test proves the check can fail).
- Which optimizations the numbers justify; if the measurements show none, 14c ships the overlay, the soak test, the new tests and the minors, and says so.
- The wording of the cash-in toast.

## 5. Verification plan
- **Overlay tests:** hidden by default; F3 and the `FxSettings` switch show it; a long press on the mute button shows it and does not toggle mute; a tap still toggles mute; it refreshes at its rate and ignores touches; it costs nothing when hidden.
- **Soak tests:** the trend check on flat, growing and noisy series (the growing one fails); the short soak passes; a deliberate leak (a test-only node added every frame) fails the check.
- **Coverage pass:** the table, then the gap tests listed above.
- **Optimization:** before and after stress numbers (`--enemies=300 --seconds=8` with `--obstacles --drops`, `--boss --fx`, and `--area=missile`, three runs each), recorded in the log.
- **Minor-fix tests:** the burst spawns safely when its parent is freed first and `burst_spawned` fires with the burst in the tree; `SpellAudit.rows()` skips a missing scroll; the merchant prompt fits its label; the cash-in toast shows once.
- **Real window:** a screenshot of the overlay on desktop; touch and mouse long-press checked in a real window (not only headless, per the project's touch rule). A real phone cannot be run from here, so the first phone numbers come from the user's testers, and I say so.
- `godot --headless --import` after adding a `class_name`, then the full suite and a smoke run.
