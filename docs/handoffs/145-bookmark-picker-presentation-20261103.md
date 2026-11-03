# Issue #145: Bookmark Picker presentation

Continuation: [final dependency update](145-bookmark-ui-corrections-20261103.md)
records the corrected #139 base, replayed commits and fresh verification. Commit
IDs and results below describe the earlier delivery, not the current candidate.

Local delivery on `feature/145-bookmark-picker-presentation`, based on #139 tip
`3e07f9b59d`. **Integrate #139 first.** Review this issue's delta against that base.
No push, PR, merge, issue closure or unrelated #136 changes are authorized.

## Architecture and behavior

`BookmarkPickerRequest` has typed Post, stored collection, remote Pool and Related
variants. Series/Collection categories remain part of existing Pool types.
`BookmarkGroupPicker` contains the shared navigation, memberships, Recent groups
and selection UI; it has no dialog/anchor branch. `BookmarkPickerActions` owns
source validation, deferred resolution and mutation guards independently of the
presenter. `BookmarkGroupPickerAnchor` supplies the normal Kurumi anchor;
`BookmarkGroupPickerDialog` supplies a Kurumi dialog through `showDialog`.

Opening never waits for metadata. A mounted picker keeps a shared draft alive;
a write resolves it only when necessary, reusing an existing canonical reference
when available. The owner checks exact source configuration and active workflow
before writing. Anchor `isShowing == false` revokes writes immediately, including
its reverse animation; dialogs check route ownership. Repeated toggles and group
creation during a pending toggle are rejected.

Create Group installs a separate name-dialog owner with the immutable request
before dismissing the original anchor/dialog. The new owner retains the draft,
checks cancellation and source changes, and blocks dismissal during its committed
write. No deferred operation reads a disposed widget reference. Group creation and
renaming share the Kurumi name editor; Recent stays pinned beneath navigation.
Equivalent remote metadata compares by value, so ordinary widget rebuilds do not
close an otherwise unchanged picker.

Bulk and Favorites Sync destination pickers reuse compact folder rows and Kurumi
dialogs while keeping their distinct add/remove counts and destination-return
semantics. The legacy bulk action sheet uses the existing Kurumi sheet. AGENTS.md
now binds dialogs, popups, anchors, sheets and context menus to Kurumi alternatives;
`showDialog` routing is explicitly allowed. Exceptions require documented technical
justification and established styling. This change does not authorize a general
application-wide dialog migration.

## Final entry-point inventory

| Entry point | Presentation and semantics |
| --- | --- |
| `BookmarkPostButton`, `BookmarkPostLikeButtonButton` | Shared anchor; actual Post memberships |
| Single-selection bookmark action in `default_multi_selection_actions.dart` | Same shared anchor and Post request |
| `PoolBookmarkButton` in Danbooru and Szurubooru | Same shared anchor; remote/stored Pool, Series and Collection references |
| `RelatedGallery` | Same shared anchor; canonical Related family request |
| `BookmarkPoolCard` Bookmark context action | Kurumi dialog for stored Pool/Series/Collection/Related references; disappearing menu trigger |
| `showBookmarkGroupPicker()`, `BookmarkPostX.toggleBookmark()` | Kurumi dialog for Post requests; no artificial anchor |
| `BookmarkContextMenuSection` | Existing Kurumi nested page; same picker content/actions and folder Back navigation |
| `showBookmarkMultiSelectionActions()` | Existing Kurumi sheet, then Kurumi batch destination picker; existing-bookmark add/remove semantics |
| `showBookmarkGroupSelectionDialog()` / `BookmarkMultiSelectionMenu` | Kurumi batch picker; applicable groups, ancestors and membership counts preserved |
| `showServerFavoriteTargetPicker()` | Kurumi destination picker; None/current selection/nested creation; no bookmark toggle |
| `showBookmarkGroupNameDialog()` / `BookmarkGroupNameDialog` | Shared Kurumi name editor for picker creation, browser group/folder creation and renaming |
| `BookmarkPickerGroupCreation` | Same name editor with independent deferred-operation ownership |

Repeated source search audited these callers plus every use of the shared picker,
folder content and name-dialog APIs. No raw Material `AlertDialog`, `Dialog`,
`SimpleDialog` or `PopupMenuButton`, nor `anchored: false` presentation path, remains
in those picker surfaces. Unrelated bookmark management confirmations, browser
menus and the outer Favorites Sync configuration dialog are outside this scope.

## Automated verification

Checked implementation commit: `760c2ab2032bc571657c72e7332231e9b7c9acf7`.
The subsequent handoff commit changes documentation only. Local `develop` and
`origin/develop` tracking references remain `02b0d60e99b2033c347f51549bcce1763a451f89`;
no integration or publication was performed.

| Check | Result |
| --- | --- |
| `fvm dart format` on all 24 changed/new Dart paths; final `--output=none --set-exit-if-changed` | Passed, no final formatting changes |
| `fvm flutter analyze --no-pub --no-fatal-infos` on those 24 paths | Exit 0; zero errors, zero warnings, 48 informational findings |
| Affected consumer run: Post button/folder/batch/name/Favorites Sync, selection parity and application Pool flows | 177 passed |
| Controlled picker lifecycle matrix | 35 passed: Series/Collection/Related creation and cancellation in anchors/dialogs, repeated actions, source changes, Post source handoff, stored references, RTL pointer bounds and focus restoration |
| Shared badge suite | 11 passed, including cached favicon/custom icons, fallback rendering and RTL geometry |
| `./scripts/run_regression_tests.sh` on the final candidate | Complete pass: 6,111 application tests; 1,655 package/CLI tests; both shell suites; 72 Python tests; durable `REGRESSION_EXIT=0` |
| Existing package skips | Two pre-existing go_router skips; no new skips |
| `git diff --check` and final picker surface/caller audit | Passed; no raw Material dialog or obsolete presentation flag in the audited picker surfaces |
| `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub` | Passed after completing fresh-worktree Flutter plugin setup |

The first Android resource-link attempt lacked `.flutter-plugins-dependencies`
after CLI-only dependency setup. Root `fvm flutter pub get` generated it, and the
unchanged-source rebuild passed. The final complete regression started after
that setup and build. Earlier regression starts were stopped during preparation;
they are not counted as passes. The native-hook modification warning and existing
Dart finalizer diagnostics appeared; completed results above establish verification.

Review removed the duplicate context-menu toggle implementation, tightened owner
initialization/disposal, retained exact Post source binding across creation, added
pending-action creation rejection and compared equivalent remote metadata by value.
All affected final checks were rerun through the complete suite.

## Android acceptance and remaining manual checks

Maestro controlled exclusively leased `emulator-5554`; the current-source debug
APK was installed without resetting app data. Installed/local SHA-256 both:
`96355fbf98e3bcd7b762a9a7491b9b9d023874fd823bb3a4edd41c57b8624e19`.

- Created `QA Picker 145` from the Post Viewer anchor through the shared Kurumi
  name editor with the keyboard open; the saved Post remained independent.
- Saved a two-member Related family, a Series and a Collection through the same
  anchored picker. The group contained the Post plus all three distinct references.
- Selected Series and Collection together, opened Add To, checked the membership
  counts, and visually inspected the Kurumi batch dialog at 2x Android text.
- Opened Create Group from that batch dialog at 2x text with the keyboard visible;
  Save and Cancel fit. Cancelled the editor, dismissed the batch dialog outside,
  and closed selection without changing memberships.
- Opened Favorites Sync's Kurumi destination picker, temporarily selected the QA
  group, restored None and closed without saving or fetching. This exercised
  destination-return semantics independently of bookmark toggling.

Deleted only the temporary group and its four unique QA entries; All Bookmarks
showed No data available. Restored Android font scale 1.0, Browse's original
Danbooru profile and Favorites' original Pixiv profile, then released the lease.
QA searches remain in ordinary history. Two launch assertions preceded cold-start
readiness (one overlapped APK replacement); inspection and the subsequent flows
confirmed the running candidate. No app reset or account changes were needed.

Automated tests cover deferred metadata timing, repeated actions, animation-time
cancellation, exact source changes, create handoffs, nested context-menu navigation,
stored-reference dialogs, narrow widths, enlarged text, keyboard layouts, RTL,
pointer bounds and focus restoration. Device checks above establish the exercised
Android paths; they are not a latency benchmark or blanket input-platform pass.
Physical-device, desktop mouse/context-menu, assistive input, live account-removal,
offline, backup-upgrade and device RTL coverage remain manual. The stored-card
context dialog and Post nested context submenu were verified in host tests rather
than through Android's default long-press selection interaction.

The candidate passes the complete local gate on its recorded #139 dependency.
A changed combined develop candidate requires new complete verification before
any separately authorized integration.

Local evidence: `.worktrees/_artifacts/145-bookmark-picker-presentation/`, including
entry-point inventory, analysis, focused tests, full regression and build logs.
Earlier compile/fixture failures and the mismatched-viewport RTL diagnostic are
superseded by the final results above; they do not establish a production defect.
