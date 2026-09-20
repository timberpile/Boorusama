# Show recent previews on feed cards

Priority: Normal
Affected feature: Following feeds / `feature/17-following-feeds`
Agent: `/root` (2026-09-20)
Work branch: `feature/17-following-feeds`

## Problem

The feed overview lists names and profiles but does not show cached posts.

## Expected behavior and acceptance criteria

- Each feed row shows up to four newest cached post thumbnails, matching pinned-search previews.
- Images use the owning profile's authentication and the overview reads cached state without fetching posts.

## Context

Feed posts already retain recent thumbnail URLs in chronological order. This task is limited to their overview presentation.

## Completion evidence

- Widget test verifies four cached preview URLs use the owning profile and require no post fetch.
- Maestro on Android showed four loaded thumbnails and owner captions for all three existing feeds.
