import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../foundation/loggers.dart';
import '../../../foundation/platform.dart';
import '../../cache/misc_data_store.dart';
import '../../bookmarks/providers.dart';
import '../../search/following_topics/providers.dart';
import 'app_port.dart';
import 'mirror_guard.dart';
import 'service.dart';
import 'storage.dart';

final folderSyncServiceProvider = Provider<FolderSyncService>((ref) {
  final service = FolderSyncService(
    metadata: _LocalMetadata(ref.watch(miscDataStoreProvider)),
    port: AppSyncCollectionPort(ref),
    storageFor: (location) => isAndroid()
        ? AndroidFolderSyncStorage(location)
        : DirectoryFolderSyncStorage(location),
    bindingsChanged: ref.watch(collectionMirrorGuardProvider).replaceBindings,
    followingBindingsChanged: ref
        .watch(collectionMirrorGuardProvider)
        .replaceFollowingBindings,
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final folderSyncStateProvider =
    StreamProvider<({FolderSyncService service, int revision})>((ref) async* {
      var revision = 0;
      final service = ref.watch(folderSyncServiceProvider);
      await service.initialize();
      yield (service: service, revision: revision++);
      await for (final _ in service.changes) {
        yield (service: service, revision: revision++);
      }
    });

final class _LocalMetadata implements FolderSyncMetadataStore {
  const _LocalMetadata(this.store);
  final MiscDataStore store;
  @override
  Future<Map<String, dynamic>> load() async {
    final value = store.get(folderSyncMetadataKey);
    return value == null ? {} : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> value) =>
      store.put(folderSyncMetadataKey, jsonEncode(value));
}

/// Active-only reconciliation: no OS-background delivery promise. Repository
/// commits coalesce with a timer; startup/resume also recover missed dirty signals.
class FolderSyncLifecycle extends ConsumerStatefulWidget {
  const FolderSyncLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<FolderSyncLifecycle> createState() =>
      _FolderSyncLifecycleState();
}

class _FolderSyncLifecycleState extends ConsumerState<FolderSyncLifecycle>
    with WidgetsBindingObserver {
  Timer? _periodic;
  Timer? _dirty;
  var _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
    _periodic = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_active) _run();
    });
  }

  void _schedule() {
    _dirty?.cancel();
    _dirty = Timer(const Duration(milliseconds: 750), () {
      if (_active) _run();
    });
  }

  Future<void> _run() async {
    if (!mounted || !_active) return;
    try {
      final service = ref.read(folderSyncServiceProvider);
      await service.initialize();
      if (service.configured && mounted && _active) await service.synchronize();
    } catch (error, stack) {
      if (mounted) {
        ref
            .read(loggerProvider)
            .handledError(
              'FolderSync',
              'reconcile',
              error: error,
              stackTrace: stack,
            );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _run();
    } else {
      _dirty?.cancel();
    }
  }

  @override
  void dispose() {
    _periodic?.cancel();
    _dirty?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bookmarkProvider, (_, next) {
      if (next.hasValue) _schedule();
    });
    ref.listen(followingTopicsProvider, (_, next) {
      if (next.hasValue) _schedule();
    });
    return widget.child;
  }
}
