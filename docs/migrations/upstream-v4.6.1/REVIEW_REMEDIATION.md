# Consolidated review remediation

Review baseline: `49f2b9ade`, branch `maintenance/upstream-v4.6.1-migration`.
The three supplied reports consolidate into 21 actionable items, plus one
explicitly conditional concern. Repeated mentions are one item, not additional
independent defects. The original implementation report's 68/68 completeness
claim is superseded by this reconciliation.

## Findings, evidence and changes

R1/R2/R3 refer to the user's three supplied reports. "Confirmed" distinguishes
an implementation/acceptance gap from a claim that a live endpoint is broken.
The approved decision log remains authoritative.

| # | Decision / reports | Validation and resolution |
| --- | --- | --- |
| 1 | A14 / R1, R2 | Confirmed Android DSL compilation failure in the baseline Dev build. Disambiguate SDK variable names, replace deprecated Kotlin options, and remove the obsolete global BuildConfig flag. AGP 9 then exposed an incompatible existing cookie-manager plugin. Restore the established AGP 8.12.1 / Kotlin 2.2.20 / Gradle 8.14 combination under A14's selective adoption rule; retain SDK 36, Java 17, flavors, package identity and signing. Enable app BuildConfig explicitly. |
| 2 | A01/X03 / R1 | Confirmed by a failing runtime-scope replacement widget test with real Hive storage. Hive factories no longer close application-owned boxes when a provider scope is disposed. Covers favorites, bookmarks/groups and the identical blacklist ownership pattern. Factory seams and fake-factory disposal remain intact. |
| 3 | D02 / all | Confirmed injected cleanup failure made a completed session unreachable. Commit terminal status, completion time, final statistics and record deletion in one SQLite transaction. A failed transaction retains retryable state and records. Startup repairs interrupted finalizations without replaying notifications; repeated cleanup preserves saved totals. Regression includes a SQLite abort trigger, rollback, startup recovery and repeated finalization. |
| 4 | N02 / R1, R2 | Confirmed original URLs/client bypassed media resolution. Resolve every progressive target/lower/fallback candidate and preload request through profile network settings, selecting an independent replacement-host client and filtered headers. Grid fallback transport receives the same treatment. A controlled adapter test checks viewer plus preload URLs, cache destination and credential stripping. |
| 5 | D01 / R1, R2 | Confirmed with controlled concurrent writes to one destination. Replace check-then-rename with native atomic publication that cannot replace an existing file. Identical content is idempotent; different content remains a recoverable conflict. Native implementations use Linux/Android no-replace rename, Darwin exclusive rename and Windows non-replacing move. |
| 6 | P08 / R1, R3 | Confirmed a deferred deletion's hidden cache key could enqueue onto its leased path. Refuse replacements while readers or deferred deletion own that path, including a recheck after asynchronous admission work. Package regression holds two readers, attempts replacement, releases both, then confirms an allowed replacement survives repeated old-lease release. |
| 7 | X04 / R1 | Confirmed the old test explicitly expected a cache path and no share directory. Sharing now copies validated images into `boorusama-share`; cache protection lasts only through copying. Cache clearing cannot delete the share copy. Existing release and startup cleanup remove share files. |
| 8 | B06 / all | Confirmed held favorite lookup blocked listing. Capability discovery and favorite enrichment now run asynchronously after obtaining posts. Existing favorite-cache merging preserves intervening user actions; optional failures remain soft. A completion-gated regression proves listing returns before the lookup is released. |
| 9 | D01 / all | Confirmed failure/retry APIs had no application UI consumer. Both download screens now display a metadata failure notice opening one shared recovery page. Retry operates on the sidecar journal only, retains conflicts and explains failed retries. Updates invalidate the failure list; resume refreshes failures written by background isolates. Narrow/large-text widget coverage proves retries leave media unchanged. |
| 10 | N05 / R2, R3 | Confirmed exported cookies defaulted unknown flags to false and native path to `/`. Android exports a conservative host-only, request-path and transport scope, with unknown HttpOnly treated as restricted. Dart defaults unknown security flags to restricted values. Explicit native attributes remain authoritative. This narrows unknown attributes; Android's header API cannot recover the original attributes. Conversion checks cover Secure, HttpOnly, path and host-only behavior; installed native behavior remains manual acceptance. |
| 11 | N01/D05 / R2, R3 | Confirmed Anime-Pictures returned an uncoordinated transport despite its quota definition. Attach its Dio to the shared `ApiRequestCoordinator`; the transport regression verifies that provider boundary. |
| 12 | P03 / R2 | Confirmed there were no app reload callers and error placeholders were static. Add focusable localized Retry controls that call `ExtendedImageController.reload()` for grid/fallback images. Progressive retry targets failed requests while retaining decoded lower pixels. Only explicitly retried failed cache keys are cleared. Tests cover pointer/keyboard retry, independent tile taps, corrupt target bytes, retained pixels and successful replacement. |
| 13 | D07 / R2, R3 | Confirmed missing `{id}` could yield `.jpg`. When an ID token is used but no genuine ID exists, generate an explicitly named `media_` URL-hash filename with the actual extension. Different URLs with the same basename remain distinct; no synthetic post ID is exported. |
| 14 | P02 / R2, R3 | Confirmed unchecked optional enable-value cast threw, and discarded options produced no warnings. Parse the switch tolerantly and retain transient per-profile warning codes for invalid/unknown actions and host rules. Package-import preflight and legacy profile-import confirmation show localized warnings. Keep UUID/unrelated fields; unsafe/uninterpretable options normalize to supported values rather than retaining invalid host rules. |
| 15 | P04 / R2 | Confirmed obsolete typed errors published before the latest-result guard. Guard error publication and resolve queued refresh callers using the final pass, also suppressing obsolete thrown failures. Tests cover typed and thrown old failures followed by a successful refresh. |
| 16 | B01 / R2 | Confirmed shared action children were empty/unused and Sankaku had no controls. Add a shared site capability for rating/date/order/user/pool/favorite options, supplied by Sankaku and Danbooru. The existing common mobile/desktop action section renders one shared options UI; site definitions own raw prefixes/values. Preserve Danbooru's existing saved-metatag controls. Test constrained dialog submission and safe mappings; raw syntax/composer/autocomplete remain available. |
| 17 | N01 / all | Confirmed reference audit found only the obsolete sliding-window implementation, its export and its own tests. Remove those files/export; retain the coordinator and its regression coverage. |
| 18 | D07 / R3 | Confirmed dry run checked disk existence but never reserved destinations within a batch. Reserve normalized destinations across all pages: skip a duplicate when skipping is enabled, otherwise fail preparation visibly before any transfer. Pixiv's page-specific default remains unchanged. Tests exercise both conflict policies; ordinary bulk fixtures now use distinct names. |
| 19 | N01 / R3 | Confirmed retry backoff could not be interrupted. Make retry waiting cancelable and cancel its timer. A controlled-clock regression proves cancellation settles without waiting for Retry-After or issuing another attempt. |
| 20 | B10 / R3 | Confirmed acceptance violation, not a demonstrated endpoint failure: the new listing host was enabled without the required live matrix. Restore the established relative XML listing endpoint and default parser; keep the existing details/autocomplete endpoints. The generated configuration reflects this. Activation remains gated on targeted authenticated/unauthenticated live checks. |
| 21 | Documentation / all | Confirmed `git diff --check e8bf883 -- docs/migrations/upstream-v4.6.1` reported handoff trailing whitespace and the catalog's extra EOF line. Remove those whitespace defects. |

## Conditional concern

R3 explicitly excluded mixed-origin quick actions from its confirmed findings.
The current bookmark builder (`bookmark_scroll_view.dart`) and Following feed
builder (`topic_feeds_page.dart`) resolve each post's origin and pass that
profile's auth to `DefaultImageGridItem`. The generic grid uses the selected
profile, but no currently affected mixed-origin use of that default builder was
established. No speculative behavior change was made for this concern.

## Verification

In progress. The initial nine application reproduction checks failed against
`49f2b9ade`; repaired focused checks and the complete cache/retry package suites
have passed. The final runtime candidate still requires the complete regression
runner, final analysis, Android build and diff review. This section will record
the checked commit and actual results before handoff.

## Limits

Manual UI acceptance is assigned to the user by A02. No phone/emulator operation,
installed upgrade/signing acceptance, live authenticated service checks, or
Windows/macOS/iOS native execution is claimed. Linux atomic sidecar publication
is exercised locally; other platform implementations require native acceptance.
The gated Rule34 listing switch remains deferred. Local fixes do not authorize
integration, pushing, PR creation, tagging or release publication.
