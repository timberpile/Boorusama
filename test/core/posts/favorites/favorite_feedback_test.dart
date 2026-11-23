import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_controller.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/simple_post_action_toolbar.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/haptics/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:oktoast/oktoast.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  for (final supported in [false, true]) {
    testWidgets(
      'unknown status leaves Add usable (lookup supported: $supported)',
      (
        tester,
      ) async {
        final reply = Completer<List<int>?>();
        var lookups = 0;
        var adds = 0;
        final post = TestPost(id: 7);
        final container = await _mount(
          tester,
          _repo(
            add: (_) async {
              adds++;
              return AddFavoriteStatus.success;
            },
            filter: supported
                ? (_) {
                    lookups++;
                    return reply.future;
                  }
                : null,
          ),
          body: FavoriteContextMenuTile(post: post),
        );

        final row = find.byType(KurumiContextMenuTile);
        expect(tester.widget<KurumiContextMenuTile>(row).enabled, !supported);
        reply.complete(null);
        await tester.pumpAndSettle();
        expect(tester.widget<KurumiContextMenuTile>(row).enabled, true);
        expect(
          container.read(favoriteStatusProvider((_profile.auth, 7))),
          isNull,
        );
        expect(lookups, supported ? 1 : 0);
        tester.widget<KurumiContextMenuTile>(row).onTap!();
        await tester.pumpAndSettle();
        expect(adds, 1);
        expect(lookups, supported ? 1 : 0);
        expect(tester.widget<KurumiContextMenuTile>(row).title, 'Unfavorite');
        await tester.pump(KurumiDurations.shortToast);
      },
    );
  }

  testWidgets(
    'own-Favorites evidence feeds the grid heart, toolbar overflow, menu and gesture',
    (
      tester,
    ) async {
      final post = TestPost(id: 7);
      final details = PostDetailsController(
        scrollController: null,
        initialPage: 0,
        posts: [post],
        initialThumbnailUrl: null,
        reduceAnimations: true,
        dislclaimer: null,
        doubleTapSeekDuration: 5,
      );
      addTearDown(details.dispose);
      final view = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 1,
        checkIfLargeScreen: () => false,
      );
      addTearDown(view.dispose);
      final remove = Completer<bool>();
      var removals = 0;
      var adds = 0;
      final container = await _mount(
        tester,
        _repo(
          add: (_) async {
            adds++;
            return AddFavoriteStatus.success;
          },
          remove: (_) {
            removals++;
            return remove.future;
          },
        ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultQuickFavoriteButton(post: post),
            PostDetails(
              data: PostDetailsData(posts: [post], controller: details),
              child: PostDetailsPageViewScope(
                controller: view,
                child: PostActionToolbarScope(
                  additionalButtons: const [],
                  bookmarkButton: const Icon(Icons.bookmark_border),
                  groupBookmarkButton: const Icon(Icons.bookmarks_outlined),
                  child: SizedBox(
                    width: 172,
                    child: DefaultPostActionToolbar(post: post),
                  ),
                ),
              ),
            ),
            FavoriteContextMenuTile(post: post),
            Consumer(
              builder: (_, ref, _) => TextButton(
                onPressed: () => ref.toggleFavorite(7),
                child: const Text('Toggle'),
              ),
            ),
          ],
        ),
      );

      final notifier = container.read(
        favoritesProvider(_profile.auth).notifier,
      );
      notifier.observeOwnFavorites([7], notifier.beginRead(), owner: '42');
      await tester.pumpAndSettle();
      expect(_heartFill(tester), 1);
      expect(find.text('Unfavorite'), findsOneWidget);
      expect(find.text('Added to favorites'), findsNothing);
      expect(adds, 0);
      expect(removals, 0);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      final overflowAction = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Unfavorite' &&
            (widget.properties.button ?? false),
      );
      final contextMenuRow = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(KurumiContextMenuTile),
          matching: overflowAction,
        ),
      );
      final overflowRow = tester
          .widgetList<Semantics>(overflowAction)
          .singleWhere((widget) => !identical(widget, contextMenuRow));
      await tester.tap(find.byWidget(overflowRow));
      await tester.pumpAndSettle();
      expect(removals, 1);
      remove.complete(false);
      await tester.pump();
      await tester.pump();
      expect(_heartFill(tester), 1);
      expect(find.text('Failed to update favorites'), findsOneWidget);
      await tester.pump(KurumiDurations.shortToast);

      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(removals, 2);
      expect(adds, 0);
      await tester.pump(KurumiDurations.shortToast);
    },
  );

  for (final status in AddFavoriteStatus.values) {
    testWidgets('gesture feedback follows ${status.name}', (tester) async {
      final repo = _repo(add: (_) async => status);
      final container = await _mount(tester, repo, quick: false);
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      expect(
        find.text('Added to favorites'),
        status.confirmed ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Failed to update favorites'),
        status.confirmed ? findsNothing : findsOneWidget,
      );
      expect(
        container.read(favoriteProvider((_profile.auth, 7))),
        status.confirmed,
      );
      await tester.pump(KurumiDurations.shortToast);
    });
  }

  testWidgets('API-only gesture explains browser login without a mutation', (
    tester,
  ) async {
    var calls = 0;
    final repo = _repo(
      add: (_) async {
        calls++;
        return AddFavoriteStatus.failure;
      },
      needsWebsiteLogin: true,
    );
    final container = await _mount(
      tester,
      repo,
      quick: false,
      profile: _apiOnly,
    );
    await tester.tap(find.text('Toggle'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(container.read(favoritesProvider(_apiOnly.auth)), isEmpty);
    expect(find.textContaining('Website login required'), findsOneWidget);
    expect(find.text('Added to favorites'), findsNothing);
    await tester.pump(KurumiDurations.shortToast);
  });

  testWidgets('rejected website session provides relogin feedback', (
    tester,
  ) async {
    final repo = _repo(
      add: (_) async => throw FavoriteActionFailure.websiteSessionRejected,
    );
    final container = await _mount(tester, repo, quick: false);
    await tester.tap(find.text('Toggle'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Use Re-login'), findsOneWidget);
    expect(find.text('Added to favorites'), findsNothing);
    expect(container.read(favoritesProvider(_profile.auth)), isEmpty);
    await tester.pump(KurumiDurations.shortToast);
  });

  testWidgets('failed quick add never fills the heart or vibrates', (
    tester,
  ) async {
    final reply = Completer<AddFavoriteStatus>();
    final container = await _mount(tester, _repo(add: (_) => reply.future));
    var impacts = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') impacts++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.byIcon(Symbols.favorite));
    await tester.pump();
    expect(container.read(favoriteProvider((_profile.auth, 7))), true);
    expect(_heartFill(tester), 0);
    reply.complete(AddFavoriteStatus.failure);
    await tester.pumpAndSettle();

    expect(_heartFill(tester), 0);
    expect(impacts, 0);
    expect(container.read(favoriteProvider((_profile.auth, 7))), false);
    expect(find.text('Failed to update favorites'), findsOneWidget);
    await tester.pump(KurumiDurations.shortToast);
  });

  testWidgets('quick remove holds the heart until the server confirms', (
    tester,
  ) async {
    final reply = Completer<bool>();
    final container = await _mount(tester, _repo(remove: (_) => reply.future));
    final notifier = container.read(favoritesProvider(_profile.auth).notifier);
    await notifier.add(7);
    await tester.pumpAndSettle();
    expect(_heartFill(tester), 1);

    await tester.tap(find.byIcon(Symbols.favorite));
    await tester.pump();
    expect(container.read(favoriteProvider((_profile.auth, 7))), false);
    expect(_heartFill(tester), 1);
    reply.complete(false);
    await tester.pumpAndSettle();

    expect(_heartFill(tester), 1);
    expect(container.read(favoriteProvider((_profile.auth, 7))), true);
    expect(find.text('Failed to update favorites'), findsOneWidget);
    await tester.pump(KurumiDurations.shortToast);
  });

  testWidgets('quick add updates the heart only after confirmation', (
    tester,
  ) async {
    final reply = Completer<AddFavoriteStatus>();
    await _mount(tester, _repo(add: (_) => reply.future));

    await tester.tap(find.byIcon(Symbols.favorite));
    await tester.pump();
    expect(_heartFill(tester), 0);
    reply.complete(AddFavoriteStatus.success);
    await tester.pumpAndSettle();

    expect(_heartFill(tester), 1);
    expect(find.text('Failed to update favorites'), findsNothing);
  });

  testWidgets(
    'quick completion for the previous account cannot update the new heart',
    (tester) async {
      final reply = Completer<AddFavoriteStatus>();
      final active = ValueNotifier(_profile);
      addTearDown(active.dispose);
      final container = await _mount(
        tester,
        _repo(add: (_) => reply.future),
        active: active,
      );
      await tester.tap(find.byIcon(Symbols.favorite));
      await tester.pump();

      final another = BooruConfig.fromJson({
        ..._profile.toJson(),
        'id': '00000000-0000-4000-8000-000000000002',
        'login': '43',
        'passHash': 'fake-other-session',
      });
      active.value = another;
      await tester.pumpAndSettle();
      reply.complete(AddFavoriteStatus.success);
      await tester.pumpAndSettle();

      expect(_heartFill(tester), 0);
      expect(container.read(favoriteProvider((another.auth, 7))), false);
      expect(container.read(favoriteProvider((_profile.auth, 7))), true);
    },
  );
}

final _apiOnly = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://rule34.xxx/',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-000000000001',
  'login': '42',
  'apiKey': 'fake-api-key',
});
final _profile = BooruConfig.fromJson({
  ..._apiOnly.toJson(),
  'passHash': 'fake-session',
});

FavoriteRepository _repo({
  Future<AddFavoriteStatus> Function(int)? add,
  Future<bool> Function(int)? remove,
  bool needsWebsiteLogin = false,
  Future<List<int>?> Function(List<int>)? filter,
}) => FavoriteRepositoryBuilder(
  add: add ?? (_) async => AddFavoriteStatus.success,
  remove: remove ?? (_) async => true,
  filter: filter,
  canFavorite: () => !needsWebsiteLogin,
  needsWebsiteLogin: needsWebsiteLogin,
);

double? _heartFill(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Symbols.favorite)).fill;

Future<ProviderContainer> _mount(
  WidgetTester tester,
  FavoriteRepository repo, {
  bool quick = true,
  BooruConfig? profile,
  ValueNotifier<BooruConfig>? active,
  Widget? body,
}) async {
  tester.view.physicalSize = const Size(320, 560);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final config = StateProvider((ref) => profile ?? _profile);
  final container = ProviderContainer(
    overrides: [
      currentReadOnlyBooruConfigProvider.overrideWith(
        (ref) => ref.watch(config),
      ),
      currentReadOnlyBooruConfigAuthProvider.overrideWith(
        (ref) => ref.watch(config).auth,
      ),
      favoriteRepoProvider.overrideWith((ref, auth) => repo),
      profileFavoriteRepoProvider.overrideWith((ref, key) => repo),
      booruLoginDetailsProvider.overrideWith(
        (ref, auth) => ApiAndCookieBasedLoginDetails(config: auth),
      ),
      currentReadOnlyBooruConfigViewerProvider.overrideWith(
        (ref) => ref.watch(config).viewer,
      ),
      currentReadOnlyBooruConfigDownloadProvider.overrideWith(
        (ref) => ref.watch(config).download,
      ),
      booruBuilderProvider.overrideWith((ref, auth) => null),
      booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
      imageViewerSettingsProvider.overrideWithValue(
        Settings.defaultSettings.viewer,
      ),
      settingsProvider.overrideWithValue(Settings.defaultSettings),
      hapticFeedbackLevelProvider.overrideWithValue(HapticFeedbackLevel.full),
    ],
  );
  addTearDown(container.dispose);
  active?.addListener(
    () => container.read(config.notifier).state = active.value,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: Kurumi.themeFrom(
            KurumiThemeMode.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            systemDarkMode: false,
          ).withBoorusamaColors(),
          builder: (context, child) => OKToast(
            child: KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
            ),
          ),
          home: Scaffold(
            body: Center(
              child:
                  body ??
                  (quick
                      ? DefaultQuickFavoriteButton(post: TestPost(id: 7))
                      : Consumer(
                          builder: (context, ref, child) => TextButton(
                            onPressed: () => ref.toggleFavorite(7),
                            child: const Text('Toggle'),
                          ),
                        )),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
