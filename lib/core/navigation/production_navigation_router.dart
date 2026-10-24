import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kurumi/material.dart';

import '../../foundation/info/package_info.dart';
import '../../foundation/performance/performance_navigation.dart';
import '../analytics/analytics_observer.dart';

import '../../boorus/danbooru/router.dart';
import '../../boorus/danbooru/posts/uploads/widgets.dart';
import '../../boorus/eshuushuu/router.dart';
import '../../boorus/pixiv/router.dart';
import '../../boorus/shimmie2/router.dart';
import '../../boorus/szurubooru/router.dart';
import '../../foundation/app_rating/app_rating.dart';
import '../configs/config/types.dart';
import '../downloads/downloader/widgets.dart';
import '../home/widgets.dart';
import '../home/types.dart';
import '../posts/details/src/routes/details_route_context.dart';
import '../routers/routes.dart';
import '../search/search/src/routes/route_utils.dart';
import '../search/following_topics/providers.dart';
import 'app_navigation.dart';
import 'navigation_account_discovery.dart';
import 'app_navigation_shell.dart';
import 'destination_id.dart';
import 'destination_activity.dart';
import 'navigation_chrome_controller.dart';
import 'navigation_chrome_route_sync.dart';
import 'destination_profile_scope.dart';
import 'destination_router.dart';
import 'legacy_navigation_bridge.dart';
import 'navigation_catalog_provider.dart';
import 'navigation_controller.dart';
import 'navigation_destination_pages.dart';
import 'navigation_route_catalog.dart';
import 'page_presentation_profile.dart';

GoRouter createProductionNavigationRouter(Ref ref, AppNavigation navigation) {
  final coverage = NavigationCoverageObserver();
  var disposed = false;
  final performanceObservers = <DestinationId, PerformanceNavigationObserver>{};
  final isDev = ref.read(isDevEnvironmentProvider);
  final templates = [
    ...Routes.features(ref),
    ...danbooruRoutes,
    ...eshuushuuRoutes,
    ...pixivRoutes,
    ...shimmie2Routes,
    ...szurubooruRoutes,
  ];
  final controller = ref.read(navigationControllerProvider.notifier);
  late final DestinationRouterBinding binding;
  String normalize(String location, Object? extra) => resolveLegacyNavigation(
    location,
    browse: controller.browseDestination,
    destinations: binding.destinations,
    favoritesProfileId: ref
        .read(navigationControllerProvider)
        .lastFavoritesProfileId,
    explicitProfileId: switch (extra) {
      SearchRouteContext(:final config) => config.id,
      final BooruConfig config => config.id,
      DetailsRouteContext(:final config) => config?.id,
      _ => null,
    },
  );
  List<DestinationRouteDefinition> definitions() {
    final catalog = ref.read(navigationCatalogProvider);
    final ids = [
      for (final destination in AppDestination.values)
        DestinationId.app(destination),
      for (final profile in ref.read(navigationProfilesProvider))
        DestinationId.browse(profile.id),
      for (final id in catalog.eligibleFavoritesProfileIds)
        DestinationId.favorites(id),
      for (final section in catalog.profileSections)
        for (final tool in section.rows)
          DestinationId.tool(section.profileId, tool.toolId),
    ];
    return [
      for (final id in ids)
        DestinationRouteDefinition(
          id: id,
          builder: (_, state) => DestinationPageActivity(
            child: id.profileId == null
                ? NavigationDestinationPage(
                    id: id,
                    initial: state.uri.queryParameters['initial'],
                    initialRequest: state.extra,
                    scrollTo: state.uri.queryParameters['scrollTo'],
                    filter: state.uri.queryParameters['filter'],
                    group: state.uri.queryParameters['group'],
                  )
                : NavigationAccountDiscovery(
                    child: NavigationDestinationPage(
                      id: id,
                      initial: state.uri.queryParameters['initial'],
                      initialRequest: state.extra,
                      scrollTo: state.uri.queryParameters['scrollTo'],
                      filter: state.uri.queryParameters['filter'],
                      group: state.uri.queryParameters['group'],
                    ),
                  ),
          ),
          children: destinationChildRoutes(
            id,
            templates
                .where((t) => !isNavigationRootTask(Uri(path: '/${t.path}')))
                .toList(),
          ),
        ),
    ];
  }

  binding = DestinationRouterBinding(
    definitions: definitions(),
    rootObserver: coverage,
    observersFor: (id) {
      bool active() =>
          !disposed &&
          binding.currentDestination == id &&
          coverage.uncovered.value &&
          !ref.read(navigationChromeProvider).menuOpen;
      return [
        AnalyticsObserver(() => ref, isActive: active),
        if (isDev)
          performanceObservers[id] = PerformanceNavigationObserver(
            isActive: active,
          ),
      ];
    },
    navigatorWrapper: (context, id, selected, navigator) => Consumer(
      builder: (context, ref, _) => DestinationActivityHost(
        selected:
            selected &&
            !ref.watch(navigationChromeProvider.select((s) => s.menuOpen)),
        coverage: coverage,
        onActivityChanged: (active) {
          if (active) performanceObservers[id]?.refresh();
        },
        child: ProviderScope(
          overrides: [
            currentDestinationRouteObserverProvider.overrideWithValue(
              binding.observerFor(id)!,
            ),
          ],
          child: DestinationScope(
            id: id,
            active: selected,
            child: id.profileId == null
                ? ProviderScope(
                    overrides: [
                      pagePresentationProfileProvider.overrideWithValue(null),
                    ],
                    child: navigator,
                  )
                : DestinationProfileScope(
                    profileId: id.profileId!,
                    child: navigator,
                  ),
          ),
        ),
      ),
    ),
    shellBuilder: (_, _, shell) => UploadToDanbooru(
      child: AppRatingScope(
        child: DownloaderScope(
          child: EntryPage(
            navigationChild: Consumer(
              builder: (context, ref, _) {
                final prefs = ref.watch(navigationControllerProvider);
                final catalog = ref.watch(navigationCatalogProvider);
                return ListenableBuilder(
                  listenable: Listenable.merge([
                    coverage.uncovered,
                    binding
                        .observerFor(binding.idAt(shell.currentIndex))!
                        .topRoute,
                  ]),
                  builder: (context, _) => NavigationChromeRouteSync(
                    route: binding.currentRoute,
                    child: AppNavigationShell(
                      interactionsBlocked:
                          !coverage.uncovered.value ||
                          binding.currentRoute is PopupRoute,
                      navigationShell: shell,
                      hasNewFollowingPosts: ref.watch(
                        followingTopicHasNewPostsProvider,
                      ),
                      active: binding.idAt(shell.currentIndex),
                      browse: controller.browseDestination,
                      catalog: catalog,
                      collapsedProfiles: prefs.collapsedProfileIds,
                      onSelect: controller.selectDestination,
                      onFavorites: () => controller.openFavorites(
                        catalog.eligibleFavoritesProfileIds,
                      ),
                      onToggleProfile: (id) =>
                          unawaited(controller.toggleProfile(id)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
    ingressRoutes: [
      GoRoute(
        path: '/',
        redirect: (_, state) => normalize(state.uri.toString(), state.extra),
      ),
      for (final (path, template) in flattenNavigationRoutes(templates))
        GoRoute(
          path: '/$path',
          name: template.name,
          builder: isNavigationRootTask(Uri(path: '/$path'))
              ? template.builder
              : null,
          pageBuilder: isNavigationRootTask(Uri(path: '/$path'))
              ? template.pageBuilder
              : null,
          onExit: template.onExit,
          redirect: isNavigationRootTask(Uri(path: '/$path'))
              ? template.redirect
              : (_, state) => normalize(state.uri.toString(), state.extra),
        ),
    ],
  );
  final startupHome = ref.read(customHomeViewKeyProvider)?.name;
  final browse = controller.browseDestination;
  final startup = switch (startupHome) {
    'bookmark' => const DestinationId.app(AppDestination.bookmarks),
    'bulk_download' => const DestinationId.app(AppDestination.bulkDownload),
    'favorites' =>
      browse.profileId == null
          ? const DestinationId.app(AppDestination.favoritesRecovery)
          : DestinationId.favorites(browse.profileId!),
    final tool? when browse.profileId != null =>
      binding.destinations
              .where(
                (id) =>
                    id.profileId == browse.profileId &&
                    id.kind == DestinationKind.tool &&
                    id.toolId!.endsWith(
                      '.${switch (tool) {
                        'favgroup' => 'favorite-groups',
                        'saved_searches' => 'saved-searches',
                        _ => tool,
                      }}',
                    ),
              )
              .firstOrNull ??
          browse,
    _ => browse,
  };
  final initial = binding.destinations.contains(startup) ? startup : browse;
  final router = NavigationGoRouter(
    routingConfig: binding.routingConfig,
    navigatorKey: navigation.navigatorKey,
    initialLocation:
        '${initial.location}${startupHome == 'search' && initial == browse ? '/search' : ''}',
    observers: [
      navigation.routeObserver,
      coverage,
      AnalyticsObserver(
        () => ref,
        isActive: () => !disposed && !coverage.uncovered.value,
      ),
      if (isDev)
        PerformanceNavigationObserver(
          isActive: () => !disposed && !coverage.uncovered.value,
        ),
    ],
    normalize: normalize,
    isDestinationRoot: (location) => binding.destinations.any(
      (id) => id.location == Uri.parse(location).path,
    ),
    selectAlias: (location, extra) {
      final uri = Uri.parse(location);
      if (uri.path.startsWith('/_nav/') || isNavigationRootTask(uri)) {
        return false;
      }
      final resolved = Uri.parse(normalize(location, extra));
      final id = binding.destinations
          .where((id) => id.location == resolved.path)
          .firstOrNull;
      // Query-bearing search/detail ingress must still construct its child page.
      if (id == null ||
          uri.queryParameters.keys.any((k) => k != 'cid' && k != '_profile')) {
        return false;
      }
      unawaited(switch (id.kind) {
        DestinationKind.browse => controller.selectBrowseProfile(id.profileId!),
        DestinationKind.favorites => controller.selectFavoritesProfile(
          id.profileId!,
          ref.read(navigationCatalogProvider).eligibleFavoritesProfileIds,
        ),
        _ => controller.selectDestination(id),
      });
      return true;
    },
    errorBuilder: (_, _) => const NavigationRecoveryPage(favorites: false),
  );
  binding.attach(router);
  controller.binding = binding;
  Future<void> reconcile({Set<String> resetProfileIds = const {}}) async {
    await binding.reconcile(definitions(), resetProfileIds: resetProfileIds);
    performanceObservers.removeWhere(
      (id, _) => !binding.destinations.contains(id),
    );
  }

  ref.listen(navigationCatalogProvider, (_, _) => unawaited(reconcile()));
  ref.listen(navigationProfilesProvider, (previous, next) {
    final changed = {
      for (final old in previous ?? <BooruConfig>[])
        if (next.where((c) => c.id == old.id).firstOrNull?.auth != old.auth)
          old.id,
    };
    unawaited(reconcile(resetProfileIds: changed));
  });
  ref.onDispose(() {
    disposed = true;
    controller.binding = null;
    router.dispose();
    binding.dispose();
    coverage.dispose();
  });
  return router;
}
