# Paste multiple searches into a feed or pinned-search folder

Priority: Normal
Affected feature: Pinned searches and following feeds / `feature/17-following-feeds`
Agent: `/root` (2026-09-20)
Work branch: `feature/17-following-feeds`

## Problem

Adding many searches currently requires one interaction per source.

## Expected behavior and acceptance criteria

- A user opens a feed or folder, pastes newline-delimited raw searches, and adds them to that selected destination.
- For folders, the user selects the owner profile. Empty lines and duplicate queries are skipped without moving existing independent pins.
- New definitions are saved without triggering a burst of immediate refresh requests.
- Invalid input or a failed save leaves the dialog open with an error.

## Context

Feed imports use the feed's profile and existing source limit. Folder imports create independent pins and retain the selected folder's organization.

## Completion evidence

- Logic and widget tests verify newline parsing, duplicate skipping, selected destination, and no immediate requests.
- Maestro showed the folder and feed dialogs with destination, multiline field, and owner profile selector for folders.
