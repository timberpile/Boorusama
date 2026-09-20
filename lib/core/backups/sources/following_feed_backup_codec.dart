import 'package:uuid/uuid.dart';

import '../../search/subscriptions/types.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'following_feed_backup_data.dart';
import 'search_backup_envelope.dart';
import 'search_backup_profile.dart';

class FollowingFeedBackupCodec extends JsonHandler<FollowingFeedBackupData> {
  @override
  FollowingFeedBackupData parse(ExportDataPayload metadata) {
    requireSearchBackupEnvelope(metadata, 'following_feeds');
    final ids = <String>{};
    final feeds = <FollowingFeedBackupRecord>[];
    for (final (index, value) in metadata.data.indexed) {
      final record = _parseFeedRow(value, 'data[$index]');
      if (!ids.add(record.id)) {
        throw InvalidBackupFormatException('data[$index].id is repeated');
      }
      feeds.add(record);
    }
    return FollowingFeedBackupData(feeds: feeds);
  }

  FollowingFeedBackupRecord _parseFeedRow(Object? raw, String field) {
    if (raw is! Map<String, dynamic> || raw['kind'] != 'feed') {
      throw InvalidBackupFormatException('$field.kind must be feed');
    }
    final id = switch (raw['id']) {
      final String value when Uuid.isValidUUID(fromString: value) =>
        value.toLowerCase(),
      _ => throw InvalidBackupFormatException('$field.id is invalid'),
    };
    final name = switch (raw['name']) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => throw InvalidBackupFormatException('$field.name is invalid'),
    };
    final position = switch (raw['position']) {
      final int value when value >= 0 => value,
      _ => throw InvalidBackupFormatException('$field.position is invalid'),
    };
    final queries = switch (raw['queries']) {
      final List values
          when values.isNotEmpty && values.length <= followingFeedSourceLimit =>
        [
          for (final value in values)
            switch (value) {
              final String query when query.trim().isNotEmpty =>
                normalizeSearchIdentity(query),
              _ => throw InvalidBackupFormatException(
                '$field.queries is invalid',
              ),
            },
        ],
      _ => throw InvalidBackupFormatException('$field.queries is invalid'),
    };
    final uniqueQueries = queries.toSet().toList();
    if (uniqueQueries.any((query) => query.isEmpty)) {
      throw InvalidBackupFormatException('$field.queries is invalid');
    }
    return FollowingFeedBackupRecord(
      id: id,
      name: name,
      position: position,
      queries: uniqueQueries,
      profile: parseBackupProfile(raw['profile'], '$field.profile'),
    );
  }

  @override
  List<dynamic> encode(FollowingFeedBackupData data) => [
    for (final feed in data.feeds)
      {
        'kind': 'feed',
        'id': feed.id,
        'name': feed.name,
        'position': feed.position,
        'queries': feed.queries,
        'profile': feed.profile.toJson(),
      },
  ];
}
