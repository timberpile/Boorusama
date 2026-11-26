import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/client_provider.dart';
import 'package:boorusama/boorus/nhentai/galleries/random.dart';
import 'package:boorusama/boorus/nhentai/galleries/source.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/src/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'fixtures.dart';

void main() {
  testWidgets('Random opens once and shuffles the preview with its tags', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final access = galleryAccess();
    final config = access.config!;
    final secondReady = Completer<void>();
    final revokedReady = Completer<void>();
    final active = StateProvider<ContentAccessContext?>((_) => access);
    var randomReads = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.uri.path, '/api/v2/galleries/random');
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'id': 101 + randomReads++},
              ),
            );
          },
        ),
      );
    final source = NhentaiGallerySource(
      access: access,
      mediaPolicy: () async => galleryPolicy(),
      fetchGallery: (id) async {
        if (id == 102) await secondReady.future;
        if (id == 103) throw StateError('Gallery unavailable under policy');
        if (id == 105) await revokedReady.future;
        return NhentaiGalleryDetails.fromJson({
          ...galleryJson(
            tags: [
              {'id': id, 'type': 'artist', 'name': 'Artist $id'},
            ],
          ),
          'id': id,
          'title': {'english': 'Gallery $id'},
          'thumbnail': null,
        });
      },
    );
    final opened = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => NhentaiRandomPage(config: config),
        ),
        GoRoute(
          path: '/details',
          builder: (_, state) {
            final details = state.extra! as DetailsRouteContext;
            final key = details.entries!.single.contentReference!.sourceKey;
            if (opened.lastOrNull != key) opened.add(key);
            return const Scaffold(body: Text('Gallery viewer'));
          },
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        routerProvider.overrideWithValue(router),
        contentProfileAccessProvider.overrideWith(() => _ProfileAccess(active)),
        contentAccessContextProvider(access.key).overrideWith(
          (ref) => ref.watch(active),
        ),
        contentGroupSourceProvider(access.key).overrideWithValue(source),
        nhentaiDioProvider(config.auth).overrideWithValue(dio),
        booruLoginDetailsProvider(config.auth).overrideWith(
          (_) => const DefaultBooruLoginDetails(
            login: null,
            apiKey: null,
            url: '',
          ),
        ),
        booruChipColorsProvider.overrideWithValue(
          BooruChipColors.colorScheme(
            ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
        ),
        tagColorProvider((config.auth, 'artist'))
            .overrideWithValue(Colors.purple),
      ],
    );
    addTearDown(source.dispose);
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gallery viewer'), findsOneWidget);
    expect(opened, ['gallery:101']);
    router.pop();
    await tester.pumpAndSettle();
    Finder artist(int id) => find.byWidgetPredicate(
      (widget) =>
          widget is TagChip &&
          widget.text == 'Artist $id' &&
          widget.colorOverride == Colors.purple,
    );
    expect(find.text('Gallery 101'), findsOneWidget);
    expect(find.text('nhentai Randomizer'), findsOneWidget);
    expect(artist(101), findsOneWidget);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(randomReads, 1);

    final shuffle = find.widgetWithIcon(IconButton, Symbols.shuffle);
    expect(find.byTooltip('Next Random'), findsOneWidget);
    await tester.tap(shuffle);
    await tester.tap(shuffle);
    await tester.pump();
    expect(find.text('Gallery 101'), findsOneWidget);
    expect(tester.widget<IconButton>(shuffle).onPressed, isNull);
    secondReady.complete();
    await tester.pumpAndSettle();
    expect(randomReads, 2);
    expect(find.text('Gallery 102'), findsOneWidget);
    expect(artist(102), findsOneWidget);
    expect(artist(101), findsNothing);
    expect(opened, ['gallery:101']);

    await tester.tap(shuffle);
    await tester.pumpAndSettle();
    expect(find.text('Gallery 102'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery 104'), findsOneWidget);
    await tester.tap(find.byType(PoolGridItem));
    await tester.pumpAndSettle();
    expect(opened, ['gallery:101', 'gallery:104']);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(shuffle);
    await tester.pump();
    container.read(active.notifier).state = null;
    revokedReady.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PoolGridItem), findsNothing);
    expect(artist(104), findsNothing);
    expect(opened, ['gallery:101', 'gallery:104']);
    expect(tester.takeException(), isNull);
  });
}

class _ProfileAccess extends ContentProfileAccess {
  _ProfileAccess(this.profile);

  final StateProvider<ContentAccessContext?> profile;

  @override
  ContentAccessContext? build(String profileId) => ref.watch(profile);
}
