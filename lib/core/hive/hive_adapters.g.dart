// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class FavoriteTagHiveObjectAdapter extends TypeAdapter<FavoriteTagHiveObject> {
  @override
  final typeId = 2;

  @override
  FavoriteTagHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteTagHiveObject(
      name: fields[0] as String,
      createdAt: fields[1] as DateTime,
      updatedAt: fields[2] as DateTime?,
      labels: (fields[3] as List?)?.cast<String>(),
      queryType: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteTagHiveObject obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.updatedAt)
      ..writeByte(3)
      ..write(obj.labels)
      ..writeByte(4)
      ..write(obj.queryType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteTagHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BlacklistedTagHiveObjectAdapter
    extends TypeAdapter<BlacklistedTagHiveObject> {
  @override
  final typeId = 3;

  @override
  BlacklistedTagHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlacklistedTagHiveObject(
      name: fields[0] as String,
      isActive: fields[1] as bool,
      createdDate: fields[2] as DateTime,
      updatedDate: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BlacklistedTagHiveObject obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isActive)
      ..writeByte(2)
      ..write(obj.createdDate)
      ..writeByte(3)
      ..write(obj.updatedDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlacklistedTagHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookmarkHiveObjectAdapter extends TypeAdapter<BookmarkHiveObject> {
  @override
  final typeId = 4;

  @override
  BookmarkHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookmarkHiveObject(
      booruId: (fields[0] as num?)?.toInt(),
      createdAt: fields[1] as DateTime?,
      updatedAt: fields[2] as DateTime?,
      thumbnailUrl: fields[3] as String?,
      sampleUrl: fields[4] as String?,
      originalUrl: fields[5] as String?,
      sourceUrl: fields[6] as String?,
      width: (fields[7] as num?)?.toDouble(),
      height: (fields[8] as num?)?.toDouble(),
      md5: fields[9] as String?,
      tags: (fields[10] as List?)?.cast<String>(),
      realSourceUrl: fields[11] as String?,
      format: fields[12] as String?,
      postId: (fields[13] as num?)?.toInt(),
      metadata: (fields[14] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkHiveObject obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.booruId)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.updatedAt)
      ..writeByte(3)
      ..write(obj.thumbnailUrl)
      ..writeByte(4)
      ..write(obj.sampleUrl)
      ..writeByte(5)
      ..write(obj.originalUrl)
      ..writeByte(6)
      ..write(obj.sourceUrl)
      ..writeByte(7)
      ..write(obj.width)
      ..writeByte(8)
      ..write(obj.height)
      ..writeByte(9)
      ..write(obj.md5)
      ..writeByte(10)
      ..write(obj.tags)
      ..writeByte(11)
      ..write(obj.realSourceUrl)
      ..writeByte(12)
      ..write(obj.format)
      ..writeByte(13)
      ..write(obj.postId)
      ..writeByte(14)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookmarkGroupHiveObjectAdapter
    extends TypeAdapter<BookmarkGroupHiveObject> {
  @override
  final typeId = 5;

  @override
  BookmarkGroupHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookmarkGroupHiveObject(
      id: fields[0] as String,
      name: fields[1] as String,
      bookmarkIds: (fields[2] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkGroupHiveObject obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.bookmarkIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkGroupHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
      profileId: (fields[1] as num).toInt(),
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
    );
  }

  @override
  void write(BinaryWriter writer, SearchSubscriptionHiveObject obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.highestSeenPostId);
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

class SearchPostPreviewHiveObjectAdapter
    extends TypeAdapter<SearchPostPreviewHiveObject> {
  @override
  final typeId = 7;

  @override
  SearchPostPreviewHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SearchPostPreviewHiveObject(
      postId: (fields[0] as num).toInt(),
      postCreatedAt: fields[1] as DateTime?,
      thumbnailUrl: fields[2] as String,
      sampleUrl: fields[3] as String?,
      discoveredAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SearchPostPreviewHiveObject obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.postId)
      ..writeByte(1)
      ..write(obj.postCreatedAt)
      ..writeByte(2)
      ..write(obj.thumbnailUrl)
      ..writeByte(3)
      ..write(obj.sampleUrl)
      ..writeByte(4)
      ..write(obj.discoveredAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchPostPreviewHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecentSearchPostHiveObjectAdapter
    extends TypeAdapter<RecentSearchPostHiveObject> {
  @override
  final typeId = 8;

  @override
  RecentSearchPostHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecentSearchPostHiveObject(
      postId: (fields[0] as num).toInt(),
      postCreatedAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecentSearchPostHiveObject obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.postId)
      ..writeByte(1)
      ..write(obj.postCreatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentSearchPostHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
