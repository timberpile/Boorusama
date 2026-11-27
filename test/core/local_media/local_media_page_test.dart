import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/boorus/danbooru/tags/edit/src/tag_edit_page.dart';
import 'package:boorusama/boorus/danbooru/tags/edit/src/widgets/tag_edit_rating_selector_section.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/lookup_preferences.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/iqdb_lookup.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/local_media/local_media_enrichment.dart';
import 'package:boorusama/core/local_media/local_media_enrichment_review.dart';
import 'package:boorusama/core/local_media/local_media_library.dart';
import 'package:boorusama/core/local_media/local_media_page.dart';
import 'package:boorusama/core/local_media/local_media_models.dart';
import 'package:boorusama/core/local_media/local_media_providers.dart';
import 'package:boorusama/core/local_media/local_media_reference.dart';
import 'package:boorusama/core/local_media/local_media_tags.dart';
import 'package:boorusama/core/tags/autocompletes/providers.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:boorusama/core/navigation/profile_context_menu.dart';
import 'package:boorusama/core/navigation/search_destination_handoff.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/options/search_options_section.dart';
import 'package:boorusama/core/search/search/src/views/simple_tag_search_view.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_context_profile_picker.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/search/suggestions/widgets.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/tags/tag/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/default_image_grid_item.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_config_icon_button.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../posts/details/progressive_image_test_utils.dart'
    show lowerPng, pumpUntil, targetPng, TestImageCache, waitForPixel;
import '../../support/fakes/memory_repositories.dart' show MemoryMiscDataStore;

import '../../application/support/fake_booru_backend.dart';
import '../../application/support/headless_app_harness.dart';

void main() {
  test('search handoff omits grouped, quoted and profile-specific terms', () {
    final (terms, omitted) = portableSearchTerms(
      'cat -dog character_(series) rating:g source:"some website here" '
      'fur* ~horse (fox (bunny rat) bird) blue_hair',
    );
    expect(terms, ['cat', '-dog', 'character_(series)', 'blue_hair']);
    expect(omitted, isTrue);
    final (portable, dropped) = portableSearchTerms('cat -dog');
    expect(portable, ['cat', '-dog']);
    expect(dropped, isFalse);
    final (empty, hasFilter) = portableSearchTerms('tagcount:0');
    expect(empty, isEmpty);
    expect(hasFilter, isTrue);
  });

  testWidgets(
    'Local Media remembers Browse and shows temporary progress beneath the shared search bar',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final directory = Directory.systemTemp.createTempSync('local-media-ui');
      addTearDown(() => directory.deleteSync(recursive: true));
      final library = (await tester.runAsync(
        () => LocalMediaLibrary.open(directory),
      ))!;
      addTearDown(library.close);
      await tester.runAsync(
        () => library.import(
          Stream.value(lowerPng),
          inspect: (_, _) async => (width: 1, height: 1, durationMs: null),
          cancellation: LocalMediaCancellation(),
          budget: LocalMediaImportBudget(),
          tags: [(name: 'example_tag', category: 'character')],
        ),
      );
      final android = _ImportAndroid();
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        phone: TestPhone.smallPortrait,
        additionalOverrides: [
          autocompleteRepoProvider(localMediaTagAuth).overrideWithValue(
            AutocompleteRepositoryBuilder(
              autocomplete: (query) async => query.text == 'miku'
                  ? const [
                      AutocompleteData(
                        label: 'hatsune_miku',
                        value: 'hatsune_miku',
                        type: AutocompleteData.tag,
                        category: '4',
                      ),
                    ]
                  : [],
            ),
          ),
          localMediaTagLookupProvider.overrideWithValue(
            (_) => Future.value([
              Tag.noCount(
                name: 'hatsune_miku',
                category: TagCategory.character(),
              ),
            ]),
          ),
          localMediaAvailableProvider.overrideWithValue(true),
          localMediaAndroidProvider.overrideWithValue(android),
          localMediaLibraryProvider.overrideWith((_) => library),
        ],
      );

      final localPage = find.byType(LocalMediaPage);
      final selectSource = find.byTooltip('Choose a Profile');
      final browse = find.text('Browse');
      await harness.pumpUntilFound(tester, selectSource);
      await tester.tap(selectSource);
      await harness.settle(tester);
      await tester.tap(find.text('Local Media').hitTestable());
      await harness.pumpUntilFound(tester, localPage);
      await harness.settle(tester);

      final bar = find.descendant(
        of: localPage,
        matching: find.byType(BooruSearchBar),
      );
      final picker = find.descendant(
        of: localPage,
        matching: find.byType(ProfileContextMenuButton),
      );
      final search = find.descendant(
        of: bar,
        matching: find.byType(EditableText),
      );
      final upload = find.byTooltip('Import');
      final searchOptions = find.byTooltip('Search Options');
      final back = find.byType(SearchAppBarBackButton).hitTestable();
      expect(find.text('Search...'), findsOneWidget);
      expect(upload, findsOneWidget);
      expect(searchOptions, findsNothing);
      expect(back, findsNothing);
      expect(find.descendant(of: bar, matching: picker), findsOneWidget);
      expect(
        tester.getCenter(picker).dx,
        greaterThan(tester.getCenter(search).dx),
      );

      await tester.tap(browse);
      await harness.settle(tester);
      expect(localPage, findsOneWidget);
      await tester.tap(find.text('Bookmarks'));
      await harness.settle(tester);
      expect(localPage, findsNothing);
      await tester.tap(browse);
      await harness.settle(tester);
      expect(localPage, findsOneWidget);

      await tester.showKeyboard(search);
      await harness.settle(tester);
      expect(upload, findsNothing);
      expect(searchOptions, findsOneWidget);
      expect(find.descendant(of: bar, matching: picker), findsNothing);
      final suggestion = find.byKey(const ValueKey('hatsune_miku'));
      await tester.enterText(search, 'miku');
      await tester.pump(const Duration(milliseconds: 200));
      expect(suggestion, findsNothing);
      await tester.enterText(search, 'exa');
      final localSuggestion = find.byKey(const ValueKey('example_tag'));
      await harness.pumpUntilFound(tester, localSuggestion);
      expect(
        tester.widget<TagSuggestionItem>(localSuggestion).tag.postCount,
        1,
      );
      await tester.tap(localSuggestion);
      await harness.settle(tester);
      final filterChip = find.byType(SelectedTagChip).hitTestable();
      final tapped = tester.widget<SelectedTagChip>(filterChip);
      expect(tapped.tagSearchItem.category, 'character');
      expect(tapped.tagColor, isNotNull);
      await tester.tap(back);
      await harness.settle(tester);
      expect(filterChip, findsNothing);

      await tester.enterText(search, 'Example Tag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await harness.settle(tester);
      final entered = tester.widget<SelectedTagChip>(filterChip);
      expect(entered.tagSearchItem.rawTag, 'example_tag');
      expect(entered.tagSearchItem.category, tapped.tagSearchItem.category);
      expect(entered.tagColor, tapped.tagColor);
      expect(back, findsOneWidget);

      await tester.enterText(search, 'unfinished draft');
      await harness.settle(tester);
      await tester.tap(back);
      await harness.settle(tester);
      expect(localPage, findsOneWidget);
      expect(filterChip, findsNothing);
      expect(back, findsNothing);
      expect(tester.widget<EditableText>(search).controller.text, isEmpty);
      expect(tester.widget<EditableText>(search).focusNode.hasFocus, isFalse);
      expect(upload, findsOneWidget);

      await tester.enterText(search, 'exa');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await harness.settle(tester);
      expect(find.text('No Matching Media'), findsOneWidget);
      expect(upload, findsNothing);
      expect(searchOptions, findsOneWidget);
      await tester.tap(
        find.descendant(of: filterChip, matching: find.byIcon(Symbols.close)),
      );
      await harness.settle(tester);
      expect(upload, findsOneWidget);
      expect(searchOptions, findsNothing);

      await tester.tap(upload);
      await harness.settle(tester);
      expect(find.text('Upload Folder').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Upload Files').hitTestable());
      await tester.pump();
      await harness.pumpUntilFound(
        tester,
        find.text('Importing · 0 of 2 Processed'),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
      await harness.pumpUntilFound(tester, find.text('Cancel').hitTestable());
      android.remaining.complete(false);
      final result = find.text(
        '0 Imported · 0 Duplicates · 0 Skipped · 1 Failed',
      );
      await harness.pumpUntilFound(tester, result);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(result, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(result, findsNothing);

      await tester.tap(search);
      await harness.settle(tester);
      await tester.tap(searchOptions);
      await harness.settle(tester);
      expect(tester.widget<EditableText>(search).focusNode.hasFocus, isFalse);
      expect(upload, findsNothing);
      expect(searchOptions, findsOneWidget);
      expect(
        find.byKey(const ValueKey('search-option.rating')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('search-option.filetype')),
        findsOneWidget,
      );
      final optionList = find
          .descendant(
            of: find.byType(SearchOptionsSection),
            matching: find.byType(Scrollable),
          )
          .first;
      final optionPosition = tester.state<ScrollableState>(optionList).position;
      final initialOptionOffset = optionPosition.pixels;
      final tagCount = find.byKey(const ValueKey('search-option.tagcount'));
      final nonzero = find.descendant(of: tagCount, matching: find.text('>0'));
      await tester.scrollUntilVisible(nonzero, 80, scrollable: optionList);
      expect(
        find.descendant(of: tagCount, matching: find.text('0')),
        findsOneWidget,
      );
      expect(nonzero, findsOneWidget);
      final sorting = find.byKey(const ValueKey('search-option.order'));
      await tester.scrollUntilVisible(sorting, 80, scrollable: optionList);
      expect(sorting, findsOneWidget);
      optionPosition.jumpTo(initialOptionOffset);
      await tester.pump();
      await tester.tap(find.text('PNG').hitTestable());
      await harness.settle(tester);
      expect(back, findsOneWidget);
      final item = find.bySubtype<DefaultImageGridItem>();
      await harness.pumpUntilFound(tester, item);
      expect(find.bySubtype<PostGridConfigIconButton>(), findsOneWidget);
      expect(upload, findsNothing);
      expect(searchOptions, findsOneWidget);
      final selection = SelectionMode.of(tester.element(item.hitTestable()));
      await tester.longPress(item.hitTestable());
      await harness.settle(tester);
      expect(selection.selection, hasLength(1));
      await tester.tap(item.hitTestable());
      await harness.settle(tester);
      expect(selection.isActive, isFalse);

      await tester.longPress(item.hitTestable());
      await harness.settle(tester);
      await tester.tap(find.byTooltip('Deselect All'));
      await harness.settle(tester);
      expect(selection.isActive, isFalse);

      await tester.longPress(item.hitTestable());
      await harness.settle(tester);
      final actions = tester
          .widgetList<MultiSelectButton>(
            find.byType(MultiSelectButton),
          )
          .map((button) => button.name);
      expect(
        actions,
        containsAll([
          'Bookmark',
          'Share',
          'Edit Metadata',
          'Delete',
        ]),
      );
      await tester.tap(find.text('Edit Metadata').hitTestable());
      final editor = find.byType(PostTagEditEditor);
      await harness.pumpUntilFound(tester, editor);
      await harness.settle(tester);
      final rating = find.descendant(
        of: find.byType(TagEditRatingSelectorSection),
        matching: find.textContaining(RegExp(r'^(G|General)$')),
      );
      await tester.tap(rating.hitTestable());
      await tester.tap(find.text('Search').hitTestable());
      final quickSearch = find.byType(SimpleTagSearchView);
      await harness.pumpUntilFound(tester, quickSearch);
      final editorField = find.descendant(
        of: quickSearch,
        matching: find.byType(EditableText),
      );
      await tester.enterText(editorField, 'miku');
      await harness.pumpUntilFound(tester, suggestion.hitTestable());
      await tester.tap(suggestion.hitTestable());
      await harness.settle(tester);
      expect(quickSearch, findsNothing);
      expect(find.text('2 tags'), findsOneWidget);
      final save = find
          .widgetWithIcon(IconButton, Icons.save_outlined)
          .hitTestable();
      Future<void> saveMetadata() async {
        await tester.pump();
        expect(tester.widget<IconButton>(save).onPressed, isNotNull);
        expect(tester.widget<IconButton>(save).tooltip, 'Save');
        await tester.runAsync(() async {
          final saved = library.changes.first;
          await tester.tap(save);
          await saved.timeout(const Duration(seconds: 10));
        });
        await harness.pumpUntil(tester, () => editor.evaluate().isEmpty);
        await harness.settle(tester);
      }

      await saveMetadata();
      final updated = library.list().single;
      expect(updated.rating, Rating.general);
      expect(updated.tags, [
        (name: 'example_tag', category: 'character'),
        (name: 'hatsune_miku', category: 'character'),
      ]);

      await harness.pumpUntilFound(tester, item.hitTestable());
      expect(selection.selection, hasLength(1));
      await tester.tap(find.text('Edit Metadata').hitTestable());
      await harness.pumpUntilFound(tester, editor);
      await harness.settle(tester);
      await tester.tap(find.text('Unrated').hitTestable());
      await saveMetadata();
      expect(library.list().single.rating, Rating.unknown);

      await tester.tap(item.hitTestable());
      await harness.settle(tester);
      expect(selection.isActive, isFalse);

      final localRef = tester.element(localPage) as WidgetRef;
      final openedTag = localRef.pushRoute<void>(
        '/local-media-search',
        extra: 'hatsune_miku',
      );
      final taggedPage = find.byWidgetPredicate(
        (widget) =>
            widget is LocalMediaPage && widget.initialTag == 'hatsune_miku',
      );
      await harness.pumpUntilFound(tester, taggedPage);
      final taggedChip = find.descendant(
        of: taggedPage,
        matching: find.byType(SelectedTagChip),
      );
      await harness.pumpUntilFound(tester, taggedChip);
      expect(
        tester.widget<SelectedTagChip>(taggedChip).tagSearchItem.rawTag,
        'hatsune_miku',
      );
      await harness.pumpUntilFound(
        tester,
        find.descendant(
          of: taggedPage,
          matching: find.bySubtype<DefaultImageGridItem>(),
        ),
      );
      await tester.tap(
        find
            .descendant(
              of: taggedPage,
              matching: find.byType(SearchAppBarBackButton),
            )
            .hitTestable(),
      );
      await harness.pumpUntil(tester, () => taggedPage.evaluate().isEmpty);
      await openedTag;
      await harness.settle(tester);

      await tester.tap(selectSource);
      await harness.settle(tester);
      await tester.tap(find.text(backend.config.name).hitTestable());
      await harness.settle(tester);
      expect(localPage, findsNothing);
      await tester.tap(browse);
      await harness.settle(tester);
      expect(localPage, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'selection manager shows success and explains a batch without matches',
    (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync(
        'local-enrichment-ui',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final library = (await tester.runAsync(
        () => LocalMediaLibrary.open(directory),
      ))!;
      addTearDown(library.close);
      await tester.runAsync(() async {
        for (final bytes in [
          lowerPng,
          Uint8List.fromList([0, 0, 0, 20, ...'ftyp'.codeUnits, 0]),
        ]) {
          await library.import(
            Stream.value(bytes),
            inspect: (_, format) async => (
              width: 1,
              height: 1,
              durationMs: format.isVideo ? 100 : null,
            ),
            cancellation: LocalMediaCancellation(),
            budget: LocalMediaImportBudget(),
          );
        }
      });
      final hashes = <String>[];
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        phone: TestPhone.portrait,
        additionalOverrides: [
          localMediaAvailableProvider.overrideWithValue(true),
          localMediaLibraryProvider.overrideWith((_) => library),
          localMediaPosterProvider.overrideWith((_, _) => null),
          localMediaEnrichmentServiceProvider.overrideWith(
            (ref) => _RecordingEnrichment(ref, hashes),
          ),
        ],
      );
      final chooser = find.byTooltip('Choose a Profile');
      await harness.pumpUntilFound(tester, chooser);
      await tester.tap(chooser);
      await harness.settle(tester);
      await tester.tap(find.text('Local Media').hitTestable());
      final tiles = find.byType(DefaultImageGridItem<Post>).hitTestable();
      await harness.pumpUntil(tester, () => tiles.evaluate().length == 2);
      final videoTile = find
          .byWidgetPredicate(
            (widget) =>
                widget is DefaultImageGridItem<Post> &&
                widget.controller.itemsNotifier.value[widget.index].isVideo,
          )
          .hitTestable();
      await tester.longPress(videoTile);
      await harness.pumpUntilFound(
        tester,
        find.byType(MultiSelectionActionBar),
      );
      final videoActions = tester
          .widget<MultiSelectionActionBar>(
            find.byType(MultiSelectionActionBar),
          )
          .children
          .whereType<MultiSelectButton>()
          .map((button) => button.name);
      expect(videoActions, containsAll(['Find on Other Profiles', 'Enrich']));
      final imageTile = find
          .byWidgetPredicate(
            (widget) =>
                widget is DefaultImageGridItem<Post> &&
                !widget.controller.itemsNotifier.value[widget.index].isVideo,
          )
          .hitTestable();
      await tester.tap(imageTile);
      await harness.settle(tester);
      final more = find.descendant(
        of: find.byType(MultiSelectionActionBar),
        matching: find.byIcon(Icons.more_horiz),
      );
      await tester.tap(more);
      Finder enrich() => find.text('Enrich').hitTestable();
      Future<void> selectEnrichment() async {
        await tester.tap(enrich());
        final confirm = find
            .widgetWithText(FilledButton, 'Enrich')
            .hitTestable();
        await harness.pumpUntilFound(tester, confirm);
        await tester.tap(confirm);
      }

      await harness.pumpUntilFound(tester, enrich());
      await selectEnrichment();
      Finder consent() => find.text('Allow Once').hitTestable();
      await harness.pumpUntilFound(tester, consent());
      expect(hashes, isEmpty);
      await tester.tap(find.text('Cancel').hitTestable());
      await harness.settle(tester);
      expect(hashes, isEmpty);
      await tester.tap(more);
      await harness.pumpUntilFound(tester, enrich());
      await selectEnrichment();
      await harness.pumpUntilFound(tester, consent());
      await tester.tap(consent());
      await harness.pumpUntil(
        tester,
        () =>
            hashes.length == 2 &&
            find.byType(LocalMediaEnrichmentReviewPage).evaluate().isEmpty,
      );
      expect(hashes, unorderedEquals(library.list().map((item) => item.md5)));
      await harness.pumpUntilFound(tester, find.text('Enriched 2 files.'));
      expect(find.text('Enrichment Results'), findsNothing);
      await harness.settle(tester);
      final localRef = tester.element(find.byType(LocalMediaPage)) as WidgetRef;
      expect(localRef.read(localMediaOnlineConsentProvider), isFalse);
      await tester.tap(more);
      await harness.pumpUntilFound(tester, enrich());
      await selectEnrichment();
      final always = find.widgetWithText(CheckboxListTile, 'Allow always');
      await harness.pumpUntilFound(tester, always);
      expect(tester.widget<CheckboxListTile>(always).value, isFalse);
      await tester.tap(always);
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Allow').hitTestable(),
      );
      await harness.pumpUntil(
        tester,
        () =>
            hashes.length == 4 &&
            find.byType(LocalMediaEnrichmentReviewPage).evaluate().isEmpty,
      );
      expect(localRef.read(localMediaOnlineConsentProvider), isTrue);
      await harness.pumpUntilFound(
        tester,
        find.text('2 files are already up to date.'),
      );
      await harness.settle(tester);
      await tester.tap(more);
      await harness.pumpUntilFound(tester, enrich());
      await selectEnrichment();
      await harness.pumpUntilFound(
        tester,
        find.text('Enrichment Results').hitTestable(),
      );
      expect(hashes, hasLength(6));
      expect(find.text('Allow Online Lookup?'), findsNothing);
      expect(find.byType(KurumiDialog), findsOneWidget);
      expect(
        find.text('No match found using the selected methods.'),
        findsNWidgets(2),
      );
      expect(find.text('Skipped (2)'), findsOneWidget);
      expect(find.text('Failed (0)'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await harness.pumpUntil(
        tester,
        () => find.byType(LocalMediaEnrichmentReviewPage).evaluate().isEmpty,
      );
      expect(find.text('Enriched 2 files.'), findsNothing);
      expect(find.text('2 files are already up to date.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grouped results and in-place comparison', (tester) async {
    final directory = Directory.systemTemp.createTempSync(
      'local-review-queue',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final library = (await tester.runAsync(() async {
      final library = await LocalMediaLibrary.open(directory);
      for (var index = 0; index < 4; index++) {
        await library.import(
          Stream.value(Uint8List.fromList([...lowerPng, index])),
          inspect: (_, _) async => (width: 2, height: 2, durationMs: null),
          cancellation: LocalMediaCancellation(),
          budget: LocalMediaImportBudget(),
        );
      }
      return library;
    }))!;
    addTearDown(library.close);

    final backend = FakeBooruBackend();
    final items = library.list();
    final media = (await tester.runAsync(
      () async => {
        for (final item in items)
          item.reference: (
            item: item,
            file: await library.resolve(item.reference),
          ),
      },
    ))!;
    final applied = <String>[];
    late WidgetRef ref;
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      runtime: backend.createRuntime(
        configs: [backend.config, backend.configB],
      ),
      phone: TestPhone.portrait,
      additionalOverrides: [
        defaultImageCacheManagerProvider.overrideWithValue(
          TestImageCache({
            _PreparedEnrichment.matchUrl(backend.config, 201): targetPng,
            _PreparedEnrichment.matchUrl(backend.configB, 202): targetPng,
            _PreparedEnrichment.matchUrl(backend.config, 203): targetPng,
          }),
        ),
        localMediaAvailableProvider.overrideWithValue(true),
        localMediaLibraryProvider.overrideWith((_) => library),
        localMediaPresentationProvider.overrideWith(
          (_, reference) => Stream.value(media[reference]),
        ),
        localMediaEnrichmentServiceProvider.overrideWith(
          (ref) => _PreparedEnrichment(
            ref,
            items,
            backend.config,
            backend.configB,
            applied,
          ),
        ),
      ],
      appWrapper: (child) => Consumer(
        builder: (context, scopedRef, _) {
          ref = scopedRef;
          return child;
        },
      ),
    );
    await harness.pumpUntilFound(tester, find.byTooltip('Choose a Profile'));
    await harness.pumpUntilComplete(
      tester,
      ref.read(lookupPreferencesProvider.notifier).setIqdb(true),
    );
    await tester.tap(find.byTooltip('Choose a Profile'));
    await harness.settle(tester);
    await tester.tap(find.text('Local Media').hitTestable());
    final tiles = find.byType(DefaultImageGridItem<Post>).hitTestable();
    await harness.pumpUntil(tester, () => tiles.evaluate().length == 4);
    final more = find.descendant(
      of: find.byType(MultiSelectionActionBar),
      matching: find.byIcon(Icons.more_horiz),
    );
    await tester.longPress(tiles.first);
    await harness.pumpUntilFound(tester, more);
    Iterable<String> actionLabels() => tester
        .widget<MultiSelectionActionBar>(find.byType(MultiSelectionActionBar))
        .children
        .whereType<MultiSelectButton>()
        .map((button) => button.name);
    expect(actionLabels(), contains('Find on Other Profiles'));
    for (var index = 1; index < 4; index++) {
      await tester.tap(tiles.at(index));
      await tester.pump();
    }
    expect(actionLabels(), isNot(contains('Find on Other Profiles')));
    await tester.tap(more);
    Finder enrich() => find.text('Enrich').hitTestable();
    await harness.pumpUntilFound(tester, enrich());
    await tester.tap(enrich());
    final start = find.widgetWithText(FilledButton, 'Enrich').hitTestable();
    await harness.pumpUntilFound(tester, start);
    await tester.tap(start);
    final allow = find.text('Allow Once').hitTestable();
    await harness.pumpUntilFound(tester, allow);
    await tester.tap(allow);
    final review = find.byType(LocalMediaEnrichmentReviewPage);
    final results = find.text('Enrichment Results').hitTestable();
    await harness.pumpUntilFound(tester, results);
    for (final title in [
      'Enriched (0)',
      'Need Review (2)',
      'Skipped (1)',
      'Failed (1)',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(
      find.text('No match found using the selected methods.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rate limited'),
      findsOneWidget,
    );
    expect(
      find.textContaining('${backend.config.name} · Exact MD5'),
      findsOneWidget,
    );
    expect(find.byType(KurumiDialog), findsOneWidget);
    Finder row(int index) =>
        find.byKey(ValueKey(('enrichment-result', items[index].reference)));
    await tester.tap(find.text('Need Review (2)').hitTestable());
    await harness.settle(tester);
    expect(row(0), findsNothing);
    await tester.tap(find.text('Need Review (2)').hitTestable());
    await harness.pumpUntilFound(tester, row(0).hitTestable());
    expect(row(0), findsOneWidget);
    expect(row(1), findsOneWidget);

    // Resolve real file I/O outside the widget test's fake clock, then open
    // the route in the test zone so its result is returned by regular pumps.
    final comparisonContext = tester.element(row(0));
    final originalFile = media[items[0].reference]!.file!;
    await tester.runAsync(
      () => precacheImage(FileImage(originalFile), comparisonContext),
    );
    await tester.tap(row(0));
    final viewer = find.byType(MixedPostDetailsPage).hitTestable();
    final comparison = find.byType(SegmentedButton<bool>);
    await tester.runAsync(() async {
      await pumpUntil(
        tester,
        () =>
            comparison.evaluate().isNotEmpty &&
            tester
                .widget<SegmentedButton<bool>>(comparison)
                .segments
                .last
                .enabled,
        reason: 'the original and matched image are decoded',
      );
      await waitForPixel(tester, [0, 0, 255, 255], within: viewer);
    });
    expect(find.text('88.2% Match'), findsOneWidget);
    expect(find.text('${backend.config.name} · Danbooru IQDB'), findsOneWidget);
    final footer = find
        .ancestor(
          of: find.text('88.2% Match'),
          matching: find.byType(Scaffold),
        )
        .first;
    expect(
      find.descendant(
        of: footer,
        matching: find.byTooltip('${items[0].reference.sha256}.png'),
      ),
      findsNothing,
    );
    final matchedImage = find
        .descendant(
          of: viewer,
          matching: find.byType(ExtendedRawImage),
        )
        .first;
    final matchElement = tester.element(matchedImage);
    Finder original() => find.text('Original').hitTestable();
    await tester.tap(original());
    await tester.pump();
    final originalImage = find.byKey(const ValueKey('review-original-media'));
    expect(tester.widget<RawImage>(originalImage).image, isNotNull);
    expect(tester.element(matchedImage), same(matchElement));
    expect(find.text('88.2% Match').hitTestable(), findsOneWidget);
    expect(viewer, findsOneWidget);
    final renderedOriginal = tester.widget<RawImage>(originalImage).image!;
    final originalPixels = await tester.runAsync(renderedOriginal.toByteData);
    expect(originalPixels!.buffer.asUint8List().take(4), [255, 0, 0, 255]);
    await tester.tap(find.text('Match').hitTestable());
    await tester.pump();
    expect(originalImage, findsNothing);
    expect(tester.element(matchedImage), same(matchElement));
    await tester.tap(original());
    await tester.pump();
    await tester.fling(viewer, const Offset(-550, 0), 1000);
    await harness.pumpUntilFound(tester, find.text('81.0% Match'));
    expect(originalImage, findsNothing);
    expect(
      find.text('${backend.configB.name} · Danbooru IQDB'),
      findsOneWidget,
    );
    expect(find.text('${backend.config.name} · Danbooru IQDB'), findsNothing);
    final apply = find
        .widgetWithText(FilledButton, 'Apply Match')
        .hitTestable();
    await harness.pumpUntil(
      tester,
      () =>
          apply.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(apply).onPressed != null,
    );
    await tester.tap(apply);
    await harness.pumpUntilFound(tester, find.text('Could Not Apply Match'));
    expect(
      find.textContaining('The match could not be saved.'),
      findsWidgets,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await harness.pumpUntilFound(tester, apply.hitTestable());
    await tester.tap(apply);
    await harness.settle(tester);
    await harness.pumpUntilFound(
      tester,
      find.text('Need Review (1)').hitTestable(),
    );
    await harness.pumpUntilFound(tester, row(1).hitTestable());
    expect(applied, ['202']);
    expect(row(0), findsNothing);
    expect(find.text('Enriched (1)'), findsOneWidget);
    expect(find.text('Need Review (1)'), findsOneWidget);

    await tester.tap(row(1));
    Finder skip() =>
        find.widgetWithText(TextButton, 'Skip Image').hitTestable();
    await harness.pumpUntilFound(tester, skip());
    await tester.binding.handlePopRoute();
    await harness.pumpUntilFound(tester, row(1).hitTestable());
    await tester.binding.handlePopRoute();
    final keep = find.text('Keep Reviewing').hitTestable();
    await harness.pumpUntilFound(tester, keep);
    await tester.tap(keep);
    await harness.pumpUntilFound(tester, row(1).hitTestable());

    await tester.tap(row(1));
    await harness.pumpUntilFound(tester, skip());
    await tester.tap(skip());
    await harness.pumpUntilFound(
      tester,
      find.text('Skipped (2)').hitTestable(),
    );
    expect(find.text('Skipped during review.'), findsOneWidget);
    expect(find.text('Need Review (0)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done').hitTestable());
    await harness.pumpUntil(tester, () => review.evaluate().isEmpty);
    expect(results, findsNothing);
    expect(applied, ['202']);

    await harness.settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(MultiSelectionActionBar),
        matching: find.byIcon(Icons.more_horiz),
      ),
    );
    await harness.pumpUntilFound(tester, enrich());
    await tester.tap(enrich());
    final restart = find.widgetWithText(FilledButton, 'Enrich').hitTestable();
    await harness.pumpUntilFound(tester, restart);
    await tester.tap(restart);
    final once = find.text('Allow Once').hitTestable();
    await harness.pumpUntilFound(tester, once);
    await tester.tap(once);
    await harness.pumpUntilFound(tester, row(1).hitTestable());
    await tester.binding.handlePopRoute();
    final leave = find
        .widgetWithText(FilledButton, 'Leave Review')
        .hitTestable();
    await harness.pumpUntilFound(tester, leave);
    await tester.tap(leave);
    await harness.pumpUntil(tester, () => review.evaluate().isEmpty);
    expect(applied, ['202']);
  });

  testWidgets(
    'applied exact tags and exclusions follow Local Media profile switches',
    (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync(
        'local-query-handoff',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final library = (await tester.runAsync(
        () => LocalMediaLibrary.open(directory),
      ))!;
      addTearDown(library.close);
      await tester.runAsync(() async {
        for (final (index, tags) in [
          (0, ['cat', 'blue_hair']),
          (1, ['cat', 'dog']),
          (2, ['landscape']),
        ]) {
          await library.import(
            Stream.value(Uint8List.fromList([...lowerPng, index])),
            inspect: (_, _) async => (width: 2, height: 2, durationMs: null),
            cancellation: LocalMediaCancellation(),
            budget: LocalMediaImportBudget(),
            tags: [for (final tag in tags) (name: tag, category: 'general')],
          );
        }
      });
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        phone: TestPhone.smallPortrait,
        additionalOverrides: [
          localMediaAvailableProvider.overrideWithValue(true),
          localMediaLibraryProvider.overrideWith((_) => library),
        ],
      );
      final bar = find.byType(BooruSearchBar).hitTestable();
      await harness.pumpUntilFound(tester, bar);
      await tester.tap(bar);
      final searchPicker = find.byType(SearchContextProfilePicker);
      await harness.pumpUntilFound(tester, searchPicker);
      await harness.settle(tester);
      final search = find.byType(EditableText).hitTestable();
      await tester.enterText(search, 'cat');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await harness.pumpUntilFound(tester, find.byType(SelectedTagChip));
      await harness.settle(tester);

      final sourceController = InheritedSearchPageController.of(
        tester.element(searchPicker),
      );
      sourceController.tagsController
        ..addTag(TagSearchItem.fromString('-dog'))
        ..addTag(TagSearchItem.fromString('rating:g'));
      sourceController.commitSelection();
      expect(sourceController.tagString.value, 'cat -dog rating:g');
      sourceController.textController.text = 'draft';
      final chooseProfile = find.byTooltip('Choose a Profile').hitTestable();
      await tester.tap(chooseProfile);
      await harness.settle(tester);
      await tester.tap(find.text('Local Media').hitTestable());
      final local = find.byType(LocalMediaPage);
      await harness.pumpUntilFound(tester, local);
      await harness.settle(tester);
      expect(searchPicker, findsNothing);
      expect(sourceController.tagString.value, 'cat -dog rating:g');
      expect(sourceController.textController.text, 'draft');
      expect(
        find.text('Some search filters aren’t available on this profile.'),
        findsOneWidget,
      );
      final localRegion = find.byType(RawSearchRegion).hitTestable();
      final localController = tester
          .widget<RawSearchRegion>(localRegion)
          .controller;
      expect(localController.tagString.value, 'cat -dog');
      final localTiles = find.byType(DefaultImageGridItem<Post>).hitTestable();
      await harness.pumpUntil(tester, () => localTiles.evaluate().length == 1);
      final matchingTile = tester.widget<DefaultImageGridItem<Post>>(
        localTiles,
      );
      final matchingPost =
          matchingTile.controller.itemsNotifier.value[matchingTile.index];
      expect(
        (matchingPost.booruData as LocalMediaPostData).reference,
        library.list(query: 'cat blue_hair').single.reference,
      );
      localController.tagsController.addTag(
        TagSearchItem.fromString('blue_hair'),
      );
      await harness.pumpUntil(
        tester,
        () => localController.tagString.value == 'cat -dog blue_hair',
      );

      await tester.tap(chooseProfile);
      await harness.settle(tester);
      await tester.tap(find.text(backend.config.name).hitTestable());
      await harness.pumpUntilFound(tester, searchPicker);
      await harness.settle(tester);
      expect(local, findsNothing);
      final controller = InheritedSearchPageController.of(
        tester.element(searchPicker),
      );
      expect(controller.tagString.value, 'cat -dog blue_hair');
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (request) =>
              request.siteUrl == backend.config.url &&
              request.query == 'cat -dog blue_hair',
        ),
      );
      await tester.binding.handlePopRoute();
      await harness.pumpUntil(tester, () => searchPicker.evaluate().isEmpty);
      expect(find.byType(LocalMediaPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Local Media is a bookmark source and has a thumbnail icon', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(
      tester,
      phone: TestPhone.smallPortrait,
    );
    final browse = find.text('Browse');
    await harness.pumpUntilFound(tester, browse);
    final context = tester.element(browse);
    final bookmarks = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(bookmarkProvider.notifier);
    await harness.pumpUntilComplete(
      tester,
      bookmarks.addBookmark(
        BooruConfig.empty.auth,
        localMediaPost(LocalMediaReference.parse('a' * 64)),
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BookmarkPage(),
      ),
    );
    await harness.pumpUntilFound(tester, find.byType(BookmarkScrollView));
    final sourceIcon = find.descendant(
      of: find.bySubtype<DefaultImageGridItem>(),
      matching: find.byIcon(Icons.perm_media_outlined),
    );
    await harness.pumpUntilFound(tester, sourceIcon);
    final sourceFilter = find.byTooltip('Source: All');
    await tester.ensureVisible(sourceFilter);
    await harness.settle(tester);
    await tester.tap(sourceFilter);
    await harness.settle(tester);
    final localOption = find.ancestor(
      of: find.text('Local Media'),
      matching: find.byType(KurumiPopupMenuItem),
    );
    expect(localOption, findsOneWidget);
    await tester.tap(localOption);
    await harness.pumpUntilFound(tester, find.byTooltip('Source: Local Media'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookmarkScrollView)),
      listen: false,
    );
    await harness.pumpUntilComplete(
      tester,
      container.read(bookmarkTagIndexProvider(const BookmarkView.all()).future),
    );
    expect(sourceIcon, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Local Media search hides on scroll and returns on reversal', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('local-media-scroll');
    addTearDown(() => directory.deleteSync(recursive: true));
    final library = (await tester.runAsync(() async {
      final library = await LocalMediaLibrary.open(directory);
      for (var index = 0; index < 24; index++) {
        await library.import(
          Stream.value(Uint8List.fromList([...lowerPng, index])),
          inspect: (_, _) async => (width: 1, height: 3, durationMs: null),
          cancellation: LocalMediaCancellation(),
          budget: LocalMediaImportBudget(),
        );
      }
      return library;
    }))!;
    addTearDown(library.close);
    final harness = await HeadlessAppHarness.mount(
      tester,
      phone: TestPhone.smallPortrait,
      additionalOverrides: [
        localMediaAvailableProvider.overrideWithValue(true),
        localMediaLibraryProvider.overrideWith((_) => library),
      ],
    );
    final picker = find.byTooltip('Choose a Profile').hitTestable();
    await harness.pumpUntilFound(tester, picker);
    await tester.tap(picker);
    await harness.settle(tester);
    await tester.tap(find.text('Local Media').hitTestable());
    final grid = find.descendant(
      of: find.byType(LocalMediaPage),
      matching: find.byType(CustomScrollView),
    );
    final search = find.descendant(
      of: find.byType(LocalMediaPage),
      matching: find.byType(BooruSearchBar),
    );
    await harness.pumpUntilFound(tester, grid);
    await harness.pumpUntilFound(
      tester,
      find.bySubtype<DefaultImageGridItem>(),
    );
    await harness.settle(tester);
    expect(search.hitTestable(), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: grid, matching: find.byType(Scrollable)).first,
    );
    await tester.drag(grid, const Offset(0, -300));
    await harness.settle(tester);
    final offset = scrollable.position.pixels;
    expect(offset, greaterThan(100));
    expect(search.hitTestable(), findsNothing);
    await tester.drag(grid, const Offset(0, 112));
    await harness.settle(tester);
    expect(scrollable.position.pixels, lessThan(offset));
    expect(scrollable.position.pixels, greaterThan(0));
    expect(search.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'import progress counts processed files against the prepared total',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'local-media-progress',
      );
      final library = await LocalMediaLibrary.open(directory);
      final android = _TwoFiles();
      final container = ProviderContainer(
        overrides: [
          localMediaAndroidProvider.overrideWithValue(android),
          localMediaLibraryProvider.overrideWith((_) => library),
          miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await library.close();
        await directory.delete(recursive: true);
      });
      final operation = container
          .read(localMediaImportProvider.notifier)
          .pickAndImport(folder: true);
      await android.secondRequested.future.timeout(const Duration(seconds: 10));
      try {
        final progress = container.read(localMediaImportProvider);
        expect(progress.processed, 1);
        expect(progress.total, 2);
        expect(progress.fraction, 0.5);
      } finally {
        android.secondAllowed.complete();
        await operation;
      }
      final result = container.read(localMediaImportProvider);
      expect(result.processed, 2);
      expect(result.imported, 1);
      expect(result.duplicates, 1);
    },
  );
}

class _ImportAndroid extends LocalMediaAndroid {
  final remaining = Completer<bool>();

  @override
  Future<bool> pick({required bool folder}) async => true;

  @override
  Future<({int total, int failed, bool limit})> prepare() async =>
      (total: 2, failed: 1, limit: false);

  @override
  Future<bool> next() => remaining.future;

  @override
  Future<void> finish() async {}
}

class _TwoFiles extends LocalMediaAndroid {
  final secondRequested = Completer<void>();
  final secondAllowed = Completer<void>();
  var _requests = 0;

  @override
  Future<bool> pick({required bool folder}) async => true;

  @override
  Future<({int total, int failed, bool limit})> prepare() async =>
      (total: 2, failed: 0, limit: false);

  @override
  Future<bool> next() async {
    if (++_requests == 2) {
      secondRequested.complete();
      await secondAllowed.future;
    }
    return true;
  }

  @override
  Stream<Uint8List> readDocument() => Stream.value(lowerPng);

  @override
  Future<LocalMediaProbe> inspect(File file, LocalMediaFormat format) async =>
      (width: 1, height: 1, durationMs: null);

  @override
  Future<void> finish() async {}
}

final class _RecordingEnrichment extends LocalMediaEnrichmentService {
  _RecordingEnrichment(super._ref, this.hashes);

  final List<String> hashes;

  @override
  Future<LocalMediaEnrichmentOutcome> enrich(
    LocalMediaLibrary library,
    LocalMediaItem item, {
    required List<BooruConfig> profiles,
    required bool Function() cancelled,
    bool automatic = false,
    bool batch = false,
    CancelToken? lookupCancellation,
    List<LookupTarget>? selection,
    IqdbPermission iqdbPermission = IqdbPermission.none,
  }) {
    expect(batch, isTrue);
    expect(lookupCancellation, isNotNull);
    hashes.add(item.md5);
    return Future.value(switch (hashes.length) {
      <= 2 => const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.updated,
      ),
      <= 4 => const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.unchanged,
      ),
      _ => const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.unchanged,
        issue: LocalMediaEnrichmentIssue.noMatch,
      ),
    });
  }
}

final class _PreparedEnrichment extends LocalMediaEnrichmentService {
  _PreparedEnrichment(
    super._ref,
    this.items,
    this.profile,
    this.otherProfile,
    this.applied,
  );

  final List<LocalMediaItem> items;
  final BooruConfig profile;
  final BooruConfig otherProfile;
  final List<String> applied;
  var _failNextApply = true;

  static String matchUrl(BooruConfig profile, int id) =>
      Uri.parse(profile.url).resolve('review/$id.png').toString();

  IqdbHit _candidate(int id, double score, BooruConfig profile) => (
    profile: profile,
    postId: id.toString(),
    score: score,
    post: TestPost(
      id: id,
      origin: postOriginFromConfig(profile),
      sampleImageUrl: matchUrl(profile, id),
      originalImageUrl: matchUrl(profile, id),
      format: 'png',
    ),
  );

  @override
  Future<LocalMediaEnrichmentOutcome> enrich(
    LocalMediaLibrary library,
    LocalMediaItem item, {
    required List<BooruConfig> profiles,
    required bool Function() cancelled,
    bool automatic = false,
    bool batch = false,
    CancelToken? lookupCancellation,
    List<LookupTarget>? selection,
    IqdbPermission iqdbPermission = IqdbPermission.none,
  }) async => switch (items.indexWhere((row) => row.id == item.id)) {
    0 => LocalMediaEnrichmentOutcome(
      LocalMediaEnrichmentResult.unchanged,
      review: LocalMediaEnrichmentReview(item, [
        _candidate(201, 88.2, profile),
        _candidate(202, 81, otherProfile),
      ]),
    ),
    1 => LocalMediaEnrichmentOutcome(
      LocalMediaEnrichmentResult.unchanged,
      review: LocalMediaEnrichmentReview(item, [
        _candidate(203, 87.6, profile),
      ]),
    ),
    2 => const LocalMediaEnrichmentOutcome(
      LocalMediaEnrichmentResult.skipped,
      issue: LocalMediaEnrichmentIssue.noMatch,
    ),
    _ => LocalMediaEnrichmentOutcome(
      LocalMediaEnrichmentResult.skipped,
      issue: LocalMediaEnrichmentIssue.incompleteLookup,
      lookupDetails: {
        (
          profile: profile,
          method: PostLookupMatchKind.exactFile,
          failure: (
            kind: LocalMediaLookupFailureKind.rateLimited,
            httpStatus: null,
            retryAt: null,
          ),
        ),
      },
    ),
  };

  @override
  Future<LocalMediaEnrichmentOutcome> applyReview(
    LocalMediaLibrary library,
    LocalMediaEnrichmentReview review,
    IqdbHit hit, {
    required bool Function() current,
  }) async {
    if (!current() || _failNextApply) {
      _failNextApply = false;
      return const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.skipped,
        issue: LocalMediaEnrichmentIssue.operationFailed,
      );
    }
    applied.add(hit.postId);
    return const LocalMediaEnrichmentOutcome(
      LocalMediaEnrichmentResult.updated,
    );
  }
}
