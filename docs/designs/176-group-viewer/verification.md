# Prototype verification

Date: 2026-11-18. Artifact scope: standalone HTML and design documentation only.

## Executed

```sh
python verify_prototype.py --chromium /usr/bin/chromium --evidence prototype-evidence
```

The script reads the adjacent `index.html`, extracts its inline JavaScript for `node --check`, and loads the HTML bytes into headless Chromium with Playwright. Browser `file:` navigation is blocked by the execution environment's policy, so automated tests use `set_content`; they do not claim a local-file navigation test in this environment. The artifact contains no external dependencies or network requests.

**Result: 87 checks passed; no browser runtime errors.**\
Chromium: `144.0.7559.96`. Node syntax check: `v22.16.0`.

Checks cover three variant placements, identity retention including the second item in a grid row, passive Timeline scrolling and offset restoration, ordering from both views, custom Save/Cancel/Undo, group-kind preference and outer-occurrence restoration, explicit boundaries, Series/Pixiv order restrictions, Pool sort options, unavailable/restricted positions, restricted origin preview, partial manifests, retry/loading, modal focus and Escape, repeated keyboard navigation, and chrome visibility.

Structural layout checks cover A/B/C × dark/light/AMOLED × phone/narrow/wide; narrow 320-pixel device layouts with 200% app text; and browser widths 320, 390, 768 and 1280. They assert no horizontal document/device/app overflow and a remaining content region, not perfect typography or full visual accessibility.

Rendered screenshots of Single and Timeline for each variant, the full workspace and the custom order dialog were captured. Screenshots were visually inspected during iteration. The download bundle includes the final captures and machine-readable `results.json`; rerunning the script recreates them. Earlier failed iterations are not claimed as passing results.

## Limits

This is not Flutter execution, an emulator run, device testing, screen-reader testing, a user study, a native gesture/zoom test, a pixel-accurate screenshot comparison, or independent UX review. No production app code changed, so no app build or Flutter test suite was run for these HTML/docs changes.

The prototype uses six original illustrative media fixtures, fixed example profiles, session-only state, synchronous actions and simulated loading. Native favorite/bookmark/download/share operations are not performed. No real credentials or private media are used. Changed network authorization, API failures, animated media and real production preloading cannot be validated by this artifact.

The design's per-profile durable preferences, occurrence-key-plus-offset restoration, async save reconciliation, real engine capability gating, native safe-area behavior, current media-to-Details transition, Timeline auto-hide header and predictive Back cancellation remain implementation work. The HTML's browser dialogs are comparison surfaces, not replacement specifications for those established behaviors.

## Review provenance

A structured author self-review identified and corrected prototype issues. The requested independent UX specialist subagent was not available through the exposed execution tools. `ux-review.md` contains the limitations and a concrete brief for an independent reviewer; it is not a fabricated reviewer report.


## 2026-11-18 screenshot-aligned iteration

- New main `index.html`: reworked to resemble the four user-provided actual screens; original A/B/C exploration archived as `original-study.html`. User screenshot images/crops are not committed. Repo prototype embeds self-authored stand-in SVG artwork.
- Local Chromium / Playwright checks on exact HTML: **40 assertions passed**, zero uncaught JavaScript exceptions; scenarios cover Pixiv Single/Timeline/Details, Pool 68-member group plus Ordered/Latest, Series and Related default modes, Related Custom Save/Cancel and Single editor, tile drill-in and Back, B/B+/B−, no extra navigation rail, and no horizontal overflow at 360/740/1200px.
- Inline JS passed Node 22 syntax verification. Browser used `page.set_content` with HTML bytes because this environment blocks file:// navigation; no claim of native Android, Flutter, screen-reader or real network testing.
- Pool/Series fixtures generate 68/12 members for ordinal coverage; Pool Latest/Oldest are illustrative ordering, not live source timestamps. Native gesture ownership, profile authorization, keyboard focus, text scaling and real media fit remain unverified.


### Reproducible scripts after the revision
- `python docs/designs/176-group-viewer/verify_prototype.py --chromium /usr/bin/chromium` targets the **current B prototype** and passed **33 checks locally** on the exact HTML and script bytes subsequently committed. It does not write evidence files.
- `python docs/designs/176-group-viewer/verify_original_study.py --chromium /usr/bin/chromium --evidence <dir>` retains the initial A/B/C scenario checks against `original-study.html`. The old 87-check result applies only to that archived initial version.
- The larger 40-check local exploratory script covered additional actions but is not a packaged repository test. These are browser-only checks and do not establish Android acceptance.

## 2026-11-18 B+ decision and verification status

The user explicitly chose **B+**, the one-tap destination-icon switch, and clarified that the application has **one shared fullscreen viewer**, not a Pixiv-only viewer. The design branch HTML now selects B+ by default; the companion reproducible browser script has been updated with four assertions for the default and both toggle directions.

Locally, a B+ patched copy of the screenshot-aligned handoff HTML passed **20 Playwright/Chromium assertions** across Pixiv, Pool, Series and Related, including one-tap switching in both directions and zero uncaught JS errors; inline JS passed Node 22 syntax check. These assertions used a local handoff copy, **not the exact latest remote GitHub blob**. The updated full branch verification script must still be run against the committed `index.html` before claiming a new complete browser test pass. No Flutter/native UI tests were run.

## 2026-11-18 Related Single sorting correction

The user clarified that the earlier Custom Related order editor was unintended. Current active mockup now defaults Related Groups to Single, adds a compact Oldest/Newest dropdown alongside the existing page counter (Immersive and Detailed), shares the same selected order with Timeline, and demonstrates saving/restoring that standard order with a Related Group Bookmark. The Custom editor, custom reorder state, actions and styles were removed; Series remains Single/Ordered, and Pool keeps its existing standard sort options.

**Fresh local browser verification:** 51 targeted Playwright/Chromium assertions passed against the revised standalone HTML, including group defaults, independent bookmark targets, the two sort options only, member-identity retention, saved sort state, Single↔Timeline synchronization, Detailed selector placement, overflow selector, Pool sorting and 320/340/360/390/740/1200 px viewport checks. Inline JavaScript passed Node v22.16.0 syntax check. A popup anchor issue discovered during the overflow check was corrected and retested. The generated local HTML text was compared against the latest remote GitHub file text and matched after the correction. This is not a Flutter/device test or a genuine independent UX review. Historical test counts below refer to older mockups only.

## 2026-11-18 Dual Bookmark buttons

The user selected two immediately visible Bookmarks distinguished by small image/collection scope badges (not the earlier split picker). The SVG fixture mockup has been updated at `index.html`; the earlier split-picker recommendation is explicitly marked superseded in `screenshot-alignment.md`. The reproducible `verify_prototype.py` now includes cases for these two independent targets.

**Local browser evidence:** 76 assertions passed across the self-contained SVG-illustration HTML and the private screenshot-art preview in Chromium, with no uncaught JavaScript exceptions. Cases include both Bookmark icons in Single and Detailed, independently saving/removing Work and Page versus Pool and Post, restored status on Timeline and B+ switching, Danbooru remote Post Favorite remaining independent, Related group bookmark in header, and responsive widths 320/340/360/390/740/1200. Embedded JavaScript in both HTML files passed Node v22 syntax checking. Captured local phone screenshots for Pixiv and Danbooru Pool were inspected for toolbar crowding.

**Limit:** the local assertion run used current generated HTML outputs corresponding to the design (with the screenshot-art output kept private), not execution of the newly committed repository test script against the **exact remote Git blob**. Repository scripts and HTML are published for local checkout and reproduction. No live site operation, API/account access, Flutter build, Android device tests or independent UX specialist review was performed. Existing historical results above apply to the prior prototype revisions only.

## 2026-11-18 Header placement adjustment

The user explicitly moved the existing `Oldest / Newest` selector from beside the page counter to the **upper Single viewer header**, before the one-tap B+ action (and Info in Immersive). The counter remains independently positioned. Detailed retains both controls with the counter in its established top-right area; the B+ control now has an opaque background for contrast on bright images. No new permanent toolbar or independent sort state was introduced. Issue [#176](https://github.com/timberpile/Boorusama/issues/176) was updated to link this design and the accepted UX decisions, without creating another issue.

A local copy of the revised standalone HTML passed **658 targeted Playwright/Chromium assertions** (mode defaults, Related sort persistence, Single/Timeline sync, 320/340/360/390/480/740/1200px layouts, all four content kinds and header/button non-overlap in Immersive and Detailed); no uncaught JavaScript errors. Its inline script passed Node v22 syntax checking. A separate screenshot-art copy passed smoke checks at 320/390px. Screenshots of the updated header were inspected. These checks were run against local generated copies with the same targeted code changes; they do **not** establish execution of the exact published GitHub blob or Android/Flutter acceptance.
