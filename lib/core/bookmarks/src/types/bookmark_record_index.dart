import 'package:collection/collection.dart';

import '../../../../foundation/cooperative_work.dart';
import '../../../content/types.dart';
import 'bookmark.dart';
import 'bookmark_group.dart';
import 'bookmark_record_fields.dart';

/// Immutable indexes owned by BookmarkLibraryState. This value has no provider,
/// persistence or independent lifecycle and never decodes stored snapshots.
final class BookmarkRecordIndex {
  BookmarkRecordIndex._({
    required this.records,
    required this.byId,
    required this.idByContent,
    required this.membershipsByBookmarkId,
    required this.revision,
    required this.strict,
  });

  factory BookmarkRecordIndex.build({
    required List<Bookmark> records,
    required List<BookmarkGroup> groups,
    int revision = 0,
    bool strict = true,
  }) => _build(records, groups, revision, strict).last!;

  static Future<BookmarkRecordIndex> buildCooperatively({
    required List<Bookmark> records,
    required List<BookmarkGroup> groups,
    required int revision,
    void Function(int completed)? onProgress,
  }) async {
    final work = CooperativeWork();
    var completed = 0;
    for (final index in _build(records, groups, revision, true)) {
      if (index != null) return index;
      completed++;
      if (work.checkpoint() case final pause?) {
        onProgress?.call(completed);
        await pause;
      }
    }
    throw StateError('Bookmark index build did not finish');
  }

  static Iterable<BookmarkRecordIndex?> _build(
    List<Bookmark> records,
    List<BookmarkGroup> groups,
    int revision,
    bool strict,
  ) sync* {
    if (revision < 0) throw const FormatException('Invalid library revision');
    final byId = <int, Bookmark>{};
    final byContent = <ContentIdentity, int>{};
    final memberships = <int, Set<String>>{};
    final ordered = <Bookmark>[];
    var alreadyOrdered = true;
    for (final record in records) {
      bookmarkCreatedAt(record);
      if (strict && (record.id < 0 || byId.containsKey(record.id))) {
        throw const FormatException('Duplicate or invalid local Bookmark ID');
      }
      byId[record.id] = record;
      memberships[record.id] = <String>{};
      if (ordered.isNotEmpty && ordered.last.id > record.id) {
        alreadyOrdered = false;
      }
      ordered.add(record);
      if (bookmarkContentIdentity(record) case final identity?) {
        if (strict && byContent.containsKey(identity)) {
          throw const FormatException('Duplicate Bookmark content identity');
        }
        byContent[identity] = record.id;
      }
      yield null;
    }
    for (final group in groups) {
      for (final id in group.bookmarkIds) {
        memberships[id]?.add(group.id);
        yield null;
      }
    }
    for (final id in memberships.keys) {
      memberships[id] = UnmodifiableSetView(memberships[id]!);
      yield null;
    }
    if (strict && !alreadyOrdered) ordered.sort((a, b) => a.id.compareTo(b.id));
    yield BookmarkRecordIndex._(
      records: UnmodifiableListView(ordered),
      byId: UnmodifiableMapView(byId),
      idByContent: UnmodifiableMapView(byContent),
      membershipsByBookmarkId: UnmodifiableMapView(memberships),
      revision: revision,
      strict: strict,
    );
  }

  final List<Bookmark> records;
  final Map<int, Bookmark> byId;
  final Map<ContentIdentity, int> idByContent;
  final Map<int, Set<String>> membershipsByBookmarkId;
  final int revision;
  final bool strict;

  BookmarkRecordIndex apply({
    required Iterable<Bookmark> upserts,
    required Set<int> removedIds,
    required Map<String, BookmarkGroup> previousGroups,
    required List<BookmarkGroup> groups,
    int? revision,
  }) {
    final nextRevision = revision ?? this.revision;
    if (nextRevision < this.revision) {
      throw const FormatException('Library revision moved backwards');
    }
    final incoming = <int, Bookmark>{};
    for (final record in upserts) {
      bookmarkCreatedAt(record);
      if (strict && (record.id < 0 || incoming.containsKey(record.id))) {
        throw const FormatException('Duplicate or invalid Bookmark delta');
      }
      incoming[record.id] = record;
    }
    final affected = <int>{...removedIds, ...incoming.keys};
    final changedRecords =
        incoming.values.any((record) => !identical(record, byId[record.id])) ||
        removedIds.any(
          (id) => byId.containsKey(id) && !incoming.containsKey(id),
        );
    var nextById = byId;
    var nextByContent = idByContent;
    var nextRecords = records;
    if (changedRecords) {
      final updated = Map<int, Bookmark>.of(byId)
        ..removeWhere((id, _) => removedIds.contains(id));
      updated.addAll(incoming);
      nextById = UnmodifiableMapView(updated);
      Map<ContentIdentity, int>? content;
      for (final id in affected) {
        final previous = byId[id];
        final next = nextById[id];
        final oldIdentity = previous == null
            ? null
            : bookmarkContentIdentity(previous);
        final newIdentity = next == null ? null : bookmarkContentIdentity(next);
        if (oldIdentity != null &&
            oldIdentity != newIdentity &&
            (content ?? idByContent)[oldIdentity] == id) {
          (content ??= Map.of(idByContent)).remove(oldIdentity);
        }
      }
      for (final record in incoming.values) {
        final identity = bookmarkContentIdentity(record);
        if (identity == null) continue;
        final owner = (content ?? idByContent)[identity];
        if (strict && owner != null && owner != record.id) {
          throw const FormatException(
            'Conflicting committed content identities',
          );
        }
        if (owner != record.id) {
          (content ??= Map.of(idByContent))[identity] = record.id;
        }
      }
      if (content != null) nextByContent = UnmodifiableMapView(content);
      final remaining = Map<int, Bookmark>.of(incoming);
      final existing = <Bookmark>[
        for (final record in records)
          if (remaining.remove(record.id) case final replacement?)
            replacement
          else if (!removedIds.contains(record.id))
            record,
      ];
      if (strict) {
        final added = remaining.values.toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        final merged = <Bookmark>[];
        var index = 0;
        for (final record in existing) {
          while (index < added.length && added[index].id < record.id) {
            merged.add(added[index++]);
          }
          merged.add(record);
        }
        merged.addAll(added.skip(index));
        nextRecords = List.unmodifiable(merged);
      } else {
        nextRecords = List.unmodifiable([...existing, ...remaining.values]);
      }
    }
    final nextGroups = {for (final group in groups) group.id: group};
    for (final id in {...previousGroups.keys, ...nextGroups.keys}) {
      final before = previousGroups[id];
      final after = nextGroups[id];
      if (identical(before, after)) continue;
      final oldMembers = before?.bookmarkIds ?? const <int>{};
      final newMembers = after?.bookmarkIds ?? const <int>{};
      if (const SetEquality<int>().equals(oldMembers, newMembers)) continue;
      affected.addAll(oldMembers.difference(newMembers));
      affected.addAll(newMembers.difference(oldMembers));
    }
    Map<int, Set<String>>? memberships;
    for (final id in affected) {
      if (!nextById.containsKey(id)) {
        if (membershipsByBookmarkId.containsKey(id)) {
          (memberships ??= Map.of(membershipsByBookmarkId)).remove(id);
        }
        continue;
      }
      final next = <String>{
        for (final group in groups)
          if (group.bookmarkIds.contains(id)) group.id,
      };
      final previous = membershipsByBookmarkId[id];
      if (previous == null ||
          !const SetEquality<String>().equals(previous, next)) {
        (memberships ??= Map.of(membershipsByBookmarkId))[id] =
            Set.unmodifiable(next);
      }
    }
    if (identical(nextById, byId) &&
        memberships == null &&
        nextRevision == this.revision) {
      return this;
    }
    return BookmarkRecordIndex._(
      records: nextRecords,
      byId: nextById,
      idByContent: nextByContent,
      membershipsByBookmarkId: memberships == null
          ? membershipsByBookmarkId
          : UnmodifiableMapView(memberships),
      revision: nextRevision,
      strict: strict,
    );
  }
}
