import '../../boorus/booru/types.dart';
import '../../tags/autocompletes/types.dart';

/// Only documented entity endpoints belong here. A missing endpoint never
/// falls back to ordinary tag autocomplete or to an unfiltered user listing.
class SearchEntityEndpoint {
  const SearchEntityEndpoint(
    this.path,
    this.parameters, {
    this.poolIds = false,
  });

  final String path;
  final Map<String, dynamic> parameters;
  final bool poolIds;
}

SearchEntityEndpoint? searchEntityEndpoint(
  BooruType type,
  String prefix,
  String text,
) {
  if (text.trim().length < 2 || RegExp(r'[\s\x00-\x1f]').hasMatch(text)) {
    return null;
  }
  return switch ((type, prefix)) {
    (BooruType.e621, 'user') => SearchEntityEndpoint('/users.json', {
      'search[name_matches]': '$text*',
      'search[order]': 'name',
      'limit': 8,
    }),
    (BooruType.moebooru, 'user') => SearchEntityEndpoint(
      '/user/autocomplete_name.json',
      {'term': text},
    ),
    (BooruType.szurubooru, 'user') => SearchEntityEndpoint('/api/users', {
      'query': 'name:$text* sort:name',
      'limit': 8,
      'fields': 'name',
    }),
    (BooruType.szurubooru, 'pool') => SearchEntityEndpoint('/api/pools', {
      'query': 'name:$text* sort:name',
      'limit': 8,
      'fields': 'id,names',
    }, poolIds: true),
    _ => null,
  };
}

List<AutocompleteData> parseSearchEntityResponse(
  Object? data,
  String prefix, {
  bool poolIds = false,
}) {
  final rows = switch (data) {
    final List rows => rows,
    {'results': final List rows} => rows,
    {'users': final List rows} => rows,
    _ => const <Object?>[],
  };
  final seen = <String>{};
  final result = <AutocompleteData>[];
  for (final row in rows.take(32)) {
    final name = switch (row) {
      final String name => name,
      {'name': final String name} => name,
      {'names': final List names}
          when names.isNotEmpty && names.first is String =>
        names.first as String,
      _ => null,
    };
    if (name == null || name.trim().isEmpty) continue;
    final value = poolIds
        ? switch (row) {
            {'id': final int id} when id > 0 => '$id',
            _ => null,
          }
        : name;
    if (value == null ||
        RegExp(r'[\s\x00-\x1f]').hasMatch(value) ||
        !seen.add(value)) {
      continue;
    }
    result.add(AutocompleteData(type: prefix, label: name, value: value));
    if (result.length == 8) break;
  }
  return result;
}
