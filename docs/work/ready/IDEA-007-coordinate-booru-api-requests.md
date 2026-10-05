# Coordinate booru API requests across profiles and clients

Priority: High
Affected feature: Booru API transport, rate limiting, automatic refresh

## Problem

The normal non-image client currently has a 10-request/second limiter, while other clients and feature-local gates can use separate budgets. This permits excessive sustained traffic and cannot enforce a shared quota for profiles and features hitting one site. Server cooldowns also need one coherent user-visible outcome.

## Expected behavior

Interactive searches/actions start ahead of automatic checks and preloads for the same API quota. Both can start small bursts while capacity is available. When a site rate-limits requests, affected work shows the remaining wait; unrelated sites continue. A manual Refresh during cooldown reports the wait and is not queued for later execution.

## Decisions and edge cases

- Use one app-lifetime API/data-request coordinator keyed by normalized actual network origin (lowercase scheme/host and effective port) plus any evidenced independent API quota. Separate profiles and clients using one quota share counters; independent origins/quotas stay separate.
- Include API-equivalent HTML data fetching. Do not route image loading, media bytes, or downloads through these new limits. Inventory nonstandard data paths so they do not silently bypass coordination.
- Classify `interactive`, `userInitiated`, `automatic`, `preload`, and `bulkTransfer` requests; preserve FIFO within each class. Active work has priority. Passive work starts only when no active request for the quota is queued or running; running passive work is not preempted and may be deferred during sustained active use.
- Enforce rolling one-second and one-minute start windows, not fixed spacing or wall-clock bucket resets. Fallback source limits are 5/s and 30/min; uniform 80% buffering yields 4/s and 24/min. Passive starts use at most half the effective rolling minute cap (12/min for fallback), rounded down. Both classes share the total windows.
- Allow centrally declared higher or lower site/engine overrides only when reliable limits justify them; apply the same 80% factor. For a low limit rounding to zero, use a longer equivalent conservative window instead of blocking requests forever. No numeric Settings controls.
- At most four API requests per quota are in flight across both classes, with no reserved class slots. Queued cancellation consumes no capacity; in-flight cancellation releases the slot after transport completion/cancel acknowledgement.
- Honor `Retry-After`. Without it, apply quota-scoped jittered cooldown steps of 30 seconds, 2 minutes, 10 minutes, then 30 minutes; success gradually clears the penalty. Long cooldown returns typed `retryAt` instead of holding queued jobs. Safe reads may retry once; favorites and other mutations never replay automatically. Serialize auth refresh per account without deadlock.

## Acceptance criteria

- Two profiles, multiple features, and separate clients on one quota obey one tested budget; separate origins or evidenced independent quotas do not throttle each other.
- Small active and passive batches start promptly when windows permit; full windows delay starts. Tests cover second/minute boundaries, passive half-cap, priority/fairness, and the shared four-in-flight cap.
- Fake-clock tests cover cancellation, refill, overrides, `Retry-After`, fallback cooldown, safe-read retry, and non-retry of mutations.
- A 429 on one client pauses its quota across clients, exposes `retryAt` to UI and feature schedulers, and leaves unrelated sites plus image/download behavior unchanged. Cancelled work leaks no permits or stale refresh completion.
- API-equivalent HTML and other nonstandard data paths are inventoried and either coordinated or explicitly justified as independent.

## Context and dependencies

Feature schedulers decide due work and run budgets; this coordinator admits actual API requests. The item-31 adaptive-refresh work (PS-031) must not execute automatically until this network-safety prerequisite exists. IDEA-010 fetches use it; video/GIF media downloads do not. Validate numerical overrides for known sites before adding them.

- [Pinned Search and Following Feed architecture](../../pinned_searches.md)
