# #144 — Owner-approved MiteMite notification categories, routing and new-offer badges

> Naming normalization (2026-11-17): Historical paths and symbol references below use current MiteMite names. Recorded commit IDs and verification results are unchanged; consult the original commits for exact historical commands and artifact locations. These reference edits do not requalify earlier evidence.

Decision date: 2026-11-16. **This handoff supersedes the 2026-11-15 rule that every MiteMite notification opens Bookmarks Home**, including contradictory assertions in the older #144 issue body, UX handoffs and tests. The approved requirements are retained below; implementation and verification evidence follow them. Continue on `feature/144-folder-based-collection-sync`; do not merge, open a PR, close #144, or alter protected devices without separate authorization.

## Notification contract

| Trigger | Distinct English title (illustrative, final copy may be refined) | Destination |
| --- | --- | --- |
| Newly received Posts in already subscribed Bookmark Groups | `N new posts` (keep approved singular/plural and `Come take a peek! 👀` body where suitable) | **Bookmarks Home**, not the MiteMite management page |
| Newly offered Bookmark Groups available to subscribe | `New bookmark groups available` | **MiteMite → Subscriptions**, with newly offered Bookmark Group entries identifiable and easy to subscribe |
| Newly introduced Following Topics inside already subscribed Folders | `N new topics` | **Following** root/collection browser, where the separate blue Topic UNSEEN badges remain authoritative |
| Newly offered Following Topic Folders available to subscribe | `New topic folders available` | **MiteMite → Subscriptions**, with newly offered Following Folder entries identifiable and easy to subscribe |
| Newly discovered device, not yet trusted | Retain `Someone new showed up!` / `A new device wants to join the fun! 👋` where appropriate | **MiteMite → Devices**, showing the normal identity/trust controls |

All five categories must have distinguishable notification messages and localized title/body strings. The two new title examples and their descriptions are **not yet exact final copy approval**; retain the existing approved device/Post wording unless the new category demands different grammar. Keep aggregate numeric counts when useful without leaking sender-owned labels, queries, media or protected details in system notifications.

## Native tap and grouping behavior

- Replace the current hard-coded `mitemite:bookmarks` payload in `lib/core/downloads/background/notification.dart` and the boolean `_pendingTap` handling in `mitemite/notifications.dart` with a typed, validated destination intent. Handle both warm taps and cold-launch payloads, retaining the target until the app navigator is ready; no duplicate navigation or dropped intent.
- Route Posts to Bookmarks Home; introduced Topics to Following; both kinds of new offers to `MiteMitePage(section: 'receive')`; discovery to `MiteMitePage(section: 'devices')`. Restore/dismiss transient routes safely using the established navigation system. For offers, focus or otherwise prominently surface relevant newly offered entries for the publisher without automatically subscribing.
- Do not mix different destinations in one Android notification summary whose tap ambiguously opens Bookmarks. Group by compatible destination or choose an equivalently deterministic scheme so every tappable child and summary has an appropriate target. Preserve other app/download notification behavior and avoid duplicate foreground/cold-launch taps.
- Notification taps must not implicitly mark Bookmark Posts Seen, acknowledge Following UNSEEN topics, trust devices, or subscribe to a collection. Keep the single global MiteMite Notifications switch, native permission/channel controls, receipt/outbox retry, privacy rules and signed-publisher verification.

## New offer badge lifecycle (owner approved)

- In **MiteMite → Subscriptions**, show a visible `NEW` badge beside each newly offered direct Bookmark Group and Following Folder. This is separate from the Android delivery/ack receipt, Topic UNSEEN badges and Bookmark Post read state.
- The badges remain visible throughout the **first successful visit** to the Subscriptions view. Acknowledge the offers that belonged to the viewed, successfully loaded snapshot **when the user leaves that view**. Do not clear on notification display/tap, background synchronization, an unsuccessful navigation, or before the page can show the offers. Offers arriving while the view is open should remain new for a later visit rather than being silently acknowledged at exit.
- Persist offer-seen state receiver-locally across restarts. Scope identities by pinned publisher/key, source kind and source ID; handle multiple devices, removals, replay, trust revocation, re-advertisement and overlap without false new markers. Never expose offer names before trust. Preserve initial trust's existing offer baseline policy: merely trusting a device must not flood notifications for its already offered roots.
- If a legacy directly offered Following Topic exists from an older publisher (new direct publication is already Folder-only), preserve compatible subscription/management behavior and avoid falsely labeling that root a Folder; use a generic Following-collection fallback if necessary.

## Detection and aggregation

- At the pre-implementation baseline, `SyncNoticeKind` had `device`, shared `offers` and Bookmark `posts`; `SyncNotificationCopy` and the native bridge are not source-specific. Split offered roots by `SyncCollectionId.kind` (`bookmarks` vs `following_topics`) for separate message selection while retaining durable deduplication and migration of existing pending outbox entries.
- Add a new notification path for truly **new Following Topic definitions** introduced into an **already subscribed** received Folder subtree. The current Following mirror Activity records changed definitions but `SyncLocalEvents.consume` enqueues no Following Topic notices. Detect newly introduced Topic identities, not rename/query edits or Folder definitions; deduplicate overlapping subscriptions and aggregate by update/batch.
- **First subscription does not generate a system-notification flood** for its preexisting Topic contents. Nevertheless, all initially received Topics remain blue UNSEEN under the separately approved Topic-badge contract. Keep Bookmark Post initial subscription suppression unchanged.
- Existing new-Post aggregation, pinned-key checks, persistent receipts/outbox, bounded storage, offline/permission-denied behavior and publisher identity must remain correct.

## Tests and handoff evidence

Add focused tests for five distinct titles/types/destinations; new offers of both source kinds; new Topics after an established Following subscription versus first-subscription baseline; coalescing and overlap; NEW badges appearing, staying through the initial visit and clearing only on successful exit; late-arriving offers; cold/warm tap routing; mixed-category Android group summary; initial navigator unavailability; selection/PopScope safety; revoked/untrusted devices; persisted outbox migrations; unaffected download notifications; and no unintended Seen or subscription/trust mutation. Verify the actual navigation and UI on Android, including small width/large text, then report exact runtime SHA and checks actually run.

Keep this as an independent notification work package. Do not combine with the unrelated Timeline, Thumbnail, Following publication eligibility or anonymous-public-reader fixes merely for convenience.


## Implementation and host verification — 2026-11-16

Implemented independently in `612a8af61`; `e38158561` projects offer identity sets once per management view rather than decoding receipt storage per row. The final combined runtime candidate is `a20cacce1`; its receipt durability follow-up conditionally restores a failed cached offer acknowledgement without changing native tokens or domain cursors (25 focused tests passed).

- The five private notice kinds are `device`, Bookmark `offers`, `posts`, `followingOffers` and `topics`. Titles/bodies are localized. Existing approved Post/device wording is retained; Topic counts use singular/plural copy. Following offers use **New Following collections available** because signed catalog metadata also supports legacy directly published Topics and cannot truthfully label every root a Folder without loading its definition package.
- Typed bounded payloads retain destination, optional offer publisher/source kind and an opaque event digest. A queue preserves blocked/cold-start ingress until the production navigation owner is ready, handles duplicate warm/cold events once, respects PopScope/selection guards and pushes the correct management section only after accepted root navigation. The publisher is focused in Subscriptions. No tap implicitly trusts, subscribes, acknowledges Topic UNSEEN or marks Bookmark Posts Seen.
- Native children and silent summaries group by compatible destination. Displayed legacy events are silently regrouped; the existing Android channel and download callback remain intact. Summary dismissal is native-only and limited to its destination. Version-1 mixed offer outbox entries migrate into source-specific batches, retaining exact identities, batch/generation and permission state.
- Offer NEW is persisted independently of native outbox acknowledgement and freshness. It is scoped by publisher, pinned key, source kind and source ID. Initial trust is a baseline; withdrawal/re-advertisement does not invent another marker. A successfully loaded/pinned offer snapshot is captured after painting; its markers remain throughout the visit. Leaving schedules the durable write after widget lifecycle callbacks. Background/dialogs, failed loads, failed writes and later arrivals do not consume the captured receipt contract. The Activity-failure readiness guard remains in place.
- New Topic intent is committed in the existing Following mirror journal only for newly introduced canonical Topics under already subscribed Folders. Folder/rename/query changes and first subscriptions do not notify. Overlap/replay and removal/reappearance deduplicate against persisted observed identities. Exact intent is copied to the private outbox before its journal cursor is retired, without acknowledging definition badges or altering Topic runtime/read state.

Focused evidence in `.worktrees/_artifacts/144-remaining-2026-11-16/`:

- `notification-boundaries-final.log`: **444 passed**, `fvm flutter test --no-pub --concurrency=6 test/core/backups/mitemite test/core/navigation --reporter expanded`. Includes all four production tap destinations at warm and cold launch, native mixed-category grouping, five distinct private messages, migration/retry, permission/channel refusal, receipt/journal safety and route guards.
- `offer-visit-fixed.log`: **3 passed**, including actual Subscriptions at 320dp/2x, native acknowledgement retaining NEW, late arrivals and successive exits. `offers-projection-final.log` repeats the real Subscriptions test after projection batching: **1 passed**. The pure visit regressions additionally cover dialogs, background, a covered/returned page and an unsuccessful load.
- Focused analysis: **0 errors, 0 warnings, 368 informational findings**. Whole-app final analysis/build/regression are recorded in the delta handoff below.

Complete final regression (`./scripts/run_regression_tests.sh`): **exit 0**, **7,582 application tests + 1,711 package/CLI tests across all 13 suites passed**; **2 existing Go Router skips**. Both shell suites and **76 Python tooling tests passed**. Completed **2026-11-16 13:40:45 UTC** on `a20cacce1c01a39a78126f63fcce7704601429e0`. Runtime/test-input SHA-256 remained unchanged at `1477e85d7e4e5cf6ff04f10782401b72f496a0f8ccd8282ae8ae4b891385614d` (5,295 inputs), matching the final build and analyzer. No emulator, protected device or native UI was operated. MethodChannel/host navigation tests do not establish Android system-UI, cold-process, live shared-folder, live-service or two-device acceptance. See [the delta delivery evidence](144-open-items-2026-11-16.md).
