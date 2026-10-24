import 'package:boorusama/core/search/following_topics/src/types/topic_query_display.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_topic.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_query_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/tags/categories/providers.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:boorusama/core/search/following_topics/src/providers/topic_query_tag_categories_provider.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final styleName in ['inherited', 'body', 'title']) {
      testWidgets('chips retain normal $styleName text height at ${scale}x', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                MaterialUiCompatibilityBridge(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final style = switch (styleName) {
                    'body' => Theme.of(context).textTheme.bodyMedium,
                    'title' => Theme.of(context).textTheme.titleMedium,
                    _ => null,
                  };
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'artist name',
                          style: style,
                          key: const Key('plain'),
                        ),
                        FollowingTopicQueryText(
                          query: 'artist_name',
                          style: style,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        final plainHeight = tester
            .getSize(find.byKey(const Key('plain')))
            .height;
        expect(
          tester.getSize(find.byType(KurumiRawCompactChip)).height,
          closeTo(plainHeight, 0.01),
        );
        expect(
          tester.getSize(find.byType(FollowingTopicQueryText)).height,
          closeTo(plainHeight, 0.01),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final missing in [false, true]) {
      testWidgets(
        'query chips use profile-specific backgrounds and handle failure ($missing/$brightness)',
        (tester) async {
          final first = BooruConfig.empty.auth;
          final second = BooruConfig.fromJson({
            ...BooruConfig.empty.toJson(),
            'id': '00000000-0000-4000-8000-000000000051',
            'url': 'https://other.example/',
          }).auth;
          final lookups = <(BooruConfigAuth, String)>[];
          final palette = BooruChipColors.colorScheme(
            ColorScheme.fromSeed(seedColor: Colors.red, brightness: brightness),
          );
          final container = ProviderContainer(
            overrides: [
              booruTagTypeProvider.overrideWith((ref, key) async {
                lookups.add(key);
                if (missing) throw StateError('cache unavailable');
                return key.$2 == 'unknown' ? null : 'artist';
              }),
              topicQueryTagCategoriesProvider.overrideWith((ref, key) async {
                if (missing) throw StateError('metadata unavailable');
                return {'artist_name': 'artist', '日本語_タグ': 'artist'};
              }),
              booruChipColorsProvider.overrideWithValue(
                palette,
              ),
              tagColorProvider.overrideWith(
                (ref, key) => key.$1 == first ? Colors.red : Colors.blue,
              ),
            ],
          );
          addTearDown(container.dispose);
          Future<List<KurumiRawCompactChip>> pump(BooruConfigAuth auth) async {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) =>
                      MaterialUiCompatibilityBridge(child: child!),
                  home: FollowingTopicQueryText(
                    auth: auth,
                    query: '-artist_name unknown rating:safe source:"https://site.test/a_b" 日本語_タグ',
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text('-artist name', findRichText: true),
              findsOneWidget,
            );
            expect(
              find.text('rating:safe', findRichText: true),
              findsOneWidget,
            );
            expect(
              find.text('source:"https://site.test/a_b"', findRichText: true),
              findsOneWidget,
            );
            return tester
                .widgetList<KurumiRawCompactChip>(
                  find.byType(KurumiRawCompactChip),
                )
                .toList();
          }

          final chips = await pump(first);
          if (!missing) {
            expect(
              chips.first.backgroundColor,
              palette.fromColor(Colors.red)!.backgroundColor,
            );
            expect(
              chips.first.foregroundColor,
              palette.fromColor(Colors.red)!.foregroundColor,
            );
          }
          final changed = await pump(second);
          if (!missing)
            expect(
              changed.first.backgroundColor,
              palette.fromColor(Colors.blue)!.backgroundColor,
            );
          expect(chips, hasLength(5));

          expect(lookups.map((p) => p.$2).toSet(), {
            'artist_name',
            'unknown',
            '日本語_タグ',
          });
          expect(lookups.map((p) => p.$1).toSet(), {first, second});
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test('formats ordinary tags without serializing the saved query', () {
    const query =
        '  artist_name -blue_hair ~green_eyes rating:safe order:score  ';
    final tokens = topicQueryDisplayTokens(query);
    expect(tokens.map((token) => token.raw).join(), query);
    expect(
      tokens.map((token) => '${token.operator}${token.displayBody}').join(),
      '  artist name -blue hair ~green eyes rating:safe order:score  ',
    );
    expect(tokens.map((token) => token.tagName).whereType<String>(), [
      'artist_name',
      'blue_hair',
      'green_eyes',
    ]);
  });

  test('retains quoted, escaped, grouped, wildcard, and unknown syntax', () {
    for (final query in [
      'source:"https://example.test/a_b?q=two words" artist_name',
      'custom:"unclosed quoted_value and spaces',
      r'custom:"escaped\" quote" -known_tag',
      '{ blue_hair OR green_eyes } rating:unknown_value',
      'name* [unknown_syntax] - ~',
      '',
      ' \t\n ',
    ]) {
      final tokens = topicQueryDisplayTokens(query);
      expect(tokens.map((token) => token.raw).join(), query);
      for (final token in tokens.where((token) => token.tagName == null)) {
        expect('${token.operator}${token.displayBody}', token.raw);
      }
    }
  });

  testWidgets(
    'compact query text remains usable at narrow width and large text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              MaterialUiCompatibilityBridge(child: child!),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const SizedBox(
                width: 160,
                child: FollowingTopicQueryText(
                  query: 'artist_name -blue_hair order:score',
                ),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(FollowingTopicQueryText),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(find.byType(KurumiRawCompactChip), findsNWidgets(3));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom names remain verbatim and card actions remain available',
    (tester) async {
      final topic = FollowingTopic.create(
        id: 'topic',
        profileId: 'profile',
        query: 'artist_name -blue_hair',
        name: 'My_Custom Name',
        position: 0,
        createdAt: DateTime.utc(2026),
      );
      var opened = false;
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            builder: (context, child) =>
                MaterialUiCompatibilityBridge(child: child!),
            home: Scaffold(
              body: FollowingTopicCard(
                topic: topic,
                config: null,
                refreshing: false,
                onOpen: () => opened = true,
                onAction: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('My_Custom Name'), findsOneWidget);
      expect(find.byType(FollowingTopicQueryText), findsOneWidget);
      // The passive chip ignores pointer events; its enclosing card handles them.
      await tester.tapAt(
        tester.getCenter(find.text('artist name', findRichText: true)),
      );
      expect(opened, isTrue);
      expect(topic.query, 'artist_name -blue_hair');
      expect(topic.name, 'My_Custom Name');
      expect(tester.takeException(), isNull);
    },
  );
}
