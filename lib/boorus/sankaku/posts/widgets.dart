// Dart imports:
import 'dart:async';

// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/search/routes.dart';
import '../favorites/providers.dart';
import 'post_data.dart';
import 'providers.dart';
import 'types.dart';

class SankakuQuickFavoriteButton extends ConsumerWidget {
  const SankakuQuickFavoriteButton({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = post.sankakuId;
    final config = ref.watchConfigAuth;
    final canFavorite = ref.watch(sankakuCanFavoriteProvider(config));

    if (!canFavorite || id == null) return const SizedBox.shrink();

    final notifier = ref.watch(sankakuFavoritesProvider(config).notifier);
    final isFaved = ref.watch(sankakuFavoriteProvider((config, id)));

    return QuickFavoriteButton(
      isFaved: isFaved,
      onFavToggle: (isFaved) {
        if (isFaved) {
          unawaited(notifier.add(id));
        } else {
          unawaited(notifier.remove(id));
        }
      },
    );
  }
}

class SankakuPostActionToolbar extends ConsumerWidget {
  const SankakuPostActionToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final data = InheritedPost.presentationOf(context).data<SankakuPostData>();
    final controller = PostDetailsPageViewScope.of(context);
    final id = _sankakuId(data?.sankakuId);
    final config = ref.watchConfigAuth;
    final canFavorite = ref.watch(sankakuCanFavoriteProvider(config));
    final isFaved = id != null
        ? ref.watch(sankakuFavoriteProvider((config, id)))
        : false;
    final notifier = ref.watch(sankakuFavoritesProvider(config).notifier);

    return SliverToBoxAdapter(
      child: SimplePostActionToolbar(
        post: post,
        maxVisibleButtons: 5,
        onStartSlideshow: controller.startSlideshow,
        favoriteButton: canFavorite && id != null
            ? FavoritePostButton(
                isFaved: isFaved,
                isAuthorized: canFavorite,
                addFavorite: () => notifier.add(id),
                removeFavorite: () => notifier.remove(id),
              )
            : null,
      ),
    );
  }
}

class SankakuUploaderFileDetailTile extends ConsumerWidget {
  const SankakuUploaderFileDetailTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final uploaderName = post.uploaderName;

    return switch (uploaderName) {
      null => const SizedBox.shrink(),
      final name => UploaderFileDetailTile(
        uploaderName: name,
        onSearch: switch (ref.watch(sankakuUploaderQueryProvider(post))) {
          final query? => () => goToSearchPage(
            ref,
            tag: query.resolveTag(),
          ),
          _ => null,
        },
      ),
    };
  }
}

class SankakuUploaderPostsSection extends ConsumerWidget {
  const SankakuUploaderPostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);

    return UploaderPostsSection<Post>(
      query: ref.watch(
        sankakuUploaderQueryProvider(post),
      ),
    );
  }
}

final kSankakuPostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) => const SankakuPostActionToolbar(),
  },
  full: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) => const SankakuPostActionToolbar(),
    DetailsPart.tags: (context) => const DefaultInheritedTagsTile<Post>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<Post>(
          uploader: SankakuUploaderFileDetailTile(),
        ),
    DetailsPart.artistPosts: (context) =>
        const DefaultInheritedArtistPostsSection<Post>(),
    DetailsPart.uploaderPosts: (context) => const SankakuUploaderPostsSection(),
  },
);

SankakuId? _sankakuId(SankakuPostIdData? data) => switch (data) {
  SankakuPostIdData(value: final value, isNumeric: true) =>
    switch (int.tryParse(value)) {
      final id? => IntId(id),
      null => null,
    },
  SankakuPostIdData(value: final value) => StringId(value),
  null => null,
};
