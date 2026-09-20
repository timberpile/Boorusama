// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../posts/listing/widgets.dart';
import '../posts/post/types.dart';
import '../tags/details/widgets.dart';
import '../tags/tag/types.dart';
import '../search/subscriptions/src/widgets/feed_follow_control.dart';

class ArtistPageScaffold<T extends Post> extends ConsumerStatefulWidget {
  const ArtistPageScaffold({
    required this.artistName,
    required this.fetcher,
    super.key,
  });

  final String artistName;
  final PostsOrErrorCore<T> Function(
    int page,
    TagFilterCategory selectedCategory,
  )
  fetcher;

  @override
  ConsumerState<ArtistPageScaffold<T>> createState() =>
      _ArtistPageScaffoldState<T>();
}

class _ArtistPageScaffoldState<T extends Post>
    extends ConsumerState<ArtistPageScaffold<T>> {
  final selectedCategory = ValueNotifier(TagFilterCategory.newest);

  @override
  Widget build(BuildContext context) {
    return PostScope(
      fetcher: (page) => widget.fetcher(page, selectedCategory.value),
      builder: (context, controller) => TagDetailsPageScaffold(
        onCategoryToggle: (category) {
          selectedCategory.value = category;
          controller.refresh();
        },
        tagName: widget.artistName,
        otherNames: const SizedBox(height: 40, width: 40),
        extras: [FeedFollowButton(query: widget.artistName)],
        gridBuilder: (context, slivers) => PostGrid(
          controller: controller,
          sliverHeaders: slivers,
        ),
      ),
    );
  }
}
