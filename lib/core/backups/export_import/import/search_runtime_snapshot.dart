import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../search/subscriptions/types.dart';

final class SearchRuntimeSnapshot extends Equatable {
  const SearchRuntimeSnapshot({
    required this.searches,
    required this.feeds,
    required this.organization,
  });

  factory SearchRuntimeSnapshot.empty() => SearchRuntimeSnapshot(
    searches: const [],
    feeds: const [],
    organization: SearchOrganization(
      folders: const [],
      homeSearchIds: const [],
    ),
  );

  final List<SearchSubscription> searches;
  final List<SearchFollowingFeed> feeds;
  final SearchOrganization organization;

  @override
  List<Object?> get props => [searches, feeds, organization];
}

final class SearchRuntimeSnapshotCodec {
  const SearchRuntimeSnapshotCodec();

  static const _version = 1;

  String encode(SearchRuntimeSnapshot snapshot) => jsonEncode({
    'version': _version,
    'searches': snapshot.searches.map(_searchToJson).toList(),
    'feeds': snapshot.feeds.map((feed) => feed.toJson()).toList(),
    'organization': snapshot.organization.toJson(),
  });

  SearchRuntimeSnapshot decode(String encoded) {
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
        organization: SearchOrganization.fromJson(organization),
      );
    }
    throw const FormatException('Invalid search runtime snapshot');
  }

  static Map<String, Object?> _searchToJson(SearchSubscription search) => {
    'id': search.id,
    'profileId': search.profileId,
    'query': search.query,
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
  };

  static SearchSubscription _searchFromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid runtime search');
    }
    final id = _requiredString(value, 'id');
    final profileId = _requiredInt(value, 'profileId');
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
    return SearchSubscription(
      id: id,
      profileId: profileId,
      query: query,
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
    );
  }

  static SearchFollowingFeed _feedFromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid runtime feed');
    }
    return SearchFollowingFeed.fromJson(value);
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

  final SearchSubscriptionRepository repository;

  Future<SearchRuntimeSnapshot> capture() async => SearchRuntimeSnapshot(
    searches: await repository.getAll(),
    feeds: await repository.getFeeds(),
    organization: await repository.getOrganization(),
  );

  Future<void> restore(SearchRuntimeSnapshot snapshot) async {
    for (final feed in await repository.getFeeds()) {
      await repository.deleteFeed(feed.id);
    }
    for (final search in await repository.getAll()) {
      await repository.delete(search.id);
    }

    final searchesByProfile = <int, List<SearchSubscription>>{};
    for (final search in snapshot.searches) {
      searchesByProfile.putIfAbsent(search.profileId, () => []).add(search);
    }
    for (final entry in searchesByProfile.entries) {
      await repository.restoreForProfile(entry.key, entry.value);
    }

    final feedsByProfile = <int, List<SearchFollowingFeed>>{};
    for (final feed in snapshot.feeds) {
      feedsByProfile.putIfAbsent(feed.profileId, () => []).add(feed);
    }
    for (final entry in feedsByProfile.entries) {
      await repository.restoreFeeds(entry.key, entry.value);
    }
    await repository.replaceOrganization(snapshot.organization);
  }
}
