import 'dart:typed_data';

import '../bookmarks/src/types/bookmark_search_token.dart';
import '../boorus/booru/types.dart';
import '../posts/post/types.dart';
import '../posts/rating/types.dart';
import '../posts/sources/types.dart';
import 'local_media_reference.dart';

enum LocalMediaFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp'),
  gif('gif', 'image/gif'),
  mp4('mp4', 'video/mp4'),
  webm('webm', 'video/webm');

  const LocalMediaFormat(this.extension, this.mime);

  final String extension;
  final String mime;
  bool get isVideo => this == mp4 || this == webm;

  static LocalMediaFormat? detect(Uint8List bytes) {
    bool has(int offset, List<int> signature) {
      if (offset + signature.length > bytes.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[i + offset] != signature[i]) return false;
      }
      return true;
    }

    if (has(0, [0xff, 0xd8, 0xff])) return jpeg;
    if (has(0, [137, 80, 78, 71, 13, 10, 26, 10])) return png;
    if (has(0, 'RIFF'.codeUnits) && has(8, 'WEBP'.codeUnits)) return webp;
    if (has(0, 'GIF87a'.codeUnits) || has(0, 'GIF89a'.codeUnits)) return gif;
    if (has(4, 'ftyp'.codeUnits)) return mp4;
    if (has(0, [0x1a, 0x45, 0xdf, 0xa3])) return webm;
    return null;
  }
}

typedef LocalMediaProbe = ({int width, int height, int? durationMs});
typedef LocalMediaTag = ({String name, String category});

typedef LocalMediaExactMatch = ({PostOrigin origin, String postId});
typedef LocalMediaSimilarMatch = ({
  PostOrigin origin,
  String postId,
  double score,
});

typedef LocalMediaEnrichment = ({
  List<LocalMediaTag> tags,
  Rating rating,
  String? source,
  Set<LocalMediaExactMatch> matches,
});

enum LocalMediaEnrichmentResult { updated, unchanged, skipped }

class LocalMediaItem {
  const LocalMediaItem({
    required this.id,
    required this.reference,
    required this.md5,
    required this.format,
    required this.byteSize,
    required this.importedAt,
    required this.probe,
    required this.tags,
    required this.rating,
    this.createdAt,
    this.source,
    this.sourceMd5,
    this.editorMade = false,
    this.metadataRevision = 0,
  });

  final int id;
  final LocalMediaReference reference;
  final String md5;
  final LocalMediaFormat format;
  final int byteSize;
  final DateTime importedAt;
  final LocalMediaProbe probe;
  final List<LocalMediaTag> tags;
  final Rating rating;
  final DateTime? createdAt;
  final String? source;
  final String? sourceMd5;
  final bool editorMade;
  final int metadataRevision;

  Post toPost() => localMediaPost(
    reference,
    id: id,
    format: format.extension,
    byteSize: byteSize,
    md5: md5,
    width: probe.width,
    height: probe.height,
    durationMs: probe.durationMs,
    createdAt: createdAt ?? importedAt,
    source: source,
    tags: tags,
    rating: rating,
  );
}

Post localMediaPost(
  LocalMediaReference reference, {
  int id = 0,
  String format = '',
  int byteSize = 0,
  String md5 = '',
  int width = 0,
  int height = 0,
  int? durationMs,
  DateTime? createdAt,
  String? source,
  List<LocalMediaTag> tags = const [],
  Rating rating = Rating.unknown,
}) => Post(
  origin: PostOrigin.forBooruType(BooruType.localMedia),
  booruData: LocalMediaPostData(reference),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: '',
    sampleImageUrl: '',
    originalImageUrl: '',
    videoThumbnailUrl: '',
    videoUrl: '',
    width: width.toDouble(),
    height: height.toDouble(),
    format: format,
    fileSize: byteSize,
    detailFacts: PostDetailFacts(
      originalByteSize: byteSize > 0 ? byteSize : null,
      originalWidth: width.toDouble(),
      originalHeight: height.toDouble(),
      originalFormat: format,
    ),
    md5: md5,
    duration: durationMs == null ? kNoduration : durationMs / 1000,
    createdAt: createdAt,
    source: PostSource.from(source),
    tags: {for (final tag in tags) tag.name},
    artistTags: {
      for (final tag in tags)
        if (tag.category == 'artist') tag.name,
    },
    characterTags: {
      for (final tag in tags)
        if (tag.category == 'character') tag.name,
    },
    copyrightTags: {
      for (final tag in tags)
        if (tag.category == 'copyright') tag.name,
    },
    rating: rating,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    score: 0,
  ),
);

LocalMediaTag normalizeLocalMediaTag(LocalMediaTag tag) {
  final name = canonicalBookmarkTag(tag.name);
  if (name.isEmpty || name.startsWith('-') || name.length > 160) {
    throw const FormatException('Invalid local tag');
  }
  return (name: name, category: tag.category);
}

final class LocalMediaCancellation {
  var _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void check() {
    if (_cancelled) throw const LocalMediaCancelled();
  }
}

final class LocalMediaCancelled implements Exception {
  const LocalMediaCancelled();
}

final class LocalMediaUnsupported implements Exception {
  const LocalMediaUnsupported();
}

final class LocalMediaLimit implements Exception {
  const LocalMediaLimit();
}

enum LocalMediaImportResult { imported, duplicate, repaired }

class LocalMediaImportBudget {
  LocalMediaImportBudget({this.maxBytes = 2 * 1024 * 1024 * 1024});

  final int maxBytes;
  var _bytesRead = 0;
  bool get exhausted => _bytesRead >= maxBytes;

  void record(int bytes) {
    _bytesRead += bytes;
    if (_bytesRead > maxBytes) throw const LocalMediaLimit();
  }

  static const imageBytes = 64 * 1024 * 1024;
  static const videoBytes = 256 * 1024 * 1024;
  static const maxFiles = 1000;
}
