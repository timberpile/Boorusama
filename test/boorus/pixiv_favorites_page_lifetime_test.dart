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
import 'package:boorusama/core/posts/listing/src/widgets/timeline_option_selector.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

final _a = _profile(100, testProfile.id);
final _b = _profile(200, otherTestProfile.id);
final _current = StateProvider<BooruConfig>((ref) => _a);

void main() {
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
    'Favorites privacy menu works at 320 dp, enlarged text and keyboard while loading',
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
  final selector = find.byType(TimelineOptionSelector<PixivBookmarkVisibility>);
  expect(selector, findsOneWidget);
  expect(find.byType(ChoiceChip), findsNothing);
  await tester.tap(selector);
  await _until(tester, () => find.text('Private').evaluate().isNotEmpty);
  await tester.tap(find.text('Private'));
  await _until(tester, () => find.text('Private').evaluate().length == 1);
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
  final calls = <_Request>[];
  final clients = <Dio>[];
  late final harness = FollowingTopicHarness(
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
  }) => response.complete(
    ResponseBody.fromString(
      jsonEncode({
        'illusts': [
          {
            'id': id,
            'width': 100,
            'height': 100,
            'type': 'illust',
            'page_count': 1,
            'visible': visible,
            'user': {'id': 99, 'name': 'Fixture'},
            'image_urls': {'medium': 'https://i.pximg.net/$id.jpg'},
            'meta_single_page': {
              'original_image_url': 'https://i.pximg.net/original/$id.jpg',
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
