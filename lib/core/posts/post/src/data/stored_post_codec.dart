// Project imports:
import '../../../rating/types.dart';
import '../../../sources/types.dart';
import '../types/booru_post_data.dart';
import '../types/post.dart';
import '../types/post_core_data.dart';
import '../types/post_origin.dart';
import '../types/stored_post_snapshot.dart';
import '../types/unified_post.dart';

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

  final UnifiedPost post;
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
    UnifiedPost post, {
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
      UnifiedPost(origin: origin, core: core, booruData: data),
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
  if (data.createdAt case final value?)
    'createdAt': value.toUtc().toIso8601String(),
  'thumbnailImageUrl': data.thumbnailImageUrl,
  'sampleImageUrl': data.sampleImageUrl,
  'originalImageUrl': data.originalImageUrl,
  'videoUrl': data.videoUrl,
  'videoThumbnailUrl': data.videoThumbnailUrl,
  if (data.mediaVariants case final value?) 'mediaVariants': value,
  if (data.thumbnailAspectRatio case final value?)
    'thumbnailAspectRatio': value,
  if (data.sampleAspectRatio case final value?) 'sampleAspectRatio': value,
  if (data.originalAspectRatio case final value?) 'originalAspectRatio': value,
  if (data.videoThumbnailAspectRatio case final value?)
    'videoThumbnailAspectRatio': value,
  if (data.videoAspectRatio case final value?) 'videoAspectRatio': value,
  'width': data.width,
  'height': data.height,
  'format': data.format,
  'md5': data.md5,
  'fileSize': data.fileSize,
  'duration': data.duration,
  if (data.hasSound case final value?) 'hasSound': value,
  'tags': data.tags.toList(),
  if (data.artistTags case final value?) 'artistTags': value.toList(),
  if (data.characterTags case final value?) 'characterTags': value.toList(),
  if (data.copyrightTags case final value?) 'copyrightTags': value.toList(),
  'rating': data.rating.name,
  'hasComment': data.hasComment,
  'isTranslated': data.isTranslated,
  'hasParentOrChildren': data.hasParentOrChildren,
  if (data.parentId case final value?) 'parentId': value,
  'source': _encodeSource(data.source),
  'score': data.score,
  if (data.downvotes case final value?) 'downvotes': value,
  if (data.uploaderId case final value?) 'uploaderId': value,
  if (data.uploaderName case final value?) 'uploaderName': value,
  if (data.status case final value?) 'status': value,
  if (data.metadata case final value?)
    'metadata': {
      if (value.page case final page?) 'page': page,
      if (value.search case final search?) 'search': search,
      if (value.limit case final limit?) 'limit': limit,
    },
};

PostCoreData _decodeCommon(Map<String, Object?> json) {
  final version = json['schemaVersion'];
  if (version != StoredPostCodec.commonSchemaVersion) {
    throw _UnsupportedCommonVersion(version);
  }

  return PostCoreData(
    id: json['id'] as int,
    createdAt: switch (json['createdAt']) {
      final String value => DateTime.parse(value),
      null => null,
      _ => throw const FormatException('Invalid createdAt'),
    },
    thumbnailImageUrl: json['thumbnailImageUrl'] as String,
    sampleImageUrl: json['sampleImageUrl'] as String,
    originalImageUrl: json['originalImageUrl'] as String,
    videoUrl: json['videoUrl'] as String,
    videoThumbnailUrl: json['videoThumbnailUrl'] as String,
    mediaVariants: _optionalStringMap(json['mediaVariants']),
    thumbnailAspectRatio: _optionalDouble(json['thumbnailAspectRatio']),
    sampleAspectRatio: _optionalDouble(json['sampleAspectRatio']),
    originalAspectRatio: _optionalDouble(json['originalAspectRatio']),
    videoThumbnailAspectRatio: _optionalDouble(
      json['videoThumbnailAspectRatio'],
    ),
    videoAspectRatio: _optionalDouble(json['videoAspectRatio']),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    format: json['format'] as String,
    md5: json['md5'] as String,
    fileSize: json['fileSize'] as int,
    duration: (json['duration'] as num).toDouble(),
    hasSound: json['hasSound'] as bool?,
    tags: _stringSet(json['tags']),
    artistTags: _optionalStringSet(json['artistTags']),
    characterTags: _optionalStringSet(json['characterTags']),
    copyrightTags: _optionalStringSet(json['copyrightTags']),
    rating: Rating.parse(json['rating']),
    hasComment: json['hasComment'] as bool,
    isTranslated: json['isTranslated'] as bool,
    hasParentOrChildren: json['hasParentOrChildren'] as bool,
    parentId: json['parentId'] as int?,
    source: _decodeSource(json['source']),
    score: json['score'] as int,
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
  final json = Map<String, Object?>.from(value as Map);
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
  final json = Map<String, Object?>.from(value as Map);
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
  final values = value as List;
  if (values.any((item) => item is! String)) {
    throw const FormatException('Expected strings');
  }
  return values.cast<String>().toSet();
}

Set<String>? _optionalStringSet(Object? value) =>
    value == null ? null : _stringSet(value);

Map<String, String>? _optionalStringMap(Object? value) {
  if (value == null) return null;
  final map = Map<String, Object?>.from(value as Map);
  if (map.values.any((item) => item is! String)) {
    throw const FormatException('Expected string values');
  }
  return map.map((key, value) => MapEntry(key, value! as String));
}

final class _UnsupportedCommonVersion implements Exception {
  const _UnsupportedCommonVersion(this.version);

  final Object? version;
}
