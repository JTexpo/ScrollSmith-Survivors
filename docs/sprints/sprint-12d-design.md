# Sprint 12d Design: Points of Interest

**Status:** Built (Sprint 12d).

Sprint 12 is four sprints: **12a** the world, **12b** obstacles, **12c** the map's regions (all done) and **12d** points of interest (this doc). Scope comes from the conversation, `sprint-12c-design.md`, `sprint-development.md` and the README (section 9, "Map Exploration"). Architecture follows `CLAUDE.md` and `technical-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The map now has places worth going to (two mazes, an island, a long corridor) and nothing in them. Sprint 12d gives the player reasons to leave the middle and take calculated risks: shrines to heal and to refill mana, chests, Rare scroll spots in the maze centres, and a merchant. The user's play feedback on 12c shapes it: enemy tracking is excellent and the mazes already punish waiting inside them with HP loss, so a Rare scroll in a maze's centre room is a real risk.

**Goals (user decisions)**
- **Everything refreshes after a delay**, so players are pushed to keep moving. A point of interest is used, then empty for a few minutes with a visible timer, then ready again.
- **Shrines and chests are free.** The trip (and the danger of the place) is the price. **The merchant is the only place that costs Gold.**
- **The merchant sells potions only.** A potion is carried between runs, so a purchase is never wasted by dying (the reason scrolls were ruled out, because they do not persist).
- **One generic point of interest driven by data** (approach 1): a new shrine is a new `.tres`, with no new code.
- Five kinds placed on the first map: Health Shrine, Mana Shrine, Treasure Chest, Rare scroll spot, Merchant.

**Non-goals (later sprints)**
- Selling scrolls, equipment or run-only blessings at the merchant.
- Points of interest that scale with run time, spawn at random, or are destroyed. Boss arenas (the README lists them).
- A game mode built around one massive maze (the user's idea for later). Placements stay data-driven so it carries over.
- Final art, sound and animation (Sprint 13), and zone-specific enemy spawning.

**Anti-goals** (a failure even if it technically works)
- Using one twice before it refreshes, or a refused use (a Health Shrine at full health) that consumes it or starts its timer.
- A refresh timer that runs while the game is paused, or one that survives into the next run. Every point of interest starts each run ready.
- A merchant sale that takes Gold without handing over the potion, sells below zero stock, or lets Gold go negative (the existing `ShopSystem` is all-or-nothing, and the merchant must keep that).
- Code that branches on a point of interest's name or id. Behaviour comes from its `kind` and numbers.
- A point of interest inside an obstacle or in a pocket nobody can reach, or one that blocks a maze or island route.
- Loot dropping into a wall, or a Rare scroll lost because the pickup cap evicted it at once.

## 2. Decisions

| Area | Decision |
|---|---|
| Data (user: approach 1) | `PointOfInterestData` (Resource, `resources/points_of_interest/`): `id`, `display_name`, `kind` (HEAL, RESTORE_MANA, LOOT, MERCHANT), `amount: float` (a fraction, used by HEAL and RESTORE_MANA), `gold_min` and `gold_max` and `scroll_count` and `scroll_table: DropTable` (used by LOOT; a Rare scroll spot is a LOOT with no Gold and the Rare-only table), `stock_per_potion: int` and `price_multiplier: float` (used by MERCHANT), `refresh_seconds: float`, `color: Color`. |
| The node | `PointOfInterest` (`Area2D` on the interactable layer, like a Lectern, in the group `points_of_interest`). It holds the shared behaviour only: the "press E" prompt, the ready or refreshing state, a refresh timer counted in `_process` (so it freezes while paused), and a ring that fills while it refreshes. `interact(actor)` emits `used(point, actor)` and nothing else. Five small scenes in `scenes/interactables/` (Health Shrine, Mana Shrine, Chest, Rare Scroll Spot, Merchant) instance it with their data, so `MapPlacement` needs no change. |
| The rules | `PointOfInterestSystem` (static, like `PotionSystem`): `refusal(data, player) -> String` (empty when allowed: a Health Shrine at full health says so, a Mana Shrine when every spell is full, a dead player cannot) and `apply(data, player, rng) -> PointOfInterestResult` (heals the player's `HealthComponent`, refills every spell's pool by `amount` through the loadout, or rolls the loot: a Gold amount and the scrolls). It computes nothing a node needs to know. |
| Who acts on a use | `Main` connects each point's `used` and does the routing, the way it routes enemy deaths and Lecterns today: a refusal shows its reason in the level toast and changes nothing; a HEAL or RESTORE_MANA is applied and the timer starts; a LOOT adds the Gold through `RunProgress.add_gold` and places each scroll through the existing `ScrollDropper.place` next to the point (a small ring of offsets, so none lands in a wall); a MERCHANT opens the merchant screen. A toast says what happened ("Healed 50%", "+25 Gold", "Found: Fire scroll"). |
| Numbers (my calls, tune by playing) | **Health Shrine:** heals 50% of maximum health, refreshes after 180 s. **Mana Shrine:** restores 50% of every spell's pool (a full refill would end mana scarcity), 240 s. **Treasure Chest:** 20 to 40 Gold and one scroll from a new `chest_drops.tres` (all 15 scrolls, weighted by rarity, Luck applies), 300 s. **Rare scroll spot:** one scroll from the existing Rare-only table (`resources/bosses/boss_scrolls.tres`), 300 s after the last is taken. **Merchant:** potions at 1.5 times the death-screen price (a small premium for buying now, a number in its data), 2 of each potion type in stock, restocking 300 s after the first purchase. |
| The merchant | `MerchantScreen` (TEMPORARY look): a thin layer over `ShopSystem.buy_potion` (given a price multiplier) with a row per potion showing price, stock and what you own, that **pauses the world like the crafting screen** (user did not object) and closes on cancel or pause. A purchase goes into the saved potion stock, and `Main` saves at once (as it does for drinking and shop actions), so quitting cannot undo it. Stock is runtime state held by the merchant (counts, plus the restock timer), never saved. |
| Placement on the first map (my call, tuned by play) | A Rare scroll spot at each maze's cleared centre room (`MapMaze.center_room_center()`: (380, 300) and (1540, 780)). A chest and a Mana Shrine inside the island, clear of both gates. A Health Shrine in the long corridor, and the merchant in the south-west open area, so the trip is the risk. All are `MapPlacement`s, at least 24 px from every wall (the existing `MapData.problems()` already checks placements against shapes), and reachable (the existing check). |
| Time | Timers tick with `_process` delta, so pausing (crafting, the merchant, the pick screen) freezes them with no extra code, and they start ready each run. |
| Touch | A point of interest is used with E, the controller's A button or the existing on-screen Interact button (all already work for anything with an `interact` method). The merchant screen handles its own touches the way the crafting and shop screens do (mouse emulation is off). |
| Overlay | The F7 overlay already marks placements, so the new ones show with no change. |

## 3. Approaches considered

1. **One generic point of interest driven by data (chosen by the user).** One scene and script, a static rules class and a data resource. It matches how potions and enemies already work, and a new kind of shrine is a new `.tres`.
2. **A scene and script per kind.** It reads simply, but the timer, prompt and refusal logic get copied five times and drift.
3. **A base class with a subclass per kind.** It shares code but every new kind needs code, and the project prefers data and composition over inheritance.

## 4. Risks for the builder

- **Balance.** A free Mana Shrine is the one map-based way to restore mana, so its numbers matter most (50% every 4 minutes). Everything is data, so tuning is cheap, but nothing has been played.
- **Scroll pickups.** `ScrollDropper` caps pickups at 100 and a new drop evicts the oldest. A Rare scroll must not be evicted before the player can reach it, and must not land inside a wall (use the placement offsets and check them against the obstacle map).
- **The merchant screen.** It is the only new interactive screen. It must pause the world, handle touch (the crafting screen's touch bridge is the model, and a headless test cannot show a swallowed tap, so it needs the real-window check described in `CLAUDE.md`), refuse a purchase it cannot afford without taking Gold, and close cleanly (`Player.require_cast_release` after, as the crafting screen does).
- **State that must not leak.** Timers and stock are per run and per node. A test must prove two points of interest from one data resource never share a timer, and that a second run starts ready.
- **Reachability and routes.** A point of interest that sits in a corridor (the Health Shrine) must not block it. It is an `Area2D`, so it is not solid, but enemies walk through it, and the prompt must not cover the corridor.
- **Interaction priority.** `InteractionComponent` picks the nearest interactable. A shrine next to a Lectern must still select the nearest.

## 5. Docs this sprint updates

`sprint-development.md` (Sprint 12d ticked, a Built note), `README.md` (the points of interest and their numbers), `technical-design.md` (the new files), `CLAUDE.md` (a "Points of interest (Sprint 12d)" section), `development-log.md`, and the memory file.

## 6. Open questions for the user

None blocking. The numbers, the placements and the merchant's premium and stock are my calls above, so they can be tuned after play. The two boss questions from Sprint 11 and the Sprint 7 ring question are still unanswered.
