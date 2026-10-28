// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/posts/count/types.dart';
import '../../../client_provider.dart';
import '../../../constants.dart';

final danbooruPostCountRepoProvider =
    Provider.family<PostCountRepository, BooruConfigSearch>((ref, config) {
      return PostCountRepositoryBuilder(
        countTags: (tags) => ref
            .read(danbooruClientProvider(config.auth))
            .countPosts(tags: tags),
        // Safebooru's count endpoint includes other ratings unless restricted.
        extraTags:
            Uri.tryParse(config.auth.url)?.host.toLowerCase() ==
                Uri.parse(kDanbooruSafeUrl).host
            ? ['rating:g']
            : [],
      );
    });
