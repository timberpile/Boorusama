import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/following_topics/src/providers/cached_feed_tag_index_provider.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/suggestions/tag_suggestion_item.dart';
import 'package:boorusama/core/tags/categories/providers.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/tags/local/types.dart';
import 'package:boorusama/core/tags/tag/colors.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_option_selector.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/types/cached_topic_feed_filter.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/cached_feed_filter_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import 'following_topic_test_utils.dart';
import '../../../application/support/fake_image_dio.dart';

import 'package:boorusama/core/config_widgets/website_logo.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(
    () => harness = FollowingTopicHarness(
      overrides: [
        deterministicFaviconDioOverride(),
        booruTagTypeStoreProvider.overrideWith(
          (ref) => Future.value(_TagStore()),
        ),
        enableDynamicColoringProvider.overrideWithValue(false),
        colorSchemeProvider.overrideWithValue(ThemeData().colorScheme),
      ],
    ),
  );
  tearDown(() => harness.dispose());

  test('resolves cached tag metadata under the origin profile URL', () {
    harness.dispose();
    final profile = testProfile.copyWith(
      url: 'https://a.example/nested/',
      booruIdHint: BooruType.danbooru.id,
    );
    harness = FollowingTopicHarness(profiles: [profile]);
    final snapshot = StoredPostSnapshot(
      origin: PostOriginSnapshot(
        booruTypeId: profile.booruIdHint,
        booruId: profile.booruIdHint,
        sourceHost: 'a.example/nested',
        profileIdHint: profile.id,
      ),
      common: _snapshot.common,
      custom: const {},
      codecVersion: 1,
    );
    final index = harness.container.read(
      cachedFeedTagIndexProvider(([snapshot], const CachedTopicFeedFilter())),
    );
    expect(index.byName['cat']!.sources.keys.single.url, profile.url);
  });

  testWidgets('drafts remain local and suggestions use only cached tags', (
    tester,
  ) async {
    final filters = <CachedTopicFeedFilter>[];
    await harness.pump(
      tester,
      Scaffold(
        body: CachedFeedFilterBar(
          snapshots: const [_snapshot],
          onChanged: filters.add,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'blue hair');
    await tester.pumpAndSettle();
    expect(filters, isEmpty);
    expect(harness.requests, isEmpty);
    expect(
      find.byKey(const ValueKey('feed-filter-suggestion-blue_hair')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('feed-filter-suggestion-blue_hair')),
    );
    await tester.pump();
    expect(filters.single.query, 'blue_hair');
    expect(harness.requests, isEmpty);
  });

  testWidgets('colors cached categories in suggestions and selected chips', (
    tester,
  ) async {
    final filters = <CachedTopicFeedFilter>[];
    final snapshot = StoredPostSnapshot(
      origin: _snapshot.origin,
      common: {
        ..._snapshot.common,
        'tags': const ['artist_name', 'character_name', 'copyright_name'],
        'artistTags': const ['artist_name'],
        'characterTags': const ['character_name'],
        'copyrightTags': const ['copyright_name'],
      },
      custom: const {},
      codecVersion: 1,
    );
    await harness.pump(
      tester,
      Scaffold(
        body: CachedFeedFilterBar(
          snapshots: [snapshot],
          onChanged: filters.add,
        ),
      ),
    );
    expect(find.text('Search Cached Posts...'), findsOneWidget);
    expect(find.text('Cached Posts Only'), findsNothing);
    expect(find.byIcon(Symbols.search), findsNothing);
    expect(
      tester.widget<BooruSearchBar>(find.byType(BooruSearchBar)).leading,
      isNull,
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final scheme = Kurumi.themeOf(
      tester.element(find.byType(CachedFeedFilterBar)),
    ).colorScheme;
    final colors = TagColors.fromBrightness(scheme.brightness);
    for (final (tag, color) in [
      ('artist_name', colors.artist),
      ('character_name', colors.character),
      ('copyright_name', colors.copyright),
    ]) {
      final suggestion = find.byKey(ValueKey('feed-filter-suggestion-$tag'));
      expect(tester.widget<TagSuggestionItem>(suggestion).textColor, color);
    }
    await tester.tap(
      find.byKey(const ValueKey('feed-filter-suggestion-artist_name')),
    );
    await settle(tester);
    expect(
      tester.widget<SelectedTagChip>(find.byType(SelectedTagChip)).tagColor,
      colors.artist,
    );
    expect(filters.single.query, 'artist_name');
    expect(harness.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'suggestions and counts narrow with tags and broaden after removal',
    (tester) async {
      final filters = <CachedTopicFeedFilter>[];
      final snapshots = [
        _post(1, ['cat', 'blue_hair', 'green_eyes']),
        _post(2, ['cat', 'blue_hair', 'red_eyes']),
        _post(3, ['cat', 'red_hair', 'yellow_eyes']),
        _post(4, ['dog', 'red_hair', 'purple_eyes']),
      ];
      await harness.pump(
        tester,
        Scaffold(
          body: CachedFeedFilterBar(
            snapshots: snapshots,
            onChanged: filters.add,
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.enterText(field, 'cat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(_suggestion(tester, 'blue_hair').tag.postCount, 2);
      expect(_suggestion(tester, 'red_hair').tag.postCount, 1);
      expect(
        find.byKey(const ValueKey('feed-filter-suggestion-dog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('feed-filter-suggestion-purple_eyes')),
        findsNothing,
      );
      await tester.enterText(field, 'blue');
      await tester.pumpAndSettle();
      expect(filters.last.query, 'cat');
      await tester.tap(
        find.byKey(const ValueKey('feed-filter-suggestion-blue_hair')),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(filters.last.query, 'cat blue_hair');
      expect(_suggestion(tester, 'red_eyes').tag.postCount, 1);
      expect(
        find.byKey(const ValueKey('feed-filter-suggestion-red_hair')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('feed-filter-suggestion-yellow_eyes')),
        findsNothing,
      );
      // Submit dismisses the overlay before operating on the selected chip.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      final chip = find.byWidgetPredicate(
        (widget) =>
            widget is SelectedTagChip &&
            widget.tagSearchItem.rawTag == 'blue_hair',
      );
      await tester.tap(
        find.descendant(of: chip, matching: find.byIcon(Symbols.close)),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(filters.last.query, 'cat');
      expect(_suggestion(tester, 'blue_hair').tag.postCount, 2);
      expect(_suggestion(tester, 'red_hair').tag.postCount, 1);
      expect(harness.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('negative tags and source both constrain suggestions', (
    tester,
  ) async {
    final filters = <CachedTopicFeedFilter>[];
    await harness.pump(
      tester,
      Scaffold(
        body: CachedFeedFilterBar(
          snapshots: [
            _post(1, ['cat', 'blue']),
            _post(2, ['dog', 'green']),
            _post(3, ['cat', 'red'], host: 'b.example'),
            _post(4, ['dog', 'blue'], host: 'b.example'),
          ],
          onChanged: filters.add,
        ),
      ),
    );
    final field = find.byType(TextField);
    await tester.enterText(field, '-dog');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(_suggestion(tester, 'cat').tag.postCount, 2);
    expect(_suggestion(tester, 'blue').tag.postCount, 1);
    expect(
      find.byKey(const ValueKey('feed-filter-suggestion-green')),
      findsNothing,
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookmarkOptionSelector<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b.example').last);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(_suggestion(tester, 'cat').tag.postCount, 1);
    expect(_suggestion(tester, 'red').tag.postCount, 1);
    expect(
      find.byKey(const ValueKey('feed-filter-suggestion-blue')),
      findsNothing,
    );
    await tester.enterText(field, '-red');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feed-filter-suggestion-red')));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(
      filters.last,
      const CachedTopicFeedFilter(query: '-dog -red', sourceHost: 'b.example'),
    );
    expect(find.byType(TagSuggestionItem), findsNothing);
    expect(harness.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a tag offers replacements within the other selected tags',
    (tester) async {
      final filters = <CachedTopicFeedFilter>[];
      await harness.pump(
        tester,
        Scaffold(
          body: CachedFeedFilterBar(
            snapshots: [
              _post(1, ['cat', 'blue_hair', 'green_eyes']),
              _post(2, ['cat', 'red_hair', 'yellow_eyes']),
              _post(3, ['dog', 'red_hair', 'purple_eyes']),
            ],
            onChanged: filters.add,
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.enterText(field, 'cat blue_hair');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      final chip = find.byWidgetPredicate(
        (widget) =>
            widget is SelectedTagChip &&
            widget.tagSearchItem.rawTag == 'blue_hair',
      );
      await tester.tap(chip);
      await tester.enterText(field, 'red hair');
      await tester.pumpAndSettle();
      expect(filters.last.query, 'cat blue_hair');
      expect(_suggestion(tester, 'red_hair').tag.postCount, 1);
      await tester.tap(
        find.byKey(const ValueKey('feed-filter-suggestion-red_hair')),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(filters.last.query, 'cat red_hair');
      expect(_suggestion(tester, 'yellow_eyes').tag.postCount, 1);
      expect(
        find.byKey(const ValueKey('feed-filter-suggestion-purple_eyes')),
        findsNothing,
      );
      expect(harness.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open suggestions reflect refreshed snapshots under the active tags',
    (tester) async {
      final filters = <CachedTopicFeedFilter>[];
      var snapshots = [
        _post(1, ['cat', 'blue']),
        _post(2, ['dog', 'red']),
      ];
      late StateSetter rebuild;
      await harness.pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: CachedFeedFilterBar(
                snapshots: snapshots,
                onChanged: filters.add,
              ),
            );
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'cat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('feed-filter-suggestion-red')),
        findsNothing,
      );
      rebuild(
        () => snapshots = [
          ...snapshots,
          _post(3, ['cat', 'red']),
        ],
      );
      await tester.pumpAndSettle();
      expect(_suggestion(tester, 'red').tag.postCount, 1);
      expect(_suggestion(tester, 'blue').tag.postCount, 1);
      expect(filters.single.query, 'cat');
      expect(harness.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'scrolls all cached suggestions with keyboard at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final filters = <CachedTopicFeedFilter>[];
        final snapshot = StoredPostSnapshot(
          origin: _snapshot.origin,
          common: {
            'tags': [
              for (var i = 0; i < 20; i++)
                'tag_${i.toString().padLeft(2, '0')}',
            ],
          },
          custom: const {},
          codecVersion: 1,
        );
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
              viewInsets: const EdgeInsets.only(bottom: 260),
            ),
            child: Scaffold(
              body: CachedFeedFilterBar(
                snapshots: [snapshot],
                onChanged: filters.add,
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'tag');
        await settle(tester);
        final last = find.byKey(
          const ValueKey('feed-filter-suggestion-tag_19'),
        );
        final scrollable = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(last, 60, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.tap(last);
        await settle(tester);
        expect(filters.single.query, 'tag_19');
        expect(harness.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('source selection does not rewrite the committed tags', (
    tester,
  ) async {
    final filters = <CachedTopicFeedFilter>[];
    await harness.pump(
      tester,
      Scaffold(
        body: CachedFeedFilterBar(
          snapshots: const [_snapshot],
          onChanged: filters.add,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '-cat');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    await tester.tap(find.byType(BookmarkOptionSelector<String?>));
    await settle(tester);
    final optionLogo = tester.widget<ConfigAwareWebsiteLogo>(
      find.byType(ConfigAwareWebsiteLogo),
    );
    expect(optionLogo.url, 'https://a.example');
    expect(optionLogo.width, 20);
    await tester.tap(find.text('a.example').last);
    await settle(tester);
    expect(
      filters.last,
      const CachedTopicFeedFilter(query: '-cat', sourceHost: 'a.example'),
    );
    expect(harness.requests, isEmpty);
    final selectedLogo = find.descendant(
      of: find.byType(BookmarkOptionSelector<String?>),
      matching: find.byType(ConfigAwareWebsiteLogo),
    );
    expect(
      tester.widget<ConfigAwareWebsiteLogo>(selectedLogo).url,
      'https://a.example',
    );
  });

  testWidgets('fits narrow width with enlarged text and an open keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await harness.pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
          viewInsets: EdgeInsets.only(bottom: 240),
        ),
        child: Scaffold(
          body: CachedFeedFilterBar(
            snapshots: const [_snapshot],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'blue_hair');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}

const _snapshot = StoredPostSnapshot(
  origin: PostOriginSnapshot(
    booruTypeId: 0,
    booruId: 0,
    sourceHost: 'a.example',
    profileIdHint: null,
  ),
  common: {
    'id': 1,
    'tags': ['cat', 'blue_hair'],
  },
  custom: {},
  codecVersion: 1,
);

class _TagStore implements TagTypeStore {
  @override
  Future<String?> getTagCategory(String siteHost, String tagName) async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> saveTag(TagInfo tagInfo) async {}
  @override
  Future<void> saveOrUpdateTagsBatch(List<TagInfo> tagInfos) async {}
}

TagSuggestionItem _suggestion(WidgetTester tester, String tag) =>
    tester.widget<TagSuggestionItem>(
      find.byKey(ValueKey('feed-filter-suggestion-$tag')),
    );

StoredPostSnapshot _post(
  int id,
  List<String> tags, {
  String host = 'a.example',
}) => StoredPostSnapshot(
  origin: PostOriginSnapshot(
    booruTypeId: 0,
    booruId: 0,
    sourceHost: host,
    profileIdHint: null,
  ),
  common: {'id': id, 'tags': tags},
  custom: const {},
  codecVersion: 1,
);
