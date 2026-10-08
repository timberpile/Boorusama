import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

enum ImportChangeKind { added, removed, changed }

enum ImportPreviewLimit { database, bookmarkMetadata, unknown }

enum ImportDetailPresentation { field, query, queryOrder }

final class ImportChangeCounts extends Equatable {
  const ImportChangeCounts({
    this.added = 0,
    this.removed = 0,
    this.changed = 0,
  });
  final int added;
  final int removed;
  final int changed;
  int get total => added + removed + changed;
  ImportChangeCounts operator +(ImportChangeCounts other) => ImportChangeCounts(
    added: added + other.added,
    removed: removed + other.removed,
    changed: changed + other.changed,
  );
  @override
  List<Object> get props => [added, removed, changed];
}

final class ImportChangeDetail extends Equatable {
  const ImportChangeDetail({
    required this.key,
    required this.before,
    required this.after,
    this.kind = ImportChangeKind.changed,
    this.presentation = ImportDetailPresentation.field,
  });
  final String key;
  final String before;
  final String after;
  final ImportChangeKind kind;
  final ImportDetailPresentation presentation;
  @override
  List<Object> get props => [key, before, after, kind, presentation];
}

/// Describe query membership separately from ordering, without index-based diffs.
List<ImportChangeDetail> importQueryChanges(
  List<String> before,
  List<String> after,
) {
  final removed = List.of(before);
  final added = <String>[];
  for (final query in after) {
    if (!removed.remove(query)) added.add(query);
  }
  final oldCommon = List.of(before);
  final newCommon = List.of(after);
  removed.forEach(oldCommon.remove);
  added.forEach(newCommon.remove);
  return [
    for (final query in removed)
      ImportChangeDetail(
        key: 'query',
        before: safeImportDisplayValue('query', query),
        after: '∅',
        kind: ImportChangeKind.removed,
        presentation: ImportDetailPresentation.query,
      ),
    for (final query in added)
      ImportChangeDetail(
        key: 'query',
        before: '∅',
        after: safeImportDisplayValue('query', query),
        kind: ImportChangeKind.added,
        presentation: ImportDetailPresentation.query,
      ),
    if (!const ListEquality<String>().equals(oldCommon, newCommon))
      ImportChangeDetail(
        key: 'queryOrder',
        before: oldCommon
            .map((query) => safeImportDisplayValue('query', query))
            .join('\n'),
        after: newCommon
            .map((query) => safeImportDisplayValue('query', query))
            .join('\n'),
        presentation: ImportDetailPresentation.queryOrder,
      ),
  ];
}

final class ImportChangePreviewRow extends Equatable {
  ImportChangePreviewRow({
    required this.category,
    required this.id,
    required this.kind,
    required this.label,
    this.previousLabel,
    this.profileId,
    this.membershipsAdded = 0,
    this.membershipsRemoved = 0,
    this.entityChanged = true,
    Iterable<ImportChangeDetail> details = const [],
    Iterable<ImportChangePreviewRow> children = const [],
    this.isContainer = false,
    this.limit,
    this.countOverride,
  }) : details = List.unmodifiable(details),
       children = List.unmodifiable(children);
  final String category;
  final String id;
  final ImportChangeKind kind;
  final String label;
  final String? previousLabel;
  final String? profileId;
  final int membershipsAdded;
  final int membershipsRemoved;
  final bool entityChanged;
  final List<ImportChangeDetail> details;
  final List<ImportChangePreviewRow> children;
  final bool isContainer;
  final ImportPreviewLimit? limit;
  final ImportChangeCounts? countOverride;
  ImportChangeCounts get counts =>
      (countOverride ??
          ImportChangeCounts(
            added:
                membershipsAdded +
                (kind == ImportChangeKind.added && entityChanged ? 1 : 0),
            removed:
                membershipsRemoved +
                (kind == ImportChangeKind.removed && entityChanged ? 1 : 0),
            changed: kind == ImportChangeKind.changed && entityChanged ? 1 : 0,
          )) +
      children.fold(const ImportChangeCounts(), (sum, row) => sum + row.counts);
  @override
  List<Object?> get props => [
    category,
    id,
    kind,
    label,
    previousLabel,
    profileId,
    membershipsAdded,
    membershipsRemoved,
    entityChanged,
    details,
    children,
    isContainer,
    limit,
    countOverride,
  ];
}

/// Compare raw values before redacting, so different secrets remain visible as a change.
List<ImportChangeDetail> importFieldChanges(Object? before, Object? after) {
  final old = _flatten(before), next = _flatten(after);
  return [
    for (final key in {...old.keys, ...next.keys})
      if (!const DeepCollectionEquality().equals(old[key], next[key]) ||
          old.containsKey(key) != next.containsKey(key))
        ImportChangeDetail(
          key: key,
          kind: !old.containsKey(key) || old[key] == null
              ? ImportChangeKind.added
              : !next.containsKey(key) || next[key] == null
              ? ImportChangeKind.removed
              : ImportChangeKind.changed,
          before: safeImportDisplayValue(key, old[key]),
          after: safeImportDisplayValue(key, next[key]),
        ),
  ];
}

Map<String, Object?> _flatten(Object? value, [String prefix = '']) {
  if (prefix.isEmpty && value == null) return {};
  if (value is Map && value.isNotEmpty) {
    return {
      for (final entry in value.entries)
        ..._flatten(
          entry.value,
          prefix.isEmpty ? entry.key.toString() : '$prefix.${entry.key}',
        ),
    };
  }
  if (value is List && value.isNotEmpty) {
    return {
      for (final (index, item) in value.indexed)
        ..._flatten(item, '$prefix[$index]'),
    };
  }
  return {prefix: value};
}

final _secretKey = RegExp(
  r'api.?key|access.?key|pass|pwd|secret|token|cookie|auth|signature|credential|login|username|header',
  caseSensitive: false,
);
String safeImportDisplayValue(String key, Object? value) {
  if (_secretKey.hasMatch(key)) return value == null ? '∅' : '••••••';
  if (value == null) return '∅';
  if (value is Map || value is List) return jsonEncode(_redact(value, key));
  var text = value is String ? value : jsonEncode(value);
  // Serialized nested configuration and arbitrary header values must not expose secrets.
  if (text.startsWith('{') || text.startsWith('[')) {
    try {
      return jsonEncode(_redact(jsonDecode(text), key));
    } on FormatException {
      return '••••••';
    }
  }
  text = text.replaceAllMapped(
    RegExp(r'[a-zA-Z][a-zA-Z0-9+.-]*://[^\s<>]+'),
    (match) {
      final uri = Uri.tryParse(match[0]!);
      if (uri == null) return '••••••';
      return uri
          .replace(
            userInfo: uri.userInfo.isEmpty ? '' : '••••••',
            queryParameters: uri.hasQuery
                ? {
                    for (final e in uri.queryParameters.entries)
                      e.key: _secretKey.hasMatch(e.key) ? '••••••' : e.value,
                  }
                : null,
            fragment: uri.fragment.isEmpty ? '' : '••••••',
          )
          .toString();
    },
  );
  return text;
}

Object? _redact(Object? value, String key) {
  if (_secretKey.hasMatch(key)) return value == null ? null : '••••••';
  if (value == null || value is num || value is bool) return value;
  if (value is Map)
    return {
      for (final e in value.entries)
        e.key.toString(): _redact(e.value, e.key.toString()),
    };
  if (value is List) return value.map((v) => _redact(v, key)).toList();
  return safeImportDisplayValue(key, value);
}
