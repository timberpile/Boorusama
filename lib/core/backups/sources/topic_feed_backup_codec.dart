import 'package:uuid/uuid.dart';

import '../../search/following_topics/types.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'topic_feed_backup_data.dart';
import 'search_backup_envelope.dart';
import 'search_backup_profile.dart';
import '../../search/following_topics/src/compatibility/topic_storage_contract.dart';

class TopicFeedBackupCodec extends JsonHandler<TopicFeedBackupData> {
  @override
  TopicFeedBackupData parse(ExportDataPayload metadata) {
    requireSearchBackupEnvelope(metadata, topicFeedsBackupSourceId);
    final ids = <String>{};
    final feeds = <TopicFeedBackupRecord>[];
    for (final (index, value) in metadata.data.indexed) {
      final record = _parseFeedRow(value, 'data[$index]');
      if (!ids.add(record.id)) {
        throw InvalidBackupFormatException('data[$index].id is repeated');
      }
      feeds.add(record);
    }
    return TopicFeedBackupData(feeds: feeds);
  }

  TopicFeedBackupRecord _parseFeedRow(Object? raw, String field) {
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
          when values.isNotEmpty && values.length <= topicFeedSourceLimit =>
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
    return TopicFeedBackupRecord(
      id: id,
      name: name,
      position: position,
      queries: uniqueQueries,
      profile: parseBackupProfile(raw['profile'], '$field.profile'),
    );
  }

  @override
  List<dynamic> encode(TopicFeedBackupData data) => [
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
