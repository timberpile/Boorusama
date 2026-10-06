import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/favorites/src/data/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/src/post_vote.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/src/post_vote_repository.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/src/widgets/favorite_action.dart';
import 'package:boorusama/core/posts/favorites/src/types/favorite_interruption.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:kurumi/material.dart';

void main() {
  final config = BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://site.test',
    customDownloadFileNameFormat: null,
  ).auth;
  for (final cancel in [false, true]) {
    for (final firstFails in [false, true]) {
      testWidgets(
        '${cancel ? 'cancel' : 'cooldown'} ${firstFails ? 'initial mutation' : 'confirmed cleanup'} preserves state and callback',
        (tester) async {
          final error = _interruption(cancel);
          var mutations = 0;
          final container = ProviderContainer(
            overrides: [
              favoriteRepoProvider(config).overrideWithValue(
                FavoriteRepositoryBuilder(
                  add: (_) async => AddFavoriteStatus.success,
                  remove: (_) {
                    mutations++;
                    return Future<bool>.error(
                      firstFails
                          ? error
                          : FavoriteCompletedWithInterruption(
                              error,
                              StackTrace.current,
                            ),
                    );
                  },
                  filter: (_) async => [1],
                  isFavorited: (_) => false,
                  canFavorite: () => true,
                ),
              ),
            ],
          );
          addTearDown(container.dispose);
          final notifier = container.read(favoritesProvider(config).notifier);
          await notifier.checkFavorites([1]);
          var completedCallback = 0;
          var showButton = true;
          await tester.pumpWidget(
            TranslationProvider(
              child: MaterialApp(
                theme: ThemeData.light().withBoorusamaColors(),
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: OKToast(child: child!),
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: StatefulBuilder(
                      builder: (context, setState) => showButton
                          ? FavoritePostButton(
                              isFaved: true,
                              isAuthorized: true,
                              addFavorite: () async {},
                              removeFavorite: () async {
                                if (await notifier.remove(1)) {
                                  completedCallback++;
                                  setState(() => showButton = false);
                                  await WidgetsBinding.instance.endOfFrame;
                                }
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byType(IconButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          expect(mutations, 1);
          expect(completedCallback, firstFails ? 0 : 1);
          expect(container.read(favoritesProvider(config))[1], firstFails);
          if (cancel) {
            expect(
              find.textContaining('Rate limited by the site'),
              findsNothing,
            );
          } else {
            expect(
              find.textContaining('Rate limited by the site. Try again in'),
              findsOneWidget,
            );
          }
          // A disposed/cancelled action does not leave the button busy.
          if (firstFails) {
            expect(
              tester.widget<IconButton>(find.byType(IconButton)).onPressed,
              isNotNull,
            );
          } else {
            expect(find.byType(FavoritePostButton), findsNothing);
          }
          await tester.pump(const Duration(seconds: 5));
        },
      );
    }
  }
  for (final cancel in [false, true]) {
    for (final firstFails in [false, true]) {
      test(
        'actual Danbooru ${cancel ? 'cancel' : '429'} ${firstFails ? 'first mutation' : 'vote cleanup'}',
        () async {
          final coordinator = ApiRequestCoordinator();
          addTearDown(coordinator.dispose);
          final transport = _FavoriteTransport(
            firstFails: firstFails,
            cancel: cancel,
          );
          final dio = Dio(BaseOptions(baseUrl: config.url))
            ..httpClientAdapter = transport;
          coordinateApiDio(dio, coordinator);
          final voteRepo = _Votes(cancel: cancel);
          final container = ProviderContainer(
            overrides: [
              danbooruClientProvider(config).overrideWithValue(
                DanbooruClient(baseUrl: config.url, dio: dio),
              ),
              danbooruCurrentUserProvider(
                config,
              ).overrideWith((ref) => Future.value(UserSelf.placeholder())),
              danbooruPostVoteRepoProvider(config).overrideWithValue(voteRepo),
              favoriteRepoProvider(config).overrideWith(
                (ref) => ref.watch(danbooruFavoriteRepoProvider(config)),
              ),
            ],
          );
          addTearDown(container.dispose);
          final notifier = container.read(favoritesProvider(config).notifier);
          await notifier.checkFavorites([1]);
          await container
              .read(danbooruPostVotesProvider(config).notifier)
              .upvote(1, localOnly: true);
          final priorVote = container.read(
            danbooruPostVotesProvider(config),
          )[1];
          var callback = 0;
          FavoriteCompletedWithInterruption? cleanup;
          final action = collectFavoriteInterruptions(() async {
            if (await notifier.remove(1)) callback++;
          }, (error) => cleanup = error);
          if (firstFails) {
            await expectLater(action, throwsA(isA<DioException>()));
          } else {
            await action;
            expect(
              cleanup?.interruption.type,
              cancel ? DioExceptionType.cancel : DioExceptionType.unknown,
            );
          }
          expect(transport.mutations, 1);
          expect(callback, firstFails ? 0 : 1);
          expect(container.read(favoritesProvider(config))[1], firstFails);
          expect(
            container.read(danbooruPostVotesProvider(config))[1],
            priorVote,
          );
          expect(voteRepo.removes, firstFails ? 0 : 1);
        },
      );
    }
  }
  testWidgets(
    'confirmed cleanup produces no late wait after owning route removal',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData.light().withBoorusamaColors(),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: OKToast(child: child!),
            ),
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );
      final error = _interruption(false);
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: FavoritePostButton(
              isFaved: true,
              isAuthorized: true,
              addFavorite: () async {},
              removeFavorite: () async {
                reportCompletedFavoriteInterruption(
                  FavoriteCompletedWithInterruption(error, StackTrace.current),
                );
                Navigator.of(context).pop();
                await WidgetsBinding.instance.endOfFrame;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(FavoritePostButton), findsNothing);
      expect(find.textContaining('Rate limited by the site'), findsNothing);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'shared utility returns confirmed removal while reporting cleanup wait',
    (tester) async {
      BuildContext? context;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: ThemeData.light().withBoorusamaColors(),
            builder: (context, child) => OKToast(child: child!),
            home: Builder(
              builder: (c) {
                context = c;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      var callback = 0;
      // This is the same utility boundary used by toolbar, quick and menu actions.
      final error = _interruption(false);
      final result = await runFavoriteAction(context!, () async {
        final handled = reportCompletedFavoriteInterruption(
          FavoriteCompletedWithInterruption(error, StackTrace.current),
        );
        expect(handled, true);
        callback++;
        return true;
      });
      await tester.pumpAndSettle();
      expect(result?.value, true);
      expect(result?.cleanupInterrupted, true);
      expect(callback, 1);
      expect(
        find.textContaining('Rate limited by the site. Try again in'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    },
  );
}

DioException _interruption(bool cancel) {
  final cooldown = ApiCooldownException(
    ApiQuotaKey.fromUri(Uri.parse('https://site.test')),
    DateTime.now().toUtc().add(const Duration(seconds: 30)),
  );
  return DioException(
    requestOptions: RequestOptions(
      path: '/votes',
      extra: {
        if (!cancel) 'boorusama.request.cooldown': cooldown,
      },
    ),
    type: cancel ? DioExceptionType.cancel : DioExceptionType.unknown,
    error: cancel ? null : cooldown,
  );
}

class _FavoriteTransport implements HttpClientAdapter {
  _FavoriteTransport({required this.firstFails, required this.cancel});
  final bool firstFails;
  final bool cancel;
  var mutations = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      mutations++;
      if (firstFails) {
        if (cancel) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          );
        }
        return ResponseBody.fromString(
          '',
          429,
          headers: {
            'retry-after': ['30'],
          },
        );
      }
      return ResponseBody.fromString('', 200);
    }
    return ResponseBody.fromString(
      '[{"id":7,"post_id":1,"user_id":0}]',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Votes implements PostVoteRepository {
  _Votes({required this.cancel});
  final bool cancel;
  var removes = 0;
  @override
  Future<bool> removeVote(PostVoteId id) {
    removes++;
    return Future<bool>.error(_interruption(cancel));
  }

  @override
  Future<List<DanbooruPostVote>> getPostVotesFromUser(
    List<int> ids,
    int userId,
  ) async => [
    DanbooruPostVote.local(
      postId: 1,
      score: 1,
    ).copyWith(voteId: const PostVoteId.fromInt(9)),
  ];
  @override
  Future<List<DanbooruPostVote>> getPostVotes(int id, {int? page}) async => [];
  @override
  Future<DanbooruPostVote?> upvote(int id) async => null;
  @override
  Future<DanbooruPostVote?> downvote(int id) async => null;
}
