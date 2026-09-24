// Project imports:
import '../../../core/comments/types.dart';
import '../posts/types.dart';

class Shimmie2CommentExtractor implements CommentExtractor<Post> {
  const Shimmie2CommentExtractor();

  @override
  CommentExtractionResult extractComments(Post source) {
    return switch (source.comments) {
      final comments? => CommentExtractionSuccess(
        comments
            .where((comment) => comment.id != null)
            .map(
              (comment) => SimpleComment(
                id: comment.id!,
                body: comment.comment ?? '',
                createdAt: comment.posted,
                updatedAt: comment.posted,
                creatorName: comment.ownerName,
                creatorId: comment.ownerId,
              ),
            )
            .toList(),
      ),
      _ => const CommentExtractionNotSupported(),
    };
  }
}
