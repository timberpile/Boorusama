// Flutter imports:
import 'package:flutter/painting.dart';

// Project imports:
import '../../../boorus/booru/types.dart';
import '../../../tags/tag/colors.dart';
import '../types/bookmark_tag_index.dart';

/// Resolves only locally available metadata, using each bookmark's own site.
/// Conflicting known categories remain neutral in a mixed-site collection.
Future<Color?> resolveBookmarkTagColor(
  BookmarkTagEntry entry, {
  required TagColors colors,
  required Future<String?> Function(String siteUrl, String tag) categoryLookup,
  required TagColorGenerator? Function(BooruType type) colorGenerator,
}) async {
  final resolved = <Color>{};
  for (final source in entry.sources.entries) {
    if (source.value.isNotEmpty) {
      for (final category in source.value) {
        final color = switch (category) {
          'artist' => colors.artist,
          'character' => colors.character,
          'copyright' => colors.copyright,
          _ => null,
        };
        if (color != null) resolved.add(color);
      }
    } else {
      try {
        String? category;
        // Preserve installation paths. Only vary the trailing slash; a
        // host-only fallback could read another booru's category on that host.
        final site = source.key.url;
        if (site.isEmpty) continue;
        final withoutSlash = site.endsWith('/')
            ? site.substring(0, site.length - 1)
            : site;
        final urls = {site, '$withoutSlash/', withoutSlash};
        for (final url in urls) {
          category = await categoryLookup(url, entry.tag);
          if (category != null && category.isNotEmpty) break;
        }
        if (category == null || category.isEmpty || category == 'unknown') {
          continue;
        }
        final color = colorGenerator(source.key.booruType)?.generateColor(
          TagColorOptions(tagType: category, colors: colors),
        );
        if (color != null) resolved.add(color);
      } catch (_) {
        // A missing/unavailable cache must not disable offline autocomplete.
      }
    }
    if (resolved.length > 1) return null;
  }
  return resolved.singleOrNull;
}
