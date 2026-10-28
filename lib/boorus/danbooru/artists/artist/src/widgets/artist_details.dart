import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../../foundation/clipboard.dart';
import '../../../../tags/details/src/artist_tag_cloud.dart';
import '../../../../wikis/providers.dart';
import '../../../../wikis/routes.dart';
import '../../../urls/widgets.dart';
import '../providers/artist_notifier.dart';
import '../types/artist.dart';
import 'artist_related_tags_sheet.dart';

class DanbooruArtistDetails extends ConsumerStatefulWidget {
  const DanbooruArtistDetails({required this.artistName, super.key});
  final String artistName;

  @override
  ConsumerState<DanbooruArtistDetails> createState() =>
      _DanbooruArtistDetailsState();
}

class _DanbooruArtistDetailsState extends ConsumerState<DanbooruArtistDetails> {
  var _expanded = false;
  var _showAllUrls = false;
  var _socialsOverflow = false;
  ArtistRelatedTagSort _sort = ArtistRelatedTagSort.count;

  @override
  Widget build(BuildContext context) {
    final artist = ref
        .watch(danbooruArtistProvider(widget.artistName))
        .valueOrNull;
    final wiki = ref.watch(danbooruWikiProvider(widget.artistName)).valueOrNull;
    final availableTags =
        ref
            .watch(danbooruRelatedTagCloudProvider(widget.artistName))
            .valueOrNull ??
        [];
    final tags = {
      for (final tag in availableTags)
        if (tag.tag.trim().isNotEmpty) tag.tag: tag,
    }.values.toList();
    final aliases =
        artist?.otherNames
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList() ??
        <String>[];
    final urls = validArtistProfileUrls(
      artist?.activeUrls.map((entry) => entry.url) ?? [],
    );
    final strings = context.t.artist_page;
    final compact = MediaQuery.sizeOf(context).width < 400;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              if (aliases.isNotEmpty)
                ArtistMetadataPill(
                  label: '${strings.aliases} ${aliases.length}',
                  icon: Symbols.sell,
                  expanded: _expanded,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              if (wiki != null && wiki.body.trim().isNotEmpty)
                ArtistMetadataPill(
                  label: strings.wiki,
                  icon: Symbols.menu_book,
                  onPressed: () => goToDanbooruWikiPage(ref, widget.artistName),
                ),
              if (tags.isNotEmpty)
                ArtistMetadataPill(
                  label:
                      '${compact ? strings.related_tags_short : strings.related_tags} ${tags.length}',
                  icon: Symbols.sell,
                  onPressed: () {
                    final container = ProviderScope.containerOf(
                      context,
                      listen: false,
                    );
                    Kurumi.showAppModalBottomSheet(
                      context: context,
                      builder: (_) => UncontrolledProviderScope(
                        container: container,
                        child: ArtistRelatedTagsSheet(
                          tags: tags,
                          initialSort: _sort,
                          onSortChanged: (sort) => _sort = sort,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final alias in aliases)
                    ActionChip(
                      label: Text(alias.replaceAll('_', ' ')),
                      tooltip: context.t.post.action.copy,
                      onPressed: () =>
                          AppClipboard.copyWithDefaultToast(context, alias),
                    ),
                ],
              ),
            ),
          if (urls.isNotEmpty) ...[
            const Divider(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.socials,
                    style: Kurumi.themeOf(context).textTheme.labelMedium,
                  ),
                ),
                if (_showAllUrls || _socialsOverflow)
                  Semantics(
                    expanded: _showAllUrls,
                    child: IconButton(
                      tooltip: _showAllUrls
                          ? context.t.generic.action.show_less
                          : '${context.t.generic.action.show_all} (${urls.length})',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 24),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      iconSize: 20,
                      icon: Icon(
                        _showAllUrls
                            ? Symbols.expand_more
                            : Symbols.chevron_right,
                      ),
                      onPressed: () =>
                          setState(() => _showAllUrls = !_showAllUrls),
                    ),
                  ),
              ],
            ),
            DanbooruArtistUrlChips(
              artistUrls: urls,
              singleRow: !_showAllUrls,
              onOverflowChanged: (overflow) {
                if (mounted && overflow != _socialsOverflow) {
                  setState(() => _socialsOverflow = overflow);
                }
              },
              showLabels: true,
              alignment: WrapAlignment.start,
            ),
          ],
        ],
      ),
    );
  }
}

class ArtistMetadataPill extends StatelessWidget {
  const ArtistMetadataPill({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expanded,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool? expanded;

  @override
  Widget build(BuildContext context) => Semantics(
    expanded: expanded,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const StadiumBorder(),
        textStyle: Kurumi.themeOf(context).textTheme.labelSmall,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Flexible(child: Text(label)),
          Icon(
            (expanded ?? false) ? Symbols.expand_less : Symbols.chevron_right,
            size: 14,
          ),
        ],
      ),
    ),
  );
}
