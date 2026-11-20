# #179 — Rule34 Favorite repair and observed Favorite state

## Scope, baseline, and authority

- Repository: `timberpile/Boorusama`; continue **`bug/179-rule34-favorite-actions`**.
- Issue: [#179 — Fix Rule34.xxx Favorite Actions](https://github.com/timberpile/Boorusama/issues/179).
- Reviewed runtime commit: **`ae20ef73bda3c255670b1738c1a23bf03e40aa5d`** (20 November 2026).
- Reviewed `develop`: **`d9203ae62dcbc5ff81e0bd70702607fb24070787`**; merge base: `04fd511a895aabbf2c08d833cc1ce3473181621d`. At review time each side had three commits not on the other side.
- The owner requested a second review, investigation of learning Favorite state from fetched Favorite pages, and this implementation handoff. This document is not an implementation or a merge approval.
- **Part A** repairs the remaining #179 defects. **Part B** is the related, owner-requested cross-engine Favorite-evidence improvement; do not describe all of Part B as a newly introduced #179 regression or invent a new issue number.
- Follow current `AGENTS.md`, `docs/development_workflow.md`, `docs/engineering_guidelines.md`, and the applicable repository skill. Recheck branch ownership, worktree changes, and current refs before implementation.

This document supersedes the [initial research handoff](https://github.com/timberpile/Boorusama/blob/16a3e9faabb6992756d8bd668cd26718f05abfd4/docs/handoffs/179-rule34-favorite-actions.md). In particular, its proposed legacy `user_id` / `pass_hash` transport is **not** the Rule34 transport implemented at the reviewed head. Do not revert the session migration to follow that older proposal.

## 1. What the second review establishes

### R1 — P1: Favorites outside the first page cannot be removed

Source: [`rule34_favorite_actions.dart:45–57`](https://github.com/timberpile/Boorusama/blob/ae20ef73bda3c255670b1738c1a23bf03e40aa5d/packages/booru_clients/lib/src/gelbooru_v2/rule34_favorite_actions.dart#L45-L57).

`remove()` reads only `_firstFavoritesPage()`. If the requested ID is absent, it throws `unknown` before sending the mutation. An existing Favorite on page two or later therefore cannot be removed, including one opened from a later page of the app's own Favorites destination.

Reproduce with a fake adapter: first page contains `[8, 9]`, has a next page, and the target is `7` on that next page. The current implementation issues only the first listing read. The test named `a target absent from the bounded listing leaves the site untouched` currently locks in this limitation; keep its safety assertion for genuinely unresolved membership, but do not treat it as coverage of successful later-page removal.

Required outcome: support later-page targets with reliable target-specific confirmation or a correctly scoped paginated verification strategy. Absence from page one is not absence from the collection.

### R2 — P2: Removing the last entry of a nonterminal page reports failure

Source: [`rule34_favorite_actions.dart:75–82`](https://github.com/timberpile/Boorusama/blob/ae20ef73bda3c255670b1738c1a23bf03e40aa5d/packages/booru_clients/lib/src/gelbooru_v2/rule34_favorite_actions.dart#L75-L82).

If the target is the final entry in `before.posts`, `before.posts.skip(index + 1)` is empty. When the refreshed first page still has a next page, the confirmation predicate always rejects the result, even after a successful server deletion.

Minimal fixture: before `[8, 7]`, target `7`, accepted delete response, after `[8, 9]`, `hasNext: true`. The server has removed `7`, but the client reports an unconfirmed mutation and the notifier rolls its displayed state back. Retrying then also hits R1 because `7` is no longer on the first page.

Required outcome: verify the boundary case without weakening the check to “ID absent from one page means removed.” A neighboring page or another verified membership signal is needed when the relevant ordering boundary is not present.

### R3 — P2, pre-existing: Favorite-page observations erase mutation ownership

Sources: [`favorites_notifier.dart`](https://github.com/timberpile/Boorusama/blob/ae20ef73bda3c255670b1738c1a23bf03e40aa5d/lib/core/posts/favorites/src/providers/favorites_notifier.dart), `FavoriteMutationTracker`, and both Gelbooru Favorite-page fetchers. The same unsafe preload behavior exists at the merge base; this is not introduced by #179.

`preloadInternal()` unconditionally calls `_mutations.forget(post.id)` and overwrites the visible value. Two problematic orderings are:

1. An own-Favorites read starts while `P` is favorited. `remove(P)` begins and displays optimistic `false`. The old read completes with `P`; preload forgets the pending operation and writes `true`. The successful remove completion cannot update the cache because `finish()` no longer recognizes its operation. The heart remains filled although the server removed the Favorite.
2. The old read finishes only after the removal has already completed. There is no pending operation to detect, but its stale positive result still resurrects `P` locally.

Required outcome: reads must never delete pending mutation ownership, and a read started before an intervening local mutation must not overwrite that mutation's result. Checking only `isPending()` at read completion does not fix the second ordering.

### Integration note — not a separate current-runtime defect

`develop` changed `FavoritePostButton.action(context)` and `SimplePostActionToolbar` for actionable overflow entries and Group Bookmark controls. The task branch changes the same components. Preserve both the new toolbar/overflow behavior and the #179 confirmation, captured-profile, and login-feedback behavior when reconciling the branch. Do not resolve conflicts by taking either whole file unchanged. Relevant paths:

- `lib/core/posts/favorites/src/widgets/favorite_post_button.dart`
- `lib/core/posts/details_parts/src/toolbars/simple_post_action_toolbar.dart`
- `packages/i18n/translations/en-US.json`

## 2. Ticket investigation: what is already stored and learned

The requested behavior is **partly implemented already**, not a missing cache from scratch:

| Path / component | Verified current behavior |
| --- | --- |
| `FavoritesNotifier` / `favoritesProvider` | An in-memory `IMap<int, bool>` keyed by `BooruConfigAuth`; starts empty. Mutations optimistically change it and normally settle or roll back. There is no durable Favorite index in this notifier. |
| `lib/boorus/gelbooru_v2/favorites/widgets.dart`, HTML path | After a successful page fetch, calls `preloadInternal(posts, selfFavorited: (_) => true)`. This is the Rule34 path, and covers other sites using this HTML path. |
| `lib/boorus/gelbooru/favorites/widgets.dart` | Also seeds every returned Favorite as `true`. |
| Gelbooru V2 API Favorite-page path | Fetches `fav:<uid>` but does not perform the same explicit positive preload. |
| `FavoritesPageScaffold` | Binds post origins and presents a grid; does not centrally ingest Favorite evidence. |
| Gelbooru V2 Favorite repository | Supplies `isFavorited: (_) => false` and no `filter` callback. Its current implementation cannot determine arbitrary post membership through a per-post lookup. This is not proof that every possible site endpoint lacks such a capability. |
| `FavoriteRepositoryBuilder` and `checkFavorites()` | An absent filter returns `[]`; `checkFavorites()` caches missing IDs as `false`. Unsupported knowledge is therefore conflated with a confirmed negative. |
| e621 | Its Favorite repository reads `post.isFavorited`; preserve its authenticated metadata semantics. Its Favorite page does not contain the explicit preload used by Gelbooru. |
| Shimmie2 | Has a username-scoped `filterFavoritesFromUsername` lookup. Do not classify it as unsupported merely because its per-post callback returns `false`. |
| Moebooru | Uses a separate Favorite-user lookup and vote-based mutation path. Do not replace that path with a generic boolean toggle. |

Inspect remaining engine adapters and custom controllers before changing their semantics. Use capability/evidence contracts rather than a hardcoded list of site names.

The optional server-Favorite-to-Bookmark-Group projection is a different feature. `ConfirmedFavoriteRepository` / `prepareServerFavoriteProjection` can project confirmed mutations into local groups. Group membership is not authoritative current remote Favorite membership and must not become the evidence store. Do not trigger projection, local bookmark creation, or “Added” feedback merely because a Favorite page was read.

Related requirements: [#102](https://github.com/timberpile/Boorusama/issues/102) explicitly prohibits interpreting unknown server-Favorite state as “not favorited”; [#44](https://github.com/timberpile/Boorusama/issues/44) and [#132](https://github.com/timberpile/Boorusama/issues/132) concern separate Bookmark Group synchronization behavior. Do not implement new filters, change group assignments, or close those issues as a side effect.

## 3. Scope recommendation and alternatives

**Recommended first delivery:** keep the existing in-memory lifetime, make observation ingestion shared and race-safe, fill the own-Favorites entry-point gaps, and preserve unknown status. This addresses the ticket without a new database or backup migration.

- Repeating `preloadInternal(... true)` in more widgets is insufficient: it propagates R3 and duplicates ownership/freshness rules.
- A shared, explicit own-Favorites observation boundary is the smallest compatible approach. It learns from already-requested data without per-thumbnail network requests.
- A durable, account-scoped Favorite-evidence index could retain knowledge across restarts, but requires separate decisions about retention, account/credential rotation, clearing, logout, backup/import, and stale external changes. **Do not add it in this delivery without owner approval.** Never use a credential hash or Bookmark Group membership as a durable actor identity.

These are review recommendations, not claims that the owner has separately approved a persistence design. The first delivery still forgets its in-memory observations on application restart/provider-container recreation. It records last-known evidence, not an always-current mirror of the website.

## 4. Part A — repair Rule34 removal without regressing session safety

### Preserve the branch's implemented transport and feedback boundaries

Relevant code includes `rule34_website_session.dart`, `rule34_favorite_actions.dart`, `gelbooru_v2_client.dart`, `GelbooruV2AuthView`, `CookieAccessWebViewPage`, and the HTTP protection/logging interceptors.

- Keep Rule34's tagged `rule34-session-v1:` value in the existing website-credential slot, account matching, and the `r34_uid` / `__Host-session` cookie pair implemented on this branch. A legacy hash or API key alone is not website mutation authorization.
- Preserve validation of cookies eligible for both Favorite paths, rejection of missing/ambiguous/mismatched sessions, and invalidation when the API user ID changes. Browser import must not overwrite a different account's API credentials.
- Keep website credentials confined to the exact HTTPS website origin. Do not forward them to the API/CDN host or follow credential-bearing redirects. Retain request-cookie precedence over a stale shared browser session while allowing clearance cookies.
- Preserve plain add-response parsing: `3` confirms success, `1` confirms already present, `2` requests website re-login; unexpected data is not success. Do not globally change other Gelbooru-family sites' response semantics.
- Preserve private diagnostics, no automatic mutation replay, cancellation/cooldown/permission propagation, and the existing confirmed-only gesture/quick-heart feedback.
- Do not infer that an API-only profile cannot learn Favorite evidence: read capability and website mutation capability remain separate.

### Removal implementation sequence

1. Add failing adapter tests for R1 and R2 before modifying the client. Keep the no-false-success tests.
2. Establish what the current website actually returns for successful deletion, rejected session, last Favorite, and populated/empty listings. Existing tests use hand-written HTML; they do not prove the live document structure. Prefer sanitized structural fixtures obtained through authorized testing. Do not change the HTTP method, endpoint, or membership protocol based on guesswork.
3. Prefer a verified target-specific acknowledgment or membership lookup if available. Otherwise extend listing verification to the relevant page/window, including pagination boundaries. A cached page hint may help locate the target, but is not authoritative membership evidence or a stable offset after concurrent changes.
4. Follow only validated same-origin, same-account pagination. Detect repeated cursors/offsets and malformed/incomplete pages; support cancellation and an explicit finite read budget. Avoid fetching the entire collection on every tap. On exhausted evidence/budget, return an honest unconfirmed outcome rather than fabricating success or silently retrying the mutation.
5. For window-based proof, establish the before/after ordering bounds with actual returned IDs. Cover a target at the end of a page using the adjacent page or an independently verified end-of-collection. A preceding ID alone does not prove the target was not pushed to the next page.
6. Separate “request dispatched but outcome unknown” from a known rejection. Never automatically issue a second delete after an ambiguous timeout or verification failure. A subsequent explicit retry may first reconcile the desired state if authoritative evidence shows the target is already absent; a partial-page miss is insufficient.
7. Keep the client result, provider mapping, notifier state, and user feedback consistent. A confirmed removal remains removed; an unconfirmed result must not show a success toast. The exact live proof mechanism remains a diagnostic task until supported by evidence.

## 5. Part B — shared, account-scoped Favorite observations

### 5.1 Separate knowledge, activity, and presentation

Represent these concepts separately, using the smallest compatible extension to the current model:

- **Knowledge:** unknown, known favorited, or known not favorited; with provenance/freshness sufficient for ordering.
- **Activity:** a lookup or mutation can be pending independently of that knowledge.
- **Presentation:** an unfilled heart may be the visual default for unknown, but is not a confirmed negative.

Add an explicit optional lookup/capability/result contract. An unsupported filter must not masquerade as a successful lookup returning an empty set. A successful authoritative lookup may provide negatives only for the IDs and account it actually resolves. Failures, cancellation, parsing uncertainty, and unsupported lookups remain unknown.

Likewise, `isPostFavorited: (_) => false` on an engine without account-specific metadata is not negative evidence. Make that distinction explicit before using generic post preloads. Preserve reliable metadata on engines that actually provide it; do not reinterpret saved/cross-account post snapshots as fresh authenticated observations.

Review `favoriteProvider`, `favoriteStatusProvider`, `favoriteStatusLoaderProvider`, and `FavoriteContextMenuTile` together. The current nullable boolean also controls loading/disabled UI. Leaving unsupported state at `null` must not create perpetual loading, repeated automatic lookups, or permanently disabled Add actions. Keep authorization separate. Do not let an unknown visual `false` short-circuit an explicit removal as already completed.

### 5.2 Introduce one observation boundary

Provide a shared notifier/helper operation conceptually like `observeOwnFavorites(postIds, readContext)`. Keep merging and concurrency rules outside widgets. The exact API/name is an implementer choice.

At actual request execution, capture:

- the immutable source/auth context and originating profile;
- the requested collection owner, validated against that account;
- the read-generation/mutation-revision fence;
- the owner/lifecycle validity needed to reject obsolete completions.

`TaskEither` is lazy: capture the read fence when the request runs, not merely when constructing a fetcher in `build()`.

After a successfully parsed response, merge **positive evidence only** for its returned IDs. Do not clear the cache or mark unreturned IDs false, even when the page is empty, filtered, the last page, or a refresh. A page is not an authoritative complete collection snapshot.

The operation must not call `addToFavorites`, send a mutation, invoke Bookmark Group projection, vibrate, or emit mutation-success feedback. Duplicate observations are idempotent. Reading your own public Favorite page can supply evidence even without website mutation credentials.

Make ownership explicit at the fetch boundary; do not assume any widget titled Favorites or any query containing `fav:` belongs to the active account. Ignore other users' Favorites for the current account's state. Keep identical numeric post IDs on different sites/accounts isolated. Never resolve the destination from whichever global profile is active after an `await`.

### 5.3 Fence reads against mutations

- Remove `_mutations.forget()` from passive observation ingestion. Mutation bookkeeping belongs to mutations, not incoming pages.
- Capture a read revision before the fetch. Reject observations for an ID if a newer mutation began or settled since that capture; preserve pending intent and the eventual success/rollback result.
- Retain sufficient revision information after a mutation finishes. Deleting the pending entry must not make an old read appear fresh again.
- Cover reads that start while a mutation is already pending and finish after it settles. Tracking only mutation starts is insufficient for this ordering; use settlement revisions or equivalent pending-at-start evidence too.
- Protect against older reads completing after newer accepted observations when both can carry authoritative state.
- A genuinely new own-Favorites read started after a completed removal may learn `true` again, e.g. the user re-favorited the post in a browser. Do not create permanent negative tombstones that block newer valid evidence.

A conservative per-auth epoch, advanced on mutation start and settlement, can safely discard a whole stale page initially; per-ID revisions allow unaffected IDs to be learned more precisely. Choose one explicitly, test it, and avoid an unbounded event log. Do not weaken the existing overlapping-mutation rollback contracts.

### 5.4 Integrate existing paths without duplicate ingestion

Start with:

1. `lib/boorus/gelbooru/favorites/widgets.dart`: replace direct positive preload with the shared boundary.
2. `lib/boorus/gelbooru_v2/favorites/widgets.dart`: replace the HTML-path preload and add the missing API-path observation.
3. `lib/core/posts/favorites/src/pages/favorite_page_scaffold.dart`: either compose an explicitly owned observer here or wrap fetchers through a shared helper. Do not add both and ingest the same response twice.
4. `lib/core/posts/favorites/src/providers/favorites_notifier.dart`, repository contracts/builders, and `favorite_mutation_tracker.dart`: implement knowledge/capability and revision rules; audit every `preload`, `preloadInternal`, `checkFavorites`, and local-remove caller.
5. Audit other Favorite-page implementations and their repository capabilities. Reuse the boundary where applicable; preserve e621 metadata, Shimmie2 lookups, and Moebooru's separate vote semantics. Do not route Pixiv Work/Page identities or custom privacy/session controllers through an unverified numeric-post assumption.

Use local code search, for example:

```bash
rg -n 'preloadInternal|checkFavorites|isPostFavorited|filterFavoritedPosts|favoritesProvider' lib test
rg -n 'FavoritesPageScaffold|FavoriteRepositoryBuilder|extends FavoriteRepository|implements FavoriteRepository' lib
```

Do not expand into automatic full Favorite synchronization, arbitrary search-query inference, new filtering UI, persistent storage, or a Bookmark Group redesign. Existing explicit Favorite-sync reads can be integrated later only under the same owner/freshness contract; cached group contents alone are never evidence.

## 6. Required regression coverage

Use controlled adapters and `Completer`s rather than timing sleeps. Tests must exercise production clients/notifiers and the real observation boundary, not only a reimplementation of their predicates.

| Area | Cases and required assertions |
| --- | --- |
| Rule34 removal | Target on page two/later; last entry on a full nonterminal page; last Favorite; moved page boundary; concurrent additions/deletions; still-present target. Confirm actual absence only with sufficient evidence. |
| Verification safety | Login page/redirect, 401/403, off-origin/account pagination, malformed/missing listing structure, repeated pagination, exhausted budget, interrupted verification. No false success and no automatic second mutation. |
| Partial-page ingestion | Page one plus page two accumulate positives; duplicates are harmless; empty/error/filtered pages do not clear known entries or create negatives for unseen IDs. |
| Race R3 | Old read arrives during a pending remove and after its success; confirmed removal remains false. Mirror relevant add/failure/rollback cases. |
| Pending-at-read-start | A read begins during an existing mutation and completes after that mutation succeeds/fails; stale evidence cannot override settlement. |
| Fresh reconciliation | A new read after a completed removal can restore true when the site has genuinely re-favorited the post. Old read completions cannot overwrite newer accepted evidence. |
| Unsupported knowledge | No per-post lookup returns unknown without issuing requests or caching false. Context menus remain usable; no infinite loader/refetch loop. Reliable negatives on supported engines remain supported. |
| Isolation | Same numeric ID across two sites/accounts; account/profile switch while a read or mutation is in flight; same account in compatible profiles; disposal or credential replacement. No completion affects the wrong actor/UI. |
| Read-only auth | API-only Rule34 can learn its own Favorite-page positives, but Add/Remove still requires a website session and sends no unauthorized mutation. |
| No projection side effects | Passive observations do not create local Bookmarks, change group assignments, invoke mutation callbacks, show Added to favorites, or vibrate. |
| Entry-point integration | Actual Gelbooru page, Gelbooru V2 HTML and API page paths, grid heart, viewer toolbar/overflow, gesture, and context menu consume the same state. Test at narrow width/enlarged text where UI changes. |

Existing test starting points:

- `packages/booru_clients/test/gelbooru_v2/rule34_favorite_actions_test.dart`
- `test/boorus/gelbooru_v2/rule34_favorite_provider_test.dart`
- `test/boorus/gelbooru_v2/rule34_session_import_test.dart`
- `test/core/posts/favorites/favorite_feedback_test.dart`
- `test/core/posts/favorites/favorite_interruption_test.dart`
- `test/core/posts/favorites/favorite_post_presentation_test.dart`
- `test/core/bookmarks/server_favorites/confirmed_favorite_repository_test.dart`
- `test/core/http/client/api_mutation_replay_test.dart`
- `test/core/http/client/dio_protection_startup_test.dart`
- `test/debug/log_redaction_test.dart`

Add focused observation/provider and real page-ingestion tests alongside these. Preserve existing tests rather than replacing meaningful failure cases with success-only fixtures.

## 7. Verification, local delivery, and remaining uncertainty

The remote review inspected source/tests and compared the branches. Small Python logical witnesses reproduced the two removal predicates and both stale-read orderings; these were **not Dart/Flutter tests**. No product code was changed by the review. No authenticated site mutation, device test, or application/package suite was run here; `fvm`, Flutter, and Dart were not on the review environment's PATH. The branch Actions query returned zero workflow runs at review time. This does not establish what the implementer may have tested locally.

For authorized implementation:

1. Reuse/create the isolated worktree for the exact task branch without disturbing unrelated work. Re-read current instructions and reconcile the #176 toolbar changes deliberately; do not modify `develop` itself or discard shared history.
2. Implement Part A and the recommended in-memory Part B in separate focused commits so their behavior can be reviewed independently. Commit scoped work before handoff. Do not publish code, create a PR/issue, merge, close #179, or delete branches without the corresponding owner authorization.
3. Format changed Dart files with `fvm dart format`, run affected analysis, and run targeted tests first. Regenerate i18n only if changed inputs/missing generated output require it; author new UI text in English localization resources only.
4. Run the complete `booru_clients` package suite plus relevant app/consumer tests. Shared Favorite state/model changes also require the complete local regression suite under the repository's scope guidance.

Example commands from the appropriate worktree, after normal dependency/generated-output setup:

```bash
test_workers="$(python3 scripts/physical_core_count.py)"
(cd packages/booru_clients && fvm dart test "--concurrency=$test_workers")
fvm flutter test --no-pub "--concurrency=$test_workers" \
  test/boorus/gelbooru_v2 \
  test/core/posts/favorites \
  test/core/bookmarks/server_favorites \
  test/core/http/client/api_mutation_replay_test.dart \
  test/core/http/client/dio_protection_startup_test.dart \
  test/debug/log_redaction_test.dart
./scripts/run_regression_tests.sh
```

Before any separately approved develop integration, require a complete pass on the **final combined runtime candidate**. Reuse a pass only for the same candidate; documentation-only changes do not require rerunning application tests. Keep durable local evidence in the ignored worktree artifact location, not `/tmp` or committed logs.

Use an emulator only for the browser/session and actual UI/device integration that cannot be covered by unit/widget tests; follow `docs/android_emulator.md` and use only authorized test credentials. Verify current session import, expired session, add/already-present, and removal on first/later/boundary pages. Capture sanitized structural/status evidence only, never cookies, account identifiers, API keys, raw authenticated URLs, or private page contents.

Final implementer report: exact commit and develop baseline, fixes versus pre-existing cache improvements, observation ownership/freshness rules, explicit non-persistence, commands/results/skips, and remaining live-site uncertainty. Do not claim Rule34 deletion is verified end-to-end until that evidence exists.
