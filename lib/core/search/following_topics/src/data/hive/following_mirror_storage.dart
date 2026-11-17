part of 'following_topic_repository_hive.dart';

const _followingMirrorKey = 'search:sync_mirrors';

extension _FollowingMirrorStorage on HiveFollowingTopicRepository {
  FollowingMirrorState _followingMirrors() =>
      switch (_organizationBox?.get(_followingMirrorKey)) {
        null => const FollowingMirrorState.empty(),
        final Map value => FollowingMirrorState.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw const FormatException('Invalid Following mirror metadata'),
      };

  FollowingMirrorSnapshot _readFollowingMirrorSnapshot() {
    final topics = _topics().toList();
    final organization = _organization();
    final ordered = topics.toList()..sort((a, b) => a.id.compareTo(b.id));
    final structure = jsonEncode({
      'topics': [
        for (final topic in ordered)
          {
            'id': topic.id,
            'profile': topic.profileId,
            'localSource': topic.localSource?.toJson(),
            'query': topic.query,
            'queryStructure': topic.queryStructure?.toJson(),
            'name': topic.name,
            'position': topic.position,
          },
      ],
      'organization': organization.toJson(),
    });
    return FollowingMirrorSnapshot(
      mirrors: _followingMirrors(),
      topics: List.unmodifiable(topics),
      organization: organization,
      structureDigest: sha256.convert(utf8.encode(structure)).toString(),
    );
  }

  ImportJournalStore? get _followingJournal => _box.path == null
      ? null
      : ImportJournalStore(
          fs: _fs,
          rootPath: p.join(
            p.dirname(_box.path!),
            'following_sync_transactions',
          ),
        );

  Future<void> _recoverFollowingMirrors() async {
    if (_organizationBox?.get('search:sync_journal_enabled') != true) return;
    final journal = _followingJournal;
    if (journal == null) return;
    final recovery = await ImportRecoveryService(
      store: journal,
      transaction: ImportTransaction(store: journal, fs: _fs),
      sources: () => {'following_topics': _mirrorTransactionSource()},
    ).recoverPending();
    if (recovery.failures.isNotEmpty) {
      throw StateError('Following Sync recovery requires attention');
    }
  }

  Future<void> _syncFollowingStorage() async {
    await _box.flush();
    await _organizationBox?.flush();
    for (final path in [_box.path, _organizationBox?.path].nonNulls) {
      await _fs.syncFile(path);
      await _fs.syncDirectory(p.dirname(path));
    }
  }

  _FollowingMirrorTransactionSource _mirrorTransactionSource({
    Set<String> topicIds = const {},
    Future<void> Function()? apply,
  }) => _FollowingMirrorTransactionSource(
    fs: _fs,
    revision: () async => _readFollowingMirrorSnapshot().structureDigest,
    capture: () async => jsonEncode({
      'version': 2,
      'topicIds': topicIds.toList()..sort(),
      'runtime': const SearchRuntimeSnapshotCodec().encode(
        SearchRuntimeSnapshot(
          searches: [
            for (final id in topicIds)
              if (_box.get(id) case final object?) _toTopic(object),
          ],
          feeds: const [],
          organization: _organization(),
        ),
      ),
      // This is local rollback state, never an outgoing .bsexport. Capture all
      // organization/cache/preferences keys so recovery is exact and does not
      // import publisher refresh settings or touch unrelated Topic records.
      'metadata': _followingRollbackMetadata(
        _organizationBox?.toMap() ?? const {},
        encode: true,
      ),
    }),
    apply: apply,
    sync: _syncFollowingStorage,
    restore: (encoded) async {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      if (!const [1, 2].contains(data['version']) || data['metadata'] is! Map) {
        throw const FormatException('Invalid Following Sync rollback');
      }
      final ids = (data['topicIds'] as List).cast<String>().toSet();
      final metadata = data['version'] == 2
          ? _followingRollbackMetadata(data['metadata'] as Map, encode: false)
          : data['metadata'] as Map;
      final owned = metadata[_followingMirrorKey] is Map
          ? FollowingMirrorState.fromJson(
              Map<String, dynamic>.from(metadata[_followingMirrorKey] as Map),
            ).owners
          : const <String, FollowingMirrorOwner>{};
      final snapshot = const SearchRuntimeSnapshotCodec().decode(
        data['runtime'] as String,
        folderScopes: {
          for (final entry in owned.entries)
            if (entry.value.kind == FollowingMirrorKind.folder)
              entry.key: entry.value.folderNameScope,
        },
      );
      if (snapshot.searches.any((topic) => !ids.contains(topic.id))) {
        throw const FormatException('Invalid Following Sync rollback scope');
      }
      await _box.deleteAll(ids);
      await _box.putAll({
        for (final topic in snapshot.searches) topic.id: _toObject(topic),
      });
      await _organizationBox!.clear();
      await _organizationBox.putAll(metadata);
    },
  );

  Future<void> _commitFollowingMirrors({
    required FollowingMirrorState expected,
    required String expectedStructureDigest,
    required FollowingMirrorState next,
    required List<FollowingTopic> topics,
    required TopicOrganization organization,
    Set<String> removeTopicIds = const {},
  }) async {
    final journal = _followingJournal;
    final storage = _organizationBox;
    if (journal == null || storage == null) {
      throw StateError('Durable Following storage is required for Sync');
    }
    final current = _readFollowingMirrorSnapshot();
    if (current.mirrors != expected ||
        current.structureDigest != expectedStructureDigest ||
        next.epoch != expected.epoch + 1 ||
        !next.activity.follows(expected.activity)) {
      throw const FollowingMirrorConflict();
    }
    final currentDigests = followingSnapshotDefinitionDigests(current);
    for (final entry in current.mirrors.owners.entries) {
      if (currentDigests[entry.key] != entry.value.definitionDigest) {
        throw const FollowingMirrorConflict();
      }
    }
    for (final entry in expected.checkpoints.entries) {
      final after = next.checkpoints[entry.key];
      final before = entry.value;
      if (after == null ||
          after.kind != before.kind ||
          after.revision < before.revision ||
          (after.revision == before.revision &&
              (after.payloadDigest != before.payloadDigest ||
                  after.descriptorDigest != before.descriptorDigest ||
                  (before.retired && !after.retired)))) {
        throw const FollowingMirrorConflict();
      }
    }
    final oldTopics = {for (final t in current.topics) t.id: t};
    final oldFolders = {for (final f in current.organization.folders) f.id: f};
    final newFolders = {for (final f in organization.folders) f.id: f};
    final upserts = {for (final topic in topics) topic.id: topic};
    if (upserts.length != topics.length ||
        removeTopicIds.any(
          (id) => !expected.isReceived(id) || next.isReceived(id),
        ) ||
        upserts.keys.any(
          (id) => oldTopics.containsKey(id) && !expected.isReceived(id),
        )) {
      throw const FollowingMirrorReadOnly();
    }
    for (final entry in next.owners.entries) {
      final old = expected.owners[entry.key];
      if ((old != null &&
              (old.sourceKey != entry.value.sourceKey ||
                  old.kind != entry.value.kind)) ||
          (old == null &&
              (oldTopics.containsKey(entry.key) ||
                  oldFolders.containsKey(entry.key)))) {
        throw const FollowingMirrorConflict();
      }
      if (entry.value.kind == FollowingMirrorKind.folder
          ? !newFolders.containsKey(entry.key)
          : !upserts.containsKey(entry.key) &&
                !oldTopics.containsKey(entry.key)) {
        throw const FollowingMirrorConflict();
      }
    }
    for (final folder in organization.folders) {
      if (folder.nameScope != next.owners[folder.id]?.folderNameScope) {
        throw const FollowingMirrorConflict();
      }
    }
    organization.tree.validatePlacements(organization.placements);
    // Sync may create independent local copies, but never capture, delete or
    // reorganize pre-existing local definitions as part of a received update.
    for (final folder in current.organization.folders) {
      if (!expected.isReceived(folder.id) && newFolders[folder.id] != folder) {
        throw const FollowingMirrorReadOnly();
      }
    }
    for (final placement in current.organization.placements) {
      if (!expected.isReceived(placement.itemId) &&
          !organization.placements.contains(placement)) {
        throw const FollowingMirrorReadOnly();
      }
    }
    final changedQueries = <String>{};
    final merged = <String, FollowingTopic>{};
    for (final topic in topics) {
      final previous = oldTopics[topic.id];
      final changed =
          previous != null &&
          (previous.query != topic.query ||
              previous.queryStructure != topic.queryStructure ||
              previous.profileId != topic.profileId);
      if (changed) changedQueries.add(topic.id);
      final local = previous == null
          ? topic
          : changed
          ? _resetRuntime(previous)
          : previous;
      merged[topic.id] = FollowingTopic(
        id: topic.id,
        profileId: topic.profileId,
        localSource: topic.localSource,
        query: topic.query,
        queryStructure: topic.queryStructure,
        name: topic.name,
        position: topic.position,
        createdAt: local.createdAt,
        runtimeRevision: local.runtimeRevision,
        previews: local.previews,
        recentPostIdentities: local.recentPostIdentities,
        unreadCount: local.unreadCount,
        lastAttemptAt: local.lastAttemptAt,
        lastSuccessfulCheckAt: local.lastSuccessfulCheckAt,
        highestSeenPostId: local.highestSeenPostId,
        lastErrorKind: local.lastErrorKind,
        adaptiveState: local.adaptiveState,
        lastMaterialEditAt: local.lastMaterialEditAt,
        autoUpdateEnabled: local.autoUpdateEnabled,
        newPostCountEstimate: local.newPostCountEstimate,
        newPostCountIsLowerBound: local.newPostCountIsLowerBound,
        historyEnd: local.historyEnd,
      );
    }
    final resultingTopics = {...oldTopics, ...merged}
      ..removeWhere((id, _) => removeTopicIds.contains(id));
    final resulting = FollowingMirrorSnapshot(
      mirrors: next,
      topics: resultingTopics.values.toList(),
      organization: organization,
      structureDigest: '',
    );
    final resultingDigests = followingSnapshotDefinitionDigests(resulting);
    for (final entry in next.owners.entries) {
      if (resultingDigests[entry.key] != entry.value.definitionDigest) {
        throw const FollowingMirrorConflict();
      }
    }
    // This durable enrollment precedes journal creation. Ordinary libraries and
    // in-memory repositories never need a filesystem recovery path; a crash
    // during the first mirror transaction must still trigger recovery on open.
    await storage.put('search:sync_journal_enabled', true);
    await _syncFollowingStorage();
    final source = _mirrorTransactionSource(
      topicIds: {...topics.map((t) => t.id), ...removeTopicIds},
      apply: () async {
        await _box.putAll({for (final t in merged.values) t.id: _toObject(t)});
        await _box.deleteAll(removeTopicIds);
        final removedFolders = oldFolders.keys.toSet().difference(
          newFolders.keys.toSet(),
        );
        for (final feed in _feeds()) {
          if (removedFolders.contains(feed.id)) {
            await storage.delete('feed:${feed.id}');
            continue;
          }
          final folder = newFolders[feed.id];
          if (folder == null) continue;
          final ids = organization.recursiveIds(folder.id);
          final retained = feed.reconcileSources(
            ids.where((id) => !changedQueries.contains(id)).toList(),
          );
          await storage.put(
            'feed:${feed.id}',
            retained
                .copyWith(
                  name: folder.name,
                  sourceIds: ids,
                  maxPosts: folder.feedMaxPosts,
                  profileId: ids.isEmpty
                      ? feed.profileId
                      : resultingTopics[ids.first]!.profileId,
                  initializedSourceIds: folder.feedMaxPosts > feed.maxPosts
                      ? const []
                      : retained.initializedSourceIds,
                )
                .toJson(),
          );
        }
        for (final key in [
          'search:auto_update_overrides',
          'search:new_post_estimates',
        ]) {
          if (storage.get(key) case final Map saved) {
            await storage.put(
              key,
              Map.of(saved)..removeWhere(
                (id, _) =>
                    removeTopicIds.contains(id) || removedFolders.contains(id),
              ),
            );
          }
        }
        // New independent rows (copy Undo) restore only their own local state.
        // The journal captures metadata and these row IDs before any write.
        for (final topic in merged.values.where(
          (t) => !oldTopics.containsKey(t.id) && !next.isReceived(t.id),
        )) {
          final overrides = Map<dynamic, dynamic>.of(
            (storage.get('search:auto_update_overrides') as Map?) ?? const {},
          );
          final estimates = Map<dynamic, dynamic>.of(
            (storage.get('search:new_post_estimates') as Map?) ?? const {},
          );
          overrides.remove(topic.id);
          estimates.remove(topic.id);
          if (!topic.autoUpdateEnabled) overrides[topic.id] = false;
          if (topic.newPostCountEstimate case final count?)
            estimates[topic.id] = {
              'count': count,
              'lowerBound': topic.newPostCountIsLowerBound,
            };
          await storage.put('search:auto_update_overrides', overrides);
          await storage.put('search:new_post_estimates', estimates);
          if (topic.historyEnd case final end?) {
            await storage.put('history:${topic.id}', {
              'confirmed': true,
              'profileId': topic.profileId,
              'query': normalizeSearchIdentity(topic.query),
              'queryStructure': topic.queryStructure?.toJson(),
              'revision': topic.runtimeRevision,
              'createdAt': topic.createdAt,
              'emptyAtHighestSeen': topic.highestSeenPostId,
              'oldest': end.oldestPostIdentity,
            });
          }
        }
        await storage.put('search:organization', organization.toJson());
        await storage.put(_followingMirrorKey, next.toJson());
      },
    );
    try {
      await ImportTransaction(store: journal, fs: _fs).execute(
        transactionId: _uuid.v4(),
        plan: ValidatedImportPlan(
          plan: ResolvedImportPlan(
            sources: [
              ResolvedImportSource(
                id: source.id,
                action: ImportAction.replace,
                items: const [],
              ),
            ],
          ),
          revisionTokens: {source.id: current.structureDigest},
          summary: PlannedChangeSummary(
            updated: topics.length,
            deleted: removeTopicIds.length,
          ),
        ),
        sources: {source.id: source},
      );
    } catch (_) {
      _mirrorRecoveryComplete = false;
      rethrow;
    }
  }

  void _requireWritableFollowing(String id) {
    if (_followingMirrors().isReceived(id))
      throw const FollowingMirrorReadOnly();
  }

  void _requireWritableFollowingOrganization(TopicOrganization organization) {
    final before = _readFollowingMirrorSnapshot();
    final after = FollowingMirrorSnapshot(
      mirrors: before.mirrors,
      topics: before.topics,
      organization: organization,
      structureDigest: '',
    );
    for (final f in organization.folders) {
      if (!before.mirrors.isReceived(f.id) &&
          before.mirrors.isReceived(f.parentId ?? '')) {
        throw const FollowingMirrorReadOnly();
      }
    }
    for (final p in organization.placements) {
      if (!before.mirrors.isReceived(p.itemId) &&
          before.mirrors.isReceived(p.folderId ?? '')) {
        throw const FollowingMirrorReadOnly();
      }
    }
    final afterDigests = followingSnapshotDefinitionDigests(after);
    for (final entry in before.mirrors.owners.entries) {
      if (afterDigests[entry.key] != entry.value.definitionDigest) {
        throw const FollowingMirrorReadOnly();
      }
    }
  }
}

/// History bounds are private Hive metadata with a typed creation timestamp.
/// Keep that type across JSON journal recovery; older journals contain no dates.
Map<dynamic, dynamic> _followingRollbackMetadata(
  Map values, {
  required bool encode,
}) => {
  for (final entry in values.entries)
    entry.key:
        entry.key is String &&
            (entry.key as String).startsWith('history:') &&
            entry.value is Map
        ? {
            ...(entry.value as Map),
            if ((entry.value as Map)['createdAt'] case final Object created)
              'createdAt': encode && created is DateTime
                  ? created.toIso8601String()
                  : !encode && created is String
                  ? DateTime.parse(created)
                  : created,
          }
        : entry.value,
};

final class _FollowingMirrorTransactionSource
    implements ImportTransactionSource {
  _FollowingMirrorTransactionSource({
    required this.fs,
    required this.revision,
    required this.capture,
    required Future<void> Function(String) restore,
    required this.sync,
    Future<void> Function()? apply,
  }) : _restore = restore,
       _apply = apply;
  final AppFileSystem fs;
  final Future<String> Function() revision;
  final Future<String> Function() capture;
  final Future<void> Function(String) _restore;
  final Future<void> Function() sync;
  final Future<void> Function()? _apply;
  @override
  String get id => 'following_topics';
  @override
  Future<String> revisionToken() => revision();
  @override
  Future<void> captureRollback(String path) async =>
      fs.writeString(path, await capture());
  @override
  Future<void> apply(ResolvedImportSource plan) async {
    final operation = _apply;
    if (operation == null)
      throw StateError('Recovery cannot apply new definitions');
    await operation();
  }

  @override
  Future<void> durableSync() => sync();
  @override
  Future<void> restore(String path) async =>
      _restore(await fs.readString(path));
}
