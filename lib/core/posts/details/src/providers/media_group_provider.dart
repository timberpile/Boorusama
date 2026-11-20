import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../boorus/booru/types.dart';

import '../../../../content/groups/group_capability.dart';
import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/types.dart';
import '../../../../settings/providers.dart';
import '../../../listing/types.dart';
import '../../../post/types.dart';
import '../types/viewer_entry.dart';
import 'viewer_source_access_provider.dart';
import 'group_reading_provider.dart';

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
        final reading = ref.watch(groupReadingProvider(entry));
        if (reading.initializing) return MediaGroupState(access: access);
        final metadata = GroupMetadataKey(
          reference: entry.contentReference,
          access: access.key,
        );
        final listing = ref.watch(
          listingSettingsForAccessProvider(access.key),
        );
        final details = ref.watch(groupDetailsProvider(metadata));
        // The indexed Timeline owns its page stride. Opening a member will
        // start the continuous Single prefix using the applied order.
        final indexedTimeline =
            reading.layout == GroupLayout.memberGrid &&
            listing.pageMode == PageMode.paginated &&
            entry.contentReference.engine == BooruType.danbooru;
        final key = indexedTimeline
            ? null
            : GroupLoadKey(
                reference: entry.contentReference,
                access: access.key,
                orderKey: reading.orderKey,
                requestedLimit: listing.postsPerPage,
              );
        final members = key == null
            ? null
            : ref.watch(groupMembersProvider(key));
        return MediaGroupState(
          access: access,
          loadKey: key,
          details: details.isLoading || details.hasError
              ? null
              : details.valueOrNull,
          members: members?.asData?.value,
          failed: details.hasError || (members?.hasError ?? false),
        );
      },
      dependencies: [
        viewerSourceAccessProvider,
        groupReadingProvider,
        listingSettingsForAccessProvider,
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
