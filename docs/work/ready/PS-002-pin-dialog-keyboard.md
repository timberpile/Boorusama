# Do not automatically open the keyboard when pinning a search

Priority: Normal
Affected feature: Pin search dialog
Reported on branch: `fix/rule34-pinned-search-tracking`

## Problem and reproduction

Open search results and choose to pin the search. The optional name field
automatically receives focus and opens the keyboard.

## Expected behavior

Opening the dialog leaves the keyboard closed. Users can tap the name field
to enter a custom name, or pin immediately using the query as the label.

## Acceptance criteria

- [ ] Opening the pin dialog does not automatically open the keyboard.
- [ ] Tapping the name field still opens the keyboard and allows editing.
- [ ] Pinning with a blank or custom name continues to work.

## Relevant context

- `lib/core/search/subscriptions/src/widgets/pin_search_dialog.dart` currently
  sets `autofocus: true` on the name field.
- Validate Android UI behavior with Maestro as required by `AGENTS.md`.

## Completion evidence

Record verification here when resolved.
