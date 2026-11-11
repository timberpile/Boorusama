import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/providers.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/widgets.dart';
import '../../content/content_access_provider.dart';
import '../../content/content_media_access.dart';
import '../../content/groups/group_source_provider.dart';
import '../../content/types.dart';
import '../../errors/types.dart';
import '../../navigation/destination_activity.dart';
import '../../settings/providers.dart';
import '../listing/types.dart';
import '../listing/widgets.dart';
import '../listing/src/widgets/post_grid_controller.dart';
import '../post/types.dart';
import '../details/src/types/viewer_entry.dart';
import 'src/types/group_post_pager.dart';

/// Keeps the established PostScope/gallery UX while replacing only its source
/// fetcher with the registered, access-bound Group membership contract.
class GroupPostScope extends ConsumerStatefulWidget {
  const GroupPostScope({
    required this.reference,
    required this.perPage,
    required this.builder,
    this.orderKey,
    this.prepareSource,
    this.scrollController,
    super.key,
  });
  final ContentReference reference;
  final String? orderKey;
  final int perPage;
  final void Function(ContentGroupSource source)? prepareSource;
  final ScrollController? scrollController;
  final Widget Function(
    BuildContext context,
    PostGridController<Post> controller,
  )
  builder;
  @override
  ConsumerState<GroupPostScope> createState() => _GroupPostScopeState();
}

class _GroupPostScopeState extends ConsumerState<GroupPostScope> {
  GroupPostPager? _pager;
  Object? _identity;
  PostGridController<Post>? _controller;
  var _projectionRevision = 0;
  ({GroupMetadataKey metadata, int revision})? _ownRefresh;
  var _peerRefreshPending = false;
  var _active = false;
  int? _peerInitialPage;

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _active = NavigationActivity.of(context);
    final config = ref.watchConfig;
    final inherited = ref.watch(currentContentAccessKeyProvider);
    var access = inherited == null
        ? ref.watch(contentProfileAccessProvider(config.id))
        : ref.watch(contentAccessContextProvider(inherited));
    if (access?.config == null ||
        (inherited == null &&
            ViewerSourceBinding(config).resolve([access!.config!]) == null) ||
        (inherited != null && access!.config!.auth != config.auth)) {
      access = null;
    }
    final key = access?.key;
    final source = access == null
        ? null
        : ref.watch(contentGroupSourceStateProvider(access.key)).asData?.value;
    final metadata = key == null
        ? null
        : GroupMetadataKey(reference: widget.reference, access: key);
    if (metadata != null) {
      ref.listen(groupRefreshRevisionProvider(metadata), (previous, next) {
        if (_ownRefresh == (metadata: metadata, revision: next)) return;
        _peerInitialPage = _controller?.pageMode == PageMode.paginated
            ? _controller?.page
            : null;
        // Revoke pending publication immediately, including inactive pages.
        _pager?.dispose();
        _pager = null;
        _identity = null;
        _projectionRevision++;
        _peerRefreshPending = true;
        if (_active) setState(() {});
      });
    }
    if (_peerRefreshPending) {
      if (!_active) return const SizedBox.expand();
      _peerRefreshPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final scroll = widget.scrollController;
        if (scroll?.hasClients ?? false) scroll!.jumpTo(0);
      });
    }
    final identity = (
      source,
      key,
      widget.reference,
      widget.orderKey,
      widget.perPage,
      _projectionRevision,
    );
    if (_identity != identity) {
      _pager?.dispose();
      _identity = identity;
      _pager = source == null
          ? null
          : GroupPostPager(
              source: source,
              reference: widget.reference,
              orderKey: widget.orderKey,
              perPage: widget.perPage,
              isPaginated: () =>
                  ref.read(imageListingSettingsProvider).pageMode ==
                  PageMode.paginated,
              isCurrent: () {
                if (!mounted || _identity != identity) return false;
                try {
                  return identical(
                    ref.read(contentGroupSourceProvider(key!)),
                    source,
                  );
                } catch (_) {
                  return false;
                }
              },
            );
      if (source != null) widget.prepareSource?.call(source);
    }
    final pager = _pager;
    final posts = PostScope<Post>(
      key: ValueKey(identity),
      initialPage: _peerInitialPage,
      fetcher: (page) => TaskEither.tryCatch(
        () => pager == null
            ? Future<PostResult<Post>>.error(
                StateError('Group source unavailable'),
              )
            : pager.fetch(page),
        (error, _) => error is BooruError
            ? error
            : UnknownError(
                error: error,
                message: 'Unable to load Group members',
              ),
      ),
      // Membership keys, rather than Post IDs, own deduplication and selection.
      duplicateIdentity: (_) => null,
      onRefresh: pager == null
          ? null
          : () {
              // Initial grid loading also uses the controller's refresh path.
              // Only a real refresh invalidates metadata observed by siblings.
              final invalidated = pager.refresh();
              if (invalidated && metadata != null) {
                _ownRefresh = (
                  metadata: metadata,
                  revision:
                      ref.read(groupRefreshRevisionProvider(metadata)) + 1,
                );
                ref
                    .read(groupRefreshRevisionProvider(metadata).notifier)
                    .advance();
                ref.invalidate(groupDetailsProvider(metadata));
                ref.invalidate(groupSummaryProvider(metadata));
              }
            },
      selectionKeysBuilder: pager?.selectionKeys,
      builder: (context, controller) {
        _controller = controller;
        return widget.builder(context, controller);
      },
    );
    return access?.config == null
        ? posts
        : CurrentBooruConfigScope(
            config: access!.config!,
            accessKey: key,
            requireAccess: true,
            child: posts,
          );
  }
}
