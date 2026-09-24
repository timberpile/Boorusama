// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/comments/types.dart';
import '../../../core/comments/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/post/types.dart';
import '../posts/types.dart';
import 'providers.dart';

class Shimmie2CommentPage extends ConsumerWidget {
  const Shimmie2CommentPage({
    required this.post,
    required this.useAppBar,
    super.key,
  });

  final Post post;
  final bool useAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final commmentExtractor = ref.watch(
      shimmie2CommentExtractorProvider(config),
    );

    return SimpleCommentPageScaffold(
      comments: switch (commmentExtractor.extractComments(post)) {
        final CommentExtractionSuccess result => result.comments,
        _ => [],
      },
      useAppBar: useAppBar,
    );
  }
}
