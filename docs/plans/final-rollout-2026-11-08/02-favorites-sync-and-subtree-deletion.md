# Plan 02: reliable Favorites Sync settings and recursive group deletion

Read the [lead handoff](../../handoffs/final-rollout-remediation-2026-11-08.md). This plan concerns #132/#143/#156 and #158, with #144 consumer implications. Audited source baseline: `4b9e8f6f9fbdd5020e1de87942f4b8a5f683ba5d`.

## A. Favorites Sync Save rejects an unchanged account

### Source-supported cause to reproduce

`lib/core/bookmarks/src/server_favorites/dialog.dart` captures all navigation profiles when opening. `settings_provider.dart::saveAll` compares that list both with the live provider and a fresh repository `getAll()`. `serverFavoriteAccountsMatch` requires complete `BooruConfigAuth` equality for every profile, not only the selected fetch target.

`lib/boorus/pixiv/client_provider.dart::persistPixivRotatedToken` intentionally updates the persisted refresh token and `passHash` account/session metadata without rebuilding `BooruConfigNotifier`. Its comments explain that rebuilding the family-keyed Dio on every rotation would drop the live access token and cause refresh churn. `BooruConfigAuth.props` includes both changing fields.

Consequently, a normal Pixiv refresh can leave a legitimate persisted profile unequal to the dialog's in-memory profile. A later Save can report `accountChanged` even when editing a different profile or the global default. The guard throws before the settings write, explaining why reopening loses the draft and why Save & Fetch never starts. This is a concrete cross-feature failure mechanism; confirm that it explains the actual user case instead of assuming every instance has the same cause.

### Implementation sequence

1. Add a regression through the real settings notifier/dialog and a Hive-backed profile repository. Start with equal provider/repository profiles, persist a normal Pixiv rotation using the production helper without updating the notifier, then save the global group, a per-profile override and Save & Fetch. Include an unrelated Pixiv profile while editing another engine.
2. Separate stable logical actor identity from mutable session credentials. Reuse existing profile/source identity and engine account identity, such as Pixiv's known user ID, with current captured-operation rules. A rotating token or expiry is not by itself an account switch. A different source/user ID, deleted/recreated record or explicit reauthentication to another actor is.
3. Keep local target assignment distinct from remote dispatch. Saving a valid existing local group assignment must not require online account validation or equality of unrelated profiles' ephemeral tokens. Validate the changed targets and preserve optimistic settings-concurrency checks; merge only intended edits into the latest settings where the existing contract requires it.
4. At explicit fetch dispatch, obtain current usable credentials from the existing session/repository path for the captured logical actor. Do not run with a stale refresh token, silently adopt another account, or force-rebuild Pixiv's entire provider chain on every token rotation. If the existing fetch runner has the same full-auth comparison, repair the whole save-to-fetch chain rather than just the first guard.
5. Preserve durable-write semantics: publish success only after successful persistence; a disk failure retains the editable draft and gives the actual storage error. Reopening/restarting must show confirmed values. Saving alone must neither fetch nor clear Group contents. Save & Fetch first commits settings, then starts only the requested actor's job.
6. Distinguish account-changed, target-changed, missing-target, local-write failure and remote-fetch failure in diagnostics. Log field-category differences and stable redacted actor identity, never credentials or raw profile JSON. Use localized user messages and the existing error/logger mechanisms.

Do not solve this by deleting all actor checks, accepting every same-host account, writing the dialog's old credentials back to disk, or adding a second token/session registry.

### Required tests

- Save global Default Bookmark Group and per-profile targets, including inherit/none/group, then reopen and restart.
- Save without a fetch performs zero Favorite network calls and preserves existing direct memberships/snapshots/dates.
- Normal Pixiv token/expiry rotation before Save, during Save and between Save and fetch does not cause a false account change.
- Actual account/user/source switch or profile deletion during an open dialog/fetch is rejected without borrowing another profile.
- Another profile's normal token refresh cannot block the selected profile or a global assignment.
- Local write failure, concurrent target edit, deleted group and cancelled fetch have distinct outcomes; the previous durable settings remain valid.
- Single-account and multi-account Save & Fetch exercise the actual runner; synthetic success callbacks alone are insufficient.

Verify on Android with the existing test accounts, using bounded reads. Do not send unnecessary remote Favorite add/remove mutations.

## B. Delete a parent and its complete local subtree

### New user decision

The earlier plan deliberately promoted child groups when deleting a parent. The user has now rejected that behavior. Deleting a local Group must remove that Group and all descendant local Groups. No descendant is automatically moved to Home or an ancestor. This changes semantics, not merely an icon or toast.

Existing implementation points:

- `lib/core/bookmarks/src/services/bookmark_hierarchy_undo.dart`: `deleteHierarchy` currently deletes supplied IDs and calls `promotedChildrenFor`.
- `lib/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart`: `previewDeleteGroup`/`deleteGroup` also use promotion semantics.
- `BookmarkGroupTree`, `BookmarkCollectionDeletionPreview`, library mutation/notifier paths, browser confirmation, view preferences, Recent and Favorites Sync targets.

### Canonical operation

1. Compute the transitive descendant closure of the selected root IDs against one current validated hierarchy snapshot. Deduplicate overlapping selections: selecting A and its descendant B must not delete or count B twice. Use the existing indexed tree and bounded traversal rather than repeated whole-library scans.
2. Derive confirmation from that same closure: affected Group count, affected memberships and Bookmark records that lose their last membership. Explicitly state that subgroups are included. Protect reserved Home/All/Default semantics; neither a virtual view nor the reserved Default can be deleted via this path.
3. At commit, under the existing mutation coordinator, verify the preview is still applicable. A newly added/moved child or changed outside membership after confirmation must trigger the existing stale-preview/reconfirmation behavior, not silently expand destructive scope.
4. Remove the full set of Group IDs and their direct memberships in the existing journaled organization transaction. Remove a Bookmark payload only when it has no surviving membership outside the removed subtree, following the existing last-membership deletion contract. The same applies to Post and ContentGroup records. Do not create unwanted Default memberships or touch remote server data.
5. Reconcile every public deletion entry point with the canonical behavior, including single card, selection/batch, settings/maintenance and any repository callers. A second low-level method must not continue promoting children.
6. Normalize the open browser/picker once to the nearest surviving ancestor. Clear stale selections and references without cascading upward across rebuilds. Delete associated local mode/Recent entries consistently; prevent a running Favorites import from resurrecting its deleted target. A deleted sync target becomes explicitly unavailable, never silently redirected.
7. For published #144 hierarchies, emit coherent deletion intent only after successful local commit. Received mirrors must obey their explicit detach/unsubscribe/removal contract; local deletion never tells the remote publisher to delete anything.

### Undo and recovery

Reuse `BookmarkHierarchyDeletion` and the existing organization journal. The receipt must retain every deleted Group's parent, sibling order, memberships and added-at dates plus affected payload snapshots. Remove obsolete promoted-child assumptions. In particular, `singlePreview` currently assumes `deletedGroups.single`; one selected root can now delete many Groups, so derive root-level UI feedback from the requested root rather than asserting one deleted node.

Undo restores the subtree atomically and retains outside memberships. Reuse surviving content records; recreate deleted records through the existing monotonic allocator, preserving source identity rather than requiring reuse of tombstoned local IDs. Validate newer conflicting changes before writing; do not overwrite a newly recreated Group or resurrect content deliberately deleted by a later operation. A failed deletion must not advertise Undo; committed-then-throw recovery must still recognize the complete transaction.

Keep persisted backup v10 compatible. This behavior change does not require a new public backup version. Update old promotion documentation, confirmation translations and tests explicitly instead of leaving contradictory active contracts.

### Required tests

Build A -> B -> C, another root D, shared Post P in C and D, plus a Work/Pool record only in B. Delete A: A/B/C and the exclusively held payload disappear, D/P survive. Undo restores all three Groups, parent/sibling order, member dates and the independent outside membership.

Also cover parent+child multi-selection, two disjoint subtrees, empty nested Groups, stale confirmation, concurrent membership change, write failure before/after journal commit, cold reopen/recovery, undo conflict, an open descendant page, picker navigation, Recent, stored Structure/Unified preferences and an active Favorites job targeting the deleted subtree. Exercise one disposable hierarchy on Android after backing up the test installation.
