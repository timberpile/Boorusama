import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../navigation/destination_activity.dart';
import '../data/bookmark_convert.dart';
import '../providers/bookmark_button_state_provider.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark_library_state.dart';
import 'bookmark_group_picker.dart';

enum BookmarkTargetScope { member, group }

/// The small marker describes the target; the main glyph keeps Bookmark's
/// established meaning and its independent saved/folder state.
class ScopedBookmarkIcon extends StatelessWidget {
  const ScopedBookmarkIcon({
    required this.scope,
    this.saved = false,
    super.key,
  });
  final BookmarkTargetScope scope;
  final bool saved;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Symbols.bookmark, fill: saved ? 1 : 0),
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              scope == BookmarkTargetScope.group
                  ? Symbols.layers
                  : Symbols.image,
              size: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class ScopedBookmarkButton extends ConsumerWidget {
  const ScopedBookmarkButton({
    required this.request,
    required this.scope,
    required this.label,
    this.requestBuilder,
    this.authorized = true,
    super.key,
  });
  final BookmarkPickerRequest? request;
  final BookmarkPickerRequest Function()? requestBuilder;
  final BookmarkTargetScope scope;
  final String label;
  final bool authorized;

  Set<String> _memberships(BookmarkLibraryState? library) {
    if (library == null) return const {};
    final target = request;
    if (target case ContentGroupBookmarkPickerRequest(:final draft)) {
      final id = library.idByContent[draft.reference.identity];
      return id == null ? const {} : library.membershipsForId(id);
    }
    if (target case PostBookmarkPickerRequest(:final post)) {
      if (library.hasUnifiedRecords) {
        final saved = library.storedBookmarkForPost(post);
        return saved == null ? const {} : library.membershipsForId(saved.id);
      }
      return library.membershipsFor(
        bookmarkIdentityForPost(post, target.config.booruIdHint),
      );
    }
    return library.pools
            .where((p) => p.identity == target?.collectionIdentity)
            .firstOrNull
            ?.groupIds ??
        const {};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider);
    final actualMemberships = _memberships(library.valueOrNull);
    final memberships = request is PostBookmarkPickerRequest
        ? actualMemberships.difference(
            ref.watch(ignoredFavoritesBookmarkGroupsProvider),
          )
        : actualMemberships;
    Widget button(VoidCallback? show) => IconButton(
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed:
          authorized &&
              request != null &&
              !library.isLoading &&
              NavigationActivity.of(context)
          ? show
          : null,
      icon: Semantics(
        label: label,
        value: memberships.isEmpty ? null : '${memberships.length}',
        excludeSemantics: true,
        child: Badge(
          isLabelVisible: memberships.length > 1,
          label: Text('${memberships.length}'),
          child: ScopedBookmarkIcon(
            scope: scope,
            saved: memberships.isNotEmpty,
          ),
        ),
      ),
    );
    return request == null
        ? button(null)
        : BookmarkGroupPickerAnchor(
            request: request!,
            requestBuilder: requestBuilder,
            builder: (context, show) => button(show),
          );
  }
}
