# Combined UI test branch — 2026-11-03

## Current user review follow-up

The user accepted the other implemented UI changes. Remaining focused checks:

- [ ] Related Bookmark add/remove stays responsive with a large existing group.
- [ ] All/Newest uses the latest current membership; All/Oldest the earliest.
      Remove/Undo/re-add updates that interpretation correctly.
- [ ] A new v9 backup contains group dates without global bookmark dates and
      restores the same memberships/order. Older v4–v8 files remain importable.

Includes #152 follow-ups `4f489ddbe` (immutable snapshots / repeated date decoding)
and `0c957c6a5` (confirmed All semantics / v9 output). Earlier global-All/v8 output
claims are superseded. The broad checklist below is retained as optional regression
reference, not a request to repeat already accepted actions.

Local branch: `maintenance/ui-combined-test-20261103`.
Worktree: `.worktrees/ui-combined-test-20261103`.
Base: local develop `02b0d60e99b2033c347f51549bcce1763a451f89`.

This is an explicitly requested local test combination. Source task branches,
primary checkout and develop are preserved. No push, PR, publication, issue
closure or develop integration. Merge commits retain the original branch history.

## Included snapshots

| Issue | Source branch | Included tip |
| --- | --- | --- |
| #139 | `feature/139-related-families` | `b8b233bf19c9` |
| #145 | `feature/145-bookmark-picker-presentation` | `666aa0a1e93d` |
| #149 | `bug/149-pool-gallery-header` | `3abf567f51e2` |
| #150 | `feature/150-context-menu-leading-icons` | `78414e11afc6` |
| #151 | `feature/151-default-grid-padding` | `b03edc285d19` |
| #152 | `feature/152-bookmark-group-added-dates` | `a31080d18` |
| #136 | `feature/136-kurumi-ui-design-system` | `962b4bdadcca` |

#139 is included through its dependent #145. #136 adds documentation/evidence
and its audit tool, not an application-wide redesign. The only textual conflict
was AGENTS.md: retained both the styleguide pointer and binding Kurumi surface
rule. Runtime changes merged automatically. Verified the automatically combined
Settings fields and Pool-gallery test fixture retain both branches' changes.

Not included: unrelated #112 viewer-toolbar work; future #105 radius migration;
#146/#147/#148 runtime changes. The Bookmark TimelineToolbar reuse assessment is
recorded on #148, not implemented here. Existing translucent global Header/system
bar behavior is therefore not acceptance evidence for those deferred issues.

## Start testing

Run from this worktree, without switching the primary checkout:

```bash
cd /home/timber/code/Boorusama/.worktrees/ui-combined-test-20261103
fvm flutter run --flavor dev
```

The worktree uses pinned Flutter 3.47.2. Dependencies and missing generated booru/
i18n output are prepared locally. Select the intended device if Flutter prompts.
No combined APK installation or device-data reset is part of this handoff.
Use small temporary groups and public safe Posts/references. Backup replace and
legacy-upgrade cases belong in a disposable test data set; retain the original
export if testing them with existing data.

## Manual acceptance checklist

### Bookmark search, surfaces and thumbnail overlays (#139)

- [ ] Browse and Bookmark searches have the same distinct rounded Kurumi field.
- [ ] Bookmark Search and the Timeline Toolbar share one opaque semantic parent;
      scrolling content does not show through. Other toolbar controls remain clear.
- [ ] The removed Bookmark Search help/info action is absent; search and suggestions
      still work, including with the actual keyboard open.
- [ ] Inspect Light, Dark, Midnight and dynamic-color themes. Adjacent surfaces,
      search suggestions and popup colors remain consistent/readable.
- [ ] Saved Related thumbnails have no title or empty title spacing; type/count
      remain available to accessibility. Series/Collection titles still work.
- [ ] Profile icons and type/count badges align: final 24 dp footprints, 16 dp type
      icons, common 4 dp insets/gap. Check favicon, custom icon and fallback, count
      clipping, narrow tiles and enlarged text. Post overlays retain their style.

### Related gallery and viewer (#139)

- [ ] Open a parent/child family as a vertical Related gallery inside the horizontal
      viewer; tapping a member opens the normal Post viewer.
- [ ] A gallery without a saved preference starts Oldest. Select Newest, leave and
      reopen a new occurrence: the saved choice is remembered after app restart.
- [ ] Change order while scrolled or with selected items: selection clears, scroll
      resets and page one reloads in the chosen direction.
- [ ] Scroll a sufficiently large family through additional pages. No duplicated,
      missing or mixed-order items appear. Switch order during loading if possible.
- [ ] Back from a member restores its gallery viewport/order. Returning to an older
      viewer occurrence preserves that occurrence while new ones use the preference.
- [ ] Bookmark Related opens immediately. Save, remove and Undo: the canonical
      family bookmark icon and selected groups update each time.
- [ ] Open the same family from another member: it resolves to the same saved
      reference. A separately saved Post stays independent. Other source profiles
      do not acquire the first source's membership.
- [ ] Reopen saved Related references, including a one-member or unavailable family
      when available; no silent retargeting to another family.

### Shared Bookmark picker (#145)

- [ ] Open the picker from each path: Post Viewer, single-Post selection, Pool,
      Series, Collection, Related gallery and stored-reference card context action.
- [ ] Stable buttons use the same Kurumi anchor; disappearing context actions and
      helper workflows use a Kurumi dialog. No Material-style picker appears.
- [ ] Folder navigation, parent/Back, current membership and pinned Recent groups
      work consistently; a repeated tap does not create duplicate writes.
- [ ] Add/remove membership and Undo for a Post and each stored reference type.
      Existing groups update without changing unrelated memberships.
- [ ] Create a group from both anchor and dialog with keyboard visible. Save adds
      to the correct source/group. Cancel and Back create nothing. Renaming and
      browser group/folder creation reuse the same name editor.
- [ ] Close the popup outside, with Back/Escape or while metadata is pending, then
      reopen. A dismissed workflow must not later save or reopen itself.
- [ ] On a slow connection, Pool/Related pickers open before metadata completes;
      normal group browsing works. Creating/saving resolves metadata only as needed.
- [ ] Where practical, switch the profile while preparation is pending: no write to
      a different or removed source. Do not remove a real account for this check.
- [ ] Multi-select Posts and references: Add To/Remove From keep batch semantics,
      membership counts and applicable groups; cancel leaves selection/data intact.
- [ ] Favorites Sync destination picker returns None/current/chosen group correctly;
      nested creation and cancel work. Choosing a destination alone must not toggle
      item bookmarks or start a sync.
- [ ] Pointer-triggered popups stay on screen near edges. Outside click, Back/Escape,
      keyboard traversal and return of focus to the trigger behave consistently.

### Pool Gallery Header (#149)

- [ ] Pool Gallery title uses the normal Kurumi inset rather than starting at the edge.
- [ ] Narrow width/long translated title/large text fit without clipping actions;
      the existing adaptive title fitting remains usable.
- [ ] Tabs, scrolling and navigation continue to work.

### Context-menu icons (#150)

- [ ] Long-press a selected Tag: Copy/Search/Follow/Favorite/Blacklist icons lead labels.
- [ ] Comparable Post, selection and Favorite/Unfavorite action icons also lead.
- [ ] Actual counts, checkmarks and submenu indicators remain trailing. Follow's
      icon leads while its count remains trailing.
- [ ] Check RTL order, disabled/destructive/focused colors, keyboard operation and
      touch on the icon/row. Copy/action and Back/outside dismissal still work.

### Grid defaults (#151)

- [ ] A new/unconfigured listing uses Padding4 and Spacing4. Existing explicit
      values, including 0 or 16, are retained after updating/restarting.
- [ ] Change padding and spacing separately; neither forces the other to match.
- [ ] Profile overrides and Settings export/restore preserve explicit values.
- [ ] Inspect Browse, Bookmark and Pool/Related grids in portrait/landscape:
      thumbnail edges, selection, keyboard-open search and pagination stay usable.

### Per-group membership dates (#152)

- [ ] Save P1 then P2 into group A. Add P2 then P1 into B. Newest shows P2 first in A
      and P1 first in B/All. All/Oldest uses the earliest current membership.
- [ ] Repeat adding an existing membership and refresh metadata: its position/date
      remains stable, as do its other groups and global All order.
- [ ] Remove B's older member and Undo: its original position returns. Remove it
      again and re-add: it becomes newest in B without changing its other dates.
- [ ] Duplicate a group: membership ordering is retained. Restart: order persists.
- [ ] Repeat with mixed Post/Pool/Series/Collection/Related references, checking both
      sort directions, previews and independent global/group order.
- [ ] Open pre-change data: original saved creation dates provide fallback ordering;
      old members must not all look newly added at upgrade time.
- [ ] Export/restore version 9: memberships, references, source identity and dates
      survive. Import an older version 4–8 backup into disposable data.
- [ ] In disposable data, test merge/copy/update/target merge: merge preserves local
      existing dates; copies retain imported dates. Unrelated memberships remain.

### Accessibility and constrained layouts (all changed flows)

- [ ] Narrow phone and landscape, largest practical text, actual soft keyboard:
      no clipped actions, hidden Save/Cancel or unusable scrolling.
- [ ] RTL and screen reader: meaningful type/count/group labels, correct directional
      layout, logical focus order and no duplicate icon actions.
- [ ] After testing, remove only temporary QA data and restore your selected
      profile, theme, font size, sort choices and grid values.

## Automated checks versus manual acceptance

The combined candidate is independently checked; the original per-branch results
are historical evidence only. Verification results are recorded below after the
complete combined run. This checklist is for the user's device review, not a claim
that every box was exercised on this combination.

Controlled tests cover scenarios that normal manual operation cannot reliably
force: failed local preference saves retaining content/order, stale async results,
dismissal during closing animation, repeated writes, cancelled creation ownership,
source removal, exact timestamp precision, malformed backup dates and rollback.
No forced failure instrumentation is added to the production UI.

## Historical combined verification result (before review follow-up)

Checked candidate: `bef656bb1` (all source merges and this checklist). The next
commit only appends this verification record. No runtime/test/dependency change
followed the complete pass.

- Pinned FVM Flutter 3.47.2 installed; CLI/root dependencies resolved and missing
  booru/i18n outputs generated. No tracked generated-source drift remained.
- All 86 changed Dart files: `fvm dart format --output=none --set-exit-if-changed`
  passed with 0 changes.
- `fvm flutter analyze --no-pub --no-fatal-infos` over Bookmark, backup, Hive,
  combined Settings and affected Danbooru gallery files: exit 0, **0 errors,
  0 warnings, 122 infos**.
- `./scripts/run_regression_tests.sh`, detected physical concurrency 6:
  **6,135 application tests; 1,661 package/CLI tests across 13 complete suites;
  both shell suites; 76 Python tests; REGRESSION_EXIT=0**.
  Kurumi's complete combined suite passed 188 tests. Two pre-existing go_router
  skips remain; none added. No interrupted or failed phase is counted as a pass.
- Existing Dart VM finalizer, locale fallback, native-hook and test hit-target
  diagnostics appeared; the explicit complete-suite result above establishes
  success. This is host-test evidence, not measured device latency.
- All seven recorded source tips are ancestors of the combined branch. The
  original task refs/worktrees, primary detached checkout and local develop were
  preserved. Final diff/conflict-marker/clean-worktree checks passed.

No new combined APK was built/installed and no combined-device acceptance was
performed in this task. Earlier individual-branch device checks remain historical
baseline evidence. The 47 boxes above are manual acceptance still to perform,
including narrow/large-text/keyboard/RTL, live metadata and backup-upgrade UI.
A different develop integration candidate would need its own complete verification
and separate integration authorization. This branch remains a local test snapshot.

Durable logs: `.worktrees/_artifacts/ui-combined-test-20261103/` (`setup.log`,
`verification.log`; exact commands in `setup.sh` and `verify.sh`).

## Final feedback follow-up verification

Checked runtime/test candidate: `e1e04d8c0e7100136b82b682ea159a4edb5f0b0d`.
Source #152 is now `a31080d18` (implementation through `c4e395c07`, then docs only).
The subsequent handoff merges/record change no checked runtime or tests.

- FVM format: 94 changed Dart paths, 0 changes.
- Combined affected-scope analysis: 0 errors, 0 warnings, 122 infos, exit 0.
- Complete final `./scripts/run_regression_tests.sh`, physical concurrency 6:
  **6,161 application + 1,661 package/CLI across 13 suites  + both shell suites
   + 76 Python tests; REGRESSION_EXIT=0**. Kurumi 188 passed; two existing go_router
  skips, none added.
- The three stale mixed-viewer fixtures now seed explicit membership chronology;
  their navigation/selection assertions are retained. Their earlier failed run
  and the interrupted pre-Default-boundary run are not passes.
- Actual UI responsiveness on the user's device remains to recheck. The host's
  synthetic 20,000-member warm-read segment improved from 173–239 ms to 0.05–0.24 ms;
  these figures are not Android frame or end-to-end action measurements.
- New v9 backups omit global bookmark dates and retain legacy 4–8 import. All uses
  latest/earliest current memberships. First Default memberships use save time,
  not the metadata draft's prepared date. The original other UI changes remain
  accepted; only the three focused review items at the top remain manual.

Full source details: [membership-derived All / v9](152-all-membership-order-20261103.md)
and [responsiveness](152-related-bookmark-responsiveness-20261103.md).
Durable logs: `.worktrees/_artifacts/related-bookmark-responsiveness/`.
No combined APK/device action, reset, push, PR or develop integration in this
follow-up. This local test branch is clean and committed; source task branches
are retained. Local develop remains `02b0d60e9`. The primary checkout was observed
at detached `8a4aefafc` during the final check (it moved outside these task
operations from the initial `cb995548b`). It is clean and was left untouched.
Run from this worktree to test the updated branch rather than that older snapshot.
