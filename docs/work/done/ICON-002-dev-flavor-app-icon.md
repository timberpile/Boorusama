# ICON-002: Give dev builds a distinct app icon

- Priority: Normal
- Affected feature: App branding
- Work branch: `feature/app-icon-generation-parity`
- Agent/session: Codex, 2026-09-22
- Depends on: [ICON-003](../done/ICON-003-app-icon-generation-parity.md)

## Problem

Production and development installs share the unbranded box icon, making them
hard to distinguish.

## Expected behavior

Every build uses the box-and-T logo, with the T printed in perspective on the
left face. Dev builds additionally show the established `Dev` lettering on the
right face; production and default builds do not.

## Acceptance criteria

- `assets/images/logo.svg` is the editable production artwork source.
- `assets/images/logo.png` is its manually exported 512-by-512 PNG input.
- `assets/images/logo-dev.svg` is the editable development artwork source, and
  `assets/images/logo-dev.png` is its manually exported PNG input.
- Production outputs contain the T and preserve the established platform
  framing from ICON-003.
- Dev outputs add the Dev mark without changing the production icon.
- Android, iOS, macOS, Windows, and web development build paths select Dev
  assets; default and production build paths select production assets.
- `flutter_launcher_icons` remains the downstream platform generator wherever
  it supports the target and flavor.
- Generation and flavor selection have focused behavioral coverage.

## Progress

- 2026-09-22: ICON-003 parity checkpoint reviewed and committed.
- 2026-09-22: Added the editable SVG and its manual 512-by-512 PNG export with
  the perspective-aligned T on the left face, then regenerated production
  platform icons through the two-stage pipeline.
- 2026-09-22: Added the Dev SVG and manual PNG export, generated flavor-specific
  Android and iOS assets with `flutter_launcher_icons`, and added flavor output
  and selection for macOS, Windows, and web.
- 2026-09-22: Verified deterministic regeneration, focused icon behavior and
  flavor-selection tests, the full Flutter test suite, static analysis, and
  successful Android debug builds for both `dev` and `prod`. Awaiting user
  review before committing this checkpoint.
- 2026-09-22: The Dev web build reaches the normal application compilation
  path but remains blocked by the existing `flutter_libavif`/`dart:ffi` web
  incompatibility; the icon template variable and generated web outputs are
  covered independently.
- 2026-09-22: User reviewed the generated production and development icons and
  confirmed that they work correctly.
