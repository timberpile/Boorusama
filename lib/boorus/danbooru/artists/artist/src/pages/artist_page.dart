import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/posts/listing/widgets.dart';
import '../../../../../../core/posts/listing/providers.dart';
import '../../../../../../core/posts/post/providers.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/tags/details/src/internal_widgets/tag_detail_region.dart';
import '../../../../../../core/tags/tag/types.dart';
import '../../../../../../core/widgets/custom_context_menu_overlay.dart';
import '../../../../../../foundation/display.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../tags/details/src/danbooru_tag_details_page.dart';
import '../widgets/artist_details.dart';
import '../widgets/artist_identity.dart';
import '../widgets/artist_posts_header.dart';

class DanbooruArtistPage extends ConsumerStatefulWidget {
  const DanbooruArtistPage({required this.artistName, super.key});

  final String artistName;

  @override
  ConsumerState<DanbooruArtistPage> createState() => _DanbooruArtistPageState();
}

class _DanbooruArtistPageState extends ConsumerState<DanbooruArtistPage> {
  var _category = TagFilterCategory.newest;
  final _banner = ArtistBannerSnapshot();
  final _gridKey = GlobalKey();
  final _profileKey = GlobalKey();

  @override
  void dispose() {
    _banner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final repo = ref.watch(originAwarePostRepoProvider(config));
    final generator = ref.watch(gridThumbnailUrlGeneratorProvider(config.auth));
    final thumbnailSettings = ref.watch(
      gridThumbnailSettingsProvider(config.auth),
    );
    _banner.isUsableImage = (post) =>
        !(config.bannedPostVisibility.isHidden &&
            post.core.status == 'banned') &&
        generator.resolve(post, settings: thumbnailSettings).url.isNotEmpty;
    _banner.fetchStillImages = (page) async {
      final result = await repo
          .getPosts(
            '${widget.artistName} filetype:jpg,png,webp,avif -animated',
            page,
            limit: 20,
            options: PostFetchOptions.raw,
          )
          .run();
      return result.fold((_) => <Post>[], (result) => result.posts);
    };
    return CustomContextMenuOverlay(
      child: PostScope(
        fetcher: (page) => repo.getPosts(
          queryFromTagFilterCategory(
            category: _category,
            tag: widget.artistName,
            builder: tagFilterCategoryToString,
          ),
          page,
        ),
        builder: (context, controller) {
          _banner.attach(controller);
          Widget profile() => Column(
            key: _profileKey,
            children: [
              ArtistIdentity(artistName: widget.artistName, banner: _banner),
              DanbooruArtistDetails(artistName: widget.artistName),
            ],
          );
          return TagDetailsRegion(
            showBackButton: false,
            detailsBuilder: (_) => profile(),
            builder: (context) => PostGrid(
              key: _gridKey,
              controller: controller,
              safeArea: context.isLargeScreen,
              sliverHeaders: [
                if (!context.isLargeScreen)
                  SliverToBoxAdapter(child: profile()),
                SliverToBoxAdapter(
                  child: DanbooruArtistPostsHeader(
                    artistName: widget.artistName,
                    controller: controller,
                    category: _category,
                    onCategoryChanged: (category) {
                      if (category == _category) return;
                      _banner.newest = category == TagFilterCategory.newest;
                      setState(() => _category = category);
                      controller.refresh();
                    },
                  ),
                ),
              ],
              header: const PostGridConfigurationHeader(blacklistOnly: true),
              itemBuilder: (context, index, scrollController, useHero) =>
                  DanbooruPostListingContextMenu(
                    index: index,
                    controller: controller,
                    child: DefaultDanbooruImageGridItem(
                      index: index,
                      autoScrollController: scrollController,
                      controller: controller,
                      useHero: useHero,
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}
