import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import '../../gelbooru/types/types.dart';
import '../types.dart';

List<TagDto> parseRbTagsHtml(Response response, Map<String, dynamic> context) {
  final html = response.data as String;
  final document = parse(html);
  final tagLink = document.getElementById('tagLink');

  if (tagLink == null) return [];

  final tags = <TagDto>[];

  // Extract different tag types
  final metaTags = tagLink.querySelectorAll('a.metadata');
  final generalTags = tagLink.querySelectorAll('a.tag-type-general');
  final modelTags = tagLink.querySelectorAll('a.model');
  final artistTags = tagLink.querySelectorAll('a.tag-type-artist');
  final copyrightTags = tagLink.querySelectorAll('a.tag-type-copyright');
  final characterTags = tagLink.querySelectorAll('a.tag-type-character');

  // Parse each tag type
  tags.addAll(_parseRbTagElements(artistTags, 1));
  tags.addAll(_parseRbTagElements(copyrightTags, 3));
  tags.addAll(_parseRbTagElements(characterTags, 4));
  tags.addAll(_parseRbTagElements(generalTags, 0));
  tags.addAll(_parseRbTagElements(metaTags, 5));
  tags.addAll(_parseRbTagElements(modelTags, 1)); // Treat models as artists

  return tags;
}

List<TagDto> _parseRbTagElements(List<Element> elements, int type) {
  return elements.map((element) {
    final name = element.text.trim().replaceAll(' ', '_');
    final href = element.attributes['href'] ?? '';

    // Try to extract count from URL if available (usually not present in post view)
    final countMatch = RegExp(r'count=(\d+)').firstMatch(href);
    final count = countMatch != null
        ? int.tryParse(countMatch.group(1) ?? '')
        : null;

    return TagDto(
      id: null, // Not available in HTML
      name: name,
      count: count,
      type: type,
      ambiguous: null, // Not available
    );
  }).toList();
}

PostV2Dto? parseRbPostHtml(
  Response response,
  Map<String, dynamic> context,
) {
  final data = response.data;
  if (data is! String) return null;
  final html = data;
  final baseUrl = switch (context['baseUrl']) {
    final String value => value.trim(),
    _ => '',
  };
  final document = parse(html);

  final postId = _extractPostId(document);
  if (postId == null) return null;

  // Try to get file URL from video or image
  String? fileUrl;

  // Check for video first
  final videoSource = document.querySelector('#gelcomVideoPlayer source');
  if (videoSource != null) {
    fileUrl = videoSource.attributes['src'];
  } else {
    // Check for image
    final imageElement = document.querySelector('#image');
    fileUrl = imageElement?.attributes['src'];
  }

  fileUrl = _resolveRbMediaUrl(fileUrl, baseUrl);
  if (fileUrl == null) return null;

  final fileUri = Uri.tryParse(fileUrl);
  final filePath = fileUri?.path ?? '';

  // Extract hash and directory
  final hashMatch = RegExp(r'/([a-f0-9]{32})\.').firstMatch(filePath);
  final hash = hashMatch?.group(1);

  final directoryMatch = RegExp(
    r'/images/([a-f0-9]{2})/([a-f0-9]{2})/',
  ).firstMatch(filePath);
  final directory = directoryMatch != null
      ? '${directoryMatch.group(1)}/${directoryMatch.group(2)}'
      : null;

  // Extract filename for image field
  final image = fileUri?.pathSegments.lastOrNull;

  // Extract other data
  final scoreElement = document.querySelector('#psc$postId');
  final score = int.tryParse(scoreElement?.text ?? '');

  final sourceInput = document.querySelector('input[name="source"]');
  final source = sourceInput?.attributes['value'] ?? '';

  // Extract owner/uploader information
  final owner = _extractOwner(document);

  // Extract change/upload timestamp
  final change = _extractChangeTimestamp(document);

  final tags = _extractTags(document);

  // Build preview URL
  final previewUrl = hash != null && directory != null
      ? _resolveRbMediaUrl(
              '/thumbnails/$directory/thumbnail_$hash.jpg',
              baseUrl,
            ) ??
            ''
      : '';

  return PostV2Dto(
    id: postId,
    fileUrl: fileUrl,
    sampleUrl: fileUrl,
    previewUrl: previewUrl,
    directory: directory,
    hash: hash,
    image: image,
    tags: tags,
    score: score,
    source: source,
    owner: owner,
    change: change,
  );
}

int? _extractPostId(Document document) {
  // Try multiple methods to extract post ID
  final hiddenInput = document.querySelector('input[name="id"]');
  if (hiddenInput != null) {
    return int.tryParse(hiddenInput.attributes['value'] ?? '');
  }

  // Fallback: extract from script or other elements
  final scriptText = document.querySelector('script')?.text ?? '';
  final match = RegExp(r"post_vote\('(\d+)'").firstMatch(scriptText);
  return match != null ? int.tryParse(match.group(1) ?? '') : null;
}

String _extractTags(Document document) {
  // Get tags from textarea if available (more complete)
  final tagsTextarea = document.querySelector('textarea[name="tags"]');
  if (tagsTextarea != null && tagsTextarea.text.isNotEmpty) {
    return tagsTextarea.text.trim();
  }

  // Fallback to extracting from links
  final tagElements = document.querySelectorAll(
    'a[class*="tag-"], a.metadata, a.copyright, a.model',
  );
  final tags = tagElements
      .map((e) => e.text.trim().replaceAll(' ', '_'))
      .where((tag) => tag.isNotEmpty)
      .toSet() // Remove duplicates
      .join(' ');

  return tags;
}

String? _extractOwner(Document document) {
  // Look for uploader in the post info section
  final uploaderLink = document.querySelector('a[href*="profile&id="]');
  return uploaderLink?.text.trim();
}

int? _extractChangeTimestamp(Document document) {
  // Look for posted date text
  final postInfo = document.querySelector('#tagLink')?.text ?? '';
  final dateMatch = RegExp(r'Posted at ([^by]+) by').firstMatch(postInfo);

  if (dateMatch != null) {
    final dateString = dateMatch.group(1)?.trim();
    if (dateString != null) {
      // Try to parse date - this is a simple implementation
      // Format appears to be "Sep, 13 2025"
      try {
        final parts = dateString.split(' ');
        if (parts.length >= 3) {
          final month = _monthNameToNumber(parts[0].replaceAll(',', ''));
          final day = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);

          if (month != null && day != null && year != null) {
            final dateTime = DateTime(year, month, day);
            return dateTime.millisecondsSinceEpoch ~/ 1000; // Unix timestamp
          }
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }
  }

  return null;
}

const _months = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

int? _monthNameToNumber(String monthName) {
  return _months[monthName];
}

GelbooruV2Posts parseRbPostsHtml(
  Response response,
  Map<String, dynamic> context,
) {
  final responseData = response.data;
  if (responseData is! String) return const GelbooruV2Posts.empty();
  final html = responseData;
  final baseUrl = switch (context['baseUrl']) {
    final String value => value.trim(),
    _ => '',
  };
  final document = parse(html);
  final data = document.getElementsByClassName('thumb');

  final posts = data
      .map((element) {
        final linkElement = element.querySelector('a[id]');
        final imageElement = linkElement?.querySelector('img');
        if (linkElement == null || imageElement == null) return null;

        final idMatch = RegExp(r'^p(\d+)$').firstMatch(
          linkElement.attributes['id'] ?? '',
        );
        final id = int.tryParse(idMatch?.group(1) ?? '');
        final thumbUrl = _resolveRbMediaUrl(
          imageElement.attributes['src'],
          baseUrl,
        );
        if (id == null || thumbUrl == null) return null;

        final posterUrl = thumbUrl
            .replaceFirst('thumbs', 'img')
            .replaceFirst('thumbnails', 'images')
            .replaceFirst('thumbnail_', '');

        final tags = imageElement.attributes['title'];
        final isVideoPreview =
            tags
                ?.split(',')
                .map((tag) => tag.trim().toLowerCase())
                .contains('video') ??
            false;
        final md5 = RegExp(
          r'thumbnail_([a-f0-9]{32})\.',
        ).firstMatch(Uri.parse(thumbUrl).path)?.group(1);

        // Parse tags for score and rating
        final tagList = tags?.split(' ') ?? <String>[];
        int? score;
        String? rating;

        for (final tag in tagList) {
          if (tag.startsWith('score:')) {
            score = int.tryParse(tag.replaceAll('score:', ''));
          } else if (tag.startsWith('rating:')) {
            rating = tag.replaceAll('rating:', '');
          }
        }

        final cleanTags = tagList
            .where((e) => e.isNotEmpty)
            .where((e) => !e.startsWith('rating:'))
            .where((e) => !e.startsWith('score:'))
            .join(' ');

        return PostV2Dto(
          id: id,
          fileUrl: isVideoPreview ? posterUrl : thumbUrl,
          sampleUrl: isVideoPreview ? posterUrl : thumbUrl,
          previewUrl: thumbUrl,
          tags: cleanTags,
          hash: md5,
          rating: rating,
          score: score,
          isVideoPreview: isVideoPreview,
        );
      })
      .nonNulls
      .toList();

  final lastPagePidStr = _parseLastPagePid(document);
  final lastPageOffset = lastPagePidStr != null
      ? int.tryParse(lastPagePidStr)
      : null;

  final estimatedCount = lastPageOffset != null
      ? estimateTotalPagesFromOffset(
          lastPageOffset: lastPageOffset,
          fixedLimit: 42,
        )
      : null;

  return GelbooruV2Posts(
    posts: posts,
    count: estimatedCount ?? posts.length,
  );
}

String? _resolveRbMediaUrl(String? value, String baseUrl) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null) return null;

  final resolved = switch (uri) {
    Uri(scheme: 'http' || 'https', host: final host) when host.isNotEmpty =>
      uri,
    Uri(scheme: '') => switch (Uri.tryParse(baseUrl)) {
      final Uri base
          when (base.scheme == 'http' || base.scheme == 'https') &&
              base.host.isNotEmpty =>
        base.resolveUri(uri),
      _ => null,
    },
    _ => null,
  };

  return resolved?.toString();
}

String? _parseLastPagePid(Document document) {
  final lastPageLink = document.querySelector('a[alt="last page"]');

  if (lastPageLink != null) {
    final href = lastPageLink.attributes['href'];
    if (href != null) {
      final pidRegex = RegExp(r'pid=(\d+)');
      final match = pidRegex.firstMatch(href);
      return match?.group(1);
    }
  }

  return null;
}
