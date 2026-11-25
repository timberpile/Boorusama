import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../bookmarks/src/types/bookmark_search_token.dart';
import '../boorus/booru/types.dart';
import '../configs/config/types.dart';
import '../configs/manage/widgets.dart';
import '../errors/types.dart';
import '../navigation/navigation_profile_picker.dart';
import '../posts/listing/src/widgets/default_image_grid_item.dart';
import '../posts/listing/src/widgets/default_multi_selection_actions.dart';
import '../posts/listing/src/widgets/post_duplicate_checker.dart';
import '../posts/listing/src/widgets/post_grid.dart';
import '../posts/listing/src/widgets/post_grid_controller.dart';
import '../posts/listing/src/widgets/post_grid_config_icon_button.dart';
import '../posts/post/types.dart';
import '../search/options/providers.dart';
import '../search/options/search_auto_commit.dart';
import '../search/options/search_options_section.dart';
import '../search/search/routes.dart';
import '../search/search/src/widgets/selected_tag_list.dart';
import '../search/search/widgets.dart';
import '../search/selected_tags/providers.dart';
import '../selection/ordered_selection_controller.dart';
import '../settings/providers.dart';
import '../tags/autocompletes/types.dart';
import '../widgets/multi_select_button.dart';
import 'local_media_actions.dart';
import 'local_media_library.dart';
import 'local_media_providers.dart';
import 'local_media_reference.dart';
import 'local_media_tags.dart';

class LocalMediaPage extends ConsumerWidget {
  const LocalMediaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.local_media;
    final library = ref.watch(localMediaLibraryProvider);
    return library.when(
      loading: () => const _LocalMediaUnavailableScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _LocalMediaUnavailableScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(t.storage_error, textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (library) => library == null
          ? const _LocalMediaUnavailableScaffold(body: SizedBox.shrink())
          : _LocalMediaGrid(key: ObjectKey(library), library: library),
    );
  }
}

class _LocalMediaUnavailableScaffold extends StatelessWidget {
  const _LocalMediaUnavailableScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
    appBar: KurumiAppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
      title: const BooruSearchBar(
        enabled: false,
        trailing: NavigationProfilePicker(favorites: false),
      ),
    ),
    body: body,
  );
}

class _ImportButton extends ConsumerWidget {
  const _ImportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.local_media;
    final imports = ref.watch(localMediaImportProvider);
    final clearing = ref.watch(localMediaClearingProvider);
    final notifier = ref.read(localMediaImportProvider.notifier);
    return KurumiPopupMenuButton(
      tooltip: t.import_action,
      semanticLabel: t.import_action,
      icon: const Icon(Icons.arrow_upward),
      enabled: !imports.running && !clearing,
      items: [
        KurumiPopupMenuItem(
          title: Text(t.import_files),
          icon: const Icon(Icons.insert_drive_file_outlined),
          onTap: () => unawaited(notifier.pickAndImport(folder: false)),
        ),
        KurumiPopupMenuItem(
          title: Text(t.import_folder),
          icon: const Icon(Icons.folder_open_outlined),
          onTap: () => unawaited(notifier.pickAndImport(folder: true)),
        ),
      ],
    );
  }
}

class _ImportProgress extends ConsumerWidget {
  const _ImportProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.local_media;
    final imports = ref.watch(localMediaImportProvider);
    if (imports.running) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: imports.fraction),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  imports.total == null
                      ? t.preparing_import
                      : t.importing(
                          count: imports.processed,
                          total: imports.total!,
                        ),
                ),
                TextButton(
                  onPressed: ref.read(localMediaImportProvider.notifier).cancel,
                  child: Text(context.t.generic.action.cancel),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (!imports.hasSummary) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        [
          t.import_result(
            imported: imports.imported,
            duplicates: imports.duplicates,
            skipped: imports.skipped,
            failed: imports.failed,
          ),
          if (imports.cancelled) t.import_cancelled,
          if (imports.limit) t.import_limit,
        ].join('\n'),
      ),
    );
  }
}

final _localMediaSearchCapabilities = capabilitiesFor(BooruType.localMedia, '');

final _localMediaSearchAuth = BooruConfig.defaultConfig(
  booruType: BooruType.localMedia,
  url: '',
  customDownloadFileNameFormat: null,
).auth;

class _LocalMediaGrid extends ConsumerStatefulWidget {
  const _LocalMediaGrid({required this.library, super.key});

  final LocalMediaLibrary library;

  @override
  ConsumerState<_LocalMediaGrid> createState() => _LocalMediaGridState();
}

class _LocalMediaGridState extends ConsumerState<_LocalMediaGrid> {
  late final PostGridController<Post> _controller;
  late final StreamSubscription<LocalMediaReference> _changes;
  late final SearchPageController _search;
  late final SearchAutoCommit _autoCommit;
  final _selection = OrderedSelectionController<Object>(
    exitWhenSelectionRemoved: true,
    exitOnDeselectAll: true,
  );
  final _scroll = AutoScrollController();

  @override
  void initState() {
    super.initState();
    _search = SearchPageController(
      tagsController: SelectedTagController(metatagExtractor: null),
      metatagExtractor: null,
      textMatchers: null,
      resolveExactTag: _resolveExactTag,
      optionKeys: {
        for (final option in _localMediaSearchCapabilities.options) option.key,
      },
    )..commitSelection();
    _autoCommit = SearchAutoCommit(
      readQuery: () => _search.tagsController.rawTagsString,
      readApplied: () => _search.tagString.value,
      commit: _search.commitSelection,
      schedule: (callback) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callback());
        WidgetsBinding.instance.ensureVisualUpdate();
      },
    );
    _search.tagsController.addListener(_autoCommit.changed);
    _search.tagString.addListener(_appliedQueryChanged);
    _controller = PostGridController<Post>(
      fetcher: _fetchPage,
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => mounted,
      duplicateTracker: PostDuplicateTracker(
        identityExtractor: (post) =>
            (post.booruData as LocalMediaPostData).reference,
      ),
      onError: (_) {
        if (mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.local_media.operation_failed,
          );
        }
      },
    );
    _changes = widget.library.changes.listen((_) {
      if (mounted &&
          !ref.read(localMediaImportProvider).running &&
          !ref.read(localMediaClearingProvider)) {
        _libraryChanged();
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    _autoCommit.dispose();
    _search.tagsController.dispose();
    _search.dispose();
    _selection.dispose();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  PostsOrErrorCore<Post> _fetchPage(int page) => TaskEither.tryCatch(
    () async {
      const pageSize = 60;
      final items = widget.library.list(
        query: _search.tagString.value,
        limit: pageSize + 1,
        offset: (page - 1) * pageSize,
      );
      return PostResult(
        posts: items.take(pageSize).map((item) => item.toPost()).toList(),
        total: null,
        hasMore: items.length > pageSize,
      );
    },
    (error, _) =>
        UnknownError(error: error, message: 'Local Media read failed'),
  );

  List<AutocompleteData> _suggestTags(String draft) {
    final query = _search.tagsController.tags
        .where((tag) => tag != _search.editingTag.value)
        .join(' ');
    return [
      for (final tag in widget.library.suggestTags(draft, query: query))
        AutocompleteData(
          label: tag.name,
          value: tag.name,
          type: AutocompleteData.tag,
          postCount: tag.count,
          category: tag.category,
        ),
    ];
  }

  AutocompleteData? _resolveExactTag(String draft) {
    if (_localMediaSearchCapabilities.contextFor(draft) != null) return null;
    final name = BookmarkSearchToken.parse(canonicalBookmarkTag(draft)).tag;
    return _suggestTags(draft).where((tag) => tag.value == name).firstOrNull;
  }

  void _returnToLibrary() {
    _search.closeEditor();
    _search.textController.clear();
    _search.tagsController.clear();
  }

  void _libraryChanged() {
    setState(() {});
    unawaited(_controller.refresh());
  }

  void _appliedQueryChanged() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_controller.refresh());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localMediaImportProvider, (previous, next) {
      if ((previous?.running ?? false) && !next.running) _libraryChanged();
    });
    ref.listen(localMediaClearingProvider, (previous, next) {
      if ((previous ?? false) && !next) _libraryChanged();
    });
    final color = Kurumi.themeOf(context).colorScheme.surface;
    final position = ref.watch(searchBarPositionProvider);
    return Scaffold(
      backgroundColor: color,
      resizeToAvoidBottomInset: false,
      body: RawSearchPageScaffold<Post>(
        fetcher: (page, _) => _fetchPage(page),
        params: const SearchParams(),
        tagsController: _search.tagsController,
        controller: _search,
        selectionModeController: _selection,
        onQueryChanged: (_) {},
        onPostControllerCreated: (_) {},
        resultHeader: const _ImportProgress(),
        nativeResultBuilder: (context, query, _, _, _, header, leadingSliver) =>
            _buildGrid(context, query, header, leadingSliver),
        landingView: SingleChildScrollView(
          child: SearchOptionsSection(
            config: _localMediaSearchAuth,
            pinStorageId: LocalMediaReference.namespace,
            controller: _search,
          ),
        ),
        searchSuggestions: DefaultSearchSuggestions(
          config: _localMediaSearchAuth,
          tagSuggestionConfig: localMediaTagAuth,
          tagSuggestions: _suggestTags,
          allowRawQuery: false,
          multiSelectController: _selection,
        ),
        searchRegion: ListenableBuilder(
          listenable: Listenable.merge([
            _search.focus,
            _search.state,
            _search.tagString,
          ]),
          builder: (context, _) {
            final active =
                _search.focus.hasFocus ||
                _search.state.value != SearchState.initial ||
                _search.tagString.value.isNotEmpty;
            const profilePicker = NavigationProfilePicker(favorites: false);
            return RawSearchRegion(
              controller: _search,
              searchBarPosition: position,
              showOptions: active,
              onBackPressed: _search.tagString.value.isNotEmpty
                  ? _returnToLibrary
                  : null,
              innerSearchButton: active
                  ? const SizedBox.shrink()
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [_ImportButton(), profilePicker],
                    ),
              trailingSearchButton: active ? profilePicker : null,
              tagList: ValueListenableBuilder(
                valueListenable: _search.tagsController,
                builder: (context, tags, _) => tags.isEmpty
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: kSelectedSearchTagHeight,
                        child: Center(
                          child: SelectedTagList(
                            tags: tags,
                            auth: localMediaTagAuth,
                            onClear: _search.tagsController.clear,
                            onDelete: _search.tagsController.removeTag,
                            onUpdate: null,
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    String query,
    Widget searchHeader,
    Widget? leadingSliver,
  ) {
    final t = context.t.local_media;
    return PostGrid<Post>(
      controller: _controller,
      scrollController: _scroll,
      selectionModeController: _selection,
      selectionKeysBuilder: (posts) => [
        for (final post in posts)
          (post.booruData as LocalMediaPostData).reference,
      ],
      header: const SizedBox.shrink(),
      sliverHeaders: [
        ?leadingSliver,
        SliverToBoxAdapter(child: searchHeader),
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CurrentBooruConfigScope(
              config: BooruConfig.empty,
              child: PostGridConfigIconButton<Post>(
                postController: _controller,
                showBlacklist: false,
              ),
            ),
          ),
        ),
      ],
      multiSelectActions: DefaultMultiSelectionActions<Post>(
        postController: _controller,
        extraActions: (posts) {
          final references = posts
              .map((post) => (post.booruData as LocalMediaPostData).reference)
              .toList();
          final item = references.length == 1
              ? widget.library.find(references.single)
              : null;
          return [
            MultiSelectButton(
              primary: true,
              icon: const Icon(Icons.share),
              name: context.t.post.action.share,
              onPressed: () => unawaited(
                shareLocalMedia(context, widget.library, references),
              ),
            ),
            if (item != null)
              MultiSelectButton(
                icon: const Icon(Icons.edit_outlined),
                name: t.edit,
                onPressed: () => unawaited(
                  editLocalMedia(
                    context,
                    () async => widget.library,
                    item,
                    ref.read(localMediaTagLookupProvider),
                  ),
                ),
              ),
            MultiSelectButton(
              icon: const Icon(Icons.delete_outline),
              name: t.delete,
              onPressed: () => unawaited(
                deleteLocalMedia(context, widget.library, references),
              ),
            ),
          ];
        },
      ),
      gridBuilder: (_, itemBuilder) => PostGridSliver<Post>(
        postController: _controller,
        itemBuilder: itemBuilder,
        emptyBuilder: (_) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text(query.isEmpty ? t.empty : t.no_results),
        ),
      ),
      itemBuilder: (context, index, scroll, hero) => DefaultImageGridItem(
        index: index,
        autoScrollController: scroll,
        controller: _controller,
        useHero: false,
        config: BooruConfig.empty.auth,
      ),
    );
  }
}
