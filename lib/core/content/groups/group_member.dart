import 'package:equatable/equatable.dart';

import '../content_entry.dart';
import '../content_page.dart';
import '../content_reference.dart';

enum MemberAvailability { unknown, available, unavailable }

final class GroupMember extends Equatable {
  GroupMember({
    required this.reference,
    required this.memberKey,
    this.sourcePosition,
    this.availability = MemberAvailability.unknown,
  }) {
    if (memberKey.trim().isEmpty ||
        memberKey.length > 2048 ||
        (sourcePosition != null && sourcePosition! < 0)) {
      throw const FormatException('Invalid Group member');
    }
  }
  final ContentReference reference;
  final String memberKey;
  final int? sourcePosition;
  final MemberAvailability availability;
  @override
  List<Object?> get props => [
    reference,
    memberKey,
    sourcePosition,
    availability,
  ];
}

final class GroupMemberQuery extends Equatable {
  GroupMemberQuery({
    required this.reference,
    this.orderKey,
    this.cursor,
    this.requestedLimit,
  }) {
    if (reference.kind != ContentKind.group ||
        orderKey == '' ||
        (requestedLimit != null && requestedLimit! <= 0)) {
      throw const FormatException('Invalid Group member query');
    }
  }
  final ContentReference reference;
  final String? orderKey;
  final ContentCursor? cursor;
  final int? requestedLimit;
  @override
  List<Object?> get props => [reference, orderKey, cursor, requestedLimit];
}

typedef GroupMemberBatch = ({
  ContentPage<GroupMember> page,
  List<ContentEntry> resolved,
});

/// Membership is occurrence-based. Hydration is identity-based and access-scoped;
/// neither deduplicating Posts nor filtering media may compact source positions.
GroupMemberBatch validateGroupMemberBatch(
  GroupMemberQuery query,
  GroupMemberBatch batch,
) {
  final members = <String, GroupMember>{};
  final references = <ContentIdentity, List<ContentReference>>{};
  final readable = <ContentIdentity>{};
  for (final member in batch.page.items) {
    if (members.containsKey(member.memberKey)) {
      throw const FormatException('Duplicate Group member occurrence');
    }
    members[member.memberKey] = member;
    if (member.availability != MemberAvailability.unavailable) {
      readable.add(member.reference.identity);
    }
    references
        .putIfAbsent(member.reference.identity, () => [])
        .add(member.reference);
  }
  final hydrated = <ContentIdentity, ContentEntry>{};
  for (final entry in batch.resolved) {
    final matches = references[entry.reference.identity];
    if (matches == null ||
        !readable.contains(entry.reference.identity) ||
        hydrated.containsKey(entry.reference.identity) ||
        entry.reference.engine != query.reference.engine ||
        entry.reference.siteNamespace != query.reference.siteNamespace) {
      throw const FormatException('Invalid access-scoped Group hydration');
    }
    for (final match in matches) {
      const ContentReferenceCodec().requireCompatible(match, entry.reference);
    }
    hydrated[entry.reference.identity] = entry;
  }
  return (
    page: batch.page,
    resolved: List<ContentEntry>.unmodifiable(hydrated.values),
  );
}
