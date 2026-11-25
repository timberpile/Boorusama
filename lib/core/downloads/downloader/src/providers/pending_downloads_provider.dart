import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../download_manager/providers.dart';
import '../../../../download_manager/types.dart';
import '../../../background/types.dart';
import '../types/metadata.dart';

final pendingDownloadsProvider = Provider((ref) {
  final claims = PendingDownloadClaims();
  void observe(TaskUpdate update) {
    final terminal = isTerminalDownloadUpdate(update);
    // A trailing progress event can replace the last status in the snapshot.
    // Only the status event releases a live claim.
    if (terminal && update is TaskProgressUpdate) return;
    final metadata = update.task.metaData;
    if (metadata.isEmpty) return;
    final id = DownloaderMetadata.fromJsonString(metadata).admissionId;
    if (id == null) return;
    claims.observe(
      id,
      update.task.taskId,
      terminal: terminal,
    );
  }

  for (final group in ref.read(downloadTaskUpdatesProvider).tasks.values) {
    group.forEach(observe);
  }
  final subscription = ref
      .read(downloadTaskStreamControllerProvider)
      .stream
      .listen(observe);
  ref.onDispose(subscription.cancel);
  return claims;
});

bool isTerminalDownloadUpdate(TaskUpdate update) => switch (update) {
  TaskStatusUpdate(:final status) => status.isFinalState,
  TaskProgressUpdate(
    progress: progressComplete ||
        progressFailed ||
        progressCanceled ||
        progressNotFound,
  ) =>
    true,
  _ => false,
};

class PendingDownloadClaims {
  final _preparing = <String>{};
  final _active = <String, String>{};

  bool claim(String id) => !_active.containsKey(id) && _preparing.add(id);

  void observe(String id, String taskId, {required bool terminal}) {
    if (!terminal) {
      _active[id] = taskId;
    } else if (_active[id] == taskId) {
      _active.remove(id);
    }
  }

  void release(String id) => _preparing.remove(id);
}
