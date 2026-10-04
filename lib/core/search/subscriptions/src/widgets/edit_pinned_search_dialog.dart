import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/types.dart';
import '../types/search_refresh.dart';
import '../types/search_subscription.dart';
import '../types/search_subscription_repository.dart';
import 'pinned_search_profile_caption.dart';

Future<({SearchSubscription subscription, SearchRefreshOutcome? refresh})?>
showEditPinnedSearchDialog(
  BuildContext context, {
  required SearchSubscription subscription,
  required List<BooruConfig> profiles,
  required bool Function(BooruConfigAuth) trackingSupported,
  required Future<
    ({SearchSubscription subscription, SearchRefreshOutcome? refresh})
  >
  Function(String profileId, String query, String? name)
  onSave,
}) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => EditPinnedSearchDialog(
    subscription: subscription,
    profiles: profiles,
    trackingSupported: trackingSupported,
    onSave: onSave,
  ),
);

class EditPinnedSearchDialog extends StatefulWidget {
  const EditPinnedSearchDialog({
    required this.subscription,
    required this.profiles,
    required this.trackingSupported,
    required this.onSave,
    super.key,
  });

  final SearchSubscription subscription;
  final List<BooruConfig> profiles;
  final bool Function(BooruConfigAuth) trackingSupported;
  final Future<
    ({SearchSubscription subscription, SearchRefreshOutcome? refresh})
  >
  Function(String profileId, String query, String? name)
  onSave;

  @override
  State<EditPinnedSearchDialog> createState() => _EditPinnedSearchDialogState();
}

enum _EditError { duplicate, missingProfile, saveFailed }

class _EditPinnedSearchDialogState extends State<EditPinnedSearchDialog> {
  late final _name = TextEditingController(text: widget.subscription.name);
  late final _query = TextEditingController(text: widget.subscription.query);
  late String? _profileId = widget.subscription.profileId;
  _EditError? _error;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profileId = _profileId;
    if (profileId == null ||
        !widget.profiles.any((profile) => profile.id == profileId)) {
      setState(() => _error = _EditError.missingProfile);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onSave(profileId, _query.text, _name.text);
      if (mounted) {
        setState(() => _saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, result);
      }
    } on DuplicatePinnedSearchException {
      if (mounted) setState(() => _error = _EditError.duplicate);
    } on MissingPinnedSearchProfileException {
      if (mounted) setState(() => _error = _EditError.missingProfile);
    } catch (_) {
      if (mounted) setState(() => _error = _EditError.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    final selected = widget.profiles
        .where((profile) => profile.id == _profileId)
        .firstOrNull;
    final warning = switch (_error) {
      _EditError.duplicate => strings.edit_duplicate,
      _EditError.missingProfile => strings.edit_missing_profile,
      _EditError.saveFailed => strings.save_failed,
      null when selected == null => strings.edit_missing_profile,
      null when selected != null && !widget.trackingSupported(selected.auth) =>
        strings.edit_unsupported,
      null => null,
    };
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(strings.edit_title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
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
                TextField(
                  controller: _query,
                  decoration: InputDecoration(labelText: strings.edit_query),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selected?.id,
                  decoration: InputDecoration(labelText: strings.edit_profile),
                  items: [
                    for (final profile in widget.profiles)
                      DropdownMenuItem(
                        value: profile.id,
                        child: Text(
                          pinnedSearchProfileCaption(profile, widget.profiles),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _profileId = value;
                          _error = null;
                        }),
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
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: _saving || _query.text.trim().isEmpty ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}
