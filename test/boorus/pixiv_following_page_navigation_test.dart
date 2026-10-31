import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/following/artist_card.dart';
import 'package:boorusama/boorus/pixiv/following/page.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_option_selector.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

final _a = _profile(100, testProfile.id);
final _b = _profile(200, otherTestProfile.id);
final _current = StateProvider<BooruConfig>((ref) => _a);

void main() {
  testWidgets(
    'real Following page isolates privacy and account then opens source Search without extra requests',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      await tester.tap(
        find.byType(TimelineOptionSelector<PixivFollowRestrict>),
      );
      await _until(tester, () => find.text('Private').evaluate().isNotEmpty);
      await tester.tap(find.text('Private'));
      await _until(tester, () => find.text('Private').evaluate().length == 1);
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
  void complete(int artist) => response.complete(
    ResponseBody.fromString(
      jsonEncode({
        'user_previews': [
          {
            'user': {'id': artist, 'name': 'Artist $artist'},
            'illusts': [
              for (var i = 0; i < 4; i++)
                {
                  'id': artist * 10 + i,
                  'user': {'id': artist},
                  'x_restrict': 0,
                  'sanity_level': 2,
                  'visible': true,
                  'image_urls': {
                    'square_medium': 'https://i.pximg.net/$artist-$i.jpg',
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
