import 'dart:convert';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/availability.dart';
import 'package:boorusama/boorus/nhentai/client_provider.dart';
import 'package:boorusama/boorus/nhentai/nhentai_builder.dart';
import 'package:boorusama/boorus/nhentai/nhentai_repository.dart';
import 'package:boorusama/boorus/nhentai/search/query.dart';
import 'package:boorusama/boorus/nhentai/tags/providers.dart';
import 'package:boorusama/boorus/nhentai/tags/store.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_suggestion_panel.dart';
import 'package:boorusama/core/search/queries/tag_query_composer.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/selected_tag_chip.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/search/suggestions/providers.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/src/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';

import 'fixtures.dart';
import 'tag_store_test.dart' show Cache;

const _vanilla = [
  NhentaiTag(id: 11, type: 'artist', name: 'vanilla', count: 88),
  NhentaiTag(id: 12, type: 'character', name: 'vanilla', count: 4),
  NhentaiTag(id: 13, type: 'group', name: 'vanilla type', count: 36),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('completing a trailing term preserves the quoted and signed input', () {
    const before = 'pages:>30 -title:"two  words" ';
    final term = NhentaiSearchTerm.trailing('$before-artist:"vanilla c')!;
    expect(term.before, before);
    expect(term.type, 'artist');
    expect(term.operator, '-');
    expect(term.prefix, 'vanilla c');
    expect(NhentaiSearchTerm.trailing('vanilla '), isNull);
    expect(NhentaiSearchTerm.trailing('jtitle:"two words"'), isNull);
    expect(NhentaiSearchTerm.isSingle('title:"two words"'), isTrue);
    expect(NhentaiSearchTerm.isSingle('$before van'), isFalse);
  });

  test(
    'editor and composer preserve native queries sent to the Search API',
    () async {
      final config = galleryAccess().config!;
      final tags = SelectedTagController(
        metatagExtractor: null,
        preserveOriginalQuery: true,
      );
      final controller = SearchPageController(
        tagsController: tags,
        textMatchers: null,
        metatagExtractor: null,
      );
      addTearDown(controller.dispose);
      addTearDown(tags.dispose);
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'result': [], 'num_pages': 3, 'total': 60},
                ),
              );
            },
          ),
        );
      addTearDown(() => dio.close(force: true));
      final client = NhentaiClient(dio: dio);
      final composer = DefaultTagQueryComposer(config: config.search);
      for (final query in [
        'vanilla',
        'artist:"vanilla"',
        'tag:"vanilla"',
        'pages:>30 -title:"two  words" artist:"vanilla cream"',
      ]) {
        tags.clear();
        controller.submit(query);
        controller.search();
        final composed = composer
            .compose([controller.tagString.value])
            .join(' ');
        final result = await client.getGalleries(query: composed, page: 2);
        expect(requests.last.uri.queryParameters, {
          'query': query,
          'page': '2',
        });
        expect(result.hasMore, isTrue);
      }
    },
  );

  test(
    'suggestions keep source order and identity, with fallback only on failure',
    () async {
      final auth = galleryAccess().config!.auth;
      final store = NhentaiPersistentTagStore(Cache());
      final writes = <Future<void>>[];
      final requests = <Object?>[];
      var fail = false;
      var empty = false;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final body =
                  jsonDecode(options.data as String) as Map<String, dynamic>;
              requests.add(body);
              if (fail) {
                handler.reject(DioException(requestOptions: options));
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    if (!empty)
                      for (final tag in _vanilla)
                        if (body['type'] == null || body['type'] == tag.type)
                          {
                            'id': tag.id,
                            'type': tag.type,
                            'name': tag.name,
                            'count': tag.count,
                          },
                  ],
                ),
              );
            },
          ),
        );
      final cache = NhentaiTagCache(
        store: _ObservedStore(store, writes),
        lookup: (_, _) async => [],
        catalog: (_, _, _, _) async => throw StateError('unexpected catalog'),
      );
      final container = ProviderContainer(
        overrides: [
          nhentaiAvailableProvider.overrideWithValue(true),
          nhentaiClientProvider(auth)
              .overrideWithValue(NhentaiClient(dio: dio)),
          nhentaiTagCacheProvider(auth).overrideWithValue(cache),
          nhentaiTagStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(cache.dispose);
      addTearDown(() => dio.close(force: true));
      final repo = NhentaiRepository(ref: container.read(_ref))
          .autocomplete(auth);

      const plain = AutocompleteQuery.text('vanilla');
      final suggestions = await repo.getAutocomplete(plain);
      expect(suggestions.map((tag) => tag.value), [
        'artist:"vanilla"',
        'character:"vanilla"',
        'group:"vanilla type"',
      ]);
      final explicit = await repo.getAutocomplete(
        const AutocompleteQuery.text('pages:>10 -artist:"vanilla'),
      );
      expect(explicit.single.value, 'artist:"vanilla"');
      expect(requests.last, {
        'query': 'vanilla',
        'type': 'artist',
        'limit': 10,
      });
      await Future.wait(writes);
      empty = true;
      expect(await repo.getAutocomplete(plain), isEmpty);
      fail = true;
      expect(
        (await repo.getAutocomplete(plain)).map((tag) => tag.value),
        suggestions.map((tag) => tag.value),
      );
      final cancelled = CancelToken()..cancel();
      await expectLater(
        repo.getAutocomplete(
          AutocompleteQuery(
            text: 'vanilla',
            cancelToken: cancelled,
          ),
        ),
        throwsA(isA<DioException>()),
      );
    },
  );

  test(
    'catalog fetches one page per visit and rotates among categories',
    () async {
      final store = NhentaiPersistentTagStore(Cache());
      final events = <String>[];
      var tick = 0;
      final cache = NhentaiTagCache(
        store: store,
        lookup: (ids, _) async {
          events.add('lookup');
          return [const NhentaiTag(id: 100, name: 'visible', type: 'artist')];
        },
        now: () => DateTime.utc(2026).add(Duration(seconds: tick++)),
        catalog: (type, sort, page, token) async {
          events.add('$type:$page');
          return NhentaiResultPage(
            items: [
              NhentaiTag(id: tick + 1, type: type, name: 'fixture-$page'),
            ],
            page: page,
            pageCount: type == 'language' || type == 'category' ? 1 : 2,
          );
        },
      );
      addTearDown(cache.dispose);
      for (var i = 0; i < 9; i++) {
        await warmNhentaiTags(cache, {100}, CancelToken(), warmCatalog: true);
      }
      expect(events, [
        'lookup',
        'language:1',
        'category:1',
        'tag:1',
        'artist:1',
        'character:1',
        'parody:1',
        'group:1',
        'tag:2',
        'artist:2',
      ]);
    },
  );

  testWidgets(
    'nhentai chips display colored names and expose exact RAW input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = galleryAccess().config!.auth;
      final tags = SelectedTagController(
        metatagExtractor: null,
        preserveOriginalQuery: true,
      );
      final controller = SearchPageController(
        tagsController: tags,
        textMatchers: null,
        metatagExtractor: null,
      );
      addTearDown(controller.dispose);
      addTearDown(tags.dispose);
      const artist = 'artist:"yuzuha"';
      const general = 'tag:"vanilla cream"';
      controller.skipToResultWithTags(
        SearchTagSet.fromList(const [artist, general]),
        queryType: QueryType.list,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruBuilderProvider(auth).overrideWithValue(NhentaiBuilder()),
            booruChipColorsProvider.overrideWithValue(
              BooruChipColors.colorScheme(
                ColorScheme.fromSeed(seedColor: Colors.blue),
              ),
            ),
            tagColorProvider((auth, 'artist')).overrideWithValue(Colors.purple),
            tagColorProvider((auth, 'general')).overrideWithValue(Colors.green),
            suggestionProvider.overrideWith(
              (_, _) => <AutocompleteData>[].lock,
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  viewInsets: const EdgeInsets.only(bottom: 240),
                ),
                child: child!,
              ),
              home: InheritedSearchPageController(
                controller: controller,
                child: Scaffold(
                  body: Column(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: tags,
                        builder: (_, items, _) => Wrap(
                          children: [
                            for (final item in items)
                              CategoryAwareSelectedTagChip(
                                auth: auth,
                                tagSearchItem: item,
                                key: ValueKey(item.originalTag),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SearchSuggestionPanel(
                          config: auth,
                          controller: controller,
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
      final names = find.byType(SelectedTagChip);
      final chips = tester.widgetList<SelectedTagChip>(names).toList();
      expect(chips.map((chip) => chip.tagLabel), ['yuzuha', 'vanilla cream']);
      expect(chips.map((chip) => chip.tagColor), [Colors.purple, Colors.green]);
      expect(find.text('yuzuha ', findRichText: true), findsOneWidget);
      expect(find.text('vanilla cream ', findRichText: true), findsOneWidget);
      expect(tags.rawTagsString, '$artist $general');
      await tester.tap(find.byKey(const ValueKey(general)));
      await tester.pump();
      expect(controller.textController.text, general);
      await tester.tap(find.text('RAW'));
      await tester.pump();
      expect(tags.tags.last.isRaw, isTrue);
      expect(find.text('RAW   $general ', findRichText: true), findsOneWidget);
      expect(tags.rawTagsString, '$artist $general');
      await tester.tap(find.byKey(const ValueKey(general)));
      await tester.pump();
      expect(controller.inputIsRaw.value, isTrue);
      expect(controller.textController.text, general);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal suggestion rows show category and preserve compound input at narrow width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = galleryAccess().config!.auth;
      final tags = SelectedTagController(
        metatagExtractor: null,
        preserveOriginalQuery: true,
      );
      final controller = SearchPageController(
        tagsController: tags,
        textMatchers: null,
        metatagExtractor: null,
      );
      addTearDown(controller.dispose);
      addTearDown(tags.dispose);
      const query = 'pages:>30 -artist:"van';
      controller.updateQuery(query);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruBuilderProvider(auth).overrideWithValue(NhentaiBuilder()),
            tagColorProvider((auth, 'artist')).overrideWithValue(Colors.purple),
            tagColorProvider((auth, 'character'))
                .overrideWithValue(Colors.green),
            suggestionProvider((auth, query)).overrideWithValue(
              _vanilla.take(2).map(nhentaiSuggestion).toList().lock,
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.8),
                  viewInsets: EdgeInsets.only(bottom: 250),
                ),
                child: Scaffold(
                  body: SearchSuggestionPanel(
                    config: auth,
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Character'), findsOneWidget);
      expect(find.text('vanilla'), findsNWidgets(2));
      expect(
        capabilitiesFor(auth.booruType, auth.url).options.map((x) => x.key),
        ['pages', 'favorites', 'uploaded', 'title', 'jtitle'],
      );
      await tester.tap(find.text('Artist'));
      controller.search();
      await tester.pump();
      expect(controller.tagString.value, 'pages:>30 -artist:"vanilla"');
      expect(tester.takeException(), isNull);
    },
  );
}

final _ref = Provider<Ref>((ref) => ref);

// A completion signal for the repository's optional write.
class _ObservedStore implements NhentaiTagStore {
  _ObservedStore(this.store, this.writes);
  final NhentaiPersistentTagStore store;
  final List<Future<void>> writes;

  @override
  Future<Map<int, NhentaiTag>> readTags(Uri source, Set<int> ids) =>
      store.readTags(source, ids);
  @override
  Future<void> upsertTags(Uri source, List<NhentaiTag> tags) {
    final write = store.upsertTags(source, tags);
    writes.add(write);
    return write;
  }

  @override
  Future<NhentaiTagCheckpoint?> readCheckpoint(
    Uri source,
    String category,
    String sort,
  ) => store.readCheckpoint(source, category, sort);
  @override
  Future<void> writeCheckpoint(Uri source, NhentaiTagCheckpoint checkpoint) =>
      store.writeCheckpoint(source, checkpoint);
}
