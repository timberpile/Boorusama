import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/favorites/favorite_control.dart';
import 'package:boorusama/boorus/pixiv/favorites/favorite_state.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/themes/theme/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

const _illust = 712345;
final _profile = _config(100);
final _replacement = _config(200);

void main() {
  testWidgets('a plain tap adds Public and updates every sibling heart', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.mount(tester);
    final hearts = find.byType(QuickFavoriteButton);
    expect(hearts, findsNWidgets(2));
    final glyphs = find.descendant(of: hearts, matching: find.byType(Icon));
    expect(
      tester.widgetList<Icon>(glyphs).map((icon) => icon.shadows),
      const [
        [mediaOverlayIconShadow],
        [mediaOverlayIconShadow],
      ],
    );

    final response = Completer<void>();
    rig.server.nextLookup = response;
    await tester.tap(hearts.first);
    await tester.pump();
    expect(rig.state.entry(_illust).pending, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widgetList<Icon>(glyphs).map((icon) => icon.fill), [0, 0]);
    await tester.tap(hearts.last);
    await tester.pump();
    expect(rig.state.entry(_illust).pending, isTrue);
    expect(rig.server.writes, isEmpty);
    response.complete();
    await tester.pumpAndSettle();
    expect(find.text('Add Private Favorite'), findsNothing);
    expect(rig.server.writes.single.data, {
      'illust_id': _illust,
      'restrict': 'public',
    });
    expect(rig.server.lookups, [_illust, _illust]);
    expect(
      tester.widgetList<Icon>(glyphs).map((icon) => icon.shadows),
      const [
        [mediaOverlayIconShadow],
        [mediaOverlayIconShadow],
      ],
    );
    expect(
      tester.widgetList<QuickFavoriteButton>(hearts).map((b) => b.isFaved),
      [
        true,
        true,
      ],
    );
    expect(
      tester
          .widget<KurumiTooltip>(
            find.ancestor(
              of: hearts.last,
              matching: find.byType(KurumiTooltip),
            ),
          )
          .message,
      contains('Public'),
    );

    final removal = Completer<void>();
    rig.server.nextLookup = removal;
    await tester.tap(hearts.last);
    await tester.pump();
    expect(rig.state.entry(_illust).pending, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widgetList<Icon>(glyphs).map((icon) => icon.fill), [1, 1]);
    removal.complete();
    await tester.pumpAndSettle();
    expect(rig.server.writes.last.path, '/v1/illust/bookmark/delete');
    expect(rig.server.writes.last.data, {'illust_id': _illust});
    expect(tester.widget<QuickFavoriteButton>(hearts.first).isFaved, isFalse);
    await rig.unmount(tester);
  });

  for (final visibility in PixivBookmarkVisibility.values) {
    testWidgets(
      'holding opens the popup and choosing ${visibility.name} adds once',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final rig = _Rig();
        await rig.mount(tester, textScale: 2);
        final heart = find.byType(QuickFavoriteButton).first;
        final public = find.text('Add Public Favorite');
        final private = find.text('Add Private Favorite');

        await tester.longPress(heart);
        await tester.pumpAndSettle();
        expect(public.hitTestable(), findsOneWidget);
        expect(private.hitTestable(), findsOneWidget);
        expect(rig.server.lookups, isEmpty);
        expect(rig.server.writes, isEmpty);

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(public, findsNothing);
        expect(rig.server.writes, isEmpty);

        await tester.longPress(heart);
        await tester.pumpAndSettle();
        await tester.tap(
          visibility == PixivBookmarkVisibility.public ? public : private,
        );
        await tester.pumpAndSettle();
        expect(rig.server.writes.single.data, {
          'illust_id': _illust,
          'restrict': visibility.name,
        });
        expect(rig.state.entry(_illust).detail?.visibility, visibility);
        await tester.longPress(heart);
        await tester.pumpAndSettle();
        expect(
          find.text(
            visibility == PixivBookmarkVisibility.public ? 'Public' : 'Private',
          ),
          findsOneWidget,
        );
        expect(public, findsNothing);
        expect(private, findsNothing);
        expect(rig.server.writes, hasLength(1));
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        await tester.tap(heart);
        await tester.pumpAndSettle();
        expect(rig.server.writes.last.path, '/v1/illust/bookmark/delete');
        expect(rig.state.entry(_illust).detail?.isBookmarked, isFalse);
        expect(tester.takeException(), isNull);
        await rig.unmount(tester);
      },
    );
  }

  testWidgets('restricted artwork omits the remote Favorite control', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.mount(tester, restricted: true);
    expect(find.byType(QuickFavoriteButton), findsNothing);
    expect(rig.server.lookups, isEmpty);
    expect(rig.server.writes, isEmpty);
    await rig.unmount(tester);
  });

  test('overlapping operations and older observations cannot undo a confirmed change', () async {
    final rig = _Rig();
    final notifier = rig.notifier;
    final actor = rig.state.actor!;
    final read = notifier.beginRead(actor.auth, actor.authEpoch);
    final gate = Completer<void>();
    rig.server.nextLookup = gate;
    final add = rig.add(PixivBookmarkVisibility.private);
    await rig.server.lookupStarted.future;
    await rig.add(PixivBookmarkVisibility.public);
    expect(rig.server.lookups, [_illust]);
    expect(rig.server.writes, isEmpty);
    gate.complete();
    await add;
    notifier.observe(read, [
      const PixivIllustDto(id: _illust, isBookmarked: false),
    ]);
    expect(rig.state.entry(_illust).detail, (
      isBookmarked: true,
      visibility: PixivBookmarkVisibility.private,
    ));
    expect(rig.state.listRevisions, {PixivBookmarkVisibility.private: 1});
    expect(rig.server.writes, hasLength(1));
  });

  test(
    'preflight preserves a preexisting Favorite of a different visibility',
    () async {
      final rig = _Rig();
      rig.server.visibility = PixivBookmarkVisibility.private;
      await rig.add(PixivBookmarkVisibility.public);
      expect(
        rig.state.entry(_illust).detail?.visibility,
        PixivBookmarkVisibility.private,
      );
      expect(rig.server.writes, isEmpty);
    },
  );

  test('learning visibility does not refresh an unchanged list', () async {
    final rig = _Rig();
    final actor = rig.state.actor!;
    final read = rig.notifier.beginRead(actor.auth, actor.authEpoch);
    rig.notifier.observe(read, [
      const PixivIllustDto(id: _illust, isBookmarked: true),
    ]);
    rig.server.visibility = PixivBookmarkVisibility.private;
    await rig.notifier.lookup(actor, _illust, isCurrent: () => true);
    expect(
      rig.state.entry(_illust).detail?.visibility,
      PixivBookmarkVisibility.private,
    );
    expect(rig.state.listRevisions, isEmpty);
    expect(rig.server.writes, isEmpty);
  });

  test(
    'ambiguous confirmation stays unknown until a read-only retry',
    () async {
      final rig = _Rig();
      rig.server.corruptConfirmation = true;
      await expectLater(
        rig.add(PixivBookmarkVisibility.private),
        throwsA(FavoriteActionFailure.unconfirmed),
      );
      final failed = rig.state.entry(_illust);
      expect(failed.detail, isNull);
      expect(failed.pendingFavorite, isNull);
      expect(failed.lookupFailed, isTrue);
      expect(rig.state.listRevisions, isEmpty);
      rig.server.corruptConfirmation = false;
      await rig.notifier.lookup(
        rig.state.actor!,
        _illust,
        isCurrent: () => true,
        retry: true,
      );
      expect(
        rig.state.entry(_illust).detail?.visibility,
        PixivBookmarkVisibility.private,
      );
      expect(rig.server.writes, hasLength(1));
    },
  );

  test(
    'a credential change fences a pending preflight and its observations',
    () async {
      final rig = _Rig();
      final old = rig.state.actor!;
      final read = rig.notifier.beginRead(old.auth, old.authEpoch);
      final gate = Completer<void>();
      rig.server.nextLookup = gate;
      final add = rig.add(PixivBookmarkVisibility.private);
      final completion = expectLater(
        add,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await rig.server.lookupStarted.future;
      (rig.harness.container.read(booruConfigProvider.notifier) as _Profiles)
          .replace();
      expect(rig.state.actor?.userId, 200);
      gate.complete();
      await completion;
      rig.notifier.observe(
        read,
        [const PixivIllustDto(id: _illust, isBookmarked: true)],
        ownList: PixivBookmarkVisibility.private,
      );
      expect(rig.server.writes, isEmpty);
      expect(rig.state.entry(_illust).detail, isNull);
    },
  );

  test(
    'an unconfirmed removal restores the last known heart for retry',
    () async {
      final rig = _Rig();
      rig.server.visibility = PixivBookmarkVisibility.private;
      final actor = rig.state.actor!;
      rig.notifier.observe(
        rig.notifier.beginRead(actor.auth, actor.authEpoch),
        [const PixivIllustDto(id: _illust, isBookmarked: true)],
        ownList: PixivBookmarkVisibility.private,
      );
      rig.server.corruptConfirmation = true;
      final operation = rig.notifier.setFavorite(
        actor,
        _illust,
        addVisibility: null,
        isCurrent: () => true,
      );
      expect(rig.state.entry(_illust).pendingFavorite, isFalse);
      await expectLater(operation, throwsA(FavoriteActionFailure.unconfirmed));
      final failed = rig.state.entry(_illust);
      expect(failed.pendingFavorite, isNull);
      expect(failed.detail, isNull);
      expect(failed.lastKnownFavorite, isTrue);
      expect(failed.lookupFailed, isTrue);
      expect(rig.state.listRevisions, isEmpty);
    },
  );
}

BooruConfig _config(int account) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.pixiv,
    url: 'https://www.pixiv.net',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': testProfile.id,
  'apiKey': 'fixture-refresh-$account',
  'passHash': PixivExtraData(userId: '$account').toPassHash(),
});

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: [_profile]);
  void replace() => state = [_replacement];
}

class _Rig {
  _Rig() {
    addTearDown(harness.dispose);
    harness.container.listen(provider, (_, _) {});
  }

  final server = _Server();
  final provider = pixivFavoriteStateProvider(_profile.id);
  late final harness = FollowingTopicHarness(
    overrides: [
      booruConfigProvider.overrideWith(_Profiles.new),
      currentReadOnlyBooruConfigProvider.overrideWithValue(_profile),
      pixivClientProvider.overrideWith((ref, _) {
        final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl))
          ..interceptors.add(InterceptorsWrapper(onRequest: server.respond));
        ref.onDispose(dio.close);
        return PixivClient(accessToken: 'fixture-access', dio: dio);
      }),
    ],
  );
  PixivFavoritesState get state => harness.container.read(provider);
  PixivFavoriteNotifier get notifier =>
      harness.container.read(provider.notifier);

  Future<void> add(PixivBookmarkVisibility visibility) => notifier.setFavorite(
    state.actor!,
    _illust,
    addVisibility: visibility,
    isCurrent: () => true,
  );

  Future<void> mount(
    WidgetTester tester, {
    double textScale = 1,
    bool restricted = false,
  }) => harness.pump(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PixivFavoriteControl(
                  illustId: _illust,
                  compact: true,
                  restricted: restricted,
                ),
                PixivFavoriteControl(
                  illustId: _illust,
                  compact: true,
                  restricted: restricted,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());
}

class _Server {
  final writes = <RequestOptions>[];
  final lookups = <int>[];
  final lookupStarted = Completer<void>();
  Completer<void>? nextLookup;
  PixivBookmarkVisibility? visibility;
  var corruptConfirmation = false;

  Future<void> respond(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var body = <String, dynamic>{};
    if (options.method == 'GET') {
      lookups.add(options.queryParameters['illust_id'] as int);
      if (!lookupStarted.isCompleted) lookupStarted.complete();
      final gate = nextLookup;
      nextLookup = null;
      await gate?.future;
      if (!corruptConfirmation || writes.isEmpty) {
        body = {
          'bookmark_detail': {
            'is_bookmarked': visibility != null,
            'restrict': visibility?.name,
          },
        };
      }
    } else {
      writes.add(options);
      visibility = switch ((options.data as Map)['restrict']) {
        'public' => PixivBookmarkVisibility.public,
        'private' => PixivBookmarkVisibility.private,
        _ => null,
      };
    }
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: body),
    );
  }
}
