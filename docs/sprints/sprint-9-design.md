# Sprint 9 Design: Gold, Equipment and the Shop

**Status:** Built (Sprint 9).

Scope comes from `sprint-development.md` (Sprint 9) plus one change the user asked for: **starting-spell buffs are asked for or re-rolled every run instead of being saved** (player feedback). Architecture follows `technical-design.md` (sections 10 and 11), `CLAUDE.md` and `sprint-0` to `sprint-8-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Sprint 8 made the wizard stronger across runs through levels. Sprint 9 adds the second reason to keep playing: **Gold**. Enemies drop it, dying never costs you what you collected, and between runs you spend it on equipment that changes how the next run plays (more element damage, a faster Wand, a hard-hitting Staff). The between-run loop becomes: die, see what you earned, shop, restart stronger and differently.

**Goals**
- Enemies drop Gold coins that the player collects. Gold is banked as it is picked up and saved with XP.
- Equipment is data: Robe, Wand, Staff, Hat and Hood definitions in a catalog. The player buys, equips and swaps them in a shop on the death screen, and the choices persist.
- Every modifier goes through one central path (`StatBonuses`, the one Sprint 8 built for levels), never directly into player stats.
- Element damage bonuses, spell damage, casting speed, and one chance effect for Wands (cast twice) and for Staffs (double damage) all work, without changing any shared `SpellData`.
- Starting-spell buffs: a chosen buff is picked at every run start and a random buff is re-rolled every run. Nothing about them is saved.
- The crafting preview shows real numbers (pool, casts, damage and interval) including level and equipment bonuses.

**Non-goals (later sprints)**
- Potions and consumables (Sprint 10), bosses and boss damage (Sprint 11), the main menu (Sprint 15), selling items, rarity, equipment art, set bonuses.
- The other Wand and Staff effects in the README: free casts, reduced mana cost, longer range, faster projectiles, bigger areas, longer duration, boss damage. This sprint ships one effect each and the data shape to add the rest (user decision: "we can expand later").

**Anti-goals** (a failure even if it technically works)
- A bonus written into a shared `SpellData` or `EnemyData`, or code that branches on an equipment id, a buff id or a level.
- A purchase that spends Gold and does not grant the item, grants it twice, or can be made without enough Gold. Equipped items the player does not own.
- Gold lost on death, a shop reachable in the middle of a run, or a death-screen tap on the Shop button that also restarts the run.
- Copy-pasting `XpGem` and `XpDropper` into Gold twins instead of reusing that code.
- A save that crashes on a missing, extra or wrongly typed field. Tests that touch the real save.

## 2. Decisions

| Area | Decision |
|---|---|
| Where the shop lives (user) | **On the death screen.** After death the player sees "+N XP, +N Gold this run", a **Shop** button and the usual restart. Closing the shop returns to the death screen. The shop cannot be opened during a run, so equipment changes take effect at the next run. Sprint 15's menu can move it later. |
| Starting-spell buffs (user, player feedback) | **Chosen buffs are picked at every run start, random buffs are re-rolled every run, and nothing is saved.** The level table is unchanged: levels 7 and 17 are random rewards and levels 12 and 19 are chosen ones. At run start, `Main` rolls each earned random reward and asks (on the existing pick screen, world paused) for each earned chosen reward, in level order. The picks live only in memory for that run. `buff_picks` leaves the save: old files still load (the field is ignored) and lose it the next time they are saved. Stack caps count the buffs already given to that spell in this run. A run-start notice names each rolled buff. Reaching level 7 mid-run no longer rolls anything, because the roll happens at the next run start. |
| Gold drops (my call) | `EnemyData.gold_reward`: plain 1, Fire 1, Thunder 1, Sea 2, Land 3. Gold coins are passive pickups collected by the existing `PickupCollector`, capped at 150 with a merge-into-the-oldest at the cap (no Gold is lost), exactly like XP gems. The pickup and dropper code is shared with XP gems, not copied. |
| Gold banking (my call) | Banked into the profile the moment a coin is collected, saved with the same dirty flag, periodic save, and save on death. HUD: a "Gold N" counter near the XP bar. Death screen: "+N Gold this run". |
| Equipment data | `EquipmentData` (Resource): id, display name, description, `category` (ROBE, WAND, STAFF, HAT, HOOD), price, `modifiers` (a list of `EquipmentModifier`: a stat and an amount), a placeholder colour (the icon stand-in). `EquipmentCatalog` (Resource) lists every item. Adding an item is a new `.tres` plus a catalog entry. |
| Slots | Three: **Robe**, **Weapon** (a Wand or a Staff, one at a time) and **Headwear** (a Hat or a Hood, one at a time). Hats and Hoods share behaviour and differ only in name and colour (README). |
| One modifier path | `StatBonuses` gains stats: element damage (Fire, Thunder, Land, Sea), spell damage, casting speed, cast-twice chance and double-damage chance, next to speed, health and spell mana. Level rewards and equipped items both add into one `StatBonuses`, and `Player.apply_stat_bonuses` pushes it to the player and the loadout. Mid-run level-ups must keep the equipment's bonuses (they are recomputed as level plus equipment). |
| Damage scale (Approach 1, user) | `SpellLoadout.try_cast` computes a `damage_scale` for the cast and sets it on each effect before `launch`. `AreaEffect._configure_hitbox` multiplies it into the hit damage. `launch` is unchanged, no Area is edited, and `SpellData` is never touched. The scale is (1 + spell damage) times the mean over the spell's elements of (1 + that element's bonus) (the mean matches how a hybrid's other stats are averaged, my call), times 2 on a double-damage roll. It never goes below 0.1. |
| Casting speed | `SpellInstance` carries an interval scale (like the mana bonus, per instance, never on `SpellData`). The cooldown after a cast is `cast_interval / (1 + casting speed)`, never below 0.05 s. |
| Wand effect (my call) | **Chance to cast twice.** On a successful cast the shots are launched a second time at once, for the same mana, without lengthening the cooldown. Rolled once per cast. |
| Staff effect (my call) | **Chance to deal double damage.** Rolled once per cast and doubles the damage of every shot in that cast (rolled per cast, not per hit, to keep it simple and testable). The loadout takes an injectable random generator so tests are deterministic. Chances are clamped from 0 to 1. |
| Catalog, starting numbers (my call, tune by playing) | **Robes:** Ember, Storm, Stone and Tide Robes, each +15% damage for one element (Fire, Thunder, Land, Sea), 100 Gold; Warded Robe, +30% max health, 120 Gold. **Hats and Hoods** (identical stats, different names and colours): Mana +10% spell mana, Swift +10% movement speed, Hardy +20% max health, 80 Gold each (six items). **Wands:** Quickwand, +25% casting speed, -15% spell damage, 10% cast twice, 200 Gold; Flickerwand, +40% casting speed, -30% spell damage, 15% cast twice, 350 Gold. **Staffs:** Oak Staff, +25% spell damage, -15% casting speed, 10% double damage, 200 Gold; Elder Staff, +45% spell damage, -30% casting speed, 15% double damage, 350 Gold. That is 15 items and about 1 to 2 runs of Gold for the cheapest. |
| Buying and equipping | One static `ShopSystem` holds the rules, like `CraftingSystem`: `buy` checks the item exists, is not owned and is affordable, then spends the Gold and grants it all or nothing, and equips it into its slot (the replaced item stays owned). `equip` and `unequip` work on owned items for free. Every action is saved at once. A failed action changes nothing and says why. |
| Shop screen (TEMPORARY look) | A one-screen list by category with price, owned and equipped markers, the player's Gold, and Buy, Equip and Unequip buttons. It works with mouse, keyboard, controller and touch (bridged like the crafting screen), and pauses nothing because the world is already over. |
| Save format | The profile gains `gold` (int), `owned` (list of ids) and `equipped` (slot to id). Missing fields default (0, empty, empty), so an old file loads and the version stays 1. Unknown ids are skipped when used. An equipped id that is not owned is dropped on load. `total_xp` and `gold` above 2^53 are rejected (a hand-edited save cannot overflow). Still renamed to `.bak` when unusable, never deleted. |
| Equipment at run start | `RunStart` applies level bonuses plus the equipped items' bonuses before the starting spells are equipped, so every spell starts with the mana bonus. |
| Crafting preview | `CraftingSession` and `CraftingScreen` show the new spell's pool, casts, damage and interval including the loadout's current bonuses (mana, damage scale, casting speed). The numbers describe what the cast will really do. |

## 3. Approaches considered

1. **Extend `StatBonuses`, scale at the effect (chosen).** One new field on `AreaEffect`, one multiplication in the single place Areas build hit damage, an interval scale on `SpellInstance`. Reuses the modifier path the docs ask for.
2. **Build a modified `SpellData` copy per cast.** Easy to reason about but allocates a resource per cast and loses the cached attack profile, which hurts with 300 enemies.
3. **Carry bonuses on the attack profile and apply them at the hurtbox.** Keeps element bonuses near the damage rules, but the profile is cached per spell, and per-cast values would break the cache.

For the shop, a menu or a shop Lectern in the arena were considered and dropped (no menu exists until Sprint 15, and a mid-run shop breaks "between runs"). For the effects, "stats only" and "everything in the README" were considered. The first leaves Wands and Staffs without character, and the second is large with no bosses to test boss damage against.

## 4. Risks for the builder

- **Death-screen taps.** The death screen listens for any tap in `_input` to restart, and a Shop button must not also restart the run. Taps inside the button must open the shop and be ignored for restarting, and the restart must not fire while the shop is open. Sprint 7's phone bug came from exactly this kind of overlap, so check the behaviour with a real-window script as well as headless tests.
- **Stat recomputation.** `apply_stat_bonuses` is idempotent from base values. Level-ups, run start and equipment must all combine into one `StatBonuses` before applying, or a bonus can be applied twice or lost.
- **Shared pickup code.** `XpGem`/`XpDropper` are generalised for Gold (a value pickup with a kind, and a dropper that reads a reward from the enemy). The collector must report XP and Gold separately.
- **Run-start flow.** The pick screens now run on every start, and a restart shows them again. A level-19 wizard sees two screens each run. Keep `Main._begin_progression` synchronous when nothing is owed, as today.
- **Casting twice.** The second launch must not spend mana, add cooldown or roll again, and ground-targeted Areas (zones) are launched twice too. Check the physics cost of doubled zones.
- **Perf.** Another 150 passive pickups cost about 1.8 ms a frame at the stress test's rate (Sprint 8's measurement for XP). Measure with both gems and coins, and note `max` caps are exports.

## 5. Docs this sprint updates

`sprint-development.md` (Sprint 9 boxes, a Built note, the buff-change note on Sprint 8), `README.md` (the buff-each-run rule in 6.1, the equipment numbers), `technical-design.md` (save format), `CLAUDE.md` (a Sprint 9 section, F-keys if any change, the buff rule), `development-log.md`, and the Sprint 8 design doc gets a short note that its "random buff is saved" rule was replaced.
