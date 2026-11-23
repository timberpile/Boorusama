import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/navigation_pages.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/providers.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/types.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/src/types/artist_repository.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/explores/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final artistPage in [true, false]) {
      testWidgets(
        '${artistPage ? 'Artist search' : 'Explore'} clears the shell at text scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final media = ValueNotifier(
            MediaQueryData(
              size: const Size(320, 640),
              padding: const EdgeInsets.only(bottom: 104),
              textScaler: TextScaler.linear(scale),
            ),
          );
          addTearDown(media.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
                  BooruConfig.empty.auth,
                ),
                booruEngineRegistryProvider.overrideWithValue(
                  BooruEngineRegistry(),
                ),
                danbooruArtistRepoProvider.overrideWith(
                  (ref, config) => _Artists(),
                ),
              ],
              child: BooruLocalization(
                child: MaterialApp(
                  builder: (context, child) => KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: ValueListenableBuilder<MediaQueryData>(
                      valueListenable: media,
                      builder: (_, data, child) =>
                          MediaQuery(data: data, child: child!),
                      child: child,
                    ),
                  ),
                  home: Builder(
                    builder: (context) => artistPage
                        ? buildEngineNavigationPage(
                            context,
                            BooruConfig.empty,
                            'danbooru.artists',
                          )
                        : const Scaffold(
                            body: ExplorePage(
                              useAppBarPadding: false,
                              sliverOverviews: [
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 1200,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Text('Last explore action'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final (bottom, keyboard) in [
            (104.0, 0.0),
            (24.0, 0.0),
            (0.0, 240.0),
            (104.0, 0.0),
          ]) {
            media.value = media.value.copyWith(
              padding: EdgeInsets.only(bottom: bottom),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            );
            await tester.pumpAndSettle();
            final last = find.text(
              artistPage ? 'Artist 19' : 'Last explore action',
            );
            final scrollable = find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(last, 200, scrollable: scrollable);
            await tester.pumpAndSettle();
            final scroll = tester.state<ScrollableState>(scrollable).position;
            scroll.jumpTo(scroll.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(last.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(last).bottom,
              lessThanOrEqualTo(640 - bottom - keyboard + 0.5),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}

class _Artists implements DanbooruArtistRepository {
  @override
  Future<List<DanbooruArtist>> getArtists({
    String? name,
    String? url,
    bool? isDeleted,
    bool? isBanned,
    bool? hasTag,
    bool? includeTag,
    ArtistOrder? order,
    CancelToken? cancelToken,
    int? page,
  }) async => page == 1
      ? [
          for (var i = 0; i < 20; i++)
            DanbooruArtist.empty().copyWith(id: i + 1, name: 'Artist $i'),
        ]
      : [];

  @override
  Future<DanbooruArtist> getArtist(String name, {CancelToken? cancelToken}) =>
      throw UnimplementedError();
}
