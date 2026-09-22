// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../core/posts/details/types.dart';
import '../../../../../core/posts/details_parts/widgets.dart';
import '../../../../../core/posts/post/types.dart';
import '../../../../../core/search/search/routes.dart';
import '../../providers.dart';

class MoebooruUploaderFileDetailTile extends ConsumerWidget {
  const MoebooruUploaderFileDetailTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<UnifiedPost>(context);
    final uploaderName = post.uploaderName;

    return switch (uploaderName) {
      null => const SizedBox.shrink(),
      final name => UploaderFileDetailTile(
        uploaderName: name,
        onSearch: switch (ref.watch(moebooruUploaderQueryProvider(post))) {
          final query? => () => goToSearchPage(
            ref,
            tag: query.resolveTag(),
          ),
          _ => null,
        },
      ),
    };
  }
}
