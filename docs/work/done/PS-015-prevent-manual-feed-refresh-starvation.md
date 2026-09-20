# PS-015 Prevent feed refresh starvation

- Priority: Normal
- Feature/branch: Following feeds / `feature/17-following-feeds`

## Problem

The prototype's manual feed refresh repeatedly checked only the ten oldest
sources. Persistently failing sources could exclude the remaining sources.

## Expected behavior

Following one tag checks that source directly. Ongoing foreground scheduling
checks feed sources incrementally, including after individual failures.

## Acceptance criteria

- [x] Adding a source triggers a refresh of that source, independent of older
  feed sources.
- [x] The bounded manual feed refresh action and its ten-source selection are
  removed.
- [x] Source refreshes still use the shared request gate.

## Completion evidence

The Follow dialog calls `refresh` for the source IDs just added. The only
`refreshFeed` caller and method were removed. Android Maestro verified creating
a feed from a search and subsequently opening it with cached posts. The focused
subscription tests and full Flutter suite passed on 2026-09-20.
