import 'package:go_router/go_router.dart';

import 'destination_id.dart';

bool isNavigationRootTask(Uri uri) =>
    uri.path.startsWith('/boorus/') ||
    uri.path == '/open' ||
    uri.path == '/changelog' ||
    uri.path == '/debug_logs';

/// Incoming public paths select an owner; contextual pushes already carry a
/// canonical destination prefix and pass through unchanged.
String resolveLegacyNavigation(
  String location, {
  required DestinationId browse,
  required Iterable<DestinationId> destinations,
  String? explicitProfileId,
  String? favoritesProfileId,
}) {
  final uri = Uri.parse(location);
  if (uri.path.startsWith('/_nav/') || isNavigationRootTask(uri)) {
    return location;
  }
  final source =
      explicitProfileId ??
      uri.queryParameters['_profile'] ??
      uri.queryParameters['cid'];
  final owner = source == null ? browse : DestinationId.browse(source);
  final global = switch (uri.path) {
    '/following-topics' ||
    '/topic-feeds' ||
    '/pinned-searches' ||
    '/following-feeds' => AppDestination.following,
    '/bookmarks' => AppDestination.bookmarks,
    '/global_blacklisted_tags' => AppDestination.blacklist,
    '/favorite_tags' => AppDestination.favoriteTags,
    '/bulk_downloads' => AppDestination.bulkDownload,
    '/download_manager' => AppDestination.downloadManager,
    '/settings' || '/desktop/settings' => AppDestination.settings,
    '/donate' || '/premium' => AppDestination.donate,
    _ => null,
  };
  final tool = switch (uri.path) {
    '/danbooru/explore' => 'danbooru.explore',
    '/danbooru/pools' => 'danbooru.pools',
    '/danbooru/forum_topics' => 'danbooru.forum',
    '/danbooru/artists' => 'danbooru.artists',
    '/danbooru/profile' => 'danbooru.profile',
    '/danbooru/favorite_groups' => 'danbooru.favorite-groups',
    '/internal/danbooru/saved_searches/feed' => 'danbooru.saved-searches',
    '/internal/danbooru/settings/blacklist' => 'danbooru.blacklist',
    '/pixiv/explore' => 'pixiv.explore',
    '/shimmie2/ext_doc' => 'shimmie2.extensions',
    '/szurubooru/pools' => 'szurubooru.pools',
    _ => null,
  };
  DestinationId target;
  var child = '';
  if (global != null) {
    target = DestinationId.app(global);
  } else if (uri.path == '/favorites') {
    final favoriteId = source ?? favoritesProfileId;
    target = favoriteId == null
        ? const DestinationId.app(AppDestination.favoritesRecovery)
        : DestinationId.favorites(favoriteId);
  } else if (tool != null && owner.profileId != null) {
    target = DestinationId.tool(owner.profileId!, tool);
  } else {
    target = uri.path.startsWith('/bookmarks/')
        ? const DestinationId.app(AppDestination.bookmarks)
        : owner;
    if (uri.path != '/') child = uri.path;
  }
  if (!destinations.contains(target)) {
    target = DestinationId.app(
      target.kind == DestinationKind.favorites
          ? AppDestination.favoritesRecovery
          : AppDestination.browseRecovery,
    );
    child = '';
  }
  final query = {...uri.queryParameters, '_profile': ?source};
  return uri
      .replace(
        path: '${target.location}$child',
        queryParameters: query.isEmpty ? null : query,
      )
      .toString();
}

/// Normalizes imperative legacy ingress before the public GoRouter call. A
/// redirect cannot do this: GoRouter's redirect reparsing discards extra.
class NavigationGoRouter extends GoRouter {
  NavigationGoRouter({
    required super.routingConfig,
    required super.navigatorKey,
    required super.initialLocation,
    required this.normalize,
    this.selectAlias,
    this.isDestinationRoot,
    super.observers,
    super.errorBuilder,
  }) : super.routingConfig();
  final String Function(String location, Object? extra) normalize;
  final bool Function(String location, Object? extra)? selectAlias;
  final bool Function(String location)? isDestinationRoot;
  @override
  void go(String location, {Object? extra}) {
    if (selectAlias?.call(location, extra) ?? false) return;
    super.go(normalize(location, extra), extra: extra);
  }

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) {
    if (selectAlias?.call(location, extra) ?? false) return Future.value();
    final resolved = normalize(location, extra);
    if (isDestinationRoot?.call(resolved) ?? false) {
      super.go(resolved, extra: extra);
      return Future.value();
    }
    return super.push<T>(resolved, extra: extra);
  }
}
