import 'search_refresh_request_gate.dart';

/// Thumbnail-only work has no dependency on chronological tracking or storage.
class TopicPreviewLoader {
  TopicPreviewLoader({int concurrency = 2})
    : _gate = SearchRefreshRequestGate(limit: concurrency);

  final SearchRefreshRequestGate _gate;

  Future<List<String>> load({
    required Future<Iterable<String>> Function() fetch,
    required bool Function() canStart,
  }) => _gate.run(() async {
    if (!canStart()) return const [];
    final urls = await fetch();
    if (!canStart()) return const [];
    final unique = <String>{};
    for (final url in urls) {
      final uri = Uri.tryParse(url.trim());
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty)
        continue;
      unique.add(uri.toString());
      if (unique.length == 4) break;
    }
    return List.unmodifiable(unique);
  });
}
