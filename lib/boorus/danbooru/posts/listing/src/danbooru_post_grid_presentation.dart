// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../core/config_widgets/website_logo.dart';
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/posts/details_parts/src/details_ui_builder.dart';
import '../../../../../core/posts/listing/widgets.dart';
import '../../../../../core/posts/post/types.dart';
import '../../../../../core/posts/sources/types.dart';
import '../../../../../foundation/clipboard.dart';
import '../../../../../foundation/url_launcher.dart';
import '../../favorites/widgets.dart';
import '../../_shared/danbooru_creator_preloader.dart';
import '../../_shared/post_creator_preloadable.dart';
import '../../details/src/details_ui_builder.dart';
import '../../post/types.dart';
import 'danbooru_post_preview.dart';

const _kBannedTextThreshold = 200.0;

final class DanbooruPostGridPresentation
    implements BooruPostPresentation, BooruPostGridPresentation {
  const DanbooruPostGridPresentation();

  @override
  bool supports(BooruPostData data) => data is DanbooruPostData;

  @override
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post) =>
      danbooruPostDetailsUiBuilder;

  @override
  PostDetailsWrapperBuilder get detailsWrapperBuilder =>
      ({required post, required child}) => DanbooruCreatorPreloader(
        preloadable: PostCreatorsPreloadable.fromUnifiedPost(post),
        child: child,
      );

  @override
  PostGridItemAdditions buildGridItemAdditions(
    BuildContext context, {
    required UnifiedPost post,
    required BooruConfigAuth config,
  }) => _buildAdditions(
    context,
    post: post,
    config: config,
    isBanned: post.status?.matches('banned') ?? false,
  );

  PostGridItemAdditions buildLegacyGridItemAdditions(
    BuildContext context, {
    required DanbooruPost post,
    required BooruConfigAuth config,
  }) => _buildAdditions(
    context,
    post: post,
    config: config,
    isBanned: post.isBanned,
  );

  PostGridItemAdditions _buildAdditions(
    BuildContext context, {
    required Post post,
    required BooruConfigAuth config,
    required bool isBanned,
  }) {
    final artistTags = [...?post.artistTags]..remove('banned_artist');

    return PostGridItemAdditions(
      quickActionButton: DanbooruQuickFavoriteButton(
        post: post,
        isBanned: isBanned,
      ),
      blockOverlay: isBanned
          ? _buildBlockOverlayItem(post, artistTags, context)
          : null,
      tooltipBuilder: (child) => DanbooruTagListPrevewTooltip(
        post: post,
        config: config,
        child: child,
      ),
      disablePostInteraction: isBanned,
      hideScore: isBanned,
      imageAspectRatio: isBanned ? 0.8 : null,
    );
  }

  BlockOverlayItem _buildBlockOverlayItem(
    Post post,
    List<String> artistTags,
    BuildContext context,
  ) {
    return BlockOverlayItem(
      overlay: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                switch (post.source) {
                  final WebSource source => ConfigAwareWebsiteLogo(
                    size: 18,
                    url: source.url,
                  ),
                  _ => const SizedBox.shrink(),
                },
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kBannedTextThreshold,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth > _kBannedTextThreshold
                        ? Text(
                            maxLines: 1,
                            'Banned post'.hc,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            if (artistTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in artistTags)
                      KurumiRawCompactChip(
                        label: Text(
                          tag.replaceAll('_', ' '),
                          maxLines: 1,
                          style: TextStyle(
                            color: Kurumi.themeOf(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        backgroundColor: Kurumi.themeOf(
                          context,
                        ).colorScheme.errorContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          AppClipboard.copyAndToast(
                            context,
                            artistTags.join(' '),
                            message: 'Tag copied to clipboard',
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      onTap: switch (post.source) {
        final WebSource source => () => launchExternalUrlString(source.url),
        _ => null,
      },
    );
  }
}
