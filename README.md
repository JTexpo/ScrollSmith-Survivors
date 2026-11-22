# ScrollSmith Survivors: Game Design Document

# 1. Game Concept

An 8-bit, top-down, survival roguelite inspired by *Vampire Survivors*, where the player takes on the role of a wizard fighting increasingly dangerous waves of enemies.

Rather than relying on traditional weapons, the player collects magical spell-scrolls that can be combined at an **Arcane Lectern** to craft unique spells.

Each spell is constructed using three components:

- **Base:** Determines the elemental damage type.
- **Area:** Determines how the spell behaves and where it affects enemies.
- **Buffs:** Provides additional modifiers that alter the spell's properties.

Spells have a limited mana capacity. Once depleted, they are lost, and the player must craft a new spell. This encourages players to constantly move, manage their resources, and experiment with different spell combinations.

The ultimate goal is to survive increasingly difficult enemy waves, collect resources, discover powerful spell combinations, and become a stronger wizard with every adventure.

## 1.1 Core Gameplay Pillars

- **Spell Crafting:** Discover scrolls and combine them to create unique magical attacks.
- **Resource Management:** Balance spell damage, mana consumption, and cooldowns.
- **Movement and Survival:** Keep moving to avoid enemies while managing limited magical resources.
- **Build Variety:** Create different playstyles through spell combinations and equipment.
- **Roguelite Progression:** Use resources collected during adventures to improve future runs.

# 2. Core Gameplay Loop

1. Begin an adventure with a starting spell and equipment.
2. Fight enemies and collect XP and Gold.
3. Level up to improve character attributes and unlock additional spell slots.
4. Discover spell-scrolls dropped by enemies or found throughout the world.
5. Combine scrolls at Arcane Lecterns to craft new spells or modify existing ones.
6. Manage spell mana while surviving increasingly difficult enemy waves.
7. Defeat bosses and progress through increasingly dangerous encounters.
8. Eventually die or complete the adventure.
9. Spend accumulated resources on permanent progression and equipment.
10. Begin another adventure with a stronger or entirely different build.

# 3. Spell Crafting System

Spells are constructed using three categories of scrolls:

- Base
- Area
- Buffs

Every crafted spell requires at least one Base and one Area scroll. Buffs are optional.

## 3.1 Base Scrolls

Base scrolls determine the elemental damage type of a spell.

Each element has strengths and weaknesses against particular enemy types. Exploiting an enemy's vulnerability increases damage, while attacking an enemy with a resistant element reduces damage.

| Element | Strong Against | Weak Against |
|---|---|---|
| Fire | Land | Sea |
| Thunder | Sea | Land |
| Land | Thunder | Fire |
| Sea | Fire | Thunder |

### Elemental Interactions

- **Fire:** Effective against Land enemies but ineffective against Sea enemies.
- **Thunder:** Effective against Sea enemies but ineffective against Land enemies.
- **Land:** Effective against Thunder enemies but ineffective against Fire enemies.
- **Sea:** Effective against Fire enemies but ineffective against Thunder enemies.

Enemies without an elemental affinity receive normal damage from all elements.

### Multiple Base Types

Certain buffs allow a spell to incorporate additional Base types.

For example:
- Fire + Thunder creates a hybrid elemental spell.
- Land + Sea creates a hybrid elemental spell.
- Fire + Sea can exploit multiple elemental interactions.

Hybrid spells can potentially exploit multiple enemy vulnerabilities, but drain mana much faster than a single element

**Built in Sprint 7:** each Additional Base scroll opens one more Base slot, up to three extra. The number of Base scrolls must match exactly (one, plus one per Additional Base), and an element cannot repeat. Against each enemy a hit uses **whichever of the spell's elements does best** (a strong match beats a neutral one, which beats a weak one), so a Fire + Sea spell hits a Fire enemy as Sea and a Thunder enemy as Fire. A hybrid's damage, speed and mana numbers are the average of its Bases, and the Additional Base buff makes each cast cost 1.8x, so the extra reach is paid for.

## 3.2 Area Scrolls

Area scrolls determine the shape, targeting method, and behavior of a spell.

Increasing a spell's effective range or area increases its mana consumption.

### Available Areas

**Line**
- Originates from the player.
- Travels or extends in the direction the player is facing or aiming.
- Damages enemies within its path.
- Can be upgraded to increase its length and width.

**Cone**
- Originates from the player.
- Projects outward in a cone in the direction of the mouse or joystick.
- Damages enemies within its arc.
- Can be upgraded to increase its angle and range.

**Area**
- Targets a location selected using the mouse or joystick.
- Creates an area-of-effect attack at the selected location.
- Can be upgraded to increase its radius and duration.

**Missile**
- Originates from the player.
- Fires a projectile toward the selected direction.
- Travels independently until it hits an enemy or reaches its maximum range.
- Can be upgraded to increase projectile speed, range, and size.

**Wave**
- Originates from the player.
- Sends a wide crescent outward in the direction of the mouse or joystick, like a Missile shaped like a cone's front edge.
- Hits every enemy it passes through once, and widens a little as it travels.
- Disappears at its maximum range.
- Can be upgraded to increase its width, range, and speed.

### Area Scaling

Area scrolls can have different levels of effectiveness.

For example:
- Small Line: Low mana consumption, short range.
- Large Line: High mana consumption, long range.
- Small Area: Low mana consumption, small explosion.
- Large Area: High mana consumption, large explosion.

Every Area has a default range (a Cone starts short, a Line starts long). Crafting can lengthen or shorten it, and longer range costs more mana while shorter range costs less.

The goal is to make every Area type useful in different situations rather than having one universally superior option.

## 3.3 Buff Scrolls

Buff scrolls provide additional modifiers to crafted spells.

Buffs are optional, but each additional buff increases the spell's mana consumption.

This creates a trade-off between creating a powerful spell and maintaining enough mana to use it consistently.

### Available Buffs

| Buff | Effect |
|---|---|
| Increased Max Mana | Increases the spell's maximum mana capacity. |
| Increased Damage | Increases the spell's damage output. |
| Double Vulnerability Damage | Doubles bonus damage against vulnerable enemies. |
| Ignore Resistance | Allows the spell to bypass enemy elemental resistance. |
| Duplicate Area | Creates additional instances of the spell's Area effect. |
| Additional Base | Adds another elemental damage type to the spell. |

### Duplicate Area

Duplicate Area increases the number of times an Area effect is applied.

Examples:
- 1 Duplicate: Mirrors the original spell.
- 2 Duplicates: Fires in three directions.
- 3 Duplicates: Fires in four directions.
- 4 Duplicates: Fires in five directions.

**Built in Sprint 7 (the ring):** a spell with N shots fires them evenly around the player, with the first on the aim (2 shots are opposite, 3 are 120 degrees apart, 5 are 72 degrees apart). A ground-targeted Area (the zone) keeps its first zone at the target and puts the others in a ring around it, at 1.5 times the zone's radius. Each shot is its own hit, and a cast costs mana once, so the buff's 2x cost per stack is what pays for the extra shots.

### Buff numbers (built in Sprint 7)

Buffs stack. Multipliers multiply, bonuses add, and every stack raises the mana cost per cast.

| Buff | Per stack | Cost per cast | Cap |
|---|---|---|---|
| Increased Max Mana | Pool x1.5 | x1.25 | none |
| Increased Damage | Damage x1.5 | x1.5 | none |
| Double Vulnerability Damage | Strong bonus +100% (one stack doubles it, two make it 2.5x damage) | x1.25 | none |
| Ignore Resistance | A weak hit counts as a normal one | x1.25 | 1 |
| Duplicate Area | +1 shot | x2.0 | 4 |
| Additional Base | One more Base slot | x1.8 | 3 |

Damage and copies never improve damage per mana. Increased Max Mana is the deliberate exception: it makes more casts, not stronger ones. A spell whose cost is above its whole pool is refused at the Lectern.

### Spell Balance

Every buff increases the spell's overall mana requirements.

The more powerful the spell, the more frequently the player will need to manage its mana.

This prevents players from simply stacking every available buff onto a single spell without considering the consequences.

# 4. Arcane Lectern

The Arcane Lectern is the primary crafting station used to combine spell-scrolls.

Players can discover Lecterns throughout the map and use them to modify their spell loadout.

### Crafting Rules

- A spell requires at least one Base scroll.
- A spell requires one Area scroll.
- Buffs are optional.
- A spell can only have one Area type unless modified by a special mechanic.
- Additional Base types can be added through buffs.
- Additional buffs increase mana consumption.

### Crafting Possibilities

Players can experiment with different combinations to create specialized spells.

Examples:

| Spell | Components | Playstyle |
|---|---|---|
| Fire Missile | Fire + Missile | Long-range damage |
| Thunder Cone | Thunder + Cone | Close-range crowd control |
| Land Area | Land + Area | Large-area damage |
| Sea Line | Sea + Line | Directional damage |
| Sea Wave | Sea + Wave | Moving wall of damage that clears crowds |
| Multi-Fire Missile | Fire + Missile + Duplicate Area | Multi-projectile damage |
| Piercing Thunder | Thunder + Missile + Ignore Resistance | Reliable damage against resistant enemies |

### Lectern Interaction

When interacting with a Lectern, the player enters a crafting interface.

The player can:
1. Select an existing spell or an empty spell slot.
2. Insert a Base scroll.
3. Insert an Area scroll.
4. Choose how far the spell reaches. A longer range costs more mana per cast and a shorter range costs less.
5. Add any available Buff scrolls.
6. Review the resulting spell's damage, mana capacity, and mana consumption, next to the spell it would replace.
7. Confirm the combination.

The world pauses while the crafting screen is open, so players can compare options without being rushed. The player begins with a single spell, and more spell slots unlock at higher levels. Crafting replaces the spell in the chosen slot, and the old spell's remaining mana is lost.

Crafting should be quick enough that players aren't spending excessive time away from the action.

# 5. Mana System

Mana is the primary resource used to cast spells.

Every spell has its own mana capacity and consumption rate.

### Spell Mana

- Each spell has a maximum mana capacity.
- Casting a spell consumes mana.
- More powerful spells consume more mana.
- Mana does not regenerate.
- Spells cannot be cast when they lack sufficient mana.

### Mana Management

The player is encouraged to rotate between spells rather than relying on a single attack.

For example:
- Spell A is used until its mana is depleted.
- Spell B is used while the player finds resources to craft Spell C (a replacement of Spell A).
- Spell C is used while the player finds resources to craft newer spells.

This creates a natural rhythm of attacking, moving, and managing resources.

### Potential Mana Modifiers

Future scrolls and equipment could introduce:
- Increased mana regeneration.
- Reduced mana consumption.
- Increased maximum mana.
- Mana regeneration on enemy kills.
- Mana regeneration on vulnerability hits.
- Chance to refund mana after casting.

# 6. Roguelite Progression

A wizard's adventure doesn't need to end when they die.

After each run, players retain certain resources and can spend them to improve their character for future adventures.

The two primary progression resources are:

- XP
- Gold

## 6.1 XP Progression

XP is accumulated during adventures and contributes toward the player's permanent wizard level. XP and level are saved, so a run that ends badly still leaves the wizard stronger.

There are 20 progression levels. Every wizard starts at level 1, which gives no reward. Levels 2 to 20 each provide a predefined upgrade, gradually improving the wizard's attributes and starting spell loadout.

Enemies drop XP as gems on the ground, and walking over a gem collects it. Stat and spell slot rewards apply the moment their level is reached. Rewards that change the starting spells apply when the next run begins. Starting-spell buffs are never saved: a random buff is re-rolled and a chosen buff is picked again at the start of every run.

### Level Progression

| Level | Reward |
|---|---|
| 1 | Starting level (no reward) |
| 2 | Increase Movement Speed |
| 3 | Increase Maximum Health |
| 4 | Increase Maximum Mana of All Spells |
| 5 | Increase Maximum Spell Slots from 1 to 2 |
| 6 | Increase Movement Speed |
| 7 | Starting Spell receives 1 Random Buff |
| 8 | Increase Maximum Health |
| 9 | Increase Maximum Mana of All Spells |
| 10 | Increase Maximum Spell Slots from 2 to 3 |
| 11 | Increase Movement Speed |
| 12 | Starting Spell receives 1 Chosen Buff |
| 13 | Increase Maximum Health |
| 14 | Start with 2 Spells |
| 15 | Increase Maximum Spell Slots from 3 to 4 |
| 16 | Increase Movement Speed |
| 17 | Second Starting Spell receives 1 Random Buff |
| 18 | Increase Maximum Health |
| 19 | Second Starting Spell receives 1 Chosen Buff |
| 20 | Increase Maximum Spell Slots from 4 to 5 |

### Reward numbers (starting values, tuned by playing)

| Reward | Amount |
|---|---|
| Increase Movement Speed | +8% of base speed each (+32% in total) |
| Increase Maximum Health | +20% of base health each (+80% in total), and the player heals by the amount it adds |
| Increase Maximum Mana of All Spells | +15% of each spell's pool each (+30% in total), for spells equipped now and later |
| Spell slots | One slot per reward, up to five |
| Starting Spell receives a Random Buff | Re-rolled at the start of every run, from the five buffs that work on one element (not Additional Base) |
| Starting Spell receives a Chosen Buff | Picked on a screen at the start of every run, from the same five |
| Start with 2 Spells | The second starting spell is Sea Cone |

XP needed to reach level 2 is 30, and each level costs 20 more than the one before it (3,990 XP in total for level 20).

### Spell Slots

Spell slots determine how many unique spells the player can equip simultaneously.

Players begin with one spell slot and gradually unlock up to five.

This encourages experimentation with different spell combinations and creates more opportunities for specialized builds.

## 6.2 Gold Progression

Gold is collected during adventures and used to purchase equipment and consumables between runs.

Unlike XP, Gold is primarily used to customize the wizard's equipment and playstyle.

Enemies drop Gold coins, and walking over one collects it (plain, Fire and Thunder enemies give 1 Gold, Sea 2, Land 3). Gold is banked the moment it is collected and saved with XP, so dying never costs what you collected.

After a run ends, the death screen shows the XP and Gold earned and a **Shop** button. The shop is where equipment is bought, swapped and taken off. It cannot be opened during a run, so equipment changes take effect at the next run. Buying an item also equips it, and the item it replaces stays owned.

There are three equipment slots: a Robe, a Weapon (one Wand or Staff) and Headwear (one Hat or Hood).

| Item | Price | Modifiers |
|---|---|---|
| Ember, Storm, Stone, Tide Robe | 100 | +15% damage for Fire, Thunder, Land or Sea spells |
| Warded Robe | 120 | +30% maximum health |
| Mana Hat or Hood | 80 | +10% maximum mana for all spells |
| Swift Hat or Hood | 80 | +10% movement speed |
| Hardy Hat or Hood | 80 | +20% maximum health |
| Quickwand | 200 | +25% casting speed, -15% spell damage, 10% chance to cast twice |
| Flickerwand | 350 | +40% casting speed, -30% spell damage, 15% chance to cast twice |
| Oak Staff | 200 | +25% spell damage, -15% casting speed, 10% chance to deal double damage |
| Elder Staff | 350 | +45% spell damage, -30% casting speed, 15% chance to deal double damage |

Casting twice launches every shot a second time for the same mana. Double damage doubles every shot of that cast. Both are rolled once per cast. A spell's element bonus is the average of the bonuses for its elements. The crafting preview shows these bonuses in the spell's damage, interval, pool and casts.

Equipment categories include:
- Robes
- Staffs and Wands
- Hats and Hoods
- Potions (Sprint 10)

### Robes

Robes are permanent equipment modifiers that provide passive bonuses.

Only one robe can be equipped at a time.

Available robe modifiers:

- Increased Fire Base Damage.
- Increased Land Base Damage.
- Increased Sea Base Damage.
- Increased Thunder Base Damage.
- Increased Maximum Mana for All Spells.
- Increased Maximum Health.
- Increased Movement Speed.

Different robes encourage players to specialize in particular elements or playstyles.

### Staffs and Wands

Wizards can cast spells without a Staff or Wand.

However, equipping one introduces additional modifiers that can significantly change how the wizard plays.

Only one Staff or Wand can be equipped at a time.

#### Wands

Wands prioritize casting speed and efficiency at the expense of raw damage.

**Primary Characteristics:**
- Increased Casting Speed.
- Reduced Spell Damage.

**Possible Modifiers:**
- Chance to cast a spell without consuming mana.
- Increased spell distance.
- Increased projectile speed.
- Reduced mana consumption.
- Chance to cast twice.

Wands are ideal for players who prefer rapid attacks and consistent spell usage.

#### Staffs

Staffs prioritize damage and spell effectiveness at the expense of casting speed.

**Primary Characteristics:**
- Increased Spell Damage.
- Reduced Casting Speed.

**Possible Modifiers:**
- Chance to deal double damage.
- Increased spell area.
- Increased elemental vulnerability damage.
- Increased spell duration.
- Increased damage against bosses.

Staffs are ideal for players who prefer slower, more powerful attacks.

### Hats and Hoods

Hats and Hoods are functionally identical equipment categories, with their differences being purely visual.

Only one can be equipped at a time.

They provide passive modifiers similar to Robes.

**Available Modifiers:**
- Increased Fire Base Damage.
- Increased Land Base Damage.
- Increased Sea Base Damage.
- Increased Thunder Base Damage.
- Increased Maximum Mana for All Spells.
- Increased Maximum Health.
- Increased Movement Speed.

### Potions

Potions are consumable items that provide temporary benefits during an adventure.

Unlike Robes, Staffs, Wands, and Hats, potions are consumed when used.

Potions are bought one at a time in the death-screen shop. You carry everything you own into every run (up to 99 of each type), and unused potions are kept when you die. A potion bar shows each type with how many you have, its cooldown and, while a timed effect runs, how long is left. Drinking saves at once, so quitting can't refund a potion.

| Potion | Price | Effect | Cooldown |
|---|---|---|---|
| Health | 40 | Restores 40% of maximum health | 10 s |
| Mana | 60 | Restores 50% of every spell's mana pool | 15 s |
| Speed | 30 | +40% movement speed for 15 s | 30 s |
| Damage | 50 | +50% spell damage for 15 s | 30 s |
| Invulnerability | 100 | No damage for 5 s | 60 s |
| Luck | 40 | +100% luck for 60 s | 90 s |

Luck makes Uncommon scrolls (weight x(1 + luck)) and Rare scrolls (weight x(1 + 2 x luck)) more likely to drop. It never changes whether something drops. Mana is the one way spent mana comes back, so a Mana Potion restores only half of each pool.

A potion is only drunk, and consumed, when its effect really happens. It is refused (and kept) when you have none left, its cooldown is running, another potion was drunk in the last second, its timed effect is still running, Health is already full, every spell is already full, or you are dead. Cooldowns and effect timers stop while the game is paused.

Keys: Z, X, C, V, B and N drink the six potions in bar order. On a controller, X selects the next potion, a left stick click selects the previous one, and B drinks the selected one (the D-pad stays for moving). On a touchscreen or with the mouse, tap or click a slot.

Potions introduce another layer of resource management and allow players to prepare for particularly difficult encounters.

# 7. Enemy Design

Enemies are the primary source of pressure during an adventure.

Each enemy has its own behavior, movement speed, health, damage, and elemental affinity.

### Enemy Attributes

- **Health:** How much damage an enemy can withstand.
- **Damage:** How much damage an enemy deals to the player.
- **Movement Speed:** How quickly an enemy approaches the player.
- **Element:** Determines elemental vulnerabilities and resistances.
- **Experience:** How much XP the enemy drops when defeated.
- **Gold:** How much Gold the enemy drops when defeated.

### Enemy Archetypes

An enemy is a **role** (its archetype) combined with an **element**, picked independently, so a Thunder Tank, a Sea Swarmer or a Fire Exploder can all appear. The role decides every stat, and the element only decides what hurts it, its colour and which scrolls it drops (a Thunder Tank is exactly as tough as a Land Tank). Roles unlock as the run goes on:

| Role | From | What it does | Health | Speed | Touch damage |
|---|---|---|---|---|---|
| Standard | start | Walks at you. | 20 | 40 | 10 |
| Swarmer | 0:30 | Weak and small, comes in clusters of 5. | 8 | 46 | 5 |
| Chaser | 1:00 | Fast and fragile. | 14 | 80 | 9 |
| Tank | 2:00 | Slow, big and tough; drops more. | 80 | 26 | 16 |
| Ranged | 3:00 | Keeps about 90 px away and fires a shot every 2 s (8 damage). | 14 | 34 | 6 |
| Exploder | 4:00 | Runs in, flashes for 0.8 s, then blasts a radius of 36 for 24 damage and dies (no rewards). Killing it during the flash cancels the blast. | 12 | 58 | 4 |
| Support | 5:00 | Heals every other enemy near it, 6 health a second; drops more. | 22 | 30 | 4 |

**Elites** are a modifier on any role and element: 3 times the health, 1.5 times the damage, a little faster, 1.4 times the size, 3 times the XP and Gold, double the drop chance, with a bright outline. The chance is 0 for the first 2 minutes, then rises 2% a minute up to 20%.

### Elemental Affinities

Every enemy can have an elemental affinity.

This creates opportunities for players to adapt their spell loadouts based on the enemies they encounter.

For example, a Fire enemy takes extra damage from Sea, reduced damage from Land, and normal damage from Fire and Thunder (an enemy takes normal damage from its own element).

# 8. Bosses and Encounters

Bosses serve as major milestones during an adventure.

Unlike regular enemies, bosses have unique attack patterns and mechanics that require the player to actively react and reposition.

Potential boss mechanics:
- Large-area attacks that require dodging.
- Summoning additional enemies.
- Temporary elemental resistance.
- Multiple attack phases.
- Vulnerability windows after specific attacks.

The first boss is the **Ember Titan** (Fire element, 1,500 health). It arrives at 5:00 and then every 5 minutes after the previous one appeared, and never two at once. After a boss dies the run goes on and the next one is tougher (each extra boss has +50% health and +20% damage). While a boss lives, normal enemies spawn at half rate.

- **Phase 1** (down to half health): Slam, Charge, Summon, one every 2.5 s.
- **Phase 2** (below half health): adds Burst, attacks every 1.8 s, and moves 30% faster.
- **Slam:** marks your position, warns for 1 s, then blasts a radius of 48 for 30 damage. Move away.
- **Charge:** warns with a line for 0.8 s, then dashes along it (25 damage), then stands still for 2 s while it takes +50% damage.
- **Burst:** a ring of 12 shots after a 0.6 s warning.
- **Summon:** calls 4 Swarmers after a 0.8 s warning.

A boss pays 300 XP and 150 Gold (both times its number) and 2 Rare scrolls where it falls. A boss warning, health bar and the run clock show at the top of the screen.

Defeating bosses can reward the player with:
- Large amounts of XP.
- Gold.
- Rare spell-scrolls.
- Unique equipment.
- Special crafting materials.

# 9. World and Progression

The world is designed around surviving increasingly difficult enemy encounters.

As time progresses, enemies become stronger, spawn rates increase, and new enemy types are introduced.

### Difficulty Scaling

The difficulty follows the run clock (it stops while the game is paused). Enemy health grows 12% a minute, damage 6% and speed 2% (up to +25%), the spawn interval shrinks (0.5 s down to 0.12 s) and the most enemies alive grows from 150 up to 300. Difficulty can increase through:
- Increased enemy health.
- Increased enemy damage.
- Increased enemy movement speed.
- Increased enemy spawn rates.
- Introduction of elite enemies.
- Introduction of new enemy archetypes.
- Periodic boss encounters.

### Map Exploration

The player is encouraged to explore the map rather than remaining in one location.

Potential points of interest include:
- Arcane Lecterns.
- Treasure Chests.
- Health and Mana Shrines.
- Rare Scroll Drops.
- Boss Arenas.
- Merchant Encounters.

These points of interest provide incentives to move around the map and take calculated risks.

# 10. Art Direction and Presentation

### Visual Style

- 8-bit / pixel-art aesthetic.
- Top-down perspective.
- Comical fantasy setting.
- Cartoon architecture and environments.
- Bright, readable spell effects.
- Distinct elemental color palettes.

### Visual Identity

The world should feel mystical and magical, contrasting the colorful magical effects produced by the player's spells.

Each element should have a recognizable visual identity:

- Fire: Orange, red, and yellow.
- Thunder: Yellow, white, and electric blue.
- Land: Brown, green, and earthy tones.
- Sea: Blue, cyan, and turquoise.

### User Interface

The interface should prioritize readability during combat.

Important HUD elements include:
- Player health.
- Individual spell mana bars.
- Current XP and level.
- Gold collected.
- Equipped spells.
- Active buffs and potion effects.
- Remaining time until the next boss encounter.

# 11. Future Features and Potential Expansions

The following features could be explored after the core gameplay systems are established.

- **Spell Discoveries:** Unlock hidden combinations by experimenting with specific scrolls.
- **Rare Scrolls:** Introduce special scrolls with unique effects.
- **Spell Evolution:** Allow spells to evolve after reaching certain conditions.
- **Wizard Classes:** Introduce different starting characters with unique passive abilities.
- **Relics:** Add powerful passive modifiers that influence an entire run.
- **Curses:** Introduce powerful upgrades with negative side effects.
- **Biomes:** Create different environments with unique enemies and elemental affinities.
- **Endless Mode:** Allow players to continue surviving for as long as possible.
- **Challenge Mode:** Introduce special rules that alter the way a run plays.

# 12. Core Design Philosophy

The primary focus of the game is experimentation and resource management.

Players should feel encouraged to experiment with different spell combinations rather than relying on a single optimal build.

Every spell should have strengths and weaknesses, and every equipment choice should introduce a meaningful trade-off.

The most powerful wizard isn't necessarily the one with the highest damage output, but the one who can effectively manage their spells, exploit enemy weaknesses, and survive the chaos of an increasingly dangerous battlefield.