# Fix Pixiv Timeline Refresh State — Technical Handoff

Issue: [#169](https://github.com/timberpile/Boorusama/issues/169)
Source reviewed: [`develop` at `55cec5ae2b69`](https://github.com/timberpile/Boorusama/tree/55cec5ae2b697612a68af40ed3a8bc4ba1caedbb) (2026-11-17).
Audience: local implementation agent. Code snippets are **unapplied proposals**, not verified patches.

## Evidence and likely cause

**Source-confirmed:** `lib/core/content/widgets/native_content_grid.dart` builds a `RefreshIndicator` around `CustomScrollView`. `NativeContentController.refresh()` clears `entries` and `viewerEntries` immediately (before awaiting `_load`), while `_load(replace: true)` clears them again **after successful fetch**. The `_footer` additionally renders `CircularProgressIndicator` whenever `loadingMore` is true. This explains both the dark/empty grid during pull-to-refresh and a second spinner. Exact device rendering is still user-reported.

## Suggested implementation

Keep previous items visible during a non-initial refresh; publish a replacement only after the result passes authorization and entry validation. The existing `_load(..., replace: true)` already performs replacement on success.

```dart
Future<void> refresh() async {
  _generation++;
  _request?.cancel('Native timeline refreshed');
  loadingMore = false;
  refreshing = true;
  // Keep entries/viewerEntries visible until successful _load().
  _loaded = false;
  hasMore = true;
  onRefresh?.call();
  await _load(initialPage, replace: true);
}
```

Rework `_footer` / initial-state rendering so that pull-to-refresh owns the progress indicator when existing entries are shown, while first load with zero entries shows the same skeleton grid/explicit empty state used by standard Post grids. On refresh failure, retain old results plus a retryable error. Ensure `retry()` still replaces rather than appending duplicate entries after a failed refresh; watch the `_loaded`, `hasMore`, generation, prefetch and continuation interactions.

## Focused verification

- Existing Pixiv Works stay visible until refresh succeeds; one refresh indicator, no extra footer spinner.
- Initial empty load shows placeholders, genuine empty result shows empty state, failed refresh retains old Works.
- Repeated refresh, cancellation, profile switch, paginated/infinite mode, and retry do not mix generations, duplicate cards or revive stale credentials.
- Run the same native-content paths for other sources, since `NativeContentGrid` is shared.
