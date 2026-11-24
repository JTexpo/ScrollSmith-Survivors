# Publishing to itch.io (notes, not a plan)

**Everything marked VERIFY was written from memory. Check itch.io's current documentation (their "HTML5 games" and "Game page" help) before relying on it.**

## What we already have
- A single-threaded Web export (`export_presets.cfg`, preset "Web", thread support off, no extensions), built by `.github/workflows/deploy-web.yml` and published to GitHub Pages. The single-threaded build needs none of the cross-origin isolation headers, which is the reason it was chosen and also what makes it suitable for itch.io's embedded player.
- PWA mode is off on purpose (a phone never serves a stale build while testing).
- The exported package is small (about 225 KB) and the engine file (`index.wasm`) is about 39 MB uncompressed; Pages compresses it on the wire (verify what itch.io does with it, see below).

## What itch.io needs
- **A zip of the export** with `index.html` at the zip's root (VERIFY the exact rule), uploaded as a project of kind "HTML" with "This file will be played in the browser" ticked. The workflow could attach the export folder as an artifact, or the zip can be made by hand from `export/web/`.
- **Size limits** (VERIFY): itch.io limits the number of files and the total size of an HTML5 upload; the 39 MB engine file may be near or over a per-file or total limit, in which case the web build must be re-exported with a smaller engine (a custom export template with unused modules disabled) or hosted elsewhere and embedded.
- **Viewport size:** the game is 480 by 270 scaled by whole numbers. Pick an embed size that is a whole multiple (960 by 540 or 1440 by 810) and enable the "Fullscreen button" option; the game also has its own Full screen button.
- **Mobile** (VERIFY): itch.io shows HTML5 games on phones in its own frame; test touch there, because the page may add margins or its own scrolling.
- **Audio autoplay:** the game already waits for the first tap, click or key before playing sound, as browsers require.
- **Page content** the page needs from us: title, a short description, a cover image (itch.io recommends a particular size, VERIFY, around 630 by 500), 3 to 5 screenshots, a genre and tags, a "made with Godot" mention, and the controls summary (take it from the Controls page, `ControlsText`).

## Decisions for the user when ready
- Free or paid (and "pay what you want").
- Which licence statement goes on the page and in the repository.
- Whether the Pages build stays live (yes is simplest: two places, one workflow) or is replaced.
- A name for the release (a version number such as 0.1.0) and whether itch.io's butler tool or a manual zip upload is used (butler needs an API key stored as a repository secret; never commit it).
