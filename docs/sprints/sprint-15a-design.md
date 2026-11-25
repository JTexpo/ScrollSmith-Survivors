# Sprint 15a Design: The front door

**Status:** Built (Sprint 15a).

Sprint 15 is three parts: **15a** the front door (this doc), **15b** onboarding and run statistics, **15c** release preparation. Scope comes from the Sprint 15 list in `sprint-development.md`, `CLAUDE.md` and the user's answers in conversation. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Today the game opens straight into a run, has no pause, and its effect and audio settings exist only in code. 15a gives it a **home screen**, a **pause menu**, a **Settings screen that saves**, and a safe **New game**.

**Goals (user decisions)**
- **A home screen** with: Play (later a map select), Shop, Tutorial (the pages arrive in 15b), Settings and New game. Achievements come in a later sprint.
- **A pause feature for runs**, and **the inventory pauses the game** while it is open (a deliberate reversal of the Sprint 5 rule that it did not pause).
- **New game erases everything** (XP, Gold, equipment) and starts at level 1, **asking twice**, once for each destructive step.
- **How the game opens and closes stays as it is** (no quit button on the web; closing the tab is the exit).
- **The home screen is its own scene** (approach A, chosen by the user), loaded first; Play loads the run scene and "Quit to home" loads the home scene back.

**My calls**
- **Settings are saved in their own file** (`user://settings.json`, versioned JSON, written like the save through a temporary file and a rename), apart from the progress save. New game erases progress and keeps your settings, and a bad settings file never touches progress (it is renamed `.bak` and defaults apply).
- **Settings contents:** Music and Effects volume sliders, the effect switches and the two scales from `FxSettings` (shake and flash strength, particles, low-health frame, heart, hurt flash, hit arcs, low-mana pulse), the performance overlay switch, a "Reduce motion" button, a read-only **Controls** page (keys, controller and touch), and Credits. No key remapping in this sprint.
- **The Tutorial button is shown but dimmed** (marked "soon") until 15b adds its pages.
- **New game keeps one backup:** the old save is renamed `save.json.bak` (the existing "a save is never deleted" rule), so a mistake is recoverable by hand. The two confirmations name what is erased.
- **The pause menu** offers Resume, Settings and Quit to home (which asks first, because the run's unspent XP is already saved but its potions, scrolls and spells are lost). It opens from the `pause` key and controller Start, and from a **HUD pause button** (a phone has no Esc key). Other screens that already close on `pause` (crafting, shop, merchant, pick) keep doing so and the pause menu does not open over them.
- **The death screen gains a Home button** beside Shop; restarting is unchanged.
- **Credits** is a short text page: the game's name, the tools (Godot, GUT) and "Made by" lines the user fills in.

**Non-goals**
- The tutorial pages and the fuller game-over screen and statistics (15b); the icon, promotional art, final playtesting and the release build (15c); a map select, achievements, key remapping.
- Any change to gameplay, balance, or how a run starts apart from loading it from the home screen.

**Anti-goals** (a failure even if it technically works)
- A New game that can erase progress with one stray tap, or that also wipes settings.
- A run that starts behind the home screen (the run scene must not be created until Play).
- A pause that leaves the world, music or timers running wrongly (the run clock, potion cooldowns, the soak-proven counts), or that is left on after leaving to home or restarting.
- Touch not working on any new screen (the project has mouse emulation off, so every screen handles its own touches, as the shop does; a sliders and toggles screen is the riskiest).
- A settings screen the effects ignore, or settings that do not survive a restart.
- A new autoload, or gameplay code that knows about the settings screen.

## 2. Approaches

- **A. Home as its own scene (chosen by the user).** `home.tscn` is the starting scene; the run scene is untouched until Play. Cost: one scene change on Play and on Quit to home.
- **B. A menu layer inside the run scene.** The run would already be running behind the menu (its buff picks, crowd and timers start in `_ready`), and every test that builds the run scene would grow a menu state. Not chosen.
- **C. Keep the run scene first and pause it until Play.** Same problems, and New game is awkward with the save already loaded. Not chosen.

## 3. Decisions

| Area | Decision |
|---|---|
| Start scene | `project.godot` `run/main_scene` becomes `scenes/home/home.tscn`. The run scene (`main.tscn`) still works when launched directly (the dev tools, the stress scene and the tests do that) and applies the saved settings itself, so a direct launch behaves the same. |
| Home screen | `HomeScreen` (a scene under `scenes/home/`): the sky backdrop, the game's name, the idle wizard sprite and a column of themed buttons, each at least `UiKit.ACTION_SIZE`. It loads the progress save (`SaveGame.load_profile`) and owns the Shop and New game flows. Play calls `SceneSwitcher.change_to` on the run scene. Keyboard and controller focus work, and touches are handled by the screen (the `TouchBridge` as in the shop). |
| Shop from home | `ShopScreen` is reused unchanged: the home screen opens it with its profile and saves after each successful action (as `Main` does), then closes back to the home buttons. The death screen's Shop keeps working. |
| New game | `NewGameFlow`: confirm 1 "Erase all progress? Your XP, Gold and equipment will be erased. Settings are kept." then confirm 2 "This cannot be undone. Start over from level 1?" (default focus on the safe choice, Cancel is the first button). On the second Yes, `SaveGame.erase(path)` renames the save to `save.json.bak` (replacing an older backup), the home screen reloads a fresh profile and says "Starting over." A tap outside the dialog cancels. |
| Settings data | `GameSettings` (static values: `music_volume`, `sfx_volume`, 0 to 1, default 0.8) beside the existing `FxSettings`. `SettingsStore` (static): `load(path)`, `save(path)`, `to_dict`, `apply_saved()`. The file holds `version`, the two volumes and `FxSettings.to_dict()`. A missing file is defaults; an unusable one is renamed `.bak`; unknown keys and wrongly typed values are ignored (as `FxSettings.apply` does). Tests use a folder inside `res://.godot/save_tests/` and never touch the real file. |
| Applying settings | `SettingsStore.apply_saved()` runs at the start of the home scene and of the run scene. A change in the Settings screen applies at once (the `SoundBoard` listens for a static `SettingsEvents.changed` announcement, like `EnemyAttackEvents`, and sets its Music and Sfx bus volumes; the effects already read `FxSettings` live) and is saved when the screen closes or after each change (my call: after each change, so quitting cannot lose it). |
| Settings screen | `SettingsScreen` (a `CanvasLayer`, process mode Always): the sliders, the switch toggles, Reduce motion, Controls and Credits sub-pages, Close. Used by the home screen and the pause menu. Sliders and toggles take touch through the screen's own handling (the bridged left click). |
| Pause menu | `PauseMenu` (a `CanvasLayer` in `main.tscn`, process mode Always) using `GamePause.set_paused`: Resume, Settings, Quit to home (asks first). `Main` opens it on `pause` when nothing else that handles `pause` is open and the player is alive, and on the HUD `PauseButton` (a new small HUD button like `MuteButton`, at least 32 by 32, hidden on death). Opening freezes the world and `GameTime` as the other screens do; music drops as it already does when the tree is paused. Closing, quitting and restarting all unpause. |
| Inventory pause | Opening `InventoryPanel` pauses through `GamePause.set_paused` and closing resumes; it pauses even though the panel has no buttons that need time to stop. Death closes it as now. `CLAUDE.md`'s Sprint 5 line is updated. |
| Death screen | A Home button beside Shop (96 by 32 like the Shop button, handled by `DeathScreen.handle_event` so a tap on it goes home and never restarts, as the Shop button's tap does). |
| Credits and controls | Plain text pages built with `UiKit` labels. The Controls page lists every action's keys from the Input Map, so it cannot drift from the real bindings, with the touch controls described in text. |
| Guards | `test_front_door_guards`: no script outside the home, settings and `Main` code references the settings screen; no autoload; the run scene is not instantiated by the home screen until Play; every new screen handles touch (the existing world-input rules and a per-screen touch test). |

## 4. What is left to the builder
- The home screen's exact layout, the title treatment, and the wizard's pose and size (existing sprites only; no new art is required).
- The pause button's art (an existing UI icon or a new 12 by 12 pixel icon from the art tool).
- The exact slider and toggle controls and their theme variations, as long as they use the game theme and are at least 22 px tall on touch.
- The Controls page's text and the Credits lines.
- The wording of the two confirmations (the meaning above is fixed).

## 5. Verification plan
- **Settings tests:** round trip, defaults for a missing file, a bad file renamed `.bak` and defaults used, unknown and mistyped values ignored, volumes clamped 0 to 1, applying sets the bus volumes (through the board), switches apply to `FxSettings`.
- **Home screen tests:** it builds its buttons, Play requests the run scene (not created before), the Tutorial button is dimmed, focus and accept work, Shop opens and saves a purchase, a failed purchase saves nothing.
- **New game tests:** the first Yes only advances, Cancel at either step changes nothing, the second Yes renames the save to `.bak` and leaves settings alone, a missing save is fine, a fresh profile is level 1 with no Gold or equipment.
- **Pause tests:** `pause` opens it only when alive and nothing else is open; Resume, Settings and Quit to home (with confirm) behave; the tree is unpaused after each exit; `GameTime` and the run clock are frozen while paused and continue after; the HUD button works for touch and click; opening the inventory pauses and closing resumes.
- **Death screen tests:** the Home button's tap goes home and never restarts, and restart still works elsewhere.
- **Real window (touch rule):** the home screen, Settings (a slider and a toggle by touch and by mouse), New game's two steps, the pause menu and the pause button, checked with `Input.parse_input_event` in window coordinates, plus screenshots of each screen. Not checked on a phone.
- `godot --headless --import` after adding a `class_name`, then the full suite and a smoke run (the smoke test's start scene follows the project's main scene).

## 6. Revisions during the build

- **Full screen (user request mid-build):** a Full screen button on the home screen and a toggle in Settings, a saved `GameSettings.fullscreen`, and `ScreenMode` (a desktop applies the saved choice at start; a browser only allows it from a tap, so never at start there).
- `SettingsScreen.set_scale` became `set_strength` (`CanvasLayer` has a built-in `set_scale`).
- The home screen holds the shop, settings and confirm screens as child scenes, not `load()` calls.
- The suite's short soak passes a looser slope limit (the verdict takes a `slope_limit`).
- A scene-changing tap: the screens take `get_viewport()` before handling input.
