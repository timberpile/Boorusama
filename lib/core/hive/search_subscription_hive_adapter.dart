import 'package:hive_ce/hive.dart';

import '../search/subscriptions/src/data/hive/recent_search_post_hive_object.dart';
import '../search/subscriptions/src/data/hive/search_post_preview_hive_object.dart';
import '../search/subscriptions/src/data/hive/search_subscription_hive_object.dart';

// This adapter keeps the existing type ID and binary field layout. An old numeric
// profile ID is decoded as invalid so the repository can ignore that row.
class SearchSubscriptionHiveObjectAdapter
    extends TypeAdapter<SearchSubscriptionHiveObject> {
  @override
  final typeId = 6;

  @override
  SearchSubscriptionHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SearchSubscriptionHiveObject(
      id: fields[0] as String,
      profileId: switch (fields[1]) {
        final String id => id,
        _ => '',
      },
      query: fields[2] as String,
      name: fields[3] as String?,
      position: (fields[4] as num).toInt(),
      createdAt: fields[5] as DateTime,
      lastAttemptAt: fields[6] as DateTime?,
      lastSuccessfulCheckAt: fields[7] as DateTime?,
      highestSeenPostId: (fields[14] as num?)?.toInt(),
      unreadCount: (fields[8] as num).toInt(),
      lastErrorKind: fields[9] as String?,
      previews: (fields[10] as List).cast<SearchPostPreviewHiveObject>(),
      recentPostIdentities: (fields[11] as List)
          .cast<RecentSearchPostHiveObject>(),
      feedId: fields[12] as String?,
      runtimeRevision: fields[13] == null ? 0 : (fields[13] as num).toInt(),
      queryStructure: fields[15] as Object?,
      adaptiveIntervalMilliseconds: switch (fields[16]) {
        final int milliseconds
            when milliseconds >= 21600000 && milliseconds <= 604800000 =>
          milliseconds,
        _ => 86400000,
      },
      emptyAutomaticStreak: fields[17] == 1 ? 1 : 0,
      lastMaterialEditAt: fields[18] is DateTime
          ? fields[18] as DateTime
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, SearchSubscriptionHiveObject obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.profileId)
      ..writeByte(2)
      ..write(obj.query)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.position)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.lastAttemptAt)
      ..writeByte(7)
      ..write(obj.lastSuccessfulCheckAt)
      ..writeByte(8)
      ..write(obj.unreadCount)
      ..writeByte(9)
      ..write(obj.lastErrorKind)
      ..writeByte(10)
      ..write(obj.previews)
      ..writeByte(11)
      ..write(obj.recentPostIdentities)
      ..writeByte(12)
      ..write(obj.feedId)
      ..writeByte(13)
      ..write(obj.runtimeRevision)
      ..writeByte(14)
      ..write(obj.highestSeenPostId)
      ..writeByte(15)
      ..write(obj.queryStructure)
      ..writeByte(16)
      ..write(obj.adaptiveIntervalMilliseconds)
      ..writeByte(17)
      ..write(obj.emptyAutomaticStreak)
      ..writeByte(18)
      ..write(obj.lastMaterialEditAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSubscriptionHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
