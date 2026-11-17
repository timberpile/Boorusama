# Fix Pixiv Browse/Search Work Grouping — Technical Handoff

Issue: [#174](https://github.com/timberpile/Boorusama/issues/174)
Source reviewed: [`develop` at `55cec5ae2b69`](https://github.com/timberpile/Boorusama/tree/55cec5ae2b697612a68af40ed3a8bc4ba1caedbb) (2026-11-17).
Audience: local implementation agent. Code snippets are **unapplied proposals**, not verified patches.

## Evidence and likely routing regression

**Previously inspected source:** `PixivWorkHomePage` and `PixivWorkSearchPage` can use native `PixivWorkGrid` / `NativeContentGrid`, whose `ContentEntry` model supports one `GroupContentEntry` per Work. However `PixivWorkSearchPage` has a `DefaultSearchPage` fallback for `SearchProfileSession.local`. Search navigation can classify nested destinations or Following-origin sessions as local, so some Pixiv routes may still emit flattened `PostContentEntry` pages. This is a **supported hypothesis**, not proof of the user's exact normal Browse/Search path. #140 is closed; #161 covers Explore pagination, not grouping. `lib/core/content/widgets/native_content_grid.dart` confirms native grouped entries remain supported.

## Suggested investigation and fix

Instrument/trace the actual affected route's profile/session mode, query origin and chosen page builder. Compare ordinary Pixiv Browse, direct Pixiv Search, nested Search, Following-origin Search, and Explore. Trace the result conversion: Pixiv API artwork ID → native `ContentGroupSummary` / `GroupContentEntry` → `ViewerEntry`. Determine whether it wrongly switches to `DefaultSearchPage` or converts each Page to a synthetic Post.

Once confirmed, route supported **normal Pixiv listing** scenarios to the existing native Work grid and retain one artwork-level identity per result. Do **not** unconditionally remove the local-session fallback: locally filtered post lists may have different input contracts. Keep Ugoira as a Post and preserve the shared Work/Page viewer introduced in #140/#164.

Illustrative routing contract, not a drop-in patch:

```dart
// Native Work listing is selected only for a supported Pixiv artwork query;
// other session modes retain their established, intentional local semantics.
if (isPixivArtworkListing && canUseNativeWorkResults(session)) {
  return buildExistingPixivWorkGrid(...);
}
return buildExistingLocalPostSearch(...);
```

## Focused verification

- Multi-page Pixiv illust/manga produces exactly one Browse/Search card with correct count and Page order; opening it uses inner Page navigation.
- Query text, pagination, account scope, Favorites/Following entry paths and back navigation remain stable.
- Single-page Works, Ugoira, local post-only collections and non-Pixiv boorus stay correct.
- Reproduce on an actual Pixiv account/device; source review alone cannot establish which route triggers the flattening.
