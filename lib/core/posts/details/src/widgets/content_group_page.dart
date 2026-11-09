import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/manage/widgets.dart';
import '../../../../content/capabilities.dart';
import '../../../../content/anonymous_access_provider.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/types.dart';
import '../../../../navigation/destination_activity.dart';
import '../providers/viewer_source_access_provider.dart';
import '../types/viewer_entry.dart';
import 'group_viewer_scope.dart';
import 'viewer_entry_navigation_header.dart';

/// Both stable native routes and mixed entries share this source/metadata/
/// presentation dispatch. A native route may seed its real, already loaded
/// engine envelope; imported metadata never enters that seed path.
class ContentGroupPage extends ConsumerWidget {
  const ContentGroupPage({
    required this.entry,
    this.active = true,
    this.embedded = true,
    this.prepareSource,
    super.key,
  });
  final GroupViewerEntry entry;
  final bool active;
  final bool embedded;
  final void Function(ContentGroupSource source)? prepareSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = entry.source;
    final access = binding == null
        ? null
        : ref.watch(viewerSourceAccessProvider(binding));
    final capability = ref.watch(
      booruGroupCapabilityProvider(entry.summary.reference.engine),
    );
    final publicAllowed =
        access?.key.profileId != null ||
        ref
                .watch(anonymousSourcePolicyProvider)
                .resolve(
                  entry.summary.reference.engine,
                  entry.summary.reference.site,
                ) !=
            null;
    if (!publicAllowed ||
        access?.config == null ||
        capability == null ||
        !access!.accepts(entry.summary.reference) ||
        !capability.presentation.supports(entry.summary)) {
      return ViewerEntryNavigationStatus(
        child: Text(context.t.bookmark.pool_unavailable),
      );
    }
    final sourceState = ref.watch(contentGroupSourceStateProvider(access.key));
    final source = sourceState.asData?.value;
    if (source == null) {
      if (sourceState.isLoading)
        return const ViewerEntryNavigationStatus(
          child: CircularProgressIndicator(),
        );
      return ViewerEntryNavigationStatus(
        child: Text(context.t.bookmark.pool_unavailable),
      );
    }
    prepareSource?.call(source);
    return CurrentBooruConfigScope(
      config: access.config!,
      accessKey: access.key,
      requireAccess: true,
      bookmarkId: binding?.bookmarkId,
      child: NavigationActivity(
        active: active && NavigationActivity.of(context),
        child: GroupViewerScope(
          entry: entry,
          embedded: embedded,
          child: _RegisteredGroupContent(
            entry: entry,
            access: access.key,
            presentation: capability.presentation,
          ),
        ),
      ),
    );
  }
}

class _RegisteredGroupContent extends ConsumerWidget {
  const _RegisteredGroupContent({
    required this.entry,
    required this.access,
    required this.presentation,
  });
  final GroupViewerEntry entry;
  final ContentAccessKey access;
  final BooruGroupPresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = GroupMetadataKey(
      reference: entry.summary.reference,
      access: access,
    );
    final actions = presentation is BooruGroupStatusPresentation
        ? (presentation as BooruGroupStatusPresentation).buildStatusActions(
            context,
            entry.summary,
          )
        : const <Widget>[];
    return ref
        .watch(groupDetailsProvider(key))
        .when(
          data: (details) => presentation.buildDetails(context, details),
          loading: () => ViewerEntryNavigationStatus(
            actions: actions,
            child: const CircularProgressIndicator(),
          ),
          error: (_, _) =>
              entry.storedDetails != null &&
                  entry.storedDetails!.summary.reference ==
                      entry.summary.reference
              ? presentation.buildDetails(context, entry.storedDetails!)
              : ViewerEntryNavigationStatus(
                  actions: actions,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t.bookmark.pool_unavailable),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(groupDetailsProvider(key)),
                        child: Text(context.t.generic.action.retry),
                      ),
                    ],
                  ),
                ),
        );
  }
}
