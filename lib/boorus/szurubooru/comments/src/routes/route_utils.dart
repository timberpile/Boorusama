// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/router.dart';

Future<String?> goToSzurubooruCommentCreatePage(
  WidgetRef ref, {
  required int postId,
  String? initialContent,
}) {
  return ref.router.push<String>(
    Uri(
      pathSegments: [
        '',
        'internal',
        'szurubooru',
        'posts',
        '$postId',
        'comments',
        'editor',
      ],
      queryParameters: {
        'text': ?initialContent,
      },
    ).toString(),
    extra: ref.readConfig,
  );
}

Future<String?> goToSzurubooruCommentUpdatePage(
  WidgetRef ref, {
  required int postId,
  required int commentId,
  required String commentBody,
}) {
  return ref.router.push<String>(
    Uri(
      pathSegments: [
        '',
        'internal',
        'szurubooru',
        'posts',
        '$postId',
        'comments',
        'editor',
      ],
      queryParameters: {
        'text': commentBody,
        'comment_id': commentId.toString(),
      },
    ).toString(),
    extra: ref.readConfig,
  );
}
