import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../providers/settings_notifier.dart';
import '../providers/settings_provider.dart';
import '../types/viewer_toolbar_layout.dart';
import '../widgets/viewer_toolbar_editor.dart';

class ViewerToolbarLayoutPage extends ConsumerStatefulWidget {
  const ViewerToolbarLayoutPage({super.key});

  @override
  ConsumerState<ViewerToolbarLayoutPage> createState() => _ViewerToolbarLayoutPageState();
}

class _ViewerToolbarLayoutPageState extends ConsumerState<ViewerToolbarLayoutPage> {
  late final ViewerToolbarLayout? _initial;
  late ViewerToolbarLayout _draft;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initial = ref.read(settingsProvider).viewerToolbarLayout;
    _draft = _initial ?? ViewerToolbarLayout.editorDefault();
  }

  Future<void> _save(ViewerToolbarLayout? value) async {
    if (_saving) return;
    setState(() { _saving = true; _failed = false; });
    try {
      final saved = await ref.read(settingsNotifierProvider.notifier).updateWith((current) {
        // Do not overwrite a newer import/editor result, or unrelated settings.
        if (current.viewerToolbarLayout != _initial) {
          throw StateError('Viewer toolbar changed while editing');
        }
        return current.copyWith(viewerToolbarLayout: () => value);
      });
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop();
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: KurumiAppBar(
      title: Text(context.t.post.detail.widgets.toolbar),
      actions: [IconButton(
        key: const Key('toolbar-apply'),
        tooltip: context.t.generic.action.apply,
        onPressed: !_saving && _draft != _initial ? () => _save(_draft) : null,
        icon: const Icon(Icons.check),
      )],
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_saving) const LinearProgressIndicator(),
          if (_failed) Padding(
            padding: const EdgeInsets.all(12),
            child: Text(context.t.post.action.operation_failed,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          IgnorePointer(
            ignoring: _saving,
            child: ViewerToolbarEditor(layout: _draft,
              onChanged: (value) => setState(() => _draft = value)),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: OutlinedButton.icon(
              key: const Key('toolbar-reset'),
              onPressed: _saving ? null : () => _save(null),
              icon: const Icon(Icons.restart_alt),
              label: Text(context.t.generic.action.reset),
            )),
        ]),
      ),
    ),
  );
}
