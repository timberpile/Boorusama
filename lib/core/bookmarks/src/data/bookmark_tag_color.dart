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
  TagColors? Function(BooruType type)? colorsForType,
  Color Function(Color color)? transformColor,
}) async {
  final resolved = <Color>{};
  void addColor(Color? color) {
    if (color != null) resolved.add(transformColor?.call(color) ?? color);
  }

  for (final source in entry.sources.entries) {
    final sourceColors = colorsForType?.call(source.key.booruType) ?? colors;
    if (source.value.isNotEmpty) {
      // Snapshot categories are canonical names, not engine-specific codes.
      for (final category in source.value) {
        final color = switch (category) {
          'artist' => sourceColors.artist,
          'character' => sourceColors.character,
          'copyright' => sourceColors.copyright,
          'general' => sourceColors.general,
          'meta' => sourceColors.meta,
          _ => null,
        };
        addColor(color);
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
          if (category != null) break;
        }
        if (category == null || category == 'unknown') {
          continue;
        }
        addColor(
          colorGenerator(source.key.booruType)?.generateColor(
            TagColorOptions(tagType: category, colors: sourceColors),
          ),
        );
      } catch (_) {
        // A missing/unavailable cache must not disable offline autocomplete.
      }
    }
    if (resolved.length > 1) return null;
  }
  return resolved.singleOrNull;
}
