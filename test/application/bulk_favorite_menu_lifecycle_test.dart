import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/src/types/favorite_interruption.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/listing/src/types/post_action_snapshot.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_actions.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'bulk selection checks unknown favorites together and waits for the result',
    (
      tester,
    ) async {
      final ids = List.generate(128, (index) => index + 101);
      final lookups = <List<int>>[];
      final response = Completer<List<int>?>();
      final flow = await _MenuFlow.mount(
        tester,
        add: (_) => fail('Opening the menu must not change favorites'),
        postIds: ids,
        lookup: (unknownIds) {
          lookups.add(unknownIds);
          return response.future;
        },
      );
      final favorites = flow.container.read(
        favoritesProvider(flow.profile.auth).notifier,
      );
      favorites.observeFavorites({ids.first: true}, favorites.beginRead());
      await flow.open(tester);
      await flow.harness.pumpUntil(tester, () => lookups.isNotEmpty);
      expect(lookups, [ids.skip(1).toList()]);
      expect(
        tester
            .widget<KurumiContextMenuTile>(
              find.widgetWithText(KurumiContextMenuTile, 'Favorite'),
            )
            .enabled,
        isFalse,
      );
      response.complete(ids.skip(1).toList());
      await flow.harness.pumpUntilFound(tester, find.text('Unfavorite'));
      expect(
        tester
            .widget<KurumiContextMenuTile>(
              find.widgetWithText(KurumiContextMenuTile, 'Unfavorite'),
            )
            .enabled,
        isTrue,
      );
      expect(lookups, hasLength(1));
    },
  );

  testWidgets('bulk Favorites finish after the access-bound menu closes', (
    tester,
  ) async {
    final first = Completer<AddFavoriteStatus>();
    final flow = await _MenuFlow.mount(
      tester,
      add: (id) =>
          id == 101 ? first.future : Future.value(AddFavoriteStatus.success),
      accessBound: true,
    );
    await flow.open(tester);
    await tester.tap(find.text('Favorite'));
    await flow.harness.settle(tester);
    expect(find.byType(PostContextMenuActions), findsNothing);
    expect(flow.adds, [101]);

    first.complete(AddFavoriteStatus.success);
    await flow.harness.pumpUntilFound(tester, find.text('Favorites updated'));
    expect(flow.adds, [101, 102]);
    expect(tester.takeException(), isNull);
    await _clearFeedback(tester);
  });

  testWidgets(
    'deleting the originating account stops the remaining selection',
    (
      tester,
    ) async {
      final first = Completer<AddFavoriteStatus>();
      final flow = await _MenuFlow.mount(tester, add: (_) => first.future);
      await flow.open(tester);
      await tester.tap(find.text('Favorite'));
      await flow.harness.settle(tester);
      expect(flow.adds, [101]);

      flow.changeAccount(delete: true);
      first.complete(AddFavoriteStatus.success);
      await flow.harness.settle(tester);
      expect(flow.adds, [101]);
      _expectNoFeedback(tester);
    },
  );

  for (final (outcome, complete)
      in <(String, void Function(Completer<AddFavoriteStatus>))>[
        ('success', (response) => response.complete(AddFavoriteStatus.success)),
        ('failure', (response) => response.complete(AddFavoriteStatus.failure)),
        (
          'cleanup interruption',
          (response) {
            response.completeError(
              FavoriteCompletedWithInterruption(
                DioException(
                  requestOptions: RequestOptions(path: '/fixture-cleanup'),
                  error: ApiCooldownException(
                    ApiQuotaKey.fromUri(Uri.parse('https://fixture.test')),
                    DateTime.now().toUtc().add(const Duration(minutes: 1)),
                  ),
                ),
                StackTrace.current,
              ),
            );
          },
        ),
      ]) {
    testWidgets(
      'replacing the account during the final mutation hides $outcome',
      (
        tester,
      ) async {
        final last = Completer<AddFavoriteStatus>();
        final flow = await _MenuFlow.mount(
          tester,
          add: (id) =>
              id == 102 ? last.future : Future.value(AddFavoriteStatus.success),
          accessBound: true,
        );
        await flow.open(tester);
        await tester.tap(find.text('Favorite'));
        await flow.harness.pumpUntil(tester, () => flow.adds.length == 2);

        final replacement = flow.changeAccount();
        await tester.pump();
        complete(last);
        await flow.harness.settle(tester);
        expect(flow.adds, [101, 102]);
        expect(
          flow.container.read(favoritesProvider(replacement.auth)),
          isEmpty,
        );
        _expectNoFeedback(tester);
      },
    );
  }

  testWidgets('menu Unfavorite cannot overtake the quick heart and can retry', (
    tester,
  ) async {
    final add = Completer<AddFavoriteStatus>();
    final flow = await _MenuFlow.mount(
      tester,
      add: (_) => add.future,
      postIds: [101],
    );
    await tester.tap(find.byType(QuickFavoriteButton));
    await flow.harness.pumpUntil(tester, () => flow.adds.isNotEmpty);
    await flow.open(tester);
    await tester.tap(find.text('Unfavorite'));
    await flow.harness.settle(tester);
    expect(flow.adds, [101]);
    expect(flow.removes, isEmpty);
    await _clearFeedback(tester);
    add.complete(AddFavoriteStatus.success);
    await flow.harness.settle(tester);

    await flow.open(tester);
    await tester.tap(find.text('Unfavorite'));
    await flow.harness.pumpUntilFound(tester, find.text('Favorites updated'));
    expect(flow.adds, [101]);
    expect(flow.removes, [101]);
    expect(
      tester
          .widget<QuickFavoriteButton>(find.byType(QuickFavoriteButton))
          .isFaved,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await _clearFeedback(tester);
  });
}

void _expectNoFeedback(WidgetTester tester) {
  expect(find.text('Favorites updated'), findsNothing);
  expect(find.text('Failed to update favorites'), findsNothing);
  expect(
    find.text('Could not complete the post action. Try again.'),
    findsNothing,
  );
  expect(find.textContaining('Rate limited by the site'), findsNothing);
  expect(tester.takeException(), isNull);
}

Future<void> _clearFeedback(WidgetTester tester) async {
  dismissAllToast();
  await tester.pump(const Duration(seconds: 4));
}

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
  void replace(List<BooruConfig> profiles) => state = profiles;
}

class _MenuFlow {
  _MenuFlow(
    this.harness,
    this.container,
    this.profile,
    this.adds,
    this.removes,
  );

  final HeadlessAppHarness harness;
  final ProviderContainer container;
  final BooruConfig profile;
  final List<int> adds;
  final List<int> removes;

  static Future<_MenuFlow> mount(
    WidgetTester tester, {
    required Future<AddFavoriteStatus> Function(int) add,
    List<int> postIds = const [101, 102],
    Future<List<int>?> Function(List<int>)? lookup,
    bool accessBound = false,
  }) async {
    final backend = FakeBooruBackend();
    final profile = BooruConfig.fromJson({
      ...backend.config.toJson(),
      'login': 'fixture-user',
      'apiKey': 'fixture-key',
    });
    final configs = [profile, backend.configB];
    final access = ContentAccessContext.profile(
      config: profile,
      authEpoch: 1,
      policyEpoch: 1,
    );
    final adds = <int>[];
    final removes = <int>[];
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      phone: TestPhone.smallPortrait,
      runtime: backend.createRuntime(
        configs: configs,
        initialConfig: backend.configB,
      ),
      additionalOverrides: [
        booruConfigProvider.overrideWith(() => _Profiles(configs)),
        if (accessBound)
          contentAccessContextProvider(access.key)
              .overrideWith((ref) => access),
        favoriteRepoProvider(profile.auth).overrideWithValue(
          FavoriteRepositoryBuilder(
            canFavorite: () => true,
            filter: lookup,
            add: (id) {
              adds.add(id);
              return add(id);
            },
            remove: (id) async {
              removes.add(id);
              return true;
            },
          ),
        ),
      ],
    );
    await harness.pumpUntilFound(tester, postTile(201));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final context = tester.element(postTile(201));
    final container = ProviderScope.containerOf(context);
    final posts = [
      for (final id in postIds)
        TestPost(
          id: id,
          origin: PostOrigin.fromSource(
            booruType: profile.auth.booruType,
            booruId: profile.booruId,
            source: profile.url,
            profileIdHint: profile.id,
          ),
        ),
    ];
    final menu = KurumiContextMenuController();
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: CurrentBooruConfigScope(
            config: profile,
            requireAccess: accessBound,
            accessKey: accessBound ? access.key : null,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (postIds.length == 1)
                    DefaultQuickFavoriteButton(post: posts.single),
                  KurumiContextMenu(
                    controller: menu,
                    menuItemsBuilder: (_) => [
                      Consumer(
                        builder: (context, ref, _) => PostContextMenuActions(
                          snapshot: PostActionSnapshot.watch(ref, posts),
                        ),
                      ),
                    ],
                    child: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => menu.showAt(
                          (context.findRenderObject()! as RenderBox)
                              .localToGlobal(Offset.zero),
                        ),
                        child: const Text('Open post actions'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await harness.settle(tester);
    return _MenuFlow(harness, container, profile, adds, removes);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open post actions'));
    await harness.pumpUntilFound(tester, find.byType(PostContextMenuActions));
  }

  BooruConfig changeAccount({bool delete = false}) {
    final replacement = BooruConfig.fromJson({
      ...profile.toJson(),
      'login': 'replacement-user',
      'apiKey': 'replacement-key',
    });
    (container.read(booruConfigProvider.notifier) as _Profiles).replace([
      if (!delete) replacement,
      harness.booruBackend.configB,
    ]);
    return replacement;
  }
}
