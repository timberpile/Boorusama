import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/groups/group_visibility.dart'
    show groupAllowsRating;
import '../../../core/content/types.dart';
import '../../../core/content/widgets/native_content_grid.dart';
import '../../../core/home/src/pages/mobile_home_page_scaffold.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/navigation/navigation_profile_picker.dart';
import '../../../core/posts/favorites/src/widgets/favorites_page_menu.dart';
import '../../../core/posts/listing/src/widgets/timeline_option_selector.dart';
import '../../../core/posts/listing/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/search/widgets.dart';
import '../../../core/settings/providers.dart';
import '../availability.dart';
import '../client_provider.dart';
import '../favorites/account.dart';
import '../favorites/cache.dart';
import '../favorites/control.dart';
import '../galleries/listing.dart';
import '../galleries/mapper.dart';
import '../tags/providers.dart';

class NhentaiHomePage extends ConsumerWidget {
  const NhentaiHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(nhentaiAvailableProvider)) return const _Unavailable();
    final config = ref.watchConfig;
    final composer = ref.watch(defaultTagQueryComposerProvider(config.search));
    return MobileHomePageScaffold(
      preserveOriginalQuery: true,
      nativeResultBuilder: (context, text, headers) => _GalleryGrid(
        config: config,
        query: composer.compose([if (text.isNotEmpty) text]).join(' '),
        sliverHeaders: headers,
      ),
    );
  }
}

class NhentaiSearchPage extends ConsumerWidget {
  const NhentaiSearchPage({required this.params, super.key});
  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(nhentaiAvailableProvider)) return const _Unavailable();
    final config = ref.watchConfig;
    final composer = ref.watch(defaultTagQueryComposerProvider(config.search));
    final repository = ref.watch(originAwarePostRepoProvider(config));
    return SearchPageScaffold<Post>(
      preserveOriginalQuery: true,
      params: params,
      fetcher: (page, controller) =>
          repository.getPostsFromController(controller.tagSet, page),
      nativeResultBuilder:
          (
            context,
            query,
            page,
            scroll,
            pageMode,
            header,
            leadingSliver,
            toolbar,
          ) => _GalleryGrid(
            config: config,
            query: composer.compose([if (query.isNotEmpty) query]).join(' '),
            initialPage: page,
            initialScrollPosition: scroll,
            pageMode: pageMode,
            header: header,
            sliverHeaders: [?leadingSliver],
            toolbarAction: toolbar.follow,
            toolbarMenuItems: [toolbar.share],
          ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(context.t.navigation.unavailable_profile),
  );
}

class NhentaiPopularPage extends ConsumerWidget {
  const NhentaiPopularPage({required this.config, super.key});
  final BooruConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _GalleryGrid(
    config: config,
    query: '',
    kind: _GalleryListingKind.popular,
  );
}

class NhentaiFavoritesPage extends ConsumerWidget {
  const NhentaiFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final hasKey = isNhentaiApiKey(config.apiKey);
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(context.t.profile.favorites),
        actions: const [
          NavigationProfilePicker(favorites: true),
          FavoritesPageMenu(),
        ],
      ),
      body: hasKey
          ? _GalleryGrid(
              config: config,
              query: '',
              kind: _GalleryListingKind.favorites,
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.t.nhentai.favorites_require_key,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}

enum _GalleryListingKind { browse, popular, favorites }

class _GalleryGrid extends ConsumerStatefulWidget {
  const _GalleryGrid({
    required this.config,
    required this.query,
    this.header,
    this.sliverHeaders = const [],
    this.toolbarAction,
    this.toolbarMenuItems = const [],
    this.initialPage,
    this.initialScrollPosition,
    this.pageMode,
    this.kind = _GalleryListingKind.browse,
  });

  final BooruConfig config;
  final String query;
  final Widget? header;
  final List<Widget> sliverHeaders;
  final Widget? toolbarAction;
  final List<Widget> toolbarMenuItems;
  final int? initialPage;
  final int? initialScrollPosition;
  final PageMode? pageMode;
  final _GalleryListingKind kind;

  @override
  ConsumerState<_GalleryGrid> createState() => _GalleryGridState();
}

class _GalleryGridState extends ConsumerState<_GalleryGrid> {
  final _seen = <int, Set<int>>{};
  CancelToken? _warmup;
  ContentAccessKey? _key;
  NhentaiGallerySort? _selectedSort;
  var _startedWarmup = false;

  @override
  void didUpdateWidget(_GalleryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) _seen.clear();
  }

  @override
  void dispose() {
    _warmup?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(contentProfileAccessProvider(widget.config.id));
    final settings = ref.watch(imageListingSettingsProvider);
    final active = NavigationActivity.of(context);
    if (_key != access?.key || !active) {
      _warmup?.cancel();
      _warmup = null;
      _startedWarmup = false;
    }
    if (_key != access?.key) {
      _key = access?.key;
      _seen.clear();
    }
    if (access == null) return const _Unavailable();
    final config = access.config!;
    final listing = ref.watch(nhentaiGalleryListingProvider(access.key));
    if (listing == null) {
      final state = ref.watch(contentGroupSourceStateProvider(access.key));
      return state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : const _Unavailable();
    }
    final source = listing.source;
    final kind = widget.kind;
    final revision = kind == _GalleryListingKind.favorites
        ? ref.watch(nhentaiFavoritesRevisionProvider(access.key))
        : 0;
    final account = kind == _GalleryListingKind.favorites
        ? ref.watch(nhentaiAccountClientProvider(access.key))
        : null;
    final query = widget.query;
    final sort = _selectedSort ?? NhentaiGallerySort.newest;
    String sortLabel(NhentaiGallerySort option) => switch (option) {
      NhentaiGallerySort.newest => context.t.nhentai.sort_newest,
      NhentaiGallerySort.popularToday => context.t.nhentai.sort_popular_today,
      NhentaiGallerySort.popularWeek => context.t.nhentai.sort_popular_week,
      NhentaiGallerySort.popularAllTime =>
        context.t.nhentai.sort_popular_all_time,
    };
    return NativeContentGrid(
      key: ValueKey(sort),
      access: access,
      queryIdentity: (kind, query, config.search, revision),
      pageMode: widget.pageMode ?? settings.pageMode,
      allowPageModeChange: kind != _GalleryListingKind.popular,
      initialPage: _selectedSort == null ? (widget.initialPage ?? 1) : 1,
      initialScrollPosition: _selectedSort == null
          ? widget.initialScrollPosition
          : null,
      header: widget.header,
      sliverHeaders: widget.sliverHeaders,
      toolbarControls: [
        if (kind == _GalleryListingKind.browse) ...[
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 12, thickness: 1),
          ),
          TimelineOptionSelector<NhentaiGallerySort>(
            label: sortLabel(sort),
            options: NhentaiGallerySort.values,
            value: sort,
            optionLabel: sortLabel,
            optionIcon: (option) => option == NhentaiGallerySort.newest
                ? Symbols.schedule
                : Symbols.local_fire_department,
            triggerSemanticLabel: '${context.t.sort.short}: ${sortLabel(sort)}',
            onSelected: (option) {
              if (sort == option) return;
              setState(() {
                _seen.clear();
                _selectedSort = option;
              });
            },
          ),
        ],
      ],
      toolbarAction: widget.toolbarAction,
      toolbarMenuItems: widget.toolbarMenuItems,
      counterLabel: (context, n) =>
          context.t.content_viewer.gallery_counter(n: n),
      groupLabel: (context, _) => context.t.content_viewer.gallery,
      showGroupBadgeIcon: false,
      groupQuickAction: (context, group) => NhentaiGalleryQuickFavorite(
        access: access,
        galleryId: nhentaiIdFromReference(group.reference),
      ),
      onRefresh: () {
        _seen.clear();
        source.invalidateAll();
        refreshNhentaiMediaPolicy(ref, config.auth);
      },
      fetchPage: (page) async {
        final request = ApiRequestContext.current();
        final token = request.cancelToken;
        final client = ref.read(nhentaiClientProvider(config.auth));
        if (kind == _GalleryListingKind.popular) {
          final popular = await client.getPopularGalleries(cancelToken: token);
          final summaries = await listing.project(
            popular,
            cancelToken: token,
            canAdmit: request.canAdmit,
          );
          return NativeContentPage(
            entries: summaries.map(
              (summary) => GroupContentEntry(summary: summary),
            ),
            hasMore: false,
            total: summaries.length,
          );
        }
        final favoriteCache = account == null
            ? null
            : ref.read(
                nhentaiFavoriteCacheProvider(nhentaiFavoriteOwner(access))
                    .notifier,
              );
        final favoriteRead = favoriteCache?.beginRead();
        final result = kind == _GalleryListingKind.favorites
            ? await (account ??
                      (throw StateError('nhentai account unavailable')))
                  .getFavorites(page, cancelToken: token)
            : await client.getGalleries(
                page: page,
                perPage: settings.postsPerPage.clamp(1, 100),
                query: query.isEmpty ? null : query,
                sort: sort,
                cancelToken: token,
              );
        final candidates = result.items.where(
          (item) =>
              item.blacklisted != true &&
              groupAllowsRating(config, Rating.unknown),
        );
        final prior = {
          for (final entry in _seen.entries)
            if (entry.key < page) ...entry.value,
        };
        final newIds = <int>{};
        final summaries = await listing.project(
          candidates.where(
            (item) => !prior.contains(item.id) && newIds.add(item.id),
          ),
          cancelToken: token,
          canAdmit: request.canAdmit,
        );
        if (!mounted ||
            _key != access.key ||
            query != widget.query ||
            sort != (_selectedSort ?? NhentaiGallerySort.newest) ||
            (token?.isCancelled ?? false) ||
            !(request.canAdmit?.call() ?? true)) {
          throw StateError('Gallery listing access changed');
        }
        if (favoriteCache != null &&
            favoriteRead != null &&
            ref.read(contentAccessContextProvider(access.key)) != null) {
          unawaited(
            favoriteCache.observeFavorites(
              result.items.map((item) => item.id),
              favoriteRead,
            ),
          );
        }
        _seen.removeWhere((number, _) => number >= page);
        _seen[page] = newIds;
        if (active &&
            kind == _GalleryListingKind.browse &&
            summaries.isNotEmpty) {
          final token = _warmup ??= CancelToken();
          final ids = candidates.expand((item) => item.tagIds).toSet();
          final warmCatalog = !_startedWarmup;
          _startedWarmup = true;
          unawaited(
            warmNhentaiTags(
              listing.cache,
              ids,
              token,
              warmCatalog: warmCatalog,
            ),
          );
        }
        return NativeContentPage(
          entries: summaries.map(
            (summary) => GroupContentEntry(summary: summary),
          ),
          hasMore:
              (result.hasMore ?? false) &&
              result.total != 0 &&
              (result.reportedPerPage == null ||
                  result.rawCount <= result.reportedPerPage!),
          total: result.total,
          rawCount: result.rawCount,
        );
      },
    );
  }
}
