import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../../foundation/loggers.dart';
import '../../../../configs/config/types.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/groups/group_capability.dart';
import '../../../../content/types.dart';
import '../../../../downloads/downloader/providers.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../widgets/adaptive_button_row.dart';
import '../../../../widgets/booru_menu_button_row.dart';
import '../../../details_parts/src/toolbars/simple_post_action_toolbar.dart';
import '../../../links/link_file_labels.dart';
import '../../../links/share_group_link_button.dart';
import '../../../post/types.dart';
import '../providers/media_group_provider.dart';
import '../types/viewer_entry.dart';
import '../types/inherited_post.dart';

/// Adds Work-only actions to the existing Post toolbar's overflow menu.
/// Page download, sharing, favorites and image quality retain the normal UI.
class MediaGroupActions extends ConsumerStatefulWidget {
  const MediaGroupActions({
    required this.entry,
    required this.child,
    super.key,
  });
  final GroupViewerEntry entry;
  final Widget child;
  @override
  ConsumerState<MediaGroupActions> createState() => _MediaGroupActionsState();
}

class _MediaGroupActionsState extends ConsumerState<MediaGroupActions> {
  var _downloading = false;
  var _cancel = false;
  var _queued = 0;
  var _total = 0;
  var _incomplete = false;

  bool _current(ContentAccessContext access) =>
      mounted &&
      NavigationActivity.of(context) &&
      identical(
        ref.read(contentAccessContextProvider(access.key)),
        access,
      );

  Future<bool> _download(Post post, ContentAccessContext access) async {
    if (!_current(access)) return false;
    final config = access.config!;
    final params = ref.read(
      sourceDownloadNotifierParamsProvider((config.auth, config.download)),
    );
    try {
      return await ref
              .read(downloadNotifierProvider(params).notifier)
              .download(
                post,
                isCurrent: () => _current(access) && !_cancel,
              ) !=
          null;
    } catch (error, stack) {
      ref
          .read(loggerProvider)
          .handledError(
            'Media',
            'work_page_download',
            error: error,
            stackTrace: stack,
            outcome: 'not_queued',
          );
      return false;
    }
  }

  Future<void> _downloadAll(MediaGroupState captured) async {
    final access = captured.access;
    final key = captured.loadKey;
    if (_downloading || access == null || key == null || !_current(access)) {
      return;
    }
    setState(() {
      _downloading = true;
      _cancel = false;
      _queued = 0;
      _total = 0;
      _incomplete = false;
    });
    try {
      var state = captured.members;
      var batches = 0;
      while (state?.next != null &&
          state!.members.length < 5000 &&
          batches++ < 128 &&
          !_cancel &&
          _current(access)) {
        await ref.read(groupMembersProvider(key).notifier).loadNext();
        final next = ref.read(groupMembersProvider(key)).valueOrNull;
        if (next == null ||
            next.nextPageError != null ||
            next.members.length <= state.members.length) {
          break;
        }
        state = next;
      }
      if (!_current(access) || _cancel || state == null) return;
      final posts = <Post>[
        for (final member in state.members.take(5000))
          if (member.availability == MemberAvailability.available)
            if (state.resolved[member.reference.identity] case PostContentEntry(
              :final post,
            ))
              post,
      ];
      setState(() {
        _total = state!.sourceTotal ?? state.members.length;
        _incomplete =
            posts.length != _total ||
            state.next != null ||
            state.nextPageError != null;
      });
      for (final post in posts) {
        if (_cancel || !_current(access)) break;
        final queued = await _download(post, access);
        if (!mounted) return;
        setState(() {
          if (queued) {
            _queued++;
          } else {
            _incomplete = true;
          }
        });
      }
    } catch (error, stack) {
      if (!mounted) return;
      ref
          .read(loggerProvider)
          .handledError(
            'Media',
            'work_download_all',
            error: error,
            stackTrace: stack,
            outcome: 'incomplete',
          );
      setState(() => _incomplete = true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!NavigationActivity.of(context)) return widget.child;
    final state = ref.watch(mediaGroupProvider(widget.entry));
    final presentation = ref
        .watch(
          booruGroupCapabilityProvider(widget.entry.contentReference.engine),
        )
        ?.presentation;
    final bookmarks = presentation is BooruMediaGroupBookmarkPresentation
        ? presentation as BooruMediaGroupBookmarkPresentation
        : null;
    final access = state.access;
    final bookmarkData = access == null
        ? null
        : GroupBookmarkPresentationData(
            access: access,
            summary: state.details?.summary ?? widget.entry.summary,
            details: state.details ?? widget.entry.storedDetails,
            page: InheritedPost.maybeOf<Post>(context),
          );
    final strings = context.t.content_viewer;
    final download = _downloading
        ? () => setState(() => _cancel = true)
        : state.access == null
        ? null
        : () => _downloadAll(state);
    return GroupLinkShareButton(
      builder: (context, share) => PostActionToolbarScope(
        bookmarkButton: bookmarks == null || bookmarkData == null
            ? null
            : bookmarks.buildBookmarkButton(context, bookmarkData),
        additionalButtons: [
          if (bookmarks != null && bookmarkData != null)
            ...bookmarks.buildBookmarkMenuButtons(context, bookmarkData),
          ButtonData(
            title: context.linkFileLabel,
            icon: const Icon(Icons.share),
            widget: const SizedBox.shrink(),
            onTap: share,
            enabled: share != null,
            placement: ButtonPlacement.menuOnly,
          ),
          ButtonData(
            title: _downloading
                ? strings.download_progress(queued: _queued, total: _total)
                : _incomplete
                ? strings.download_incomplete
                : strings.download_all,
            icon: Icon(
              _downloading
                  ? Icons.cancel_outlined
                  : Icons.download_for_offline_outlined,
            ),
            widget: const SizedBox.shrink(),
            onTap: download,
            enabled: download != null,
            placement: ButtonPlacement.menuOnly,
          ),
        ],
        child: widget.child,
      ),
    );
  }
}

/// Summary-only actions use the existing row without inventing a current Post.
class MediaGroupSummaryActions extends StatelessWidget {
  const MediaGroupSummaryActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = PostActionToolbarScope.maybeOf(context);
    final bookmark = actions?.bookmarkButton;
    return SliverToBoxAdapter(
      child: bookmark == null
          ? const SizedBox.shrink()
          : BooruMenuButtonRow(
              buttons: [
                ButtonData(
                  required: true,
                  widget: bookmark,
                  title: context.t.post.action.bookmark,
                  icon: const Icon(Icons.bookmark_border),
                ),
                ...actions!.additionalButtons,
              ],
            ),
    );
  }
}
