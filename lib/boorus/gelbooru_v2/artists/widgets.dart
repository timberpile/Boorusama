// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/artists/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/tags/tag/types.dart';

class GelbooruV2ArtistPage extends ConsumerWidget {
  const GelbooruV2ArtistPage({
    required this.artistName,
    super.key,
  });

  final String artistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;

    return ArtistPageScaffold(
      artistName: artistName,
      fetcher: (page, selectedCategory) => ref
          .read(originAwarePostRepoProvider(config))
          .getPosts(
            queryFromTagFilterCategory(
              category: selectedCategory,
              tag: artistName,
              builder: (category) => category == TagFilterCategory.popular
                  ? some('sort:score:desc')
                  : none(),
            ),
            page,
          ),
    );
  }
}
