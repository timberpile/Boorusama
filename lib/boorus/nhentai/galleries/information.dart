import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:intl/intl.dart';
import 'package:kurumi/material.dart';

import '../../../core/artists/types.dart';
import '../../../core/boorus/defaults/widgets.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/details/src/providers/media_group_provider.dart';
import '../../../core/posts/details/src/types/inherited_post.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/details/src/widgets/media_group_actions.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/sources/types.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/selected_tags/types.dart';
import '../search/query.dart';
import '../tags/presentation.dart';
import 'mapper.dart';
import 'related.dart';

final nhentaiGalleryDetailsUi = PostDetailsUIBuilder(
  preview: kFallbackPostDetailsUIBuilder.preview,
  full: {
    DetailsPart.toolbar: (context) =>
        InheritedPost.maybeOf<Post>(context) == null
        ? const MediaGroupSummaryActions()
        : kFallbackPostDetailsUIBuilder.full[DetailsPart.toolbar]!(context),
    for (final part in [
      DetailsPart.galleryTitle,
      DetailsPart.galleryInfo,
      DetailsPart.tags,
    ])
      part: (_) => SliverToBoxAdapter(
        child: NhentaiGalleryInformation(part: part),
      ),
    DetailsPart.galleryRelated: (_) => const NhentaiRelatedGalleries(),
    DetailsPart.fileDetails: (context) =>
        InheritedPost.maybeOf<Post>(context) == null
        ? const SliverToBoxAdapter()
        : kFallbackPostDetailsUIBuilder.full[DetailsPart.fileDetails]!(context),
  },
);

class NhentaiGalleryInformation extends ConsumerWidget {
  const NhentaiGalleryInformation({this.details, this.part, super.key});

  final ContentGroupDetails? details;
  final DetailsPart? part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = GroupViewerScope.maybeEntryOf(context);
    final state = entry == null ? null : ref.watch(mediaGroupProvider(entry));
    final value = details ?? state?.details ?? entry?.storedDetails;
    final summary = value?.summary ?? entry?.summary;
    if (summary == null) return const SizedBox.shrink();
    final id = nhentaiIdFromReference(summary.reference);
    final uploaded = value?.sourceDates?.publishedAt;
    final strings = context.t.nhentai;
    final date = uploaded == null
        ? strings.unknown_date
        : DateFormat.yMMMd(Localizations.localeOf(context).toString())
              .format(uploaded.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (part == null || part == DetailsPart.galleryTitle)
          ArtistSection(
            commentary: ArtistCommentary(
              originalTitle: summary.title ?? '',
              originalDescription: value?.description?.text ?? '',
              translatedTitle: '',
              translatedDescription: '',
            ),
            artistTags: {
              for (final artist in value?.creators ?? []) artist.displayName,
            },
            source: PostSource.from('https://nhentai.net/g/$id/'),
          ),
        if (part == null || part == DetailsPart.galleryInfo)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _GalleryDetail(label: strings.uploaded, value: date),
                _GalleryDetail(label: strings.id, value: '$id'),
              ],
            ),
          ),
        if (part == null || part == DetailsPart.tags)
          NhentaiGalleryTags(
            tags: value?.tags ?? summary.previewTags,
            access: state?.access,
          ),
      ],
    );
  }
}

class NhentaiGalleryTags extends ConsumerWidget {
  const NhentaiGalleryTags({
    required this.tags,
    required this.access,
    super.key,
  });

  final GroupTags? tags;
  final ContentAccessContext? access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = access?.config?.auth ?? BooruConfig.empty.auth;
    final config = access?.key.profileId == null ? null : access?.config;
    final sections = <NhentaiTagSection, List<GroupTag>>{};
    for (final tag in tags?.values ?? const <GroupTag>[]) {
      if (tag.name?.isNotEmpty ?? false) {
        sections
            .putIfAbsent(NhentaiTagSection.fromSource(tag.category), () => [])
            .add(tag);
      }
    }
    if (sections.isEmpty) return const SizedBox.shrink();

    return RawTagsTile(
      title: Text(
        context.t.tags.counter(
          n: sections.values.expand((list) => list).length,
        ),
      ),
      initiallyExpanded: true,
      children: [
        for (final section in NhentaiTagSection.values)
          if (sections[section] case final group?)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    section.label(context),
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 6,
                    children: [
                      for (final tag in group)
                        TagChip(
                          text: tag.displayName ?? tag.name!,
                          auth: auth,
                          colorOverride: section.color(context, ref, auth),
                          onTap: config == null
                              ? null
                              : () => _search(ref, config, tag),
                        ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _search(WidgetRef ref, BooruConfig config, GroupTag tag) =>
      goToSearchPage(
        ref,
        config: config,
        tags: SearchTagSet.fromList([
          nhentaiTagQuery(tag.name!, tag.category),
        ]),
        queryType: QueryType.list,
      );
}

class _GalleryDetail extends StatelessWidget {
  const _GalleryDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      Text(value),
    ],
  );
}
