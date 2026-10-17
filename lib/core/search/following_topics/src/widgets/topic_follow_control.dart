import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../providers/following_topic_selectors.dart';
import '../providers/following_topics_notifier.dart';
import '../types/following_topic.dart';
import '../types/search_refresh.dart';
import 'follow_topic_folder_picker.dart';
import 'search_folder_dialog.dart';

class FollowTopicButton extends ConsumerStatefulWidget {
  const FollowTopicButton({
    required this.query,
    this.queryStructure,
    this.originatingTopicId,
    this.compact = false,
    this.onFeedback,
    super.key,
  });

  final String query;
  final SearchQueryStructure? queryStructure;
  final String? originatingTopicId;
  final bool compact;
  final ValueChanged<String?>? onFeedback;

  @override
  ConsumerState<FollowTopicButton> createState() => _FollowTopicButtonState();
}

class _FollowTopicButtonState extends ConsumerState<FollowTopicButton> {
  var _busy = false;
  var _operationRevision = 0;

  @override
  void didUpdateWidget(covariant FollowTopicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.originatingTopicId != widget.originatingTopicId) {
      _operationRevision++;
      _busy = false;
      widget.onFeedback?.call(null);
    }
  }

  Future<void> _open() async {
    final revision = ++_operationRevision;
    final profileId = ref.readConfig.id;
    final query = widget.query;
    setState(() => _busy = true);
    widget.onFeedback?.call(null);
    try {
      await showTopicFollowFlow(
        context,
        ref,
        profileId: profileId,
        query: query,
        queryStructure: widget.queryStructure,
        originatingTopicId: widget.originatingTopicId,
        onFeedback: (message) {
          if (mounted &&
              revision == _operationRevision &&
              ref.readConfig.id == profileId &&
              widget.query == query) {
            widget.onFeedback?.call(message);
          }
        },
      );
    } finally {
      if (mounted && revision == _operationRevision) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) return const SizedBox.shrink();
    final profileId = ref.watchConfig.id;
    final topics = ref.watch(followingTopicsProvider);
    final matches = ref.watch(
      matchingFollowingTopicsProvider((
        profileId: profileId,
        query: widget.query,
      )),
    );
    return TopicFollowPill(
      count: matches.valueOrNull?.length ?? 0,
      compact: widget.compact,
      busy: _busy || topics.isLoading,
      onPressed: _busy || !topics.hasValue ? null : _open,
    );
  }
}

class TopicFollowPill extends StatelessWidget {
  const TopicFollowPill({
    required this.count,
    required this.onPressed,
    this.compact = false,
    this.busy = false,
    super.key,
  });

  final int count;
  final bool compact;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final following = count > 0;
    final label = following ? strings.following : strings.follow;
    final icon = busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Symbols.rss_feed, size: 20);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(width: compact ? 4 : 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (following) ...[
          SizedBox(width: compact ? 4 : 8),
          Badge(label: Text('$count')),
        ],
      ],
    );
    return Semantics(
      button: true,
      label: following ? '$label, $count' : label,
      child: Tooltip(
        message: label,
        child: following
            ? FilledButton.tonal(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size(64, 48),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                ),
                child: child,
              )
            : FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size(64, 48),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                ),
                child: child,
              ),
      ),
    );
  }
}

Future<void> showTopicFollowFlow(
  BuildContext context,
  WidgetRef ref, {
  required String profileId,
  required String query,
  SearchQueryStructure? queryStructure,
  String? originatingTopicId,
  String? initialFolderId,
  ValueChanged<String?>? onFeedback,
}) async {
  final state = ref.read(followingTopicsProvider).valueOrNull;
  if (state == null) return;
  final matches = selectMatchingFollowingTopics(
    state,
    profileId: profileId,
    query: query,
  );
  final previousDestinations = {for (final match in matches) match.folderId};
  final initialDestinations = matches.isEmpty
      ? initialFolderId == null
            ? <String?>{}
            : <String?>{initialFolderId}
      : previousDestinations;
  final selectedDestinations = await showFollowTopicFolderPickerDialog(
    context,
    query: query,
    selectedFolderIds: initialDestinations,
    onCreateFolder: (parentId) async {
      final name = await showSearchFolderNameDialog(context);
      if (name == null || !context.mounted) return null;
      return ref
          .read(followingTopicsProvider.notifier)
          .createSharedFolder(name, parentId: parentId);
    },
  );
  if (selectedDestinations == null || !context.mounted) return;
  try {
    final notifier = ref.read(followingTopicsProvider.notifier);
    final result = await notifier.setFollowDestinations(
      profileId: profileId,
      query: query,
      queryStructure: queryStructure,
      folderIds: selectedDestinations,
    );
    onFeedback?.call(null);
    if (_trackingSupported(ref, profileId)) {
      for (final topic in result.added) {
        unawaited(
          notifier.refresh(topic.id).then((outcome) {
            if (outcome is SearchRefreshFailed && context.mounted) {
              onFeedback?.call(context.t.following_topics.snapshot_failed);
            }
          }),
        );
      }
    }
    if (result.removed.isNotEmpty && context.mounted) {
      Kurumi.showSuccessToast(
        context,
        context.t.following_topics.unfollowed,
        duration: const Duration(seconds: 5),
        actionLabel: context.t.following_topics.undo,
        onAction: () async {
          try {
            await notifier.setFollowDestinations(
              profileId: profileId,
              query: query,
              queryStructure: queryStructure,
              name: result.removed.first.name,
              folderIds: previousDestinations,
            );
          } catch (_) {
            if (context.mounted) {
              Kurumi.showErrorToast(
                context,
                context.t.following_topics.undo_failed,
              );
            }
          }
        },
      );
    }
  } catch (_) {
    if (context.mounted) {
      onFeedback?.call(context.t.following_topics.save_failed);
    }
  }
}

bool _trackingSupported(WidgetRef ref, String profileId) {
  final profile = ref
      .read(booruConfigProvider)
      .where((profile) => profile.id == profileId)
      .firstOrNull;
  return profile != null &&
      ref.read(followingTopicTrackingSupportedProvider(profile.auth));
}

/// Compatibility entry point for callers that only own a BuildContext.
Future<void> showTopicFolderFollowDialog(
  BuildContext context, {
  required String profileId,
  required String query,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final state = container.read(followingTopicsProvider).valueOrNull;
  if (state == null) return;
  final matches = selectMatchingFollowingTopics(
    state,
    profileId: profileId,
    query: query,
  );
  final previousDestinations = {for (final match in matches) match.folderId};
  final selectedDestinations = await showFollowTopicFolderPickerDialog(
    context,
    query: query,
    selectedFolderIds: matches.isEmpty ? {} : previousDestinations,
    onCreateFolder: (parentId) async {
      final name = await showSearchFolderNameDialog(context);
      if (name == null || !context.mounted) return null;
      return container
          .read(followingTopicsProvider.notifier)
          .createSharedFolder(name, parentId: parentId);
    },
  );
  if (selectedDestinations == null || !context.mounted) return;
  final notifier = container.read(followingTopicsProvider.notifier);
  final result = await notifier.setFollowDestinations(
    profileId: profileId,
    query: query,
    folderIds: selectedDestinations,
  );
  if (result.added.isNotEmpty) {
    final profile = container
        .read(booruConfigProvider)
        .where((value) => value.id == profileId)
        .firstOrNull;
    if (profile != null &&
        container.read(followingTopicTrackingSupportedProvider(profile.auth))) {
      for (final topic in result.added) {
        unawaited(notifier.refresh(topic.id));
      }
    }
  }
  if (result.removed.isNotEmpty && context.mounted) {
    Kurumi.showSuccessToast(
      context,
      context.t.following_topics.unfollowed,
      duration: const Duration(seconds: 5),
      actionLabel: context.t.following_topics.undo,
      onAction: () => notifier.setFollowDestinations(
        profileId: profileId,
        query: query,
        name: result.removed.first.name,
        folderIds: previousDestinations,
      ),
    );
  }
}
