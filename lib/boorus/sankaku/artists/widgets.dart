// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/artists/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/tags/tag/types.dart';

class SankakuArtistPage extends ConsumerWidget {
  const SankakuArtistPage({
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
            [
              artistName,
              if (selectedCategory == TagFilterCategory.popular) 'order:score',
            ].join(' '),
            page,
          ),
    );
  }
}
