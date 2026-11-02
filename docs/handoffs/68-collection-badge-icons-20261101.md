# #68 — Compact Collection Badge Icons

Branch: `feature/group-neighboring-series`.
Implementation checkpoint: `d38e17f851c5ffc7414b29abbf130548be9e5e05`; this handoff follows the badge tap-through review fix.

## Implemented

- Fixed-white badge assets: Lucide book-open (Series), an original vector Collection icon matching the supplied reference (photo in the foreground lower-left, second empty frame behind upper-right), and Lucide workflow (future Related). The license file distinguishes their origins.
- Bookmarked Pool/Series tiles and grouped Search Series show the source/profile favicon first, then the type icon and count. The far right corner stays free.
- When space is constrained, show `X/total`, then just the authoritative `total`, then the type icon only; never ellipsize the count or hide the type. Complete values and localized type remain accessible.
- Existing Danbooru Pool Gallery identifies its Series/Collection type. Related grouping itself remains in #134.
- The overlay does not intercept tile taps. Existing Series tests now target presentation entries rather than removed type text.

**Collection visual correction:** Do not replace `group_collection.svg` with Lucide `images` (any version). Its stacking direction is different from the accepted screenshot. The custom SVG has been compared visually at small and enlarged sizes against the uploaded 47×43 reference image; Android/Flutter rendering still needs local verification.

## Local verification required

Flutter/FVM and Android tooling are unavailable in this GitHub-editing runtime. **No Flutter tests, Dart format/analyzer, build, or real device checks were executed.** The SVG shapes were reviewed and their XML structure checked.

1. Read the latest `AGENTS.md` and inspect the existing worktree and HEAD without resetting unrelated changes. Format changed Dart files with `fvm dart format`; fix any analyzer findings.
2. Run `fvm flutter test --no-pub test/core/posts/pools/pool_grid_item_badge_test.dart` and `fvm flutter test --no-pub test/application/pool_bookmark_flow_test.dart` plus nearby Pool Gallery/Bookmark tests.
3. Check visually on Android: Bookmarks with mixed profiles and Series/Collection references, deleted-profile logo fallback, normal Search Series, Danbooru Pool Gallery, light/dark themes, 4-column layouts, 1x/2x font scale, selection mode, and both tapping the badge and long-pressing elsewhere on the card.
4. Confirm icon-only / total / partial-total fallbacks, no overflow, source badge at left, blank far-right corner, original cover quality and safe navigation. Related glyph should be present as an asset but not rendered by a timeline until #134.
5. Run the full regression and Android debug build on the final integration candidate before requesting merge approval. Record exact commit/state, commands, failures and unresolved manual checks.

Do not create a PR, merge into develop, close the issue, or delete branches without authorization.
