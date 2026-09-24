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

GoRoute searchRoutes(Ref ref) => GoRoute(
  path: 'search',
  name: '/search',
  pageBuilder: (context, state) {
    final customHomeViewKey = ref.read(customHomeViewKeyProvider);
    final params = SearchParams.fromUri(state.uri);

    final searchPage = InheritedInitialSearchQuery(
      params: params,
      child: const SearchPage(),
    );
    final page = switch (state.extra) {
      final BooruConfig config => CurrentBooruConfigScope(
        config: config,
        child: searchPage,
      ),
      _ => searchPage,
    };

    return switch (isDesktopPlatform()) {
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
