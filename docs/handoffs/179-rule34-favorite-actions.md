# #179 — Fix Rule34.xxx website Favorite actions

**Issue:** https://github.com/timberpile/Boorusama/issues/179
**Implementation branch:** `bug/179-rule34-favorite-actions`, created from `develop@04fd511a895aabbf2c08d833cc1ce3473181621d` (20 November 2026).
**Status:** Code-researched repair guidance; no runtime fix or authenticated mutation has been executed here. Follow `AGENTS.md`, `docs/development_workflow.md` and `.agents/skills/implement-change/SKILL.md`. Recheck the current local worktree and remote baseline before editing.

## What is reported, and what the source actually proves

**User report:** Favoriting a Post on `https://rule34.xxx/` fails. The precise build, exact authentication mode, server status and add-versus-remove variant have not yet been captured on a device.

### Confirmed client/auth mismatch

1. `packages/booru_clients/boorus.yaml` registers Rule34.xxx under `gelbooru_v2`. Rule34 post searches use `https://api.rule34.xxx/...`, while site Favorite actions use the inherited **website** endpoints (`https://rule34.xxx/public/addfav.php?id=...` and `/index.php?page=favorites&s=delete&id=...`).
2. `lib/boorus/gelbooru_v2/client_provider.dart` constructs `GelbooruV2Client` with separate `userId=login`, `apiKey` and `passHash`. `packages/booru_clients/lib/src/gelbooru_v2/gelbooru_v2_client.dart` mixes in `GelbooruClientFavorites`, so the generic website Favorite mutation is used for Rule34 without a Rule34-specific capability check.
3. `lib/core/configs/config/src/types/booru_login_details_impl.dart`: `ApiAndCookieBasedLoginDetails.hasLogin()` considers **either a nonempty pass hash or user ID + API key** sufficient for the *profile* to count as logged in. But `GelbooruClientFavorites.canFavorite` specifically needs **both user ID and `pass_hash` cookie**; an API-only profile can read Posts and yet cannot perform website Favorite mutations. `lib/boorus/gelbooru_v2/configs/widgets.dart` already exposes optional `AdvancedAuthSection` with embedded browser session import; `lib/core/configs/auth/src/widgets/advanced_auth_section.dart` imports `user_id` and `pass_hash` if available.
4. `lib/core/posts/favorites/src/widgets/utils.dart` (`WidgetRef.toggleFavorite`) guards only generic `guardLogin`, calls `FavoritesNotifier.add`, **ignores the returned `AddFavoriteStatus` and displays “Added to favorites” even when that status is `failure`**. On failure `FavoritesNotifier.add` rolls back its optimistic state. That is a confirmed false-success UX bug in the gesture path.
5. `lib/core/posts/favorites/src/widgets/quick_favorite_button.dart` similarly has a `Future<void>` toggle callback that discards the status returned by `FavoritesNotifier.add`. Its like-button can haptically acknowledge a failed request until state catches up; correct the confirmation path without changing local Bookmark behavior.
6. `packages/booru_clients/lib/src/gelbooru/gelbooru_client_favorites.dart` switches on **exact** response body strings `'1'`, `'2'` and `'3'`. Numeric response data, whitespace/newline or an HTML login response is not handled explicitly. The shared remove method currently accepts **any HTTP 200/302** as success without verifying authentication or result; login redirection can be a false positive.
7. The inferred successful Rule34 add endpoint is **corroborated**, not disproved, by a recent third-party Rule34 script: `https://sleazyfork.org/en/scripts/559604-rule34-xxx-keyboard-shortcuts/code` requests `/public/addfav.php?id=...` and interprets `3` as added, `1` as already favorited, `2` as not logged in. This is **unofficial public evidence**, not a verified authenticated Boorusama mutation. Do **not** change the endpoint blindly.

These facts establish **an authentication/capability mismatch, response fragility and false UI success**, but do not prove which one caused the reporter's specific failure. Confirm with controlled HTTP fixtures first and, if possible, authorized authenticated device observations without recording secrets.

## Implementation decisions / exact work

### A. Separate API-read auth from website-Favorite auth

- In `gelbooruV2FavoriteRepoProvider` / `GelbooruClientFavorites`, implement a clear Rule34 website-Favorite capability: a **nonempty captured `user_id` AND nonempty `pass_hash`**, not the generic profile `hasLogin()` or `apiKey`. Validate emptiness, not only non-null. The API-key-only profile is valid for **search**, but not a valid session for website Favorite mutations.
- Keep the browser login path already implemented in `GelbooruV2AuthView → AdvancedAuthSection → CookieAccessWebViewPage`. If website session is missing or rejected, make the UI communicate **“Website login required / reconnect using the profile's browser-login action”** using localization. Do not attempt to reuse an API key as a `pass_hash`, auto-synthesize cookies or forward API credentials to the website mutation endpoint.
- The normal Favorite heart/gesture must not claim success when website session auth is unavailable. If a user-visible action is still displayed for discovery, it must open/help with authentication or show a clear localized error; it may not perform an unauthenticated optimistic mutation. Do not change API-read profile validation globally merely to fix Favorites.
- Scope any Rule34 exception to **verified exact site hostname(s)**, not all Gelbooru V2 installations. Keep `gelbooru.com`, `realbooru.com` and custom sites' existing auth and Favorites behavior intact.

### B. Make mutation responses trustworthy

- Preserve the confirmed `/public/addfav.php?id=POST_ID` endpoint unless **real authenticated evidence** identifies a site change. Supply session cookies via the existing `buildGelbooruSessionHeaders(userId, passHash)` and `stateChangingRequestExtra`; keep credential transport confined to `https://rule34.xxx` (not the separate API/CDN host). Verify the request's effective base URL, origin and redirect behavior in a mocked-Dio test.
- Request/interpret a **plain** response. Normalize a body such as `'3'`, `'3\\n'`, or numeric `3` to a bounded status, without treating unrecognized JSON, HTML, arbitrary text, 30x login redirects or HTTP failures as success. For Rule34 use **3 = success, 1 = already favorited, 2 = website login required**. Other sites' status semantics must stay unchanged unless separately verified. Expose a typed login-required outcome/error as narrowly as the app's `FavoriteRepository` API permits; do not collapse it into a fabricated success.
- Make the removal action check for an **authenticated, confirmed outcome**. Current `removeFavorite` accepts HTTP 200 or 302 without checking whether the final page is a login/denial redirect. Preserve the existing endpoint until verified; use response validation or a bounded authenticated verification read where the site offers one. If Rule34-specific remove behavior requires a different HTTP method, change it **only after** a verified fixture/live observation. Never mark an unknown response as removed.
- Continue propagating cancellations, cooldowns and permission changes through `isFavoriteRequestInterruption`; do not retry non-idempotent mutations automatically or return “success” when an interrupted/failed response is ambiguous. Keep `FavoriteMutationTracker` race semantics, credential isolation and origin restrictions.

### C. Fix the UI's false-success reporting

- In `lib/core/posts/favorites/src/widgets/utils.dart` change `WidgetRef.toggleFavorite` so it checks `runFavoriteAction(... FavoritesNotifier.add(...))`'s actual `result.value`. Show the **success** snackbar only for `AddFavoriteStatus.success` or `AddFavoriteStatus.alreadyExists`; for `failure` show a localized failure or login-required message. The current unconditional success snackbar after a failed result must go. Keep a canceled/interrupted action distinct from failure and retain confirmed-success cleanup feedback.
- For `DefaultQuickFavoriteButton`, stop discarding the result of `FavoritesNotifier.add` in its `onFavToggle` callback. Ensure the quick heart/haptic state is acknowledged **only after** confirmed Favorite success; failed add/remove must visually revert without stale local “liked” state. Make the smallest compatible callback/result adjustment for existing other callers; avoid a broad Favorite UI rewrite.
- `FavoritesNotifier` already performs optimistic rollback on an unacknowledged add; do not duplicate that state machinery. Do not treat API-authenticated “profile logged in” as proof that a website Favorite action is authorized. Distinguish local Bookmark Group action from remote Rule34 Favorite state.

### D. Failure/recovery requirements

- **API-only:** read/search still works; the remote Favorite action correctly identifies the missing website session and explains how to sign in. No attempted website mutation and no false success. 
- **Browser-session authenticated:** add returns success/already, remove returns only confirmed success; visible state updates consistently for active Profile/Post. Persistence is limited to what the server confirms; do not invent remote favorite state from stale cache or switch profiles silently.
- **Cookie expired / server code 2:** report session expired and prompt re-login, never success. Unauthorized/HTML login page/redirect and inconsistent body formats produce clear failures without exposing tokens.
- **Network/cooldown/cancel:** no false success; preserve existing interruption handling. On source/account change, a stale completion cannot update another account's Favorite state.
- **No secrets in tests/logs:** never print `pass_hash`, `user_id` or session-cookie header values, API keys, full authenticated URLs, captured browser content or headers in exceptions/diagnostics.

## Required tests / evidence

- Add focused package tests under `packages/booru_clients/test/gelbooru_v2/` using a fake Dio adapter, **without any live authenticated user data**, to inspect Rule34 website-origin request, session Cookie presence (use fake values), and status mapping `3`/`1`/`2` for plain/whitespace/numeric responses; HTML/login redirect, forbidden/network failure, cancellation and unauthenticated session.
- Add app/provider tests under `test/boorus/gelbooru_v2/`: API-only profile vs browser session; `canFavoriteProvider` behavior and no unauthorized website request; correct callback status and optimistic rollback on failure; site-specific behavior does not regress Gelbooru/Realbooru. Preserve API Post browsing with ID/key.
- Add regression tests for `WidgetRef.toggleFavorite` (gesture) **not claiming “Added” on `AddFavoriteStatus.failure`** and the quick heart's failed-response reversion. Existing `test/core/posts/favorites/favorite_interruption_test.dart`, `favorite_post_presentation_test.dart` and `test/core/bookmarks/server_favorites/confirmed_favorite_repository_test.dart` are relevant neighbors.
- If possible use a leased Android device/emulator following `docs/android_emulator.md` and a **test Rule34 account the owner has authorized**. Compare API-only, imported valid browser session, expired session, add, already-added and remove. Record sanitized response **status/type/outcome only**, never credentials or private POST/query data. If live authentication remains unverified, report the limitation and do not claim the site mutation was fixed.
- Run changed Dart formatting (`fvm dart format`), package/app targeted `fvm flutter test` and analysis, and the repo's full regression suite before any authorized `develop` integration. Retain durable logs in ignored worktree artifacts, not committed files.

## Delivery and restrictions

Commit only scoped changes/tests to `bug/179-rule34-favorite-actions`. Report branch/commit, reproduced failure mode(s), exact site-auth criteria, confirmed outcomes, test commands/results, and any live-site uncertainty. This is **pre-release priority**, but the branch is not approved to merge by virtue of being documented. Do **not** post an issue comment, make a PR, merge into `develop` or close #179 without explicit owner authorization.
