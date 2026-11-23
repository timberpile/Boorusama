import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/following/artist_card.dart';
import 'package:boorusama/boorus/pixiv/following/page.dart';
import 'package:boorusama/boorus/pixiv/following/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

final _a = _profile(100, testProfile.id);
final _b = _profile(200, otherTestProfile.id);
final _current = StateProvider<BooruConfig>((ref) => _a);

void main() {
  testWidgets(
    'near-end scrolling loads once, pauses on failure, retries and stops at exhaustion',
    (tester) async {
      final calls = <_Request>[];
      final harness = _paginationHarness(calls);
      await harness.pump(tester, PixivFollowingArtistsPage(config: _a));
      await _until(tester, () => calls.length == 1);
      calls.single.complete(1000, count: 60, nextOffset: 60);
      await _until(tester, () => _artists(harness).length == 60);
      await tester.pumpAndSettle();
      final position = _position(tester);
      position.jumpTo(100);
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      position.jumpTo(position.maxScrollExtent - position.viewportDimension);
      await _until(tester, () => calls.length == 2);
      expect(position.extentAfter, greaterThan(0));
      expect(calls.last.options.queryParameters['offset'], 60);
      position.jumpTo(position.pixels + 10);
      position.jumpTo(position.pixels + 10);
      await tester.pump();
      expect(calls, hasLength(2));
      calls.last.response.complete(ResponseBody.fromString('{}', 503));
      await _until(
        tester,
        () => harness.container.read(_following(_a)).requireValue.failedMore,
      );
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(_artists(harness), hasLength(60));
      await tester.tap(find.text('Retry'));
      await _until(tester, () => calls.length == 3);
      expect(calls.last.options.queryParameters['offset'], 60);
      calls.last.complete(1060, count: 30);
      await _until(tester, () => _artists(harness).length == 90);
      await tester.pumpAndSettle();
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(calls, hasLength(3));
      expect(
        harness.container.read(_following(_a)).requireValue.hasMore,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('short Following pages retain manual continuation', (
    tester,
  ) async {
    final calls = <_Request>[];
    final harness = _paginationHarness(calls);
    await harness.pump(tester, PixivFollowingArtistsPage(config: _a));
    await _until(tester, () => calls.length == 1);
    calls.single.complete(1000, nextOffset: 30);
    await _until(tester, () => _artists(harness).length == 1);
    await tester.pumpAndSettle();
    expect(find.text('Load More').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Load More'));
    await _until(tester, () => calls.length == 2);
    expect(calls.last.options.queryParameters['offset'], 30);
    calls.last.complete(1001);
    await _until(tester, () => _artists(harness).length == 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('privacy and account changes cancel automatic continuation', (
    tester,
  ) async {
    final calls = <_Request>[];
    final harness = _paginationHarness(calls);
    await harness.pump(
      tester,
      Consumer(
        builder: (context, ref, _) =>
            PixivFollowingArtistsPage(config: ref.watch(_current)),
      ),
    );
    await _until(tester, () => calls.length == 1);
    calls.single.complete(1000, count: 60, nextOffset: 60);
    await _until(tester, () => _artists(harness).length == 60);
    await tester.pumpAndSettle();
    var position = _position(tester);
    position.jumpTo(position.maxScrollExtent - position.viewportDimension);
    await _until(tester, () => calls.length == 2);
    final publicMore = calls.last;
    position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private'));
    await _until(tester, () => calls.length == 3);
    await _until(tester, () => publicMore.cancelled);
    expect(calls.last.options.queryParameters['restrict'], 'private');
    calls.last.complete(2000, count: 30, nextOffset: 30);
    publicMore.complete(1060);
    await _until(tester, () => _artists(harness, private: true).length == 30);
    await tester.pumpAndSettle();
    position = _position(tester);
    position.jumpTo(position.maxScrollExtent - position.viewportDimension);
    await _until(tester, () => calls.length == 4);
    final privateMore = calls.last;
    expect(privateMore.options.queryParameters['offset'], 30);
    harness.container.read(_current.notifier).state = _b;
    await _until(tester, () => calls.length == 5);
    await _until(tester, () => privateMore.cancelled);
    expect(calls.last.options.queryParameters['user_id'], 200);
    expect(calls.last.options.queryParameters['offset'], 0);
    calls.last.complete(3000);
    privateMore.complete(2030);
    await _until(tester, () => _artists(harness, config: _b).length == 1);
    expect(_artists(harness, config: _b).single.user.id, 3000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'long Following lists show privacy only at the top after each switch',
    (tester) async {
      final calls = <_Request>[];
      final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl))
        ..httpClientAdapter = _Adapter(calls);
      final harness = FollowingTopicHarness(
        profiles: [_a],
        overrides: [
          pixivClientProvider.overrideWith(
            (ref, auth) => PixivClient(accessToken: 'fixture-access', dio: dio),
          ),
        ],
      );
      addTearDown(() {
        harness.dispose();
        dio.close(force: true);
      });
      await harness.pump(tester, PixivFollowingArtistsPage(config: _a));
      await _until(tester, () => calls.isNotEmpty);
      for (var pass = 0; pass < 2; pass++) {
        calls.last.complete(1000 + pass * 100, count: 60);
        await _until(
          tester,
          () => find.byType(PixivFollowingArtistCard).evaluate().isNotEmpty,
        );
        final privacy = find.byKey(
          const ValueKey('pixiv-following-privacy'),
          skipOffstage: false,
        );
        expect(privacy.hitTestable(), findsOneWidget);
        expect(find.text('Public').hitTestable(), findsOneWidget);
        expect(find.text('Private').hitTestable(), findsOneWidget);
        expect(
          tester.getCenter(find.text('Public')).dy,
          closeTo(tester.getCenter(find.text('Private')).dy, .5),
        );
        for (var i = 0; i < 3; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -700),
          );
          await tester.pumpAndSettle();
        }
        expect(privacy.hitTestable(), findsNothing);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 40));
        await tester.pumpAndSettle();
        expect(privacy.hitTestable(), findsNothing);
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.pixels, greaterThan(1000));
        expect(calls, hasLength(pass + 1));
        scroll.position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(privacy.hitTestable(), findsOneWidget);
        if (pass == 0) {
          await tester.tap(find.text('Private'));
          await _until(tester, () => calls.length == 2);
          expect(calls.last.options.queryParameters['restrict'], 'private');
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'real Following page isolates privacy and account then opens source Search without extra requests',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final calls = <_Request>[];
      final clients = <Dio>[];
      final harness = FollowingTopicHarness(
        profiles: [_a, _b],
        overrides: [
          pixivClientProvider.overrideWith((ref, auth) {
            final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl))
              ..httpClientAdapter = _Adapter(calls);
            clients.add(dio);
            return PixivClient(accessToken: 'fixture-access', dio: dio);
          }),
        ],
      );
      addTearDown(() {
        harness.router.dispose();
        harness.dispose();
        for (final client in clients) {
          client.close(force: true);
        }
      });
      SearchRouteContext? opened;
      String? query;
      harness.router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Consumer(
              builder: (context, ref, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 220),
                ),
                child: PixivFollowingArtistsPage(config: ref.watch(_current)),
              ),
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (_, state) {
              opened = state.extra! as SearchRouteContext;
              query = state.uri.queryParameters[kInitialQueryKey];
              return const Scaffold(body: Text('Source Search'));
            },
          ),
        ],
      );
      await harness.pump(tester, const SizedBox.shrink());
      await tester.pumpWidget(
        harness.wrap(
          MaterialApp.router(
            routerConfig: harness.router,
            builder: themeBuilder,
          ),
        ),
      );
      await _until(tester, () => calls.length == 1);
      final public = calls.single;
      expect(find.text('Pixiv Following'), findsOneWidget);
      expect(find.text(_a.name), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        find.byType(KurumiSegmentedButton<PixivFollowRestrict>),
        findsOneWidget,
      );
      await tester.tap(find.text('Private'));
      await _until(tester, () => calls.length == 2);
      final private = calls.last;
      expect(public.cancelled, isTrue);
      expect(private.options.queryParameters['restrict'], 'private');
      harness.container.read(_current.notifier).state = _b;
      await _until(tester, () => calls.length == 3);
      expect(private.cancelled, isTrue);
      expect(calls.last.options.queryParameters['user_id'], 200);
      expect(calls.last.options.queryParameters['restrict'], 'public');
      calls.last.complete(700);
      public.complete(500);
      private.complete(600);
      await _until(
        tester,
        () => find.byType(PixivFollowingArtistCard).evaluate().isNotEmpty,
      );
      expect(find.text('Artist 700'), findsOneWidget);
      expect(find.text('Artist 500'), findsNothing);
      expect(find.text('Artist 600'), findsNothing);
      expect(find.byType(BooruImage), findsNWidgets(3));
      expect(
        calls.map((call) => call.options.path),
        everyElement('/v1/user/following'),
      );
      final before = calls.length;
      await tester.tap(find.text('Artist 700'));
      await tester.pumpAndSettle();
      expect(opened?.config, _b);
      expect(query, 'user:700');
      expect(calls, hasLength(before));
      expect(harness.container.read(selectedTestProfileProvider), testProfile);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

FollowingTopicHarness _paginationHarness(List<_Request> calls) {
  final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl))
    ..httpClientAdapter = _Adapter(calls);
  final harness = FollowingTopicHarness(
    profiles: [_a, _b],
    overrides: [
      pixivClientProvider.overrideWith(
        (ref, auth) => PixivClient(accessToken: 'fixture-access', dio: dio),
      ),
    ],
  );
  addTearDown(() {
    harness.dispose();
    dio.close(force: true);
  });
  return harness;
}

ProviderListenable<AsyncValue<PixivFollowingState>> _following(
  BooruConfig config, {
  bool private = false,
}) => pixivFollowingProvider((
  config: config,
  userId: config.id == _a.id ? 100 : 200,
  restrict: private ? PixivFollowRestrict.private : PixivFollowRestrict.public,
));

List<PixivFollowingArtist> _artists(
  FollowingTopicHarness harness, {
  BooruConfig? config,
  bool private = false,
}) =>
    harness.container
        .read(_following(config ?? _a, private: private))
        .valueOrNull
        ?.artists ??
    const [];

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

BooruConfig _profile(int account, String id) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.pixiv,
    url: 'https://www.pixiv.net',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': id,
  'name': 'Profile $account',
  'apiKey': 'fixture-refresh-$account',
  'passHash': PixivExtraData(userId: '$account', xRestrict: 0).toPassHash(),
});

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

class _Request {
  _Request(this.options, Future<void>? cancellation) {
    cancellation?.then((_) => cancelled = true);
  }
  final RequestOptions options;
  final response = Completer<ResponseBody>();
  var cancelled = false;
  void complete(int artist, {int count = 1, int? nextOffset}) =>
      response.complete(
        ResponseBody.fromString(
          jsonEncode({
            if (nextOffset != null)
              'next_url': Uri.https('app-api.pixiv.net', '/v1/user/following', {
                'user_id': '${options.queryParameters['user_id']}',
                'restrict': '${options.queryParameters['restrict']}',
                'offset': '$nextOffset',
              }).toString(),
            'user_previews': [
              for (var artistId = artist; artistId < artist + count; artistId++)
                {
                  'user': {'id': artistId, 'name': 'Artist $artistId'},
                  'illusts': [
                    for (var i = 0; i < 4; i++)
                      {
                        'id': artistId * 10 + i,
                        'user': {'id': artistId},
                        'x_restrict': 0,
                        'sanity_level': 2,
                        'visible': true,
                        'image_urls': {
                          'square_medium':
                              'https://i.pximg.net/$artistId-$i.jpg',
                        },
                      },
                  ],
                },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.calls);
  final List<_Request> calls;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancellation,
  ) {
    final call = _Request(options, cancellation);
    calls.add(call);
    return call.response.future;
  }

  @override
  void close({bool force = false}) {}
}
