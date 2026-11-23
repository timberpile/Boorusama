# Favorites header verification (#131)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/131-favorites-header-scroll`.

Shared non-Pixiv Favorites and Danbooru's dedicated Favorites explicitly enabled
floating navigation app bars. Remove those overrides; the existing non-floating
Kurumi default matches Pixiv Favorites. The independent Timeline Toolbar remains
unchanged. No Browse, Explore, Pixiv or global Kurumi policy changes.

Checks on final code:

- `fvm dart format lib/core/posts/favorites/src/pages/favorite_page_scaffold.dart lib/boorus/danbooru/posts/favorites/src/favorites_page.dart test/core/navigation/favorites_profile_picker_regression_test.dart`: passed.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/core/navigation/favorites_profile_picker_regression_test.dart`: 2 passed. Actual Danbooru/Gelbooru pages at 320dp/200% text: down/partial up keeps title hidden and toolbar visible, top restores title; existing picker/profile/search flow remains covered.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv_favorites_page_lifetime_test.dart --plain-name 'populated Favorites prefetch but title and privacy return only at the top'`: 1 passed.
- `timeout 20s fvm dart analyze lib/core/posts/favorites/src/pages/favorite_page_scaffold.dart lib/boorus/danbooru/posts/favorites/src/favorites_page.dart test/core/navigation/favorites_profile_picker_regression_test.dart`: no issues.
- `git diff --check`: passed.

The first fresh-worktree 75-second guarded test command was interrupted during
startup and is not counted. The unchanged final candidate completed the short
runs above. The host runner also printed a native finalizer diagnostic while
reporting the successful Favorites flow; no Flutter test assertion failed.

Not run: full suite, emulator/Maestro, live services/accounts, APK build/install,
Android visual checks or final manual acceptance. Owner QA: repeat partial upward
scroll in non-Pixiv Favorites and compare Pixiv; title returns only at list top,
while toolbar may reveal earlier. Full integration qualification remains pending.
