import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/favorites/src/data/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/providers.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_button_state_provider.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/votes/types.dart';
import 'package:boorusama/core/posts/votes/widgets.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/bookmark_post_button.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:boorusama/core/widgets/booru_menu_button_row.dart';
import 'package:boorusama/core/widgets/adaptive_button_row.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'test_support.dart';

void main() {
  for (final ignore in [false, true]) {
    testWidgets(
      'profile favorite updates heart vote and bookmark widgets (ignore: $ignore)',
      (tester) async {
        final h = FavoriteHarness();
        final requests = <String>[];
        await tester.runAsync(
          () => h.open(
            extraOverrides: (profile) => [
              danbooruClientProvider(profile.auth).overrideWithValue(
                DanbooruClient(
                  baseUrl: profile.url,
                  dio: Dio(BaseOptions(baseUrl: profile.url))
                    ..httpClientAdapter = _Server(requests),
                ),
              ),
              favoriteRepoProvider(profile.auth).overrideWith(
                (ref) => createConfirmedFavoriteRepository(
                  ref,
                  profile.auth,
                  ref.watch(danbooruFavoriteRepoProvider(profile.auth)),
                ),
              ),
            ],
          ),
        );
        addTearDown(h.close);
        final container = h.container;
        final group = await tester.runAsync(() async {
          final group = await container
              .read(bookmarkProvider.notifier)
              .createGroup('Favorites');
          final settings = container.read(
            serverFavoriteSettingsProvider.notifier,
          );
          await settings.setGlobal(group.id);
          final baseline = container
              .read(serverFavoriteSettingsProvider)
              .requireValue;
          await settings.saveAll(
            profiles: h.profiles.profiles,
            expected: baseline,
            updated: baseline.withIgnoreBookmarkStatus(ignore),
          );
          return group;
        });
        final identity = bookmarkIdentityForPost(
          h.post(1),
          h.profile.booruIdHint,
        );
        final heart = container.listen(
          favoriteProvider((h.profile.auth, 1)),
          (_, _) {},
        );
        final vote = container.listen(
          danbooruPostVoteProvider((h.profile.auth, 1)),
          (_, _) {},
        );
        final bookmark = container.listen(
          bookmarkButtonStateProvider(identity),
          (_, _) {},
        );
        addTearDown(heart.close);
        addTearDown(vote.close);
        addTearDown(bookmark.close);
        expect(heart.read(), isFalse);
        expect(bookmark.read().presentation!.isBookmarked, isFalse);
        final favorites = container.read(
          favoritesProvider(h.profile.auth).notifier,
        );
        Future<AddFavoriteStatus>? adding;
        Future<bool>? removing;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: BooruLocalization(
              child: MaterialApp(
                theme: ThemeData(
                  extensions: const [KurumiExtendedColorScheme()],
                ).withBoorusamaColors(),
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) {
                      final isFaved = ref.watch(
                        favoriteProvider((h.profile.auth, 1)),
                      );
                      final voted = ref.watch(
                        danbooruPostVoteProvider((h.profile.auth, 1)),
                      );
                      return BooruMenuButtonRow(
                        buttons: [
                          ButtonData(
                            title: 'Favorite',
                            widget: FavoritePostButton(
                              isFaved: isFaved,
                              isAuthorized: true,
                              addFavorite: () => adding = favorites.add(
                                1,
                                profileId: h.profile.id,
                              ),
                              removeFavorite: () => removing = favorites.remove(
                                1,
                                profileId: h.profile.id,
                              ),
                            ),
                          ),
                          ButtonData(
                            title: 'Upvote',
                            widget: UpvotePostButton(
                              voteState: voted?.voteState ?? VoteState.unvote,
                              onUpvote: () {},
                              onRemoveUpvote: () {},
                            ),
                          ),
                          ButtonData(
                            title: 'Bookmark',
                            widget: BookmarkPostButton(
                              post: h.post(1),
                              config: h.profile.auth,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          await tester.runAsync(() async {
            await tester.tap(find.byType(FavoritePostButton));
            return await adding!;
          }),
          AddFavoriteStatus.success,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Icon>(find.byIcon(Symbols.favorite)).fill, 1);
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.arrow_upward)).color,
          isNotNull,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.bookmark)).fill,
          ignore ? 0 : 1,
        );
        expect(heart.read(), isTrue);
        expect(vote.read()?.voteState, VoteState.upvoted);
        expect(bookmark.read().presentation!.isBookmarked, !ignore);
        expect(
          container
              .read(bookmarkProvider)
              .requireValue
              .membershipsFor(identity),
          {group!.id},
        );
        expect(
          await tester.runAsync(() async {
            await tester.tap(find.byType(FavoritePostButton));
            return await removing!;
          }),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.favorite)).fill,
          isNot(1),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.arrow_upward)).color,
          isNull,
        );
        expect(tester.widget<Icon>(find.byIcon(Symbols.bookmark)).fill, 0);
        expect(heart.read(), isFalse);
        expect(vote.read(), isNull);
        expect(bookmark.read().presentation!.isBookmarked, isFalse);
        expect(requests, ['POST /favorites.json', 'DELETE /favorites/1.json']);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Server implements HttpClientAdapter {
  _Server(this.requests);
  final List<String> requests;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{}),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
