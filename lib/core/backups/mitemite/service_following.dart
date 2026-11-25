part of 'service.dart';

const _forgetKey = 'mitemite.v1.pending_forgets';

extension MiteMiteFollowing on MiteMiteService {
  Future<FollowingMirrorStore> _followingRepository() async {
    _ensureCurrent();
    final factory = followingStore;
    if (factory == null) throw const SyncUpdateRequired();
    final pending = _following ??= factory();
    try {
      final result = await pending;
      _ensureCurrent();
      return result;
    } catch (_) {
      if (identical(_following, pending)) _following = null;
      rethrow;
    }
  }

  Future<SyncFollowingMirrorEngine> _followingEngine(
    MiteMiteStorage storage,
  ) async => SyncFollowingMirrorEngine(
    store: await _followingRepository(),
    gate: gate,
    preparation: SyncReceivePreparation(storage: storage, fs: fs, codec: codec),
    profiles: () => profiles?.call() ?? const [],
    anonymousPolicy: anonymousPolicy,
    now: now,
    ensureCurrent: _ensureCurrent,
  );

  Future<void> publishFollowing(String source) =>
      _action('publication:following_topics:$source', () async {
        final id = syncUuid(source);
        if (publishedFollowingRoots.contains(id)) return;
        final snapshot = await (await _followingRepository())
            .readMirrorSnapshot();
        if (snapshot.mirrors.isReceived(id) ||
            !snapshot.organization.folders.any((f) => f.id == id)) {
          throw const FollowingMirrorReadOnly();
        }
        final roots = {...publishedFollowingRoots, id};
        await _save(location, name, publishedRoots, followingRoots: roots);
        publishedFollowingRoots = Set.unmodifiable(roots);
        await _publishFollowingChange();
      });

  Future<void> stopPublishingFollowing(String source) =>
      _action('publication:following_topics:$source', () async {
        final id = syncUuid(source);
        if (!publishedFollowingRoots.contains(id)) return;
        final roots = {...publishedFollowingRoots}..remove(id);
        await _save(location, name, publishedRoots, followingRoots: roots);
        publishedFollowingRoots = Set.unmodifiable(roots);
        await _publishFollowingChange();
        if (enabled) unawaited(_scheduleMaintenance(force: true));
      });

  Future<void> _publishFollowingChange() async {
    await markDirty();
    if (enabled && location != null) {
      await _sync(await _open(location!));
      if (outgoingFailure != null) throw const SyncPublicationPending();
    }
  }

  Future<void> subscribeFollowing(String publisher, Set<String> roots) =>
      _subscriptionAction(publisher, 'following_topics', roots, (roots) async {
        if (!enabled) throw const SyncPublisherUnavailable();
        final storage = await _open(location!);
        final device = devices.singleWhere((d) => d.id == publisher);
        final ticket = await _ticket(storage, device);
        await _receiveFollowing(storage, device, ticket, roots: Set.of(roots));
      });

  Future<void> _receiveFollowing(
    MiteMiteStorage storage,
    DiscoveredSyncDevice device,
    VerifiedSyncCatalog ticket, {
    Set<String>? roots,
  }) => _applied(
    () async => (await _followingEngine(storage))
        .receive(ticket: ticket, publisherKey: device.key, directRoots: roots),
    domains: const {SyncDomain.following},
  );

  Future<void> unsubscribeFollowing(String publisher, String source) =>
      _subscriptionAction(publisher, 'following_topics', {source}, (_) async {
        await _applied(
          () async =>
              (await _followingEngine(_OfflineStorage()))
                  .unsubscribe(publisher, source),
          domains: const {SyncDomain.following},
        );
      });

  Future<String> localFollowingCopy(String localId) => _run(() async {
    late String result;
    await _applied(
      () async =>
          result = await (await _followingEngine(_OfflineStorage()))
              .createLocalCopy(localId),
      domains: const {SyncDomain.following},
    );

    return result;
  });

  Future<void> acknowledgeFollowing(
    String localId, {
    String? definitionDigest,
  }) => _run(
    () => _applied(
      () async => (await _followingRepository()).acknowledgeMirrorDefinition(
        localId,
        definitionDigest: definitionDigest,
      ),
      domains: const {SyncDomain.following},
    ),
  );

  Future<void> acknowledgeFollowingDefinitions(Map<String, String> receipts) {
    final captured = Map<String, String>.unmodifiable(receipts);
    if (captured.isEmpty) return Future.value();
    return _run(
      () => _applied(() async {
        final repository = await _followingRepository();
        if (repository is FollowingDefinitionReceiptStore) {
          await (repository as FollowingDefinitionReceiptStore)
              .acknowledgeMirrorDefinitions(captured);
        } else {
          for (final entry in captured.entries) {
            await repository.acknowledgeMirrorDefinition(
              entry.key,
              definitionDigest: entry.value,
            );
          }
        }
      }, domains: const {SyncDomain.following}),
    );
  }

  Set<String> _pendingForgets() {
    final raw = preferences.get(_forgetKey);
    if (raw == null) return {};
    final ids = jsonDecode(raw);
    if (ids is! List || ids.length > miteMiteMaxEntries) {
      throw const FormatException('Invalid pending Forget actions');
    }
    return ids.map(syncUuid).toSet();
  }

  /// Revoke shared authority first, then finish both domain journals. The durable
  /// intent survives partial cleanup and is recovered before reapproval/receive.
  Future<void> _recoverForgets() async {
    for (final publisher in _pendingForgets()) {
      await gate.revokePublisher(publisher);
      await _engine(_OfflineStorage()).forgetDevice(publisher);
      if (followingStore != null) {
        await (await _followingEngine(_OfflineStorage()))
            .unsubscribe(publisher, publisher, forget: true);
      }
      await mutations.runExclusive(() => _collectionAliases.forget(publisher));
      await _refreshProjection();
      await mutations.runExclusive(
        () => preferences.put(
          _forgetKey,
          canonicalSyncJson(
            (_pendingForgets()..remove(publisher)).toList()..sort(),
          ),
        ),
      );
    }
  }
}
