// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/cupertino.dart';
import 'package:kurumi/kurumi.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../following_topics/src/widgets/following_definition_entry.dart';
import '../../../../../foundation/platform.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../navigation/destination_id.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../../../../home/types.dart';
import '../../../../router.dart';
import '../pages/search_page.dart';
import 'params.dart';
import 'route_utils.dart';

GoRoute searchRoutes(Ref ref) => GoRoute(
  path: 'search',
  name: '/search',
  pageBuilder: (context, state) {
    final customHomeViewKey = ref.read(customHomeViewKeyProvider);
    final routeContext = switch (state.extra) {
      final SearchRouteContext value => value,
      final BooruConfig config => SearchRouteContext(config: config),
      _ => null,
    };
    final params =
        SearchParams.fromUri(
          state.uri,
        ).withOriginatingTopic(
          routeContext?.originatingTopicId,
          topicOrigin: routeContext?.topicOrigin,
        );

    final destination = DestinationScope.maybeOf(context);
    final local = destination != null;
    final fresh =
        params.query == null && params.tags == null && params.page == null;
    final owner =
        routeContext?.config ??
        ref
            .read(booruConfigProvider)
            .where((c) => c.id == state.uri.queryParameters['_profile'])
            .firstOrNull;
    final searchPage = InheritedInitialSearchQuery(
      params: params,
      child:
          local &&
              owner == null &&
              state.uri.queryParameters.containsKey('_profile')
          ? Center(child: Text(context.t.navigation.unavailable_profile))
          : Consumer(
              builder: (context, routeRef, child) => FollowingDefinitionEntry(
                ready:
                    routeContext == null ||
                    routeRef
                            .watch(
                              booruBuilderProvider(routeContext.config.auth),
                            )
                            ?.searchPageBuilder !=
                        null,
                receipts: routeContext?.followingDefinitionReceipts ?? const {},
                child: child!,
              ),
              child: SearchPage(
                key: state.extra is SearchParams
                    ? ObjectKey(state.extra)
                    : null,
                initialConfig: local ? owner : null,
                closeOnClear:
                    fresh &&
                    (params.fromSearchBar ?? false) &&
                    state.extra is SearchRouteContext &&
                    destination?.id.kind == DestinationKind.browse,
              ),
            ),
    );
    final page = local
        ? searchPage
        : switch (routeContext) {
            final SearchRouteContext routeContext => CurrentBooruConfigScope(
              config: routeContext.config,
              child: searchPage,
            ),
            _ => searchPage,
          };

    // A fresh editor overlays its source timeline until a query is applied.
    // Keep that route painted instead of replacing it with an empty surface.
    if (fresh) {
      return CustomTransitionPage(
        key: state.pageKey,
        name: state.name,
        opaque: false,
        child: page,
        transitionsBuilder: Kurumi.fadeTransitionBuilder(),
      );
    }

    return switch (ref.watch(appPlatformProvider).isDesktop) {
      true => CustomTransitionPage(
        key: state.pageKey,
        name: state.name,
        child: page,
        transitionsBuilder: Kurumi.fadeTransitionBuilder(),
      ),
      false => switch ((
        isAlt: customHomeViewKey?.isAlt ?? false,
        fromSearchBar: params.fromSearchBar ?? false,
      )) {
        (isAlt: true, fromSearchBar: _) => CupertinoPage(
          key: state.pageKey,
          name: state.name,
          child: page,
        ),
        (isAlt: false, fromSearchBar: false) => CupertinoPage(
          key: state.pageKey,
          name: state.name,
          child: page,
        ),
        (isAlt: false, fromSearchBar: true) => CustomTransitionPage(
          key: state.pageKey,
          name: state.name,
          child: page,
          transitionsBuilder: Kurumi.fadeTransitionBuilder(),
        ),
      },
    };
  },
);
