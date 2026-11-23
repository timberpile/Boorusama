# Issue #117 — Pixiv Favorites local completion

[Current all-branch review](117-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

## Continue the existing branch

`feature/117-pixiv-favorites` starts independently from develop
`422aeae087c1108e655d85d1a3dac25120456cd6`. Read current AGENTS.md, issue #117,
and comments before claiming an isolated worktree. No merge, PR, release or
issue closure is authorized. Do not begin #119 until #117 is merged.

## Source implementation

- A readonly Pixiv client extension calls `/v1/user/bookmarks/illust` through
  the existing authenticated request/header/error path. Public/Private only;
  All remains absent because it was not authenticated/live-verified.
- Bookmark pages validate the continuation's HTTPS host, path, account,
  visibility, unique numeric cursor, and forward progress. Only the cursor is
  reused in a new request to the fixed endpoint; the URL itself is never
  followed. New requests explicitly disallow redirects and accept cancellation.
- An account/filter-scoped session adapts sequential cursor pages to PostGrid.
  Refresh cancels the previous generation, failure preserves the retry cursor,
  disposal suppresses late results, and known exhaustion makes further requests
  local no-ops. It reuses the existing Pixiv post parser and origin binding.
- PixivBuilder now supplies the existing shared Favorites destination with a
  PostGrid and profile picker. Public/Private filters rebuild the source scope.
  Cursor pagination is explicitly infinite; arbitrary page jumps are not faked
  by walking the account. Missing account identity/token offers login recovery.
- Navigation eligibility requires a nonempty refresh token and positive account
  ID. No account discovery is started while constructing navigation metadata.
- No server favorite/unfavorite operation, bulk matching, imaginary search
  syntax, unsupported server-favorites collection action, or second Favorites
  navigation destination was added. Existing native Pixiv auth refresh remains
  the only bearer-token owner. All UI text reuses existing `context.t` resources.

## Verification actually performed

The three modified source files were reconstructed from pinned GitHub content
and their original Git blob SHAs were verified. Source diffs, UTF-8, final
newlines and `git diff --check` were checked. Client and session tests were
prepared before implementing their behavior; execution could not start because
FVM, Flutter and Dart are absent (exit 127). No test pass, analyzer/format result,
compile/build result, authenticated Pixiv response or Android acceptance is
claimed. The authoring workspace was partial, not a runnable full checkout.

The request shape was compared with PixivPy's current `user_bookmarks_illust`
implementation. That is source evidence, not a live contract guarantee.

## Required local completion

1. Format/analyze with the pinned FVM SDK. Confirm the client extension is
   exported via the existing Pixiv library and the UI compiles through Kurumi.
2. Run the complete `packages/booru_clients` suite (package API changed), then:

   ```bash
   fvm flutter test --no-pub test/boorus/pixiv_favorites_session_test.dart
   fvm flutter test --no-pub test/core/navigation/engine_navigation_capabilities_test.dart
   fvm flutter test --no-pub test/pixiv_test.dart test/pixiv_auth_test.dart
   ```

   The new package test is `test/pixiv/pixiv_bookmarks_test.dart`.
3. Add view/provider tests for shared Favorites profile selection, changing
   Public/Private during a delayed request, changing accounts, missing identity,
   expired-token recovery, empty/error states and successful post opening.
4. Important existing boundary: the develop Grid controller currently decides
   continuation from nonempty post lists. #113 separately corrects this. This
   branch emits correct `PostResult.hasMore`/`maxPage` and avoids requests beyond
   a known end, but does NOT cherry-pick #113. Validate all-filtered nonterminal
   source pages and immediate final-page Load More behavior when that fix is
   integrated; do not mask the bug with unbounded eager page fetching here.
5. With an authorized logged-in Pixiv test account, verify actual continuation
   shapes and both visibility modes over multiple pages, token refresh,
   restricted/deleted artworks, multipage works, and cancellation. Never put
   tokens or private response payloads in logs, fixtures or handoffs. Retain the
   public/private distinction and do not expose All merely because another
   endpoint supports it. Review refresh-token metadata updates/profile scope.
6. Follow device lease/Maestro guidance; test 320dp, enlarged text, refresh,
   selection and viewer navigation. An existing background/profile change must
   not expose the old account's private results in the new account's view.
7. After local fixes/review, run full regression on the final integration
   candidate and prepare a development build for Timber's manual review. Report
   exact commits, commands, failures/skips and outstanding acceptance. Do not
   mark review-ready until the necessary checks have actually passed.
