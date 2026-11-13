# #141 Pixiv Bookmark regression candidate — local completion and acceptance

## Branch and evidence

- Branch: `feature/141-pixiv-work-page-bookmarks`.
- Runtime candidate: `56669fa7c2e226473d730cf5a4e9556fc7983b06`.
- Previous branch head: `e9d1056d0b15105db48e5ff4d1e0cbab7b203323`.
- Issue: #141, open / in-progress. This handoff does not authorize integration.
- [Source diagnosis and UX comparison](../designs/2026-11-13-pixiv-bookmark-regressions.md).

**Status: partial corrective candidate, not an accepted or green build.** Remote
source edits and regression tests are committed. The approved locale edits are
provided as an unapplied patch below. No Dart formatting, analyzer, Flutter test,
Android, or live Pixiv result exists for this new candidate. The previous handoff's
7,147 app / 1,693 package / 76 Python pass belongs only to runtime
`8203d21ef2c681c0f2919785737781cfe68b947a`; owner feedback superseded its functional
acceptance. Do not carry those results forward as evidence for this commit.

## First complete the small outstanding source edit

Apply [`141-bookmark-labels.patch`](141-bookmark-labels.patch) to the two
translation resources and regenerate localizations through the repository's
normal generation path. It changes only:

| Resource key | en-US | de-DE |
| --- | --- | --- |
| `content_viewer.bookmark_work` | Entire Work | Gesamtes Werk |
| `content_viewer.bookmark_page` | Current Page | Aktuelle Seite |

Do not reserialize or replace unrelated translations. The patch's context and
offset application were checked with Git against synthetic locale fixtures;
that is not evidence of application to the real files. The new widget tests
intentionally expect the approved labels and cannot pass until the source
strings and generated translations are updated. Commit the actual resource
changes and remove the obsolete patch once applied; update the status wording
in the diagnosis document accordingly.

## Implemented changes

`MediaGroupActions.build` retains `PostActionToolbarScope` when navigation is
inactive. Previously, opening the choice dialog caused
`DestinationPageActivity.didPushNext` to make the route inactive and remove the
Work button; its awaited continuation then returned because it was unmounted.
The same early return exposed `SimplePostActionToolbar`'s ordinary Page bookmark
fallback for inactive neighbors. Page and Work use independent identities, and
the old Work button lacked the Page button's selected color, explaining the
reported identity/color discrepancy in source. No storage-index corruption or
migration defect was established.

The Work button is keyed by Work/access, retains its owner through a covering
dialog, freezes the actual Page at chooser entry, and rejects outer Work changes,
source revocation and unmount before destination handoff. A Page must belong to
that Work and actor. A confirmed one-Page Work has only direct Work bookmarking;
an unknown count retains alternatives. Choice rows use the same bookmark glyph
with independent persisted membership fill/color/count. The main button still
means Work only. It uses the app's bookmark selected-color role. Redundant
Work/Page overflow actions are removed; other toolbar actions remain.

`KurumiActionIconButton` / `KurumiDropdownIcon` provide the reusable trailing
chevron. Bookmark and Download use them. The chevron stays in layout bounds and
mirrors with directionality; the action target is at least 48 x 48 dp. Opening a
menu has no selected-state side effect. The visually small Download variant now
also has that target and supports its advertised alternate action: review its
actual callers carefully for layout regressions rather than assuming this is
pixel-neutral.

Persistence codecs, migrations, membership mutation, Undo and commit guards were
not changed. A historical Page-only bookmark deliberately does not imply a Work
bookmark, including on a single-Page Work. Remote Pixiv Favorites remain distinct.

## Checks to run and repair before acceptance

Use the repository's current verification workflow. At minimum inspect/format/
analyze the changed app and Kurumi files and run:

- `test/boorus/pixiv/works/work_bookmark_actions_test.dart` and the existing
  `work_bookmark_commit_guard_test.dart`, `work_bookmark_persistence_test.dart`,
  target/library tests in the same directory.
- `packages/kurumi/test/action_icon_button_test.dart` and relevant existing
  Kurumi button/menu tests.
- Bookmark picker/mutation, mixed-content Viewer, Pixiv presentation and Download
  regression suites, followed by the required complete candidate regression.

The new widget fixture uses the real `MediaGroupActions`, real route coverage,
real picker/notifier and unified Hive journal. It controls source/provider input
rather than making network requests. It waits for a notifier revision after the
write rather than a timing sleep. Verify that fixture setup and real-I/O waiting
work on the project's test runner; no execution result is claimed. This remains
a host widget test, not an actual full-Viewer swipe test. Existing durable commit
guard tests must continue rejecting dismissal/profile/source loss before commit.

## Device and owner acceptance matrix

1. **Targets and labels:** genuine one-Page, multi-Page, unknown count,
   summary-only, restricted/unavailable Page. Work-only, Page-only, both, neither;
   zero/one/multiple Group memberships. Both choices use the same glyph and
   independently correct state. Only confirmed one-Page Works lose the chooser.
2. **Real navigation:** saved A to unsaved B and saved A to saved B, both directions,
   rapid swipes/Back, before/after member loading. Include older Page bookmarks,
   imported entries and newly saved Works. No Page fallback, transient false
   fill/color, disappearing arrow, or menu-open ghost bookmark.
3. **Mutations:** direct Work, chooser Work, chooser Page -> destination -> exact
   durable record/original Page index. Create Group with keyboard, cancel at both
   stages, revoke profile/access, leave the Work, and repeat. No implicit second
   target or remote Favorite mutation. Confirm removal/Undo and restart.
4. **Presentation and regression:** 320 dp, large text, RTL, light/dark/AMOLED,
   screen-reader labels/actions, multiple membership badge, ordinary non-Pixiv
   bookmarks, local Work cards/filter/sort, backup/import. Verify Download normal
   and small variants, quality chooser, share, Favorites and source isolation.

## Still a product decision

The existing main control continues to show Work status only. The diagnosis doc
compares two explicit actions, a split surface, and a combined-state badge. Its
recommendation is two explicit Work/Page targets for maximum clarity; a split
surface is a possible visual grouping but still needs two full hit targets.
A speculative four-state badge was not implemented. Obtain the owner's choice
before a material toolbar redesign, independently of accepting these defects.

## Completion record

Record the final runtime SHA, actual commands/results, any fixes to the new
fixtures, device evidence and remaining owner decisions in this handoff and
#141. Keep historical and current evidence separate. Local acceptance and an
explicit integration decision are still required.
