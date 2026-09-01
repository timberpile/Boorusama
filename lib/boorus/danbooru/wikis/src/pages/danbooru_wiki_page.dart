// Flutter imports:
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../core/posts/details_parts/widgets.dart';
import '../../../../../core/search/search/routes.dart';
import '../../../../../core/tags/details/widgets.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../artists/artist/providers.dart';
import '../../../artists/artist/types.dart';
import '../../../artists/urls/widgets.dart';
import '../../../tags/details/widgets.dart';
import '../routes/route_utils.dart';
import '../types/wiki.dart';
import '../widgets/danbooru_wiki_dtext_body.dart';
import '../wiki_providers.dart';

class DanbooruWikiPage extends ConsumerWidget {
  const DanbooruWikiPage({
    required this.wikiPageName,
    super.key,
  });

  final String wikiPageName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wiki = ref.watch(danbooruWikiProvider(wikiPageName));
    final wikiValue = wiki.valueOrNull;
    final artistState =
        wiki.hasValue && (wikiValue == null || wikiValue.type is TagWiki)
        ? ref.watch(danbooruArtistProvider(wikiPageName))
        : null;
    final artist = artistState?.valueOrNull;
    final theme = Kurumi.themeOf(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (wikiValue?.type case TagWiki(:final tag))
            IconButton(
              onPressed: () => goToSearchPage(ref, tag: tag),
              icon: const Icon(Symbols.search),
            ),
          IconButton(
            tooltip: context.t.post.action.view_in_browser,
            onPressed: () => openDanbooruWikiPageInBrowser(
              ref,
              wikiPageName,
            ),
            icon: const Icon(Icons.open_in_browser),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () =>
            ref.read(danbooruWikiProvider(wikiPageName).notifier).reload(),
        child: wiki.when(
          data: (wiki) {
            if (wiki == null) {
              if (artistState?.isLoading ?? false) {
                return const _WikiPageFill(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              if (artist != null && !artist.isEmpty) {
                return CustomScrollView(
                  slivers: [
                    _ArtistDetailsSliver(
                      artist: artist,
                    ),
                  ],
                );
              }

              return const _WikiPageFill(
                child: NoDataBox(),
              );
            }

            return CustomScrollView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        wiki.title.replaceAll('_', ' '),
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (wiki.otherNames.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final name in wiki.otherNames)
                              RawTagChip(
                                text: name.replaceAll('_', ' '),
                                maxTextLength: 100,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                backgroundColor: colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                foregroundColor: colorScheme.primary,
                                borderColor: colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: DanbooruWikiDTextSliverBody(data: wiki.body),
                ),
                if (artist != null && !artist.isEmpty)
                  _ArtistDetailsSliver(artist: artist),
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 24),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
          loading: () => const _WikiPageFill(
            child: CircularProgressIndicator.adaptive(),
          ),
          error: (error, _) => _WikiPageFill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error.toString()),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistDetailsSliver extends StatelessWidget {
  const _ArtistDetailsSliver({
    required this.artist,
  });

  final DanbooruArtist artist;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            TagOtherNames(otherNames: artist.otherNames),
            const SizedBox(height: 8),
            DanbooruArtistUrlChips(
              artistUrls: artist.activeUrls.map((e) => e.url).toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 16,
              ),
              child: ArtistTagCloud(tagName: artist.name),
            ),
          ],
        ),
      ),
    );
  }
}

class _WikiPageFill extends StatelessWidget {
  const _WikiPageFill({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Center(child: child),
        ),
      ],
    );
  }
}
