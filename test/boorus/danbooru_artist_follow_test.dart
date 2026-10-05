import 'dart:ui' show SemanticsAction;

import 'package:boorusama/core/artists/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/types/search_following_feed.dart';
import 'package:boorusama/core/search/subscriptions/src/types/search_organization.dart';
import 'package:boorusama/core/search/subscriptions/src/types/search_subscription.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/feed_follow_control.dart';
import 'package:boorusama/core/posts/details_parts/src/source_link.dart';
import 'package:boorusama/boorus/danbooru/posts/details/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  const colors = (
    primary: Color(0xffa82753),
    onPrimary: Color(0xfffff2e9),
    surfaceContainerHighest: Color(0xffe1e7e8),
    onSurfaceVariant: Color(0xff39484a),
  );
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: colors.primary,
      ).copyWith(
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        surfaceContainerHighest: colors.surfaceContainerHighest,
        onSurfaceVariant: colors.onSurfaceVariant,
      );

  final cases = [
    (artistTags: <String>{}, followQuery: null),
    (artistTags: <String>{'artist_one'}, followQuery: 'artist_one'),
    (
      artistTags: <String>{'artist_one', 'artist_two'},
      followQuery: null,
    ),
  ];

  for (final testCase in cases) {
    testWidgets(
      'shows Follow only for one artist tag (${testCase.artistTags.length})',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentReadOnlyBooruConfigProvider.overrideWithValue(
                BooruConfig.empty,
              ),
              pinnedSearchTrackingSupportedProvider.overrideWith(
                (ref, config) => true,
              ),
              searchSubscriptionsProvider.overrideWith(
                _TestSearchSubscriptionsNotifier.new,
              ),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
                home: Scaffold(
                  body: DanbooruArtistInfo(
                    commentary: const ArtistCommentary.description(
                      'Artist commentary',
                    ),
                    artistTags: testCase.artistTags,
                    source: RawWebSource(
                      faviconUrl: null,
                      url: 'https://source.example/post',
                      uri: Uri.parse('https://source.example/post'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        if (testCase.followQuery case final query?) {
          expect(find.byType(FeedFollowButton), findsOneWidget);
          expect(find.text('Follow'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is FeedFollowButton && widget.query == query,
            ),
            findsOneWidget,
          );
        } else {
          expect(find.byType(FeedFollowButton), findsNothing);
          expect(find.text('Follow'), findsNothing);
        }
        if (testCase.artistTags.isNotEmpty) {
          expect(find.text(testCase.artistTags.join(' ')), findsOneWidget);
          expect(find.text('https://source.example/post'), findsOneWidget);
        }
        expect(find.text('Artist commentary'), findsOneWidget);
      },
    );
  }

  final visualCases = [
    (
      label: 'Follow',
      isFollowing: false,
      background: colors.primary,
      foreground: colors.onPrimary,
    ),
    (
      label: 'Following',
      isFollowing: true,
      background: colors.surfaceContainerHighest,
      foreground: colors.onSurfaceVariant,
    ),
  ];

  for (final testCase in visualCases) {
    testWidgets(
      'shows an accessible icon-free ${testCase.label} pill using theme colors',
      (tester) async {
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentReadOnlyBooruConfigProvider.overrideWithValue(
                BooruConfig.empty,
              ),
              pinnedSearchTrackingSupportedProvider.overrideWith(
                (ref, config) => true,
              ),
              searchSubscriptionsProvider.overrideWith(
                () => _TestSearchSubscriptionsNotifier(
                  following: testCase.isFollowing,
                ),
              ),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                theme: ThemeData(colorScheme: colorScheme),
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
                home: Scaffold(
                  body: DanbooruArtistInfo(
                    commentary: const ArtistCommentary.description(
                      'Artist commentary',
                    ),
                    artistTags: const {'artist_one'},
                    source: RawWebSource(
                      faviconUrl: null,
                      url: 'https://source.example/post',
                      uri: Uri.parse('https://source.example/post'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final label = find.text(testCase.label);
        expect(label, findsOneWidget);
        expect(find.byIcon(Symbols.rss_feed), findsNothing);
        expect(find.bySemanticsLabel(testCase.label), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(testCase.label))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );

        final pill = find
            .ancestor(
              of: label,
              matching: find.byWidgetPredicate(
                (widget) => widget is Material && widget.shape is StadiumBorder,
              ),
            )
            .first;
        final pillMaterial = tester.widget<Material>(pill);
        expect(pillMaterial.color, testCase.background);
        expect(pillMaterial.shape, isA<StadiumBorder>());
        expect(
          DefaultTextStyle.of(tester.element(label)).style.color,
          testCase.foreground,
        );
        expect(tester.getRect(pill).height, greaterThanOrEqualTo(48));
        semantics.dispose();

        await tester.tap(label);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        if (testCase.isFollowing) {
          expect(find.text('Artists'), findsOneWidget);
          final checkbox = tester.widget<CheckboxListTile>(
            find.byType(CheckboxListTile),
          );
          expect(checkbox.value, isTrue);
        } else {
          expect(find.text('No following feeds yet.'), findsOneWidget);
        }
      },
    );
  }

  final geometryCases = [
    (name: 'narrow width', width: 320.0, textScale: 1.0),
    (name: 'enlarged text', width: 400.0, textScale: 2.0),
  ];

  for (final testCase in geometryCases) {
    testWidgets(
      'keeps Follow in the artist row at ${testCase.name}',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentReadOnlyBooruConfigProvider.overrideWithValue(
                BooruConfig.empty,
              ),
              pinnedSearchTrackingSupportedProvider.overrideWith(
                (ref, config) => true,
              ),
              searchSubscriptionsProvider.overrideWith(
                _TestSearchSubscriptionsNotifier.new,
              ),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: testCase.width,
                      child: MediaQuery(
                        data: MediaQueryData(
                          size: Size(testCase.width, 720),
                          textScaler: TextScaler.linear(testCase.textScale),
                        ),
                        child: const DanbooruArtistInfo(
                          commentary: ArtistCommentary(
                            originalTitle: 'Original title',
                            originalDescription: 'Original commentary',
                            translatedTitle: 'Translated title',
                            translatedDescription: 'Translated commentary',
                          ),
                          artistTags: {'artist_one'},
                          source: NonWebSource('original source'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final artistTile = tester.getRect(find.byType(SourceLink));
        final followButton = tester.getRect(find.byType(FeedFollowButton));
        expect(artistTile.overlaps(followButton), isTrue);
        expect(find.byIcon(Symbols.keyboard_arrow_down), findsOneWidget);
        expect(find.byIcon(Symbols.rss_feed), findsNothing);
        expect(
          followButton.overlaps(
            tester.getRect(find.byIcon(Symbols.keyboard_arrow_down)),
          ),
          isFalse,
        );
        expect(followButton.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _TestSearchSubscriptionsNotifier extends SearchSubscriptionsNotifier {
  _TestSearchSubscriptionsNotifier({this.following = false});

  final bool following;

  @override
  Future<SearchSubscriptionsState> build() async => SearchSubscriptionsState(
    subscriptions: following
        ? [
            SearchSubscription.create(
              id: 'artist-search',
              profileId: BooruConfig.empty.id,
              query: 'artist_one',
              name: null,
              position: 0,
              createdAt: DateTime.utc(2026),
            ),
          ]
        : const [],
    feeds: following
        ? [
            SearchFollowingFeed(
              id: 'artist-feed',
              profileId: BooruConfig.empty.id,
              name: 'Artists',
              sourceIds: const ['artist-search'],
            ),
          ]
        : const [],
    refreshingIds: const {},
    batchCompleted: 0,
    batchTotal: 0,
    organization: SearchOrganization(
      folders: const [],
      homeSearchIds: const [],
    ),
  );
}
