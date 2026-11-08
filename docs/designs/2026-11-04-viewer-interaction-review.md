# Image View / Overview: Local-Image Experiment and Review

Date: 2026-11-04. Application baseline: `e306ff5338a2255a89731c61bd0672336a933344`.
Branch: `maintenance/content-architecture-design`.

This is a **design-only supplement**, not approved Flutter behavior. It follows the user's questions about the visual guide and their request to select local images in the prototype. Runtime stabilization still precedes the architecture implementation.

## Start here

- [Image View / Overview Lab](mockups/2026-11-04-viewer-interaction-lab.html): standalone HTML with multiple local-image selection, separate Work/page navigation, extreme aspect ratios and a current-Classic comparison.
- [Plain-language model and navigation clarifications](2026-11-04-content-model-and-viewer-clarifications.md): Pool versus Gallery, the proposed wrappers, and each responsibility with an example.
- [Earlier A/B/C, architecture and Favorites comparison](mockups/2026-11-04-content-design-lab.html): retained as historical alternatives. This newer lab does not silently approve one of them.

Download the HTML file and open it in a browser. No build or server is required by the file. GitHub's normal blob view displays its source rather than running it.

## Local images

Every file-selection operation creates one temporary Work containing the successfully decoded images from that selection. Select files again to create another Work and test skipping without first viewing all pages. The native chooser supplies ordering; there is no reorder editor in this experiment.

The same selected image drives the viewer and the zoom calculation. Width and height come from the decoded local image, not a guessed preset. Local filenames are inserted as text, not HTML. No artist, tags or remote statistics are inferred for local files.

Files remain browser-local through object URLs. The file performs no network requests, has a `connect-src 'none'` policy, contains no analytics and does not store image bytes in browser persistence. Clearing local images revokes their URLs. Reloading discards the selection. Neither this publication nor the prototype uploads user images to GitHub or ChatGPT.

Supported input types: PNG, JPEG, WebP, GIF, AVIF and BMP when the browser can decode them. SVG input is deliberately excluded; the built-in fixtures are code-owned inline SVG. Limits are 30 files per selection, 60 retained local images, 25 MB per file and 80 million decoded pixels per image. Corrupt/unsupported/oversized files are skipped with a count. These are prototype safeguards, not proposed app limits.

## Interaction under discussion

**Image View** keeps one image central. **Overview** attaches artist/actions/description/tags and lower related-content sections beneath that same image. A single image tap toggles these states; a double-tap zooms without first revealing Overview. The prototype delays the single-tap action briefly to distinguish the two.

The image node and URL survive a mode change. Overview uses an uncropped preview, adapting its height for wide images and bounding tall images. A full-strip comic preview is only context, not a readable comic. Returning to Image View restores that page's reading transform. Switching pages or Works does not force the view mode back to an initial preference.

No persistent previous/next image or Work buttons appear inside the simulated phone. Desktop test controls live outside it; keyboard equivalents are supplied.

### The unresolved two-level navigation problem

One ordinary horizontal swipe cannot simultaneously mean next page and skip the remainder of a Work. This prototype deliberately makes the distinction explicit:

- Swipe the unzoomed image horizontally to change pages.
- In Overview, swipe the title/description area horizontally to change Works immediately.
- Optional two-finger parallel swiping is an experimental shortcut for changing Works in Image View. It is disabled by default. A detected pinch cancels the shortcut.
- A page swipe does not automatically cross the Work boundary. Returning to an earlier Work restores its selected page.

These are **alternatives to evaluate**, not an approved gesture contract. The Overview gesture costs a tap when starting in Image View and has discoverability/text-selection tradeoffs. Two-finger recognition needs physical Android testing against pinch zoom, TalkBack and system gestures. Do not advertise it as solved by this browser prototype. Existing production zoom-edge navigation is not reproduced here.

## Current Classic versus the candidate

Source reference: [Kurumi interactive viewer](https://github.com/timberpile/Boorusama/blob/e306ff5338a2255a89731c61bd0672336a933344/packages/kurumi/lib/src/components/interactive_viewer.dart#L526-L715).

Current Classic uses a 3.0 fixed target for normal shapes and exact other-dimension fitting when aspect mismatch exceeds 3.0. An existing non-identity transform resets to contain, including an automatically width-fitted comic. The previous lab's Comic reference used a reading baseline, so it was not an exact Classic comparison for that case.

The new lab preserves Classic's two-state reset for comparison and makes only the candidate's first target aspect-aware, with adjustable floor/cap. The default trial values, 1.35 and 4.0, are not approved constants. Tall Comic fitting is handled separately. Exact other-fit is also selectable and deliberately demonstrates the no-op for viewport-matched images.

Illustrative 400 x 800 usable viewport targets, before runtime constraints:

| Image | Current Classic | Candidate floor 1.35 / cap 4 |
| --- | ---: | ---: |
| Portrait 1200 x 1800 | 3.00 | 1.35 |
| Square 1000 x 1000 | 3.00 | 2.00 |
| Landscape 1600 x 900 | 3.56 | 3.56 |
| Panorama 4000 x 1000 | 8.00 | 4.00 |
| Matched 1000 x 2000 | 3.00 | 1.35 |

The actual prototype reports its measured media viewport. These values are relative to contain, not original pixel size. Flutter animation, scale limits, original-on-zoom media changes, video gestures, per-profile gestures and Auto Comic revisit policy still need integration testing. Do not infer production equivalence from the simplified browser transforms.

## Model and Favorites recommendations

Pool/Series/Collection/Gallery do not require four separate shared implementations. Danbooru Series and Collection share a Pool type; category remains meaningful for such behavior as Series-only timeline grouping. A native `gallery` address does not demand a separate global UI class. The engine identifies the source; stable kinds disambiguate resources where needed within it.

`PostListEntry` and `GroupListEntry` are proposed variants of `ContentListEntry`, describing slots in a genuinely mixed list, not new media models. Existing `ViewerEntry` remains the viewer occurrence. Summary/details/session/presentation are responsibilities to keep clear, not eleven mandatory new public classes.

For Pixiv Favorites, the recommended placement is the **compact Timeline Toolbar selector**. Scope is a list filter, the selected Public/Private state remains visible and it consumes no additional row. It follows the toolbar's agreed hide/reveal behavior. Header menu is the fallback if actual narrow-layout testing shows unacceptable crowding. Placement is not approved yet; do not add an unverified All scope.

## Verification

Final HTML blob checked locally and against GitHub: `ee9036a69ae59b623fdd211d9ee88e1b2c578c97`.

**35 Chromium/Playwright assertions passed**, with zero JavaScript errors and zero HTTP/HTTPS requests. Coverage includes local multi-file loading, corrupt input, multiple Works, safe filenames, object-URL cleanup, unsupported SVG rejection, single/double-tap separation, mouse page swipe, Overview Work swipe, keyboard navigation, boundary behavior, mode persistence, selected-page restoration, comic reading-transform restoration, Classic square/Comic cases, aspect-aware target and document overflow at 320/390/768 px.

A native browser drag initially cancelled mouse swipes. A `dragstart` trace identified the cause; disabling native image dragging fixed it, and the expanded checks passed again.

Reproduce with the companion Python script (Playwright, Pillow and Chromium installed):

```sh
python docs/designs/mockups/2026-11-04-viewer-interaction-check.py \
  docs/designs/mockups/2026-11-04-viewer-interaction-lab.html
```

The runner writes its report and generated fixtures to `.worktrees/_artifacts/content-design-lab` by default. The review environment blocks `file://` navigation by policy, so automation loaded the unchanged HTML via `page.set_content`; a browser-file navigation test was not claimed. The content is self-contained and does not use server APIs. No private images were used in testing.

No Flutter, Maestro, physical-device multi-touch, TalkBack, authenticated API, APK or application regression tests were run. No runtime files, issues, PRs or develop changes were made. The original diagrams and earlier prototypes remain available; only design material is published here.
