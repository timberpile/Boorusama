// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// Project imports:
import '../../../../../foundation/filesystem.dart';
import 'sidecar_store.dart';
import '../types/sidecar_result.dart';

final sidecarStoreProvider = FutureProvider<SidecarStore>((ref) async {
  final container = ref.container;
  final fs = ref.watch(appFileSystemProvider);
  final storagePath = await fs.getAppStoragePath();
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return SidecarStore(
    directory: p.join(storagePath, 'download-sidecars'),
    fs: fs,
    onChanged: () {
      // This notifies a dependent; it must not declare a dependency back to it.
      if (!disposed) container.invalidate(sidecarFailuresProvider);
    },
  );
}, name: 'sidecarStoreProvider');

final sidecarRecoveryProvider = FutureProvider<void>((ref) async {
  final store = await ref.watch(sidecarStoreProvider.future);
  await store.recover();
}, name: 'sidecarRecoveryProvider');

final AutoDisposeFutureProvider<List<SidecarFailure>> sidecarFailuresProvider =
    FutureProvider.autoDispose<List<SidecarFailure>>((ref) async {
      final store = await ref.watch(sidecarStoreProvider.future);
      return store.failures();
    }, name: 'sidecarFailuresProvider');
