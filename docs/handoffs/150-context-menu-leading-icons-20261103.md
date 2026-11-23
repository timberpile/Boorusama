# Issue #150: Leading context-menu action icons

Branch: `feature/150-context-menu-leading-icons`, based on `02b0d60e9`.
Implementation: `f112aca05f43d0d43158f77e842adc68b8d61750`.

Added an optional leading slot to `KurumiContextMenuTile`. It inherits existing
icon sizing, mirrors directional spacing in RTL, follows disabled/destructive/
focus colors, and remains part of the row's single accessible action. Touch,
keyboard, focus, dismissal and trailing content keep the existing control path.

Moved action icons in General Tag, common Post, selection, favorite/unfavorite
and Danbooru Post action rows to the leading side. Follow's RSS action leads;
its count remains a trailing Badge. Bookmark submenu arrows, selection/state
indicators and unrelated trailing widgets were not converted. No radius change.

Verification:

- FVM formatting and `git diff --check` passed.
- Scoped analysis: 0 errors, 0 warnings, 1 existing unnecessary-import info.
- Complete Kurumi package: **186 passed** on the final component, including four
  new narrow/2x/RTL/count-position/pointer-dismissal cases. Existing keyboard,
  focus and Back behavior tests remain included.
- Final application consumers: **8 passed** (profile context menus, unified Post
  actions and Favorite Tags).
- Android dev x64 build passed. One earlier build process ended with SIGTERM;
  the durable final build completed with `BUILD_EXIT=0`.
- Installed/local APK SHA-256 matched
  `b682d2981c8240e3acd51bc0e0a579d1e7a0ad603b66849777ccc75e4f932e5d`.
  Maestro used exclusively leased Android 17 at 360×800 logical, gesture mode.
  Inspected the actual Tag menu at 1x/2x text; all five actions fit/wrapped, Copy
  dismissed the menu, and Back dismissed the enlarged menu. Font restored to 1.0.
  No Favorite/Blacklist/account mutation was performed; the QA clipboard is cat.

Logs/captures: `.worktrees/_artifacts/approved-ui-150/`. Device RTL, desktop
pointer, assistive technology and a nonzero Follow count remain manual; controlled
widget tests cover RTL and trailing counts. Full application regression was not
required for this scoped package/API addition; integration needs the final
combined candidate's complete gate. Preserve #145's stricter AGENTS rule when
integrating the independent branches. No push, PR, merge or issue closure.
