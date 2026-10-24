import 'package:html/dom.dart';

typedef RbImageMetadata = ({
  String? originalUrl,
  int? width,
  int? height,
  int? fileSize,
});

/// Reads explicitly identified original media from an already loaded detail page.
/// Display dimensions and rounded human-readable file sizes are not original facts.
RbImageMetadata parseRbImageMetadata(
  Document document, {
  required String displayedUrl,
  required String? Function(String?) resolveUrl,
}) {
  final image = document.querySelector('#image');
  final candidates = <String>{};
  var hasOriginalReference = false;
  void addOriginal(String? value) {
    if (value == null || value.trim().isEmpty) return;
    hasOriginalReference = true;
    final resolved = resolveUrl(value);
    if (resolved != null) candidates.add(resolved);
  }

  addOriginal(image?.attributes['data-original']);
  addOriginal(image?.attributes['data-original-url']);
  // A generic label in a comment or source link is not a media control.
  final metadataLinks = document.querySelectorAll(
    '#post-info a[href], #stats a[href], #tagLink a[href]',
  ).toSet();
  for (final link in document.querySelectorAll('a[href]')) {
    final label = link.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final explicitId = const {'highres', 'original-image', 'original-file'}
        .contains(link.id.toLowerCase());
    final explicitLabel = RegExp(
      r'^(?:original(?: image| file)?|download original)(?:\s*\([^)]*\))?$',
      caseSensitive: false,
    ).hasMatch(label);
    if (explicitId || (explicitLabel && metadataLinks.contains(link))) {
      addOriginal(link.attributes['href']);
    }
  }

  // Preserve the existing direct-image fallback, but never relabel a known
  // sample or an invalid/ambiguous explicit original reference as the original.
  final path = Uri.tryParse(displayedUrl)?.path.toLowerCase() ?? '';
  final original = candidates.length == 1
      ? candidates.single
      : !hasOriginalReference && !path.contains('/samples/')
      ? displayedUrl
      : null;
  if (original == null) {
    return (originalUrl: null, width: null, height: null, fileSize: null);
  }

  int? positive(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  var width = positive(image?.attributes['data-original-width']);
  var height = positive(image?.attributes['data-original-height']);
  // Search each supported container independently: dimensions and byte counts
  // need not share a container, but fragments must not form a synthetic pair.
  final metadataTexts = [
    for (final selector in const ['#post-info', '#stats', '#tagLink'])
      if (document.querySelector(selector) case final info?)
        info.text.replaceAll(RegExp(r'\s+'), ' '),
  ];
  RegExpMatch? metadataMatch(RegExp pattern) {
    for (final text in metadataTexts) {
      final match = pattern.firstMatch(text);
      if (match != null) return match;
    }
    return null;
  }

  final dimensions = metadataMatch(RegExp(
    r'\b(?:Original (?:Size|Resolution)|Resolution|Dimensions|Size)\s*:\s*(\d{1,7})\s*[x×]\s*(\d{1,7})\b',
    caseSensitive: false,
  ));
  // Do not combine unrelated half-pairs from different representations.
  if (width == null || height == null) {
    width = positive(dimensions?.group(1));
    height = positive(dimensions?.group(2));
  }
  if (width == null || height == null) {
    width = null;
    height = null;
  }

  final byteText = image?.attributes['data-original-file-size'] ??
      metadataMatch(RegExp(
        r'\bFile size\s*:\s*(\d{1,16})\s*(?:bytes|B)\b',
        caseSensitive: false,
      ))?.group(1);
  final bytes = int.tryParse(byteText?.trim() ?? '');
  return (
    originalUrl: original,
    width: width,
    height: height,
    fileSize: bytes != null && bytes >= 0 ? bytes : null,
  );
}
