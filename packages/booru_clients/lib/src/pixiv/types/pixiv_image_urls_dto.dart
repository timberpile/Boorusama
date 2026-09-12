/// The illust's own `image_urls`. Deliberately has no `original` key — see
/// [PixivMetaSinglePage] and [PixivMetaPageImageUrls] for that.
class PixivImageUrls {
  const PixivImageUrls({this.squareMedium, this.medium, this.large});

  factory PixivImageUrls.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivImageUrls();

    return PixivImageUrls(
      squareMedium: json['square_medium'] as String?,
      medium: json['medium'] as String?,
      large: json['large'] as String?,
    );
  }

  final String? squareMedium;
  final String? medium;
  final String? large;
}

/// Present only when `page_count == 1`; carries the single original URL.
class PixivMetaSinglePage {
  const PixivMetaSinglePage({this.originalImageUrl});

  factory PixivMetaSinglePage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivMetaSinglePage();

    return PixivMetaSinglePage(
      originalImageUrl: json['original_image_url'] as String?,
    );
  }

  final String? originalImageUrl;
}

/// Per-page image URLs for a `page_count > 1` illust, unlike the top-level
/// [PixivImageUrls] this one DOES carry `original`.
class PixivMetaPageImageUrls {
  const PixivMetaPageImageUrls({
    this.squareMedium,
    this.medium,
    this.large,
    this.original,
  });

  factory PixivMetaPageImageUrls.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivMetaPageImageUrls();

    return PixivMetaPageImageUrls(
      squareMedium: json['square_medium'] as String?,
      medium: json['medium'] as String?,
      large: json['large'] as String?,
      original: json['original'] as String?,
    );
  }

  final String? squareMedium;
  final String? medium;
  final String? large;
  final String? original;
}

class PixivMetaPage {
  const PixivMetaPage({this.imageUrls});

  factory PixivMetaPage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivMetaPage();

    return PixivMetaPage(
      imageUrls: PixivMetaPageImageUrls.fromJson(
        json['image_urls'] as Map<String, dynamic>?,
      ),
    );
  }

  final PixivMetaPageImageUrls? imageUrls;
}
