import 'following_topic_test_utils.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/search/src/routes/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:boorusama/core/boorus/defaults/src/base_booru_builder.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

/// Uses the production shared Search scaffold with deterministic preview results.
class TopicQueryTestBuilder extends BaseBooruBuilder {
  TopicQueryTestBuilder({this.onController, this.onFetch, this.posts});
  final List<Post> Function()? posts;
  final void Function(BooruConfig, SearchPageController)? onController;
  final void Function(BooruConfig, String)? onFetch;

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => Consumer(
        builder: (context, ref, _) {
          final config = ref.watchConfig;
          return SearchPageScaffold<Post>(
            params: params,
            fetcher: (page, tags) {
              onFetch?.call(config, tags.rawTagsString);
              final result = posts?.call() ?? const <Post>[];
              return TaskEither.of(
                PostResult(posts: result, total: result.length),
              );
            },
            landingViewBuilder: (_) => const SizedBox.expand(),
            searchRegionBuilder: (posts, controller) {
              onController?.call(config, controller);
              return DefaultSearchRegion(
                controller: controller,
                postController: posts,
              );
            },
          );
        },
      );
}

final _topicRouterHomes = Expando<ValueNotifier<Widget>>();

/// Uses the production Search route so child pages share its Navigator.
Future<void> pumpTopicQueryRouter(
  FollowingTopicHarness harness,
  WidgetTester tester,
  Widget home, {
  Widget Function(BuildContext, GoRouterState)? detailsBuilder,
}) async {
  final existing = _topicRouterHomes[harness];
  if (existing != null) {
    existing.value = home;
    await settle(tester);
    return;
  }
  final homeValue = ValueNotifier(home);
  _topicRouterHomes[harness] = homeValue;
  addTearDown(homeValue.dispose);
  await ensureI18nInitialized('en-US');
  final provider = Provider<GoRouter>(
    (ref) => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder(
            valueListenable: homeValue,
            builder: (_, home, _) => home,
          ),
          routes: [searchRoutes(ref)],
        ),
        GoRoute(
          path: '/details',
          builder:
              detailsBuilder ??
              (_, _) => const Scaffold(body: Text('Post details')),
        ),
      ],
    ),
  );
  harness.router = harness.container.read(provider);
  addTearDown(harness.router.dispose);
  await tester.pumpWidget(
    harness.wrap(
      MaterialApp.router(
        routerConfig: harness.router,
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: themeBuilder,
      ),
    ),
  );
  await settle(tester);
}
