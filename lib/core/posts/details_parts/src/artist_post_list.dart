// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:sliver_tools/sliver_tools.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../router.dart';
import '../../../tags/tag/providers.dart';
import '../../../widgets/booru_visibility_detector.dart';
import '../../details/providers.dart';
import '../../details/types.dart';
import '../../listing/providers.dart';
import '../../post/types.dart';
import 'sliver_details_post_list.dart';

class DefaultInheritedArtistPostsSection<T extends Post>
    extends ConsumerStatefulWidget {
  const DefaultInheritedArtistPostsSection({
    super.key,
    this.filterQuery,
  });

  final PostFilterQuery<T>? filterQuery;

  @override
  ConsumerState<DefaultInheritedArtistPostsSection<T>> createState() =>
      _DefaultInheritedArtistPostsSectionState<T>();
}

class _DefaultInheritedArtistPostsSectionState<T extends Post>
    extends ConsumerState<DefaultInheritedArtistPostsSection<T>> {
  final Map<String, VisibilityController> _visControllers = {};

  @override
  void dispose() {
    for (final controller in _visControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  VisibilityController _getController(String tag) {
    return _visControllers.putIfAbsent(tag, () => VisibilityController());
  }

  @override
  Widget build(BuildContext context) {
    final post = InheritedPost.of(context);
    final auth = ref.watchConfigAuth;

    final thumbUrlBuilder = ref.watch(gridThumbnailUrlGeneratorProvider(auth));
    final thumbSettings = ref.watch(gridThumbnailSettingsProvider(auth));
    final configFilter = ref.watchConfigFilter;
    final config = ref.watchConfig;
    const previewLimit = BatchedPreview(artistUploaderPreviewPostLimit);

    return MultiSliver(
      children: ref
          .watch(artistCharacterGroupProvider((post: post, auth: auth)))
          .maybeWhen(
            data: (data) => data.artistTags.isNotEmpty
                ? data.artistTags.expand(
                    (tag) {
                      final controller = _getController(tag);
                      final postsQuery = (
                        configFilter,
                        config,
                        tag,
                        widget.filterQuery,
                      );
                      return [
                        SliverToBoxAdapter(
                          child: BooruVisibilityDetector(
                            childKey: Key('artist-posts-$tag'),
                            controller: controller,
                          ),
                        ),
                        SliverDetailsPostList(
                          key: ValueKey(postsQuery),
                          tag: tag,
                          subtitle: context.t.post.detail.artist,
                          onTap: () => _goToArtistPage(tag),
                          child: ListenableBuilder(
                            listenable: controller,
                            builder: (context, child) => controller.isVisible
                                ? ref
                                      .watch(
                                        detailsPostsProvider(
                                          (
                                            configFilter,
                                            config,
                                            tag,
                                            widget.filterQuery ??
                                                postFilterQueryNone,
                                          ),
                                        ),
                                      )
                                      .maybeWhen(
                                        data: (data) => data.isNotEmpty
                                            ? SliverPreviewPostGrid(
                                                auth: auth,
                                                posts: data,
                                                limit: previewLimit,
                                                imageUrl: (p) => thumbUrlBuilder
                                                    .resolve(
                                                      p,
                                                      settings: thumbSettings,
                                                    )
                                                    .url,
                                                onShowAll: () =>
                                                    _goToArtistPage(tag),
                                              )
                                            : const SliverSizedBox(),
                                        orElse: () =>
                                            const SliverPreviewPostGridPlaceholder(
                                              limit: previewLimit,
                                            ),
                                      )
                                : const SliverPreviewPostGridPlaceholder(
                                    limit: previewLimit,
                                  ),
                          ),
                        ),
                      ];
                    },
                  ).toList()
                : [],
            orElse: () => [
              const SliverPreviewPostGridPlaceholder(
                limit: previewLimit,
              ),
            ],
          ),
    );
  }

  void _goToArtistPage(String tag) {
    goToArtistPage(ref, tag);
  }
}
