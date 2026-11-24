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
import 'adjacent_group_preparation.dart';
import 'post_details_page_view_scope.dart';
import 'viewer_entry_navigation_header.dart';

/// Both stable native routes and mixed entries share this source/metadata/
/// presentation dispatch. A native route may seed its real, already loaded
/// engine envelope; imported metadata never enters that seed path.
class ContentGroupPage extends ConsumerWidget {
  const ContentGroupPage({
    required this.entry,
    this.active = true,
    this.embedded = true,
    this.prepared,
    this.suspendWhenInactive = false,
    this.onOpenMember,
    this.prepareSource,
    this.onDisplayed,
    super.key,
  });
  final GroupViewerEntry entry;
  final bool active;
  final bool embedded;
  final PreparedViewerKey? prepared;
  final bool suspendWhenInactive;
  final ValueChanged<String>? onOpenMember;
  final void Function(ContentGroupSource source)? prepareSource;
  final VoidCallback? onDisplayed;

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
      if (sourceState.isLoading) {
        return const ViewerEntryNavigationStatus(
          child: CircularProgressIndicator(),
        );
      }
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
          passive: suspendWhenInactive && !active,
          onOpenMember: onOpenMember,
          child: _RegisteredGroupContent(
            entry: entry,
            access: access.key,
            presentation: capability.presentation,
            prepared: prepared?.access == access.key ? prepared : null,
            active: !suspendWhenInactive || active,
            onDisplayed: onDisplayed,
          ),
        ),
      ),
    );
  }
}

class _RegisteredGroupContent extends ConsumerStatefulWidget {
  const _RegisteredGroupContent({
    required this.entry,
    required this.access,
    required this.presentation,
    required this.prepared,
    required this.active,
    this.onDisplayed,
  });
  final GroupViewerEntry entry;
  final ContentAccessKey access;
  final BooruGroupPresentation presentation;
  final PreparedViewerKey? prepared;
  final bool active;
  final VoidCallback? onDisplayed;

  @override
  ConsumerState<_RegisteredGroupContent> createState() =>
      _RegisteredGroupContentState();
}

class _RegisteredGroupContentState
    extends ConsumerState<_RegisteredGroupContent> {
  (GroupMetadataKey, int)? _retainedKey;
  ContentGroupDetails? _retained;

  @override
  Widget build(BuildContext context) {
    final presentation = widget.presentation;
    final onDisplayed = widget.onDisplayed;
    final key = GroupMetadataKey(
      reference: widget.entry.summary.reference,
      access: widget.access,
    );
    final revision = ref.watch(groupRefreshRevisionProvider(key));
    final saved = (key, revision);
    if (_retainedKey != saved) {
      _retainedKey = saved;
      _retained = null;
    }
    final prepared = widget.prepared;
    final preparation = prepared == null
        ? null
        : ref.watch(preparedViewerDetailsProvider(prepared));
    final state = widget.active || prepared == null && _retained == null
        ? ref.watch(groupDetailsProvider(key))
        : preparation;
    _retained = state?.valueOrNull ?? _retained;
    final value = _retained;
    if (value != null && state?.hasError != true) {
      final child = presentation.buildDetails(context, value);
      return onDisplayed == null
          ? child
          : _DisplayedGroupContent(onDisplayed: onDisplayed, child: child);
    }
    final actions = presentation is BooruGroupStatusPresentation
        ? (presentation as BooruGroupStatusPresentation).buildStatusActions(
            context,
            widget.entry.summary,
          )
        : const <Widget>[];
    return ViewerEntryNavigationStatus(
      actions: actions,
      child: state?.hasError ?? false
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t.bookmark.pool_unavailable),
                TextButton(
                  onPressed: () => ref.invalidate(groupDetailsProvider(key)),
                  child: Text(context.t.generic.action.retry),
                ),
              ],
            )
          : const CircularProgressIndicator(),
    );
  }
}

/// A loaded gallery displays the saved Group itself, without displaying any
/// individual member in the full media Viewer. Loading/error surfaces, retained
/// neighbors and covered/background routes cannot acknowledge that record.
class _DisplayedGroupContent extends StatefulWidget {
  const _DisplayedGroupContent({
    required this.onDisplayed,
    required this.child,
  });
  final VoidCallback onDisplayed;
  final Widget child;

  @override
  State<_DisplayedGroupContent> createState() => _DisplayedGroupContentState();
}

class _DisplayedGroupContentState extends State<_DisplayedGroupContent>
    with WidgetsBindingObserver {
  var _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifyDisplayed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _notifyDisplayed();
  }

  void _notifyDisplayed() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          !NavigationActivity.of(context) ||
          !(ModalRoute.of(context)?.isCurrent ?? true) ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        return;
      }
      final pages = PostDetailsPageViewScope.maybeOf(context)?.pageController;
      if (pages != null &&
          (!pages.hasClients || pages.position.isScrollingNotifier.value)) {
        return;
      }
      widget.onDisplayed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pager = PostDetailsPageViewScope.maybeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        if (pager != null) ...[
          pager.currentPage,
          pager.precisePage,
          if (pager.pageController.hasClients)
            pager.pageController.position.isScrollingNotifier,
        ],
      ]),
      builder: (_, child) {
        _notifyDisplayed();
        return child!;
      },
      child: widget.child,
    );
  }
}
