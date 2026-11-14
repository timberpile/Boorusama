# #141 — Pixiv Bookmark corrections: local final acceptance

Updated 2026-11-14. Issue #141 remains open/in-progress. This handoff is not
integration approval.

## Start here

Continue `feature/141-pixiv-work-page-bookmarks`, preserving later branch work.
Observed review HEAD: `52ce918c4222458eb6bc3bcc0c5107eb8db4be4b` (2026-11-14 UTC).
The most recent verified source-level runtime change is `64da57f27aac84312d1053dd134ea8acbbab75d8`; later commits add a **still-present temporary diagnostic CI workflow** and other verification/docs work, not accepted app behavior. Recheck the branch head and exact runtime diff before local work. Read the
[root-cause and UX comparison](../designs/2026-11-13-pixiv-bookmark-regressions.md).

**Status: corrective candidate, not locally accepted.** Hosted verification is
separate from Android/live Pixiv acceptance. The final result for the current
candidate must be read from the verification record below; historical counts
must not be carried forward.

## Changes already committed

`MediaGroupActions` now preserves Work toolbar scope while navigation is
inactive. Previously, opening the chooser covered the route, removed that scope
and disposed the button awaiting the result. Inactive neighbors also fell back
to the ordinary Page bookmark action. Independent Page/Work identities and their
previously different selected-color handling explain the reported mismatch in
source. No storage corruption or migration defect was established.

The button retains Work/access ownership, captures the actual Page when opening
the chooser, and rejects stale outer Work, revoked authorization or unmounted
continuations. A confirmed one-Page Work exposes only direct Work bookmarking;
unknown count is not treated as one. Work/Page rows share a glyph but show
independent persisted membership state/count. Main-button fill remains Work-only.
Duplicate Work/Page overflow entries are removed; unrelated actions remain.

`KurumiActionIconButton` and `KurumiDropdownIcon` are shared by Bookmark and
Download. Commit `937ab4b3bc7b3edec2a7dc783bf4520f982e1e48` attempted a Material 2
layout correction by reserving the main 20/24 dp glyph **plus** 16 dp chevron
in a `Row`. **This implementation conflicts with the owner's subsequently
approved UI contract and is not an accepted final fix:** the chevron must be
centered vertically at the **right** as an overlay/composite within the
**unchanged button footprint**, with no increase in requested width. The normal
button's ripple/interaction center stays optically between the two glyphs,
matching Download behavior, and the chevron remains visible while the menu is
open. Download and Bookmark must use one reusable Kurumi control; normal tap
still executes the primary action and hold opens alternatives. Confirm a genuine
48x48 dp usable hit target without 8 px right overflow at 20/24 dp, compact
layouts, Material 2/3 and RTL. Do not solve it by clipping or shrinking the
chevron away.

The approved labels are applied in `e7354dfc77e24e4ba25a55c34098abd439003bb8`:
Entire Work / Current Page; Gesamtes Werk / Aktuelle Seite. The old patch is
removed. Generate translations normally; do not look for or reapply that patch.

`64da57...` adds the missing Riverpod extension import required by the action
tests, an explicit mounted guard after the asynchronous route transition, and
focused test lint/format corrections. No persistence codec, membership, identity,
migration or Undo semantics were rewritten. Historical Page-only bookmarks do
not imply Work membership, even for a one-Page Work. Pixiv Favorites are separate.

## Actual verification record

- [Locale validation 43569381180](https://github.com/timberpile/Boorusama/actions/runs/43569381180)
  succeeded: exactly four approved values, valid JSON and unchanged unrelated
  bytes in en-US/de-DE.
- [Isolated run 43572108909](https://github.com/timberpile/Boorusama/actions/runs/43572108909)
  on `53ad491...` failed compilation because `requireValue`'s extension was not
  imported. It also exposed async-context and test lint findings. These are the
  demonstrated defects addressed by `64da57...`.
- [Completed run 43572469576](https://github.com/timberpile/Boorusama/actions/runs/43572469576),
  job `132379609968`, tested bot commit `64da57f27aac84312d1053dd134ea8acbbab75d8`
  and **FAILED**. Its detailed log reports **73 passed / 14 failed** Pixiv Work
  test cases, each of the inspected failures being a **30-second
  `TimeoutException`** in `commitBookmarkInteraction()` while waiting for a
  `bookmarkProvider` revision after a destination-row tap. Analysis also
  reported remaining `unnecessary_async` infos. The workflow's
  `continue-on-error` step conclusion is **not** a pass; the final job failed.
  This run is not a conclusive production storage bug or a qualified final pass.
- Earlier broad-run summaries did not match the source-fingerprinted fixture;
  do not use them as current acceptance evidence. The fixture already places
  real Hive setup and mutation waits in `tester.runAsync`; an attempted edit
  stopped at its exact-source assertion and made no fixture change.
- No local build, device test, live Pixiv reproduction or independent review was
  performed by the remote session. Historical `8203d21...` counts do not qualify
  these changes. **`.github/workflows/141-bounded-diagnostic.yml` currently
  remains on this branch** (`52ce918...`) and should be evaluated/removed after
  the underlying failure is diagnosed. It instruments a temporary test fixture
  at CI runtime, not a production fix; keep any meaningful final regression test.

## Review findings to resolve BEFORE owner acceptance (2026-11-14)

1. **P0: timeout diagnosis with definitive evidence.** The current
   `work_bookmark_widget_fixture.dart` calls `tester.tap` from inside
   `tester.runAsync` and then waits for the production notifier's revision
   without pumping the test binding while the operation may still depend on
   Flutter's frame/microtask machinery. This is a **plausible test deadlock**, not
   a proven root cause. Keep production code unchanged until distinguished:
   instrument the row callback, picker `_toggle`, `BookmarkPickerActions`,
   notifier `toggleContentGroupTarget/togglePostTarget`, repository journal,
   publish/revision and guard checks. Prefer a harness that executes the user
   gesture in the normal widget-test zone, pumps frames while awaiting the
   asynchronous real-I/O mutation, and verifies **both** durable Hive contents
   and emitted revision. Exercise Work, Page, new Group and cancelled flows.
   Capture the earliest blocked await and exact exception (if any); do not
   merely lengthen timeouts or delete the failing tests.
2. **P1: approved visual control not implemented.** Replace width-expanding
   Kurumi `Row` with the agreed unchanged-footprint right-center chevron
   overlay. Ensure Download and Bookmark both retain their behavior and the
   correct ripple center; use production-toolbar geometry tests and device
   capture rather than only a standalone icon test. Add the four-state
   Work/body + current-Page-marker indicator to the main Bookmark button.
3. **P1: gate any final sign-off on fresh evidence.** Source-only lifecycle
   guard and menu removal are credible and implemented, but no valid passing
   candidate-wide bookmark test result or live Pixiv Android evidence exists.
   Re-run analysis, focused tests, complete repository regression and device
   scenarios on the **exact final runtime** after fixes. Compare the checked
   candidate to the carried #144 source before P9 integration.

## Local completion and acceptance

First resolve any current hosted failure and run the repository-required checks
on the final candidate. Include the Work action, commit guard, persistence,
target/library tests; Kurumi action geometry and existing button/menu suites;
Bookmark picker/mutations, mixed-content Viewer, Download and backup/import
regressions. Record exact commits, commands and outcomes. The action fixture uses
production route coverage, chooser, Group picker/notifier and unified Hive, but
controlled provider inputs are not real Viewer swipe evidence.

Exercise the following device cases without changing identity/persistence policy:

1. **Target/state matrix:** genuine one-Page, multi-Page, unknown count,
   summary-only and unavailable/restricted Pages; Work-only, Page-only, both and
   neither saved; zero, one and multiple memberships. Correct independent fills,
   glyphs, labels and counts; only confirmed one-Page Works lose the chooser.
2. **Real navigation:** saved A to unsaved B and saved A to saved B in both
   directions, rapid swipes/Back, before and after loading. Include imported and
   historical Page-only records. No Page fallback, transient false fill/color,
   disappearing arrow or menu-open ghost save.
3. **Real writes:** direct Work and both choices to a destination, exact durable
   record and original Page index, new Group with keyboard, cancellation at both
   stages, source/profile loss, outer Work change, removal/Undo and restart.
   No implicit second target or server Favorite mutation.
4. **Presentation:** narrow width, large text, RTL, light/dark/AMOLED,
   screen-reader actions, membership badges, ordinary non-Pixiv bookmarks and
   normal/small Download callers. Verify minimum hit targets do not overflow
   compact toolbars and quality/share actions remain correct.

## Product boundary and completion record

**The owner has already decided the final main-icon semantics; these are no
longer an open UI choice.** Keep the one Work-primary / long-press chooser
button (a confirmed single-Page Work has no chooser), and use a **Page-only
marker** with the existing Bookmark body:

| Saved state | Bookmark body | Page marker |
| --- | --- | --- |
| Neither | Outlined | Absent |
| Entire Work only | Filled | Absent |
| Current Page only | Outlined | Present |
| Both | Filled | Present |

Compute Work and current Page status separately from canonical saved identities,
not the open menu, pressed/ripple state, adjacent Work, remote Pixiv Favorite,
or previous Page. The Page marker should be a small legible Material page/file
glyph (no new SVG required initially), with a separate persistent right-center
chevron affordance. In chooser rows, **Entire Work** and **Current Page** both
use the standard Bookmark glyph, each independently filled by its own saved
membership. Accessible value/tooltip must convey both statuses; test Page
changes, legacy Page-only saves, work-menu open/close and single-Page Works.
Main icon's Page marker and overlay chevron are **not implemented** in reviewed
source `bookmark_actions.dart` / `action_icon_button.dart` at `52ce918...`.
Do not claim this design is accepted in code until implemented and verified.

**Page -> parent Work navigation is also requested** for saved Pixiv Page
Bookmarks. `PixivPostData.illustId` and `pageIndex` already preserve the genuine
source identity, enabling a same-site/profile `group/work:<illustId>` reference
without manufacturing or requiring a saved parent Work. There is no verified
UI parent-link implementation in the reviewed candidate. Implement or explicitly
coordinate its acceptance scope with the owner; keep it distinct from generic
Danbooru Pool membership lookup, and fail safely if the source profile is gone.

Update this handoff and #141 with the final tested runtime, actual host/device
results, any additional fixes and remaining decisions. Final local acceptance
and explicit integration approval are still required.
