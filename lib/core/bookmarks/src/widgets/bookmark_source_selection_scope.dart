import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../navigation/destination_activity.dart';
import '../providers/local_providers.dart';
import '../types/bookmark_view.dart';

/// Clears obsolete session state even when an empty Group has no filter bar.
class BookmarkSourceSelectionScope extends ConsumerStatefulWidget {
  const BookmarkSourceSelectionScope({
    required this.view,
    required this.child,
    super.key,
  });
  final BookmarkView view;
  final Widget child;

  @override
  ConsumerState<BookmarkSourceSelectionScope> createState() =>
      _BookmarkSourceSelectionScopeState();
}

class _BookmarkSourceSelectionScopeState
    extends ConsumerState<BookmarkSourceSelectionScope> {
  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final raw = ref.watch(selectedBooruUrlProvider);
    final selected = ref.watch(effectiveBookmarkSourceProvider(view));
    final active =
        TickerMode.valuesOf(context).enabled &&
        NavigationActivity.of(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (active && raw != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.view != view ||
            !TickerMode.valuesOf(context).enabled ||
            !NavigationActivity.of(context) ||
            !(ModalRoute.of(context)?.isCurrent ?? true) ||
            ref.read(selectedBooruUrlProvider) != raw) {
          return;
        }
        final current = ref.read(availableBookmarkViewSourcesProvider(view));
        if (!current.isLoading &&
            current.hasValue &&
            !current.hasError &&
            ref.read(effectiveBookmarkSourceProvider(view)) == null) {
          ref.read(selectedBooruUrlProvider.notifier).state = null;
        }
      });
    }
    return widget.child;
  }
}
