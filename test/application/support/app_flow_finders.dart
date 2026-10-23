import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';

/// Localized strings of the mounted app, for finders that match visible text.
Translations appStrings(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first).t;

Finder postGrid() => find.byElementPredicate(
  (element) =>
      element.widget is PostGrid<Post> &&
      (ModalRoute.of(element)?.isCurrent ?? true),
);

Finder postGridScrollable() => find
    .descendant(
      of: postGrid().first,
      matching: find.byType(Scrollable),
    )
    .first;

Finder postTile(int id) => find.byElementPredicate(
  (element) =>
      element.widget is SliverPostGridImageGridItem &&
      (element.widget as SliverPostGridImageGridItem).post.id == id &&
      (ModalRoute.of(element)?.isCurrent ?? true),
  description: 'post tile with ID $id',
);

/// A listing tile (not a bookmark tile) whose post carries [tag].
Finder listingPostWithTag(String tag) => find.byWidgetPredicate(
  (widget) =>
      widget is SliverPostGridImageGridItem && widget.post.tags.contains(tag),
  description: 'listing post tagged $tag',
);

Finder bookmarkTile({
  required int postId,
  required int booruId,
  String? sourceUrl,
}) => find.byWidgetPredicate(
  (widget) => switch (widget) {
    SliverPostGridImageGridItem(post: final post) =>
      post.id == postId &&
          post.origin.booruId == booruId &&
          (sourceUrl == null ||
              post.origin.sourceHost == normalizePostSourceHost(sourceUrl)),
    _ => false,
  },
  description:
      'bookmark tile for post $postId from booru $booruId'
      '${sourceUrl == null ? '' : ' at $sourceUrl'}',
);

Finder postDetailsScaffold() => find.byWidgetPredicate(
  (widget) => widget is PostDetailsPageScaffold,
  description: 'post details scaffold',
);

PostGridController<Post> postController(WidgetTester tester) =>
    PostScope.of<Post>(tester.element(postGrid().first));

List<int> loadedPostIds(WidgetTester tester) =>
    postController(tester).allItems.map((post) => post.id).toList();

Post currentDetailPost(WidgetTester tester) => tester
    .widget<PostDetailsPageScaffold>(
      postDetailsScaffold().first,
    )
    .controller
    .currentPost
    .value;
