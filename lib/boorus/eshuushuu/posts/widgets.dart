// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/selected_tags/types.dart';

class EshuushuuInheritedTagsTile extends ConsumerWidget {
  const EshuushuuInheritedTagsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultInheritedTagsTile<Post>(
      onTagTap: (tag) {
        final tagSet = SearchTagSet();
        tagSet.addTag(
          TagSearchItem.fromString(tag.name),
        );

        goToSearchPage(
          ref,
          tags: tagSet,
        );
      },
    );
  }
}
