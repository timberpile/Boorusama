import '../../../../core/posts/links/share_group_link_button.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../core/boorus/booru/types.dart';
import '../../../../core/bookmarks/src/widgets/pool_bookmark_button.dart';
import '../../../../core/bulk_downloads/routes.dart';
import '../../../../core/configs/config/providers.dart';
import '../../../../core/configs/config/types.dart';
import '../../../../core/content/types.dart';
import '../../../../core/posts/details/routes.dart';
import '../../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../../core/posts/details/src/widgets/content_group_page.dart';
import '../../../../core/posts/details/src/widgets/post_details_page_view_scope.dart';
import '../../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../../../core/posts/details_pageview/widgets.dart';
import '../../../../core/posts/listing/widgets.dart';
import '../../../../core/posts/pools/group_post_scope.dart';
import '../../../../core/posts/pools/src/widgets/group_gallery_checkpoint.dart';
import '../../../../core/posts/pools/widgets.dart';
import '../../../../core/posts/post/types.dart';
import '../../../../core/search/search/routes.dart';
import '../../../../core/settings/providers.dart';
import '../bookmarks.dart';
import '../content_group_source.dart';
import '../types.dart';

class SzurubooruPoolDetailPage extends ConsumerStatefulWidget {
  const SzurubooruPoolDetailPage({
    required this.poolId,
    this.initialPool,
    super.key,
  });
  final int poolId;
  final SzurubooruPool? initialPool;
  @override
  ConsumerState<SzurubooruPoolDetailPage> createState() =>
      _SzurubooruPoolDetailPageState();
}

class _SzurubooruPoolDetailPageState
    extends ConsumerState<SzurubooruPoolDetailPage> {
  late final GroupViewerEntry? _entry;
  @override
  void initState() {
    super.initState();
    final config = ref.readConfig;
    try {
      if (config.auth.booruType != BooruType.szurubooru)
        throw const FormatException('Wrong Pool engine');
      final reference = const ContentReferenceCodec().parse(
        engine: BooruType.szurubooru,
        site: Uri.parse(config.url),
        kind: ContentKind.group,
        sourceKey: 'pool:${widget.poolId}',
      );
      _entry = GroupViewerEntry(
        summary: ContentGroupSummary(
          reference: reference,
          title: widget.initialPool?.name,
          memberCount: widget.initialPool?.postCount,
        ),
        occurrenceId: Object(),
        source: ViewerSourceBinding(config),
      );
    } on FormatException {
      _entry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return entry == null
        ? ViewerEntryNavigationStatus(
            child: Text(context.t.bookmark.pool_unavailable),
          )
        : ContentGroupPage(
            entry: entry,
            embedded: false,
            prepareSource: (source) {
              final pool = widget.initialPool;
              if (source is SzurubooruGroupSource && pool?.postIds != null) {
                source.seedPool(entry.summary.reference, pool!);
              }
            },
          );
  }
}

/// The native Pool route and mixed Group entry share this unchanged grid layout.
class SzurubooruPoolDetailContent extends ConsumerStatefulWidget {
  const SzurubooruPoolDetailContent({
    required this.pool,
    required this.embedded,
    required this.storageId,
    super.key,
  });
  final SzurubooruPool pool;
  final bool embedded;
  final Object storageId;
  @override
  ConsumerState<SzurubooruPoolDetailContent> createState() =>
      _SzurubooruPoolDetailContentState();
}

class _SzurubooruPoolDetailContentState
    extends ConsumerState<SzurubooruPoolDetailContent> {
  final _scroll = AutoScrollController();
  final _selection = SelectionModeController();
  PostDetailsPageViewController? _outer;
  var _restored = false;
  var _selecting = false;
  var _order = PoolDetailsOrder.order;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.embedded) _outer = PostDetailsPageViewScope.maybeOf(context);
    if (!_restored) {
      _restored = true;
      _order =
          PageStorage.maybeOf(context)?.readState(
            context,
            identifier: (widget.storageId, 'szuru-pool-order'),
          ) as PoolDetailsOrder? ??
          PoolDetailsOrder.order;
    }
  }

  void _selectionChanged() {
    if (_selecting == _selection.isActive) return;
    _selecting = _selection.isActive;
    if (_selecting) {
      _outer?.disableAllSwiping();
      _outer?.disableKeyboardShortcuts();
    } else {
      _outer?.enableAllSwiping();
      _outer?.enableKeyboardShortcuts();
    }
  }

  void _setOrder(PoolDetailsOrder value) {
    if (_order == value) return;
    _selection.disable();
    PageStorage.maybeOf(context)?.writeState(
      context,
      value,
      identifier: (widget.storageId, 'szuru-pool-order'),
    );
    PageStorage.maybeOf(context)?.writeState(
      context,
      null,
      identifier: (widget.storageId, 'szuru-pool-viewport', value),
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _order = value);
  }

  @override
  void dispose() {
    _selection.removeListener(_selectionChanged);
    _selection.dispose();
    _scroll.dispose();
    if (_selecting) {
      _outer?.enableAllSwiping();
      _outer?.enableKeyboardShortcuts();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final config = ref.watchConfig;
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.szurubooru,
      site: Uri.parse(config.url),
      kind: ContentKind.group,
      sourceKey: 'pool:${pool.id}',
    );
    final perPage = ref.watch(
      imageListingSettingsProvider.select((s) => s.postsPerPage),
    );
    final actions = <Widget>[
      const GroupLinkShareButton(),
      PoolBookmarkButton(
        pool: szurubooruBookmarkPool(pool, site: Uri.parse(config.url)),
      ),
      IconButton(
        tooltip: context.t.generic.action.search,
        icon: const Icon(Symbols.search),
        onPressed: () =>
            goToSearchPage(ref, tag: 'pool:${pool.id}', config: config),
      ),
      if (config.anonymousReadScope == null)
        IconButton(
          tooltip: context.t.download.download,
          icon: const Icon(Symbols.download),
          onPressed: () =>
              goToBulkDownloadPage(context, ['pool:${pool.id}'], ref: ref),
        ),
    ];
    return GroupPostScope(
      key: ValueKey((reference, _order, perPage)),
      reference: reference,
      orderKey: _order.name,
      perPage: perPage,
      builder: (context, controller) {
        final grid = PostGrid<Post>(
          controller: controller,
          scrollController: _scroll,
          selectionModeController: _selection,
          safeArea: !widget.embedded,
          itemBuilder: (context, index, scroll, useHero) =>
              DefaultImageGridItem<Post>(
                index: index,
                autoScrollController: scroll,
                controller: controller,
                useHero: !widget.embedded && useHero,
                config: config.auth,
                onTap: !widget.embedded
                    ? null
                    : () => goToPostDetailsPageFromController(
                        ref: ref,
                        initialIndex: index,
                        controller: controller,
                        initialThumbnailUrl: null,
                        config: config,
                        hero: false,
                      ),
              ),
          sliverHeaders: [
            if (widget.embedded)
              ViewerEntryNavigationHeader(actions: actions)
            else
              KurumiSliverAppBar(
                title: Text(context.t.pool.pool),
                floating: true,
                actions: actions,
              ),
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(
                  pool.name?.replaceAll('_', ' ') ?? '???',
                  style: Kurumi.themeOf(context).textTheme.titleLarge,
                ),
                subtitle: _SzurubooruPoolMetadata(pool: pool),
              ),
            ),
            if (pool.description case final description?
                when description.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: MarkdownBody(data: description),
                ),
              ),
            SliverToBoxAdapter(
              child: PoolOrderToggle(value: _order, onChanged: _setOrder),
            ),
          ],
        );
        return !widget.embedded
            ? grid
            : PoolGalleryCheckpoint(
                identity: (widget.storageId, 'szuru-pool-viewport', _order),
                controller: controller,
                scrollController: _scroll,
                perPage: perPage,
                child: grid,
              );
      },
    );
  }
}

class _SzurubooruPoolMetadata extends StatelessWidget {
  const _SzurubooruPoolMetadata({
    required this.pool,
  });

  final SzurubooruPool pool;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final summary = [
      if (pool.category case final category? when category.isNotEmpty)
        category.replaceAll('_', ' '),
      if (pool.postCount case final count?) context.t.posts.counter(n: count),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) Text(summary.join(' - ')),
        if (pool.updatedAt case final updatedAt?)
          Text(
            '${context.t.pool.detail.last_updated}: ${updatedAt.fuzzify(locale: locale)}',
          ),
      ],
    );
  }
}
