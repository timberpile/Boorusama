# Combined production rollout continuation

Branch: `maintenance/combined-testing-2026-11-08`.

This implementation checkpoint continues the published final-rollout handoff. It is not final Android acceptance or permission to integrate into develop. The final combined verification, Android evidence, restoration and independent exact-candidate re-review will be appended before delivery.

## Reconciliation

The published task inputs were already ancestors of `6990547ffac395b99161c3b5363bddb7cbf1b6b3`; they were not replayed. The only missing relevant local history was the two approved UI-convention documentation commits on `feature/136-kurumi-ui-design-system`. Merge `3b1ce9ed8` reconciles those without changing the primary checkout or other task worktrees. The primary remains detached at `4b9e8f6f9`.

## Production wiring and decisions

- Pixiv Search, Explore/ranking/following/recommended and account/privacy-scoped Favorites now return native Work cards through the registered capability. Search retains its ordinary scaffold, autocomplete, Always Include Tags and settings-sensitive identity. Ugoira remains a real animation Post.
- The shared mixed viewer presents native Works/Galleries with an image-only Page pager and Work-level metadata/Overview. Normal Bookmark saves the Group; held/overflow actions select a frozen real Page or Group independently. Existing queue, share sheet and portable `.bslink` contracts handle Page media and separate Group/Page links. No implicit Page records or new server Favorite mutations are introduced.
- Stable Page checkpoints load a later source slot before enabling Page actions. Reading transforms are bounded per occurrence. Native metadata registers selection above the outer Work pager, so ordinary details swipes navigate Works and holding text still selects it. Single-Page image drags stay within that Work.
- nhentai is registered with real listing/search, safe configured media hosts, Gallery/Page mapping, source manifests, durable bounded tag shards and the same viewer/library actions. Unknown, partial and explicitly complete-empty tags stay distinct through actual saved snapshots.
- Native timelines reuse the existing viewport continuation controller, pacing and current-route/current-actor guards. There is one shared continuation policy rather than a second native pagination heuristic.
- New reads can attach to a unique currently compatible profile despite a stale hint. Queued actions keep their captured actor and revalidate immediately before committing. Pixiv media preserves its public image Referer through the final redirect boundary while excluding unrelated credentials.
- Disk cache identity remains the ordinary URL/custom key. No epoch salt or cache-clearing migration is added. Cover selection awaits cached sample probes; unused mosaic slots stay empty. Cover visibility facts retain tag coverage, rating and selected-cover status without storing a remote manifest.
- Local deletion removes the complete selected subtree atomically, preserves outside memberships, and records complete Undo. Sync notification happens after releasing the data coordinator, avoiding a sync/deletion lock inversion.
- Import acknowledgement reuses the completed plan and warning revision; source changes coalesce and compute only affected projections off the UI isolate. Large detail/recommendation surfaces build lazily. Apply remains gated by completed current planning and durable preflight.
- Settings > Export and Import > Folder Sync and ordinary Group/Following menus expose signed folder publication, trust, receive/subscriptions, activity and ownership controls. See [the sync handoff](144-folder-sync-production-2026-11-09.md) for protocol, retention, read-only and verified local-journal recovery boundaries.
- Backup writing remains v10. Optional cover facts are backward-readable. No unrelated issue scope, develop merge, PR, release or issue closure is included.

## Review corrections and evidence status

The independent review was explicitly started with `gpt-6.1-sol`, High reasoning and no inherited author context. Its initial review found two P1 and seven P2 defects. Corrections include deletion lock ordering, verified mirrored-import restart recovery, disabled Following definitions, late Page/transform restoration, composed Pixiv search, pending cache-probe ordering, queued native ownership checks, staged SAF identity publication, and Pixiv coverage/direct-read policy enforcement.

Focused evidence is recorded in durable ignored artifacts under `.worktrees/_artifacts/final-rollout-2026-11-08/`. It includes 286 booru-client tests, 47 extended-image package tests, 40 Pixiv policy/production tests, 46 sync/recovery tests, actual guarded-Dio plus Flutter nhentai decoding, and 26 shared/nearby viewer integration tests. These are scoped checks; the complete combined runner and Android/JVM acceptance remain pending at this checkpoint. Interrupted or failing earlier runs remain retained and are not passes.

The current emulator was boot-ready with no Boorusama package installed. Its initial package list, settings and absent external app/QA roots were recorded before installing the audited ordinary-main baseline. A verified immutable earlier local app/cache archive was cloned into the newly installed QA app; the original archive was not modified. Final restoration must return this emulator to its actual initially absent-app state, preserve original package/settings state and remove only verified campaign-owned outputs.

The audited baseline ordinary-main APK matches clean source `4b9e8f6f9` and its installed SHA-256. The credential-free synthetic export is 3,230,031 bytes with 18,000 Bookmarks, 2,000 Following definitions and two public profiles. Its first baseline import completed; a recorded import session showed 8,190,321 microseconds maximum UI delay. A later populated-library preview failed its readiness check while the process remained alive with approximately 1.32 GiB PSS; no crash marker was observed. Automation wall time, sampled memory and Flutter frame/UI-delay measurements are separate evidence. The new candidate comparison is still pending.

Penpot publication is externally unavailable: the actual execute request returned no connected Penpot instance for the user token. The selected family-A Structure/Unified SVG assets remain available. This does not count as publication and does not stop runtime verification. Android baseline Danbooru browsing returned the real HTTP 503 maintenance response; other source acceptance remains separate.
