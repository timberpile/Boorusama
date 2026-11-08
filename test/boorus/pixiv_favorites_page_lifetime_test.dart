import 'package:boorusama/core/images/booru_image.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/favorites/page.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart' show CacheExtentStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

final _a = _profile(100, testProfile.id);
final _b = _profile(200, otherTestProfile.id);
final _current = StateProvider<BooruConfig>((ref) => _a);

void main() {
  testWidgets(
    'Favorites starts a bounded thumbnail range before those posts enter the viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final starts = <(String, DateTime)>[];
      final page = _Harness(
        loadImages: true,
        onMediaRequest: (options) {
          if (options.uri.host == 'i.pximg.net')
            starts.add((options.uri.toString(), tester.binding.clock.now()));
        },
      );
      await page.pump(tester);
      page.calls.single.complete(1, count: 60);
      await _until(tester, () => !page.controller(tester).refreshing);
      await drain(tester);
      await _until(tester, () => starts.isNotEmpty);
      final requested = starts.map((s) => s.$1).toSet();
      expect(requested, isNotEmpty);
      expect(requested.length, lessThan(60));
      final images = find.byType(BooruImage, skipOffstage: false);
      final ahead = images.evaluate().where(
        (e) =>
            requested.contains((e.widget as BooruImage).imageUrl) &&
            tester.getRect(find.byWidget(e.widget, skipOffstage: false)).top >=
                844,
      );
      expect(
        ahead,
        isNotEmpty,
        reason: 'An HTTP request must begin while its cached tile is still below the viewport.',
      );
      final grid = tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>));
      expect(grid.cacheExtent, isNull);
      final scrollView = tester.widget<CustomScrollView>(
        find.descendant(
          of: find.byType(PostGrid<Post>),
          matching: find.byType(CustomScrollView),
        ),
      );
      expect(scrollView.scrollCacheExtent?.style, CacheExtentStyle.viewport);
      expect(scrollView.scrollCacheExtent?.value, 1);
      expect(page.calls, hasLength(1));
      await page.close(tester);
    },
  );

  testWidgets(
    'automatic Favorites failure stops, explicit retry retains the cursor, and refresh renews the budget',
    (tester) async {
      final page = _Harness();
      await page.pump(tester);
      page.calls.single.complete(1, more: true);
      await tester.pump();
      await tester.pump(page.controller(tester).debounceDuration);
      await _until(tester, () => page.calls.length == 2);
      page.calls.last.response.complete(ResponseBody.fromString('{}', 503));
      await _until(tester, () => !page.controller(tester).loadingMore);
      expect(page.controller(tester).errors.value, isNotNull);
      await tester.pump();
      expect(page.calls, hasLength(2));
      final retry = page.controller(tester).fetchMore();
      await tester.pump(page.controller(tester).debounceDuration);
      await _until(tester, () => page.calls.length == 3);
      expect(page.calls.last.options.queryParameters['max_bookmark_id'], '90');
      page.calls.last.complete(2);
      await _until(tester, () => !page.controller(tester).loadingMore);
      await retry;
      expect(page.controller(tester).items, hasLength(2));
      final refresh = page.controller(tester).refresh();
      await _until(tester, () => page.calls.length == 4);
      expect(
        page.calls.last.options.queryParameters['max_bookmark_id'],
        isNull,
      );
      page.calls.last.complete(11, more: true, cursor: '50');
      await _until(tester, () => !page.controller(tester).refreshing);
      await refresh;
      await tester.pump();
      await tester.pump(page.controller(tester).debounceDuration);
      await _until(tester, () => page.calls.length == 5);
      expect(page.calls.last.options.queryParameters['max_bookmark_id'], '50');
      page.calls.last.complete(12);
      await _until(tester, () => !page.controller(tester).loadingMore);
      expect(page.controller(tester).items.map((p) => p.illustId), [11, 12]);
      await page.close(tester);
    },
  );

  testWidgets(
    'short Favorites pages prefetch at most three cursors and retain manual continuation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final page = _Harness();
      await page.pump(tester);
      for (var number = 1; number <= 4; number++) {
        page.calls.last.complete(number, more: true, cursor: '${100 - number}');
        final controller = page.controller(tester);
        if (number < 4) {
          await tester.pumpAndSettle();
          await tester.pump(controller.debounceDuration);
          await _until(tester, () => page.calls.length == number + 1);
        } else {
          await _until(tester, () => !controller.loadingMore);
        }
      }
      await tester.pumpAndSettle();
      expect(page.calls, hasLength(4));
      expect(page.controller(tester).items, hasLength(4));
      expect(
        page.calls
            .skip(1)
            .map((c) => c.options.queryParameters['max_bookmark_id']),
        ['99', '98', '97'],
      );
      await tester.tap(
        find
            .text(
              tester
                  .element(find.byType(PixivFavoritesPage))
                  .t
                  .infinite_scroll
                  .load_more,
            )
            .last,
      );
      await tester.pump(page.controller(tester).debounceDuration);
      await _until(tester, () => page.calls.length == 5);
      expect(page.calls.last.options.queryParameters['max_bookmark_id'], '96');
      page.calls.last.complete(5);
      await _until(tester, () => !page.controller(tester).loadingMore);
      expect(page.controller(tester).items, hasLength(5));
      expect(page.controller(tester).hasMore, isFalse);
      await page.close(tester);
    },
  );

  testWidgets(
    'populated Favorites prefetch but title and privacy return only at the top',
    (tester) async {
      final page = _Harness();
      await page.pump(tester);
      page.calls.single.complete(1, count: 60, more: true);
      await _until(tester, () => !page.controller(tester).refreshing);
      final scrollable = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(page.calls, hasLength(1));
      position.jumpTo(
        position.maxScrollExtent - position.viewportDimension * 2,
      );
      await tester.pump(page.controller(tester).debounceDuration);
      await _until(tester, () => page.calls.length == 2);
      expect(position.extentAfter, greaterThan(position.viewportDimension));
      expect(page.calls.last.options.queryParameters['max_bookmark_id'], '90');
      page.calls.last.complete(101, count: 60);
      await _until(tester, () => !page.controller(tester).loadingMore);
      final privacy = find.byKey(
        const ValueKey('pixiv-favorites-privacy'),
        skipOffstage: false,
      );
      final title = find.text('Favorites', skipOffstage: false);
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(privacy.hitTestable(), findsNothing);
      expect(title.hitTestable(), findsNothing);
      await tester.drag(scrollable, const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(privacy.hitTestable(), findsNothing);
      expect(title.hitTestable(), findsNothing);
      expect(
        find.byType(PostGridConfigurationHeader<Post>).hitTestable(),
        findsOneWidget,
      );
      expect(position.pixels, greaterThan(200));
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(privacy.hitTestable(), findsOneWidget);
      expect(title.hitTestable(), findsOneWidget);
      expect(page.calls, hasLength(2));
      expect(tester.takeException(), isNull);
      await page.close(tester);
    },
  );

  for (final private in [false, true]) {
    testWidgets(
      'real Favorites continues empty pages and stops a nonempty terminal page (private=$private)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final page = _Harness();
        await page.pump(tester);
        if (private) {
          final old = page.calls.single;
          await _selectPrivate(tester);
          await _until(tester, () => page.calls.length == 2);
          old.complete(99);
        }
        final start = page.calls.length;
        page.calls.last.complete(1, visible: false, more: true);
        final controller = page.controller(tester);
        await _until(tester, () => !controller.refreshing);
        expect(controller.items, isEmpty);
        expect(controller.hasMore, isTrue);
        final label = tester
            .element(find.byType(PixivFavoritesPage))
            .t
            .infinite_scroll
            .load_more;
        final more = find.widgetWithText(FilledButton, label);
        expect(more, findsOneWidget);
        for (final (cursor, visible) in [('80', false), ('70', true)]) {
          await tester.ensureVisible(more);
          await tester.pump();
          expect(more.hitTestable(), findsOneWidget);
          await tester.tap(more);
          await tester.pump(controller.debounceDuration);
          await _until(tester, () => !page.calls.last.response.isCompleted);
          expect(
            page.calls.last.options.queryParameters['restrict'],
            private ? 'private' : 'public',
          );
          page.calls.last.complete(
            3,
            visible: visible,
            more: !visible,
            cursor: cursor,
          );
          await _until(tester, () => !controller.loadingMore);
          expect(controller.hasMore, !visible);
          expect(
            controller.items.map((post) => post.illustId),
            visible ? [3] : <int>[],
          );
        }
        expect(page.calls, hasLength(start + 2));
        expect(more, findsNothing);
        expect(tester.takeException(), isNull);
        await page.close(tester);
      },
    );
  }

  testWidgets(
    'Favorites privacy buttons work at 320 dp, enlarged text and keyboard while loading',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final page = _Harness();
      await page.pump(tester);
      final old = page.calls.single;
      await _selectPrivate(tester);
      await _until(tester, () => page.calls.length == 2);
      expect(old.cancelled, isTrue);
      expect(page.calls.last.options.queryParameters['restrict'], 'private');
      page.calls.last.complete(2, visible: false);
      old.complete(99);
      await _until(tester, () => !page.controller(tester).refreshing);
      expect(page.controller(tester).items, isEmpty);
      expect(tester.takeException(), isNull);
      await page.close(tester);
    },
  );

  testWidgets(
    'an unverified replacement credential issues no old-account Favorites request',
    (tester) async {
      final page = _Harness();
      await page.pump(tester);
      final old = page.calls.single;
      page.harness.container
          .read(_current.notifier)
          .state = BooruConfig.fromJson({
        ..._a.toJson(),
        'apiKey': 'fixture-new-account',
        'login': '',
        'passHash': null,
      });
      await _until(
        tester,
        () => find.byType(PostGrid<Post>).evaluate().isEmpty,
      );
      await _until(tester, () => old.cancelled);
      expect(page.calls, hasLength(1));
      old.complete(99);
      await tester.pumpAndSettle();
      expect(page.calls, hasLength(1));
      page.harness.container.read(_current.notifier).state = _b;
      await _until(tester, () => page.calls.length == 2);
      expect(page.calls.last.options.queryParameters['user_id'], 200);
      page.calls.last.complete(20);
      await _until(tester, () => page.controller(tester).items.isNotEmpty);
      expect(page.controller(tester).items.single.illustId, 20);
      await page.close(tester);
    },
  );
  for (final whileLoadingMore in [false, true]) {
    testWidgets(
      'cosmetic profile changes replace the captured Favorites session ($whileLoadingMore)',
      (tester) async {
        final page = _Harness();
        await page.pump(tester);
        final first = page.controller(tester);
        Future<void>? loading;
        if (whileLoadingMore) {
          page.calls[0].complete(1, more: true);
          await _until(tester, () => first.items.isNotEmpty);
          loading = first.fetchMore();
          await tester.pump(first.debounceDuration);
          await _until(tester, () => page.calls.length == 2);
        }
        final oldCall = page.calls.last;
        page.harness.container.read(_current.notifier).state = _a.copyWith(
          name: 'Renamed',
        );
        await _until(
          tester,
          () => page.calls.length == (whileLoadingMore ? 3 : 2),
        );
        final current = page.controller(tester);
        expect(current, isNot(same(first)));
        expect(oldCall.cancelled, isTrue);
        expect(page.calls.last.options.queryParameters['user_id'], 100);
        page.calls.last.complete(2);
        oldCall.complete(99);
        if (loading != null) await loading;
        await _until(tester, () => current.items.isNotEmpty);
        expect(current.items.map((post) => post.illustId), [2]);
        expect(current.errors.value, isNull);
        final refreshed = current.refresh();
        await _until(
          tester,
          () => !page.calls.last.response.isCompleted,
        );
        page.calls.last.complete(3);
        await tester.pumpAndSettle();
        await refreshed;
        expect(current.items.map((post) => post.illustId), [3]);
        await page.close(tester);
      },
    );
  }

  testWidgets(
    'privacy and account changes cancel old Favorites requests and results',
    (tester) async {
      final page = _Harness();
      await page.pump(tester);
      final public = page.calls.single;
      final context = tester.element(find.byType(PixivFavoritesPage));
      await _selectPrivate(tester);
      await _until(tester, () => page.calls.length == 2);
      expect(public.cancelled, isTrue);
      expect(page.calls.last.options.queryParameters['restrict'], 'private');
      final private = page.calls.last;
      page.harness.container.read(_current.notifier).state = _b;
      await _until(tester, () => page.calls.length == 3);
      expect(private.cancelled, isTrue);
      expect(page.calls.last.options.queryParameters['user_id'], 200);
      expect(page.calls.last.options.queryParameters['restrict'], 'public');
      page.calls.last.complete(20);
      public.complete(10);
      private.complete(11);
      final current = page.controller(tester);
      await _until(tester, () => current.items.isNotEmpty);
      expect(current.items.single.illustId, 20);
      expect(current.items.single.origin.profileIdHint, _b.id);
      expect(context.mounted, isTrue);
      expect(tester.takeException(), isNull);
      await page.close(tester);
    },
  );
}

Future<void> _selectPrivate(WidgetTester tester) async {
  final selector = find.byType(KurumiSegmentedButton<PixivBookmarkVisibility>);
  expect(selector, findsOneWidget);
  expect(find.text('Public').hitTestable(), findsOneWidget);
  expect(find.text('Private').hitTestable(), findsOneWidget);
  final public = tester.getRect(find.text('Public'));
  final private = tester.getRect(find.text('Private'));
  expect(public.center.dy, closeTo(private.center.dy, .5));
  expect(public.right, lessThan(private.left));
  await tester.tap(find.text('Private'));
  await tester.pump();
}

BooruConfig _profile(int account, String id) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.pixiv,
    url: 'https://www.pixiv.net',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': id,
  'apiKey': 'fixture-refresh-$account',
  'passHash': PixivExtraData(userId: '$account').toPassHash(),
});

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 100 && !condition(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue);
}

class _Harness {
  _Harness({this.loadImages = false, this.onMediaRequest});
  final bool loadImages;
  final void Function(RequestOptions)? onMediaRequest;
  final calls = <_Request>[];
  final clients = <Dio>[];
  late final harness = FollowingTopicHarness(
    loadImages: loadImages,
    onMediaRequest: onMediaRequest,
    profiles: [_a, _b],
    overrides: [
      currentReadOnlyBooruConfigProvider.overrideWith(
        (ref) => ref.watch(_current),
      ),
      pixivClientProvider.overrideWith((ref, auth) {
        final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
        clients.add(dio);
        dio.httpClientAdapter = _Adapter(calls);
        return PixivClient(accessToken: 'fixture-access', dio: dio);
      }),
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    await harness.pump(tester, const PixivFavoritesPage());
    await _until(tester, () => calls.isNotEmpty);
  }

  PostGridController<Post> controller(WidgetTester tester) =>
      tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>)).controller;

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
    for (final dio in clients) {
      dio.close(force: true);
    }
  }
}

class _Request {
  _Request(this.options, Future<void>? cancellation) {
    cancellation?.then((_) => cancelled = true);
  }
  final RequestOptions options;
  final response = Completer<ResponseBody>();
  var cancelled = false;

  void complete(
    int id, {
    bool more = false,
    bool visible = true,
    String cursor = '90',
    int count = 1,
  }) => response.complete(
    ResponseBody.fromString(
      jsonEncode({
        'illusts': [
          for (var artworkId = id; artworkId < id + count; artworkId++)
            {
              'id': artworkId,
              'width': 100,
              'height': 100,
              'type': 'illust',
              'page_count': 1,
              'visible': visible,
              'user': {'id': 99, 'name': 'Fixture'},
              'image_urls': {'medium': 'https://i.pximg.net/$artworkId.jpg'},
              'meta_single_page': {
                'original_image_url':
                    'https://i.pximg.net/original/$artworkId.jpg',
              },
            },
        ],
        if (more)
          'next_url':
              'https://app-api.pixiv.net/v1/user/bookmarks/illust?user_id=${options.queryParameters['user_id']}&restrict=${options.queryParameters['restrict']}&max_bookmark_id=$cursor',
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
