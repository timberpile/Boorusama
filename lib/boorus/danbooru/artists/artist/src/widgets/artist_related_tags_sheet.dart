import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:intl/intl.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/search/search/routes.dart';
import '../../../../../../core/tags/tag/providers.dart';
import '../../../../tags/related/types.dart';
import '../../../../tags/tag/widgets.dart';

enum ArtistRelatedTagSort { count, name }

List<DanbooruRelatedTagItem> sortArtistRelatedTags(
  List<DanbooruRelatedTagItem> tags,
  ArtistRelatedTagSort sort,
) => [...tags]
  ..sort((a, b) {
    if (sort == ArtistRelatedTagSort.count) {
      final count = b.postCount.compareTo(a.postCount);
      if (count != 0) return count;
    }
    return a.tag.compareTo(b.tag);
  });

class ArtistRelatedTagsSheet extends ConsumerStatefulWidget {
  const ArtistRelatedTagsSheet({
    required this.tags,
    required this.initialSort,
    required this.onSortChanged,
    super.key,
  });
  final List<DanbooruRelatedTagItem> tags;
  final ArtistRelatedTagSort initialSort;
  final ValueChanged<ArtistRelatedTagSort> onSortChanged;

  @override
  ConsumerState<ArtistRelatedTagsSheet> createState() =>
      _ArtistRelatedTagsSheetState();
}

class _ArtistRelatedTagsSheetState
    extends ConsumerState<ArtistRelatedTagsSheet> {
  late var _sort = widget.initialSort;

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final tags = sortArtistRelatedTags(widget.tags, _sort);
    final strings = context.t.artist_page;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${strings.related_tags} · ${tags.length}',
                      style: Kurumi.themeOf(context).textTheme.titleLarge,
                    ),
                  ),
                  const CloseButton(),
                ],
              ),
              const SizedBox(height: 4),
              KurumiSegmentedButton<ArtistRelatedTagSort>(
                initialValue: _sort,
                segments: {
                  ArtistRelatedTagSort.count: strings.by_count,
                  ArtistRelatedTagSort.name: strings.alphabetical,
                },
                onChanged: (sort) {
                  setState(() => _sort = sort);
                  widget.onSortChanged(sort);
                },
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in tags)
                        DanbooruTagContextMenu(
                          tag: tag.tag,
                          child: ActionChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    tag.tag.replaceAll('_', ' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // The existing DTO contains tag-wide totals.
                                if (tag.postCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    NumberFormat.compact().format(
                                      tag.postCount,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            labelStyle: TextStyle(
                              color: ref.watch(
                                tagColorProvider((
                                  config.auth,
                                  tag.category.name,
                                )),
                              ),
                            ),
                            tooltip: tag.postCount > 0
                                ? strings.tag_post_count(count: tag.postCount)
                                : null,
                            onPressed: () {
                              Navigator.of(context).pop();
                              goToSearchPage(ref, tag: tag.tag, config: config);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
