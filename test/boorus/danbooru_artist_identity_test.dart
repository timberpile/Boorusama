import 'package:boorusama/boorus/danbooru/posts/details/widgets.dart';
import 'package:boorusama/core/artists/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/details_parts/src/source_link.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:boorusama/foundation/url_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

const _artistTag = 'Artist_漢字_With_Underscores';

void main() {
  final sources = [
    (label: 'missing', source: PostSource.none(), url: null),
    (
      label: 'non-web',
      source: const NonWebSource('drawn from memory'),
      url: null,
    ),
    (
      label: 'web',
      source: PostSource.from('https://source.example/art/42'),
      url: 'https://source.example/art/42',
    ),
    (
      label: 'Pixiv',
      source: PostSource.pixiv(42),
      url: 'https://www.pixiv.net/en/artworks/42',
    ),
    (
      label: 'invalid web',
      source: RawWebSource(
        faviconUrl: null,
        url: 'javascript:alert(1)',
        uri: Uri.parse('javascript:alert(1)'),
      ),
      url: null,
    ),
  ];

  for (final scenario in sources) {
    testWidgets('artist identity and Follow survive ${scenario.label} source', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      final harness = FollowingTopicHarness(
        overrides: [externalUrlLauncherProvider.overrideWithValue(launcher)],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        CurrentBooruConfigScope(
          config: otherTestProfile,
          child: Scaffold(
            body: DanbooruArtistInfo(
              artistTags: const {_artistTag},
              commentary: const ArtistCommentary.empty(),
              source: scenario.source,
            ),
          ),
        ),
      );
      expect(find.byType(SourceLink), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text(_artistTag), findsOneWidget);
      expect(find.byType(FollowTopicButton), findsOneWidget);
      expect(
        tester.widget<FollowTopicButton>(find.byType(FollowTopicButton)).query,
        _artistTag,
      );
      expect(find.byTooltip('View Artist: $_artistTag'), findsOneWidget);
      if (scenario.url case final url?) {
        await tester.tap(find.text(url));
        await tester.pump();
        expect(launcher.urls, [Uri.parse(url)]);
      } else {
        expect(tester.widget<SourceLink>(find.byType(SourceLink)).url, isNull);
        expect(launcher.urls, isEmpty);
      }
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(_artistTag),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final tags in [
    <String>{},
    {'', '  ', '\n'},
  ]) {
    testWidgets('empty artist tags expose no identity or navigation ($tags)', (
      tester,
    ) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: DanbooruArtistInfo(
            artistTags: tags,
            source: PostSource.none(),
            commentary: const ArtistCommentary.description(
              'Commentary stays available',
            ),
          ),
        ),
      );
      expect(find.byType(SourceLink), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(FollowTopicButton), findsNothing);
      expect(find.byTooltip('View Artist'), findsNothing);
      expect(find.text('Commentary stays available'), findsOneWidget);
    });
  }

  for (final multiple in [false, true]) {
    testWidgets(
      'avatar routes the explicitly selected artist in its originating profile ($multiple)',
      (tester) async {
        final launcher = _RecordingLauncher();
        final harness = FollowingTopicHarness(
          overrides: [externalUrlLauncherProvider.overrideWithValue(launcher)],
        );
        addTearDown(harness.dispose);
        String? openedArtist;
        BooruConfig? openedConfig;
        harness.router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, state) => CurrentBooruConfigScope(
                config: otherTestProfile,
                child: Scaffold(
                  body: DanbooruArtistInfo(
                    artistTags: multiple
                        ? {'artist_two', _artistTag}
                        : {' ', _artistTag},
                    commentary: const ArtistCommentary.empty(),
                    source: PostSource.from('https://source.example/art/42'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/artists',
              builder: (_, state) {
                openedArtist = state.uri.queryParameters[kArtistNameKey];
                openedConfig = state.extra! as BooruConfig;
                return const Scaffold(body: Text('Artist destination'));
              },
            ),
          ],
        );
        addTearDown(harness.router.dispose);
        await harness.pump(tester, const SizedBox.shrink());
        await tester.pumpWidget(
          harness.wrap(
            MaterialApp.router(
              routerConfig: harness.router,
              builder: themeBuilder,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('https://source.example/art/42'));
        await tester.pump();
        expect(launcher.urls, [Uri.parse('https://source.example/art/42')]);
        expect(openedArtist, isNull);
        final avatar = find.byTooltip(
          multiple ? 'View Artist' : 'View Artist: $_artistTag',
        );
        expect(tester.getSize(avatar).shortestSide, greaterThanOrEqualTo(48));
        await tester.tap(avatar);
        await tester.pumpAndSettle();
        if (multiple) {
          expect(openedArtist, isNull);
          expect(find.byType(FollowTopicButton), findsNothing);
          await tester.tap(
            find.descendant(
              of: find.byType(KurumiPopupMenuItem),
              matching: find.text(_artistTag),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(openedArtist, _artistTag);
        expect(openedConfig, otherTestProfile);
        expect(
          harness.container.read(selectedTestProfileProvider),
          testProfile,
        );
        expect(launcher.urls, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'source-free commentary controls stay independent of artist navigation',
    (tester) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: DanbooruArtistInfo(
            artistTags: const {_artistTag},
            source: PostSource.none(),
            commentary: const ArtistCommentary(
              originalTitle: 'Original title',
              originalDescription: 'Original body',
              translatedTitle: 'Translated title',
              translatedDescription: 'Translated body',
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Translated body', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Symbols.keyboard_arrow_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Original'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Original body', findRichText: true),
        findsOneWidget,
      );
      expect(find.byTooltip('View Artist: $_artistTag'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
    },
  );

  for (final size in [
    (width: 320.0, scale: 2.0),
    (width: 1200.0, scale: 1.0),
  ]) {
    for (final multiple in [false, true]) {
      testWidgets(
        'artist controls and chooser fit ${size.width} at ${size.scale}x ($multiple)',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(size.width, 800);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = FollowingTopicHarness();
          addTearDown(harness.dispose);
          await harness.pump(
            tester,
            MediaQuery(
              data: MediaQueryData(
                size: Size(size.width, 800),
                textScaler: TextScaler.linear(size.scale),
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DanbooruArtistInfo(
                    artistTags: multiple
                        ? {_artistTag, 'another_long_artist_name_アーティスト'}
                        : {_artistTag},
                    source: PostSource.from(
                      'https://source.example/a/very/long/source/path',
                    ),
                    commentary: const ArtistCommentary(
                      originalTitle: 'Original',
                      originalDescription: 'Original text',
                      translatedTitle: 'Translated',
                      translatedDescription: 'Translated text',
                    ),
                  ),
                ),
              ),
            ),
          );
          if (multiple) {
            await tester.tap(find.byTooltip('View Artist'));
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: find.byType(KurumiPopupMenuItem),
                matching: find.text(_artistTag),
              ),
              findsOneWidget,
            );
          } else {
            final follow = tester.getRect(find.byType(FollowTopicButton));
            final avatar = tester.getRect(
              find.byTooltip('View Artist: $_artistTag'),
            );
            expect(follow.overlaps(avatar), isFalse);
            expect(
              follow.overlaps(
                tester.getRect(find.byIcon(Symbols.keyboard_arrow_down)),
              ),
              isFalse,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _RecordingLauncher implements ExternalUrlLauncher {
  final urls = <Uri>[];
  @override
  Future<bool> launch(
    Uri url, {
    ExternalLaunchMode mode = ExternalLaunchMode.externalApplication,
  }) async {
    urls.add(url);
    return true;
  }
}
