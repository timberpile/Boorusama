# Detect new posts by highest observed post ID

Priority: High
Affected feature: Pinned searches and following feeds / `feature/17-following-feeds`
Agent: `/root` (2026-09-20)
Work branch: `feature/17-following-feeds`

## Problem

Refresh currently compares upload timestamps to the previous check time. A higher ID with an older timestamp does not set NEW, despite default post order being approximately ID descending.

## Expected behavior and acceptance criteria

- Each tracked search stores its highest observed post ID across successful refreshes.
- The first successful refresh establishes a baseline; later snapshots set NEW when they contain a higher ID, regardless of upload timestamp.
- Lower or equal IDs do not set NEW. Empty snapshots and failed refreshes retain the ID boundary.
- Existing stored searches migrate safely and the boundary survives reopening Hive storage.
- Feed NEW continues to aggregate its member searches.

## Context

The timestamp of the last successful check remains useful for scheduling and display. Refreshes still fetch one bounded page of 50 posts.

## Completion evidence

- Service tests verify higher IDs set NEW even with older timestamps; lower IDs with newer timestamps do not.
- Repository tests verify baseline and empty snapshot behavior, Hive persistence across reopening, reset on site change, and safe initialization of older searches without the ID field.
- All 223 search-subscription tests passed and full `fvm dart analyze` found no issues.
