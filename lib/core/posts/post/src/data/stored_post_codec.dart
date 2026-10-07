// Project imports:
import '../../../rating/types.dart';
import '../../../sources/types.dart';
import '../types/booru_post_data.dart';
import '../types/post.dart';
import '../types/post_core_data.dart';
import '../types/post_origin.dart';
import '../types/stored_post_snapshot.dart';

enum StoredPostDecodeFailureReason {
  malformedOrigin,
  malformedCommonData,
  unsupportedCommonVersion,
}

sealed class StoredPostDecodeResult {
  const StoredPostDecodeResult();
}

final class StoredPostDecodeSuccess extends StoredPostDecodeResult {
  const StoredPostDecodeSuccess(this.post);

  final Post post;
}

final class StoredPostDecodeFailure extends StoredPostDecodeResult {
  const StoredPostDecodeFailure(this.reason, {this.error});

  final StoredPostDecodeFailureReason reason;
  final Object? error;
}

final class StoredPostCodec {
  const StoredPostCodec();

  static const commonSchemaVersion = 1;

  StoredPostSnapshot encode<D extends BooruPostData>(
    Post post, {
    BooruPostDataCodec<D>? dataCodec,
  }) {
    final data = post.booruData;
    final (custom, codecVersion) = switch (data) {
      UnknownPostData(:final custom, :final schemaVersion) => (
        custom,
        schemaVersion,
      ),
      LegacyPostData(:final custom, :final schemaVersion) => (
        custom,
        schemaVersion,
      ),
      D() when dataCodec != null && dataCodec.supports(data) => (
        dataCodec.encode(data),
        dataCodec.currentVersion,
      ),
      _ => throw ArgumentError.value(
        data,
        'post.booruData',
        'No compatible post data codec was provided',
      ),
    };

    return StoredPostSnapshot(
      origin: post.origin.toSnapshot(),
      common: _encodeCommon(post.core),
      custom: custom,
      codecVersion: codecVersion,
    );
  }

  StoredPostDecodeResult decode<D extends BooruPostData>(
    StoredPostSnapshot snapshot, {
    BooruPostDataCodec<D>? dataCodec,
  }) {
    late final PostOrigin origin;
    try {
      origin = PostOrigin.fromSnapshot(snapshot.origin);
    } catch (error) {
      return StoredPostDecodeFailure(
        StoredPostDecodeFailureReason.malformedOrigin,
        error: error,
      );
    }

    final PostCoreData core;
    try {
      core = _decodeCommon(snapshot.common);
    } on _UnsupportedCommonVersion catch (error) {
      return StoredPostDecodeFailure(
        StoredPostDecodeFailureReason.unsupportedCommonVersion,
        error: error,
      );
    } catch (error) {
      return StoredPostDecodeFailure(
        StoredPostDecodeFailureReason.malformedCommonData,
        error: error,
      );
    }

    final data = _decodeCustom(snapshot, origin, dataCodec);

    return StoredPostDecodeSuccess(
      Post(origin: origin, core: core, booruData: data),
    );
  }

  BooruPostData _decodeCustom<D extends BooruPostData>(
    StoredPostSnapshot snapshot,
    PostOrigin origin,
    BooruPostDataCodec<D>? codec,
  ) {
    final typeKey = codec?.typeKey ?? origin.booruType.name;
    if (codec == null) {
      return UnknownPostData(
        typeKey: typeKey,
        schemaVersion: snapshot.codecVersion,
        custom: snapshot.custom,
        reason: UnknownPostDataReason.unavailableCodec,
      );
    }
    if (snapshot.codecVersion > codec.currentVersion) {
      return UnknownPostData(
        typeKey: typeKey,
        schemaVersion: snapshot.codecVersion,
        custom: snapshot.custom,
        reason: UnknownPostDataReason.unsupportedVersion,
      );
    }

    try {
      final decoded = codec.decode(
        snapshot.custom,
        version: snapshot.codecVersion,
      );
      if (!codec.supports(decoded) || decoded.typeKey != codec.typeKey) {
        return UnknownPostData(
          typeKey: typeKey,
          schemaVersion: snapshot.codecVersion,
          custom: snapshot.custom,
          reason: UnknownPostDataReason.incompatiblePayload,
        );
      }
      return decoded;
    } catch (_) {
      return UnknownPostData(
        typeKey: typeKey,
        schemaVersion: snapshot.codecVersion,
        custom: snapshot.custom,
        reason: UnknownPostDataReason.malformedData,
      );
    }
  }
}

Map<String, Object?> _encodeCommon(PostCoreData data) => {
  'schemaVersion': StoredPostCodec.commonSchemaVersion,
  'id': data.id,
  'createdAt': ?data.createdAt?.toUtc().toIso8601String(),
  'thumbnailImageUrl': data.thumbnailImageUrl,
  'sampleImageUrl': data.sampleImageUrl,
  'originalImageUrl': data.originalImageUrl,
  'videoUrl': data.videoUrl,
  'videoThumbnailUrl': data.videoThumbnailUrl,
  'mediaVariants': ?data.mediaVariants,
  'thumbnailAspectRatio': ?data.thumbnailAspectRatio,
  'sampleAspectRatio': ?data.sampleAspectRatio,
  'originalAspectRatio': ?data.originalAspectRatio,
  'videoThumbnailAspectRatio': ?data.videoThumbnailAspectRatio,
  'videoAspectRatio': ?data.videoAspectRatio,
  'width': data.width,
  'height': data.height,
  'format': data.format,
  'md5': data.md5,
  'fileSize': data.fileSize,
  'duration': data.duration,
  'hasSound': ?data.hasSound,
  'tags': data.tags.toList(),
  'artistTags': ?data.artistTags?.toList(),
  'characterTags': ?data.characterTags?.toList(),
  'copyrightTags': ?data.copyrightTags?.toList(),
  'rating': data.rating.name,
  'hasComment': data.hasComment,
  'isTranslated': data.isTranslated,
  'hasParentOrChildren': data.hasParentOrChildren,
  'parentId': ?data.parentId,
  'source': _encodeSource(data.source),
  'score': data.score,
  'downvotes': ?data.downvotes,
  'uploaderId': ?data.uploaderId,
  'uploaderName': ?data.uploaderName,
  'status': ?data.status,
  'metadata': ?_encodeMetadata(data.metadata),
};

Map<String, Object?>? _encodeMetadata(PostMetadata? metadata) =>
    switch (metadata) {
      final metadata? => {
        'page': ?metadata.page,
        'search': ?metadata.search,
        'limit': ?metadata.limit,
      },
      null => null,
    };

PostCoreData _decodeCommon(Map<String, Object?> json) {
  final version = json['schemaVersion'];
  if (version != StoredPostCodec.commonSchemaVersion) {
    throw _UnsupportedCommonVersion(version);
  }

  return PostCoreData(
    id: _required<int>(json['id'], 'id'),
    createdAt: switch (json['createdAt']) {
      final String value => DateTime.parse(value),
      null => null,
      _ => throw const FormatException('Invalid createdAt'),
    },
    thumbnailImageUrl: _required<String>(
      json['thumbnailImageUrl'],
      'thumbnailImageUrl',
    ),
    sampleImageUrl: _required<String>(json['sampleImageUrl'], 'sampleImageUrl'),
    originalImageUrl: _required<String>(
      json['originalImageUrl'],
      'originalImageUrl',
    ),
    videoUrl: _required<String>(json['videoUrl'], 'videoUrl'),
    videoThumbnailUrl: _required<String>(
      json['videoThumbnailUrl'],
      'videoThumbnailUrl',
    ),
    mediaVariants: _optionalStringMap(json['mediaVariants']),
    thumbnailAspectRatio: _optionalDouble(json['thumbnailAspectRatio']),
    sampleAspectRatio: _optionalDouble(json['sampleAspectRatio']),
    originalAspectRatio: _optionalDouble(json['originalAspectRatio']),
    videoThumbnailAspectRatio: _optionalDouble(
      json['videoThumbnailAspectRatio'],
    ),
    videoAspectRatio: _optionalDouble(json['videoAspectRatio']),
    width: _required<num>(json['width'], 'width').toDouble(),
    height: _required<num>(json['height'], 'height').toDouble(),
    format: _required<String>(json['format'], 'format'),
    md5: _required<String>(json['md5'], 'md5'),
    fileSize: _required<int>(json['fileSize'], 'fileSize'),
    duration: _required<num>(json['duration'], 'duration').toDouble(),
    hasSound: json['hasSound'] as bool?,
    tags: _stringSet(json['tags']),
    artistTags: _optionalStringSet(json['artistTags']),
    characterTags: _optionalStringSet(json['characterTags']),
    copyrightTags: _optionalStringSet(json['copyrightTags']),
    rating: Rating.parse(json['rating']),
    hasComment: _required<bool>(json['hasComment'], 'hasComment'),
    isTranslated: _required<bool>(json['isTranslated'], 'isTranslated'),
    hasParentOrChildren: _required<bool>(
      json['hasParentOrChildren'],
      'hasParentOrChildren',
    ),
    parentId: json['parentId'] as int?,
    source: _decodeSource(json['source']),
    score: _required<int>(json['score'], 'score'),
    downvotes: json['downvotes'] as int?,
    uploaderId: json['uploaderId'] as int?,
    uploaderName: json['uploaderName'] as String?,
    status: json['status'] as String?,
    metadata: _decodeMetadata(json['metadata']),
  );
}

Map<String, Object?> _encodeSource(PostSource source) => switch (source) {
  NoSource() => const {'kind': 'none'},
  NonWebSource(:final value) => {'kind': 'nonWeb', 'value': value},
  PixivSource(:final url) => {'kind': 'pixiv', 'url': url},
  RawWebSource(:final url) => {'kind': 'web', 'url': url},
};

PostSource _decodeSource(Object? value) {
  final json = _map(value, 'post source');
  return switch (json) {
    {'kind': 'none'} => PostSource.none(),
    {'kind': 'nonWeb', 'value': final String source} => NonWebSource(source),
    {'kind': 'pixiv', 'url': final String url} => PostSource.pixiv(
      int.parse(Uri.parse(url).pathSegments.last),
    ),
    {'kind': 'web', 'url': final String url} => PostSource.from(url),
    _ => throw const FormatException('Invalid post source'),
  };
}

PostMetadata? _decodeMetadata(Object? value) {
  if (value == null) return null;
  final json = _map(value, 'post metadata');
  return PostMetadata(
    page: json['page'] as int?,
    search: json['search'] as String?,
    limit: json['limit'] as int?,
  );
}

double? _optionalDouble(Object? value) => switch (value) {
  null => null,
  final num number => number.toDouble(),
  _ => throw const FormatException('Expected a number'),
};

Set<String> _stringSet(Object? value) {
  final values = _list(value, 'string set');
  if (values.any((item) => item is! String)) {
    throw const FormatException('Expected strings');
  }
  return values.cast<String>().toSet();
}

Set<String>? _optionalStringSet(Object? value) =>
    value == null ? null : _stringSet(value);

Map<String, String>? _optionalStringMap(Object? value) {
  if (value == null) return null;
  final map = _map(value, 'string map');
  if (map.values.any((item) => item is! String)) {
    throw const FormatException('Expected string values');
  }
  return map.map((key, value) => MapEntry(key, value! as String));
}

T _required<T>(Object? value, String field) => switch (value) {
  final T value => value,
  _ => throw FormatException('Invalid stored post $field'),
};

List<Object?> _list(Object? value, String field) => switch (value) {
  final List<Object?> values => values,
  _ => throw FormatException('Invalid stored post $field'),
};

Map<String, Object?> _map(Object? value, String field) => switch (value) {
  final Map<Object?, Object?> map when map.keys.every((key) => key is String) =>
    Map<String, Object?>.from(map),
  _ => throw FormatException('Invalid stored post $field'),
};

final class _UnsupportedCommonVersion implements Exception {
  const _UnsupportedCommonVersion(this.version);

  final Object? version;
}
