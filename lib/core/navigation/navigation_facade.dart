import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../configs/config/types.dart';
import '../search/search/src/routes/route_utils.dart';
import '../posts/details/src/routes/details_route_context.dart';
import '../posts/details/src/routes/lazy_post_details_route.dart';
import 'page_source_context.dart';
import 'navigation_page_request.dart';
import 'legacy_navigation_bridge.dart';
import 'navigation_controller.dart';
import '../configs/manage/providers.dart';
import '../router.dart' show routerProvider;
import 'destination_profile_scope.dart';

/// Existing helpers keep their payload and return type. The explicit source is
/// carried as a safe UUID query component, never an envelope around extra.
extension DestinationRoutingRef on WidgetRef {
  Future<T?> pushRoute<T>(String location, {Object? extra}) {
    final router = read(routerProvider);
    final destination = DestinationScope.maybeOf(context)?.id;
    if (destination == null ||
        location.startsWith('/_nav/') ||
        isNavigationRootTask(Uri.parse(location))) {
      return router.push<T>(location, extra: extra);
    }
    if (!context.mounted ||
        read(navigationControllerProvider.notifier)
                .binding
                ?.currentDestination !=
            destination) {
      return Future.value();
    }
    final uri = Uri.parse(location);
    // A filtered task listing is a child of the operation that opened it.
    // The unfiltered public entry still selects the shared destination.
    final taskDetails =
        uri.path == '/download_manager' &&
        uri.queryParameters.containsKey('group');
    if (!taskDetails &&
        const {
          '/bookmarks',
          '/following-topics',
          '/topic-feeds',
          '/pinned-searches',
          '/following-feeds',
          '/global_blacklisted_tags',
          '/favorite_tags',
          '/bulk_downloads',
          '/download_manager',
          '/settings',
          '/desktop/settings',
          '/donate',
          '/premium',
        }.contains(uri.path)) {
      router.go(location, extra: extra);
      return Future.value();
    }
    final source = switch (extra) {
      SearchRouteContext(:final config) => config.id,
      LazyPostDetailsRouteContext(:final config) => config.id,
      final BooruConfig config => config.id,
      DetailsRouteContext(:final config) => config?.id,
      _ =>
        uri.queryParameters['_profile'] ??
            read(explicitPageSourceProvider)?.profileId,
    };
    final sourceConfig = switch (extra) {
      SearchRouteContext(:final config) => config,
      LazyPostDetailsRouteContext(:final config) => config,
      final BooruConfig config => config,
      DetailsRouteContext(:final config) => config,
      _ => null,
    };
    final live = read(booruConfigProvider)
        .where((c) => c.id == source)
        .firstOrNull;
    if (source != null &&
        (live == null ||
            (sourceConfig != null && sourceConfig.auth != live.auth))) {
      return Future.value();
    }
    final request = NavigationPageRequest(
      logicalUri: uri,
      origin: destination,
      extra: extra,
      source: source == null
          ? null
          : PageSourceContext(
              profileId: source,
              originatingTopicId: extra is SearchRouteContext
                  ? extra.originatingTopicId
                  : null,
            ),
    );
    return router.push<T>(
      request.logicalUri
          .replace(
            path: '${request.origin.location}${request.logicalUri.path}',
            queryParameters: {
              ...uri.queryParameters,
              if (request.source case final source?)
                '_profile': source.profileId,
            },
          )
          .toString(),
      extra: request.extra,
    );
  }

  Future<T?> pushNamedRoute<T>(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) => pushRoute<T>(
    read(routerProvider).namedLocation(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    ),
    extra: extra,
  );
}
