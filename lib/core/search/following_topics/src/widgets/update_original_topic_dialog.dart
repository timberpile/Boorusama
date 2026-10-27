import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../search/src/types/topic_search_origin.dart';
import '../providers/following_topics_notifier.dart';
import '../types/following_topic.dart';
import '../types/following_topic_repository.dart';
import '../types/search_refresh.dart';

Future<TopicSearchOrigin?> showUpdateOriginalTopicDialog(
  BuildContext context, {
  required TopicSearchOrigin original,
  required BooruConfig profile,
  required String query,
  required SearchQueryStructure? structure,
  required ValueChanged<String?> onFeedback,
}) => showDialog<TopicSearchOrigin>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _UpdateOriginalTopicDialog(
    original: original,
    profile: profile,
    query: query,
    structure: structure,
    onFeedback: onFeedback,
  ),
);

class _UpdateOriginalTopicDialog extends ConsumerStatefulWidget {
  const _UpdateOriginalTopicDialog({
    required this.original,
    required this.profile,
    required this.query,
    required this.structure,
    required this.onFeedback,
  });
  final TopicSearchOrigin original;
  final BooruConfig profile;
  final String query;
  final SearchQueryStructure? structure;
  final ValueChanged<String?> onFeedback;

  @override
  ConsumerState<_UpdateOriginalTopicDialog> createState() =>
      _UpdateOriginalTopicDialogState();
}

class _UpdateOriginalTopicDialogState
    extends ConsumerState<_UpdateOriginalTopicDialog> {
  var _saving = false;
  String? _error;

  Future<void> _update() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final strings = context.t.following_topics;
    try {
      final profile = ref
          .read(booruConfigProvider)
          .where((p) => p.id == widget.profile.id)
          .firstOrNull;
      if (profile == null || profile.auth != widget.profile.auth) {
        throw MissingFollowingTopicProfileException();
      }
      if (widget.query.trim().isEmpty) throw ArgumentError('Empty topic query');
      final notifier = ref.read(followingTopicsProvider.notifier);
      final original = widget.original.topic;
      final saved = await notifier.editLocally(
        original.id,
        profileId: profile.id,
        query: widget.query,
        queryStructure: () => widget.structure,
        name: original.name,
        autoUpdateEnabled: original.autoUpdateEnabled,
        expectedTopic: original,
      );
      // Saving is complete before a separate baseline refresh starts.
      if (saved.material) {
        unawaited(
          notifier
              .refresh(original.id)
              .then<void>(
                (outcome) {
                  if (outcome case SearchRefreshFailed(:final kind)
                      when kind != SearchRefreshErrorKind.unsupported) {
                    widget.onFeedback(strings.edit_baseline_failed);
                  }
                },
                onError: (Object _, StackTrace _) {
                  widget.onFeedback(strings.edit_baseline_failed);
                },
              ),
        );
      }
      if (mounted) {
        Navigator.pop(
          context,
          TopicSearchOrigin(topic: saved.topic, profile: profile),
        );
      }
    } on DuplicateFollowingTopicException {
      if (mounted) setState(() => _error = strings.edit_duplicate);
    } on MissingFollowingTopicProfileException {
      if (mounted) setState(() => _error = strings.edit_missing_profile);
    } on StaleFollowingTopicEditException {
      if (mounted) setState(() => _error = strings.edit_conflict);
    } catch (_) {
      if (mounted) setState(() => _error = strings.save_failed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final original = widget.original;
    final organization = ref
        .watch(followingTopicsProvider)
        .valueOrNull
        ?.organization;
    final placement = organization?.placements
        .where((p) => p.itemId == original.topic.id)
        .firstOrNull;
    final tree = organization?.tree;
    final folderPath = placement == null
        ? strings.no_folder
        : placement.folderId == null
        ? context.t.folders.home
        : tree?.byId.containsKey(placement.folderId) ?? false
        ? tree!.path(placement.folderId)
        : strings.no_folder;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(strings.original_update_title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                original.topic.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                folderPath,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _query(
                context,
                strings.original_current_query,
                original.topic.query,
              ),
              const SizedBox(height: 12),
              _query(context, strings.original_new_query, widget.query),
              if (original.topic.profileId != widget.profile.id) ...[
                const SizedBox(height: 12),
                Text(
                  strings.original_current_profile(
                    profile: original.profile.name,
                  ),
                ),
                Text(
                  strings.original_new_profile(profile: widget.profile.name),
                ),
              ],
              const SizedBox(height: 12),
              Text(strings.original_update_explanation),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _update,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.edit_update),
          ),
        ],
      ),
    );
  }

  Widget _query(BuildContext context, String label, String query) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(query),
      ),
    ],
  );
}
