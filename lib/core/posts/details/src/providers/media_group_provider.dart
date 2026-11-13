import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/types.dart';
import '../../../post/types.dart';
import '../types/viewer_entry.dart';
import 'viewer_source_access_provider.dart';

/// One occurrence's observers share the engine's source and envelope. Loading
/// or losing its actor deliberately exposes no previous actionable Page.
final mediaGroupProvider = Provider.autoDispose
    .family<MediaGroupState, GroupViewerEntry>(
      (ref, entry) {
        final binding = entry.source;
        final access = binding == null
            ? null
            : ref.watch(viewerSourceAccessProvider(binding));
        if (access == null || !access.accepts(entry.contentReference)) {
          return const MediaGroupState(failed: true);
        }
        final source = ref.watch(contentGroupSourceStateProvider(access.key));
        if (source.isLoading || source.hasError) {
          return MediaGroupState(access: access, failed: source.hasError);
        }
        final metadata = GroupMetadataKey(
          reference: entry.contentReference,
          access: access.key,
        );
        final key = GroupLoadKey(
          reference: entry.contentReference,
          access: access.key,
        );
        final details = ref.watch(groupDetailsProvider(metadata));
        final members = ref.watch(groupMembersProvider(key));
        return MediaGroupState(
          access: access,
          loadKey: key,
          details: details.isLoading || details.hasError
              ? null
              : details.valueOrNull,
          members: members.isLoading || members.hasError
              ? null
              : members.valueOrNull,
          failed: details.hasError || members.hasError,
        );
      },
      dependencies: [
        viewerSourceAccessProvider,
        contentGroupSourceStateProvider,
        groupDetailsProvider,
        groupMembersProvider,
      ],
    );

class MediaGroupState {
  const MediaGroupState({
    this.access,
    this.loadKey,
    this.details,
    this.members,
    this.failed = false,
  });
  final ContentAccessContext? access;
  final GroupLoadKey? loadKey;
  final ContentGroupDetails? details;
  final GroupMembersState? members;
  final bool failed;

  Post? postAt(int index) {
    if (failed || details == null) return null;
    final member = members?.members.elementAtOrNull(index);
    if (member == null || member.availability != MemberAvailability.available) {
      return null;
    }
    return switch (members?.resolved[member.reference.identity]) {
      PostContentEntry(:final post) => post,
      _ => null,
    };
  }
}
