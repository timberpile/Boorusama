import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/types.dart';
import '../types/search_refresh.dart';
import '../types/following_topic.dart';
import '../types/following_topic_repository.dart';

typedef FollowingTopicEditResult = ({
  FollowingTopic topic,
  SearchRefreshOutcome? refresh,
});
typedef SaveFollowingTopicEdit = Future<FollowingTopicEditResult> Function(
  BooruConfig profile,
  String query,
  String? name,
  bool autoUpdateEnabled,
  SearchQueryStructure? queryStructure,
);

Future<FollowingTopicEditResult?> showEditFollowingTopicDialog(
  BuildContext context, {
  required FollowingTopic topic,
  required List<BooruConfig> profiles,
  required bool Function(BooruConfigAuth) trackingSupported,
  required SaveFollowingTopicEdit onSave,
}) => showDialog<FollowingTopicEditResult>(
  context: context,
  barrierDismissible: false,
  builder: (_) => EditFollowingTopicDialog(
    topic: topic,
    profiles: profiles,
    trackingSupported: trackingSupported,
    onSave: onSave,
  ),
);

class EditFollowingTopicDialog extends StatefulWidget {
  const EditFollowingTopicDialog({
    required this.topic,
    required this.profiles,
    required this.trackingSupported,
    required this.onSave,
    super.key,
  });
  final FollowingTopic topic;
  final List<BooruConfig> profiles;
  final bool Function(BooruConfigAuth) trackingSupported;
  final SaveFollowingTopicEdit onSave;
  @override
  State<EditFollowingTopicDialog> createState() =>
      _EditFollowingTopicDialogState();
}

class _EditFollowingTopicDialogState extends State<EditFollowingTopicDialog> {
  late final _name = TextEditingController(
    text: widget.topic.name,
  );
  late bool _autoUpdateEnabled = widget.topic.autoUpdateEnabled;
  String? _error;
  var _saving = false;
  BooruConfig? get _profile =>
      widget.profiles.where((p) => p.id == widget.topic.profileId).firstOrNull;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<FollowingTopicEditResult> _persist(
    String query,
    SearchQueryStructure? structure,
  ) => widget.onSave(
    _profile!,
    query,
    _name.text,
    _autoUpdateEnabled,
    structure,
  );

  Future<void> _save() async {
    if (_saving || _profile == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _persist(
        widget.topic.query,
        widget.topic.queryStructure,
      );
      if (mounted) Navigator.pop(context, result);
    } on DuplicateFollowingTopicException {
      if (mounted) {
        setState(() => _error = context.t.following_topics.edit_duplicate);
      }
    } on MissingFollowingTopicProfileException {
      if (mounted)
        setState(
          () => _error = context.t.following_topics.edit_missing_profile,
        );
    } on StaleFollowingTopicEditException {
      if (mounted) {
        setState(() => _error = context.t.following_topics.edit_conflict);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.t.following_topics.save_failed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final selected = _profile;
    final warning =
        _error ??
        (selected == null
            ? strings.edit_missing_profile
            : !widget.trackingSupported(selected.auth)
            ? strings.edit_unsupported
            : null);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(strings.edit_title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: AbsorbPointer(
              absorbing: _saving,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: strings.edit_name,
                      hintText: strings.edit_name_hint,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.auto_update_topic),
                    value: _autoUpdateEnabled,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _autoUpdateEnabled = value),
                  ),
                  if (warning != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      warning,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: _saving || selected == null ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}
