# Following Topics: interaction consistency and reliability plan

Date: 2026-10-16

Status: implementation specification; D1–D4 resolved on 2026-10-16

Branch: `feature/following-topics-ux-consistency`

Branch base: `develop` at `e8bf883912ecd5a8c4154472a962aa0aabf0c09a`

Reviewed feature: `ae13f2d44c658561df8d9b3095c9d1bb028c2291`

[Local-agent handoff](2026-10-16-following-topics-ux-consistency-handoff.md)

## Purpose and authority

Make Following Topics behave as one feature across searches, artist pages, tag
menus, folders, feeds, settings, and backups. Preserve the existing Pinned
Searches-derived appearance instead of introducing another visual redesign.

This document translates the source-level UX review into implementable changes.
It does not assert that the review's scenarios were reproduced on a device.
Reproduce suspected defects against this branch before changing them; record a
finding as not reproduced rather than forcing a change to match the review.
The feature has since received substantial local verification: do not reuse the
old implementation handoff's assertion that the integrated code is untested.
Its recorded verification is not proof that these new changes will pass.

The user authorized this planning branch and its handoff, not application changes
in this planning session. The local agent should implement the settled items when
execution is requested, and must not merge, create a PR, or publish implementation
changes without the authorization required by the repository workflow.

FTC identifiers below are local checklist identifiers, not allocated work-item or
GitHub issue numbers. Do not reopen the completed original work item 0035 or
rewrite its historical verification report. No additional ticket is a prerequisite.

## Keep these decisions and boundaries

- Keep **Following Topics** as the destination title and **Topic** as the stored
  query concept. Keep Danbooru Saved Searches and site-native following distinct.
- Keep the existing cards, four thumbnail previews, folder hierarchy, compact
  metadata, count/NEW badges, Kurumi toolbars, and approved RSS icon family.
- First-time Follow continues to open a naming/destination dialog. Do not silently
  introduce one-tap following, a remembered automatic destination, or auto-unfollow.
- Each folder can explicitly enable a feed; feed mode defaults off. Retention is
  configurable per folder, default 1000. Retain existing valid custom limits.
- Equal queries in separate folders remain independent Topic records. Do not
  normalize them into shared records or change query identity semantics here.
- Opening a Topic uses ordinary search and its pagination. Opening a feed marks
  its contained Topics read under the already agreed first-version policy.
- Keep the existing adaptive Topic scheduler, quotas, cooldowns, request ownership,
  network/power guards, and safe verified delta/fallback behavior. No second
  folder scheduler, background-OS worker, or new API-capability expansion.
- Keep Hive. No inactivity eviction or automatic global cache purge. A cache
  retains valid entries when its feed is disabled, absent explicit clearing.
- Preserve profile/account origins, legacy persisted names and IDs, backup wire
  compatibility, and all previously disabled update preferences.
- No broad feed-pagination rewrite, visual mockup rebuild, unrelated component
  migration, or repository-wide cleanup. Performance changes must be measured.

## Product decision register

D1–D4 are **resolved as of 2026-10-16**. The user approved D1 and D2, delegated
D3 to the option consistent with a future context-specific profile model, and
changed D4 to automatic continuation with a small warning. The selected D3
implementation is route-scoped ownership. These are requirements, not pending
recommendations; do not ask the user to decide them again.

| ID | Decision | Implementation boundary | Applies to |
| --- | --- | --- | --- |
| D1 | Allow valid, normally searchable manual-only Topics when automatic tracking is unsupported. | Save, organize, edit, and open the normal search. Explain tracking unavailability and do not issue automatic or feed requests the engine/query cannot support. | FTC-08 |
| D2 | Bulk Topic actions on selected folders include descendant Topics. | Deduplicate by Topic ID across selected parents, children, and individual Topics; independent copies of the same query remain separate. Show the affected count. Unfollow still needs explicit scope confirmation and never implicitly deletes the folder tree. | FTC-14 |
| D3 | Use the Topic owner's profile only within its search and dependent operations; do not switch the global active profile merely to open a Topic. | Chosen under the user's delegation because it fits profiles having effect only where endpoint, auth, query semantics, or actions differ. Preserve the correct account for all child operations; the wider profile overhaul is out of scope. | FTC-01, FTC-20 |
| D4 | Continue automatically with available feed sources and show only a small non-blocking warning when some are unavailable. | No Continue prompt or required Retry action. Keep cached/successful posts, isolate source failures, use bounded coordinated recovery, and merge recovered results without duplicates or disruptive scroll jumps. | FTC-09, FTC-10, FTC-13 |

D4 supersedes the earlier recommendation for opt-in partial continuation. The
warning must remain while coverage is incomplete and may expose optional details,
but must not become a blocking dialog, repeated error toast, or action required
to keep browsing. A source failure is not evidence that its history is exhausted.

The number of confirmation taps for first-time Follow, the RSS family, the
Following Topics name, 1000-post default, independent Topic copies, and the
read-on-feed-open policy are not reopened by this pass.

## Source map and confidence

The following paths are evidence/starting points, not a mandate to retain their
current internal structure. Method names are more durable than old line numbers.
At branch creation, the base was the direct child of the reviewed feature commit;
that child concerned bookmark removal feedback, not a replacement Topics feature.

| Ref | Starting points | Review evidence to verify |
| --- | --- | --- |
| S1 | [Follow controls](../../lib/core/search/following_topics/src/widgets/topic_follow_control.dart), [search actions](../../lib/core/search/search/src/widgets/search_page_scaffold.dart), [tag menu](../../lib/core/tags/tag/src/widgets/general_tag_context_menu.dart) | Shared artist/tag creation flow differs from search-result management; search selects a first matching Topic. |
| S2 | [Following notifier](../../lib/core/search/following_topics/src/providers/following_topics_notifier.dart), [Topic model](../../lib/core/search/following_topics/src/types/following_topic.dart), [selectors](../../lib/core/search/following_topics/src/providers/following_topic_selectors.dart) | Query matching, independent copies, persistence/refresh coupling, and custom-name normalization. |
| S3 | [Follow dialog](../../lib/core/search/following_topics/src/widgets/follow_topic_dialog.dart), [folder picker](../../lib/core/search/following_topics/src/widgets/follow_topic_folder_picker.dart), [folder editors](../../lib/core/search/following_topics/src/widgets/search_folder_dialog.dart), [folder navigation](../../lib/core/groups/folder_navigation.dart) | Name-only versus settings-capable folder creation, root-only creation in the Follow picker, leaf-only location labels. |
| S4 | [Collection page](../../lib/core/search/following_topics/src/pages/following_topics_page.dart), [Topic card](../../lib/core/search/following_topics/src/widgets/following_topic_card.dart), [folder card](../../lib/core/search/following_topics/src/widgets/following_topic_folder_card.dart) | Selection, sorting, action visibility, error handling, and current-folder settings discoverability. |
| S5 | [Feed page](../../lib/core/search/following_topics/src/pages/topic_feeds_page.dart), [history session](../../lib/core/search/following_topics/src/services/feed_history_session.dart) | Duplicate routes, material-change invalidation, generic empty state, and source-page failures. |
| S6 | [Coordinator](../../lib/core/search/following_topics/src/providers/search_refresh_coordinator.dart), [Topic Info](../../lib/core/search/following_topics/src/widgets/following_topic_info_dialog.dart), [Feed Info](../../lib/core/search/following_topics/src/widgets/topic_feed_info_dialog.dart), [update settings](../../lib/core/settings/src/pages/topic_updates_page.dart) | Route-dependent scope flags in Info versus scheduler, page-active boolean, and redundant controls. |
| S7 | [Hive repository](../../lib/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart), [storage settings](../../lib/core/settings/src/pages/data_and_storage_page.dart), [cache notifier](../../lib/core/cache/cache_notifier.dart) | Different single/all cache clearing semantics and avoidable full-cache reads for metadata. |
| S8 | [Backup registry](../../lib/core/backups/sources/providers.dart), [legacy feed source](../../lib/core/backups/sources/topic_feeds_source.dart), [Topics source](../../lib/core/backups/sources/following_topics_source.dart) | Modern folder feeds export with Topics while an equally current-looking legacy feed source can show zero. |
| S9 | [Search route helper](../../lib/core/search/search/src/routes/route_utils.dart), [search routes](../../lib/core/search/search/src/routes/routes.dart) | Search already accepts a scoped BooruConfig; Topic opening changes the global profile first. |
| S10 | [English](../../packages/i18n/translations/en-US.json), [German](../../packages/i18n/translations/de-DE.json), [current subsystem documentation](../following_topics.md) | Terminology, fallback localization, existing accepted behavior, and compatibility constraints. |
| S11 | [Existing tests](../../test/core/search/following_topics), [Hive benchmark](../../benchmark/feed_cache_profile_uuid_performance_test.dart) | Interaction tests can encode the wrong contract; benchmark fixtures have four tags and one feed. |

## Shared interaction contract

### Follow state and target resolution

| Situation | Control | Expected action |
| --- | --- | --- |
| No match | Follow | Open the first-time dialog; no state mutation before confirmation. |
| One match | Following with disclosure | Open management for that exact Topic. |
| Multiple matches, no exact context | Following with disclosure | Choose a Topic by name, full folder path, and profile where needed. |
| Opened from a specific matching Topic | Following with disclosure | Prefer its ID, after validating the current profile/query and continued existence. |
| Local save in progress | Stable-size saving state | Prevent duplicate submission; show progress accessibly. |
| State still loading or failed | Distinct loading/error availability | Do not infer not-followed from an absent AsyncValue. |
| Existing Topic with tracking unavailable | Following management remains reachable | Do not block local management merely because refresh is unsupported. |

Management offers **Open topic**, **Edit topic**, **Move**, **Add to another
folder**, and **Unfollow**. The last two must be distinguishable: adding creates
an independent copy; moving preserves the selected record's identity. Preserve
same-destination duplicate protection and make intentional copies explicit.
Do not clear a custom name unless the user explicitly clears the field.

### Vocabulary and control semantics

| Context | Wording/meaning |
| --- | --- |
| Destination | Following Topics |
| Stored query | Topic; use query for its actual expression |
| Creation versus management | Follow / Following |
| Definition form | Edit topic |
| Diagnostics | Topic details |
| Folder editor | Folder settings |
| Combined browsing | Open feed |
| Feed-to-folder navigation | Topics |
| Feed configuration | Feed settings, using the same folder editor |
| Topic removal | Unfollow; scope always identifies the affected record(s) |
| Local result retention | Maximum cached posts, not maximum browsable posts |

Use sentence case for actions and preserve established destination naming.
Use **No folder** for the unfiled destination and **New folder...** as an action,
not bracketed pseudo-values. Topic folder breadcrumbs should consistently use the
collection root label, without changing unrelated collection terminology globally.

## Detailed implementation checklist

Priority: P1 means correctness/trust first; P2 means core UX consistency; P3 means
measured improvement. Check a task only after its acceptance cases are verified.
D1–D4 are resolved; their subsections are part of the implementation scope.

### FTC-01 — Resolve exact Topic targets (P1; S1, S2)

- [x] Replace first-match behavior with one selector returning all visible matching
  Topics for a profile and normalized query. Preserve existing normalization;
  do not reorder or reinterpret quoted/raw expressions as part of this fix.
- [x] Carry optional originating Topic ID through search navigation. Validate it
  after edits/profile/query changes; a stale ID must not select unrelated content.
- [x] For ambiguous matches show a location-aware chooser. Counts of copies are
  location metadata, not unread badges. Resolve missing/deleted records safely.

**Acceptance:** two independent copies remain distinguishable from artist, tag,
search, and Topic-originated search entry points. No operation silently chooses
an iteration-order winner. Changing search input invalidates the old target.

### FTC-02 — One behavioral Follow/Following entry point (P1; S1–S3)

- [x] Route artist headers, inline artist controls, tag menus, and search-result
  actions through one controller/entry service using FTC-01. Sharing only a
  visual button is insufficient.
- [x] Following manages existing records; it never falls through to unprefilled
  root creation. Add another copy only through the explicit action.
- [x] Prefill name and location for edits, provide scoped Unfollow, and retain
  independent record IDs, unread state, and update preferences.
- [x] Preserve a typed query structure where valid, including new-folder paths.
  Capture query/profile/structure consistently before asynchronous work.

**Acceptance:** confirm an unchanged custom-named nested Topic from every entry
point; record count, ID, name, folder, and preferences are unchanged. Cancel any
step and observe no mutations. Explicit Add to another folder creates only one
independent copy without moving the original.

### FTC-03 — Transactional local saves and separate preview refresh (P1; S1–S3)

- [x] Persist definition plus placement atomically, or with tested compensation
  under the existing serialized mutation boundary. Include new-folder creation
  when it belongs to the same confirmed action. Do not chain unrelated rename
  and move calls that can leave a partial user edit.
- [x] Keep dialogs open with entered values and inline validation/storage errors
  until the local operation succeeds. Disable double-submit while saving.
- [x] After durable success, close the editor and display Following immediately.
  Schedule the preview through the existing request coordinator independently.
  Every started asynchronous operation must have an owner and error handling.
- [x] Report saved-but-preview-failed separately from save-failed, including
  deferred/rate-limited states. Do not tie local editing latency to the website.
- [x] Scope feedback and busy state to the captured operation/query/profile;
  discard stale feedback on changed searches or disposed screens. Do not clear
  a successful Topic merely because its preview failed.

**Acceptance:** offline, rate-limited, slow, and failed refresh cases all retain a
successfully saved Topic; forced storage or move failures retain inputs and the
previous state. Concurrent duplicate submits do not create extra records.

### FTC-04 — Standard Follow controls and icon semantics (P2; S1, S4, S10)

- [x] Use one Follow pill family across artist headers, inline controls, and
  result headers. Density variations may change spacing, not behavioral meaning.
- [x] Use primary styling for Follow and tonal styling plus a clear disclosure
  affordance for Following. Preserve the approved RSS identity where an icon is
  present; use a check/disclosure consistently to indicate state/action, not a
  competing set of icons or unexplained fill-only state.
- [x] Remove the numeric copy-count badge from the RSS icon. Leave unread
  TopicNewPostsBadge semantics intact; put copy locations in management.
- [x] Maintain a stable loading footprint and existing minimum 48px touch height;
  use theme tokens and component sizes rather than new hardcoded styling.
- [x] Menus should use action labels appropriate to a menu, not embed another
  full-size pill. Accessibility must announce target and management action, not
  a fictitious toggle when tapping opens a menu.

**Acceptance:** consistent states in dark/light themes, 240/320px constrained
headers, 2x text, focus/keyboard operation, and screen-reader announcements.
Full action labels remain available even when the visual label must truncate.

### FTC-05 — One folder editor and full destination context (P2; S3)

- [x] Unify name-only and settings-capable creation paths around one editor result
  with name, parentId, feedEnabled, and maxPosts. Reuse the existing tree picker.
- [x] Permit nested creation from Follow and Move, not just collection browsing.
  Provide feed settings at creation everywhere; default feed mode off/1000.
- [x] Show full chosen folder paths, with accessible full text for truncation.
  Use No folder and New folder... instead of [Home]/[New].
- [x] Validate sibling name collisions before dismissing. Handle destinations
  deleted concurrently and failures while creating a folder and Topic together.

**Acceptance:** equivalent folders can be created from each entry point with the
same settings. Two identically named leaf folders remain distinguishable. Cancel
and failed save do not leave unintended empty folders or move existing Topics.

### FTC-06 — Discoverable folder/feed settings (P2; S4, S5)

- [x] Add Folder settings to the opened folder's overflow menu. Keep existing
  enabled-folder feed shortcuts on the card and AppBar, hidden during selection.
- [x] Replace the feed's ambiguous Edit action with Topics navigation and an
  explicit Feed settings action using FTC-05. Do not restore a separate editor.
- [x] Explain retention as cached metadata entries, not a pagination stop or an
  offline image guarantee. Display useful current occupancy when available.
- [x] Preserve valid custom limits when opening/saving settings. Reducing a limit
  trims only excess entries; increasing it does not imply backfill is complete.
  Do not start a full rebuild or clear valid cache on either change.
- [x] Explain that disabling feed mode retains its existing cache and does not
  change contained Topics' own Auto-update preferences.

**Acceptance:** change retention from inside a feed without navigating back to
its parent card; settings survive rename, move, disable/re-enable, and restart.
No unrequested cache rebuild or periodic-update switch occurs.

### FTC-07 — One effective automatic-update state (P1; S6)

- [x] Derive effective eligibility and reasons from Topic identity/ownership,
  capability, global settings, per-topic override, environment, and cooldown.
  Both Info entry points consume the same result as scheduler-facing logic.
- [x] Stop passing modern folder Topics through the legacy feedSource policy
  merely because their Info dialog was opened from a feed.
- [x] Expose one global Automatic topic updates setting for the unified feature;
  preserve the effective off state if either old modern-topic gate was off.
  Keep legacy decoding/ownership handling compatible; do not reset overrides.
- [x] Put individual Auto-update in the Topic editor or explicit quick action;
  details can show diagnostics but must not be its only discovery path.
- [x] Show compact Updates paused/tracking-unavailable metadata only where useful.
  Do not clutter every card with unchanged enabled-state boilerplate.

**Acceptance:** the same Topic opened directly or through a feed displays the
same schedule/reason for every combination of legacy flags, overrides, network,
power, and unsupported queries. Migration never silently enables old preferences.

### FTC-08 — Separate local Topic capability from tracking (P2; D1; S1, S6)

- [x] Give disabled/unavailable actions the same explanation across all entry
  points. Engine-level support alone must not claim every query is trackable.
- [x] Keep existing Topic management and normal search reachable when refresh
  support disappears. Never call an unsupported refresh transport accidentally.
- [x] Allow valid searchable manual-only Topics from every Follow entry point,
  including bulk creation. Saving must not require a supported refresh adapter.
  Show tracking unavailability explicitly; normal opening still uses ordinary
  search. Update editor validation without weakening actual query validation.
- [x] Evaluate capabilities per operation: do not issue automatic or feed fetches
  that the engine/query cannot support. Explain excluded manual-only sources in
  feed status, and let supported sources continue under D4. Do not reinterpret
  unsupported tracking as zero matching posts or a successful check.
- [x] Preserve existing user Auto-update preferences; capability unavailability
  is an effective state, not permission to overwrite stored overrides. A later
  supported configuration must not silently enable a previously disabled Topic.

**Acceptance:** a valid searchable query can be followed, organized, edited, and
opened without tracking support. No unsupported transport or fake empty-success
result is issued, and existing disabled preferences remain intact.

### FTC-09 — Accurate feed initialization and freshness presentation (P2; S5, S6)

- [x] Build presentation from feed-specific initializedSourceIds, pending work,
  errors, cache presence, settings, and source availability. A Topic's tracking
  baseline is not evidence it initialized this particular feed.
- [x] Distinguish no Topics, loading N of M Topics, paused/waiting, partial
  failures, completed zero matches, unavailable profile, and cleared cache.
- [x] Show cached results while refreshing or paused. Continue healthy sources
  automatically when others fail; use D4's small non-blocking warning rather
  than a mandatory Continue/Retry action or a large permanent error panel.
  Follow a topic or Open update settings can remain useful for genuinely empty
  or user-paused states; source-failure recovery must not require them.
- [x] Share the same summary with Feed Info; identify initialization versus
  periodic updates. Do not promise a paused queue is making progress.
- [x] Use compact status UI. If all sources are unavailable, retain cached posts
  and show an honest unavailable state, not endless loading or a false no-posts
  result. Do not mislabel intentionally manual-only Topics as transient failures.

**Acceptance:** old-baseline/new-feed, empty, offline, battery-saver, rate-limit,
partial-success, missing-profile, and resumed states all have truthful text.
Partial availability never requires a user action to continue healthy sources;
successful cached results remain visible.

### FTC-10 — Consistent Refresh and outcome feedback (P2; S4–S6)

- [x] Wire feed pull-to-refresh and menu refresh into the same existing guarded
  operation. Honor batch ownership, limits, and cancellation; no parallel fetcher.
- [x] Report failures returned as SearchRefreshOutcome as well as exceptions;
  distinguish partial success and deferred work from total failure. For partial
  feed-source unavailability, aggregate feedback into D4's small warning instead
  of one toast per source or a blocking confirmation.
- [x] Route success, errors, undo where supported, and rate-limit messaging through
  the application's established feedback components. Do not mix unrelated
  SnackBar and toast conventions in otherwise identical operations.
- [x] Preserve scroll while refreshing. For genuinely additive results use the
  existing show-updates affordance rather than unrequested jumps to the top.

**Acceptance:** menu and gesture behave identically; repeated refresh does not
multiply requests; successful cached content survives failed refreshes.

### FTC-11 — Folder/feed routes and initialization ownership (P1; S4–S6)

- [x] Navigate between Topics and Feed views using the same folder identity;
  reuse an existing appropriate folder route instead of pushing duplicate stacks.
  Preserve separate scroll state for each view.
- [x] Replace the shared page-active boolean with minimal route-aware ownership
  (for example, disposable visible-consumer registrations). A covered/disposed
  page must not cancel or keep alive the wrong feed's initialization interest.
- [x] Route changes, overlays, backgrounding, cancellation, and returning to an
  earlier feed must reestablish the correct active interest. Do not add a scheduler.
- [x] Guard repeated Open Feed taps, handle deleted/disabled folders gracefully,
  and ensure one navigation result per action.

**Acceptance:** Folder A -> Feed A -> Topics A -> Feed B -> Back cannot duplicate
or strand screens or stop Feed A incorrectly. Double taps push one feed. Normal
periodic Topic updates remain independent of route visibility.

### FTC-12 — Invalidate stale history on material changes (P1; S5)

- [x] Fingerprint source definitions using Topic ID, runtime revision, profile,
  and query, plus relevant configuration revisions. Compare actual semantics,
  not just sourceIds or the equality of cached post arrays.
- [x] On query/profile/source removal or invalidated ownership, dispose/cancel
  stale work, rebuild history, and reject old responses. Never keep executing an
  immutable cursor's old source definition because its Topic ID was unchanged.
- [x] Separate material changes from additive refreshes. Only additive updates
  may wait behind Show updated posts. Keep unaffected valid cache/provenance.
- [x] Use existing request/session tokens and revisions where possible, not a
  generalized replacement state framework.

**Acceptance:** edit a query, change a profile endpoint, remove a source, or delete
a profile during history requests. Old results cannot reappear; unaffected posts
remain; late completions cannot mutate the replacement session.

### FTC-13 — Automatic partial-source continuation and recovery (P1/P2; D4; S5)

- [x] Isolate failures per source. Keep cached posts and successful cursor data
  visible, and continue fetching available sources automatically. Do not require
  a Continue/Retry tap or fail the entire history merge for one unavailable site.
- [x] Show a small warning such as "Some topics are unavailable" while coverage
  is incomplete. Keep it stable and accessible without repeated announcements,
  repeated toasts, or a blocking modal. Optional details must remain optional.
- [x] Preserve the failed source's cursor/checkpoint and pending gap. Failure
  must not mark it exhausted or advance past unfetched data. Only actual terminal
  results can exhaust a source; reject stale results using FTC-12's ownership.
- [x] Retry through the existing coordinator, quotas, cooldowns, and network/power
  guards at bounded eligible opportunities. Do not add a scheduler or a tight
  retry loop, and do not reattempt a failing source for every healthy-source row.
  Available sources must not wait for a failed source's backoff to finish.
- [x] Merge recovered posts automatically by upload order and origin-aware ID,
  preserving the visible scroll anchor and deduplicating overlaps. Keep the
  warning until the session's relevant gaps are covered, not merely until one
  retry succeeds. No action is required to resume a recovered source.
- [x] If all sources are temporarily unavailable, retain the cache and stop
  active loading honestly until an eligible recovery trigger. Distinguish this
  from an empty result or exhausted history. Keep this a focused failure/recovery
  change, not a general pagination rewrite.

**Acceptance:** one unavailable source does not blank or block healthy results;
no Continue/Retry action is required. Test one, several, and all source failures,
rate limits, later automatic recovery, preserved gap cursors, source edits during
recovery, scroll stability, and same-ID/different-origin posts. Incomplete coverage
remains visible via the small warning until repaired.

### FTC-14 — Reliable selection and explicit bulk scope (P2; D2; S4)

- [x] Return mutation success/failure explicitly. A failed Move must retain
  selection; clear it only after successful completion or explicit cancellation.
- [x] Back/Escape exits selection before navigating. Reuse existing app selection
  components for tap, range, and accessible keyboard interactions where possible.
  Avoid another independent gesture implementation.
- [x] Add Refresh selected and Mark read where absent; surface Unfollow selected
  only with exact scope and established confirmation/undo policy.
- [x] Snapshot selected IDs before asynchronous operations and revalidate changes;
  include hidden/deleted items safely and prevent action sets changing mid-save.
- [x] Apply bulk Topic actions to the union of directly selected Topic IDs and
  all descendants of selected folders. Refresh, Mark read, and Auto-update use
  this same resolver. Deduplicate by Topic ID, not query; independent copies
  remain separate targets. Show selected containers and affected Topics when
  counts differ, and explain capability-based skips without blocking other work.
- [x] Unfollow selected uses that same descendant scope with an explicit preview
  and confirmation. It removes the confirmed Topic records, not the containing
  folder tree. Folder Move remains a structural move; never flatten descendants
  or introduce a persistent inherited policy through a bulk action.

**Acceptance:** failed moves, nested selections, changed lists, cancellation,
Back/Escape, and mixed folder/Topic selections keep predictable state and exact
scope. Per-topic policy remains individual, not inherited from a folder.

### FTC-15 — Consistent folder-aware sorting (P2; S4)

- [x] Sort folders using descendant summaries for Updates first and last-post
  ordering, just as their visible cards summarize descendants. Name ordering
  applies to both sections. Keep folders and Topics in separate sections.
- [x] Define stable ties using manual positions and IDs; missing timestamps or
  baselines must have deterministic fallback order, not random movement.
- [x] Preserve manual placement data. Sorted views must not rewrite positions,
  and manual Move up/down controls appear only in manual order.
- [x] Derive summaries once per relevant state change rather than repeatedly
  scanning all Topics for each comparator.

**Acceptance:** folder summaries visibly agree with selected ordering; changing
the sort and returning to Manual restores the original arrangement.

### FTC-16 — Empty-state creation and local discovery (P2; S3, S4)

- [x] Add a visible Follow a topic action to an empty collection/folder, with the
  same editor, profile selection, and current destination as other entry points.
  Keep multi-line bulk following as a secondary option, not the only creation UI.
- [x] Add local name/query filtering and an optional profile filter. Search the
  current folder subtree (root searches all Topics); show full paths for results.
  Use no remote requests and never change the global profile just to filter.
- [x] Restore the ordinary hierarchy when clearing the filter. Disable filter
  changes while selecting unless existing app components explicitly preserve
  and communicate offscreen selection; never silently hide selected targets.
- [x] Use No matching topics for filtered emptiness, not No topics yet. Label
  recursive Topic counts as Topics rather than generic visible-row items.

**Acceptance:** nested results are discoverable, filter matches include custom
names and raw queries, clearing restores navigation/scroll, and empty-state
following inserts into the intended folder without network-dependent saving.

### FTC-17 — Vocabulary, icons, menus, and localization audit (P2; S1–S4, S10)

- [x] Apply the shared vocabulary contract across active screens, feedback,
  dialogs, settings, menus, diagnostics, accessibility, and export presentation.
- [x] Preserve approved RSS navigation/feed identity; use consistent icon sizes,
  tooltip meaning, focus states, and contextual hiding during selection. Do not
  perform another domain/file rename for already-correct internal Topic names.
- [x] Reuse KurumiAnchor/KurumiPopupMenuItem/KurumiContextMenu and comparable
  application editors where appropriate. Do not mix menu row styles or migrate
  unrelated screens just to standardize this feature.
- [x] Review English and German in context, including Following state wording,
  optional names, the title Einem Thema folgen, No folder, and plural/count messages.
  Validate all locale fallbacks after changes; no hardcoded user-facing strings.
- [x] Keep external Saved Searches/native following names, old routes, backup
  identifiers, and persisted compatibility constants untouched.

**Acceptance:** one label has one action; an editor is not called Info; Edit does
not merely open a browser. Existing compatibility data still parses. Screen-reader
labels describe behavior and source context, not only duplicate visible text.

### FTC-18 — Explicit cache clearing with no immediate resurrection (P1/P2; S7)

- [x] Align single-feed and all-feed clearing: remove modern cache materialization
  while preserving folder definitions, enabled state, limits, Topics, and overrides.
  A deliberate subsequent Open Feed recreates the cache; background Topic refresh
  must not immediately recreate it solely because stale metadata remains.
- [x] Cancel/revoke old cache writers or use the existing minimal invalidation
  mechanism so late refresh completions cannot resurrect cleared snapshots.
  This does not require cancelling every unrelated Topic update.
- [x] Clearing from a live feed ends that cached session; show Cache cleared with
  an explicit Reload action instead of an empty view promising automatic progress.
- [x] Handle batch-clear errors and partial completion truthfully. Keep estimated
  serialized size labeled as estimated, excluding claims of guaranteed disk-space
  reclamation or offline image availability.
- [x] Retain inactive/disabled feed caches until manual clearing. Do not smuggle
  in TTL, global eviction, or an image-cache generation redesign.

**Acceptance:** clear during active refresh, clear all with one failure, restart,
and next explicit opening obey the same documented lifetime. Topic definitions,
NEW state, preferences, and unrelated feed results survive.

### FTC-19 — Unified export presentation, legacy import preserved (P2; S8)

- [x] Present Topics as the current source, explaining that it includes folders
  and feed settings. Hide an empty legacy Topic Feeds export option, or label it
  explicitly legacy when legacy records genuinely exist.
- [x] Separate UI discoverability from registry/decoder compatibility. Old source
  IDs and archives must still import even when no legacy export tile is shown.
- [x] Keep custom export selection, partial imports, replace/merge/copy review,
  independent duplicate identities, overrides, and rollback behavior intact.
- [x] Ensure summaries report the data actually exported; do not imply snapshot
  caches or image files are included when only definitions/settings are exported.

**Acceptance:** modern feeds no longer appear missing because a separate export
category says zero. Legacy files still restore correctly and no visible Topic
is lost through an old-format replace operation.

### FTC-20 — Route-scoped Topic search ownership (P2; D3; S4, S9)

- [x] Pass the Topic owner's explicit BooruConfig and originating Topic ID to
  the search route helper. Do not update the global active profile merely to
  open a Topic; use the existing route-scoped configuration infrastructure.
- [x] Resolve all search actions, auth, suggestions, Follow management, viewer
  navigation, and downloads from the scoped owner; do not fix only fetching.
- [x] Returning leaves the previous global browse profile unchanged. A deliberate
  user profile switch inside search follows established app behavior.
- [x] Keep organization and local discovery profile-independent; apply profiles
  only where request endpoint, account/auth, query behavior, rendering, or actions
  require them. This choice aligns with the user's planned future profile model
  but does not authorize implementing that broader overhaul in this task.

**Acceptance:** a Topic owned by profile B opens while globally browsing A with
correct B auth/actions throughout dependent routes. Back and unrelated tabs stay
on A unless the user deliberately switched them. Same-site/different-account
cases keep the intended credentials; no fallback chooses the wrong account.

### FTC-21 — Measured collection-scale performance (P3; S4, S7, S11)

- [x] Avoid decoding every full feed cache for membership/source-ID queries.
  Separate metadata reads from snapshot materialization inside current storage,
  and cache/invalidate parsed state only where justified by measured hot paths.
- [x] Replace eager wrapper-list construction with appropriate lazy list/sliver
  builders; narrow reactive subscriptions and preserve stable keys/scroll state.
- [x] Benchmark about 50 tags/post, real-shaped codec fields and provenance,
  1000/2000 snapshots, several nested/independent feed caches, and refresh bursts.
  Compare before/after on the same device/build with repeated measurements.
- [x] Include Android profile/release measurements when available. Report JIT/Linux
  diagnostics separately. Do not invent a latency budget or treat four-tag
  synthetic figures as a production capacity guarantee.

**Acceptance:** measurable work reduction without stale cache metadata, ordering,
identity, or rollback regressions. No SQLite migration or unrelated optimization.

### FTC-22 — Contract tests, documentation, and final qualification (P1/P2; all)

- [x] Replace tests that merely enshrine the inconsistent flow, such as expecting
  an already-followed tag to open an unqualified creation dialog. Test real
  mutations/outcomes from every entry point, not only labels and cancellation.
- [x] Add the shared acceptance matrix below, failure injection, controlled-clock
  scheduling, and late-completion tests. Do not use fixed sleeps as correctness.
- [x] Update docs/following_topics.md and this checklist with actual decisions,
  implemented behavior, reproduction results, and verification limits.
- [x] Format/analyze affected scope, generate changed i18n inputs, run affected
  consumers, and run the complete repository regression gate on the final runtime
  candidate. Report device and upgrade coverage separately.

**Acceptance:** every task and the resolved D1–D4 contracts are verified. Report
any genuine implementation limitation explicitly rather than treating a resolved
decision as pending. Final report names the checked commit/state and actual
commands/results, including failures/skips/limits.

## Implementation record (2026-10-16)

FTC-01 through FTC-22 and decisions D1 through D4 are implemented on
`feature/following-topics-ux-consistency`. The implementation uses exact
originating Topic UUIDs and route-scoped owner profiles, one Follow/Following
controller, atomic definition/placement writes, shared folder settings,
descendant-aware bulk operations, route-owned feed initialization, source
definition fingerprints, automatic partial-source continuation, and explicit
modern-cache clearing. Current backup presentation hides an empty legacy feed
source without removing its registry/decoder compatibility.

Host/JIT measurement uses four independent/nested-shaped caches, ten sources per
feed, 50 tags per post, per-post provenance, 1000/2000 snapshots per feed, and a
50-post refresh burst. Repeated medians were 39,863/71,674 microseconds for full
in-memory decode and 22/27 microseconds for metadata-only decode. Android
profile/release and live-site measurements were unavailable and are intentionally
not inferred from the host diagnostic. Final formatting, analysis, consumer
tests, full repository regression, and the checked commit are recorded in the
task report after the final candidate is committed.

## Dependency and delivery order

| Phase | Tasks | Why |
| --- | --- | --- |
| 0. Establish current behavior | FTC-22 baseline scenarios; read resolved D1–D4 | Reproduce findings without undoing completed feature work. |
| 1. Targeting and saves | FTC-01, FTC-02, FTC-03, then FTC-04 | No cosmetic redesign over inconsistent mutation behavior. |
| 2. Status and material correctness | FTC-07, FTC-11, FTC-12, FTC-18 | Fix misleading eligibility, stale requests, navigation ownership, and clear races. |
| 3. Cohesive browsing/editing | FTC-05, FTC-06, FTC-09, FTC-10, FTC-17 | Shared editor/actions plus truthful progress and feedback. |
| 4. Collection-scale interaction | FTC-14, FTC-15, FTC-16, FTC-19 | Explicit selection scope, ordering, discovery, and exports. |
| 5. Resolved capability and context behavior | FTC-08, recursive FTC-14, FTC-20, automatic partial FTC-13 | Implement D1–D4; no further product answers are needed. Pull FTC-20 forward with targeting, and FTC-13 with lifecycle work when practical. |
| 6. Measurement and qualification | FTC-21, final FTC-22 | Optimize demonstrated hot paths and qualify the resulting candidate. |

Batch related mechanical changes. Phase boundaries do not require user approval
unless a product decision or genuine scope deviation is encountered. No mandatory
per-task commit, extra plan, PR, or reviewer-agent workflow is implied.

## Acceptance matrix

| Case | Required result | Main tasks |
| --- | --- | --- |
| A01: existing named nested Topic, all Follow entry points | Unchanged ID/name/path; no duplicate on confirming unchanged data | 01–04 |
| A02: same query in two folders; originating Topic search | Exact copy selected or explicit chooser; independent states preserved | 01, 02 |
| A03: slow/offline/rate-limited preview after save | Local success independent of preview; truthful scoped feedback | 03, 10 |
| A04: save or placement failure; destination removed concurrently | Inputs and prior data retained; no orphan creation or partial edit | 03, 05 |
| A05: change query/profile while follow/refresh is pending | No stale button/error/target updates in the replacement context | 01, 03 |
| A06: create nested feed-enabled folder from Follow, Move, browser | Equivalent settings, full path, no accidental root-only behavior | 05, 06 |
| A07: same Topic Info directly and via Feed Info | Identical effective scheduling and disabled reason | 07 |
| A08: legacy global flags and individual disabled override | No update preference silently enabled by UI consolidation | 07, 19 |
| A09: unsupported-but-searchable query | Manual-only Topic saves, edits, and opens; no unsupported transport, false zero results, or lost overrides | 08 |
| A10: old baseline, newly opened feed, partial initialization | Feed-specific progress, successful cache retained | 09 |
| A11: empty/offline/paused/missing profile/no matches | Truthful distinct states; available sources continue with a small warning, no required action | 09, 10, 13 |
| A12: nested feed/folder routes and rapid Open Feed taps | One intended route, preserved scroll, correct active ownership | 11 |
| A13: source query/profile/removal during history request | Stale session/results rejected; unaffected posts remain | 12 |
| A14: additive refresh while reading older posts | No involuntary jump; show-updates action remains available | 10, 12 |
| A15: one/several/all unavailable sources and automatic recovery | Healthy data continues without a tap; small warning, bounded retries, gap-safe cursors, dedup and stable scroll | 13 |
| A16: failed move, Back/Escape, source list changes in selection | Selection exits/persists only when appropriate | 14 |
| A17: selected parent and child plus independent duplicate query | Descendant union by Topic ID; independent copies retained; scoped Unfollow confirmation, no implicit folder deletion | 14 |
| A18: folder/Topic unread and date sorting, return to Manual | Summary and sort agree; manual placement unchanged | 15 |
| A19: local subtree and profile filters; empty creation | No network/global-profile side effects; correct destination | 16 |
| A20: cache clear versus late writer; disable/re-enable | No resurrection or unexpected eviction; explicit reopen semantics | 18 |
| A21: modern export and legacy import in same installation | Clear presentation, stable compatibility and rollback | 19 |
| A22: global profile A, Topic owner B | Route-scoped B auth/actions throughout child routes; global A unchanged, including same-site different accounts | 20 |
| A23: same numeric ID across sites/accounts and cached origins | Cross-site entries distinct; same-site identity dedup safe | 01, 12, 19, 20 |
| A24: 240/320px controls, 2x text, keyboard insets, dark/light | Reachable actions, coherent labels, no overflow or stale state | 04–06, 14, 17 |
| A25: realistic multi-feed performance fixtures | Before/after evidence, unchanged functional contracts | 21 |

## Mapping to the preceding review

| Review section | Planned work |
| --- | --- |
| 1. Following opens creation | FTC-01–03 |
| 2. First-match ambiguity | FTC-01, FTC-02 |
| 3. Follow design and icons | FTC-04, FTC-17 |
| 4. Save versus refresh | FTC-03, FTC-10 |
| 5. Folder creation | FTC-05 |
| 6. Folder/feed settings | FTC-06 |
| 7. Automatic-update status | FTC-07, FTC-08 |
| 8. Feed progress/empty states | FTC-09, FTC-10 |
| 9. Navigation and active ownership | FTC-11 |
| 10. History invalidation and failure | FTC-12, FTC-13 |
| 11. Selection | FTC-14 |
| 12. Sort/discovery | FTC-15, FTC-16 |
| 13. Vocabulary/menus/capabilities | FTC-04, FTC-08, FTC-17 |
| 14. Cache and backup presentation | FTC-18, FTC-19 |
| Additional: profile scope and performance | FTC-20, FTC-21 |
| Contract-first testing and honest qualification | FTC-22 |

## Planning-session validation boundary

Only this specification and its handoff are to be committed during planning.
Validate Markdown structure, cross-links, referenced repository targets, checklist
coverage, and the remote diff. No application test run is required for these
non-runtime documents. The implementation agent must execute and record its own
runtime verification; nothing in this plan claims those changes have been made.
