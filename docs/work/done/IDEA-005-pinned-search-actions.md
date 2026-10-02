# IDEA-005: Consolidate pinned-search actions and folder cards

Priority: Normal
Affected feature: Pinned Searches / `feature/pinned-search-action-menu`

Agent: `/root/implement_05`
Work branch: `feature/pinned-search-action-menu`

## Problem

Pinned Searches gives infrequent maintenance actions dedicated app-bar space
and sends folder management to a separate page. Folder rows also lack the card
layout and cached visual previews used by individual pinned searches.

## Expected behavior

- Keep Sort as a dedicated app-bar action on both Home and folder views.
- Put Add searches, Create folder, and Refresh All in the Home overflow menu.
  Keep automatic-refresh settings hidden while scheduled refresh is disabled.
- Put Add searches and Refresh Folder in the folder-view overflow menu.
- Render folders as cards with their name, aggregate NEW state, item count,
  cached preview strip, and per-folder overflow actions for Refresh, Rename,
  Move up, Move down, and Delete.
- Build the preview strip deterministically from the first cached preview of
  each of the first four folder members that have previews, preserving folder
  order and each member's profile authentication.
- Remove the dedicated Manage folders entry and page. Keep current persistence,
  single-level organization, confirmation, and failure behavior unchanged.
- Never issue post requests to populate folder previews.

## Acceptance criteria

- [x] Home and folder app bars expose exactly the agreed dedicated and overflow
      actions, including disabled refresh/add states where applicable.
- [x] Folder cards expose the agreed visible content and actions.
- [x] Folder previews are cached-only, deterministic, owner-aware, and capped
      at four.
- [x] Folder create, rename, reorder, refresh, and confirmed delete behavior
      remains functional without a management page.
- [x] Empty folders, narrow layouts, enlarged text, loading, and error states
      remain usable and accessible.
- [x] Focused tests, the full suite, analyzer comparison, and Android UI
      validation complete successfully.

## Constraints and dependencies

This is a presentation and action-placement change only. Do not alter the
organization schema, add nesting, or introduce preview network requests. Follow
`docs/pinned_searches.md`, `AGENTS.md`, and `docs/development_workflow.md`.

## Progress

- 2026-10-02: Claimed in the isolated item-05 worktree. Existing Home/folder
  page, card, folder-management, organization, and widget-test patterns
  inspected. Preparing observable RED coverage while the shared Flutter
  toolchain slot is reserved by another item.
- 2026-10-02: RED confirmed 11 focused failures against the old dedicated
  toolbar, manager-page navigation, ListTile folders, and missing folder
  previews/actions. Implemented overflow action placement and cached folder
  cards without changing repository or notifier behavior. The focused suite
  now passes 55 tests, including cached-only owner-aware previews and narrow
  enlarged-text coverage.
- 2026-10-02: Analyzer remains at the known base of 227 info-only findings;
  no item-05 finding was introduced. Full-suite and Android verification are
  reserved for the coordinated final gate.
- 2026-10-02: Independent review found inconsistent folder-refresh
  availability between the root card and opened folder. Both surfaces now use
  one rule: refresh requires an existing non-empty folder with at least one
  refreshable member and no active member refresh. Observable empty, active,
  and missing-folder coverage brings the focused suite to 58 passing tests;
  analyzer remains at the 227-info baseline.
- 2026-10-02: Re-review confirmed the production rule and requested explicit
  evidence for unsupported-only folders. Added one widget scenario proving
  Refresh is disabled and dispatches no request from both the root folder card
  and opened-folder page. The focused suite now passes 59 tests; analyzer
  remains at the 227-info baseline.
- 2026-10-02: Final gate passed 59 focused and 1,492 full-suite tests. Analyzer
  remained at the established 227 informational findings and the branch diff
  check passed. A fresh dev x64 APK was built, hashed, installed on the assigned
  emulator-5564, and exercised with Maestro at normal size and a temporary
  320dp-equivalent viewport with 2x text. Temporary local folder state and all
  device display changes were restored afterward.
- 2026-10-02: Reopened for a requested card-density and folder-identification
  extension. The bounded design reuses the individual card's localized Last
  post states, derives the newest timestamp from cached member previews only,
  adds an inline folder icon, and halves internal card spacing while retaining
  existing outer gutters and 48dp actions. Observable RED coverage is in
  preparation before production changes.
- 2026-10-02: Refined shared card spacing to 8dp side/bottom, 4dp top, and a
  3dp preview-top gap while retaining thumbnail spacing and 48dp menu targets.
  Manual sorting now keeps Move up/down visible with boundary directions
  disabled; every non-manual sort omits both actions from folder and search
  cards on Home and inside folders. Four expected RED assertions became green;
  all 68 focused tests and all 1,501 tests pass. Changed-file analysis is clean.
  The first parallel full-suite run had one unrelated bulk-download timing
  failure; that exact test passed alone and the serial full suite passed.

## Completion evidence

- Final approved review: `/tmp/boorusama-ready-05-rereview2.md`.
- `fvm flutter test --no-pub` passed all 1,492 tests; the four item-focused
  files passed all 59 tests.
- `fvm flutter analyze --no-pub` reported exactly the known 227 info-only
  findings, with no item-05 diagnostic.
- `git diff --check 46558a4d0..460a4916e` passed.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64
  --no-pub` built `app-dev-debug.apk` from `460a4916e`; SHA-256 was
  `cedf2edfd81e235a9aab7d1211031d68b6128f35dfd17a9196a496554d358d32`.
  The APK and installed emulator-5564 package both reported
  `com.timberpile.boorusama.dev`, version code 186, and version name
  `4.5.0-timberpile.2-dev`.
- Maestro on emulator-5564 confirmed dedicated Sort and the agreed root/folder
  overflow actions, no Manage folders entry, folder NEW/count/cached preview
  and actions, disabled empty-folder refresh, and usable narrow/2x layouts.
  Automated widget coverage additionally verifies disabled active and
  unsupported-only folder refresh on both surfaces without dispatch.
- Item 08 supersedes this branch's temporary Refresh settings entry during
  integration; the combined result must keep automatic-refresh settings
  hidden.
- Final integration preserved the hidden automatic-refresh settings, and the
  four affected widget-test files passed all 73 tests. Targeted analysis of
  the integrated production and test files reported no issues.
