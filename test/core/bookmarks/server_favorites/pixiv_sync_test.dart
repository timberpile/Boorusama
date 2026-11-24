import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  final pixiv = pixivFavoriteTestProfile();
  late FavoriteHarness h;
  late _Listing listing;

  setUp(() async {
    h = FavoriteHarness();
    listing = _Listing();
    await h.open(
      unifiedGroups: true,
      additionalProfiles: [pixiv],
      extraOverrides: (_) => [
        booruEngineRegistryProvider.overrideWith(
          (ref) => BooruEngineRegistry(),
        ),
        pixivClientProvider.overrideWith((ref, auth) {
          expect(auth, pixiv.auth);
          return listing.client;
        }),
      ],
    );
  });

  tearDown(() async {
    listing.close();
    await h.close();
  });

  BookmarkLibraryNotifier library() =>
      h.container.read(bookmarkLibraryProvider.notifier);
  ServerFavoriteFetchNotifier fetch() =>
      h.container.read(serverFavoriteFetchProvider.notifier);
  ServerFavoriteSettingsNotifier settings() =>
      h.container.read(serverFavoriteSettingsProvider.notifier);

  test(
    'availability requires a verified identity and token without API IO',
    () {
      final available = h.container.read(
        serverFavoriteAvailabilityProvider(pixiv.auth),
      );
      expect(available, isNull);
      for (final profile in [
        pixivFavoriteTestProfile(token: null),
        pixivFavoriteTestProfile(token: '  '),
        pixivFavoriteTestProfile(userId: null),
        pixivFavoriteTestProfile(userId: '0'),
      ]) {
        expect(
          h.container.read(serverFavoriteAvailabilityProvider(profile.auth)),
          ServerFavoriteProblem.signedOut,
        );
      }
      expect(supportsServerFavoriteProjection(pixiv.auth.booruType), isFalse);
      expect(listing.requests, isEmpty);
    },
  );

  test('fetches both visibilities as durable artwork bookmarks in a populated group', () async {
    final target = await library().createGroup('Target');
    final other = await library().createGroup('Existing Work');
    final access = ContentAccessContext.profile(
      config: pixiv,
      authEpoch: 0,
      policyEpoch: 0,
    );
    final work = PixivWorkBookmarkTarget(
      access: access,
      summary: pixivWorkSummary(PixivIllustDto.fromJson(_work(80)), access),
    ).draft(currentAccess: access, at: DateTime.utc(2024));
    await library().addContentGroupDraftsToGroup([work], other.id);
    await library().addPostsToGroup(h.profile.auth, [h.post(4)], target.id);
    await settings().setGlobal(target.id);
    expect(listing.requests, isEmpty);
    final before = await library().snapshotForExport();
    final originalDates = before.groupsById[target.id]!.addedAt;
    listing.respond = (request) => switch (_scope(request)) {
      ('public', null) => _page([_work(80), _work(70)], next: ('public', '90')),
      ('public', '90') => _page([_work(70)], next: ('public', '60')),
      ('public', '60') => _page([_work(65, visible: false)]),
      ('private', null) => _page([_work(80)], next: ('private', '75')),
      ('private', '75') => _page([
        _work(60, type: 'ugoira', pageCount: 1),
        _work(50, pageCount: 1),
      ]),
      final scope => throw StateError('Unexpected fixture request $scope'),
    };

    final progress = await fetch().start(pixiv.id);
    expect(progress.status, ServerFavoriteFetchStatus.completed);
    expect(progress.added, 4);
    expect(listing.requests.map(_scope), [
      ('public', null),
      ('public', '90'),
      ('public', '60'),
      ('private', null),
      ('private', '75'),
    ]);
    for (final request in listing.requests) {
      expect(request.method, 'GET');
      expect(request.path, '/v1/user/bookmarks/illust');
      expect(request.queryParameters['user_id'], 42);
    }
    expect(listing.requestClasses, everyElement(ApiRequestClass.bulkTransfer));

    final after = await library().snapshotForExport();
    final members = after.groupsById[target.id]!;
    expect(
      members.addedAt,
      containsPair(originalDates.keys.single, originalDates.values.single),
    );
    final ordered =
        selectBookmarkGridEntries(
          state: after,
          view: BookmarkView.group(target.id),
          selectedTags: const [],
          sortType: BookmarkSortType.newest,
        ).map(
          (entry) => switch (entry) {
            BookmarkNativeGroupEntry(:final bookmark) => _artwork(bookmark),
            BookmarkPostEntry(:final bookmark) => _artwork(bookmark),
            _ => throw StateError('Unexpected fixture grid entry'),
          },
        );
    expect(ordered, [
      'work:80',
      'work:70',
      'ugoira:60',
      'work:50',
      'post:4',
    ]);
    final savedWork = before.records.whereType<ContentGroupBookmark>().single;
    expect(after.byId[savedWork.id], savedWork);
    expect(after.groupsById[other.id], before.groupsById[other.id]);
    expect(
      savedWork.summary.memberCount,
      3,
    );
    expect(
      savedWork.sourceProfileHint,
      pixiv.id,
    );

    await h.restart();
    await fetch().startAll([ServerFavoriteSession(pixiv, target.id)]);
    final repeated = h.container.read(serverFavoriteFetchProvider)[pixiv.id]!;
    expect(repeated.status, ServerFavoriteFetchStatus.completed);
    expect(repeated.added, 0);
    expect(
      (await library().snapshotForExport()).groupsById[target.id],
      members,
    );
  });

  test(
    'a Private request failure leaves the Public buffer untouched',
    () async {
      final target = await library().createGroup('Target');
      await settings().setGlobal(target.id);
      final before = await library().snapshotForExport();
      listing.respond = (request) => switch (_scope(request)) {
        ('public', null) => _page([_work(80)]),
        _ => throw DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 429),
        ),
      };

      final progress = await fetch().start(pixiv.id);
      expect(progress.problem, ServerFavoriteProblem.remoteFailure);
      expect(listing.requests.map(_scope), [
        ('public', null),
        ('private', null),
      ]);
      expect(await library().snapshotForExport(), before);
    },
  );

  test(
    'a changed target cancels a download without redirecting its entries',
    () async {
      final original = await library().createGroup('Original');
      final replacement = await library().createGroup('Replacement');
      await settings().setGlobal(original.id);
      final started = Completer<void>();
      final finish = Completer<Map<String, dynamic>>();
      listing.respond = (_) {
        started.complete();
        return finish.future;
      };

      final running = fetch().start(pixiv.id);
      await started.future;
      await settings().setGlobal(replacement.id);
      expect((await running).status, ServerFavoriteFetchStatus.cancelled);
      finish.complete(_page([_work(80)]));
      final after = await library().snapshotForExport();
      expect(after.groupsById[original.id]!.bookmarkIds, isEmpty);
      expect(after.groupsById[replacement.id]!.bookmarkIds, isEmpty);
      expect(listing.requests, hasLength(1));
    },
  );

  test(
    'cancel during download revokes the active request before any write',
    () async {
      final target = await library().createGroup('Target');
      await settings().setGlobal(target.id);
      final before = await library().snapshotForExport();
      final started = Completer<RequestOptions>();
      final finish = Completer<Map<String, dynamic>>();
      listing.respond = (request) {
        if (_scope(request) == ('public', null)) return _page([_work(80)]);
        started.complete(request);
        return finish.future;
      };
      final running = fetch().start(pixiv.id);
      final request = await started.future;
      fetch().cancel(pixiv.id);
      expect((await running).status, ServerFavoriteFetchStatus.cancelled);
      expect(request.cancelToken?.isCancelled, isTrue);
      finish.complete(_page([_work(40)]));
      expect(await library().snapshotForExport(), before);
    },
  );

  test(
    'cancel during saving keeps committed batches and retry adds the rest',
    () async {
      final target = await library().createGroup('Target');
      await settings().setGlobal(target.id);
      listing.respond = (request) =>
          _page([_work(_scope(request).$1 == 'public' ? 80 : 40)]);
      final subscription = h.container.listen(serverFavoriteFetchProvider, (
        _,
        current,
      ) {
        final progress = current[pixiv.id];
        if ((progress?.running ?? false) && progress?.added == 1) {
          fetch().cancel(pixiv.id);
        }
      });
      final cancelled = await fetch().start(pixiv.id);
      subscription.close();
      expect(cancelled.status, ServerFavoriteFetchStatus.cancelled);
      expect(cancelled.added, 1);
      final partial = await library().snapshotForExport();
      expect(partial.records.map(_artwork), ['work:40']);
      final retried = await fetch().start(pixiv.id);
      expect(retried.status, ServerFavoriteFetchStatus.completed);
      expect(retried.added, 1);
      final complete = await library().snapshotForExport();
      expect(
        complete.groupsById[target.id]!.addedAt,
        containsPair(
          partial.byId.keys.single,
          partial.groupsById[target.id]!.addedAt.values.single,
        ),
      );
    },
  );

  for (final (name, updated, completes) in [
    (
      'rotates its token',
      pixivFavoriteTestProfile(token: 'fixture-rotated'),
      true,
    ),
    ('signs out', pixivFavoriteTestProfile(token: null), false),
    ('switches account', pixivFavoriteTestProfile(userId: '99'), false),
  ]) {
    test('captured Pixiv profile $name mid-fetch', () async {
      final target = await library().createGroup('Target');
      await settings().setGlobal(target.id);
      listing.respond = (request) {
        if (_scope(request) == ('public', null)) {
          h.profiles.profiles = [h.profile, updated];
          return _page([_work(80)]);
        }
        return _page([_work(40)]);
      };
      final progress = await fetch().start(pixiv.id);
      final after = await library().snapshotForExport();
      if (completes) {
        expect(progress.status, ServerFavoriteFetchStatus.completed);
        expect(after.records, hasLength(2));
        expect(listing.requests, hasLength(2));
      } else {
        expect(progress.problem, ServerFavoriteProblem.accountChanged);
        expect(after.records, isEmpty);
        expect(listing.requests, hasLength(1));
      }
    });
  }
}

String _artwork(Bookmark record) => switch (record) {
  ContentGroupBookmark(:final reference) => reference.sourceKey,
  PostBookmark(:final post) when post.pixivData != null =>
    'ugoira:${post.illustId}',
  PostBookmark(:final post) => 'post:${post.id}',
  _ => throw StateError('Unexpected fixture bookmark'),
};

(String, String?) _scope(RequestOptions request) => (
  request.queryParameters['restrict'] as String,
  request.queryParameters['max_bookmark_id'] as String?,
);

Map<String, dynamic> _page(
  List<Map<String, dynamic>> works, {
  (String, String)? next,
}) => {
  'illusts': works,
  if (next case (final visibility, final cursor))
    'next_url':
        '$kPixivApiBaseUrl/v1/user/bookmarks/illust'
        '?user_id=42&restrict=$visibility&max_bookmark_id=$cursor',
};

Map<String, dynamic> _work(
  int id, {
  String type = 'manga',
  int pageCount = 3,
  bool visible = true,
}) => {
  'id': id,
  'type': type,
  'user': {'id': 9},
  'visible': visible,
  'page_count': pageCount,
  'x_restrict': 0,
  'sanity_level': 2,
  'meta_single_page': {
    'original_image_url': 'https://i.pximg.net/img/${id}_p0.jpg',
  },
};

class _Listing {
  _Listing() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          requests.add(request);
          requestClasses.add(apiRequestContextFor(request).requestClass);
          try {
            final data = await respond(request);
            handler.resolve(Response(requestOptions: request, data: data));
          } on DioException catch (error) {
            handler.reject(error);
          } catch (error) {
            handler.reject(DioException(requestOptions: request, error: error));
          }
        },
      ),
    );
  }

  final _dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
  late final client = PixivClient(accessToken: 'fixture', dio: _dio);
  final requests = <RequestOptions>[];
  final requestClasses = <ApiRequestClass>[];
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;

  void close() => _dio.close(force: true);
}
