import '../../../content/groups/related_group_counts.dart';

import '../../../posts/listing/src/widgets/related_grid_card.dart';
import '../../../posts/listing/widgets.dart' show PostGridImage;

import '../providers/bookmark_read_access.dart';
import '../services/bookmark_presentation_covers.dart';
import '../types/pool_bookmark_cover.dart';

import 'package:dio/dio.dart';

import '../../../http/client/coordination.dart';
import '../../../blacklists/providers.dart';
import 'bookmark_group_viewer_entry.dart';
import '../providers/related_bookmark_provider.dart';
import '../../../posts/details/routes.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/listing/types.dart';
import '../../../posts/post/types.dart';
import '../../../config_widgets/website_logo.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../configs/manage/widgets.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/types.dart';
import '../../../posts/details/src/providers/viewer_source_access_provider.dart';
import '../../../configs/config/types.dart';
import '../../../images/booru_image.dart';
import '../../../posts/pools/pool_grid_item.dart';
import '../../../selection/selection_input.dart';
import '../../../settings/providers.dart';
import '../providers/bookmark_provider.dart';
import '../providers/pool_bookmark_provider.dart';
import '../types/pool_bookmark.dart';
import '../types/pool_bookmark_capability.dart';
import 'bookmark_group_picker.dart';

class BookmarkPoolCard extends ConsumerStatefulWidget {
  const BookmarkPoolCard({
    required this.pool,
    required this.index,
    this.groupId,
    this.projected = false,
    this.onOpen,
    this.relatedGeometry,
    super.key,
  });
  final CollectionBookmark pool;
  final int index;
  final String? groupId;
  final bool projected;
  final VoidCallback? onOpen;
  final RelatedGridGeometry? relatedGeometry;

  @override
  ConsumerState<BookmarkPoolCard> createState() => _BookmarkPoolCardState();
}

class _BookmarkPoolCardState extends ConsumerState<BookmarkPoolCard> {
  var _busy = false;
  final _relatedGeometry = RelatedGridGeometry();

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final selection = SelectionMode.of(context);
    final profile = resolvePoolBookmarkProfile(
      pool,
      ref.watch(bookmarkReadProfilesProvider),
    );
    final total = pool.isRelated ? _relatedTotal(pool) : pool.total;
    Widget buildCard(Widget image) => PoolGridItem(
      padding: pool.isRelated ? EdgeInsets.zero : const EdgeInsets.all(2),
      total: total,
      name: pool.isRelated ? null : pool.title,
      kind: pool.isRelated
          ? PoolGridItemKind.related
          : switch (pool.category) {
              BookmarkedPoolCategory.series => PoolGridItemKind.series,
              _ => PoolGridItemKind.collection,
            },
      sourceIcon: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: profile == null
            ? ConfigAwareWebsiteLogo.fromBooruType(
                pool.origin.booruType,
                pool.origin.sourceHost,
                fit: BoxFit.contain,
              )
            : ConfigAwareWebsiteLogo.fromConfig(
                profile.auth,
                customIconUrl: profile.profileIcon?.url,
                fit: BoxFit.contain,
              ),
      ),
      category: pool.isRelated
          ? null
          : switch (pool.category) {
              BookmarkedPoolCategory.series => context.t.pool.category.series,
              BookmarkedPoolCategory.collection =>
                context.t.pool.category.collection,
              BookmarkedPoolCategory.unknown => null,
            },
      image: image,
      onTap: () {
        if (!handleSelectionTap(context, widget.index)) _open();
      },
    );
    final card = pool.isRelated
        ? BookmarkPoolCoverImage._related(
            pool: pool,
            frame: _RelatedBookmarkCardFrame(
              geometry: widget.relatedGeometry ?? _relatedGeometry,
              listType: ref.watch(
                imageListingSettingsProvider.select((s) => s.imageListType),
              ),
              cardBuilder: buildCard,
            ),
          )
        : AspectRatio(
            aspectRatio: .6,
            child: buildCard(
              BookmarkPoolCoverImage(pool: pool, showLabel: true),
            ),
          );
    return KurumiContextMenu(
      triggers: !selection.isActive,
      menuItemsBuilder: (_) => [
        KurumiContextMenuTile(
          title: context.t.generic.action.view,
          onTap: _open,
        ),
        if (!widget.projected) ...[
          KurumiContextMenuTile(
            title: context.t.post.action.bookmark,
            onTap: () => showBookmarkPickerDialog(
              context,
              request: StoredBookmarkPickerRequest(
                config: profile?.auth ?? BooruConfig.empty.auth,
                collection: pool,
                source: profile,
              ),
            ),
          ),
          KurumiContextMenuTile(
            title: context.t.bookmark.pool_refresh,
            onTap: _refresh,
          ),
          if (widget.groupId != null)
            KurumiContextMenuTile(
              title: context.t.generic.action.remove,
              onTap: _remove,
            ),
        ],
        KurumiContextMenuTile(
          title: context.t.generic.action.select,
          onTap: () => selection.enable(initialSelected: [widget.index]),
        ),
      ],
      child: GestureDetector(
        onLongPress:
            selection.isActive || ref.watch(postGridLongPressOpensMenuProvider)
            ? null
            : () => selection.enable(initialSelected: [widget.index]),
        child: SelectableBuilder(
          index: widget.index,
          builder: (_, selected) => KurumiSelectableItem(
            item: card,
            onPreview: _open,
            isInSelectionMode: selection.isActive,
            isSelected: selected,
          ),
        ),
      ),
    );
  }

  int? _relatedTotal(CollectionBookmark pool) {
    final reference = bookmarkGroupReference(
      pool,
      ref.watch(bookmarkReadProfilesProvider),
    );
    if (reference == null) return null;
    // Cover rendering resolves this same reader. Observing its count does not
    // create a Group source or start a summary/member request.
    final access = ref.watch(
      bookmarkReadAccessProvider(BookmarkReaderRequest.reference(reference)),
    );
    if (access == null || !access.accepts(reference)) return null;
    final key = GroupMetadataKey(reference: reference, access: access.key);
    return ref.watch(
      relatedGroupCountsProvider.select(
        (counts) => relatedGroupTotal(counts, key, fallback: pool.total),
      ),
    );
  }

  Future<void> _open() async {
    if (widget.onOpen case final open?) {
      open();
      return;
    }
    final entry = groupViewerEntryForBookmark(
      ref,
      widget.pool,
      occurrenceId: widget.pool.localId,
    );
    final source = entry.source;
    final access = source == null
        ? null
        : ref.read(viewerSourceAccessProvider(source));
    goToPostDetailsPageCore<Post>(
      ref: ref,
      posts: const [],
      initialIndex: 0,
      hero: false,
      initialThumbnailUrl: null,
      config: access?.config,
      entries: [entry],
    );
  }

  Future<void> _refresh() => _perform((profile, capability) async {
    final expectedRecord = ref
        .read(bookmarkProvider)
        .asData
        ?.value
        .byId[widget.pool.bookmarkId ?? int.tryParse(widget.pool.localId)];
    if (widget.pool.family case final family?) {
      final summary = await ref.read(
        relatedBookmarkRefreshProvider((profile, family)).future,
      );
      if (!mounted || !_currentAccess(profile))
        throw StateError('Related profile changed');
      await ref
          .read(bookmarkProvider.notifier)
          .refreshPoolBookmark(
            summary,
            canCommit: () => mounted && _currentAccess(profile),
            expectedRecord: expectedRecord,
          );
      return;
    }
    final remote = await capability.getBookmarkPool(
      profile,
      widget.pool.referenceId,
    );
    if (remote == null || !mounted) throw StateError('Pool unavailable');
    final summary = await ref.read(
      poolBookmarkRefreshProvider((profile, remote)).future,
    );
    if (!mounted) return;
    if (!_currentAccess(profile)) {
      throw StateError('Pool profile changed');
    }
    await ref
        .read(bookmarkProvider.notifier)
        .refreshPoolBookmark(
          summary,
          canCommit: () => mounted && _currentAccess(profile),
          expectedRecord: expectedRecord,
        );
  });

  Future<void> _perform(
    Future<void> Function(BooruConfig, PoolBookmarkCapability) action,
  ) async {
    if (_busy) return;
    _busy = true;
    ProviderSubscription<ContentAccessContext?>? subscription;
    final cancellation = CancelToken();
    try {
      final entry = groupViewerEntryForBookmark(
        ref,
        widget.pool,
        occurrenceId: widget.pool.localId,
      );
      final binding = entry.source;
      if (binding == null) throw StateError('Pool source unavailable');
      subscription = ref.listenManual(
        viewerSourceAccessProvider(binding),
        (_, next) {
          if (_operationAccess != null &&
              next?.hasSameAuthorization(_operationAccess!) != true)
            cancellation.cancel("Bookmark reader revoked");
        },
      );
      final access = subscription.read();
      final profile = access?.config;
      final capability = profile == null
          ? null
          : ref.read(poolBookmarkCapabilityProvider(profile));
      if (profile == null || capability == null || access == null)
        throw StateError('Pool source unavailable');
      _operationAccess = access;
      await runWithApiRequestContext(
        ApiRequestContext(
          cancelToken: cancellation,
          canStart: () => mounted && _currentAccess(profile),
          canAdmit: () => mounted && _currentAccess(profile),
        ),
        () => action(profile, capability),
      );
    } catch (_) {
      if (mounted)
        Kurumi.showErrorToast(
          context,
          widget.pool.isRelated
              ? context.t.bookmark.related_unavailable
              : context.t.bookmark.pool_unavailable,
        );
    } finally {
      subscription?.close();
      _operationAccess = null;
      _busy = false;
    }
  }

  ContentAccessContext? _operationAccess;

  bool _currentAccess(BooruConfig profile) {
    final access = _operationAccess;
    return access != null &&
        identical(access.config, profile) &&
        identical(ref.read(contentAccessContextProvider(access.key)), access);
  }

  Future<void> _remove() async {
    if (_busy) return;
    _busy = true;
    final notifier = ref.read(bookmarkProvider.notifier);
    try {
      final result = await notifier.removePostsFromGroup(
        BooruConfig.empty.auth,
        [],
        widget.groupId!,
        poolLocalIds: {widget.pool.localId},
      );
      if (mounted) notifier.showRemovalUndo(context, result);
    } catch (_) {
      if (mounted)
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
    } finally {
      _busy = false;
    }
  }
}

/// Facts retained on the record or chosen locally for the current received revision.
final storedBookmarkPoolCoverProvider = Provider.autoDispose
    .family<PoolBookmarkCover?, CollectionBookmark>((ref, pool) {
      if (!pool.needsCoverFacts) return pool.cover;
      if (pool.groupIds.isNotEmpty) {
        final library = ref.watch(bookmarkProvider).asData?.value;
        final saved = library?.pools
            .where(
              (saved) =>
                  saved.localId == pool.localId &&
                  saved.identity == pool.identity &&
                  saved.sourceSite == pool.sourceSite &&
                  saved.observedAt == pool.observedAt,
            )
            .firstOrNull;
        if (library != null &&
            saved != null &&
            poolCoverHasReceivedMembership(library, saved)) {
          return ref
              .watch(bookmarkPresentationCoversProvider)
              .selected(
                bookmarkPresentationCoverKey(library, saved),
              );
        }
      }
      return null;
    });

/// Evaluate retained facts without starting a member or cover lookup.
final storedBookmarkPoolCoverEligibleProvider = Provider.autoDispose
    .family<bool, CollectionBookmark>((ref, pool) {
      final cover = ref.watch(storedBookmarkPoolCoverProvider(pool));
      if (cover == null) return false;
      final reference = bookmarkGroupReference(
        pool,
        ref.watch(bookmarkReadProfilesProvider),
      );
      if (reference == null) return false;
      final access = ref.watch(
        bookmarkReadAccessProvider(
          BookmarkReaderRequest.reference(reference),
        ),
      );
      final profile = access?.config;
      if (profile == null) return false;
      final blacklist = ref.watch(blacklistTagsProvider(profile.filter));
      if (blacklist.isLoading || !blacklist.hasValue || blacklist.hasError) {
        return false;
      }
      final publicSource = profile.anonymousReadScope?.source;
      final thumbnail = Uri.tryParse(cover.thumbnail);
      return (publicSource == null ||
              (thumbnail != null && publicSource.allowsMedia(thumbnail))) &&
          bookmarkCoverAllowed(cover, profile, blacklist.requireValue);
    });

class BookmarkPoolCoverImage extends ConsumerStatefulWidget {
  const BookmarkPoolCoverImage({
    required this.pool,
    this.showLabel = false,
    this.allowBackfill = true,
    super.key,
  }) : _frame = null;
  const BookmarkPoolCoverImage._related({
    required this.pool,
    required _RelatedBookmarkCardFrame frame,
  }) : _frame = frame,
       showLabel = true,
       allowBackfill = true;
  final CollectionBookmark pool;
  final bool showLabel;
  final bool allowBackfill;
  final _RelatedBookmarkCardFrame? _frame;
  @override
  ConsumerState<BookmarkPoolCoverImage> createState() =>
      _BookmarkPoolCoverImageState();
}

class _BookmarkPoolCoverImageState
    extends ConsumerState<BookmarkPoolCoverImage> {
  BooruConfig? _discoveryReader;
  String? _presentationRevision;
  bool? _wasVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _wasVisible == false) _discoveryReader = null;
    _wasVisible = visible;
  }

  @override
  void didUpdateWidget(BookmarkPoolCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pool.localId != widget.pool.localId ||
        oldWidget.pool.identity != widget.pool.identity ||
        oldWidget.pool.sourceSite != widget.pool.sourceSite ||
        oldWidget.pool.observedAt != widget.pool.observedAt)
      _discoveryReader = null;
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final reference = bookmarkGroupReference(
      pool,
      ref.watch(bookmarkReadProfilesProvider),
    );
    final access = reference == null
        ? null
        : ref.watch(
            bookmarkReadAccessProvider(
              BookmarkReaderRequest.reference(reference),
            ),
          );
    final profile = access?.config;
    final blacklist = profile == null
        ? null
        : ref.watch(blacklistTagsProvider(profile.filter));
    // Reading an existing receiver choice is independent from starting a new
    // discovery attempt. A newly selected actor may display the same choice
    // immediately if its current policy permits it.
    final presentation = _presentationCover(pool);
    final visible = TickerMode.valuesOf(context).enabled;
    if (widget.allowBackfill &&
        visible &&
        pool.needsCoverFacts &&
        presentation == null &&
        _discoveryReader == null)
      _discoveryReader = profile;
    final reader = _discoveryReader;
    // A covered route cannot start fresh work. An existing attempt keeps its
    // actor when profiles/policy change; revocation must not cycle accounts.
    final backfill =
        widget.allowBackfill &&
            visible &&
            reader != null &&
            pool.needsCoverFacts &&
            presentation == null &&
            pool.groupIds.isNotEmpty
        ? ref.watch(missingPoolCoverProvider((reader, pool)))
        : null;
    if (presentation == null && (backfill?.isLoading ?? false))
      return _present(const KurumiImagePlaceholder());
    if ((backfill?.hasError ?? false) && widget.showLabel) {
      return _present(
        Center(child: Text(context.t.search.errors.failed_to_load_data)),
      );
    }
    final displayed = presentation == null
        ? backfill?.asData?.value ?? pool
        : pool.copyWith(cover: presentation, coverUrl: presentation.thumbnail);
    final allowed =
        profile != null &&
        displayed.coverUrl != null &&
        displayed.cover != null &&
        blacklist?.hasValue == true &&
        !blacklist!.isLoading &&
        !blacklist.hasError &&
        bookmarkCoverAllowed(displayed.cover!, profile, blacklist.requireValue);
    if (profile != null &&
        displayed.cover != null &&
        displayed.coverUrl != null &&
        (allowed || widget._frame != null)) {
      return CurrentBooruConfigScope(
        config: profile,
        accessKey: access!.key,
        requireAccess: true,
        bookmarkId: pool.bookmarkId,
        child: _BookmarkPoolCoverMedia(
          config: profile,
          cover: displayed.cover!,
          frame: widget._frame,
          // Resolve retained metadata before layout even while policy loads;
          // the image itself remains gated by the unchanged visibility check.
          placeholder: allowed ? null : _unavailable(context),
        ),
      );
    }
    return _present(_unavailable(context));
  }

  Widget _unavailable(BuildContext context) => ColoredBox(
    color: Kurumi.themeOf(context).colorScheme.surfaceContainerLow,
    child: widget.showLabel
        ? Center(
            child: Text(
              context.t.pool.no_cover_image,
              textAlign: TextAlign.center,
            ),
          )
        : const SizedBox.expand(),
  );

  Widget _present(Widget image) =>
      widget._frame?.build(null, (_) => image) ?? image;

  PoolBookmarkCover? _presentationCover(CollectionBookmark pool) {
    if (!pool.needsCoverFacts || pool.groupIds.isEmpty) return null;
    final library = ref.watch(bookmarkProvider).asData?.value;
    if (library == null) return null;
    final saved = library.pools
        .where(
          (p) =>
              p.localId == pool.localId &&
              p.identity == pool.identity &&
              p.sourceSite == pool.sourceSite &&
              p.observedAt == pool.observedAt,
        )
        .firstOrNull;
    if (saved == null || !poolCoverHasReceivedMembership(library, saved)) {
      if (_presentationRevision != null) _discoveryReader = null;
      _presentationRevision = null;
      return null;
    }
    final revision = bookmarkPresentationCoverKey(library, saved);
    if (_presentationRevision != revision) _discoveryReader = null;
    _presentationRevision = revision;
    return ref.watch(bookmarkPresentationCoversProvider).selected(revision);
  }
}

/// Read presentation settings inside the image's established source scope, so
/// global and source-local listing projections cannot notify sibling scopes
/// synchronously while a parent listing rebuilds.
class _BookmarkPoolCoverMedia extends ConsumerWidget {
  const _BookmarkPoolCoverMedia({
    required this.config,
    required this.cover,
    this.frame,
    this.placeholder,
  });
  final _RelatedBookmarkCardFrame? frame;
  final Widget? placeholder;
  final BooruConfig config;
  final PoolBookmarkCover cover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gridThumbnailSettingsProvider(config.auth));
    final radius = ref.watch(
      imageListingSettingsProvider.select((s) => s.imageBorderRadius),
    );
    final media = ref
        .watch(gridThumbnailUrlGeneratorProvider(config.auth))
        .resolveStaticCover(cover, settings: settings);
    if (frame case final related?) {
      return related.build(
        media.aspectRatio,
        (fit) =>
            placeholder ??
            PostGridImage(
              media: media,
              config: config.auth,
              fit: fit,
              forceCover: fit == BoxFit.cover,
            ),
      );
    }
    return BooruImage(
      config: config.auth,
      imageUrl: media.url,
      placeholderUrl: cover.thumbnail,
      aspectRatio: .6,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

/// The entire card shares the cover's already resolved source scope. Placeholder
/// paths capture the fallback too, before discovery can provide a later cover.
class _RelatedBookmarkCardFrame {
  const _RelatedBookmarkCardFrame({
    required this.geometry,
    required this.listType,
    required this.cardBuilder,
  });
  final RelatedGridGeometry geometry;
  final ImageListType listType;
  final Widget Function(Widget image) cardBuilder;

  Widget build(double? ratio, Widget Function(BoxFit fit) imageBuilder) =>
      RelatedGridCard(
        geometry: geometry,
        listType: listType,
        aspectRatio: ratio,
        builder: (fit) => cardBuilder(imageBuilder(fit)),
      );
}
