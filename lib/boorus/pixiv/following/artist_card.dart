import 'package:booru_clients/pixiv.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/images/booru_image.dart';
import '../../../core/posts/post/src/widgets/explicit_block_overlay.dart';
import 'presentation.dart';

class PixivFollowingArtistCard extends StatelessWidget {
  const PixivFollowingArtistCard({
    required this.artist,
    required this.config,
    required this.maxRestriction,
    required this.onOpen,
    super.key,
  });
  final PixivFollowingArtist artist;
  final BooruConfigAuth config;
  final int maxRestriction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final user = artist.user;
    final avatar = pixivFollowingImageUrl(user.profileImageUrls?.medium);
    final previews = pixivFollowingPreviews(
      artist,
      maxRestriction: maxRestriction,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 40,
                    child: ClipOval(
                      child: avatar == null
                          ? const Icon(Icons.person_outline)
                          : BooruImage(
                              config: config,
                              imageUrl: avatar,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user.name?.isNotEmpty ?? false)
                              ? user.name!
                              : '${user.id}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if ((user.account?.isNotEmpty ?? false))
                          Text(
                            user.account!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (previews.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 4),
                  child: Row(
                    children: [
                      for (final preview in previews)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ExplicitContentBlockOverlay(
                                // A revealed work must not reveal a replacement
                                // artwork or another profile's preview at this slot.
                                key: ValueKey((
                                  config,
                                  user.id,
                                  preview.artworkId,
                                  preview.url,
                                )),
                                rating: preview.rating,
                                child: BooruImage(
                                  config: config,
                                  imageUrl: preview.url,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      for (var i = previews.length; i < 3; i++) const Spacer(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
