/// One frame of an ugoira's frame sequence.
class PixivUgoiraFrame {
  const PixivUgoiraFrame({this.file, this.delay});

  factory PixivUgoiraFrame.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivUgoiraFrame();

    return PixivUgoiraFrame(
      file: json['file'] as String?,
      delay: json['delay'] as int?,
    );
  }

  final String? file;

  /// Frame duration in milliseconds.
  final int? delay;
}

/// Response of `/v1/ugoira/metadata` (body key `ugoira_metadata`).
class PixivUgoiraMetadataDto {
  const PixivUgoiraMetadataDto({this.zipUrlMedium, this.frames = const []});

  factory PixivUgoiraMetadataDto.fromJson(Map<String, dynamic> json) {
    final zipUrls = json['zip_urls'] as Map<String, dynamic>?;

    return PixivUgoiraMetadataDto(
      zipUrlMedium: zipUrls?['medium'] as String?,
      frames: _parseFrames(json['frames']),
    );
  }

  final String? zipUrlMedium;
  final List<PixivUgoiraFrame> frames;

  static List<PixivUgoiraFrame> _parseFrames(dynamic json) {
    if (json is! List) return const [];

    return json
        .whereType<Map<String, dynamic>>()
        .map(PixivUgoiraFrame.fromJson)
        .toList();
  }
}
