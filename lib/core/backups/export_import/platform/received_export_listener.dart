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
      (export) => unawaited(_openWhenNavigatorIsReady(export.path)),
    );
  }

  Future<void> _openWhenNavigatorIsReady(String path) async {
    while (mounted) {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        await navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => ImportFlowPage(packagePath: path),
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
