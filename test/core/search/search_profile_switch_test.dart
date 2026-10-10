import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/boorus/defaults/src/base_booru_builder.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/pages/search_page.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:boorusama/core/search/suggestions/providers.dart';
import 'package:boorusama/core/tags/metatag/providers.dart';
import 'package:boorusama/core/tags/metatag/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/kurumi.dart';
import 'package:boorusama/foundation/networking.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'subscriptions/pinned_search_test_utils.dart';

BooruConfig profile(String id, String name, BooruType type, String url) =>
    BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: type,
        url: url,
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': '00000000-0000-4000-8000-00000000000$id',
      'name': name,
    });

void main() {
  final first = profile('a', 'Shared', BooruType.danbooru, 'https://a.example');
  final sameEngine = profile(
    'b',
    'Shared',
    BooruType.danbooru,
    'https://b.example',
  );
  final otherEngine = profile('c', '', BooruType.gelbooru, 'https://c.example');

  for (final next in [sameEngine, otherEngine]) {
    testWidgets(
      'switching results to ${next.url} retains search intent globally',
      (tester) async {
        final observed = <SearchPageController>[];
        final fetches = <String>[];
        final suggestions = <String>[];
        final harness = PinnedSearchHarness(
          profiles: [first, next],
          booruBuilder: (_) => _SearchBuilder(observed, fetches),
        );
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          ProviderScope(
            overrides: [
              networkStateProvider.overrideWithValue(
                NetworkDisconnectedState(),
              ),
              metatagExtractorProvider.overrideWith(
                (ref, config) => _Extractor(config.url),
              ),
              suggestionsNotifierProvider.overrideWith(
                () => _Suggestions(suggestions),
              ),
            ],
            child: CurrentBooruConfigScope(
              config: first,
              child: const Scaffold(body: SearchPage()),
            ),
          ),
        );
        var controller = observed.last;
        controller.tagsController.addTags([
          TagSearchItem.fromString('-cat'),
          const TagSearchItem.raw(tag: '(dog ~ bird) rating:safe'),
        ]);
        controller.didSearchOnce.value = true;
        controller.tagString.value = controller.tagsController.rawTagsString;
        await _settle(tester);
        controller.textController.value = const TextEditingValue(
          text: '  pending:term ',
          selection: TextSelection.collapsed(offset: 7),
        );
        await _settle(tester);
        final previous = controller;
        final terms = controller.tagsController.rawTagsString;
        await tester.tap(find.byIcon(Icons.more_vert));
        await _settle(tester);
        await tester.tap(
          find
              .ancestor(
                of: find.text('Switch Profile'),
                matching: find.byType(KurumiPopupMenuButton),
              )
              .first,
        );
        await _settle(tester);
        expect(
          find.text('Shared (${first.url})'),
          next.name.isEmpty ? findsNothing : findsOneWidget,
        );
        await tester.tap(
          find.text(next.name.isEmpty ? next.url : 'Shared (${next.url})'),
        );
        await _settle(tester);
        controller = observed.last;
        expect(identical(previous, controller), isFalse);
        expect(harness.container.read(currentBooruConfigProvider).id, next.id);
        expect(controller.tagsController.rawTagsString, terms);
        expect(controller.textController.value.text, '  pending:term ');
        expect(controller.textController.selection.baseOffset, 7);
        expect(controller.didSearchOnce.value, isTrue);
        expect((controller.metatagExtractor! as _Extractor).url, next.url);
        expect(
          identical(controller.metatagExtractor, previous.metatagExtractor),
          isFalse,
        );
        expect(fetches.any((e) => e.startsWith('${next.url}|$terms')), isTrue);
        expect(suggestions.last, '${next.url}|  pending:term ');
        expect(find.text('Results ${first.url}'), findsNothing);
        expect(find.text('Results ${next.url}'), findsOneWidget);
        expect(find.byType(SearchPage), findsOneWidget);
        final requestCount = fetches.length;
        await tester.tap(find.byIcon(Icons.more_vert));
        await _settle(tester);
        await tester.tap(
          find
              .ancestor(
                of: find.text('Switch Profile'),
                matching: find.byType(KurumiPopupMenuButton),
              )
              .first,
        );
        await _settle(tester);
        expect(find.byIcon(Symbols.check), findsOneWidget);
        await tester.tap(
          find.text(next.name.isEmpty ? next.url : 'Shared (${next.url})'),
        );
        await _settle(tester);
        expect(identical(observed.last, controller), isTrue);
        expect(fetches.length, requestCount);
      },
    );
  }

  testWidgets(
    'single active profile is checked and choosing it keeps controllers and requests',
    (tester) async {
      final observed = <SearchPageController>[];
      final fetches = <String>[];
      final harness = PinnedSearchHarness(
        profiles: [testProfile],
        booruBuilder: (_) => _SearchBuilder(observed, fetches),
      );
      addTearDown(harness.dispose);
      await harness.pump(tester, const Scaffold(body: SearchPage()));
      final controller = observed.last;
      expect(find.byIcon(Icons.more_vert), findsNothing);
      controller.tagsController.addTag(TagSearchItem.fromString('cat'));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await _settle(tester);
      expect(find.text('Remove all selected tags'), findsOneWidget);
      expect(find.text('Bulk download'), findsOneWidget);
      await tester.tap(
        find
            .ancestor(
              of: find.text('Switch Profile'),
              matching: find.byType(KurumiPopupMenuButton),
            )
            .first,
      );
      await _settle(tester);
      expect(find.byIcon(Symbols.check), findsOneWidget);
      await tester.tap(find.text(testProfile.url));
      await _settle(tester);
      expect(identical(observed.last, controller), isTrue);
      expect(fetches, isEmpty);
      await tester.tap(find.byIcon(Icons.more_vert));
      await _settle(tester);
      await tester.tap(find.text('Remove all selected tags'));
      await _settle(tester);
      expect(controller.tagsController.tags, isEmpty);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    },
  );

  testWidgets(
    'nested profile menu fits narrow width with enlarged text and keyboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final harness = PinnedSearchHarness(
        profiles: [first, sameEngine, otherEngine],
        booruBuilder: (_) => _SearchBuilder([], []),
      );
      addTearDown(harness.dispose);
      // Use the real selected-tag overflow inside the search page.
      await harness.pump(
        tester,
        const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(body: SearchPage()),
        ),
      );
      final region = tester.widget<DefaultSearchRegion>(
        find.byType(DefaultSearchRegion),
      );
      region.controller.tagsController.addTag(TagSearchItem.fromString('cat'));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await _settle(tester);
      await tester.tap(
        find
            .ancestor(
              of: find.text('Switch Profile'),
              matching: find.byType(KurumiPopupMenuButton),
            )
            .first,
      );
      await _settle(tester);
      expect(find.text('Shared (${first.url})'), findsOneWidget);
      expect(find.text('Shared (${sameEngine.url})'), findsOneWidget);
      expect(find.text(otherEngine.url), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SearchBuilder extends BaseBooruBuilder {
  _SearchBuilder(this.observed, this.fetches);
  final List<SearchPageController> observed;
  final List<String> fetches;

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => Consumer(
        builder: (context, ref, _) {
          final config = ref.watchConfig;
          return SearchPageScaffold<Post>(
            params: params,
            fetcher: (page, tags) {
              fetches.add('${config.url}|${tags.rawTagsString}|$page');
              return TaskEither.of(const PostResult(posts: <Post>[], total: 0));
            },
            landingViewBuilder: (_) => const SizedBox.expand(),
            searchRegionBuilder: (posts, controller) {
              observed.add(controller);
              return DefaultSearchRegion(
                controller: controller,
                postController: posts,
              );
            },
            extraHeaders: (_, _) => [
              SliverToBoxAdapter(child: Text('Results ${config.url}')),
            ],
          );
        },
      );
}

class _Suggestions extends SuggestionsNotifier {
  _Suggestions(this.queries);
  final List<String> queries;
  @override
  void getSuggestions(String query) => queries.add('${arg.url}|$query');
}

class _Extractor implements MetatagExtractor {
  _Extractor(this.url);
  final String url;
  @override
  String? fromString(String value) =>
      value.startsWith('rating:') ? 'rating' : null;
  @override
  bool hasMetatag(String query) => fromString(query) != null;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}
