# Boorusama navigation concept lab

Three interactive alternatives using the same synthetic content:

- **A — Familiar sidebar:** global drawer, existing destination hierarchy, no phone task bar.
- **B — Task navigation:** Browse / Following / Bookmarks / More; adaptive rail/sidebar; separate Feeds and Pins histories.
- **C — Workspaces:** independently retained named contexts, desktop tabs, mobile space picker, searchable Jump.

[Design and recommendation](../../2026-10-09-navigation-concepts.md)

## Open

Open `index.html` in a modern browser. No build, package installation, server, CDN, API key or account is needed. For browsers that restrict local file scripts, serve the repository root:

```sh
python3 -m http.server 8000
```

Then open `http://localhost:8000/docs/designs/mockups/navigation/`.

Examples when served locally:

```text
index.html?concept=A
index.html?concept=B#/following/folder/atmospheres
index.html?concept=B#/bookmarks/group/scenery
index.html?concept=C
```

These initial hash routes are illustrative. They do not implement the application's complete deep-link contract. Direct links do not reconstruct every intermediate parent in this lab; use the in-app folder navigation to test full hierarchy retention.

## Review

Use the concept buttons outside the app to switch A/B/C. Each keeps independent demo data. Phone, Tablet and Desktop change the available preview width; on an actual narrow browser the preview still respects the window. Scenario controls jump to nested folders, selection, sign-in, offline, empty and unavailable-profile states. Large text, light theme and keyboard-height controls stress the layout without changing real system settings.

Navigate by clicking inside the app. Long-press a post or use Page actions → Select items. Shift-click extends a range; long-press and drag demonstrates range selection. Browser Back/Forward is chronological; the app's Back button follows the current hierarchy. Dirty forms ask before discarding changes. Outside menu taps close the menu without opening a post underneath.

Try these journeys:

1. Open Bookmarks → Collections → Scenery, leave through global navigation, and return. Compare the number of actions in A and B.
2. Open Following/Pinned searches → Sketchbook discoveries. Check the owner, use Back, then navigate World building → Atmospheres. Switch to Feeds and back to see separate nested histories.
3. Open a saved post, toggle Bookmark, inspect Details and close it, then close the viewer. The underlying bookmark mutation should wait until the viewer closes.
4. In C, open Spaces, switch among the seeded contexts, keep one as a new space, change profile and return to the original space.
5. Create a pin in the nested folder tree, move selected bookmarks to a real group, edit a feed's independent source queries, and pause/resume a simulated download.

Shortcuts: `/` opens search; Escape closes a transient surface or exits selection; left/right changes viewer posts. A/B use 1–4 for main destinations. C uses 1–6 for open spaces and Ctrl/Cmd+K for Jump. Shortcuts do not intercept text entry.

## Scope and limitations

This is a navigation reference, **not Flutter implementation code**. The review workbench is not an app-screen redesign. The inner app uses Kurumi-inspired hierarchy and conventions, not the actual Flutter widgets.

All content and operations use synthetic memory-only fixtures. There are no network requests, persisted credentials or real file operations. Reset restores the current concept; a page reload resets all concepts. SVG illustrations are generated locally. Times, counts, media badges and progress are illustrative.

The working interactions cover destination/profile state, folder traversal, search, filters, selected items, group/pin creation and movement, pin ownership, feed editing, viewer state, modal/dirty-form handling, spaces and simulated downloads/preferences. Detailed native media playback, real pagination, account APIs, full engine pages, .bsexport generation, native file pickers, share sheets and backup transactions are explicitly bounded. The post Move demo replaces membership with one group; it is not the complete production multi-group editor. Pin-folder creation and navigation are demonstrated, not a replacement for all production folder CRUD.

There is no claim of native gesture compatibility, process-death restoration, screen-reader conformance or production performance. The simulated keyboard is a height stress test, not an input method.

## Files

`model.js` contains synthetic data and navigation/state logic. `app.js` holds shared helpers and session context; `views.js` renders screens, `dialogs.js` renders transient surfaces, and `actions.js` binds interactions. These classic scripts share lexical scope and load in the explicit deferred order in the entry point. `styles.css` contains the responsive app and review workbench. `index.html` is the entry point. `tests/` contains isolated model and browser acceptance checks.

## Checks

Node 18+:

```sh
node --check docs/designs/mockups/navigation/model.js
for file in docs/designs/mockups/navigation/*.js; do node --check "$file"; done
node --test docs/designs/mockups/navigation/tests/model.test.cjs
```

Python Playwright and an installed Chromium:

```sh
python3 docs/designs/mockups/navigation/tests/browser_smoke.py --browser /usr/bin/chromium
# Optional screenshots (choose a scratch directory, not the source tree):
python3 docs/designs/mockups/navigation/tests/browser_smoke.py --screenshots /tmp/navigation-review
```

The browser test deliberately inlines the exact local files with `set_content`, avoiding external navigation and network access. It checks 13 browser journeys and 24 concept/size/text combinations; it does not test local-server configuration or Flutter.

The recorded isolated run passed 16 model tests and the browser suite with no JavaScript page errors or network requests. The project's mandatory full application/package/CLI/tooling verification **could not run**: a full checkout and pinned FVM/Flutter SDK were unavailable in the execution environment. See the design document for the remaining acceptance work. Do not treat these HTML tests as a substitute.
