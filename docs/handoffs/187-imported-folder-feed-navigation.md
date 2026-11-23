# Imported folder feeds: navigation rejection

Issue: [#187](https://github.com/timberpile/Boorusama/issues/187)

Continue branch: `feature/187-profileless-following-import`

Inspected implementation: `2509c687952db3db9c810bca28e035880c5bb12d`.
Current remote develop during investigation: `ee19bbe1307f73b5662bcdf0caef82933ac3e0e1`.

## Finding and evidence boundary

The owner reports that imported folder feeds do nothing when tapped, including after disabling and re-enabling Feed, while newly created folders work. The source confirms a deterministic silent navigation rejection for folders whose first Topic has a detached storage owner. This investigation did not run Flutter, a build, or a device reproduction; no runtime patch was applied. The previous local continuation and its reported checks remain documented in [the original handoff](187-profileless-following-import.md).

## Root cause

All paths below are relative to the repository and were inspected at the implementation commit above.

1. `lib/core/backups/sources/following_topic_import_service.dart`: unresolved Topics receive a fresh UUID storage namespace in `FollowingTopic.profileId`. Their actual portable source remains in `localSource`. This UUID is deliberately not a saved user profile.
2. `lib/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart`, `ensureFolderFeed`: the materialized Feed takes `first?.profileId ?? existing?.profileId ?? fallbackProfileId`. A populated imported folder therefore gets its first Topic's detached namespace as its legacy cache anchor.
3. `lib/core/search/following_topics/src/pages/following_topics_page.dart`, `_openFolderFeed`: the production destination branch forwards that anchor as `queryParameters: {'_profile': feed.profileId}`.
4. `lib/core/navigation/navigation_facade.dart`, `DestinationRoutingRef.pushRoute`: `_profile` means a real account source. It searches `booruConfigProvider`; when the UUID is not present, it returns `Future.value()` before `router.push`. No exception reaches the caller, so no failure toast is shown.

Toggling Feed changes the folder settings, not the Topic's ownership. Opening recomputes the same anchor and repeats the rejection. A new empty folder with a saved profile uses the real fallback profile; a folder whose first Topic is profile-owned also passes. A mixed folder can therefore fail depending on which Topic supplies the anchor, not whether its sources can actually be read.

## Minimal fix

Open modern folder feeds by their folder/feed ID only. They are multi-source collections, not single-account pages. Remove the `_profile` query argument from `_openFolderFeed`:

```diff
       if (DestinationScope.maybeOf(context) != null) {
         await ref.pushNamedRoute<void>(
           '/following-topics/feed',
           pathParameters: {'feedId': feed.id},
-          queryParameters: {'_profile': feed.profileId},
         );
```

The route factory in `lib/core/search/following_topics/src/routes/routes.dart` already permits a missing `_profile`. `TopicFeedPage.build` resolves current reader configurations through `followingTopicConfigProvider` for its individual sources, with the stored profile anchor only as a fallback. Its content authorization remains per source.

Do not weaken `pushRoute`'s invalid-account/revoked-scope guards, manufacture a saved profile, rewrite Topic ownership, or bind a mixed folder to an arbitrary real account just to pass navigation. `navigation_route_catalog.dart` also attaches a page-wide profile lease when `_profile` is present; omitting it avoids incorrectly tying a mixed-source folder's lifetime to one account. Keep genuine profile-scoped legacy actions unchanged. Audit other modern folder-feed entry points for the same parameter misuse; do not broadly remove account context from search/viewer routes.

This change needs no persisted-format migration, cache deletion, or reimport. Existing affected folders should become reachable after the fix is verified.

## Regression test that exercises the failure

`test/core/search/following_topics/topic_folder_actions_test.dart` currently opens a normal profile-backed folder using `FollowingTopicHarness.pump`. That helper builds `MaterialApp(home: child)` without `DestinationScope`, so `_openFolderFeed` takes the raw `Navigator.push` fallback and never executes the failing facade. Merely adding a detached fixture to that same test is insufficient.

Add `test/core/search/following_topics/imported_folder_feed_navigation_test.dart` using production destination routing, or a faithful `DestinationRouterBinding` plus `DestinationScope`, registered child routes and an attached `navigationControllerProvider` binding whose current destination is Following. Do not mock `pushRoute` or the account validation under test.

- Import a folder with a valid public Topic and no matching local profile through `FollowingTopicImportService`; assert its storage owner is absent from saved profiles. Tap the folder's Open Feed button. Before the fix the route stays unchanged; after it the real `TopicFeedPage` is pushed and its URI has no `_profile`.
- Repeat with zero saved profiles, with one unrelated saved profile, and after disabling/re-enabling Feed. The nonempty imported folder remains navigable without adding a profile or changing its identity.
- Check a mixed folder with a detached/unavailable first Topic and a readable later Topic. Reorder the sources and confirm navigation does not depend on the first owner. Add a compatible profile after import and verify the retained folder still opens.
- Retain the existing empty-folder-with-local-profile and ordinary local-folder behavior, Back navigation, and current account isolation/revocation tests. Unavailable sources must remain safely unavailable; opening a folder does not grant network access.

Use controlled repositories/transports, not live websites. Confirm that omitting `_profile` from this global Following entry does not inherit an unrelated explicit page source. Record a failing-before/passing-after result for the actual destination route.

## Local execution and acceptance

Read current `AGENTS.md`; continue the existing isolated task worktree and preserve unrelated local edits. Implement the targeted fix and regression test, format changed Dart files, run `git diff --check`, and analyze the affected scope. Run the new test, `topic_folder_actions_test.dart`, `following_topic_navigation_test.dart`, related Following public-access tests and navigation tests using the pinned FVM SDK and physical-core concurrency. Before any authorized develop integration, the final combined candidate still requires the complete regression suite under the repository workflow.

Commit the scoped fix and tests; report the exact tested commit and outstanding device/live-media acceptance separately. Do not create a PR, merge, close #187, or delete the branch without separate authorization.
