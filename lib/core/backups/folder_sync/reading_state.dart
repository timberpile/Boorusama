import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../boorus/booru/types.dart';
import 'protocol.dart';

/// Reuses the app's proven portable, typed identity, never a local Hive key,
/// URL thumbnail or a display name. JSON tuple encoding avoids delimiter aliases.
String syncBookmarkMemberKey(Bookmark bookmark) {
  final identity = bookmarkContentIdentity(bookmark);
  final engine = bookmarkEngine(bookmark);
  if (identity == null || engine == BooruType.unknown) {
    throw const FormatException('Unaddressable content cannot be synchronized');
  }
  return canonicalSyncJson([
    engine.id,
    identity.siteNamespace,
    identity.kind.name,
    identity.sourceKey,
  ]);
}

/// Receiver-local state for ONE canonical publisher/Group, shared by its root
/// and nested links. Never export it or reuse it for Following post NEW state.
/// Persist this JSON with the mirror transaction; UI wiring is intentionally
/// outside this pure model and must supply actual rendered/visible identities.
final class SyncGroupReadingState {
  SyncGroupReadingState._({
    required this.group,
    required this.revision,
    required Set<String> members,
    required Set<String> readMembers,
    required Set<String> arrivals,
    required this.hasUnseenChange,
  }) : members = Set.unmodifiable(members),
       readMembers = Set.unmodifiable(readMembers),
       arrivals = Set.unmodifiable(arrivals);

  factory SyncGroupReadingState.empty(SyncCollectionId group) {
    if (group.kind != 'bookmarks') {
      throw const FormatException('Not a Bookmark Group');
    }
    return SyncGroupReadingState._(
      group: group,
      revision: 0,
      members: {},
      readMembers: {},
      arrivals: {},
      hasUnseenChange: false,
    );
  }

  factory SyncGroupReadingState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const SyncUpdateRequired();
    final rawGroup = json['group'];
    final revision = json['revision'];
    final changed = json['changed'];
    if (rawGroup is! Map<String, dynamic> ||
        revision is! int ||
        revision < 0 ||
        revision > folderSyncMaxSequence ||
        changed is! bool) {
      throw const FormatException('Invalid local reading state');
    }
    final group = SyncCollectionId.fromJson(rawGroup);
    final members = _decodeKeys(json['members']);
    final read = _decodeKeys(json['read']);
    final arrivals = _decodeKeys(json['arrivals']);
    if (group.kind != 'bookmarks' ||
        !members.containsAll(arrivals) ||
        (!changed && arrivals.isNotEmpty) ||
        (revision == 0 && (members.isNotEmpty || read.isNotEmpty || changed))) {
      throw const FormatException('Inconsistent local reading state');
    }
    return SyncGroupReadingState._(
      group: group,
      revision: revision,
      members: members,
      readMembers: read,
      arrivals: arrivals,
      hasUnseenChange: changed,
    );
  }

  final SyncCollectionId group;

  /// Last committed MEMBERSHIP revision, not a catalog metadata sequence.
  final int revision;
  final Set<String> members;

  /// Retain previously read identities through removal/rearrival. No other
  /// Group's state, root-link ID, Page sibling or aggregate can populate this.
  final Set<String> readMembers;
  final Set<String> arrivals;
  final bool hasUnseenChange;
  Set<String> get unreadMembers =>
      Set.unmodifiable(members.difference(readMembers));

  SyncGroupReadingState applyMembership({
    required int revision,
    required Set<String> members,
  }) {
    syncPositiveInteger(revision);
    final next = _keys(members);
    if (revision < this.revision ||
        (revision == this.revision && !_same(next, this.members))) {
      throw const SyncConflict();
    }
    if (revision == this.revision) return this;
    return SyncGroupReadingState._(
      group: group,
      revision: revision,
      members: next,
      readMembers: readMembers,
      arrivals: arrivals
          .intersection(next)
          .union(next.difference(this.members)),
      hasUnseenChange: hasUnseenChange || !_same(next, this.members),
    );
  }

  /// A delayed render of an older revision must not clear newer arrivals.
  /// Calling this does not mark a single Post read or acknowledge child Groups.
  SyncGroupReadingState acknowledgeArrival({required int renderedRevision}) =>
      renderedRevision != revision
      ? this
      : SyncGroupReadingState._(
          group: group,
          revision: revision,
          members: members,
          readMembers: readMembers,
          arrivals: {},
          hasUnseenChange: false,
        );

  bool canMarkRead(Set<String> selection) => selection.any(
    (key) => members.contains(key) && !readMembers.contains(key),
  );

  /// Invoke for actually displayed full-Viewer Posts or explicit Mark Read.
  /// A Work card alone is not proof that all of its Pages have been displayed.
  SyncGroupReadingState markRead(Set<String> selection) {
    final newlyRead = selection.intersection(members).difference(readMembers);
    if (newlyRead.isEmpty) return this;
    return SyncGroupReadingState._(
      group: group,
      revision: revision,
      members: members,
      readMembers: readMembers.union(newlyRead),
      arrivals: arrivals,
      hasUnseenChange: hasUnseenChange,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'group': group.toJson(),
    'revision': revision,
    'members': members.toList()..sort(),
    'read': readMembers.toList()..sort(),
    'arrivals': arrivals.toList()..sort(),
    'changed': hasUnseenChange,
  };
}

Set<String> _keys(Iterable<String> values) {
  final keys = values.toSet();
  if (keys.any((key) => key.isEmpty)) {
    throw const FormatException('Empty member key');
  }
  return keys;
}

Set<String> _decodeKeys(Object? value) {
  if (value is! List || value.any((key) => key is! String)) {
    throw const FormatException('Invalid reading identity list');
  }
  final keys = _keys(value.cast<String>());
  if (keys.length != value.length) {
    throw const FormatException('Duplicate member key');
  }
  return keys;
}

bool _same(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
