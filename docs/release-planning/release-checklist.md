# Release checklist (Sprint 15c, built 2026-11-26)

## Blocking the next publish
- [x] **Web build has no sound**: fixed 2026-11-25 (bus layout), verified in a browser. **The user still confirms it by ear** on the live site and in itch.io's frame.
- [x] The published address is `https://jtexpo.github.io/ScrollSmith-Survivors/` (`CLAUDE.md` updated, a test guards it).

## Sprint 15 list
- [x] Create the game icon (`assets/icon.png`, built from `art/sprites/app_icon.sprite`).
- [x] Create promotional screenshots (`docs/release-planning/promo/`; the user judges them).
- [x] Create promotional artwork (the cover and the fight GIF).
- [ ] Perform final playtesting (the user: the manual checklist below, on a desktop and on a phone).
- [ ] Fix release-blocking bugs (none known; the playtest may find some).
- [x] Create the release build (the workflow's `itch-web-zip` artifact; version 1.0.0).

## What was missing and is now done
- Icon, a version number (1.0.0, in `project.godot`, Credits and the home screen), licence notices (`LICENSE`, the Credits lines and `licences.txt` in the build), the page's description and tags (`html/head_include`), a rotate hint for an upright phone, the page text (`itchio-page.md`) and the pictures.
- **Still open:** real-phone performance numbers (every figure so far is from a laptop; the performance overlay, F3 or a 1 second press on the mute button, lets testers send a screenshot; see `future-roadmap.md` for the slow-device question) and the Private test upload to itch.io.

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
