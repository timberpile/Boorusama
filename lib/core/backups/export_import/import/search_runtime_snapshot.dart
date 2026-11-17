import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../search/following_topics/types.dart';
import '../../../search/following_topics/src/types/following_mirror_state.dart';
import '../../../search/following_topics/src/services/conservative_refresh_policy.dart';

final class SearchRuntimeSnapshot extends Equatable {
  const SearchRuntimeSnapshot({
    required this.searches,
    required this.feeds,
    required this.organization,
    this.sourceOwnedIds = const {},
  });

  factory SearchRuntimeSnapshot.empty() => SearchRuntimeSnapshot(
    searches: const [],
    feeds: const [],
    organization: TopicOrganization(
      folders: const [],
      homeSearchIds: const [],
    ),
  );

  final List<FollowingTopic> searches;
  final List<TopicFeed> feeds;
  final TopicOrganization organization;

  /// Exclusion only: rollback must never turn a former mirror into Local data.
  final Set<String> sourceOwnedIds;

  @override
  List<Object?> get props => [searches, feeds, organization, sourceOwnedIds];
}

final class SearchRuntimeSnapshotCodec {
  const SearchRuntimeSnapshotCodec();

  static const _version = 1;

  String encode(SearchRuntimeSnapshot snapshot) => jsonEncode({
    'version': _version,
    'searches': snapshot.searches.map(_searchToJson).toList(),
    'feeds': snapshot.feeds.map((feed) => feed.toJson()).toList(),
    'organization': snapshot.organization.toJson(),
    'folderScopes': {
      for (final folder in snapshot.organization.folders)
        if (folder.nameScope != null) folder.id: folder.nameScope,
    },
    'sourceOwnedIds': snapshot.sourceOwnedIds.toList()..sort(),
  });

  SearchRuntimeSnapshot decode(
    String encoded, {
    Map<String, String> folderScopes = const {},
  }) {
    final value = jsonDecode(encoded);
    if (value case {
      'version': _version,
      'searches': final List searches,
      'feeds': final List feeds,
      'organization': final Map organization,
    }) {
      return SearchRuntimeSnapshot(
        searches: searches.map(_searchFromJson).toList(),
        feeds: feeds.map(_feedFromJson).toList(),
        organization: TopicOrganization.fromJson(
          organization,
          folderScopes: {
            ...((value['folderScopes'] as Map?) ?? const {})
                .cast<String, String>(),
            ...folderScopes,
          },
        ),
        sourceOwnedIds: Set.unmodifiable(
          ((value['sourceOwnedIds'] as List?) ?? const []).cast<String>(),
        ),
      );
    }
    throw const FormatException('Invalid search runtime snapshot');
  }

  static Map<String, Object?> _searchToJson(FollowingTopic search) => {
    'id': search.id,
    'profileId': search.profileId,
    'localSource': search.localSource?.toJson(),
    'query': search.query,
    'queryStructure': search.queryStructure?.toJson(),
    'autoUpdateEnabled': search.autoUpdateEnabled,
    'newPostCountEstimate': search.newPostCountEstimate,
    'newPostCountIsLowerBound': search.newPostCountIsLowerBound,
    'name': search.name,
    'position': search.position,
    'createdAt': search.createdAt.toIso8601String(),
    'runtimeRevision': search.runtimeRevision,
    'previews': [
      for (final preview in search.previews)
        {
          'postId': preview.postId,
          'postCreatedAt': preview.postCreatedAt?.toIso8601String(),
          'thumbnailUrl': preview.thumbnailUrl,
          'sampleUrl': preview.sampleUrl,
          'discoveredAt': preview.discoveredAt.toIso8601String(),
        },
    ],
    'recentPostIdentities': [
      for (final identity in search.recentPostIdentities)
        {
          'postId': identity.postId,
          'postCreatedAt': identity.postCreatedAt.toIso8601String(),
        },
    ],
    'unreadCount': search.unreadCount,
    'lastAttemptAt': search.lastAttemptAt?.toIso8601String(),
    'lastSuccessfulCheckAt': search.lastSuccessfulCheckAt?.toIso8601String(),
    'highestSeenPostId': search.highestSeenPostId,
    'lastErrorKind': search.lastErrorKind?.name,
    'adaptiveIntervalMilliseconds':
        search.adaptiveState.interval.inMilliseconds,
    'emptyAutomaticStreak': search.adaptiveState.consecutiveEmptyAutomatic,
    'lastMaterialEditAt': search.lastMaterialEditAt?.toIso8601String(),
  };

  static FollowingTopic _searchFromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid runtime search');
    }
    final id = _requiredString(value, 'id');
    final profileId = _requiredString(value, 'profileId');
    final query = _requiredString(value, 'query');
    final position = _requiredInt(value, 'position');
    final createdAt = _requiredDate(value, 'createdAt');
    final runtimeRevision = _requiredInt(value, 'runtimeRevision');
    final unreadCount = _requiredInt(value, 'unreadCount');
    final previews = _requiredList(value, 'previews').map((raw) {
      if (raw is! Map) {
        throw const FormatException('Invalid runtime search preview');
      }
      return SearchPostPreview(
        postId: _requiredInt(raw, 'postId'),
        postCreatedAt: _optionalDate(raw, 'postCreatedAt'),
        thumbnailUrl: _requiredString(raw, 'thumbnailUrl'),
        sampleUrl: _optionalString(raw, 'sampleUrl'),
        discoveredAt: _requiredDate(raw, 'discoveredAt'),
      );
    }).toList();
    final identities =
        _requiredList(
          value,
          'recentPostIdentities',
        ).map((raw) {
          if (raw is! Map) {
            throw const FormatException('Invalid recent search identity');
          }
          return RecentSearchPostIdentity(
            postId: _requiredInt(raw, 'postId'),
            postCreatedAt: _requiredDate(raw, 'postCreatedAt'),
          );
        }).toList();
    return FollowingTopic(
      id: id,
      profileId: profileId,
      localSource: value['localSource'] == null
          ? null
          : FollowingTopicSource.fromJson(value['localSource'] as Map),
      query: query,
      queryStructure: SearchQueryStructure.tryParse(value['queryStructure']),
      autoUpdateEnabled: value['autoUpdateEnabled'] != false,
      newPostCountEstimate: _optionalInt(value, 'newPostCountEstimate'),
      newPostCountIsLowerBound: value['newPostCountIsLowerBound'] == true,
      name: _optionalString(value, 'name'),
      position: position,
      createdAt: createdAt,
      previews: previews,
      recentPostIdentities: identities,
      unreadCount: unreadCount,
      lastAttemptAt: _optionalDate(value, 'lastAttemptAt'),
      lastSuccessfulCheckAt: _optionalDate(value, 'lastSuccessfulCheckAt'),
      highestSeenPostId: _optionalInt(value, 'highestSeenPostId'),
      lastErrorKind: _optionalErrorKind(value, 'lastErrorKind'),
      runtimeRevision: runtimeRevision,
      adaptiveState: AdaptiveRefreshState(
        interval: Duration(
          milliseconds: switch (value['adaptiveIntervalMilliseconds']) {
            final int milliseconds
                when milliseconds >= 21600000 && milliseconds <= 604800000 =>
              milliseconds,
            _ => 86400000,
          },
        ),
        consecutiveEmptyAutomatic: value['emptyAutomaticStreak'] == 1 ? 1 : 0,
      ),
      lastMaterialEditAt: _optionalDate(value, 'lastMaterialEditAt'),
    );
  }

  static TopicFeed _feedFromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid runtime feed');
    }
    return TopicFeed.fromJson(value);
  }

  static List<Object?> _requiredList(Map value, String key) =>
      switch (value[key]) {
        final List list => list,
        _ => throw FormatException('Invalid $key'),
      };

  static String _requiredString(Map value, String key) => switch (value[key]) {
    final String text => text,
    _ => throw FormatException('Invalid $key'),
  };

  static String? _optionalString(Map value, String key) => switch (value[key]) {
    null => null,
    final String text => text,
    _ => throw FormatException('Invalid $key'),
  };

  static int _requiredInt(Map value, String key) => switch (value[key]) {
    final int number => number,
    _ => throw FormatException('Invalid $key'),
  };

  static int? _optionalInt(Map value, String key) => switch (value[key]) {
    null => null,
    final int number => number,
    _ => throw FormatException('Invalid $key'),
  };

  static DateTime _requiredDate(Map value, String key) =>
      switch (_requiredString(value, key)) {
        final String text => _parseDate(text, key),
      };

  static DateTime? _optionalDate(Map value, String key) => switch (value[key]) {
    null => null,
    final String text => _parseDate(text, key),
    _ => throw FormatException('Invalid $key'),
  };

  static DateTime _parseDate(String value, String key) =>
      DateTime.tryParse(value) ?? (throw FormatException('Invalid $key'));

  static SearchRefreshErrorKind? _optionalErrorKind(
    Map value,
    String key,
  ) {
    final name = _optionalString(value, key);
    if (name == null) return null;
    for (final kind in SearchRefreshErrorKind.values) {
      if (kind.name == name) return kind;
    }
    throw FormatException('Invalid $key');
  }
}

final class SearchRuntimeSnapshotService {
  const SearchRuntimeSnapshotService(this.repository);

  final FollowingTopicRepository repository;

  Future<FollowingMirrorState> _mirrors() async =>
      repository is FollowingMirrorStore
      ? (await (repository as FollowingMirrorStore).readMirrorSnapshot())
            .mirrors
      : const FollowingMirrorState.empty();

  Future<SearchRuntimeSnapshot> capture() async {
    final mirrors = await _mirrors();
    final organization = await repository.getOrganization();
    return SearchRuntimeSnapshot(
      searches: (await repository.getAll())
          .where((topic) => !mirrors.isReceived(topic.id))
          .toList(),
      feeds: (await repository.getFeeds())
          .where((feed) => !mirrors.isReceived(feed.id))
          .toList(),
      organization: TopicOrganization(
        folders: organization.folders.where(
          (folder) => !mirrors.isReceived(folder.id),
        ),
        placements: organization.placements.where(
          (placement) => !mirrors.isReceived(placement.itemId),
        ),
      ),
      sourceOwnedIds: mirrors.owners.keys.toSet(),
    );
  }

  Future<void> restore(SearchRuntimeSnapshot snapshot) async {
    final mirrors = await _mirrors();
    final protected = {...snapshot.sourceOwnedIds, ...mirrors.owners.keys};
    for (final feed in await repository.getFeeds()) {
      if (!mirrors.isReceived(feed.id)) await repository.deleteFeed(feed.id);
    }
    for (final search in await repository.getAll()) {
      if (!mirrors.isReceived(search.id)) await repository.delete(search.id);
    }

    final searchesByProfile = <String, List<FollowingTopic>>{};
    for (final search in snapshot.searches) {
      if (!protected.contains(search.id))
        searchesByProfile.putIfAbsent(search.profileId, () => []).add(search);
    }
    for (final entry in searchesByProfile.entries) {
      await repository.restoreForProfile(entry.key, entry.value);
    }

    final feedsByProfile = <String, List<TopicFeed>>{};
    for (final feed in snapshot.feeds) {
      if (!protected.contains(feed.id))
        feedsByProfile.putIfAbsent(feed.profileId, () => []).add(feed);
    }
    for (final entry in feedsByProfile.entries) {
      await repository.restoreFeeds(entry.key, entry.value);
    }
    final current = await repository.getOrganization();
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [
          ...snapshot.organization.folders.where(
            (folder) => !protected.contains(folder.id),
          ),
          ...current.folders.where((folder) => mirrors.isReceived(folder.id)),
        ],
        placements: [
          ...snapshot.organization.placements.where(
            (p) => !protected.contains(p.itemId),
          ),
          ...current.placements.where((p) => mirrors.isReceived(p.itemId)),
        ],
      ),
    );
  }
}
