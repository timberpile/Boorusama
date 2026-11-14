import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../../foundation/filesystem.dart';
import '../../../foundation/platform.dart';
import '../../boorus/engine/providers.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/src/types/unified_bookmark_store.dart';
import '../../cache/misc_data_store.dart';
import '../../cache/hive_misc_data_store.dart';
import '../sources/bookmark_backup_codec.dart';
import '../../content/groups/group_source_provider.dart';
import 'android_storage.dart';
import 'durable_preferences.dart';
import 'protocol.dart';
import 'service.dart';
import 'storage.dart';

// Opening settings never activates transport or starts a periodic scan.
final folderSyncActivationProvider = StateProvider<bool>(
  (ref) {
    final raw = ref.read(miscDataStoreProvider).get('folder_sync.v1.settings');
    if (raw == null) return false;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)['location'] is String;
    } on FormatException {
      return false;
    }
  },
);

final folderSyncServiceProvider = FutureProvider<FolderSyncService>((
  ref,
) async {
  final rawPreferences = ref.watch(miscDataStoreProvider);
  final mutations = ref.watch(dataMutationCoordinatorProvider);
  final registry = ref.watch(booruEngineRegistryProvider);
  final metadata = ref.watch(groupMetadataCodecProvider);
  final fs = ref.watch(appFileSystemProvider);
  // Injected test stores may define their own durability; production uses Hive.
  final preferences = rawPreferences is HiveMiscDataStore
      ? DurableSyncPreferences(rawPreferences, fs)
      : rawPreferences;
  var current = true;
  FolderSyncService? createdService;
  ref.onDispose(() {
    current = false;
    createdService?.dispose();
  });
  final android = ref.watch(appPlatformProvider).isAndroid;
  final repositoryReady = ref.watch(bookmarkRepoProvider.future);
  final groupsReady = ref.watch(bookmarkGroupRepoProvider.future);
  if (preferences is DurableSyncPreferences) await preferences.synchronize();
  final repository = await repositoryReady;
  final groups = await groupsReady;
  if (!current) throw StateError('Sync provider disposed');
  final store = unifiedBookmarkStorage(repository);
  if (store == null) throw StateError('Sync requires unified Bookmark storage');
  final identity = await mutations.runExclusive(() async {
    if (!current) throw StateError('Sync provider disposed');
    final saved = preferences.get('folder_sync.v1.identity');
    if (saved != null) {
      return SyncSigningIdentity.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
    }
    final created = await SyncSigningIdentity.create();
    await preferences.put(
      'folder_sync.v1.identity',
      jsonEncode(created.localJson()),
    );
    return created;
  });
  if (!current) throw StateError('Sync provider disposed');
  final service = FolderSyncService(
    preferences: preferences,
    store: store,
    groups: groups,
    fs: fs,
    identity: identity,
    mutations: mutations,
    codec: BookmarkBackupCodec(
      postDataCodec: (type) => registry.getPostCapability(type)?.codec,
      groupMetadata: metadata,
    ),
    storageFor: (location) async {
      if (android) return AndroidFolderSyncStorage(location);
      if (!await Directory(location).exists()) {
        throw StateError('Shared directory unavailable');
      }
      return DirectoryFolderSyncStorage(location);
    },
    onApplied: () => ref.read(bookmarkProvider.notifier).refresh(),
  );
  createdService = service;
  return service;
});

class FolderSyncLifecycle extends ConsumerStatefulWidget {
  const FolderSyncLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<FolderSyncLifecycle> createState() =>
      _FolderSyncLifecycleState();
}

class _FolderSyncLifecycleState extends ConsumerState<FolderSyncLifecycle>
    with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _dirty;
  FolderSyncService? _service;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _attach(FolderSyncService? service) {
    if (identical(_service, service)) return;
    _poll?.cancel();
    _service = service;
    if (service != null && _foreground) {
      _poll = Timer.periodic(const Duration(seconds: 30), (_) => _sync());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
  }

  Future<void> _sync() async {
    final service = _service;
    if (!_foreground || service == null || service.busy) return;
    try {
      await service.synchronize();
    } catch (_) {
      /* Localized status is exposed by the service. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _poll?.cancel();
    _dirty?.cancel();
    if (_foreground && _service != null) {
      _poll = Timer.periodic(const Duration(seconds: 30), (_) => _sync());
      unawaited(_sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(folderSyncActivationProvider)) {
      final ready = ref.watch(folderSyncServiceProvider);
      _attach(ready.valueOrNull);
      ref.listen(bookmarkProvider, (previous, next) {
        if (_service == null ||
            _service!.busy ||
            _service!.applying ||
            previous?.valueOrNull?.revision == next.valueOrNull?.revision) {
          return;
        }
        _dirty?.cancel();
        _dirty = Timer(
          const Duration(milliseconds: 500),
          () => unawaited(_sync()),
        );
      });
    } else {
      _attach(null);
    }
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _dirty?.cancel();
    super.dispose();
  }
}
