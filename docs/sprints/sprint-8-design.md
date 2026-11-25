# Sprint 8 Design: XP, Levels and Saving

**Status:** Built (Sprint 8). Note: Sprint 9 replaced the "a random buff is rolled once and kept, a chosen buff is picked once and kept" rule: starting-spell buffs are now re-rolled or picked again at every run start and are never saved. Level 1 is the starting level and gives nothing (user).

Scope comes from `sprint-development.md` (Sprint 8) plus one change the user asked for: **the save system moves here from Sprint 9**, because levels are permanent. Architecture follows `technical-design.md`, `CLAUDE.md` and `sprint-0` to `sprint-7-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Until now every run starts from nothing. Sprint 8 gives the game its rogue-lite spine: enemies drop XP, XP raises a **permanent wizard level** (20 levels, README 6.1, where level 1 is where everyone starts), and each level gives a fixed reward. The level survives death and closing the game, so a run that ends badly still leaves the wizard stronger.

**Goals**
- Enemies drop XP gems, the player collects them, XP accumulates, and level-ups happen at the right thresholds.
- Every reward from level 2 to level 20 works: movement speed, health, spell max mana, spell slots (1 to 5), starting-spell buffs (random and chosen) and a second starting spell.
- XP and level persist between runs and between sessions (desktop, web and phone), through a small save system that Sprint 9 will reuse for Gold and equipment.
- The HUD shows XP, level, progress to the next level and level-up notices. Locked and unlocked slots already show in the spell bar.

**Non-goals (later sprints)**
- Gold, equipment, potions (Sprint 9 and 10), a main menu, a "reset progress" button or several save profiles (Sprint 15), XP magnets, levels above 20, final art.

**Anti-goals** (a failure even if it technically works)
- A `match` on the level number anywhere in code. Rewards are data.
- Bonuses written into a shared `SpellData` or `EnemyData` resource (two copies of a spell must never share state).
- A damaged, missing, old or hand-edited save that crashes the game, or that is replaced by a blank one without keeping the broken file.
- XP that is thrown away at the gem cap, or a level-up that interrupts a fight with a menu.
- Tests that read or write the player's real save file.

## 2. When rewards apply (user decision)

| Reward type | When it takes effect |
|---|---|
| Speed, health, max mana, spell slots | **Right away** when the level is reached, with a notice. Every later run starts with them already applied. |
| Starting-spell rewards (random buff, chosen buff, second spell) | **At the start of the next run.** They change what you *begin* with, so the spell in your slot is not touched mid-run. |
| Random buff | Rolled **at level-up** and stored in the save, so it is permanent and cannot be re-rolled by quitting. The notice says what you will start with. |
| Chosen buff | Owed after the level-up. A small pick screen appears at the next run start (before the run begins, game paused), so nothing interrupts a fight. Closing the game before picking just asks again next time. |

## 3. Decisions

| Area | Decision |
|---|---|
| Structure | **Data-driven, no new autoload** (user choice). `LevelTrack` (Resource) holds 20 `LevelReward` entries (a reward type, an amount, or a buff target). `PlayerProfile` (RefCounted) holds total XP and the starting buffs. `SaveGame` (static) reads and writes it. `StatBonuses` (RefCounted) sums the stat rewards. `RunProgress` (Player component) collects XP and levels up. `RunStart` (static) sets up a run. No code branches on a level number. |
| Save file | One JSON file in `user://` (outside the repo, in Godot's per-project user-data folder, so it also works in the web build and on a phone). Fields: `version`, `total_xp`, `starting_buffs` (buff ids per starting spell). Save and load take a **path argument**, so tests use a throwaway folder. Written to a temporary file and then renamed, so a crash mid-write cannot destroy the old save. |
| Bad saves | Every field is type-checked on load. Missing file means a fresh profile. An unreadable file, wrong shape or a newer `version` is **renamed to `.bak`** (never deleted) and a fresh profile starts. Unknown buff ids (a buff removed later) are skipped. |
| When it saves | On level-up, on death, every 10 seconds while the XP has changed, and when the window closes. Browsers and phones don't always send a close notice, so the periodic save is what covers them. |
| XP and level | Total XP is the only stored number. The level is computed from it by the track, so the two can never disagree. XP counts up forever, the level stops at 20 and the bar shows "MAX". Several level-ups from one pickup apply in order. |
| XP curve (my call, tune by playing) | The track stores the cumulative XP needed for each level. Starting numbers: reaching level 2 needs 30 XP and each next level costs 20 more than the one before (so level 20 is at 3,990 XP in total). That is a few good runs for the first reward and about 4 to 8 runs to finish the track. The track holds levels 2 to 20 (19 rewards). |
| XP drops | `EnemyData.xp_reward` (the field already named in `technical-design.md`). My call: plain 5, Fire 4, Thunder 4, Sea 6, Land 10. An `XpGem` pickup is passive like a scroll pickup, and the player's existing `PickupCollector` collects both kinds. The gem count is capped (150). At the cap a new gem's value is **added to the oldest gem** instead of being dropped, so no XP is lost. |
| Level 1 (user decision) | Everyone starts at level 1 with 0 XP, and level 1 gives no reward and no bonus. The README's "Base Level" row for level 1 is dropped (the README is updated), so there is no spell damage bonus and no extra stat for it. Rewards begin at level 2. |
| Stat rewards (my call) | Movement speed +8% per reward (levels 2, 6, 11, 16: +32%). Maximum health +20% of base per reward (levels 3, 8, 13, 18: +80%). Spell max mana +15% per reward (levels 4, 9: +30%). Pools only grow: existing spells gain the same extra mana, new spells start with it, and the cost per cast does not change, so the player gets more casts. A health reward also heals by the amount it adds. |
| Spell slots | Levels 5, 10, 15 and 20 each unlock one slot (README). A run starts with `1 + the slot rewards earned` slots, and a mid-run reward calls the existing `SpellLoadout.unlock_next()`. The F11 debug key is removed because the real system now exists. |
| Starting-spell buffs | Levels 7 and 12 (first spell), 17 and 19 (second spell). They are stored as buff ids in the profile, applied through a new `SpellBuilder` function that returns a **copy** of a spell with buffs folded in (the same rules as crafting). Stacks respect each buff's `max_stacks`. |
| Which buffs can be given (my call) | The five that work on a single element: Increased Max Mana, Increased Damage, Double Vulnerability, Ignore Resistance and Duplicate Area. **Additional Base is left out** of both the random pool and the chosen list, because a starting spell has no second Base scroll to fill the slot. |
| Second spell (level 14, my call) | **Sea Cone**, authored like `fire_missile.tres` (generous 1000-cast pool). It covers the Fire enemy that Fire Missile only hits neutrally. It goes in slot 2, which is already unlocked by then. |
| Debug | A DEBUG key (F12) gives 100 XP, to delete when real play replaces it, as with F9, F10 and F11. It writes the real save, so the manual test notes say how to reset it (delete the one file). |
| HUD (TEMPORARY look) | A thin XP bar across the top with "Lv N" ("Lv 1" on a fresh save, "MAX" at 20), a level-up toast ("Level 4! More mana", "Slot 2 unlocked", "Next run: Fire Missile gains Duplicate Area") and a one-line "+N XP this run" on the death screen. The spell bar already dims locked slots. |

## 4. Approaches considered

1. **Data-driven components (chosen).** A track of reward resources, a profile object and static save and run-start helpers. More small files, but each is testable without a screen and Sprint 9 adds Gold to the same profile.
2. **One `Progression` autoload.** One script with XP, levels, saving and a `match` per level. Quicker to write, but it adds an autoload CLAUDE.md says to avoid, is harder to test, and would be rewritten for Sprint 9's equipment.

For XP delivery, instant XP on kill was considered and dropped because the sprint plan asks for drops and pickups, and gems give the player something to move toward.

## 5. Risks for the builder

- **Mana bonuses on live spells.** `SpellInstance` owns its pool. The bonus raises its maximum and current mana together, and a new spell must start with the bonus included.
- **Scene reload on restart.** The death screen reloads the main scene, so `RunStart` must be safe to run every time and must not apply a bonus twice.
- **Pause for the pick screen.** It reuses `GamePause`. It needs mouse, keyboard, controller and touch (through `TouchBridge`), like the crafting screen.
- **Perf.** Gems are many small passive areas, like scrolls. The stress test must still hold 60 fps with 300 enemies and drops on.

## 6. Docs this sprint updates

`sprint-development.md` (Sprint 8 gets the save tasks, Sprint 9 notes that the save already exists and only adds Gold and equipment), `CLAUDE.md` (a Sprint 8 section, F11 removed, F12 added), `README.md` (level 1 is the starting level with no reward, plus the reward numbers), `technical-design.md` (save format) and `development-log.md`.
