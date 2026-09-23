// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../core/boorus/engine/providers.dart';
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/configs/manage/providers.dart';
import '../../../../../core/posts/explores/types.dart';
import '../../../../../core/posts/post/providers.dart';
import '../../../../../core/posts/post/types.dart';
import '../../../../../core/posts/rating/types.dart';
import '../../../../../core/settings/providers.dart';
import '../../../client_provider.dart';
import '../../../constants.dart';
import '../../post/providers.dart';
import 'data/explore_repository_cacher.dart';
import 'data/explore_repository_impl.dart';
import 'types/explore_repository.dart';

final danbooruExploreRepoProvider = Provider.family<ExploreRepository, BooruConfig>(
  (ref, config) {
    final origin = PostOrigin.fromSource(
      booruType: config.auth.booruType,
      booruId: config.booruId,
      source: config.url,
      profileIdHint: config.id,
    );
    return ExploreRepositoryCacher(
      repository: ExploreRepositoryApi(
        transformer: (posts) async => bindPostResultOrigin(
          await transformPosts(ref, posts, config.search),
          origin: origin,
        ),
        client: ref.watch(danbooruClientProvider(config.auth)),
        postRepository: ref.watch(originAwarePostRepoProvider(config)),
        settings: () => ref.read(imageListingSettingsProvider),
        shouldFilter: (post) {
          // A special rule for safebooru to make sure inappropriate posts are not shown
          if (config.auth.url == kDanbooruSafeUrl) {
            return post.rating != Rating.general;
          }

          final filterer = ref
              .read(booruRepoProvider(config.auth))
              ?.granularRatingFilterer(config.search);

          if (filterer == null) return false;

          return filterer(post, config.search);
        },
      ),
      popularStaleDuration: const Duration(seconds: 10),
      mostViewedStaleDuration: const Duration(seconds: 30),
      hotStaleDuration: const Duration(seconds: 5),
    );
  },
  dependencies: [
    settingsRepoProvider,
    booruBuilderProvider,
  ],
);

final danbooruMostViewedTodayProvider = FutureProvider<PostResult<Post>>(
  (ref) {
    final repo = ref
        .watch(danbooruExploreRepoProvider(ref.watchConfig))
        .getMostViewedPosts(DateTime.now());

    return repo.run().then(
      (value) => value.fold(
        (l) => <Post>[].toResult(),
        (r) => r,
      ),
    );
  },
  dependencies: [currentReadOnlyBooruConfigProvider],
);

final danbooruPopularTodayProvider = FutureProvider<PostResult<Post>>((
  ref,
) {
  final repo = ref
      .watch(danbooruExploreRepoProvider(ref.watchConfig))
      .getPopularPosts(DateTime.now(), 1, TimeScale.day);

  return repo.run().then(
    (value) => value.fold(
      (l) => <Post>[].toResult(),
      (r) => r,
    ),
  );
}, dependencies: [currentReadOnlyBooruConfigProvider]);

final danbooruHotTodayProvider = FutureProvider<PostResult<Post>>((
  ref,
) {
  final repo = ref
      .watch(danbooruExploreRepoProvider(ref.watchConfig))
      .getHotPosts(1);

  return repo.run().then(
    (value) => value.fold(
      (l) => <Post>[].toResult(),
      (r) => r,
    ),
  );
}, dependencies: [currentReadOnlyBooruConfigProvider]);
