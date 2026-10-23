import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/search/suggestions/suggestions_notifier.dart';
import 'package:boorusama/core/tags/autocompletes/providers.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:boorusama/core/tags/configs/providers.dart';
import 'package:boorusama/core/tags/configs/src/tag_info.dart';
import 'package:boorusama/core/tags/local/providers.dart';
import 'package:boorusama/core/tags/local/src/data/repo_empty.dart';
import 'package:boorusama/core/tags/local/src/types/cached_tag.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'publishes API suggestions before cache and ignores late enrichment after clear',
    (tester) async {
      final source = _Source();
      final notifier = source.notifier;
      notifier.getSuggestions('one piece');
      await tester.pump(const Duration(milliseconds: 200));
      expect(source.requests.single.query.text, 'one_piece');
      source.requests.single.result.complete([
        const AutocompleteData(label: 'One Piece', value: 'one_piece'),
      ]);
      await tester.pump();
      expect(source.results('one piece').single.category, isNull);
      expect(source.cache.requests, hasLength(1));
      notifier.clear();
      source.cache.requests.single.complete(
        const TagResolutionResult(
          found: [
            CachedTag(
              siteHost: '',
              tagName: 'one_piece',
              category: 'copyright',
            ),
          ],
          missing: [],
        ),
      );
      await tester.pump();
      expect(source.results('one piece'), isEmpty);
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'an obsolete API response cannot replace another query or category',
    (tester) async {
      final source = _Source();
      source.notifier.getSuggestions('cat');
      await tester.pump(const Duration(milliseconds: 200));
      source.notifier.setCategory('artist');
      source.notifier.getSuggestions('cat');
      await tester.pump(const Duration(milliseconds: 200));
      expect(source.requests.last.query.category, 'artist');
      source.requests.last.result.complete([
        const AutocompleteData(label: 'Current', value: 'current'),
      ]);
      await tester.pump();
      source.requests.first.result.complete([
        const AutocompleteData(label: 'Stale', value: 'stale'),
      ]);
      await tester.pump();
      expect(source.results('cat').single.value, 'current');
      source.notifier.getSuggestions('dog');
      expect(source.results('dog'), isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      source.requests.last.result.complete([]);
      source.cache.requests.single.complete(
        const TagResolutionResult(found: [], missing: ['current']),
      );
      await tester.pump();
      expect(source.results('dog'), isEmpty);
      expect(source.results('cat').single.category, isNull);
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('failed requests retry and disposal cancels pending completion', (
    tester,
  ) async {
    final source = _Source();
    source.notifier.getSuggestions('cat');
    await tester.pump(const Duration(milliseconds: 200));
    source.requests.single.result.completeError(StateError('offline'));
    await tester.pump();
    source.notifier.getSuggestions('cat');
    await tester.pump(const Duration(milliseconds: 200));
    expect(source.requests, hasLength(2));
    source.container.invalidate(suggestionsNotifierProvider(source.config));
    source.requests.last.result.complete([
      const AutocompleteData(label: 'Late', value: 'late'),
    ]);
    await tester.pump();
    expect(source.results('cat'), isEmpty);
    expect(source.cache.requests, isEmpty);
    await tester.pump(Duration.zero);
  });
}

class _Source {
  _Source() {
    container = ProviderContainer(
      overrides: [
        booruLoginDetailsProvider.overrideWith(
          (_, config) => DefaultBooruLoginDetails(
            login: config.login,
            apiKey: config.apiKey,
            url: config.url,
          ),
        ),
        tagInfoProvider.overrideWithValue(
          const TagInfo(metatags: {}, defaultBlacklistedTags: {}, r18Tags: {}),
        ),
        autocompleteRepoProvider.overrideWith(
          (_, _) => AutocompleteRepositoryBuilder(
            autocomplete: (query) {
              final result = Completer<List<AutocompleteData>>();
              requests.add((query: query, result: result));
              return result.future;
            },
          ),
        ),
        tagCacheRepositoryProvider.overrideWith((_) => Future.value(cache)),
      ],
    );
    addTearDown(container.dispose);
  }

  final config = BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://example.test',
    customDownloadFileNameFormat: null,
  ).auth;
  final requests =
      <({AutocompleteQuery query, Completer<List<AutocompleteData>> result})>[];
  final cache = _Cache();
  late final ProviderContainer container;
  SuggestionsNotifier get notifier =>
      container.read(suggestionsNotifierProvider(config).notifier);
  Iterable<AutocompleteData> results(String query) =>
      container.read(suggestionProvider((config, query)));
}

class _Cache extends EmptyTagCacheRepository {
  final requests = <Completer<TagResolutionResult>>[];
  @override
  Future<TagResolutionResult> resolveTags(
    String siteHost,
    List<String> tagNames,
  ) {
    final result = Completer<TagResolutionResult>();
    requests.add(result);
    return result.future;
  }
}
