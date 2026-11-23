part of 'service.dart';

extension MiteMiteCollectionAliases on MiteMiteService {
  Map<SyncCollectionId, String> get collectionAliases =>
      _collectionAliases.values;

  Future<void> setCollectionAlias(SyncCollectionId id, String? value) =>
      _action(
        'collection-alias:${id.key}',
        () async {
          _ensureCurrent();
          if (gate.approvedKey(id.publisher) == null)
            throw const SyncTrustRequired();
          if (id.kind == 'bookmarks') {
            final current = await mirrors.readMirrorState();
            if (!current.owners.values.any(
              (owner) =>
                  owner.publisher == id.publisher && owner.source == id.source,
            ))
              throw const SyncConflict();
          } else {
            final current = await (await _followingRepository())
                .readMirrorSnapshot();
            if (!current.mirrors.owners.values.any(
              (owner) =>
                  owner.kind == FollowingMirrorKind.folder &&
                  owner.publisher == id.publisher &&
                  owner.source == id.source,
            ))
              throw const SyncConflict();
          }
          _ensureCurrent();
          await _collectionAliases.set(id, value);
        },
        local: true,
      );

  Future<void> _pruneCollectionAliases(Set<SyncDomain> domains) async {
    if (collectionAliases.isEmpty) return;
    await mutations.runExclusive(() async {
      _ensureCurrent();
      if (domains.contains(SyncDomain.bookmarks)) {
        final current = await mirrors.readMirrorState();
        _ensureCurrent();
        await _collectionAliases.retain('bookmarks', {
          for (final owner in current.owners.values)
            SyncCollectionId(
              publisher: owner.publisher,
              kind: 'bookmarks',
              source: owner.source,
            ),
        });
      }
      if (domains.contains(SyncDomain.following) && followingStore != null) {
        final current = await (await _followingRepository())
            .readMirrorSnapshot();
        _ensureCurrent();
        await _collectionAliases.retain('following_topics', {
          for (final owner in current.mirrors.owners.values)
            if (owner.kind == FollowingMirrorKind.folder)
              SyncCollectionId(
                publisher: owner.publisher,
                kind: 'following_topics',
                source: owner.source,
              ),
        });
      }
    });
  }
}
