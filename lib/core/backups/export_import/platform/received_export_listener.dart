import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../../foundation/filesystem.dart';
import '../../../router.dart';
import '../import/import_flow_page.dart';
import 'received_export_service.dart';

class ReceivedExportListener extends ConsumerStatefulWidget {
  const ReceivedExportListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReceivedExportListener> createState() =>
      _ReceivedExportListenerState();
}

class _ReceivedExportListenerState
    extends ConsumerState<ReceivedExportListener> {
  StreamSubscription<ReceivedExport>? _subscription;
  final _pending = <ReceivedExport>[];
  var _opening = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_listen);
  }

  Future<void> _listen() async {
    final service = await ReceivedExportService.create(
      fs: ref.read(appFileSystemProvider),
    );
    if (!mounted) return;
    _subscription = service.exports.listen(
      _enqueue,
    );
  }

  void _enqueue(ReceivedExport export) {
    _pending.add(export);
    if (!_opening) unawaited(_drain());
  }

  Future<void> _drain() async {
    _opening = true;
    try {
      while (mounted && _pending.isNotEmpty) {
        final export = _pending.removeAt(0);
        while (mounted && navigatorKey.currentState == null) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final navigator = navigatorKey.currentState;
        if (!mounted || navigator == null) break;
        await navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => ImportFlowPage(
              packagePath: export.path,
              disposeInput: () => _deleteReceivedFile(export.path),
            ),
          ),
        );
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _deleteReceivedFile(String path) async {
    final fs = ref.read(appFileSystemProvider);
    if (await fs.fileExists(path)) await fs.deleteFile(path);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    for (final export in _pending) {
      unawaited(_deleteReceivedFile(export.path));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
