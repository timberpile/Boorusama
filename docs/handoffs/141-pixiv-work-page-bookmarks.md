# Issue #141: independent Pixiv Work and Page Bookmarks

Branch/worktree: `feature/141-pixiv-work-page-bookmarks`,
`.worktrees/141-pixiv-work-page-bookmarks`.
Base: published `develop` commit `bfc9030a9c14b539d9d3877911d41dc442633cd2`,
which integrates accepted #140, including the short horizontal swipe correction.
Status: production integration implemented; complete final-candidate regression
is pending. This is local work for the owner's separate review. No publication,
PR, develop integration, issue closure or Android/live-service acceptance is claimed.

## Production behavior

- The existing shared Viewer toolbar's Bookmark button targets the entire Pixiv
  Work by default. Hold offers Work or the captured current real Page. Both
  explicit actions also appear in the existing overflow menu. Missing/restricted
  Pages have no actionable Page target. No second toolbar or fullscreen route
  was introduced.
- Summary-only Details can save a Work immediately without waiting for members
  or manufacturing a Post. Native Browse/Search cards offer the same Work picker
  from their existing context-menu surface. The selected Page's download, media
  share, quality and remote Favorite actions retain the normal toolbar path.
- The generic picker accepts immutable ContentGroup drafts. Its provisional ID
  never selects storage. Opening freezes the Work/Page and source access; later
  selection or hydration does not redirect the pending action. Existing Recent,
  navigation, creation, dismissal, Back/Escape and saved-record editing remain.
- Saving a Work writes one genuine `group/work:<illustId>` record and no implicit
  Pages. Saving a Page writes only its real `post/work-page:<illustId>:<index>`
  record. Their memberships, last-membership removal, Undo and cold restart are
  independent. No remote Favorite operation, new store, or backup version is used.
- Captured picker ownership is checked after awaits and at the repository journal
  boundary through the existing asynchronous operation's scoped guard. New Group
  creation commits the prepared Work/Page and Group together. The captured Page
  path reuses existing Post snapshot preparation, avoiding an empty destination
  when access is revoked during preparation.
- Saved native Works participate in mixed Bookmark grids, membership-date order,
  tag/source filtering, suggestions, mosaics, source availability counts and
  selection. Cards reopen the existing mixed Viewer with stored metadata and
  captured source binding. Bulk membership editing uses authoritative saved IDs.
  An invalidated mixed selection reports failure without an uncaught exception.
- Stored covers respect source policy, rating, tags, deleted/banned flags and
  existing thumbnail-quality preferences. They use known thumbnail/sample media,
  never fetch a manifest or an original just to fill a card, and retain a stable
  placeholder when unavailable. v10 backup preserves Work/Page identities,
  independent membership dates and optional safe cover metadata. Existing Work
  and Page portable `.bslink` paths remain separate from source Work URLs.

## Current verification (2026-11-13)

Durable evidence: `.worktrees/_artifacts/141-pixiv-bookmarks-20261113/` in the
primary workspace.

- Existing Pixiv Works, Bookmark feature, Content contracts and backup-source
  consumer suite: **1,196 passed**, `focused-initial.log/.exit`.
- Final Work/action/storage/cover/backup and bulk selection suite: **65 passed**,
  `actions-final.log/.exit`. The native UI cases exercise actual picker surfaces,
  long-press choice, frozen Page selection, new Group handoff, 320dp/200-percent
  text, keyboard insets, dismissal and access revocation. Storage checks use real
  Hive journals with completion gates after preparation: both successful targets
  and cancellation, context loss or profile removal leave the expected records
  and Groups. Creation's first commit must contain both the target and Group.
- Shared mixed Viewer plus stored-cover suite: **134 passed**,
  `cover-viewer.log/.exit`. The real standard toolbar is asserted to contain the
  Work Bookmark button in the existing portrait/narrow/enlarged/landscape matrix.
  Cover checks reject deleted/banned/missing-profile media, preserve quality and
  prove no Group source is constructed to display stored covers.
- The stale mixed-selection regression fails on the previous implementation with
  the actual uncaught StateError (`stale-selection-red.log/.exit`), then passes
  with localized failure and no dispatched write in the final action suite.
  Earlier new-fixture failures are retained separately: toast timers needed
  expiry on the controlled widget clock, the reserved Default Group belongs to
  the expected preimage, and real Post preparation needs its engine codec.
- All **41 changed Dart files** formatted with FVM; `git diff --check` passed.
  Final affected-scope analysis: **0 errors, 2 existing warnings, 197 infos**,
  exit 2 (`analysis-final.log/.exit`). The warnings are the existing promoted
  cast and unused `coverUrl` variable in the mixed Viewer source/test.
- The complete local suite will qualify the final commit before owner-review
  delivery. Earlier foundation passes below do not qualify this new combination.

These are native Flutter host and real local storage checks. No Android target
is currently configured; the owner directed native UI testing where possible.
No new APK, emulator operation, real platform clipboard/share/download or live
Pixiv mutation is claimed. The completed older foundation review below is
historical; the current production diff was self-reviewed. Do not run Astra
subagents unless the owner explicitly requests them again.

## Preservation and continuation

All 33 originally modified/untracked #141 files were preserved in recovery
commit `95bdcb0d13257b52de60e1a67079d187881205ad`, then checkpointed on the original
branch before replay. `refs/recovery/141-before-develop-20261113` retains
`7097c9f8508f447585bc526f03fd40771c1a096a`. Only the four #141-owned commits after
`1cd076deb...` were replayed onto published develop; no old cumulative prerequisite
history was replayed or force-pushed. The primary checkout and unrelated tasks
were preserved.

Keep #141 at its own owner-review gate. Once ready, continue #144 and then #157
without waiting for another implementation instruction. Before implementation,
inspect and reconcile their feature branches, handoffs, tests and approved
designs. `maintenance/combined-testing-2026-11-08` is reference material only,
never a merge source. Preserve individual acceptance and publication boundaries.

## Historical source-foundation handoff

The following records pre-integration work and its original remaining steps;
those statements are superseded by the current production state above.

## Started contract

`lib/boorus/pixiv/works/bookmark_targets.dart` captures immutable, distinct local
targets using the existing generic Bookmark records and codecs:

- A Work target retains a genuine `group/work:<illustId>` Summary plus optional
  already loaded Details. Building its ContentGroupBookmark draft performs no
  detail/member/media request and embeds no implicit Page snapshots.
- A Page target captures one real, actor-bound Pixiv Post with its deployed
  `post/work-page:<illustId>:<originalIndex>` identity, media and typed data. A
  later Page/Work selection cannot redirect that frozen target. Unavailable or
  restricted Pages cannot manufacture actionable draft targets.
- Draft creation checks the current existing ContentAccessContext against the
  captured context through its established authorization predicate. Revocation
  or another same-site account is rejected. This does not replace the generic
  mutation session's checks across awaits or add another authorization model.
- Draft local ID zero is provisional. Only the repository allocator may publish
  a local ID; it must never be passed as a saved-record selector.
- Work/Page drafts use the existing ContentGroupBookmark/PostBookmark envelope,
  source profile hint, source-native tag index and v10 tagged record codec. No
  shared storage, schema, backup version, cache or provider model is changed.
  Remote Pixiv Favorite services are not part of this path.

The engine-local tests drive both tagged-codec round trips and actual unified
Hive storage. They cover separate Work/Page memberships, repeated Work save,
independent last-membership removal and Undo, cold restart, original Page index,
source binding and the absence of implicit Page payloads in Work records.
Last-membership Undo deliberately allocates a fresh local storage ID through
the existing generic service; the original Work/Page source identity and index
remain unchanged. The tests preserve that established allocator behavior.

## Remaining integration

The existing sealed BookmarkPickerRequest still has unsaved remote Group paths
specialized for Pool/Related. Do not cast a Work into a synthetic Pool or pass its
provisional ID as a SavedBookmarkPickerRequest. The next shared change should
add a generic unsaved ContentGroup draft request/adapter to that same picker and
existing mutation session, with frozen actor/target checks around awaited work.
Coordinate common files with the #156 lead before editing.

After #140's active-media bridge is connected, normal Bookmark selects Work;
hold/overflow offers Work or Current Page through that shared picker. Preserve
immediate opening, Recent, direct memberships, creation, Back/Escape, successful
dismissal and action-target capture. The decorative hold chevron stays inside
the established fixed button hit bounds and does not create another target.

The shared Group URI and `.bslink` v1 infrastructure already exists after #156.
Connect the existing Share Sheet to the distinct Work/Page references instead
of inventing a source Page URL or using synthetic numeric Post IDs as Work IDs.
Page-specific bytes remain Page actions; native Pixiv source links stay Work
links. Narrow/large-text UI, picker during swipes, resource cleanup and cancellation
still require production-path regressions.

Final acceptance requires mixed-library import/backup compatibility, fresh
independent actual Sol High review of the production integration, complete
final-candidate regression and leased real Android/Maestro Work/Page
save/open/remove/Undo/share verification with full
restoration. No emulator is owned by this workstream. The approved Image View/
Overview and Work/Page action decisions are already recorded; no new unresolved
product decision was introduced by this foundation.

## Verification

Fresh-worktree setup used pinned FVM/dependency resolution and `./gen.sh` only
because generated outputs were missing. Durable command evidence is retained
under `.worktrees/_artifacts/141-*` in the primary workspace. Two overlapping
intermediate Flutter runs collided while cleaning their disposable test-assets
directory; both were stopped (exit 130). Neither is passing evidence. Subsequent
Flutter test commands ran sequentially. An intermediate run also exposed a
missing test import and the incorrect test assumption that last-membership Undo
reuses a deleted local ID. Both were corrected without changing shared storage.

On the unchanged runtime/test candidate committed with this handoff:

- `fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works
  test/core/bookmarks/stored_bookmark_codec_test.dart
  test/core/bookmarks/bookmark_unified_library_service_test.dart`: **34 passed**.
  Evidence: `.worktrees/_artifacts/141-bookmark-targets-final-rerun.log`.
- `fvm dart analyze lib/boorus/pixiv/works test/boorus/pixiv/works`: **no issues**
  (zero errors, warnings or informational findings). Evidence:
  `.worktrees/_artifacts/141-bookmark-targets-final-analysis.log`.
- Changed Dart formatting and `git diff --check` passed.

These are targeted foundation checks, not complete final-candidate regression,
live Pixiv or Android/Maestro evidence. The completed foundation review/re-review
is recorded below; production integration review remains open. No push,
PR, integration, issue closure or device operation was performed.

## Independent Sol High review correction

The independent foundation review's P2 tag-omission finding applied to the
inherited #140 mapper. The verified #140 fix `308463b1dcedf252ae260a361e13f6300244b9f5`
was propagated here as `207e0e054`: Pixiv DTO observations preserve unknown,
partial and explicitly complete tags. Omitted facts no longer create a complete
empty Group index; explicit `tags: []` still does. Malformed subsets retain
usable native tags and partial coverage without throwing.

An additional #141 regression checks unknown/empty/partial index coverage and
proves that merging an omitted refresh retains cached native/translated index
tags. No Bookmark storage or schema change was needed.

- Final `fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works
  test/core/bookmarks/stored_bookmark_codec_test.dart
  test/core/bookmarks/bookmark_unified_library_service_test.dart`: **37 passed**,
  `141-tag-omission-final-tests.log`.
- Analysis of Work source/tests and changed Pixiv DTO/test: **no issues** (zero
  errors, warnings or informational findings), `141-tag-omission-final-analysis.log`.
- The complete **240-test** booru_clients pass is reused from the identical
  package subtree at #140's correction; `140-tag-omission-package-suite.log`.
  `git diff 308463b1d -- packages/booru_clients` is empty on this candidate.
- Changed Dart formatting and `git diff --check` passed.

Independent actual Sol High review and re-review are complete for source candidate
`1167f6dbf398be58879cf2967bd0c2a084cbe8f4`. The reviewer independently reran the
Work/codec/library command: **37 passed**, `sol-review-141-corrected-tests.log`.
The omitted/explicit-empty/partial-tag finding is resolved, with no remaining
actionable foundation findings. The reviewer also independently verified the
corrected #140/#141 package subtrees match and reused the owning 240-test package
pass. The [durable independent report](../../../_artifacts/architecture-foundations-sol-review.md)
records the exact scope and limits; it is local workspace evidence, not a
published repository artifact.

This final handoff update and the reconciled inherited #140 handoff change
documentation only. Runtime, tests and package files match the reviewed candidate;
existing scoped/package passes remain applicable. Documentation links and
`git diff --check` were verified without rerunning application tests.

Production listing/viewer integration, generic picker/share/UI wiring, full
combined regression, fresh production integration review and current
Android/Maestro acceptance remain open. The source foundation review does not
complete #141 or authorize integration.
