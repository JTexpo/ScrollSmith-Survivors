# Release checklist (the parked Sprint 15c)

## Blocking the next publish
- [ ] **Web build has no sound** (see the first item under "Open items" in `future-roadmap.md`). Find the cause in a real browser and fix it, then check on desktop Chrome and Firefox and a phone before publishing.
- [ ] The published address is now `https://jtexpo.github.io/ScrollSmith-Survivors/` (the repository was renamed); update the address in `CLAUDE.md` ("Web build and GitHub Pages") and anywhere else it is written.

## Still to do from the Sprint 15 list
- [ ] Create the game icon.
- [ ] Create promotional screenshots.
- [ ] Create promotional artwork.
- [ ] Perform final playtesting.
- [ ] Fix release-blocking bugs.
- [ ] Create the release build.

## What the project lacks today (found 2026-11-24)
- **No icon.** `project.godot` has no `config/icon`, so the browser tab shows Godot's default icon. The Web preset has `html/export_icon=true`, so adding an icon fixes the favicon. Plan: draw a pixel-art icon (the wizard and a scroll) with the art pipeline and scale it by a whole number for the file (the one place scaling is unavoidable).
- **Default web page.** The preset uses Godot's own HTML shell (`html/custom_html_shell=""`, `html/head_include=""`): no description meta tags, Godot's loading screen, no hint for portrait phones (the game is landscape, 480 by 270 with integer scaling).
- **No version number** anywhere (not in `project.godot`, not on screen). Plan: a `config/version` setting shown small on the home screen and in Credits.
- **Licence notices.** Credits mention Godot and GUT but not their licences. Plan: a "Third-party licences" section (Godot is MIT, GUT is MIT; confirm the exact notices to include) and a decision on the licence of the game's own code and art (the user's call).
- **No real-phone numbers.** Every performance figure so far is from a desktop laptop. The performance overlay (F3, or a 1 second press on the mute button) lets testers send a screenshot. See `future-roadmap.md` for the slow-device question.
- **Promotional material** is not made. Plan: screenshots taken from the real game with the existing scratchpad pattern (a throwaway save, a staged scene, `--resolution` at a whole multiple of 480 by 270) and a key-art banner composed from the game's own sprites; the user judges the art.

## Manual test checklist (run before any public release)
Run on the Pages build and on the itch.io build once it exists.

1. **First load:** the page loads, the home screen appears, no console errors, the tab title and icon are right.
2. **Audio:** music starts after the first tap or key (browsers require it); the M key and the HUD speaker button mute; Settings volume sliders change loudness and are remembered after a reload.
3. **Touch (phone, landscape):** the left stick moves, the right stick aims and casts, spell slots, potions, Interact, Inventory, Pause and Mute buttons all respond; the Full screen button works; every button is easy to hit.
4. **A full run:** Play, kill enemies, collect scrolls, craft a spell at a Lectern, drink a potion, use a shrine and the merchant, fight a boss, die, read the death card, tap Home.
5. **Saving:** XP, Gold and equipment survive closing and reopening the tab; New game asks twice and erases only after the second yes; Settings survive New game.
6. **Pause and inventory:** the pause menu and the inventory both stop the world; Quit to home works and shows no errors.
7. **Tutorial:** all four pages open, page, and close by touch, mouse, keyboard and controller.
8. **Browsers:** Chrome, Firefox and Safari on desktop; Chrome on Android; Safari on iPhone. Note any that fail.
9. **Performance:** open the overlay in a busy fight (many enemies, a boss) and record frames per second on each device.
10. **Portrait phone:** note what a player sees (a hint to rotate is planned).

## Known issues to decide on before release
See "Open items" in `future-roadmap.md`: the Zone balance, slow-device behaviour, the death card's "Level reached" row, and the deferred minors from the 14c, 15a and 15b reviews.
