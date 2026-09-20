# Explain query and rate-limit refresh failures

Priority: High
Affected feature: Pinned searches and following feeds / `feature/17-following-feeds`
Agent: `/root` (2026-09-20)
Work branch: `feature/17-following-feeds`

## Problem

Danbooru `-video -touhou` reports a generic query failure. HTTP 429 is collapsed into network failure, and feed screens do not expose source error kinds.

## Expected behavior and acceptance criteria

- The pinned-search card explains a search-term limit when the server returns 422.
- Refresh checks do not add an explicit sort term on any engine.
- HTTP 429 has a distinct persisted refresh error and visible wording on pinned searches, feed overview, feed page, and source management.
- Failures preserve cached posts and checkpoints.

## Context

The earlier Danbooru refresh appended `order:created_at`, which counted against a normal account's two-term limit. Error kinds are persisted by enum name.

## Completion evidence

- Refresh tests cover HTTP 422 and 429; card and feed widget tests cover the corresponding visible messages.
- Query adapter tests verify Danbooru and Szurubooru omit added sort terms; Philomena no longer receives sort fetch options.
- Maestro refreshed the existing Danbooru `-video -touhou` pin without the former query error.
