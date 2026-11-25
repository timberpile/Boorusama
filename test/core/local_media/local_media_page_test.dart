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
import 'package:boorusama/core/configs/config/types.dart';
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
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/search/search/src/views/simple_tag_search_view.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_context_profile_picker.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/suggestions/widgets.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/tags/tag/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/default_image_grid_item.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_config_icon_button.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../posts/details/progressive_image_test_utils.dart' show lowerPng;

import '../../application/support/fake_booru_backend.dart';
import '../../application/support/headless_app_harness.dart';

void main() {
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
      expect(find.byKey(const ValueKey('search-option.order')), findsOneWidget);
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
  testWidgets('Danbooru search can switch to Local Media and back', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      phone: TestPhone.smallPortrait,
      additionalOverrides: [
        localMediaAvailableProvider.overrideWithValue(true),
        localMediaLibraryProvider.overrideWith((_) => null),
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

    final chooseProfile = find.byTooltip('Choose a Profile').hitTestable();
    await tester.tap(chooseProfile);
    await harness.settle(tester);
    await tester.tap(find.text('Local Media').hitTestable());
    final local = find.byType(LocalMediaPage);
    await harness.pumpUntilFound(tester, local);
    await harness.settle(tester);
    expect(searchPicker, findsNothing);

    await tester.tap(chooseProfile);
    await harness.settle(tester);
    await tester.tap(find.text(backend.config.name).hitTestable());
    await harness.pumpUntilFound(tester, searchPicker);
    await harness.settle(tester);
    expect(local, findsNothing);
    final controller = InheritedSearchPageController.of(
      tester.element(searchPicker),
    );
    expect(controller.tagString.value, 'cat');
    expect(tester.takeException(), isNull);
  });

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
