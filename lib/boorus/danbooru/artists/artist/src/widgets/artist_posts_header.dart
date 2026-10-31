import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/search/search/routes.dart';
import '../../../../../../core/posts/listing/widgets.dart';
import '../../../../../../core/posts/listing/providers.dart';
import '../../../../../../core/posts/links/boorusama_artist_link.dart';
import '../../../../../../core/posts/links/share_artist_link_button.dart';
import '../../../../../../core/tags/tag/types.dart';

class DanbooruArtistPostsHeader extends ConsumerStatefulWidget {
  const DanbooruArtistPostsHeader({
    required this.artistName,
    required this.category,
    required this.onCategoryChanged,
    super.key,
    this.controller,
  });

  final PostGridController? controller;
  final String artistName;
  final TagFilterCategory category;
  final ValueChanged<TagFilterCategory> onCategoryChanged;

  @override
  ConsumerState<DanbooruArtistPostsHeader> createState() =>
      _ArtistPostsHeaderState();
}

class _ArtistPostsHeaderState extends ConsumerState<DanbooruArtistPostsHeader> {
  int? _count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    context.t.artist_page.posts,
                    style: Kurumi.themeOf(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.controller case final controller?)
                  ListenableBuilder(
                    listenable: controller,
                    builder: (_, _) {
                      if (!controller.refreshing &&
                          controller.errors.value == null) {
                        _count = controller.count.value ?? controller.total;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          _count?.toString() ?? '',
                          style: Kurumi.themeOf(context).textTheme.labelMedium,
                        ),
                      );
                    },
                  ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: TextButton.icon(
                    onPressed: () => goToSearchPage(
                      ref,
                      tag: widget.artistName,
                      config: ref.readConfig,
                    ),
                    icon: const Icon(Symbols.search),
                    label: Text(context.t.generic.action.search),
                  ),
                ),
                ArtistLinkShareButton(
                  profileName: ref.watchConfig.name,
                  link: BoorusamaArtistLink.fromArtist(
                    auth: ref.watchConfigAuth,
                    artistName: widget.artistName,
                  ),
                ),
                if (widget.controller case final controller?)
                  PostGridConfigIconButton(postController: controller),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        KurumiSegmentedButton<TagFilterCategory>(
          key: ValueKey(widget.category),
          initialValue: widget.category,
          segments: {
            TagFilterCategory.newest: context.t.explore.newest,
            TagFilterCategory.popular: context.t.explore.popular,
          },
          onChanged: widget.onCategoryChanged,
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
