import '../../../../../core/configs/config/types.dart';
import '../../../../../core/boorus/booru/types.dart';
import '../../../../../core/content/types.dart';
import '../../../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../../../core/posts/details/src/widgets/content_group_page.dart';
import '../../../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../content_group_source.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../bookmarks.dart';
import '../../pool/types.dart';

import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../../../core/posts/pools/widgets.dart';
import '../../../../../core/posts/details/src/widgets/post_details_page_view_scope.dart';
import '../../../../../core/posts/details_pageview/widgets.dart';
import 'widgets/danbooru_infinite_post_id_list.dart';
import 'widgets/description_section.dart';
import 'widgets/pool_gallery_header.dart';
import 'widgets/pool_order_selector.dart';

class PoolDetailPage extends ConsumerStatefulWidget {
  const PoolDetailPage({required this.pool, super.key});
  final DanbooruPool pool;
  @override
  ConsumerState<PoolDetailPage> createState() => _PoolDetailPageState();
}

class _PoolDetailPageState extends ConsumerState<PoolDetailPage> {
  late final GroupViewerEntry? _entry;
  @override
  void initState() {
    super.initState();
    final config = ref.readConfig;
    try {
      if (config.auth.booruType != BooruType.danbooru)
        throw const FormatException('Wrong Pool engine');
      final reference = const ContentReferenceCodec().parse(
        engine: config.auth.booruType,
        site: Uri.parse(config.url),
        kind: ContentKind.group,
        sourceKey: 'pool:${widget.pool.id}',
      );
      _entry = GroupViewerEntry(
        summary: ContentGroupSummary(
          reference: reference,
          title: widget.pool.name,
          memberCount: widget.pool.postCount,
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
              if (source is DanbooruGroupSource &&
                  widget.pool.postIds != null) {
                source.seedPool(entry.summary.reference, widget.pool);
              }
            },
          );
  }
}

/// The standalone route and mixed viewer use this same gallery implementation.
class PoolDetailContent extends ConsumerStatefulWidget {
  const PoolDetailContent({
    required this.pool,
    this.embedded = false,
    this.storageId,
    super.key,
  });
  final DanbooruPool pool;
  final bool embedded;
  final Object? storageId;
  @override
  ConsumerState<PoolDetailContent> createState() => _PoolDetailContentState();
}

class _PoolDetailContentState extends ConsumerState<PoolDetailContent> {
  PoolDetailsOrder _order = PoolDetailsOrder.order;
  final _scrollController = AutoScrollController();
  PostDetailsPageViewController? _outerPager;
  var _restored = false;
  var _selectionActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.embedded) _outerPager = PostDetailsPageViewScope.of(context);
    if (!_restored) {
      _restored = true;
      _order =
          PageStorage.maybeOf(context)?.readState(
            context,
            identifier: (widget.storageId ?? widget.pool.id, 'order'),
          ) as PoolDetailsOrder? ??
          PoolDetailsOrder.order;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_selectionActive) {
      _outerPager?.enableAllSwiping();
      _outerPager?.enableKeyboardShortcuts();
    }
    super.dispose();
  }

  void _setOrder(PoolDetailsOrder order) {
    if (order == _order) return;
    if (_selectionActive) {
      _selectionActive = false;
      _outerPager?.enableAllSwiping();
      _outerPager?.enableKeyboardShortcuts();
    }
    PageStorage.maybeOf(context)?.writeState(
      context,
      null,
      identifier: (widget.storageId ?? widget.pool.id, 'viewport', order),
    );
    PageStorage.maybeOf(context)?.writeState(
      context,
      order,
      identifier: (widget.storageId ?? widget.pool.id, 'order'),
    );
    setState(() => _order = order);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    return SafeArea(
      top: false,
      bottom: false,
      child: DanbooruInfinitePostIdList(
        pool: pool,
        order: _order,
        orderControl: PoolOrderSelector(value: _order, onChanged: _setOrder),
        checkpointIdentity: widget.embedded
            ? (widget.storageId ?? pool.id, 'viewport', _order)
            : null,
        scrollController: _scrollController,
        useHero: !widget.embedded,
        onSelectionChanged: widget.embedded
            ? (active) {
                if (_selectionActive == active) return;
                _selectionActive = active;
                if (active) {
                  _outerPager?.disableAllSwiping();
                  _outerPager?.disableKeyboardShortcuts();
                } else {
                  _outerPager?.enableAllSwiping();
                  _outerPager?.enableKeyboardShortcuts();
                }
              }
            : null,
        sliverHeaders: [
          PoolGalleryHeader(
            pool: danbooruBookmarkPool(
              pool,
              site: Uri.parse(ref.watchConfigAuth.url),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pool.name?.replaceAll('_', ' ') ?? '???',
                    style: Kurumi.themeOf(context).textTheme.titleLarge,
                  ),
                  if (pool.updatedAt case final updated?) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${context.t.pool.detail.last_updated}: ${updated.fuzzify(locale: Localizations.localeOf(context))}',
                      style: Kurumi.themeOf(context).textTheme.bodySmall
                          ?.copyWith(
                            color: Kurumi.themeOf(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PoolDescriptionSection(
              pool: pool,
            ),
          ),
        ],
      ),
    );
  }
}
