// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/cupertino.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import '../../../../../foundation/platform.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/widgets.dart';
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
    final params = SearchParams.fromUri(
      state.uri,
    ).withOriginatingTopic(routeContext?.originatingTopicId);

    final searchPage = InheritedInitialSearchQuery(
      params: params,
      child: const SearchPage(),
    );
    final page = switch (routeContext) {
      final SearchRouteContext routeContext => CurrentBooruConfigScope(
        config: routeContext.config,
        child: searchPage,
      ),
      _ => searchPage,
    };

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
