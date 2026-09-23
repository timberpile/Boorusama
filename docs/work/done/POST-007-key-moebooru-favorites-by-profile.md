# POST-007: Isolate Moebooru favorite users by profile

Priority: High

Affected feature or branch: `feature/bookmark-post-behavior-parity`

Agent/session: Codex `/root`, 2026-09-23

Work branch: `feature/bookmark-post-behavior-parity`

Dependencies: POST-001 unified post model and mixed-booru presentation

## Problem

Moebooru favorite-user state is keyed only by post ID and reads auth implicitly,
so equal post IDs on different profiles can share data or use the global
profile.

## Expected behavior

Favorite-user state and requests are isolated by the scoped profile and post
ID.

## Acceptance criteria

- Different Moebooru profiles with the same post ID have independent state.
- The provider declares and reads its scoped profile dependency explicitly.
- Focused provider and viewer tests pass.

## Completion evidence

- The favorites provider declares the current read-only auth dependency and
  retains that auth for its request.
- A widget regression test confirms equal post IDs in two profile scopes use
  distinct notifier state.
