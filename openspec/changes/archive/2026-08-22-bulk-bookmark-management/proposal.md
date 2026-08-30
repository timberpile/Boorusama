## Why

Multi-selection still exposes the old single-purpose bookmark action, which cannot represent local bookmark groups or safely handle selections whose posts have different memberships. Users need one clear entry point for managing selected bookmarks while preserving selection mode for consecutive group edits.

## What Changes

- Replace the old multi-selection bookmark action with a `Bookmarks` action that opens a context menu.
- Expose `Add to group >`, `Remove from group >`, and `Delete` from that menu.
- Add group-selection dialogs that show aggregate membership counts for the selected posts rather than pretending their memberships are identical.
- Make add operations additive and preserve all existing memberships.
- Make bulk remove operations remove only the selected group membership, leaving a bookmark with no remaining memberships in `No Group`.
- Keep selection mode active after successful add or remove operations so users can perform consecutive actions.
- Keep complete bookmark deletion separate from group-membership removal.
- Separate the notifier operations for membership-only removal, complete deletion, and single-post removal that deletes a bookmark when its final membership is removed.
- Add focused provider and UI coverage for mixed memberships, No Group behavior, selection persistence, and safe group removal.

## Capabilities

### New Capabilities

- `bulk-bookmark-management`: Manage selected posts' local bookmark group memberships and complete bookmark deletion through the multi-selection bookmark action.

### Modified Capabilities

None.

## Impact

- Multi-selection action UI and bookmark group dialogs.
- Bookmark notifier APIs and group-membership mutation semantics.
- Bookmark-list selection refresh and item removal behavior.
- Localization for the new menu and dialog actions.
- Provider, widget, and existing bookmark-group tests.
