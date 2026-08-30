## 1. Bookmark mutation semantics

- [x] 1.1 Split membership-only removal, complete bookmark deletion, and single-post final-membership removal into distinct notifier operations with clear names and documentation.
- [x] 1.2 Add batch-oriented add-to-group and remove-from-group operations that load selected bookmark state once, preserve unrelated memberships, and refresh provider state once.
- [x] 1.3 Ensure membership-only removal leaves a bookmark with no remaining memberships in the No Group view, while the single-post operation retains final-membership deletion behavior.
- [x] 1.4 Update all existing single-post, bookmark-list, group-picker, and bulk-action callers to use the operation matching their intended semantics.

## 2. Aggregate group-management UI

- [x] 2.1 Add the multi-selection `Bookmarks` action that opens the bookmark-management menu with `Add to group >`, `Remove from group >`, and `Delete`.
- [x] 2.2 Build reusable selected-post membership aggregation that reports total selected posts, existing bookmark count, ungrouped count, and per-group membership counts.
- [x] 2.3 Implement the Add to group dialog with named groups, No Group, group creation, aggregate counts, additive membership behavior, and the documented No Group behavior.
- [x] 2.4 Implement the Remove from group dialog with named-group membership counts, membership-only removal, and operation-specific feedback.
- [x] 2.5 Implement the Delete confirmation and complete deletion flow separately from group-membership removal.

## 3. Multi-selection integration

- [x] 3.1 Replace the legacy global bookmark action in normal post-list multi-selection with the new `Bookmarks` workflow.
- [x] 3.2 Replace the bookmark-page multi-selection complete-removal action with the new workflow while retaining an explicit Delete operation.
- [x] 3.3 Keep selection mode active after successful add, remove, and delete operations, reconciling items that leave the current filtered view without disabling the remaining selection.
- [x] 3.4 Verify the same workflow works from All, No Group, and named bookmark-group views and supports consecutive add-then-remove operations.

## 4. Localization and user feedback

- [x] 4.1 Add localized labels for `Bookmarks`, `Add to group`, `Remove from group`, `Delete`, dialog titles, aggregate membership summaries, and confirmation messages.
- [x] 4.2 Add success and failure feedback for bulk group additions, membership removals, and complete deletion without conflating membership removal with bookmark deletion.

## 5. Tests

- [x] 5.1 Update existing provider coverage so final-membership deletion is tested through the single-post operation rather than membership-only removal.
- [x] 5.2 Add provider tests proving membership-only removal preserves the bookmark, produces empty memberships, and makes it visible in No Group.
- [x] 5.3 Add mixed-membership tests for additive group assignment, membership-only removal, preservation of unrelated memberships, and No Group additions.
- [x] 5.4 Add widget tests for the `Bookmarks` menu actions, aggregate group counts, add/remove dialogs, Delete confirmation, and selection persistence.

## 6. Verification

- [x] 6.1 Run formatting and static analysis for changed Dart and localization files.
- [x] 6.2 Run focused bookmark provider, group, multi-selection, and widget tests.
- [x] 6.3 Run strict OpenSpec validation and review the final change status.
