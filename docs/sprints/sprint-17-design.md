# Sprint 17 Design: Achievements

**Status:** Proposed, awaiting the user's approval. Branch `sprint-17-achievements`.

Sprint 17 of the wishlist (`docs/release-planning/future-roadmap.md`, item 2). Scope comes from the user's answers in conversation; decisions marked "my call" are mine and open to correction.

## 1. Intent

Give the player goals to hunt for and a reason to keep beating bosses: **12 achievements** that unlock as they play, shown on a screen reachable from the home screen, with a small toast when one unlocks. Beating a boss also earns a **starting spell** that resembles it, in a slot of its own. The game already has strong systems for run statistics, levels, bosses and saving; this sprint adds the goals on top without changing how any of them play.

**The 12 achievements (user decisions)**

| Group | Achievements | Reward |
|---|---|---|
| Bosses (3) | Defeat the Tempest Dragon, the Ember Titan, the Dire Minotaur | A starting spell each (below) |
| Level (4) | Reach level 5, 10, 15, 20 | Badge only |
| Gold (1) | Earn 1000 Gold in total, over all runs | Badge only |
| Survival (4) | Survive 5, 10, 15, 20 minutes in one run (any map) | Badge only |

**Boss spells (user decision on slots, my proposal on the spells).** Each boss's spell resembles it and sits in a fixed slot, tied to the level that unlocks the slot (levels 10, 15, 20), so a maxed account looks the same for everyone:

| Boss | Slot (unlocks at) | Spell (my proposal) | Why |
|---|---|---|---|
| Tempest Dragon | 3 (level 10) | Thunder **Zone** | strikes landing on the ground, like its lightning |
| Ember Titan | 4 (level 15) | Fire **Wave** | a rolling wall of flame, like its slam |
| Dire Minotaur | 5 (level 20) | Land **Line** | a piercing rush, like its charge |

A reward is applied at the start of the **next run** (the same rule as every starting-spell reward) and only if its slot is already unlocked; otherwise it waits and appears the first run after the player reaches the level. It only ever fills an **empty** slot at run start, so it can never replace a crafted spell.

**Goals**
- All 12 are visible on the achievements screen from the start, **earned ones in colour and unearned ones with a greyed-out icon**, each with its goal text and (for bosses) its reward line, so a player knows what to hunt for.
- A toast reads "Achievement unlocked: defeat the <boss>" (the same shape for every kind: "reach level 10", "survive 10 minutes", "earn 1000 Gold").
- Achievements are **data**: adding one later is a new `.tres` plus a catalog entry, with no code change (the project's rule for scrolls, enemies, bosses and maps).
- They persist in the save, and unlock from events the game already announces, without any gameplay code calling into the achievement system.

**Two consequences settled after a builder check (my calls, open to correction)**
- **A fully rewarded player has no empty slot.** At level 20 with all three bosses beaten, a run starts with five spells (Fire Missile, the second spell, and the three boss spells), so every spell crafted at a Lectern replaces one of them. I accept this: crafted spells and the replaced starters both last only one run (the starters return next run), so the player simply chooses which starter to give up, and nothing is lost for good. No setting to decline a reward is built.
- **Balance target for the boss spells.** "In line with the Sea Cone" means the same *output*, not the same per-hit numbers: each new spell's modelled damage per second against a group of 8 and its damage per pool must be within 1.5 times the Sea Cone's, using the Sprint 14b audit's model (a Zone hits every tick and the audit found Zones at 5x to 6x the median, so the Thunder Zone's per-hit damage will be much lower than the Sea Cone's). The numbers are reported and then tuned by play.

**Non-goals (this sprint)**
- Mechanical rewards for the level, Gold and survival achievements (the user: not all need one). A small Gold bonus for survival was floated and is **not** built; it can be a later sprint.
- More Gold or kill-count tiers, map unlocks (all maps are open from the start, a user decision in 16a), statistics screens, an achievement for crafting or potions, share or leaderboard features.
- Changing slot unlock levels, boss data, the level track or the starting spells.

**Anti-goals** (a failure even if it technically works)
- An achievement that unlocks twice, loses progress on a restart or a crash, or fires while the game is paused (the run clock must freeze).
- A reward spell put in a locked slot, or one that replaces a crafted spell.
- Any gameplay system (spawner, director, progress, player) that needs to know achievements exist.
- A test that touches the player's real save, or one that really changes scene.
- Boss spells so strong that the starting kit stops mattering (balance is checked and reported, tuned by play).

## 2. Approaches

- **A. Data-driven achievements with a condition type (chosen by the user).** Each achievement is a `.tres` with a name, an icon, one condition (boss defeated, level reached, lifetime Gold, seconds survived) and an optional reward (a spell and a slot). One tracker listens to events the game already announces, decides what unlocks, saves it and raises the toast. Matches how levels, scrolls, bosses and maps are built.
- **B. Hard-code each achievement.** Fastest for 12, but every new one edits code in the run scene, and it breaks the "rules live in data" convention.
- **C. Saved lifetime counters with achievements as thresholds.** Flexible for later "kill 1000" goals, but it builds a statistics system nobody asked for and puts more in the save. Counters can be added later as a new condition kind.

## 3. Decisions

| Area | Decision |
|---|---|
| Data | `AchievementData` (`resources/achievements/`): `id`, `display_name`, `description` (the goal line), `kind` (BOSS, LEVEL, GOLD_TOTAL, SURVIVE_SECONDS), `threshold` (level, Gold or seconds; unused for BOSS), `boss_id` (BOSS only), `icon` (a sprite name), `reward_spell` (a `SpellData`, optional) and `reward_slot` (3 to 5, with a spell). `AchievementCatalog` lists the 12 in screen order. `problems()` reports a bad entry (no id, a duplicate id, a threshold at or below 0, a BOSS with no boss id, a reward slot outside 3 to 5 or used twice, a spell that cannot cast). |
| Tracker | `AchievementTracker` (`scripts/progression/`, a plain node like `RunStats`) is created per run by `Main`. It only **listens**: `EnemySpawner.boss_died(boss, number)` (the boss's `data.id`), `RunProgress.leveled_up(level, reward)`, Gold added through `RunProgress.add_gold`, and the run clock (a once-a-second check of `RunClock.seconds()`, which freezes while paused). A guard test fails if it is named from gameplay scripts, as with `RunStats`. |
| Rules | Static `AchievementRules.is_met(data, profile, event)` and `unlock(profile, data)`, pure and unit-testable. Unlocking is idempotent: an earned id is never unlocked again. Each unlock calls `ProfileSaver.save_now()` so a crash cannot lose it, then emits `unlocked(data)`. |
| Save | `PlayerProfile` gains `achievements: Array[StringName]` (earned ids) and `lifetime_gold: int`, both **optional** fields (version stays 1, like `bests`), range-checked like every field (a bad value is a bad save). Unknown ids (an achievement removed later) are kept and ignored. `lifetime_gold` rises whenever Gold is collected through `RunProgress.add_gold` (coins, chests, merchant-scroll Gold, boss rewards); it never falls when Gold is spent. New game erases them with the rest of the save (my call: consistent with "erases progress"). |
| Old saves | On load the tracker's `sync` unlocks, **silently (no toast)**, what the save already proves: level achievements from the level, survival achievements from the best survival over all maps; `lifetime_gold` starts at the current Gold (the best known figure). Boss achievements start from zero (my call). |
| Reward | Static `AchievementRewards.apply(loadout, profile, catalog, track, level)`, called by `RunStart.prepare` after the level spells: for each earned achievement with a reward whose slot is unlocked **and empty**, equip a fresh full-mana `SpellInstance` of the reward spell (no starting buffs: those belong to the two level-reward spells, my call). Never mid-run. |
| Spells | Three new `SpellData` `.tres` (`thunder_zone`, `ember_wave`, `land_line`) in `resources/spells/`, authored like `sea_cone.tres` (own pool and cost, a per-spell element look), numbers set by the audit and tuned by play. Starting values: a pool of 1000 mana and a cost like the Sea Cone's, with damage and cast interval set so the output matches the balance target above. |
| Toast | `AchievementToast` (`scripts/ui/`, themed `HudToast`): one pooled node, a queue so several unlocks show one after another (about 3 s each), count `_process` time so it freezes while paused, ignores touches. Text from the data: "Achievement unlocked: <description>". A new short sound `achievement` (a chime; the audio pipeline, **not judged by ear**, the user auditions it). |
| Screen | `AchievementsScreen` (a child scene of `home.tscn`, process Always, `TouchBridge` for touches, Esc or back closes, a 300 ms input guard, explicit focus neighbours, like `TutorialScreen`). A 2-column grid of 12 cards (icon, name, goal text, and the reward line for bosses such as "Reward: Thunder Zone in slot 3 (level 10)"), a count "n of 12" and a Close button of at least 72 by 28. Earned cards are coloured, unearned ones grey with a greyed icon (the icon tinted, not a second sprite). Read-only. |
| Home | A small **Achievements** button at the top left (the Full screen button's mirror, 100 by 28), because the five main buttons already fill the 270 px height (my call). |
| Art | Icons are 16 by 16 white sprites (so the tint greys them), made in the art pipeline: a star (level), an hourglass (survival), a coin (Gold) and three boss heads (Dragon, Titan, Minotaur). Bright, simple, cartoon (the user's art taste), compared in contact sheets. |
| Docs | A new section "Achievements (Sprint 17)" in `docs/architecture/progression-and-economy.md` (with its heading added to `tests/fixtures/claude_md_sections.txt`), a line in the `CLAUDE.md` index summary, `development-log.md`, `sprint-development.md` (mark 17 done). |

## 4. What is left to the builder
- The exact numbers of the three boss spells within the rules above, the exact pixel art of the six icons, the layout of the card grid inside the 480 by 270 screen, the toast's look, the achievement chime's recipe.
- How `AchievementTracker` is fed Gold events (a signal on `RunProgress`, or `PickupCollector.gold_collected`, whichever the code already has) without gameplay code calling it.

## 5. Verification plan
- **Rules and tracker:** each condition kind unlocks at its threshold and not before; a boss unlocks only for its own id; an earned achievement never unlocks twice (also across two runs and after a save round trip); the survival check does not advance while paused; level 20 unlocks 5, 10, 15 and 20 together in order; several unlocks at once queue their toasts.
- **Save:** both fields round-trip; an old save (no fields) loads and `sync` grants the level and survival ones silently; a wrong type, a negative or out-of-range value is a bad save; unknown ids are kept; New game erases both; no test touches the real save.
- **Rewards:** at run start the boss spells fill only unlocked, empty slots (a level-9 player gets none; a level-10 player with the Dragon achievement gets slot 3); a crafted spell is never replaced; no starting buffs are applied; two instances never share mana.
- **Catalog and data:** 12 unique ids; every boss id exists in some map's roster or the default roster; reward slots are 3, 4, 5 and unique; every reward spell is castable; a new achievement `.tres` appears on the screen with no code change.
- **Screen and toast:** 12 cards, earned in colour and unearned greyed; the count line; the reward line; Esc, back and a tap outside close; focus works; a touch and a mouse each act exactly once (checked in a real window, as in 15a and 16a); the toast shows its text, queues, freezes while paused and never takes a touch.
- **Guards and art:** the tracker is named only by `Main` and its own tests; a test fails if the home script names `main.tscn`; art tests (palette, margins, frame counts) cover the six icons; the sound catalog test covers `achievement`.
- **Balance and performance (reported, not asserted):** the spell audit's damage per pool for the three new spells against the Sea Cone and the crafted median; the soak test and a stress run show no change.
- **Real window:** a boss defeat in a forced run shows the toast and the screen shows the card in colour; the full flow from a clean throwaway `HOME`.
