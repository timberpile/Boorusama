import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/types.dart';
import '../providers/search_subscriptions_notifier.dart';

Future<int?> showBulkSearchImportDialog(
  BuildContext context, {
  required String destination,
  required Future<int> Function(int? profileId, String rawQueries) onAdd,
  List<BooruConfig> profiles = const [],
  int? initialProfileId,
}) => showDialog<int>(
  context: context,
  builder: (_) => BulkSearchImportDialog(
    destination: destination,
    onAdd: onAdd,
    profiles: profiles,
    initialProfileId: initialProfileId,
  ),
);

class BulkSearchImportDialog extends StatefulWidget {
  const BulkSearchImportDialog({
    required this.destination,
    required this.onAdd,
    this.profiles = const [],
    this.initialProfileId,
    super.key,
  });

  final String destination;
  final Future<int> Function(int? profileId, String rawQueries) onAdd;
  final List<BooruConfig> profiles;
  final int? initialProfileId;

  @override
  State<BulkSearchImportDialog> createState() => _BulkSearchImportDialogState();
}

class _BulkSearchImportDialogState extends State<BulkSearchImportDialog> {
  final _queries = TextEditingController();
  late int? _profileId =
      widget.profiles.any(
        (profile) => profile.id == widget.initialProfileId,
      )
      ? widget.initialProfileId
      : widget.profiles.firstOrNull?.id;
  var _saving = false;
  var _failed = false;

  @override
  void dispose() {
    _queries.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final count = await widget.onAdd(_profileId, _queries.text);
      if (mounted) Navigator.pop(context, count);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    return AlertDialog(
      title: Text(strings.bulk_add),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.bulk_destination.replaceAll(
                  '{destination}',
                  widget.destination,
                ),
              ),
              if (widget.profiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _profileId,
                  decoration: InputDecoration(labelText: strings.bulk_profile),
                  items: [
                    for (final profile in widget.profiles)
                      DropdownMenuItem(
                        value: profile.id,
                        child: Text(
                          profile.name.isEmpty ? profile.url : profile.name,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _profileId = value),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _queries,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: strings.bulk_queries,
                  hintText: strings.bulk_queries_hint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _failed = false),
              ),
              if (_failed) ...[
                const SizedBox(height: 8),
                Text(
                  strings.bulk_failed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          onPressed:
              _saving ||
                  (widget.profiles.isNotEmpty && _profileId == null) ||
                  parseBulkSearchQueries(_queries.text).isEmpty
              ? null
              : _add,
          child: Text(strings.bulk_add),
        ),
      ],
    );
  }
}
