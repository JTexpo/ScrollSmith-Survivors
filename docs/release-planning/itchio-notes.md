# Publishing to itch.io

Verified on 2026-11-26 against itch.io's own help pages ("HTML5 games", https://itch.io/docs/creators/html5, and "Getting started", https://itch.io/docs/creators/getting-started). Anything not on those pages is marked NOT VERIFIED.

## What we already have
- A single-threaded Web export (`export_presets.cfg`, preset "Web", thread support off, no extensions), built by `.github/workflows/deploy-web.yml` and published to GitHub Pages. The single-threaded build needs none of the cross-origin isolation headers, which is the reason it was chosen and also what makes it suitable for itch.io's embedded player. (The itch.io HTML5 page does not mention SharedArrayBuffer.)
- PWA mode is off on purpose (a phone never serves a stale build while testing).
- The engine file (`index.wasm`) is about 39 MB uncompressed. VERIFIED: itch.io's limit is 200 MB for one extracted file, 500 MB in all and 1,000 files per zip, so the build is far inside the limits. itch.io gzips `html`, `js`, `wasm` and `pck` files itself.
- Since Sprint 15c the workflow also writes `licences.txt` into the build, checks it against these limits (`tools/release/check_itch_zip.gd`) and attaches `scrollsmith-survivors-<version>-itch.zip` to every run as the artifact `itch-web-zip` (kept 14 days).

## The itch.io rules (VERIFIED)
- The zip must have an `index.html` at its root; file names are case sensitive on itch.io's server (the checker also fails two names that differ only by case).
- At most 1,000 files after extraction; at most 500 MB extracted in all; at most 200 MB for any one extracted file.
- **Embed in page:** you set the viewport size. **Click to launch in fullscreen:** no size needed. Use "Embed in page" at 960 by 540 (a whole multiple of 480 by 270).
- **Fullscreen button:** itch.io can add one (bottom right in embed mode) if the engine has none. The game has its own Full screen button as well.
- **Mobile friendly:** when ticked, phones start the game in the fullscreen launch mode whatever the desktop setting; when not ticked, phone visitors see a warning that the game may not work. Tick it.
- Page visibility: new pages are **Private** by default; "Public restricted" publishes without allowing purchases; "Public" publishes. "Save & view page" previews a private page. (itch.io's own word is Private, not "draft".)
- Cover image ratio 315:250, minimum 315 by 250, recommended a larger one at the same ratio such as **630 by 500**. Screenshots: **3 to 5**, any size. Genre plus up to **10 tags**; more detailed classification is on the Metadata tab after the first save.
- NOT VERIFIED: a size limit for an animated GIF cover or screenshot (the pages say nothing; the GIF in `promo/` is kept under 3 MB to be safe), and any upload size limit for a new account (itch.io says new accounts can have one that support raises on request; the real zip size is measured in Task 8 of the Sprint 15c plan and noted in the development log).

## Steps (what the user does)
1. Merge the Sprint 15c branch. Open the repository's Actions tab, run "Deploy web build to GitHub Pages" (or use the run from the merge), open the finished run and download the artifact `itch-web-zip`; unzip it once and check that `index.html` sits at the top.
2. Create the itch.io project (kind: HTML). Paste the text from `itchio-page.md`, upload the zip and tick "This file will be played in the browser", set the embed size 960 by 540 and tick Mobile friendly and Fullscreen button. Upload the pictures from `promo/` (cover 630 by 500, 3 to 5 screenshots). Leave visibility **Private**.
3. "Save & view page" and play it on a desktop and on a phone inside itch.io's own frame. Walk through the manual checklist in `release-checklist.md` (sound after the first tap, touch controls, a full run, saving, the Tutorial, the rotate hint on an upright phone).
4. Set the visibility to **Public** when you are satisfied.

## Decisions (settled)
- Free. Licence: all rights reserved (`LICENSE`, the Credits and `licences.txt`). Version `1.0.0`. The Pages build stays live as the test build. A manual upload of the zip (no `butler`, no API key, no secret); `butler` can be added later as one more workflow step.
