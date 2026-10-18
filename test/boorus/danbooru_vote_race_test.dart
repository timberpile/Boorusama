import 'dart:async';

import 'package:boorusama/boorus/danbooru/posts/votes/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/src/post_vote.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/src/post_vote_repository.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/votes/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes/test_post.dart';

void main() {
  test('a vote preload started before favoriting cannot erase its automatic upvote', () async {
    final config = BooruConfig.empty.auth;
    final repository = _Votes();
    final container = ProviderContainer(
      overrides: [
        danbooruPostVoteRepoProvider(config).overrideWithValue(repository),
        danbooruCurrentUserProvider(config)
            .overrideWith((ref) => Future.value(UserSelf.placeholder())),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(danbooruPostVotesProvider(config).notifier);
    final preload = notifier.getVotes([TestPost(id: 1)]);
    await repository.lookupStarted.future;
    await notifier.upvote(1, localOnly: true);
    final automaticVote = container.read(danbooruPostVotesProvider(config))[1]!;
    repository.preload.complete([]);
    await preload;
    expect(
      container.read(danbooruPostVotesProvider(config))[1]?.voteState,
      VoteState.upvoted,
    );
    expect(await notifier.removeVote(1, automaticVote.voteId), isTrue);
    expect(repository.removed, const PostVoteId.fromInt(20));
  });
}

class _Votes implements PostVoteRepository {
  final preload = Completer<List<DanbooruPostVote>>();
  final lookupStarted = Completer<void>();
  PostVoteId? removed;
  var calls = 0;
  @override
  Future<List<DanbooruPostVote>> getPostVotesFromUser(List<int> ids, int user) {
    if (calls++ == 0) {
      lookupStarted.complete();
      return preload.future;
    }
    return Future.value([
      DanbooruPostVote.local(
        postId: 1,
        score: 1,
      ).copyWith(voteId: const PostVoteId.fromInt(20)),
    ]);
  }

  @override
  Future<bool> removeVote(PostVoteId id) async {
    removed = id;
    return true;
  }

  @override
  Future<DanbooruPostVote?> upvote(int id) async => null;
  @override
  Future<DanbooruPostVote?> downvote(int id) async => null;
  @override
  Future<List<DanbooruPostVote>> getPostVotes(int id, {int? page}) async => [];
}
