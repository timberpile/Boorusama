import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import 'following_topic_profile_caption.dart';

import '../../../../configs/config/types.dart';
import '../types/search_refresh.dart';
import '../types/following_topic.dart';
import '../types/following_topic_repository.dart';

typedef FollowingTopicEditResult = ({
  FollowingTopic topic,
  SearchRefreshOutcome? refresh,
});
typedef SaveFollowingTopicEdit = Future<FollowingTopicEditResult> Function(
  BooruConfig? profile,
  String query,
  String? name,
  bool autoUpdateEnabled,
  SearchQueryStructure? queryStructure,
);

Future<FollowingTopicEditResult?> showEditFollowingTopicDialog(
  BuildContext context, {
  required FollowingTopic topic,
  required List<BooruConfig> profiles,
  BooruConfig? sourceConfig,
  required bool Function(BooruConfigAuth) trackingSupported,
  required SaveFollowingTopicEdit onSave,
}) => showDialog<FollowingTopicEditResult>(
  context: context,
  barrierDismissible: false,
  builder: (_) => EditFollowingTopicDialog(
    topic: topic,
    profiles: profiles,
    sourceConfig: sourceConfig,
    trackingSupported: trackingSupported,
    onSave: onSave,
  ),
);

class EditFollowingTopicDialog extends StatefulWidget {
  const EditFollowingTopicDialog({
    required this.topic,
    required this.profiles,
    this.sourceConfig,
    required this.trackingSupported,
    required this.onSave,
    super.key,
  });
  final FollowingTopic topic;
  final List<BooruConfig> profiles;
  final BooruConfig? sourceConfig;
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
  late final _query = TextEditingController(text: widget.topic.query);
  bool get _portable => widget.topic.localSource?.isImported ?? false;
  late bool _autoUpdateEnabled = widget.topic.autoUpdateEnabled;
  String? _error;
  var _saving = false;
  late String? _profileId =
      widget.profiles.any((p) => p.id == widget.topic.profileId)
      ? widget.topic.profileId
      : widget.sourceConfig?.id;
  late final _recoveringProfile = _profileId == null;
  BooruConfig? get _profile =>
      widget.profiles.where((p) => p.id == _profileId).firstOrNull ??
      (widget.sourceConfig?.id == _profileId ? widget.sourceConfig : null);

  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<FollowingTopicEditResult> _persist(
    String query,
    SearchQueryStructure? structure,
  ) => widget.onSave(
    _portable ? null : _profile,
    query,
    _name.text,
    _autoUpdateEnabled,
    structure,
  );

  Future<void> _save() async {
    if (_saving || (!_portable && _profile == null)) return;
    final query = _portable ? _query.text.trim() : widget.topic.query;
    if (normalizeSearchIdentity(query).isEmpty) {
      setState(() => _error = context.t.following_topics.edit_invalid_query);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _persist(
        query,
        query == widget.topic.query ? widget.topic.queryStructure : null,
      );
      if (mounted) Navigator.pop(context, result);
    } on DuplicateFollowingTopicException {
      if (mounted) {
        setState(() => _error = context.t.following_topics.edit_duplicate);
      }
    } on MissingFollowingTopicProfileException {
      if (mounted) {
        setState(
          () => _error = context.t.following_topics.edit_missing_profile,
        );
      }
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
        (selected == null && _portable
            ? strings.imported_source_unavailable(
                site: widget.topic.localSource!.url,
              )
            : selected == null
            ? strings.edit_missing_profile
            : !widget.trackingSupported(selected.auth)
            ? strings.edit_unsupported
            : null);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: KurumiDialog(
          width: 460,
          screenInset: 16,
          dismissible: false,
          semanticLabel: strings.edit_title,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.edit_title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: _saving,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      if (_portable) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _query,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: strings.edit_query,
                          ),
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ],
                      if (!_portable &&
                          _recoveringProfile &&
                          widget.profiles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(strings.edit_profile),
                        const SizedBox(height: 4),
                        KurumiOptionDropDownButton<String?>(
                          value: _profileId,
                          alignment: AlignmentDirectional.centerStart,
                          selectedItemBuilder: (id) {
                            final profile = widget.profiles
                                .where((p) => p.id == id)
                                .firstOrNull;
                            return profile == null
                                ? Text(strings.edit_profile)
                                : FollowingTopicProfileOption(profile: profile);
                          },
                          items: [
                            for (final profile in widget.profiles)
                              DropdownMenuItem<String?>(
                                value: profile.id,
                                child: FollowingTopicProfileOption(
                                  profile: profile,
                                ),
                              ),
                          ],
                          onChanged: (id) => setState(() {
                            _profileId = id;
                            _error = null;
                          }),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(strings.auto_update_topic),
                        value: _autoUpdateEnabled,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _autoUpdateEnabled = value),
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
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: Text(context.t.generic.action.cancel),
                    ),
                    FilledButton(
                      onPressed: _saving || (!_portable && selected == null)
                          ? null
                          : _save,
                      child: Text(strings.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
