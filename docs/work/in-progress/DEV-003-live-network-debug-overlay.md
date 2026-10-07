# Show live network activity in a debug overlay

Priority: Low
Affected feature: API coordination and automatic pinned-search/feed refresh

## Problem

While reviewing coordinated requests and automatic refresh, the user cannot
see whether loading is making requests, downloading media, or waiting for
local admission or a server cooldown.

## Expected behavior

A small floating button toggles a live network panel. A Settings switch
enables or disables the button, enabled by default for debug Dev builds.

## Acceptance criteria

- Available only when both debug mode and the Dev flavor are active; other
  builds expose neither the button nor its Settings switch.
- The persisted switch defaults to enabled. Switching it off removes the
  button and panel immediately; switching it on restores the button.
- The panel distinguishes active API transports, active media downloads,
  queued requests, and limiter/cooldown waits, including useful counts,
  elapsed time, host, purpose and active/passive priority where available.
- Counts follow physical request and body lifetimes, including completion,
  cancellation, redirects and failures. Cache hits are not active downloads.
- The panel follows app routes, remains reachable on narrow screens, and
  remains inside the app-lock boundary. It can be closed without leaving the
  current page or blocking ordinary scrolling.
- Display no credentials, query strings, signed URLs, request/response bodies,
  or account identifiers. Observing activity must not start network work or
  alter request priorities, retries, cancellation or refresh scheduling.
- Verify gating, settings persistence, transport lifetimes, wait reasons and
  panel interaction with focused tests and the final combined debug UI check.

## Dependencies and authorization

User explicitly requested this on 2026-10-06 while reviewing
feature/api-request-coordination and feature/conservative-adaptive-refresh.
Depends on the reviewed active-browsing policy correction. Implement in its
own branch/worktree, with reviewed prerequisites replayed once. Publication
and local develop integration remain separately authorized.

Relevant documentation: docs/http_request_coordination.md,
docs/pinned_searches.md, docs/development_workflow.md and
docs/engineering_guidelines.md.

## Claim

Claimed 2026-10-06 by coordinator /root. Implementer /root/dev003, assigned 2026-10-06.
Branch: feature/debug-request-monitor.
Worktree: /home/timber/code/Boorusama/.worktrees/debug-request-monitor.
Original base: local develop 46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd.

Accepted outside preflight: /tmp/boorusama-priority-program-2026-10-05/debug-monitor-final-preflight.md.
Source remains gated on reviewed API and PS031 corrective prerequisites.
Debug Dev builds keep only a bounded sanitized live ledger while the UI is
off, so enabling it can show ongoing transfers without restarting clients.
Off hides the button/panel and stops panel subscriptions/timers; other builds
have no diagnostic hooks or collection. Native player-internal HTTP and native
redirect hops remain explicitly unobservable, with no invented counts.

No local develop integration, remote publication or cleanup is authorized.

## Paused by user (2026-10-06)

User explicitly deprioritized and paused the Debug Monitor. Preserve source/worktree; no further implementation, review, commit or QA until requested. Frozen source and pending review findings are recorded in `/tmp/boorusama-priority-program-2026-10-05/dev003-paused-handoff.md`. Ticket stays in-progress as a paused claim; no integration or completion. Other current tickets continue separately.

## Current queue status (2026-10-07)

The Debug Monitor remains paused and incomplete. Its registered worktree is now based on `be6fe19f3` and retains uncommitted implementation and tests; preserve those files. API coordination and adaptive refresh are already integrated into local `develop`, superseding the original prerequisite delivery gate above. No further Debug Monitor implementation or verification was performed for this queue update, and no product integration is included.
