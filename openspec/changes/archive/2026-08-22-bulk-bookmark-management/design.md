## Context

The default multi-selection action currently calls the legacy bulk bookmark operation, which only adds posts that are not globally bookmarked. The bookmark content view also performs complete deletion directly and disables selection after the operation. Group-aware single-post controls already maintain local bookmark memberships, but their final-membership removal currently has different semantics from the required bulk group removal.

The new workflow must support selections containing unbookmarked posts, ungrouped bookmarks, and bookmarks with different named-group memberships. See `proposal.md` and `specs/bulk-bookmark-management/spec.md` for the user-visible contract.

## Goals / Non-Goals

**Goals:**

- Give multi-selection one `Bookmarks` entry point with explicit add, remove, and delete actions.
- Make mixed group membership understandable through aggregate counts.
- Keep bulk group removal membership-only so final removal produces a No Group bookmark.
- Preserve the existing single-post behavior that deletes a bookmark when its final group membership is removed.
- Keep selection active across consecutive bulk operations.
- Reuse the existing local group and bookmark state rather than introducing a second grouping model.

**Non-Goals:**

- No dedicated Move operation; moving is performed by adding to the destination group and then removing the source membership.
- No per-post membership editor inside the multi-selection dialog.
- No changes to Danbooru server-side favorite groups.
- No changes to the global search setting that hides bookmarked posts.

## Decisions

### Use a bookmark action menu from the multi-selection button

The bottom bookmark button will remain a single compact action in the selection bar, but its label and accessibility name will be `Bookmarks`. Pressing it opens an anchored menu containing `Add to group >`, `Remove from group >`, and `Delete`.

This keeps the selection bar compact while making the operation choice explicit before presenting the group list. The menu does not need a `Bookmarks` header because the entry point already identifies the feature. The add and remove rows open the same style of group-selection surface with operation-specific titles; `Delete` opens a confirmation dialog.

The existing action-bar abstraction only renders standard multi-select buttons. The bookmark action therefore needs a small specialized popup-capable selection action that preserves the existing button appearance while owning its popup state. The popup should use the app's existing anchored menu treatment and menu-item styling rather than adding a new global navigation pattern.

### Calculate aggregate membership for the selected posts

Before showing an add or remove dialog, derive a snapshot from the selected posts and the current bookmark membership state:

- total selected posts;
- number of selected posts already bookmarked;
- number of selected posts with no named memberships;
- named-group membership count for every group represented by the local group repository.

Each named-group row will show an aggregate count such as `5 of 12`. Add and remove dialogs can phrase the same count differently, but neither dialog will show a single binary checkmark for the mixed selection. The add dialog includes `No Group`; the remove dialog lists named groups only, with groups having no matching selected memberships disabled or omitted.

For `No Group` additions, the operation is deliberately conservative: create ungrouped bookmarks only for selected posts that are not bookmarked, leave already-ungrouped bookmarks unchanged, and do not clear memberships from grouped bookmarks. This preserves the additive nature of the add action and avoids turning an apparently harmless selection into a bulk membership-clearing operation.

### Split bookmark mutation semantics into three operations

The bookmark domain will expose three distinct behaviors:

- `removeBookmarkFromGroup`: remove only the requested membership and preserve the bookmark even if no named memberships remain. This is used by the bulk remove dialog.
- `deleteBookmark`/`deleteBookmarks`: remove the bookmark, all memberships, and associated cached images. This is used by the explicit Delete action.
- `removeFromGroupAndDeleteIfLast`: remove the requested membership and delete the bookmark only when it was the final named membership. This preserves the existing single-post toggle behavior.

The current final-membership deletion branch must not remain hidden inside the membership-only operation. Keeping the branch-specific behavior at separate call sites makes it possible to test the bulk dialog's No Group guarantee independently from the single-post behavior.

Bulk operations should load the selected bookmark records and memberships once, perform the necessary repository writes, refresh provider state once, and report failures without disabling selection. They should avoid deleting a bookmark as a side effect of membership-only removal.

### Keep selection mode active and reconcile changed listings

The new bookmark actions will not call the selection controller's disable method after add, remove, or delete. After state refresh, the listing controller will retain selection for items that remain in its current item set. Items removed by the active bookmark filter may disappear and be removed from the visible selection as part of normal controller reconciliation.

This allows a user to add selected posts to Group B, reopen `Bookmarks`, and remove them from Group A without selecting them again. It also avoids leaving the selection UI in a disabled state when an operation fails.

### Test both domain semantics and the dialog entry points

Provider tests will cover the three mutation behaviors, including the critical case where bulk group removal leaves a bookmark with an empty membership set and therefore visible in `No Group`. Widget tests will cover the `Bookmarks` menu labels, add/remove aggregate counts, the No Group add behavior, delete confirmation, and selection persistence after successful actions.

## Risks / Trade-offs

- **Popup implementation complexity:** The existing selection action bar is built around ordinary buttons, so a popup-capable bookmark action needs a small specialized integration. → Keep the existing visual button contract and reuse the existing anchored menu primitives.
- **Aggregate counts can be misunderstood:** A count such as `5 of 12` does not describe each post individually. → Use explicit operation-specific wording and never use an ambiguous binary checkmark for mixed selections.
- **Large selections may involve many writes:** Adding or removing memberships across a large selection can be expensive. → Load state once, batch repository work where supported, refresh once, and keep selection active during the operation.
- **Delete is destructive:** Users could confuse it with group removal. → Keep Delete as a separate menu item and require explicit confirmation.

## Migration Plan

1. Add the new multi-selection menu and group-selection dialogs while preserving the existing single-post controls.
2. Split membership-only removal from final-membership deletion in the bookmark notifier and update callers according to their intended semantics.
3. Replace the legacy multi-selection add and bookmark-page complete-removal actions with the new workflow.
4. Add localization and focused provider/widget tests.
5. Run formatting, analyzer, focused tests, and strict OpenSpec validation.

No persisted-data migration is required. Existing bookmarks with no group memberships already represent the `No Group` view.
