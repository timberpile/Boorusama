// Package imports:
import 'package:equatable/equatable.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../boorus/booru/types.dart';
import '../../../posts/post/types.dart';
import '../../../posts/rating/types.dart';
import '../../../posts/sources/types.dart';

class Bookmark extends Equatable with ImageInfoMixin, TagListCheckMixin {
  factory Bookmark({
    required int id,
    required int booruId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String thumbnailUrl,
    required String sampleUrl,
    required String originalUrl,
    required String sourceUrl,
    required double width,
    required double height,
    required String md5,
    required Set<String> tags,
    required String? realSourceUrl,
    required String? format,
    required ImageUrlResolver imageUrlResolver,
    required int? postId,
    required Map<String, String> metadata,
  }) {
    final resolvedThumbnail = imageUrlResolver.resolveThumbnailUrl(
      thumbnailUrl,
    );
    final resolvedSample = imageUrlResolver.resolvePreviewUrl(sampleUrl);
    final resolvedOriginal = imageUrlResolver.resolveImageUrl(originalUrl);
    final effectiveFormat = format ?? _extension(resolvedOriginal);
    final isVideo = isFormatVideo(effectiveFormat);
    final booruType = BooruType.fromLegacyId(booruId);
    final post = Post(
      origin: PostOrigin.fromSource(
        booruType: booruType,
        booruId: booruId,
        source: sourceUrl,
      ),
      core: PostCoreData(
        id: postId ?? id,
        thumbnailImageUrl: resolvedThumbnail,
        sampleImageUrl: resolvedSample,
        originalImageUrl: resolvedOriginal,
        videoUrl: isVideo ? resolvedOriginal : '',
        videoThumbnailUrl: isVideo ? resolvedThumbnail : '',
        width: width,
        height: height,
        format: effectiveFormat,
        md5: md5,
        fileSize: 0,
        duration: kNoduration,
        tags: tags,
        rating: Rating.unknown,
        hasComment: false,
        isTranslated: false,
        hasParentOrChildren: false,
        source: PostSource.from(realSourceUrl),
        score: 0,
        metadata: _metadataFromMap(metadata),
      ),
      booruData: LegacyPostData(
        typeKey: 'legacy_${booruType.name}',
        custom: const {},
      ),
    );
    final snapshot = const StoredPostCodec().encode(post);

    return Bookmark.fromSnapshot(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      snapshot: snapshot,
      post: post,
      postId: postId,
      sourceUrl: sourceUrl,
    );
  }

  const Bookmark.fromSnapshot({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.snapshot,
    required this.post,
    required this.postId,
    String? sourceUrl,
  }) : _sourceUrl = sourceUrl;

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    required ImageUrlResolver imageUrlResolver,
  }) => Bookmark(
    id: json['id'] as int,
    booruId: json['booruId'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    thumbnailUrl: json['thumbnailUrl'] as String,
    sampleUrl: json['sampleUrl'] as String,
    originalUrl: json['originalUrl'] as String,
    sourceUrl: json['sourceUrl'] as String,
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    md5: json['md5'] as String,
    tags: _parseTags(json['tags']),
    realSourceUrl: json['realSourceUrl'] as String?,
    format: json['format'] as String?,
    imageUrlResolver: imageUrlResolver,
    postId: json['postId'] as int?,
    metadata:
        (json['metadata'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ??
        const {},
  );

  final int id;
  int get localId => id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final StoredPostSnapshot snapshot;
  final Post post;
  final int? postId;
  final String? _sourceUrl;

  int get booruId => snapshot.origin.booruTypeId;
  String get sourceUrl =>
      _sourceUrl ??
      (snapshot.origin.sourceHost.isEmpty
          ? ''
          : 'https://${snapshot.origin.sourceHost}');
  @override
  double get width => post.width;
  @override
  double get height => post.height;
  String get md5 => post.md5;
  @override
  Set<String> get tags => post.tags;
  String? get realSourceUrl => post.source.url;
  String? get format => post.format;
  Map<String, String> get metadata => toMetadata(post.metadata);
  int? get metadataPage => post.metadata?.page;
  int? get metadataLimit => post.metadata?.limit;
  String? get metadataSearch => post.metadata?.search;
  String get originalUrl => post.originalImageUrl;
  String get sampleUrl => post.sampleImageUrl;
  String get thumbnailUrl => post.thumbnailImageUrl;
  bool get isVideo => post.isVideo;

  BookmarkUniqueId get uniqueId => BookmarkUniqueId(
    booruId: booruId,
    url: originalUrl,
  );

  static final empty = Bookmark(
    id: -1,
    booruId: -10,
    createdAt: DateTime(1),
    updatedAt: DateTime(1),
    thumbnailUrl: '',
    sampleUrl: '',
    originalUrl: '',
    sourceUrl: '',
    width: -1,
    height: -1,
    md5: '',
    tags: const {},
    realSourceUrl: null,
    format: null,
    imageUrlResolver: const DefaultImageUrlResolver(),
    postId: null,
    metadata: const {},
  );

  static Map<String, String> toMetadata(PostMetadata? metadata) => {
    if (metadata?.page case final value?) 'page': '$value',
    if (metadata?.limit case final value?) 'limit': '$value',
    'search': ?metadata?.search,
  };

  Bookmark copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailUrl,
    String? sampleUrl,
    String? originalUrl,
    String? sourceUrl,
    double? width,
    double? height,
    String? md5,
    Set<String>? tags,
    String? Function()? realSourceUrl,
    String? Function()? format,
    int? Function()? postId,
    Map<String, String>? metadata,
    ImageUrlResolver? imageUrlResolver,
    StoredPostSnapshot? snapshot,
    Post? post,
  }) {
    final changesLegacyPost =
        thumbnailUrl != null ||
        sampleUrl != null ||
        originalUrl != null ||
        width != null ||
        height != null ||
        md5 != null ||
        tags != null ||
        realSourceUrl != null ||
        format != null ||
        postId != null ||
        metadata != null ||
        imageUrlResolver != null;
    if (!changesLegacyPost) {
      return Bookmark.fromSnapshot(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        snapshot: snapshot ?? this.snapshot,
        post: post ?? this.post,
        postId: post?.id ?? this.postId,
        sourceUrl: sourceUrl ?? this.sourceUrl,
      );
    }

    return Bookmark(
      id: id ?? this.id,
      booruId: booruId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      sampleUrl: sampleUrl ?? this.sampleUrl,
      originalUrl: originalUrl ?? this.originalUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      md5: md5 ?? this.md5,
      tags: tags ?? this.tags,
      realSourceUrl: realSourceUrl != null
          ? realSourceUrl()
          : this.realSourceUrl,
      format: format != null
          ? format()
          : originalUrl != null
          ? null
          : this.format,
      imageUrlResolver: imageUrlResolver ?? const DefaultImageUrlResolver(),
      postId: postId != null ? postId() : this.postId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'booruId': booruId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'thumbnailUrl': thumbnailUrl,
    'sampleUrl': sampleUrl,
    'originalUrl': originalUrl,
    'sourceUrl': sourceUrl,
    'width': width,
    'height': height,
    'md5': md5,
    'tags': tags.toList(),
    'realSourceUrl': realSourceUrl,
    'format': format,
    'postId': postId,
    'metadata': Map<String, String>.from(metadata),
  };

  @override
  List<Object?> get props => [id, createdAt, updatedAt, snapshot, postId];
}

typedef BookmarkEntry = Bookmark;

PostMetadata? _metadataFromMap(Map<String, String> metadata) {
  if (metadata.isEmpty) return null;
  return PostMetadata(
    page: int.tryParse(metadata['page'] ?? ''),
    limit: int.tryParse(metadata['limit'] ?? ''),
    search: metadata['search'],
  );
}

String _extension(String path) {
  final uri = Uri.tryParse(path);
  final segment = uri?.pathSegments.lastOrNull ?? path;
  final dot = segment.lastIndexOf('.');
  return dot < 0 ? '' : segment.substring(dot + 1);
}

Set<String> _parseTags(dynamic tags) => switch (tags) {
  final String value => tryDecodeJson(value).fold(
    (_) => const {},
    _parseJsonTags,
  ),
  final List values => values.map((value) => value.toString()).toSet(),
  _ => const {},
};

Set<String> _parseJsonTags(dynamic tags) => switch (tags) {
  final List values => values.map((value) => value.toString()).toSet(),
  _ => const {},
};

enum BookmarkGetError { nullField, databaseClosed, unknown }

typedef BookmarksOrError = TaskEither<BookmarkGetError, List<Bookmark>>;

class BookmarkUniqueId extends Equatable {
  const BookmarkUniqueId({
    required this.booruId,
    required this.url,
  });

  BookmarkUniqueId.fromPost(Post post, this.booruId)
    : url = post.originalImageUrl;

  final int booruId;
  final String url;

  @override
  List<Object?> get props => [booruId, url];
}
