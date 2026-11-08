# Issue #141: independent Pixiv Work/Page Bookmark continuation

Status: **started, incomplete, not approved**. The user explicitly authorized
beginning this issue after #140 establishes a stable source contract; completion
still depends on #140's actual viewer/listing integration. No runtime UI cutover,
PR, publication, develop integration, issue closure or device acceptance is
claimed.

Branch/worktree: `feature/141-pixiv-work-page-bookmarks`,
`.worktrees/141-pixiv-work-page-bookmarks`.
Base: `0e69d84c7f0cf6df0136e5fb249c7826c9f77e8a`, the #140 engine-owned
Work/Page foundation. Its [handoff](140-pixiv-work-viewer.md) records prerequisite
limits, including the unfinished inherited #156 cache remediation. The current
#156 lead owns shared cache/access changes. Reconcile the final prerequisites
before combined acceptance.

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

Final acceptance requires mixed-library import/backup compatibility, independent
actual Sol High review/re-review, complete final-candidate regression and leased
real Android/Maestro Work/Page save/open/remove/Undo/share verification with full
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
live Pixiv or Android/Maestro evidence. Independent Sol High review/re-review
remains coordinated by the #156 lead after the foundation commits. No push,
PR, integration, issue closure or device operation was performed.
