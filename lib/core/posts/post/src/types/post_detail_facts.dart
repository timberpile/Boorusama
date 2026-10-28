import 'package:equatable/equatable.dart';

/// Source evidence for Details, independent of operational media fallbacks.
/// An empty contract is also the conservative interpretation of old snapshots.
final class PostDetailFacts extends Equatable {
  const PostDetailFacts({
    int? originalByteSize,
    double? originalWidth,
    double? originalHeight,
    String? originalFormat,
    this.score,
    int? favoriteCount,
    int? commentCount,
    String? description,
  }) : _originalByteSize = originalByteSize,
       _originalWidth = originalWidth,
       _originalHeight = originalHeight,
       _originalFormat = originalFormat,
       _favoriteCount = favoriteCount,
       _commentCount = commentCount,
       _description = description;

  final int? _originalByteSize;
  final double? _originalWidth;
  final double? _originalHeight;
  final String? _originalFormat;
  final int? score;
  final int? _favoriteCount;
  final int? _commentCount;
  final String? _description;

  int? get originalByteSize => _nonnegative(_originalByteSize);
  double? get originalWidth => _dimension(_originalWidth);
  double? get originalHeight => _dimension(_originalHeight);
  String? get originalFormat {
    final value = _text(_originalFormat)
        ?.replaceFirst(RegExp(r'^\.'), '')
        .toLowerCase();
    return value != null && RegExp(r'^[a-z0-9]+$').hasMatch(value)
        ? value
        : null;
  }

  int? get favoriteCount => _nonnegative(_favoriteCount);
  int? get commentCount => _nonnegative(_commentCount);
  String? get description => _text(_description);

  Map<String, Object?> toJson() => {
    'originalByteSize': ?originalByteSize,
    'originalWidth': ?originalWidth,
    'originalHeight': ?originalHeight,
    'originalFormat': ?originalFormat,
    'score': ?score,
    'favoriteCount': ?favoriteCount,
    'commentCount': ?commentCount,
    'description': ?description,
  };

  factory PostDetailFacts.fromJson(Object? value) {
    if (value == null) return const PostDetailFacts();
    if (value is! Map || value.keys.any((k) => k is! String)) {
      throw const FormatException('Invalid post detail facts');
    }
    return PostDetailFacts(
      originalByteSize: value['originalByteSize'] as int?,
      originalWidth: (value['originalWidth'] as num?)?.toDouble(),
      originalHeight: (value['originalHeight'] as num?)?.toDouble(),
      originalFormat: value['originalFormat'] as String?,
      score: value['score'] as int?,
      favoriteCount: value['favoriteCount'] as int?,
      commentCount: value['commentCount'] as int?,
      description: value['description'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    originalByteSize,
    originalWidth,
    originalHeight,
    originalFormat,
    score,
    favoriteCount,
    commentCount,
    description,
  ];
}

int? _nonnegative(int? value) => value != null && value >= 0 ? value : null;
double? _dimension(double? value) =>
    value != null &&
        value.isFinite &&
        value > 0 &&
        value == value.truncateToDouble()
    ? value
    : null;
String? _text(String? value) =>
    value != null && value.trim().isNotEmpty ? value.trim() : null;

/// Only call for a URL the source identifies as its original resource.
String? originalFormatFromUrl(String? url) =>
    RegExp(r'\.([a-zA-Z0-9]+)$')
        .firstMatch(Uri.tryParse(url ?? '')?.path ?? '')
        ?.group(1)
        ?.toLowerCase();

String? originalFormatFromMime(String? mime) {
  final parts = mime?.toLowerCase().split('/');
  if (parts == null ||
      parts.length != 2 ||
      !{'image', 'video'}.contains(parts.first))
    return null;
  final subtype = parts.last.split(';').first.trim();
  return switch (subtype) {
    'jpeg' => 'jpg',
    'svg+xml' => 'svg',
    'quicktime' => 'mov',
    'x-matroska' => 'mkv',
    'png' ||
    'gif' ||
    'webp' ||
    'avif' ||
    'bmp' ||
    'heic' ||
    'mp4' ||
    'webm' => subtype,
    _ => null,
  };
}
