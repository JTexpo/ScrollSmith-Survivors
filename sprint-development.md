# Sprint Development Plan

## Project Overview

This document outlines the incremental development plan for the wizard survival roguelite.

Development is divided into focused sprints, with each sprint introducing a specific set of mechanics or improvements.

The goal is to maintain a playable version of the game throughout development rather than attempting to implement every system simultaneously.

### Development Principles

- Each sprint should produce a playable build.
- Prioritize core gameplay before progression and additional content.
- Avoid introducing multiple interconnected systems in the same sprint unless necessary.
- Build systems to be expandable rather than hardcoding individual implementations.
- Test and balance mechanics before building additional systems on top of them.
- Keep development focused on the minimum viable game before expanding its content.

### Important Design Decisions

The following decisions should be treated as established design requirements:

- Spells have limited mana.
- Spells do not naturally regenerate mana.
- Once a spell's mana is depleted, it cannot be cast again unless its mana is explicitly restored.
- Players must move around the map to survive and manage their available resources.
- The visual style is colorful, comedic, cartoon-inspired pixel art.
- The game uses a top-down perspective.
- The game is inspired by the survival and progression mechanics of Vampire Survivors, while emphasizing player-created spells.

---

# Sprint 0: Project Foundation

**Goal:** Establish the project structure and technical foundation.

### Tasks

- [x] Create the game project.
- [x] Configure the target resolution.
- [x] Configure pixel-art rendering and filtering.
- [x] Establish the top-down camera.
- [x] Implement basic scene management.
- [x] Establish input handling for keyboard and mouse.
- [x] Establish input handling for controller/joystick.
- [x] Create a basic player placeholder.
- [x] Create a basic enemy placeholder.
- [x] Establish a reusable entity/component structure.
- [x] Establish a reusable data structure for spells.
- [x] Establish a reusable data structure for scrolls.
- [x] Establish version control and repository structure.

### Deliverable

A blank playable environment containing a controllable placeholder character.

### Completion Criteria

- The project runs without errors.
- The player can be controlled.
- The camera follows the player.
- The project can be built and tested consistently.

---

# Sprint 1: Player Movement and Combat Foundation

**Goal:** Establish the fundamental gameplay experience.

Before implementing spell crafting, the player needs to feel good to control.

### Tasks

#### Player

- [x] Implement player movement.
- [x] Implement movement speed.
- [x] Implement player health.
- [x] Implement player damage and death.
- [x] Implement enemy collision.
- [x] Implement player damage feedback.
- [x] Implement basic knockback.

#### Enemies

- [x] Create a basic enemy.
- [x] Implement enemy movement toward the player.
- [x] Implement enemy collision damage.
- [x] Implement enemy health.
- [x] Implement enemy death.
- [x] Implement enemy spawning.
- [x] Implement configurable enemy spawn rates.

#### Combat

- [x] Create a temporary basic attack.
- [x] Implement damage calculations.
- [x] Implement enemy damage feedback.
- [x] Implement basic combat effects.

### Deliverable

A playable environment where the player can move around, fight enemies, take damage, and die.

### Completion Criteria

- Player movement feels responsive.
- Enemies consistently pursue the player.
- Combat interactions work reliably.
- The player can survive against multiple enemies.
- Enemy spawning can be configured.

### Testing Focus

Spend time adjusting player movement speed, enemy speed, collision behavior, and enemy spawn rates.

These values will influence almost every other gameplay system.

---

# Sprint 2: Base Spell System

**Goal:** Implement the foundation of the spell system.

At this stage, spells are created directly through development tools or predefined configurations. Scroll collection and crafting will come later.

### Tasks

#### Spell Architecture

- [x] Create a reusable Spell data structure.
- [x] Implement spell Base types.
- [x] Implement spell damage.
- [x] Implement spell mana capacity.
- [x] Implement current spell mana.
- [x] Implement mana consumption.
- [x] Prevent casting when mana is depleted.
- [x] Implement spell casting intervals.
- [x] Implement spell cooldowns or casting delays where applicable.

#### Base Elements

- [x] Implement Fire.
- [x] Implement Thunder.
- [x] Implement Land.
- [x] Implement Sea.
- [x] Create configurable elemental damage modifiers.

#### Spell Casting

- [x] Implement basic spell casting.
- [x] Implement spell targeting.
- [x] Implement spell damage application.
- [x] Implement spell visual effects.
- [x] Implement spell impact feedback.

#### Mana

- [x] Implement individual spell mana pools.
- [x] Display spell mana in the UI.
- [x] Prevent spells from casting without sufficient mana.
- [x] Implement explicit mana restoration through test/debug tools.

**Important:** Mana does not naturally regenerate. Once depleted, a spell remains unusable until something explicitly restores its mana.

**Built note:** "spell targeting" is the aim direction, and "spell visual effects" is the element tint on the projectile. The elemental modifier table is built and tested, but it only takes effect once enemies have elements (Sprint 4).

### Deliverable

A player who can cast four different elemental spells, each with its own mana capacity and damage type.

### Completion Criteria

- Each elemental spell can be cast.
- Mana decreases when a spell is used.
- Spells stop working when mana reaches zero.
- Damage is correctly applied to enemies.
- Spells can have different damage and mana configurations.

---

# Sprint 3: Spell Areas and Behaviors

**Goal:** Expand spells beyond their elemental damage type.

This sprint introduces the Area system, allowing spells to behave differently depending on their configuration.

### Tasks

#### Line

- [x] Implement Line targeting.
- [x] Implement directional damage.
- [x] Implement configurable line length.
- [x] Implement configurable line width.

#### Cone

- [x] Implement Cone targeting.
- [x] Implement directional cone attacks.
- [x] Implement configurable cone angle.
- [x] Implement configurable cone range.

#### Area

- [x] Implement targeted Area attacks.
- [x] Implement mouse/joystick targeting.
- [x] Implement area-of-effect damage.
- [x] Implement configurable radius.
- [x] Implement configurable duration.

#### Missile

- [x] Implement projectile spawning.
- [x] Implement projectile direction.
- [x] Implement projectile movement.
- [x] Implement projectile collision.
- [x] Implement projectile lifetime.
- [x] Implement configurable projectile speed.
- [x] Implement configurable projectile range.

#### Wave (added in Sprint 3 at the user's request)

- [x] Implement a wide crescent that travels outward.
- [x] Hit every enemy it passes through once.
- [x] Implement configurable width, speed and range.

#### Spell Configuration

- [x] Allow Base and Area combinations.
- [x] Allow different mana costs for different Areas.
- [ ] Allow different damage values for different Areas.

### Deliverable

A functional spell system supporting all five Area types (Line, Cone, Area, Missile, Wave).

### Completion Criteria

- All five Areas behave as intended.
- Spells can use any Base type with any Area type.
- Area size and range are configurable.
- Mana consumption reflects the configured spell.
- Spells interact correctly with enemies.

**Built note:** every Area is its own scene behind one `launch` call, with defaults in an `AreaData` resource and a per-spell `range_scale` and `size_scale` for Sprint 6 crafting to set. The rule linking range to mana cost is left to the Spell Builder (Sprint 6). The starting loadout is Fire Missile, Thunder Cone, Land Area, Sea Line and Sea Wave. "Spells interact correctly with enemies" is true for damage and knockback. Elemental effects arrive in Sprint 4.

---

# Sprint 4: Elemental Affinities and Enemy Variety

**Goal:** Make elemental spell choices meaningful.

Enemies should have elemental strengths and weaknesses, encouraging players to experiment with different spell configurations.

### Tasks

#### Elemental Interactions

- [x] Implement enemy elemental affinities.
- [x] Implement elemental vulnerabilities.
- [x] Implement elemental resistances.
- [x] Implement neutral damage.
- [x] Implement configurable vulnerability multipliers.
- [x] Implement configurable resistance multipliers.

#### Enemy Variety

- [x] Create a Fire enemy.
- [x] Create a Thunder enemy.
- [x] Create a Land enemy.
- [x] Create a Sea enemy.
- [x] Implement different enemy movement speeds.
- [x] Implement different enemy health values.
- [x] Implement different enemy damage values.

#### Visual Feedback

- [x] Display damage numbers.
- [x] Communicate vulnerability hits.
- [x] Communicate resistance hits.
- [x] Add elemental visual effects to enemies.

### Deliverable

A combat system where choosing the correct elemental spell provides a meaningful advantage.

### Completion Criteria

- Elemental interactions work correctly.
- Enemy affinities are configurable.
- Vulnerabilities and resistances are visually communicated.
- Players can identify which spells are effective against different enemies.

**Built note:** each enemy has one element, with vulnerability and resistance derived from the element table (same element is normal damage). The multiplier applies when a hit lands, and each hit reports vulnerable, resisted or neutral. "Elemental visual effects" is the enemy body tint in the element colour. "Players can identify which spells are effective" is communicated through damage numbers and colours, with no in-game legend yet.

---

# Sprint 5: Spell Scroll Collection

**Goal:** Introduce the primary item collection mechanic.

Players can now discover spell-scrolls during an adventure.

### Tasks

#### Scroll Architecture

- [x] Create a reusable Scroll data structure.
- [x] Implement Base scrolls.
- [x] Implement Area scrolls.
- [x] Implement Buff scrolls.
- [x] Assign scroll categories.
- [x] Implement scroll pickup interactions.

#### Enemy Drops

- [x] Implement enemy scroll drops.
- [x] Implement configurable drop chances.
- [x] Implement scroll drop tables.
- [x] Implement scroll pickup visuals.
- [x] Implement scroll collection feedback.

#### Inventory

- [x] Create a scroll inventory.
- [x] Display collected scrolls.
- [x] Implement scroll stacking where appropriate.
- [x] Display scroll categories.
- [x] Implement inventory limits if required.

### Deliverable

Enemies can drop scrolls, and the player can collect and store them.

### Completion Criteria

- Scrolls drop from enemies.
- Scrolls can be collected.
- Scrolls are stored correctly.
- Different scroll categories are distinguishable.
- Collected scrolls persist for the duration of the run.

**Built note:** 15 scrolls (4 Base, 5 Area including Wave, 6 Buff) are data. Buff scrolls are collectible only: their effects arrive in Sprint 7. Drops come from per-enemy drop tables with themed weights (an elemental enemy heavily favours its own element's Base scroll, never guaranteed). Pickup is automatic by walking over a scroll. The inventory is a per-run component with no limit, and the display is a toggleable temporary panel plus a "+ Fire Scroll" toast.

---

# Sprint 6: Arcane Lectern and Spell Crafting

**Goal:** Introduce the game's defining mechanic: player-created spells.

### Tasks

#### Lectern

- [x] Create the Arcane Lectern entity.
- [x] Implement Lectern interaction.
- [x] Implement the crafting interface.
- [x] Implement player proximity requirements.
- [x] Implement crafting confirmation.

#### Spell Crafting

- [x] Allow selection of a Base scroll.
- [x] Allow selection of an Area scroll.
- [x] Allow optional Buff scrolls.
- [x] Validate spell combinations.
- [x] Calculate resulting spell statistics.
- [x] Calculate resulting mana requirements.
- [x] Generate the resulting spell.
- [x] Consume the appropriate scrolls.
- [x] Allow crafted spells to replace existing spells.

#### Spell Management

- [x] Display currently equipped spells.
- [x] Allow spells to be equipped.
- [x] Allow spells to be replaced.
- [x] Respect the player's available spell slots.
- [x] Display individual spell mana.

### Deliverable

Players can collect scrolls and craft their own spells using Arcane Lecterns.

### Completion Criteria

- Players can craft spells from collected scrolls.
- Crafting rules are enforced.
- Scrolls are consumed correctly.
- Crafted spells function in combat.
- Spell statistics update according to their components.

**Built note:** a static `SpellBuilder` turns a Base scroll, an Area scroll and a range option into a spell (each Area carries baseline numbers and each Base scroll carries multipliers), and a static `CraftingSystem` validates, consumes the scrolls all-or-nothing and equips the spell. The crafting screen is one workbench screen with a live preview beside the spell it replaces, and the world pauses while it is open. The player now starts with one spell (Fire Missile, 1000 casts) and four locked slots, and Sprint 8 will unlock more. Buff scrolls show locked in the screen until Sprint 7. Three Lecterns sit off-screen in the arena.

---

# Sprint 7: Buff System

**Goal:** Introduce additional spell customization.

Buffs allow players to create specialized spells with unique strengths and weaknesses.

### Tasks

#### Buff Implementation

- [x] Implement Increased Max Mana.
- [x] Implement Increased Damage.
- [x] Implement Double Vulnerability Damage.
- [x] Implement Ignore Resistance.
- [x] Implement Duplicate Area.
- [x] Implement Additional Base.

#### Buff Calculations

- [x] Calculate combined spell damage.
- [x] Calculate additional mana requirements.
- [x] Calculate maximum mana.
- [x] Calculate elemental interactions for multiple Base types.
- [x] Calculate duplicated Area behavior.
- [x] Validate buff combinations.

#### Crafting Interface

- [x] Display available Buff scrolls.
- [x] Display active Buffs.
- [x] Preview resulting spell statistics.
- [x] Display additional mana costs.
- [x] Communicate potential drawbacks.

### Deliverable

A complete spell crafting system supporting Base, Area, and Buff combinations.

### Completion Criteria

- All Buffs function correctly.
- Buffs affect spell statistics.
- Mana requirements scale with Buffs.
- Multiple Buffs can be combined.
- The crafting interface communicates the resulting spell.

**Built note:** buffs are data: each Buff scroll carries a `BuffEffect` resource, and `SpellBuilder` folds the stacks into the spell, so a new buff is a new `.tres`. A hit uses the best match of a hybrid's elements. Duplicate Area fires a ring of shots (or a ring of zones around the target). Additional Base opens one more Base slot per stack, with the Base count matching exactly and no repeated element. Crafting is still one screen: a buff row with minus and plus steppers, a multi-select Base column ("Base 2 of 2") and a preview with the drawbacks in plain words. Spells whose cost is above their pool are refused. Balance has not been tested in play.

---

# Sprint 8: XP and Run Progression

**Goal:** Introduce progression during an adventure.

Players should become stronger as they survive and defeat enemies.

### Tasks

#### XP Collection

- [x] Implement XP drops.
- [x] Implement XP pickup.
- [x] Implement XP accumulation.
- [x] Implement XP display.
- [x] Implement level-up thresholds.

#### Leveling System

- [x] Implement the 20-level progression structure.
- [x] Implement movement speed upgrades.
- [x] Implement health upgrades.
- [x] Implement maximum spell mana upgrades.
- [x] Implement spell slot upgrades.
- [x] Implement starting spell bonuses.
- [x] Implement random Buff selection.
- [x] Implement chosen Buff selection.
- [x] Implement starting spell unlocks.

#### Saving (moved here from Sprint 9: levels are permanent)

- [x] Save and load a profile (XP and the chosen buffs) as one versioned file.
- [x] Recover from a missing, damaged or newer save without losing the old file.
- [x] Save on level-up, on death, periodically and when the game closes.

#### UI

- [x] Display current XP.
- [x] Display current level.
- [x] Display XP progress toward the next level.
- [x] Display level-up notifications.
- [x] Display unlocked spell slots.

### Deliverable

A complete XP and leveling system that improves the player throughout an adventure.

### Completion Criteria

- XP is collected correctly.
- Level-ups trigger at the correct thresholds.
- All progression rewards (levels 2 to 20) function.
- Spell slots unlock correctly.
- Starting spell modifications are applied correctly.

**Built note:** XP and level persist between runs (the user's decision), so the save system moved here from Sprint 9. (Sprint 9 changed one rule: starting-spell buffs are no longer saved, a random buff is re-rolled and a chosen buff is picked again every run.) Level 1 is where every wizard starts and gives nothing, so the track holds levels 2 to 20 as 19 `LevelReward` resources on a `LevelTrack`. Enemies drop XP gems (capped at 150, merging into the oldest gem at the cap so no XP is lost). Stat and slot rewards apply at once through one `Player.apply_stat_bonuses`. Starting-spell rewards apply at the next run start: a random buff is rolled when the level is reached and kept, a chosen buff is picked on a small screen before the run, and level 14 adds Sea Cone as a second starting spell. The F11 debug key is gone and F12 gives 100 XP. Balance has not been tested in play.

---

# Sprint 9: Gold and Permanent Progression

**Goal:** Introduce the between-run economy.

Players can now use Gold to purchase equipment that changes their future adventures.

### Tasks

#### Gold

- [x] Implement Gold drops.
- [x] Implement Gold collection.
- [x] Implement Gold accumulation.
- [x] Implement Gold persistence between runs (the save file and profile already exist from Sprint 8, so this adds Gold to them).
- [x] Display Gold collected during an adventure.

#### Equipment

- [x] Implement Robes.
- [x] Implement Wands.
- [x] Implement Staffs.
- [x] Implement Hats.
- [x] Implement Hoods.
- [x] Implement equipment modifiers.
- [x] Implement equipment purchasing.
- [x] Implement equipment selection.
- [x] Implement equipment persistence (also added to the Sprint 8 profile and save file).

#### Equipment Bonuses

- [x] Implement elemental damage bonuses.
- [x] Implement maximum mana bonuses.
- [x] Implement health bonuses.
- [x] Implement movement speed bonuses.
- [x] Implement Wand casting speed bonuses.
- [x] Implement Staff damage bonuses.
- [x] Implement equipment-specific special effects. (One each: Wand chance to cast twice, Staff chance to deal double damage. The rest of the README list is left for later.)

#### Shop Interface

- [x] Create the equipment shop.
- [x] Display equipment descriptions.
- [x] Display equipment prices.
- [x] Display player Gold.
- [ ] Implement purchasing confirmation. (Not built: pressing an item buys it at once and a message says so. A confirm dialog is a later polish.)
- [x] Prevent purchases without sufficient Gold.

### Deliverable

A functional between-run shop and equipment progression system.

### Completion Criteria

- Gold persists between adventures.
- Equipment can be purchased.
- Equipment bonuses apply correctly.
- Equipment selections persist between runs.
- Different equipment creates meaningful gameplay differences.

**Built note:** enemies drop Gold coins (the same pickup and dropper as XP gems), Gold is banked as it is collected and saved with the rest, and a **Shop** button on the death screen opens a shop with 15 pieces of equipment in three slots (Robe, Wand or Staff, Hat or Hood). Every modifier goes through the one `StatBonuses` path that levels use. Element damage, spell damage, casting speed and two chance effects reach every cast through a per-cast damage scale, so no Area and no shared spell data is edited. The crafting preview now shows the real numbers with level and equipment bonuses. Also, at the player feedback of the user, starting-spell buffs are no longer saved: a random buff is re-rolled and a chosen buff is picked again at the start of every run. Balance has not been tested in play.

---

# Sprint 10: Potions and Consumables

**Goal:** Introduce temporary items that provide additional strategic options.

### Tasks

- [x] Create a reusable Potion data structure.
- [x] Implement Health Potions.
- [x] Implement Mana Potions.
- [x] Implement Speed Potions.
- [x] Implement Damage Potions.
- [x] Implement Invulnerability Potions.
- [x] Implement Luck Potions.
- [x] Implement potion purchasing.
- [x] Implement potion inventory. (Sprint 10 saved a stock carried into every run; since Sprint 14b potions last one run, at most 3 of each, in an in-memory `RunPotions`.)
- [x] Implement potion usage.
- [x] Implement potion duration.
- [x] Implement potion cooldowns or usage restrictions. (A cooldown per type, a 1 s shared cooldown, and refusals that keep the potion.)

### Deliverable

Players can purchase and use consumables during an adventure.

### Completion Criteria

- Potions apply their intended effects.
- Potions are consumed correctly.
- Temporary effects expire correctly.
- Mana Potions can restore depleted spell mana.
- Potion effects are communicated through the UI.

**Built note:** potions are data (`PotionData` in a `PotionCatalog`), bought one at a time in the death-screen shop and carried as a saved stock. A potion bar shows each type with its count, cooldown and remaining effect time, and drinking is a key (Z X C V B N), a controller button (X, left stick click, B), a click or a tap. Health and Mana are instant, Speed, Damage and Luck are timed stat bonuses, and Invulnerability is a timed window on the hurtbox. A refused potion (none left, cooling down, effect running, full health, full mana, dead) is never consumed. The Player now holds three bonus layers (level, equipment, temporary) and one `refresh_bonuses`, and luck weights scroll drops by rarity. Balance has not been tested in play.

---

# Sprint 11: Enemy Variety and Boss Encounters

**Goal:** Introduce more challenging combat encounters.

### Tasks

#### Enemy Archetypes

- [x] Implement Swarmers.
- [x] Implement Chasers.
- [x] Implement Ranged Enemies.
- [x] Implement Tanks.
- [x] Implement Exploders.
- [x] Implement Support Enemies.
- [x] Implement Elite Enemies.

#### Bosses

- [x] Create a boss architecture. (`BossData`, `BossPhase`, `BossAttack` and one `Boss` state machine.)
- [x] Implement boss health.
- [x] Implement boss-specific attacks. (Slam, Charge, Burst and Summon, all telegraphed.)
- [x] Implement attack patterns.
- [x] Implement multiple attack phases.
- [x] Implement boss spawning. (One boss, the Ember Titan: the architecture takes more, only one ships.)
- [x] Implement boss rewards.
- [x] Implement boss death and encounter completion.

#### Difficulty

- [x] Implement enemy health scaling.
- [x] Implement enemy damage scaling.
- [x] Implement enemy spawn scaling.
- [x] Implement elite enemy spawn rates.
- [x] Implement timed encounters.
- [x] Implement boss encounter intervals.

### Deliverable

A variety of enemies and at least one fully functional boss encounter.

### Completion Criteria

- Enemy archetypes behave differently.
- Boss encounters require active player movement.
- Difficulty increases over time.
- Boss rewards function correctly.

**Built note:** an enemy is now an archetype (the role and every stat) plus an element (affinity, colour, drops), picked independently, so a Thunder Tank or a Sea Swarmer comes out of the same pieces and an element never changes a stat (user decisions). The seven archetypes are Standard, Swarmer, Chaser, Tank, Ranged, Exploder and Support, with Elites as a modifier on any of them, and they unlock over run time. Ranged enemies fire projectiles, Exploders fuse and blast, Support enemies heal others, and every danger is telegraphed. A `DifficultyCurve` raises health, damage, speed, spawn rate and elite chance with run time, and a `RunDirector` brings an Ember Titan at 5 minutes and every 5 minutes after, each tougher, with two phases, a vulnerability window after its charge, XP, Gold and Rare scroll rewards. The run continues after a boss (user decision). The Staff's boss damage was left out. Balance has not been tested in play.

---

# Sprint 12: World Design and Exploration

**Goal:** Make the world more interesting to explore.

**Split into four sprints (user decision):** **12a** the world (map as data, a bigger map, boundaries, placement, decorations, map-specific spawns), **12b** obstacles (they also break up wide circling), **12c** the map's regions (a maze, a walled island, a corridor, zone tints) and **12d** points of interest (chests, shrines, merchant, rare scroll spots, with refresh timers). Items are tagged with the sprint that builds them.

### Tasks

- [x] Create the first playable map (12a).
- [x] Implement environmental boundaries (12a).
- [x] Implement environmental obstacles (12b).
- [x] Implement treasure chests (12d).
- [x] Implement Arcane Lectern placement (12a).
- [x] Implement Health Shrines (12d).
- [x] Implement Mana Shrines (12d).
- [x] Implement merchant encounters (12d).
- [x] Implement rare scroll locations (12d).
- [x] Implement environmental decorations (12a).
- [x] Implement map-specific enemy spawn configurations (12a).

### Deliverable

A complete playable environment with points of interest that encourage exploration.

### Completion Criteria

- The player has reasons to explore.
- Points of interest are distributed throughout the map.
- Environmental obstacles interact correctly with movement and combat.
- The map supports the intended survival gameplay.

**Built note (12a):** the map is data (`MapData`, with `MapPlacement`s) and a `GameMap` scene builds the floor, boundary walls, decorations and placed scenes from it. The first map is 1920×1080 (four screens by four, user decision) with three Lecterns spread far apart, and `Main` hands its bounds to the spawner and camera. Decorations are a seeded scatter and F7 shows a debug overlay of the bounds and placements. Nothing blocks movement except the outer wall yet, so a bigger map alone makes wide circling easier until 12b. Balance has not been tested in play.

**Built note (12b):** obstacles are data (`MapObstacle` rectangles and circles in `MapData`) that block movement and enemy projectiles but never the player's spells (user decision, Missile blocking rejected). Enemies, the boss and enemy shots find them through an `ObstacleMap`, and enemies route around them with a flow field: a coarse grid swept outward from the player, rebuilt a few hundred cells a frame as the player moves, so nobody gets stuck behind a wall or in a dead end. The first map has 27 obstacles: five pillar clusters for small loops, three corridor pairs, a U-shaped dead end, a short wall by each Lectern and an open centre. F7 also shows the blocked cells and the field. Balance and the layout have not been tested in play.

**Built note (12c):** the first map gained regions. Two seeded mazes (`MapMaze`, 9 by 6 cells each, in opposite corners, the second an exact half-turn image of the first, with loops, a cleared centre room and three entrances), a walled island with two gates, a 560 px corridor along the bottom, and floor tints and decorations per zone (`MapZone`). The new walls are ordinary obstacles, reached through one list (`MapData.solid_shapes()`), so enemy routing, projectiles and spawning did not change. Every free cell is reachable, and the maze centre and the island interior are left empty for the points of interest in 12d. Balance and the layout have not been tested in play.

**Built note (12d):** five points of interest sit on the first map, all driven by one data resource (`PointOfInterestData`) and one node (`PointOfInterest`): a Health Shrine (heals half your health, refreshes in 3 minutes), a Mana Shrine (restores half of every spell's pool, 4 minutes), a Treasure Chest (Gold and a scroll, 5 minutes), a Rare scroll spot at each maze's centre room (a Rare scroll, 5 minutes) and a Merchant (potions only, at 1.5 times the death-screen price, 2 of each in stock, restocking after 5 minutes). Shrines and chests are free, only the merchant costs Gold (user decisions), and a refused use never consumes anything. The merchant screen pauses the world, and a purchase is saved at once. Balance and the placements have not been tested in play.

---

# Sprint 13: Art, Animation, Audio, and Polish

**Goal:** Establish the game's visual and audio identity.

The intended art direction is comedic, colorful, and cartoon-inspired pixel art.

The world should feel like a playful fantasy adventure rather than a grim-dark survival experience.

Sprint 13 is split into six: **13a** the art foundation (built), **13b** the world's art (built), **13c** spells and equipment (spell and projectile art, enemy projectiles and blast zones, the reticle, and the wizard visibly wearing the equipped robe, headwear and weapon, a user request during 13a), **13d** the interface (built: a font and one look for every HUD piece and screen), **13e** audio (built), **13f** polish (built).

**Built note (13a):** a replaceable art pipeline. Sprites are text pixel grids (`art/sprites/*.sprite`) in one palette (`art/palette.txt`), built by `tools/art/art_builder.gd` into committed PNG sheets and `SpriteSetData` resources, and shown by `BodyView`, which falls back to the old coloured square when there is no art. The player (idle, move, cast), all seven enemy archetypes in the five element colourways (move, death, and the Ranged shot, Exploder fuse and Support pulse) and the Ember Titan (idle, telegraph, attack, vulnerable) have sprites; elites get a silhouette outline. Overwriting a sheet PNG replaces that art with no code change. Gameplay and hit shapes are unchanged. Stress is about 30% lower than before (about 139 against 199 fps at 300 enemies), still more than twice the 60 fps target. Not yet drawn: player damage and hurt poses, spell and projectile art, equipment and UI.

**Built note (13b):** the world has the same look. Each zone of the first map has a tiled floor (grass, and one lavender stone floor for the mazes, the stronghold and the tunnel) with a wavy, organic edge instead of a straight one, walls are a 9-slice of one stone-block tile (mazes, stronghold, tunnel) or a leafy hedge (the plaza's small walls), every round post is a tree, decorations are bold 12 by 12 sprites spread evenly (flowers, mushrooms and pebbles on the grass, pebbles and cracks on the stone), and the Lectern, the five points of interest (a ready and a dimmed refreshing look) and the scroll, XP gem and Gold coin pickups have sprites. The map names its art (`MapObstacle.material`, `MapZone.floor_style`, `decoration_styles`) and a missing name keeps today's flat colour, so collision, pathfinding and the layout tests did not change. Overwriting a tile or wall PNG replaces it with no code change (checked in a copy of the project). Several rounds of user feedback during the build made the floors brighter, simpler and more cartoon, softened the zone edges, replaced emerald-looking hedge mazes with brick and then with one stone look, and swapped marble pillars for trees. Stress is the same as main within noise (about 141 against about 135 fps median at 300 enemies). Unused but kept: the brick wall, path and hall floors and the marble post sprites.

**Built note (13c):** combat has the cartoon look and the wizard wears what is equipped. Area spells keep their exact hit shape as a faint tint with a bright edge and play element effect sprites over it: Fire flames and Land rock spikes rise from the ground (nearest the caster first), Thunder bolts and Sea splashes fall from the sky; a Zone plays a fresh set at each damage tick, and a hybrid spell cycles through its elements. Missiles are one flying object per element in three size classes (the hit shape follows the exact size, the drawing never scales), and a Wave is a row of them along its front. Enemy shots take their shooter's element colours as small dark-outlined orbs, blast zones warn with rings of pixel marks that grow with the fuse and end in a burst, the boss's charge warning is a dashed line of the same marks, and the target reticle is a pixel crosshair. The wizard is drawn in layers (bare body, robe, beard, headwear, weapon): five robe colourways, a pointed hat and a hood in three trims each, and a wand and a staff in two looks each, set from `EquipmentData.sprite_name` and `sprite_variant` at run start. After feedback the wizard shows no skin at all (a shadowed face with only the eyes, and a white beard over the robe) and the hat and hood are wider so the head reads smaller. Stress with the effects is within about 15% of main (the full scene about 98 against about 113 fps, a Zone about 187 against about 222, a Line and a Wave equal). Not yet done: the HUD and menus (13d), audio (13e), polish (13f).

**Built note (13d):** the interface has one whimsical look. A slim pixel font (`art/fonts/ui.pixelfont`, 5 px letters, a plain and an outlined build with identical metrics) is built by the art tool into BMFont sheets; cream panels with a plum outline, red, green and yellow buttons, slot frames, pink, sky and red bars and icons are sliced sprites (`slice` without `tile`, so corners may be transparent) tiled and never stretched; one committed theme (`resources/ui/game_theme.tres`, written as text by `ThemeBuilder` and set as `gui/theme/custom`) styles every `Control`, and `UiKit` builds themed labels, buttons, bars, icons and the full-screen `window`. Text over the world (Gold, the clock, damage numbers, toasts, prompts) uses the outlined font and is readable on grass, stone and a boss fight; "TEMP HP BAR" is a heart and a bar. Every screen (death, buff pick, inventory, merchant, shop, crafting) sits on a cream page and wraps or fits its longest text (tests measure it). Behaviour, layouts and input did not change (checked in a real window: touch and mouse buy exactly once, focus walks and the death screen's Shop tap never restarts). Stress is about 104 fps median against about 115 before, inside the usual noise. Play-test follow-up (user feedback, before merging): the scattered map decoration was removed from the first map, green now means go (Confirm, Buy, Shop) and red stop (Cancel, Close), buttons and slots were enlarged for touch (the crafting screen got Spell and Buffs tabs), and the starting-buff screen is colourful (each buff has its own colour and icon in data). Not done: a confirm dialog in the shop, sound (13e) and polish (13f).

**Built note (13e):** the game has chiptune audio. About 43 sound recipes (`audio/sounds/*.sfx`: wave shapes, pitch slides, envelopes, noise) and two looping tunes (`audio/music/*.tune`: a run loop and a faster boss loop, four voices each) are rendered by the art tool into committed WAVs (22,050 Hz mono, about 2.5 MB), with stale and orphan tests. One `SoundBoard` node in `main.tscn` (not an autoload) owns a fixed pool of 12 voices, the Music and Sfx buses, the mute state, the first-input unlock the web needs and the music (the boss loop crossfades in and out, music drops 9 dB while a screen pauses the game, jingles duck it); a pure `VoiceLimiter` applies per-sound caps, gaps and priorities so a 300-enemy fight stays quiet and warnings, deaths and level-ups always get a voice. It listens to signals that already exist (a few got a one-line announcement signal: enemy shots and blast zones through the static `EnemyAttackEvents`, crafting, shop and merchant refusals, `Main.point_effect_applied`), and every `Button` clicks and ticks through one hook. The M key and a speaker button on the HUD mute everything and the choice is saved in the profile. `scenes/world/sound_test.tscn` lets you audition every sound and tune, and the stress scene has a `--sound` option (no measurable cost: about 105 to 118 fps against 110 to 124). **Nothing was judged by ear:** the recipes and tunes are chiptune-idiom guesses for the user to audition and tune. Not done: volume sliders and the audio settings screen (Sprint 15).

**Built note (13f):** two things that felt flat were fixed properly, the rest got light touches. Remaining health: from 50% the heart on the health bar beats, below 30% a dithered red frame pulses round the screen edge (faster and stronger as health falls, never above 40% opaque or 2 Hz) with a quiet heartbeat, and it clears at once on a heal or death. A hit on the wizard flashes it red, jitters it 2 px, throws sparks, kicks the camera and shows an arc at the screen edge on the side it came from. Spell weight: every spell gets an impact weight from its wait and its damage per hit (`ImpactWeight`, numbers in `ImpactConfig`), announced by the shared `AreaEffect` base so no Area was edited; light spells throw a few sparks, heavy ones a bigger burst, a whole-pixel shake (at most 4 px), a soft flash (at most 12%) and a lower, louder impact sound. One `FxDirector` node (no autoload) makes every effect within hard budgets (4 bursts a frame, a 256-particle pool, one shake per 80 ms and one flash per 330 ms). Light touches: pickup sparks, a pulsing slot and a faint blip at low mana, stars on a level-up, a sparkle where a Rare scroll lands. Every effect has a switch in `FxSettings` for Sprint 15's settings screen (user request). `scenes/world/fx_test.tscn` lets you fire every effect and set the health; the stress scene has `--fx`. Stress is about 107 fps with effects against about 108 without. **The feel was not judged:** every number is a starting value for the user to tune. Not done: the settings screen itself and saving the switches (Sprint 15).

### Art Direction

- [x] Establish a consistent pixel-art resolution.
- [x] Establish a limited color palette.
- [x] Create the player character sprite.
- [x] Create player movement animations.
- [x] Create player casting animations.
- [x] Create enemy sprites.
- [x] Create enemy movement animations.
- [x] Create enemy attack animations.
- [x] Create elemental spell sprites.
- [x] Create scroll sprites.
- [x] Create equipment sprites.
- [x] Create Lectern sprites.
- [x] Create environmental tiles.
- [x] Create UI elements.

### Animation

- [x] Player idle animation.
- [x] Player movement animation.
- [x] Player casting animation.
- [ ] Player damage animation.
- [x] Enemy movement animations.
- [x] Enemy attack animations.
- [x] Enemy death animations.
- [x] Spell projectile animations.
- [x] Spell impact animations.
- [ ] Item pickup animations.

### Audio

- [x] Implement background music.
- [x] Implement player movement sounds where appropriate.
- [x] Implement spell casting sounds.
- [x] Implement spell impact sounds.
- [x] Implement enemy sounds.
- [x] Implement enemy death sounds.
- [x] Implement item pickup sounds.
- [x] Implement UI sounds.
- [x] Implement boss encounter music.

### Polish

- [x] Add screen shake where appropriate.
- [x] Add particle effects.
- [x] Add damage indicators.
- [x] Add visual feedback for low mana.
- [x] Add visual feedback for level-ups.
- [x] Add visual feedback for rare item drops.

### Deliverable

A visually cohesive and audio-complete game with a recognizable cartoon fantasy identity.

### Completion Criteria

- Art assets share a consistent style.
- Animations communicate gameplay actions clearly.
- Important combat effects are readable.
- Audio feedback supports gameplay without becoming overwhelming.

---

# Sprint 14: Balancing and Optimization

**Goal:** Ensure the game is enjoyable, stable, and performant.

Sprint 14 is split into three: **14a** the world pass (built), **14b** balance, **14c** optimization.

**Built note (14a):** the first map has its points of interest and Lecterns spread out and guarded. The chest moved to the bottom-left inside a ring of trees, the merchant to a hedge yard north of the plaza, and the Lecterns to a ring at the top, a ring at the west edge and a hedge room east of the island, each with one opening; the Rare scroll spots, Health Shrine and Mana Shrine did not move. Nothing is closer than 400 px to the next, the Lecterns are 700 px or more apart and 400 px or more from the start. Map data only; stress is about 106 fps. Whether it feels better is the user's call.

**Built note (14b):** the Missile bursts where it ends (a small area hit of 18 px for half its damage, so it matters in a crowd without taking the Zone's role) and casts every 0.6 s; the Cone reaches 94 px at Normal (Short is what Normal used to be) and casts every 0.8 s; potions last one run (an in-memory `RunPotions`, at most 3 of each type, sold only by the merchant, which now shows a restock timer on its prompt and its screen, and the death-screen shop no longer sells them; old saves' potions are cashed in for Gold once); and a spell audit tool (`scripts/dev/spell_audit.gd`) reports damage per mana pool for every Base, Area and buff against groups of 1 and 8. The audit found the four Zones about 5x the median in a crowd; nothing was changed because the user decides. All starting values are the user's to tune by play.

**Built note (14c):** the game can measure itself and a long run is proven flat. A performance overlay (frames per second, frame time, enemies, nodes) is toggled by F3 or by a 1 s long press on the mute button (a tap still mutes, now on release); it is off by default and reads engine counters only. A soak test (`scripts/dev/soak_test.gd`, `SoakRun`, `SoakDriver`) plays rounds of the whole game (crowd, every Area, pickups, level-ups, potions, a boss, a death and a restart) and samples node, object, orphan and memory counts at rest after each: 12 rounds gave exactly 620 nodes every round, 0 orphans and memory flat after warm-up, so no leak was found; a short version runs in the suite and a deliberate leak fails it. The Sprint 14 test list was checked against the existing tests and the gaps got `tests/test_combinations.gd` (all passed, no bug). The deferred minors from 13d to 14b are fixed. **No optimization was made:** on the development laptop the full 300-enemy scene runs at about 90 to 115 fps when the machine is at full speed, but the machine was on battery with Low Power Mode and the same scene swung between about 100 fps and about 10 to 45 fps from run to run, which made before and after numbers meaningless; that swing also suggests the game loses frame rate sharply, not gradually, on a slower CPU. No phone was measured: the first phone numbers must come from testers using the overlay.

### Tasks

#### Gameplay Balancing

- [ ] Balance player health.
- [ ] Balance player movement speed.
- [ ] Balance enemy movement speed.
- [ ] Balance enemy health.
- [ ] Balance enemy damage.
- [ ] Balance enemy spawn rates.
- [ ] Balance spell damage.
- [ ] Balance spell mana consumption.
- [ ] Balance spell casting speed.
- [ ] Balance elemental multipliers.
- [ ] Balance Buff effectiveness.
- [ ] Balance equipment bonuses.
- [ ] Balance XP progression.
- [ ] Balance Gold rewards.
- [ ] Balance boss difficulty.

#### Testing

- [x] Test all Base and Area combinations.
- [x] Test all Buff combinations.
- [x] Test multiple equipped spells.
- [x] Test depleted mana scenarios.
- [x] Test equipment combinations.
- [x] Test potion interactions.
- [x] Test level progression.
- [x] Test player death.
- [x] Test run completion.
- [x] Test save/load functionality.

#### Optimization

- [ ] Optimize enemy spawning.
- [ ] Optimize projectile handling.
- [ ] Implement object pooling where beneficial.
- [ ] Optimize particle effects.
- [ ] Profile performance with large enemy counts (Sprint 1 desktop baseline: 60 fps target met at 300 and 500 enemies, see `development-log.md`; re-measure on phones/browsers).
- [ ] Add crowd separation if enemy stacking hurts readability (enemies currently converge on the player).
- [x] Fix memory leaks. (14c: the soak test found none.)
- [ ] Fix known gameplay bugs.

### Deliverable

A balanced and stable version of the game that can support extended play sessions.

### Completion Criteria

- No critical gameplay bugs remain.
- Performance remains stable during large encounters.
- Progression is balanced.
- Spells have meaningful strengths and weaknesses.
- The game remains enjoyable throughout an entire run.

---

# Sprint 15: Release Preparation

**Goal:** Prepare the game for its first public release.

Sprint 15 is split into three: **15a** the front door (built), **15b** onboarding and run statistics (built), **15c** release preparation (**parked** by the user on 2026-11-24 until the game is improved further; the plan, the missing pieces, a manual test checklist and itch.io notes are in `docs/release-planning/`, and the wishlist that comes first is in `docs/release-planning/future-roadmap.md`: new maps and bosses, achievements, and a livelier home screen and tutorial).

**Built note (15a):** the game opens on a home screen (Play, Shop, Tutorial dimmed until 15b, Settings, New game, Full screen) that is its own scene, so no run exists until Play. Settings are saved in their own file (music and effects volume, every screen-effect switch, the performance overlay, full screen) with a Reduce motion preset and read-only Controls and Credits pages; the sound board follows the volumes live. New game asks twice and keeps one `.bak`. A pause menu (Esc, controller Start or a HUD button) offers Resume, Settings and Quit to home; the inventory now pauses the game; the death screen gained a Home button. Checked in a real window by touch and mouse; not on a phone.

**Built note (15b):** the Tutorial button works: four pages with pictures (surviving and moving, casting spells, scrolls and the Lectern, potions and the shop), never opening by itself, with key names read from the Input Map. A per-run tally (`RunStats`, which only listens) feeds a death-card recap of nine stats, and three bests (longest survival, most enemies, highest level) are saved in an optional field of the progress save, with "New best!" shown only for a beaten non-zero best whose save worked; New game erases them. The one-line death summary is gone. Checked in a real window by touch and mouse; not on a phone.

### Tasks

- [x] Implement the main menu. (15a: the home screen.)
- [x] Implement settings. (15a: the Settings screen, saved in `user://settings.json`.)
- [x] Implement audio settings. (15a: music and effects volume.)
- [x] Implement control settings. (15a: a read-only Controls page; no key remapping.)
- [x] Implement pause menu. (15a.)
- [x] Implement game-over screen. (15b: the death card is a run recap.)
- [x] Implement run statistics. (15b: a per-run tally and three saved bests.)
- [ ] Implement persistent save data.
- [x] Implement tutorial/onboarding. (15b: four Tutorial pages.)
- [ ] Implement credits.
- [ ] Create game icon.
- [ ] Create promotional screenshots.
- [ ] Create promotional artwork.
- [ ] Perform final playtesting.
- [ ] Fix release-blocking bugs.
- [ ] Create release build.

### Deliverable

A complete, playable release candidate.

### Completion Criteria

- The player can start and finish an adventure.
- Progression persists between sessions.
- All major systems function correctly.
- The game has a complete user interface.
- The game is ready for external playtesting.

---

# Sprint 16: New Maps and Bosses

**Status:** planned (the user's request of 2026-11-24, updated the same day with the user's confirmed enemy columns and map themes). Split into four sprints so none is lost: **16a** the map select, the per-map art sets and the new layouts, **16b** the forest's art and the Tempest Dragon, **16c** the ruins' art refresh, **16d** the maze's art and the Dire Minotaur. Each leaves a playable build. Sprint 15c (release) is parked until the wishlist is done (see `docs/release-planning/`).

**Goal:** Three themed maps to play, each with its own look for the same enemies and its own boss, and each naturally harder than the last because of its layout (forest easy, ruins medium, maze hard).

### The maps (the user's themes, in this order)
1. **The forest**: an open forest (no walls, Vampire Survivors style, with points of interest) **about finding a dragon**; its boss is the **Tempest Dragon** (Thunder).
2. **The ruins**: the ruins of a city, which is **the map we have now** (its id and layout stay); its boss is the **Ember Titan** (Fire).
3. **The maze**: a **minotaur's maze or dungeon**, one complete maze (the user liked the mazes in the first map), with points of interest; its boss is the **Dire Minotaur** (Land).

**Everything is the same on every map: the same seven enemy types, elements, stats, spawn config (difficulty curve, elites, boss interval) and rewards; only the sprites differ.** The user's point: **the challenge is the map the player has to navigate.** An open forest has no obstacles, so a player is rarely trapped (the easiest); the ruins have walls and rooms (medium); the maze has dead ends and corridors where a player can be cornered or flanked (the hardest). So difficulty comes from the layout, not from numbers, and no per-map difficulty data is needed (each map uses the same spawn config).

### The enemy columns (confirmed by the user: each column is one map)
| Type | Forest | Ruins | Maze |
|---|---|---|---|
| Standard | goblin | bandit | zombie |
| Swarmer | rats | slime | snakes |
| Chaser | wolves | mimic | ghost |
| Tank | ent | animated armour | troll |
| Ranged | kobolds | elemental | skeletons |
| Exploder | creepers | mephit (the current imp) | warforge (robot-like) |
| Support | shaman | cultist | beholder |
| Boss | Tempest Dragon | Ember Titan | Dire Minotaur |

**What that means for the art we have.** Today's enemy sprites are a mix of the first two columns: goblin, wolf and kobold belong to the **forest**, and slime, animated armour, imp (the mephit) and cultist belong to the **ruins**. So:
- **Already drawn:** forest goblin, wolf and kobold; ruins slime, animated armour, mephit (imp) and cultist; the Ember Titan.
- **New for the forest (16b):** rats, ent, creepers, shaman and the Tempest Dragon.
- **New for the ruins (16c):** bandit, mimic and elemental, replacing the goblin, wolf and kobold there.
- **New for the maze (16d):** all seven (zombie, snakes, ghost, troll, skeletons, warforge, beholder) and the Dire Minotaur.
- **Naming:** enemy art is looked up as `enemy_<set>_<type>` (`forest`, `ruins`, `maze`) with a fallback to the current `enemy_<type>`. (16a decision: no sprite is renamed; the fallback alone keeps every map showing today's art until 16b to 16d add the set sprites.)

### Decisions
Confirmed by the user: the enemy columns above; **everything but the sprites is the same on every map, and the difficulty order (forest easiest, ruins medium, maze hardest) comes only from the layout**; **all three maps open from the start** (unlocking by boss belongs to the achievements sprint, 17); **every map is 1920 by 1080, the same as the ruins** (the user: no need to expand; the forest is bounded with no walls and its points of interest spread as far apart as that allows); **bests are kept per map** (the user: some maps are easier than others, so a longest survival or most enemies only means something against the same map).

**Nothing is left open for the maps' design.** Confirmed by the user: **the bosses arrive on the same 300-second timer on every map, with no lair mechanic** (the forest is "about finding a dragon" and the maze is a minotaur's dungeon as themes, not as a hunt), and **the death card drops the "Level reached" row** (the level is permanent, so at level 20 it would always say 20), which also removes the saved best level.

---

## Sprint 16a: The map select, the art sets and the new layouts

**Status:** done (see `sprint-16a-design.md`, `development-log.md` and `CLAUDE.md`, "Maps and the map select").

**Goal:** Play chooses a map; a map says which enemy art set and boss roster it uses; the forest and the maze exist and are playable, with today's art and the Ember Titan until their art sprints.

### Tasks
- [ ] **Bests per map.** The saved `bests` becomes one entry per map id (`{"ruins": {"seconds": N, "enemies": N}, "forest": {...}}`); an old save's flat `bests` (made on the ruins, the only map then) loads as the ruins' bests, so nothing is lost; `RunRecords` and `RunRecap` take the map id, the death card shows and compares the current map's bests, New game erases all of them. The death card's **"Level reached" row is removed** (user decision) and with it the saved best level (an old save's `level` value is ignored), leaving eight rows and two bests (longest survival and most enemies).
- [ ] `MapData` names its enemy art set, a short description and its boss roster (the map's `spawn_config.bosses`), plus a `MapCatalog` resource listing the maps in order (forest, ruins, maze). The ruins keep the first map's data and id.
- [ ] A per-map enemy art lookup (`enemy_<set>_<type>`, falling back to `enemy_<type>`); the existing sprites are renamed into their sets (goblin, wolf, kobold into `forest`; slime, armour, imp, cultist into `ruins`) so the ruins and forest still show today's art where the new sprites do not exist yet. The boss's sprite comes from its `BossData`. No enemy stats change.
- [ ] A map select screen between the home screen's Play and the run (cards with the map's name, a theme line and its boss), by touch, mouse, keyboard and controller; the chosen map is passed to the run without an autoload.
- [ ] The **forest** layout as data (1920 by 1080, like every map): player start, grass floor, groves and rocks as obstacles (few, so it stays open), points of interest and three Lecterns far apart and from the start, with whatever the boss-finding decision needs; layout tests.
- [ ] The **maze** layout as data: one full `MapMaze` over the whole map (closed boundary, a cleared centre, extra openings for loops), points of interest in rooms and dead ends, three far-apart Lecterns; layout tests.
- [ ] The stress scene takes `--map=<id>`; the spawner, flow field, draw chunks and soak test are checked on every map (the open forest has far fewer walls but the same area, and the maze has many corridors, so spawning, the flow field and crowd behaviour differ); performance recorded.
- [ ] Real-window screenshots of the select screen and both new layouts, by touch and mouse.

### Deliverable
Three maps selectable from Play, all playable.

### Completion Criteria
- Every map loads, is fully reachable and has no layout problems.
- The ruins play exactly as before, and every map uses the same numbers. A simulated run of each map checks that the layouts alone give the order the user expects (forest easiest, maze hardest); if the maze turns out unfair or the forest trivial, that is reported to the user rather than fixed with per-map numbers.
- Missing enemy art never breaks a map.
- Performance on every map stays at or near the ruins'.

---

## Sprint 16b: The forest's art and the Tempest Dragon

**Status:** done (see `sprint-16b-design.md`, `development-log.md` and `CLAUDE.md`, "The forest's art and the Tempest Dragon").

**Goal:** The forest looks and feels like its own place, about finding a dragon.

### Tasks
- [ ] New forest enemy sprites: rats, ent, creepers and shaman (the goblin, wolves and kobolds already exist), with the same animations as the current set and element colourways, through the art pipeline and its stale-output tests.
- [ ] The **Tempest Dragon**: boss art (idle, telegraph, attack, vulnerable), a Thunder `BossData` with phases and attacks (built from the existing slam, charge, burst and summon kinds, tuned to feel different from the Ember Titan), its rewards, and its place in the forest's roster; it arrives on the 300-second timer like the Ember Titan.
- [ ] Forest world art as needed (floor patches, decorations, groves), bright and cartoon with one pixel size.
- [ ] Sound: reuse the boss stinger and boss music unless the user wants new ones.
- [ ] Tests for the set lookup, the boss data and its fight (like the Ember Titan's); real-window screenshots; a balance check against the ruins' difficulty.

### Deliverable
The forest with its full enemy set and the Tempest Dragon.

---

## Sprint 16c: The ruins' art refresh

**Goal:** The ruins show exactly their column: bandit, slime, mimic, animated armour, elemental, mephit, cultist and the Ember Titan.

### Tasks
- [ ] New ruins sprites: bandit (standard), mimic (chaser) and elemental (ranged), replacing the goblin, wolf and kobold on that map; the mephit stays the current imp (renamed if wanted).
- [ ] Tests (the set lookup, the stale-output tests), screenshots, and a check that the ruins' behaviour and balance did not change.

### Deliverable
The ruins with their themed enemy set.

---

## Sprint 16d: The maze's art and the Dire Minotaur

**Goal:** The maze feels like a minotaur's dungeon.

### Tasks
- [ ] Seven maze enemy sprites (zombie, snakes, ghost, troll, skeletons, warforge, beholder), done as in 16b.
- [ ] The **Dire Minotaur**: boss art, a Land `BossData` (phases and attacks tuned for corridors, where a charge matters), rewards and its place in the maze's roster; it arrives on the 300-second timer like the Ember Titan.
- [ ] Maze world art as needed (a darker dungeon variant of the stone floor and walls, if wanted).
- [ ] Tests, screenshots, and a balance check for the maze's tight corridors (crowd behaviour, boss movement through the flow field).

### Deliverable
The maze with its own enemies and the Dire Minotaur.

### Completion Criteria (16a to 16d together)
- Three themed maps, each with its own enemy look and its own boss, the same numbers everywhere, and a difficulty that comes from the layout.
- The ruins' layout and id are unchanged.
- No map-specific code branches on a map id.

---

## Planned after Sprint 16 (the user's wishlist; details in `docs/release-planning/future-roadmap.md`)
- **Sprint 17: Achievements.** Defeating a boss rewards a starting spell (like the Sea Cone); an achievements store in the save and a screen on the home screen; possibly map unlocks.
- **Sprint 18: A livelier home screen and tutorial** with more art.
- **Sprint 15c (parked): release preparation** (`docs/release-planning/`).

---

# Development Milestones

The sprints can be grouped into larger milestones to track overall progress.

| Milestone | Sprints | Result |
|---|---|---|
| Foundation | 0–1 | Playable character and basic combat |
| Spell Framework | 2–4 | Functional elemental spell system |
| Spell Crafting | 5–7 | Complete scroll collection and crafting |
| Progression | 8–10 | XP, Gold, equipment, and consumables |
| Content | 11–12 | Enemies, bosses, and world exploration |
| Polish | 13–14 | Art, audio, balancing, and optimization |
| Release | 15 | Release candidate (15c parked) |
| New content | 16–18 | New maps and bosses, achievements, a livelier front door |

# MVP: Minimum Viable Product

Before attempting to complete every sprint, establish a smaller playable version of the game.

The MVP should contain:

- One playable wizard.
- One playable map.
- Four elemental Base types.
- Four Area types.
- Basic Buff functionality.
- A limited selection of enemies.
- Enemy spawning.
- Scroll drops.
- Scroll collection.
- One Arcane Lectern.
- Spell crafting.
- Individual spell mana pools with no natural regeneration.
- XP collection.
- Basic leveling.
- Player health and death.
- A basic game-over screen.

The MVP does not need:

- Multiple biomes.
- Multiple bosses.
- Full equipment progression.
- Potions.
- Rare scrolls.
- Spell evolution.
- Multiple playable characters.
- Extensive enemy variety.

The purpose of the MVP is to validate the central gameplay loop.

**If collecting scrolls, crafting spells, and surviving with limited mana isn't fun in the MVP, additional content won't solve that problem.**

# Sprint Completion Checklist

Every sprint should end with the following checks:

- [ ] All planned tasks are completed or explicitly deferred.
- [ ] New features have been tested.
- [ ] Existing features still function.
- [ ] Known bugs have been documented.
- [ ] Gameplay has been tested in a playable build.
- [ ] Code and assets have been committed to version control.
- [ ] The next sprint's objectives have been reviewed.

# Final Development Philosophy

Build the game from the inside out.

First establish movement and combat, then introduce spell behavior, then spell crafting, and finally the progression systems that give players reasons to keep playing.

Avoid spending too much time on content before the underlying mechanics are proven to be enjoyable.

A small, polished game with an engaging spell-crafting loop is a much stronger foundation than a large game with many unfinished systems.