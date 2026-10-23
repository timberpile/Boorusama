import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/search/options/catalog/aliases.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_options_section.dart';
import 'package:boorusama/core/search/options/search_suggestion_panel.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/configs/providers.dart';
import 'package:boorusama/core/tags/configs/src/tag_info.dart';
import 'package:boorusama/core/tags/metatag/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../following_topics/following_topic_test_utils.dart';
import '../../../support/fakes/memory_repositories.dart';

void main() {
  for (final type in [BooruType.danbooru, BooruType.e621]) {
    test('$type offers one preferred field while retaining alias parsing', () {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      final config = _config(type);
      final grammar = harness.container.read(
        searchCapabilitiesProvider(config),
      );
      final catalog = harness.container.read(
        searchOptionCatalogProvider(config),
      );
      final keys = catalog.map((option) => option.key).toSet();
      for (final entry in searchOptionAliasesFor(type).entries) {
        expect(keys, isNot(contains(entry.key)), reason: entry.key);
        expect(keys, contains(entry.value), reason: entry.key);
        expect(grammar.byKey(entry.key), isNotNull);
        expect(grammar.contextFor('-${entry.key}:42')?.option.key, entry.key);
      }
      // Creating notes and editing notes, or naming an uploader and specifying
      // an uploader ID, are distinct operations despite overlapping labels.
      expect(keys, containsAll(['noter', 'noteupdater']));
      if (type == BooruType.e621) {
        expect(
          keys,
          containsAll(['user', 'user_id', 'voted', 'upvote', 'downvote']),
        );
      }
    });
  }

  test('FREE metadata transfers from an alias to its preferred field', () {
    final harness = FollowingTopicHarness(
      overrides: [
        tagInfoProvider.overrideWithValue(
          TagInfo(
            metatags: {const Metatag.simple(name: 'pixiv', isFree: true)},
            defaultBlacklistedTags: {},
            r18Tags: {},
          ),
        ),
      ],
    );
    addTearDown(harness.dispose);
    final options = harness.container.read(
      searchOptionCatalogProvider(_config(BooruType.danbooru)),
    );
    expect(
      options.singleWhere((option) => option.key == 'pixiv_id').isFree,
      isTrue,
    );
  });

  testWidgets('old alias pins display one preferred filter and catalog row', (
    tester,
  ) async {
    final harness = FollowingTopicHarness(
      overrides: [
        miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
        currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
          _config(BooruType.danbooru),
        ),
      ],
    );
    addTearDown(harness.dispose);
    final controller = _controller();
    final pins = ValueNotifier<List<String>>(['pixiv', 'pixiv_id']);
    addTearDown(pins.dispose);
    await harness.pump(
      tester,
      Scaffold(
        body: ValueListenableBuilder(
          valueListenable: pins,
          builder: (_, keys, _) => SearchOptionsSection(
            controller: controller,
            pinnedKeys: keys,
            onPin: (key) async => pins.value = [...pins.value, key],
            onUnpin: (key) async =>
                pins.value = pins.value.where((pin) => pin != key).toList(),
          ),
        ),
      ),
    );
    expect(find.text('Pixiv work ID'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-option.pixiv')), findsNothing);
    expect(
      find.byKey(const ValueKey('search-option.pixiv_id')),
      findsOneWidget,
    );
    final context = tester.element(find.byType(SearchOptionsSection));
    await tester.tap(find.byTooltip(context.t.search_options.all_options));
    await tester.pumpAndSettle();
    final catalogList = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListView),
    );
    await tester.scrollUntilVisible(
      find.text('pixiv_id'),
      400,
      scrollable: find.descendant(
        of: catalogList,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 100,
    );
    expect(find.text('pixiv'), findsNothing);
    expect(find.text('pixiv_id'), findsOneWidget);
    final row = find.ancestor(
      of: find.text('pixiv_id'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.byTooltip(context.t.search_options.unpin),
      ),
    );
    await tester.pumpAndSettle();
    expect(pins.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final (query, title, key) in [
    ('pixiv', 'Pixiv work ID', 'pixiv_id'),
    ('comments', 'Comment count', 'comment_count'),
    ('artcomm', 'Commentary edited by', 'commentaryupdater'),
  ]) {
    testWidgets('$query discovers and selects only the preferred field', (
      tester,
    ) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      final controller = _controller();
      controller.updateQuery(query);
      await harness.pump(
        tester,
        Scaffold(
          body: SearchSuggestionPanel(
            config: _config(BooruType.danbooru),
            controller: controller,
          ),
        ),
      );
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text(title));
      await tester.pump();
      expect(controller.textController.text, '$key:');
    });
  }

  testWidgets('applying a preferred field replaces ordinary aliases only', (
    tester,
  ) async {
    final controller = _controller();
    controller.tagsController.addTags([
      TagSearchItem.fromString('pixiv:42'),
      TagSearchItem.fromString('-pixiv_id:24'),
      const TagSearchItem.raw(tag: '(pixiv:99 rating:g)'),
      TagSearchItem.fromString('landscape'),
    ]);
    controller.applyOption('pixiv_id', 'pixiv_id:100');
    expect(controller.tagsController.rawTags, [
      'pixiv_id:100',
      '(pixiv:99 rating:g)',
      'landscape',
    ]);
    expect(controller.tagsController.tags[1].isRaw, isTrue);
  });
}

BooruConfigAuth _config(BooruType type) => BooruConfig.defaultConfig(
  booruType: type,
  url: 'https://example.test',
  customDownloadFileNameFormat: null,
).auth;

SearchPageController _controller() {
  final tags = SelectedTagController(metatagExtractor: null);
  final controller = SearchPageController(
    tagsController: tags,
    textMatchers: [],
    metatagExtractor: null,
    optionKeys: capabilitiesFor(
      BooruType.danbooru,
      'https://example.test',
    ).options.map((option) => option.key).toSet(),
    optionAliases: searchOptionAliasesFor(BooruType.danbooru),
  );
  addTearDown(() {
    controller.dispose();
    tags.dispose();
  });
  return controller;
}
