import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/favorites/account.dart';
import 'package:boorusama/boorus/nhentai/favorites/control.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/listing/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/haptics/types.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../support/fakes/memory_repositories.dart';
import 'fixtures.dart';

Finder _tooltip(String text) => find.byWidgetPredicate(
  (widget) => widget is KurumiTooltip && widget.message == text,
);

void main() {
  testWidgets('the favorite control contributes no action without a key', (
    tester,
  ) async {
    final access = galleryAccess();
    int? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAccessContextProvider(access.key).overrideWithValue(access),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  NhentaiFavoriteControl(access: access, galleryId: 101),
                  NhentaiGalleryQuickFavorite(access: access, galleryId: 101),
                  NhentaiFavoriteControl(
                    access: access,
                    galleryId: 101,
                    builder: (_, buttons) {
                      actions = buttons.length;
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Symbols.favorite), findsNothing);
    expect(actions, 0);
  });

  testWidgets('Gallery thumbnail and viewer share confirmed favorite state', (
    tester,
  ) async {
    final config = galleryAccess().config!.copyWith(
      apiKey: 'synthetic-gallery-api-key',
    );
    final access = ContentAccessContext.profile(
      config: config,
      authEpoch: 1,
      policyEpoch: 1,
    );
    final profiles = _Profiles([config]);
    final requests = <(String, String)>[];
    final favoriteReady = Completer<void>();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var favorited = false;
    var opened = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            requests.add((request.method, request.uri.path));
            switch (request.method) {
              case 'POST':
                await favoriteReady.future;
                favorited = true;
              case 'DELETE':
                favorited = false;
            }
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'favorited': favorited},
              ),
            );
          },
        ),
      );
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(() => profiles),
        persistentCacheStoreProvider.overrideWithValue(
          MemoryPersistentCacheStore(),
        ),
        hapticFeedbackLevelProvider.overrideWithValue(HapticFeedbackLevel.none),
        nhentaiAccountClientProvider(access.key).overrideWith(
          (ref) => NhentaiAccountClient(dio: dio),
        ),
      ],
    );
    addTearDown(container.dispose);
    final revisions = <int>[];
    final sub = container.listen(
      nhentaiFavoritesRevisionProvider(access.key),
      (_, next) => revisions.add(next),
    );
    addTearDown(sub.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            theme: Kurumi.themeFrom(
              KurumiThemeMode.light,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              systemDarkMode: false,
            ),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    NhentaiFavoriteControl(access: access, galleryId: 101),
                    SizedBox(
                      width: 140,
                      height: 180,
                      child: PoolGridItem(
                        image: const SizedBox.expand(),
                        onTap: () => opened++,
                        name: 'Gallery',
                        total: 5,
                        trailingAction: NhentaiGalleryQuickFavorite(
                          access: access,
                          galleryId: 101,
                        ),
                      ),
                    ),
                    const SizedBox(height: 800),
                    NhentaiGalleryQuickFavorite(access: access, galleryId: 102),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final quick = find.descendant(
      of: find.byType(PoolGridItem),
      matching: find.byType(QuickFavoriteButton),
    );
    expect(quick, findsOneWidget);
    final initialHeart = tester.widget<QuickFavoriteButton>(quick);
    expect(initialHeart.enabled, isTrue);
    expect(initialHeart.isFaved, isFalse);
    expect(requests, isEmpty);

    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(find.byType(QuickFavoriteButton).hitTestable(), findsOneWidget);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    final viewerHeart = find.descendant(
      of: find.byType(NhentaiFavoriteControl).first,
      matching: find.byIcon(Symbols.favorite),
    );
    expect(quick, findsOneWidget);
    expect(tester.getSize(quick), const Size.square(48));
    expect(tester.widget<QuickFavoriteButton>(quick).enabled, isTrue);
    expect(tester.widget<QuickFavoriteButton>(quick).isFaved, isFalse);
    expect(requests, isEmpty);
    await tester.tap(quick);
    await tester.pump();
    expect(tester.widget<QuickFavoriteButton>(quick).enabled, isFalse);
    expect(tester.widget<QuickFavoriteButton>(quick).isFaved, isFalse);
    expect(revisions, isEmpty);
    favoriteReady.complete();
    await tester.pumpAndSettle();
    expect(_tooltip('Unfavorite').hitTestable(), findsNWidgets(2));
    expect(tester.widget<QuickFavoriteButton>(quick).isFaved, isTrue);
    expect(opened, 0);
    expect(revisions, [1]);
    await tester.tap(viewerHeart);
    await tester.pumpAndSettle();
    expect(_tooltip('Favorite').hitTestable(), findsNWidgets(2));
    expect(tester.widget<QuickFavoriteButton>(quick).isFaved, isFalse);
    expect(revisions, [1, 2]);
    await tester.tap(find.byType(PoolGridItem));
    expect(opened, 1);
    profiles.replace(
      config.copyWith(thumbnailActions: const ThumbnailActions.none()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuickFavoriteButton), findsNothing);
    expect(viewerHeart, findsOneWidget);
    expect(requests, [
      ('POST', '/api/v2/galleries/101/favorite'),
      ('DELETE', '/api/v2/galleries/101/favorite'),
    ]);
  });
}

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> configs) : super(initialConfigs: configs);

  void replace(BooruConfig profile) => state = [profile];
}
