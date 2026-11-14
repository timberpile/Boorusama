# #141 — Pixiv Bookmark corrections: local final acceptance

Updated 2026-11-14. Issue #141 remains open/in-progress. This handoff is not
integration approval.

## Start here

Continue `feature/141-pixiv-work-page-bookmarks`, preserving later branch work.
Runtime/test candidate: `64da57f27aac84312d1053dd134ea8acbbab75d8`.
The subsequent diagnosis and handoff commits change documentation or remove
temporary CI workflows, not application behavior. Read the
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
Download. Commit `937ab4b3bc7b3edec2a7dc783bf4520f982e1e48` corrects the Material 2
composite icon slot: reserve the main glyph plus 16 dp chevron, while retaining
an explicit 20/24 dp main glyph and at least 48 x 48 dp target. Tap and hold stay
separate; disabling also disables hold. Menu opening does not select the icon.

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
- [Current verification 43572469576](https://github.com/timberpile/Boorusama/actions/runs/43572469576),
  job `132379609968`, was triggered by `a5ccf30...` but explicitly commits and tests
  `64da57f27aac84312d1053dd134ea8acbbab75d8`. It runs analysis of the Pixiv Work
  sources/tests and the complete `test/boorus/pixiv/works` directory. At this
  handoff checkpoint the test step is still running; **no passing result is
  claimed**. Read the final outcome/log, not a continue-on-error step conclusion.
- Earlier broad-run summaries did not match the source-fingerprinted fixture;
  do not use them as current acceptance evidence. The fixture already places
  real Hive setup and mutation waits in `tester.runAsync`; an attempted edit
  stopped at its exact-source assertion and made no fixture change.
- No local build, device test, live Pixiv reproduction or independent review was
  performed by this remote session. Historical `8203d21...` counts do not qualify
  these changes. Temporary verification workflows are removed from the branch.

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

Simultaneous Work/Page toolbar status remains a product choice, not part of the
corrective redesign approval. The design note compares two explicit actions
(recommended for clarity), a split surface and a combined badge. Retain the
Work-primary/held-chooser behavior until the owner decides; do not introduce an
ambiguous four-state badge or silently change direct tap to Page.

Update this handoff and #141 with the final tested runtime, actual host/device
results, any additional fixes and remaining decisions. Final local acceptance
and explicit integration approval are still required.
