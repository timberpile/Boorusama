// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import 'types/types.dart';

const _kCommentParams =
    'creator,id,post_id,body,score,is_deleted,created_at,updated_at,is_sticky,do_not_bump_post,updater_id';

mixin DanbooruClientComments {
  Dio get dio;

  /// A bounded complete set of visible IDs can establish a total. A partial
  /// comment page never becomes a total, even on sites with a lower page cap.
  Future<int?> getCommentCount({required int postId}) async {
    final query = {
      'search[post_id]': postId,
      'search[is_deleted]': false,
      'search[order]': 'id_desc',
      'only': 'id,is_deleted',
    };
    const limit = 100;
    final response = await dio.get(
      '/comments.json',
      queryParameters: {...query, 'limit': limit},
    );
    final rows = response.data;
    if (rows is! List || rows.length > limit) return null;
    if (rows.isEmpty) return 0;
    final ids = <int>[];
    var count = 0;
    for (final row in rows) {
      if (row is! Map || row['id'] is! int || (row['id'] as int) <= 0)
        return null;
      final id = row['id'] as int;
      if (ids.isNotEmpty && id >= ids.last) return null;
      ids.add(id);
      if (row['is_deleted'] == false)
        count++;
      else if (row['is_deleted'] != true)
        return null;
    }
    final continuation = await dio.get(
      '/comments.json',
      queryParameters: {
        ...query,
        'search[id]': '<${ids.last}',
        'limit': 1,
      },
    );
    return continuation.data is List && (continuation.data as List).isEmpty
        ? count
        : null;
  }

  Future<List<CommentDto>> getComments({
    required int postId,
    int? limit,
    CancelToken? cancelToken,
  }) async {
    final response = await dio.get(
      '/comments.json',
      queryParameters: {
        'search[post_id]': postId,
        'limit': ?limit,
        'only': _kCommentParams,
      },
      cancelToken: cancelToken,
    );

    return (response.data as List)
        .map((item) => CommentDto.fromJson(item))
        .toList();
  }

  Future<CommentDto> postComment({
    required int postId,
    required String content,
  }) async {
    final formData = {
      'comment[post_id]': postId,
      'comment[body]': content,
      'comment[do_not_bump_post]': true,
    };

    final response = await dio.post(
      '/comments.json',
      data: formData,
      options: Options(
        headers: dio.options.headers,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    return CommentDto.fromJson(response.data);
  }

  Future<void> updateComment({
    required int commentId,
    required String content,
  }) async {
    final formData = {
      'comment[body]': content,
    };

    final _ = await dio.put(
      '/comments/$commentId.json',
      data: formData,
      options: Options(
        headers: dio.options.headers,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
  }

  Future<void> deleteComment({
    required int commentId,
  }) async {
    final _ = await dio.delete(
      '/comments/$commentId.json',
    );
  }

  Future<List<CommentVoteDto>> getCommentVotes({
    required List<int> commentIds,
    bool? isDeleted,
  }) async {
    if (commentIds.isEmpty) {
      throw ArgumentError('commentIds cannot be empty');
    }

    final response = await dio.get(
      '/comment_votes.json',
      queryParameters: {
        'search[comment_id]': commentIds.join(','),
        if (isDeleted != null) 'search[is_deleted]': isDeleted.toString(),
      },
    );

    return (response.data as List)
        .map((item) => CommentVoteDto.fromJson(item))
        .toList();
  }

  Future<CommentVoteDto> voteComment({
    required int commentId,
    required int score,
  }) async {
    final response = await dio.post(
      '/comments/$commentId/votes.json',
      queryParameters: {
        'score': score,
      },
    );

    return CommentVoteDto.fromJson(response.data);
  }

  Future<void> removeCommentVote({
    required int commentId,
  }) async {
    final _ = await dio.delete(
      '/comment_votes/$commentId.json',
    );
  }

  Future<CommentVoteDto> upvoteComment({
    required int commentId,
  }) => voteComment(
    commentId: commentId,
    score: 1,
  );

  Future<CommentVoteDto> downvoteComment({
    required int commentId,
  }) => voteComment(
    commentId: commentId,
    score: -1,
  );
}
