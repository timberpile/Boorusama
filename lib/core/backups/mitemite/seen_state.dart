import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_library_state.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../boorus/booru/types.dart';
import 'protocol.dart';

/// Frozen receiver-local targets for one displayed occurrence. Combined views
/// include every represented canonical Group; stale callbacks cannot follow a
/// moved source outside the captured subtree or borrow another owner's identity.
final class BookmarkSeenTarget {
  const BookmarkSeenTarget({
    required this.groupId,
    required this.publisher,
    required this.source,
    required this.member,
    this.scopeGroupId,
    this.scopeSource,
    this.additionalTargets = const [],
  });
  final String groupId;
  final String publisher;
  final String source;
  final String member;
  final String? scopeGroupId;
  final String? scopeSource;
  final List<BookmarkSeenTarget> additionalTargets;
  Iterable<BookmarkSeenTarget> get allTargets sync* {
    yield this;
    yield* additionalTargets;
  }

  bool isCurrent(BookmarkLibraryState state) {
    final resolver = BookmarkSeenTargetResolver(state.mirrors);
    return allTargets.any(resolver.contains);
  }
}

/// Validate immutable owner data once for each group and captured scope.
final class BookmarkSeenTargetResolver {
  BookmarkSeenTargetResolver(this.state);

  final BookmarkMirrorState state;
  final _seen = <String, SyncGroupSeenState?>{};
  final _scopes = <(String, String, String, String), bool>{};
  late final _parents = {
    for (final owner in state.owners.values)
      (owner.publisher, owner.source): owner.parentSource,
  };

  SyncGroupSeenState? forGroup(String id) => _seen.putIfAbsent(id, () {
    final data = state.owners[id]?.reading;
    return data == null || data.isEmpty
        ? null
        : SyncGroupSeenState.fromJson(data);
  });

  bool contains(BookmarkSeenTarget target) {
    final owner = state.owners[target.groupId];
    if (owner == null ||
        owner.publisher != target.publisher ||
        owner.source != target.source ||
        !(forGroup(target.groupId)?.members.contains(target.member) ?? false)) {
      return false;
    }
    final rootId = target.scopeGroupId;
    if (rootId == null) return true;
    final root = state.owners[rootId];
    if (root == null ||
        root.publisher != target.publisher ||
        root.source != target.scopeSource) {
      return false;
    }
    return _scopes.putIfAbsent(
      (target.publisher, target.source, rootId, root.source),
      () {
        final visited = <String>{};
        String? cursor = target.source;
        while (cursor != null && visited.add(cursor)) {
          if (cursor == root.source) return true;
          cursor = _parents[(target.publisher, cursor)];
        }
        return false;
      },
    );
  }
}

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
final class SyncGroupSeenState {
  SyncGroupSeenState._({
    required this.group,
    required this.revision,
    required Set<String> members,
    required Set<String> seenMembers,
    required Set<String> arrivals,
    required this.hasUnseenChange,
  }) : members = Set.unmodifiable(members),
       seenMembers = Set.unmodifiable(seenMembers),
       arrivals = Set.unmodifiable(arrivals);

  factory SyncGroupSeenState.empty(SyncCollectionId group) {
    if (group.kind != 'bookmarks') {
      throw const FormatException('Not a Bookmark Group');
    }
    return SyncGroupSeenState._(
      group: group,
      revision: 0,
      members: {},
      seenMembers: {},
      arrivals: {},
      hasUnseenChange: false,
    );
  }

  factory SyncGroupSeenState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const SyncUpdateRequired();
    final rawGroup = json['group'];
    final revision = json['revision'];
    final changed = json['changed'];
    if (rawGroup is! Map<String, dynamic> ||
        revision is! int ||
        revision < 0 ||
        revision > miteMiteMaxSequence ||
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
    return SyncGroupSeenState._(
      group: group,
      revision: revision,
      members: members,
      seenMembers: read,
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
  final Set<String> seenMembers;
  final Set<String> arrivals;
  final bool hasUnseenChange;
  Set<String> get unseenMembers =>
      Set.unmodifiable(members.difference(seenMembers));

  SyncGroupSeenState applyMembership({
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
    return SyncGroupSeenState._(
      group: group,
      revision: revision,
      members: next,
      seenMembers: seenMembers,
      arrivals: arrivals
          .intersection(next)
          .union(next.difference(this.members)),
      hasUnseenChange: hasUnseenChange || !_same(next, this.members),
    );
  }

  /// A delayed render of an older revision must not clear newer arrivals.
  /// Calling this does not mark a single Post read or acknowledge child Groups.
  SyncGroupSeenState acknowledgeArrival({required int renderedRevision}) =>
      renderedRevision != revision
      ? this
      : SyncGroupSeenState._(
          group: group,
          revision: revision,
          members: members,
          seenMembers: seenMembers,
          arrivals: {},
          hasUnseenChange: false,
        );

  bool canMarkSeen(Set<String> selection) => selection.any(
    (key) => members.contains(key) && !seenMembers.contains(key),
  );

  /// Invoke for actually displayed full-Viewer Posts or explicit Mark Seen.
  /// A Work card alone is not proof that all of its Pages have been displayed.
  SyncGroupSeenState markSeen(Set<String> selection) {
    final newlySeen = selection.intersection(members).difference(seenMembers);
    if (newlySeen.isEmpty) return this;
    return SyncGroupSeenState._(
      group: group,
      revision: revision,
      members: members,
      seenMembers: seenMembers.union(newlySeen),
      arrivals: arrivals,
      hasUnseenChange: hasUnseenChange,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'group': group.toJson(),
    'revision': revision,
    'members': members.toList()..sort(),
    'read': seenMembers.toList()..sort(),
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

/// Persistent Unseen members in one received publisher subtree. A member still
/// unseen in any covered Group contributes once; reading flags remain per Group.
Set<String> syncBookmarkUnseenMembers(BookmarkLibraryState state, String root) {
  final owner = state.mirrors.owners[root];
  if (owner == null) return const {};
  return Set.unmodifiable({
    for (final id in state.groupTree.subtreeIds(root))
      if (state.mirrors.owners[id] case final child?
          when child.publisher == owner.publisher)
        ...SyncGroupSeenState.fromJson(child.reading).unseenMembers,
  });
}
