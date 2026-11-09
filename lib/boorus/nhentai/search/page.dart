import 'package:booru_clients/nhentai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/blacklists/providers.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/content/types.dart';
import '../../../core/content/widgets/native_content_grid.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/settings/providers.dart';
import '../../../core/posts/rating/types.dart';
import '../client_provider.dart';
import '../galleries/mapper.dart';
import '../galleries/source.dart';
import '../tags/providers.dart';

/// Browse and Search use the real Gallery listing, never one detail call per
/// card. The common grid owns continuation, route guards and mixed navigation.
class NhentaiSearchPage extends ConsumerStatefulWidget {
  const NhentaiSearchPage({required this.params, super.key});
  final SearchParams params;
  @override
  ConsumerState<NhentaiSearchPage> createState() => _NhentaiSearchPageState();
}

class _NhentaiSearchPageState extends ConsumerState<NhentaiSearchPage> {
  late final _query = TextEditingController(
    text: widget.params.query ?? widget.params.tags?.rawTags.join(' ') ?? '',
  );
  late String _search = _query.text.trim();

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final access = ref.watch(contentProfileAccessProvider(config.id));
    final source = access == null
        ? null
        : ref.watch(
            contentGroupSourceProvider(access.key),
          ) as NhentaiGallerySource;
    final settings = ref.watch(imageListingSettingsProvider);
    return Scaffold(
      appBar: KurumiAppBar(
        title: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: context.t.search.hint),
          onSubmitted: (value) => setState(() => _search = value.trim()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.t.generic.action.search,
            onPressed: () => setState(() => _search = _query.text.trim()),
          ),
        ],
      ),
      body: access == null
          ? const Center(child: CircularProgressIndicator())
          : NativeContentGrid(
              access: access,
              queryIdentity: _search,
              pageMode: settings.pageMode,
              initialPage: widget.params.page ?? 1,
              onRefresh: () {
                source!.invalidateAll();
                ref.invalidate(nhentaiMediaPolicyProvider(config.auth));
              },
              fetchPage: (page) async {
                final client = ref.read(nhentaiClientProvider(config.auth));
                final results = await client.getGalleries(
                  page: page,
                  perPage: settings.postsPerPage.clamp(1, 100),
                  query: _search.isEmpty ? null : _search,
                );
                final policy = await ref.read(
                  nhentaiMediaPolicyProvider(config.auth).future,
                );
                final blacklist = await ref.read(
                  blacklistTagsProvider(config.filter).future,
                );
                final tags = blacklist.isEmpty
                    ? const <int, NhentaiTag>{}
                    : await ref
                          .read(nhentaiTagCacheProvider(config.auth))
                          .resolveVisible(
                            results.items.expand((item) => item.tagIds),
                          );
                final summaries = [
                  for (final dto in results.items)
                    if (dto.blacklisted != true &&
                        groupAllowsRating(config, Rating.unknown))
                      nhentaiGallerySummary(
                        dto,
                        access,
                        policy,
                        resolvedTags: tags,
                      ),
                ];
                summaries.removeWhere(
                  (summary) => !groupTagsPassBlacklist(
                    summary.previewTags,
                    blacklist,
                    rating: Rating.unknown,
                    sourceId: int.parse(
                      summary.reference.sourceKey.split(':').last,
                    ),
                    sourceUrl: summary.reference.site.toString(),
                  ),
                );
                for (final summary in summaries) {
                  source!.seedSummary(summary);
                }
                return NativeContentPage(
                  entries: [
                    for (final summary in summaries)
                      GroupContentEntry(summary: summary),
                  ],
                  // Unknown continuation cannot justify an automatic loop.
                  hasMore: results.hasMore == true,
                  total: results.total,
                  rawCount: results.rawCount,
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }
}
