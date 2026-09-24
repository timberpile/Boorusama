# POST-002: Repair Danbooru details provider scope

Priority: High

Affected feature or branch: `feature/bookmark-post-behavior-parity`

Agent/session: Codex `/root`, 2026-09-23

Work branch: `feature/bookmark-post-behavior-parity`

Dependencies: POST-001 unified post model and mixed-booru presentation

## Problem

Opening the full details page for Danbooru post `12247758` leaves the page
blank. Returning twice then emits cascading Flutter rendering and widget-tree
assertions.

The first failure is Riverpod rejecting the Danbooru creator and uploader-query
providers inside the mixed viewer's page-scoped profile because their scoped
dependencies are not declared.

## Expected behavior

- Danbooru details that include an uploader resolve under the active page's
  profile scope.
- The full details page renders normally.
- Leaving details and the viewer does not emit framework assertions.

## Acceptance criteria

- A regression test fails on the missing provider dependencies before the fix.
- Creator and uploader-query providers declare their scoped dependency chain.
- The focused regression test and full Flutter suite pass.
- The exact `id:12247758` flow succeeds on `emulator-5556`, including opening
  details and navigating back twice without new exceptions.
- A separate Sol High agent reviews the completed feature branch.

## Reproduction evidence

- Tested commit: `e01c7a57dba2462a90d2ed194c0074ce30edad76`.
- Device: `emulator-5556`.
- First error: `danbooruCreatorProvider(101372)` is read below an overridden
  profile dependency without itself being scoped.
- `danbooruUploaderQueryProvider(post)` then reports the same dependency error.
- Sliver, layout, semantics, and back-navigation assertions follow after the
  failed details subtree build.

## Progress

- Added the missing Riverpod dependency chain from the page-scoped read-only
  profile through the Danbooru creator and uploader-query providers.
- Added a widget regression test covering a Danbooru post with an uploader ID
  below `CurrentBooruConfigScope`.
- Verified all seven mixed-details tests and the full 1,373-test Flutter suite.
- `fvm flutter analyze` completes with the branch's existing 234 info-level
  diagnostics and no warnings or errors.
- Repeated the exact `id:12247758` flow on `emulator-5556`: details rendered
  title, statistics, tags, file details, uploader, and related posts; both back
  operations completed without new Flutter exceptions.
- Independent Sol High review confirmed the provider fix and reported five
  broader feature-branch findings, tracked separately as POST-003 through
  POST-007.
