part of 'service.dart';

final class _MaintenanceObsolete implements Exception {
  const _MaintenanceObsolete();
}

extension MiteMiteMaintenance on MiteMiteService {
  Duration get _activeTime {
    final since = _foregroundSince;
    final elapsed = since == null ? Duration.zero : _elapsed() - since;
    return _activeBefore + (elapsed.isNegative ? Duration.zero : elapsed);
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _activeBefore = _activeTime;
    _foregroundSince = value ? _elapsed() : null;
    _foreground = value;
  }

  Future<VerifiedSyncCatalog> _verifyCatalog(
    String publisher,
    int sequence,
    Uint8List bytes,
  ) async {
    final cached = _verifiedCatalogs[publisher];
    if (cached != null &&
        cached.ticket.sequence == sequence &&
        listEquals(cached.bytes, bytes)) {
      // A signature cache never grants authority: recheck current pinned trust,
      // OBSERVED and any failed cached-write barrier before using its ticket.
      return gate.withCurrentCatalog(cached.ticket, () async => cached.ticket);
    }
    final ticket = await gate.verifyAndCheckpoint(
      publisher: publisher,
      expectedSequence: sequence,
      bytes: bytes,
    );
    _verifiedCatalogs[publisher] = (
      bytes: Uint8List.fromList(bytes),
      ticket: ticket,
    );
    return ticket;
  }

  Future<bool> _ownCatalogPresent(MiteMiteStorage storage) async {
    final raw = preferences.get(
      'mitemite.v1.outgoing.${identity.id}.catalog_intent',
    );
    if (raw == null) return false;
    final prior = SyncCatalog.fromJson(
      (jsonDecode(raw) as Map<String, dynamic>)['catalog']
          as Map<String, dynamic>,
    );
    final bytes = await storage.read(
      prior.path,
      maxBytes: miteMiteMaxMetadataBytes,
    );
    if (bytes == null) return false;
    final cached = _verifiedOwnCatalog;
    if (cached != null &&
        cached.intent == raw &&
        listEquals(cached.bytes, bytes)) {
      return true;
    }
    try {
      final content = await verifySyncDocument(bytes, identity.publicKey);
      final matches =
          canonicalSyncJson(content) == canonicalSyncJson(prior.toJson());
      if (matches) {
        _verifiedOwnCatalog = (intent: raw, bytes: Uint8List.fromList(bytes));
      }
      return matches;
    } on FormatException {
      return false;
    }
  }

  Future<void> _scheduleMaintenance({bool force = false}) {
    if (force) _auditDue = true;
    if (_maintenance case final active?) return active;
    if (_disposed ||
        !_foreground ||
        location == null ||
        (!_auditDue && _activeTime < _nextAudit)) {
      return Future.value();
    }
    late final Future<void> running;
    running =
        Future<void>(() async {
          final generation = _storageGeneration;
          final selected = location!;
          try {
            void current() {
              _ensureCurrent();
              if (!_foreground || generation != _storageGeneration) {
                throw const _MaintenanceObsolete();
              }
            }

            current();
            final storage = await _open(selected);
            final intentKey =
                'mitemite.v1.outgoing.${identity.id}.catalog_intent';
            final raw = preferences.get(intentKey);
            if (raw == null) return;
            final catalog = SyncCatalog.fromJson(
              (jsonDecode(raw) as Map<String, dynamic>)['catalog']
                  as Map<String, dynamic>,
            );
            void sameCatalog() {
              current();
              if (preferences.get(intentKey) != raw) {
                throw const _MaintenanceObsolete();
              }
            }

            for (final entry in catalog.entries) {
              if (entry.state != SyncPublicationState.active) continue;
              final revision = entry.revision!;
              final repair = await _operations.runExclusive(() async {
                sameCatalog();
                try {
                  final payload = await SyncRevisionTransport(storage).read(
                    expected: revision,
                    publisherKey: identity.publicKey,
                  );
                  sameCatalog();
                  return payload == null;
                } on FormatException {
                  sameCatalog();
                  return true;
                }
              });
              if (repair) {
                _repairSources.add(entry.id.key);
                await synchronize(trigger: SyncTrigger.localChange);
                // The repair committed a new catalog. Replan against that catalog
                // on the next check; old audit evidence must not authorize cleanup.
                return;
              }
              await Future<void>.delayed(Duration.zero);
            }
            sameCatalog();
            final result = await SyncOwnedRetention(
              storage: storage,
              identity: identity,
              preferences: preferences,
              ensureCurrent: sameCatalog,
              withDeletion: (action) => _operations.runExclusive(action),
            ).prune(catalog);
            sameCatalog();
            _auditDue = result.hasMore;
            _nextAudit = _activeTime + const Duration(minutes: 15);
            retentionFailure = null;
          } on _MaintenanceObsolete {
            _auditDue = true;
          } catch (error) {
            _auditDue = true;
            if (!_disposed) retentionFailure = error;
          }
        }).whenComplete(() {
          if (identical(_maintenance, running)) _maintenance = null;
          _notify();
        });
    _maintenance = running;
    return running;
  }
}
