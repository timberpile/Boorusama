# Issue #118 — Pixiv Following Artists local completion

[Current all-branch review](118-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

## Continue the existing branch

Continue `feature/118-pixiv-following-artists`, independently based on develop
`422aeae087c1108e655d85d1a3dac25120456cd6`. Read current AGENTS.md, issue #118,
and latest comments; claim an isolated worktree before making changes. The user
authorized remote implementation and local completion, not a merge, PR, release,
or issue closure. #120 must wait for #118 and #100 to be merged.

## Source implementation

- Read-only `/v1/user/following` requests use the existing authenticated Pixiv
  client, request headers, error translation and token refresh path. They accept
  cancellation and explicitly reject redirects. Only Public/Private are exposed;
  All is intentionally not assumed from the artwork-follow feed.
- The typed response reads artist identity and at most three supplied previews.
  Missing previews are valid. Missing collections/identities are errors, not
  fabricated empty results. Continuations validate HTTPS origin/path, account,
  visibility and strictly advancing offset. Only the offset is reused in a new
  fixed-endpoint request, never the server-provided URL itself.
- A manually declared Riverpod AsyncNotifier family owns account/filter state.
  It coalesces load-more operations, deduplicates artist IDs, preserves results
  and retry offsets on failure, and cancels/ignores results from disposed or
  refreshed scopes. No account list is persisted into Following Topics.
- Pixiv-specific navigation includes Following Artists only when local account
  identity and credentials exist. The global Following destination is unchanged.
  The page receives its source profile explicitly, uses Public/Private filters,
  pull-to-refresh and bounded explicit pagination, and retains login recovery.
- Read-only cards follow the existing Topic card spacing: avatar/name/account,
  then up to three square previews across the card width. No detail/artwork
  request is issued just to fill a preview slot. Provided previews honor muted,
  visible, source-artist and known account restriction data; media URLs must
  start on HTTPS pximg.net hosts. Avatar absence has a neutral fallback.
- Tapping a card opens normal Search with `user:<numeric-id>` and the originating
  Pixiv profile. No edit, unfollow, folder, Bulk Match or separate artist viewer
  was introduced. UI labels reuse `context.t`; the title uses an existing-style
  fork translation extension with English fallback and German localization.

## Independence and eventual integration

This branch does not incorporate #117 or #113. #117 independently adds another
Pixiv client part and the same optional private `_get` cancellation/redirect
parameters. When both branches are accepted, retain both part declarations and
client methods while applying those shared parameters once. Navigation changes
are separate: #117 adds Favorites eligibility, #118 adds a profile tool. Do not
cherry-pick either unmerged branch merely to make development easier.

## Verification actually performed

Original modified files were reconstructed from pinned GitHub content and their
Git blob SHAs verified. Reviewed source/diffs, relative paths and UTF-8/final
newlines, and ran `git diff --check`. Prepared client, notifier, presentation and
navigation tests. The focused FVM command could not start because FVM, Flutter
and Dart are absent (exit 127). No Dart formatting/analyzer/test/build result,
authenticated live Pixiv response, Android test or independent review passed.
The authoring checkout was partial and is not a full runnable repository.

## Local completion and acceptance

1. Use the pinned FVM SDK to format/analyze changed files and resolve generated
   outputs when necessary. Verify the manual family notifier against the pinned
   Riverpod version and the page through the Material UI/Kurumi bridge.
2. Run the complete `packages/booru_clients` test suite, including the new
   `test/pixiv/pixiv_following_users_test.dart`, then the application cases:

   ```bash
   fvm flutter test --no-pub \
     test/boorus/pixiv_following_provider_test.dart \
     test/boorus/pixiv_following_presentation_test.dart \
     test/core/navigation/engine_navigation_capabilities_test.dart
   ```

   Run neighboring navigation route, Pixiv authentication/explore and parser
   tests as appropriate. Client shape assertions are not a live API test.
3. Add widget/routing coverage for a card opening `user:<id>` in its original
   profile, three/no previews, long names, 320dp, enlarged text, all loading/error
   states and Public/Private/account changes during delayed requests. Confirm
   the full account scope is replaced and no private old-account list flashes.
4. Review content-rule integration for this new preview surface, including
   configured local blacklists/media blur and restricted/muted previews. The
   current source applies server visibility and account-level restriction
   guards, not a new independent blacklist engine. Reuse existing filtering if
   an additional application-level guard is needed; do not add per-card fetches.
5. On an authorized authenticated Pixiv test account, verify both visibility
   modes, actual next-offset URLs, missing/deleted artists, token refresh,
   rate limits, retry, cancellation and page exhaustion. Never log credentials
   or private raw response payloads. Leave All absent unless separately proven.
6. Follow emulator lease/Maestro instructions. Compare card density with actual
   Following Topics, ensure all three previews span the content width, confirm
   no extra artwork calls, and exercise navigation/back plus keyboard/text-size
   constraints. Bulk Match remains absent until its dependent issue is allowed.
7. Perform a critical review, fix findings, then run the complete regression
   suite on the final combined candidate before integration. Prepare a private
   development build for Timber's manual review and record exact commit,
   commands, skips/failures, artifacts and remaining acceptance. Do not mark
   review-ready while required technical checks remain unrun or failing.
