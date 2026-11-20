import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
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
import '../../configs/manage/providers.dart';
import '../../content/anonymous_access_provider.dart';
import '../../configs/config/types.dart';
import '../../search/following_topics/src/data/providers.dart';
import '../../search/following_topics/src/providers/following_topics_notifier.dart';
import '../../search/following_topics/src/types/following_mirror_state.dart';
import '../sources/search_backup_profile.dart';
import 'android_storage.dart';
import 'durable_preferences.dart';
import 'local_change_detection.dart';
import 'failure.dart';
import 'private_preferences.dart';
import 'protocol.dart';
import 'service.dart';
import 'storage.dart';

// Opening settings never activates transport or starts a periodic scan.
final miteMiteActivationProvider = StateProvider<bool>(
  (ref) {
    final raw = ref.read(miscDataStoreProvider).get('mitemite.v1.settings');
    if (raw == null) return false;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)['location'] is String;
    } on FormatException {
      return false;
    }
  },
);

final miteMiteServiceProvider = FutureProvider<MiteMiteService>((
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
  MiteMiteService? createdService;
  ref.onDispose(() {
    current = false;
    createdService?.dispose();
  });
  final android = ref.watch(appPlatformProvider).isAndroid;
  final repositoryReady = ref.watch(bookmarkRepoProvider.future);
  final groupsReady = ref.watch(bookmarkGroupRepoProvider.future);
  if (preferences is DurableSyncPreferences) await preferences.synchronize();
  if (preferences is PrivateSyncPreferences) await preferences.synchronize();
  final repository = await repositoryReady;
  final groups = await groupsReady;
  if (!current) throw StateError('Sync provider disposed');
  final store = unifiedBookmarkStorage(repository);
  if (store == null) throw StateError('Sync requires unified Bookmark storage');
  final identity = await mutations.runExclusive(() async {
    if (!current) throw StateError('Sync provider disposed');
    final saved = preferences.get('mitemite.v1.identity');
    if (saved != null) {
      return SyncSigningIdentity.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
    }
    final created = await SyncSigningIdentity.create();
    await preferences.put(
      'mitemite.v1.identity',
      jsonEncode(created.localJson()),
    );
    return created;
  });
  if (!current) throw StateError('Sync provider disposed');
  final service = MiteMiteService(
    preferences: preferences,
    store: store,
    groups: groups,
    fs: fs,
    identity: identity,
    mutations: mutations,
    followingStore: () async {
      final repository = await ref.read(
        followingTopicRepositoryProvider.future,
      );
      if (repository is! FollowingMirrorStore)
        throw StateError('Following mirror storage required');
      return repository as FollowingMirrorStore;
    },
    profiles: () => [
      for (final config in ref.read(booruConfigProvider))
        BackupProfileReference(
          id: config.id,
          booruType: config.auth.booruType.name,
          url: config.url,
          name: config.auth.booruType.name,
        ),
    ],
    codec: BookmarkBackupCodec(
      postDataCodec: (type) => registry.getPostCapability(type)?.codec,
      groupMetadata: metadata,
    ),
    storageFor: (location) async {
      if (android) return AndroidMiteMiteStorage(location);
      if (!await Directory(location).exists()) {
        throw StateError('Shared directory unavailable');
      }
      return DirectoryMiteMiteStorage(location);
    },
    anonymousPolicy: () => ref.read(anonymousSourcePolicyProvider),
    onDomainsApplied: (domains) async {
      if (domains.contains(SyncDomain.bookmarks))
        await ref.read(bookmarkProvider.notifier).refresh();
      if (domains.contains(SyncDomain.following) &&
          ref.exists(followingTopicsProvider)) {
        await ref.read(followingTopicsProvider.notifier).reloadFromStorage();
      }
    },
  );
  createdService = service;
  return service;
});

/// Excludes retained resources from previous async generations. The source
/// provider remains the only owner of service disposal.
final currentMiteMiteServiceProvider = Provider<MiteMiteService?>(
  (ref) => ref.watch(miteMiteServiceProvider).unwrapPrevious().valueOrNull,
  dependencies: [miteMiteServiceProvider],
);

/// FutureProvider owns the service lifetime. This bridge observes mutations
/// without giving a second provider ownership/disposal of the ChangeNotifier.
final miteMiteChangesProvider = NotifierProvider<MiteMiteChanges, int>(
  MiteMiteChanges.new,
  dependencies: [currentMiteMiteServiceProvider],
);

class MiteMiteChanges extends Notifier<int> {
  var _revision = 0;
  @override
  int build() {
    final service = ref.watch(currentMiteMiteServiceProvider);
    void changed() {
      state = ++_revision;
    }

    service?.addListener(changed);
    ref.onDispose(() => service?.removeListener(changed));
    return ++_revision;
  }
}

final publishedBookmarkRootsProvider = Provider<Set<String>>(
  (ref) {
    if (!ref.watch(miteMiteActivationProvider) &&
        !ref.exists(miteMiteServiceProvider))
      return const {};
    final service = ref.watch(currentMiteMiteServiceProvider);
    return ref.watch(
      miteMiteChangesProvider.select(
        (_) => service?.publishedRoots ?? const <String>{},
      ),
    );
  },
  dependencies: [
    miteMiteServiceProvider,
    currentMiteMiteServiceProvider,
    miteMiteChangesProvider,
    miteMiteActivationProvider,
  ],
);

final publishedFollowingRootsProvider = Provider<Set<String>>(
  (ref) {
    if (!ref.exists(miteMiteServiceProvider)) return const {};
    final service = ref.watch(currentMiteMiteServiceProvider);
    return ref.watch(
      miteMiteChangesProvider.select(
        (_) => service?.publishedFollowingRoots ?? const <String>{},
      ),
    );
  },
  dependencies: [
    miteMiteServiceProvider,
    currentMiteMiteServiceProvider,
    miteMiteChangesProvider,
    miteMiteActivationProvider,
  ],
);

final followingSyncPresentationProvider = Provider<Object?>(
  (ref) {
    final service = ref.watch(currentMiteMiteServiceProvider);
    return ref.watch(
      miteMiteChangesProvider.select(
        (_) => service?.receiverFollowing?.mirrors,
      ),
    );
  },
  dependencies: [
    miteMiteServiceProvider,
    currentMiteMiteServiceProvider,
    miteMiteChangesProvider,
    miteMiteActivationProvider,
  ],
);

/// Alias changes have their own stable projection; poll timestamps never rebuild
/// collection labels or the Following list's cached body.
final syncCollectionAliasesProvider = Provider<Map<SyncCollectionId, String>>((
  ref,
) {
  final service = ref.watch(currentMiteMiteServiceProvider);
  if (service == null) return const {};
  return ref.watch(
    miteMiteChangesProvider.select((_) => service.collectionAliases),
  );
}, dependencies: [currentMiteMiteServiceProvider, miteMiteChangesProvider]);

// Operational timestamps must not rebuild collection lists on every poll.
final miteMiteManagementViewProvider = Provider.autoDispose
    .family<_ManagementView, String?>((ref, section) {
      ref.watch(miteMiteChangesProvider);
      final service = ref.watch(currentMiteMiteServiceProvider);
      if (service == null) return const _ManagementView([]);
      Object? kind(Object? error) =>
          error == null ? null : syncFailureKind(error);
      final following = service.receiverFollowing;
      return _ManagementView([
        service.location,
        service.name,
        service.discoveryNotifications,
        service.publishedRoots,
        service.publishedFollowingRoots,
        service.devices,
        {
          for (final device in service.devices)
            device.id: service.gate.approvedKey(device.id) != null,
        },
        {for (final e in service.deviceFailures.entries) e.key: kind(e.value)},
        kind(service.outgoingFailure),
        kind(service.followingFailure),
        kind(service.failure),
        service.reloadFailure != null,
        service.activityFailure != null,
        service.retentionFailure != null,
        service.receiverMirrors?.epoch,
        (following?.structureDigest, following?.mirrors.epoch),
        service.pendingActionKeys,
        if (section == 'receive') ...[
          service.events.unseenOffers.keys.toSet(),
          service.busy,
          service.isReconciling,
        ],
        if (section == null || section == 'activity') service.events.history,
        if (section == null) ...[
          service.lastSync,
          service.lastSuccess,
          service.isReconciling,
        ],
      ]);
    }, dependencies: [currentMiteMiteServiceProvider, miteMiteChangesProvider]);

final class _ManagementView extends Equatable {
  const _ManagementView(this.values);
  final List<Object?> values;
  @override
  List<Object?> get props => values;
}

class MiteMiteLifecycle extends ConsumerStatefulWidget {
  const MiteMiteLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<MiteMiteLifecycle> createState() => _MiteMiteLifecycleState();
}

class _MiteMiteLifecycleState extends ConsumerState<MiteMiteLifecycle>
    with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _dirty;
  StreamSubscription<FileSystemEvent>? _watcher;
  String? _watchedLocation;
  MiteMiteService? _service;
  bool _foreground = true;
  MiteMiteService? _syncingService;
  bool _requested = false;
  bool _dirtySource = false;

  // Widget rebuilds lag provider disposal. Scheduled callbacks must recheck the
  // source generation even while the previous instance is still attached here.
  MiteMiteService? get _currentService {
    final service = _service;
    return service != null &&
            identical(ref.read(currentMiteMiteServiceProvider), service)
        ? service
        : null;
  }

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _attach(MiteMiteService? service) {
    if (identical(_service, service)) return;
    _poll?.cancel();
    _dirty?.cancel();
    _stopWatcher();
    _service?.removeListener(_changed);
    _service?.setForeground(false);
    _service = service;
    service?.setForeground(_foreground);
    service?.addListener(_changed);
    if (service != null && _foreground) {
      _poll = Timer.periodic(const Duration(minutes: 1), (_) {
        _watchDirectory();
        unawaited(_sync());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _foreground && identical(service, _currentService)) {
          ref.invalidate(publishedFollowingRootsProvider);
          _watchDirectory();
          unawaited(_sync(SyncTrigger.startup));
        }
      });
    }
  }

  void _changed() {
    _watchDirectory();
    if (_requested &&
        !identical(_syncingService, _currentService) &&
        !(_currentService?.busy ?? true))
      _debounce(SyncTrigger.watcher);
  }

  void _debounce([SyncTrigger trigger = SyncTrigger.localChange]) {
    _requested = true;
    if (trigger == SyncTrigger.localChange) _dirtySource = true;
    _dirty?.cancel();
    if (_foreground)
      _dirty = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(
          _sync(_dirtySource ? SyncTrigger.localChange : SyncTrigger.watcher),
        ),
      );
  }

  Future<void> _sync([SyncTrigger trigger = SyncTrigger.poll]) async {
    final service = _currentService;
    if (!_foreground || service == null) {
      _requested = true;
      return;
    }
    // A poll/resume during an update joins that update. A real local mutation
    // independently retains _requested through _debounce and its durable epoch.
    if (identical(_syncingService, service) || service.isReconciling) {
      if (trigger == SyncTrigger.resume || trigger == SyncTrigger.startup) {
        unawaited(service.synchronize(trigger: trigger));
      }
      return;
    }
    if (service.busy) {
      _requested = true;
      return;
    }
    _requested = false;
    _dirtySource = false;
    _syncingService = service;
    try {
      await service.synchronize(trigger: trigger);
    } catch (_) {
      /* Localized service state remains visible and retries are bounded. */
    } finally {
      if (identical(_syncingService, service)) _syncingService = null;
      if (mounted &&
          identical(service, _currentService) &&
          _foreground &&
          _requested)
        _debounce(SyncTrigger.watcher);
    }
  }

  void _stopWatcher() {
    unawaited(_watcher?.cancel());
    _watcher = null;
    _watchedLocation = null;
  }

  void _watchDirectory() {
    final service = _currentService;
    final location = service?.location;
    if (!_foreground ||
        location == null ||
        ref.read(appPlatformProvider).isAndroid) {
      _stopWatcher();
      return;
    }
    if (_watchedLocation == location) return;
    _stopWatcher();
    _watchedLocation = location;
    try {
      final ownPrefix =
          '${Directory(location).absolute.path}${Platform.pathSeparator}v1${Platform.pathSeparator}devices${Platform.pathSeparator}${service!.identity.id}${Platform.pathSeparator}';
      _watcher = Directory(location)
          .watch(recursive: true)
          .listen(
            (event) {
              if (mounted &&
                  identical(service, _currentService) &&
                  !event.path.startsWith(ownPrefix))
                _debounce(SyncTrigger.watcher);
            },
            onError: (Object _) {
              if (mounted && identical(service, _currentService))
                _stopWatcher();
            },
            cancelOnError: true,
          );
    } catch (_) {
      // Mounted shares/providers may not support events. Polling and full
      // startup/resume reconciliation remain the mandatory fallback.
      _stopWatcher();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _currentService?.setForeground(_foreground);
    _poll?.cancel();
    _dirty?.cancel();
    _stopWatcher();
    if (_foreground && _currentService != null) {
      _poll = Timer.periodic(const Duration(minutes: 1), (_) {
        _watchDirectory();
        unawaited(_sync());
      });
      _watchDirectory();
      unawaited(_sync(SyncTrigger.resume));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(miteMiteActivationProvider)) {
      _attach(ref.watch(currentMiteMiteServiceProvider));
      ref.listen(followingTopicsProvider, (previous, next) {
        final before = previous?.valueOrNull;
        final after = next.valueOrNull;
        if (before != null &&
            after != null &&
            hasLocalFollowingSyncChanges(before, after))
          _localChanged();
      });
      ref.listen(booruConfigProvider, (previous, next) {
        if (previous != next) _localChanged();
      });
      ref.listen(bookmarkProvider, (previous, next) {
        final service = _currentService;
        final before = previous?.valueOrNull;
        final after = next.valueOrNull;
        if (service == null ||
            before == null ||
            after == null ||
            !hasLocalSyncChanges(before, after))
          return;
        // Do not drop a real local mutation just because receive/publication is
        // busy. Persist intent and re-run after the current operation finishes.
        unawaited(() async {
          try {
            await service.markDirty();
          } catch (_) {
            /* Startup/resume performs a full reconciliation as well. */
          }
          if (mounted && identical(_currentService, service)) _debounce();
        }());
      });
    } else {
      _attach(null);
    }
    return widget.child;
  }

  void _localChanged() {
    final service = _currentService;
    if (service == null) return;
    unawaited(() async {
      try {
        await service.markDirty();
      } catch (_) {
        /* Startup reconciliation remains available. */
      }
      if (mounted && identical(_currentService, service)) _debounce();
    }());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service?.removeListener(_changed);
    _service?.setForeground(false);
    _poll?.cancel();
    _dirty?.cancel();
    _stopWatcher();
    super.dispose();
  }
}
