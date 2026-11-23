// Package imports:
import 'package:booru_clients/nozomi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../../../core/tags/categories/providers.dart';
import '../../../core/tags/local/providers.dart';
import '../client_provider.dart';
import 'parser.dart';
import 'search_request.dart';

final nozomiPostRepoProvider =
    Provider.family<PostRepository<Post>, BooruConfigSearch>((ref, config) {
      return _createNozomiPostRepository(
        ref: ref,
        config: config,
        order: NozomiPostOrder.date,
      );
    });

final nozomiPostRepoWithOrderProvider =
    Provider.family<
      PostRepository<Post>,
      ({BooruConfigSearch config, NozomiPostOrder order})
    >(
      (ref, params) => _createNozomiPostRepository(
        ref: ref,
        config: params.config,
        order: params.order,
      ),
    );

PostRepository<Post> _createNozomiPostRepository({
  required Ref ref,
  required BooruConfigSearch config,
  required NozomiPostOrder order,
}) {
  final client = ref.watch(nozomiClientProvider(config.auth));
  final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));
  return PostRepositoryBuilder<Post>(
    tagComposer: tagComposer,
    fetchSingle: (id, {options}) async {
      final numericId = id as NumericPostId?;
      if (numericId == null) return Future.value();
      final post = await client.getPost(id: numericId.value);
      if (post != null) {
        await _saveNozomiTagCategories(ref, config.auth.url, [post]);
      }
      return post != null ? postDtoToPost(post, null) : null;
    },
    fetch: (tags, page, {limit, options}) async {
      final request = NozomiSearchRequest.fromTags(tags, fallbackOrder: order);
      // Match NozomiClient's bounded ID-page stride before missing DTOs are removed.
      final pageLimit = (limit ?? 64).clamp(1, 100);
      final result = await client.getPostsWithTotal(
        tags: request.tags,
        page: page,
        limit: pageLimit,
        order: request.order,
      );
      await _saveNozomiTagCategories(ref, config.auth.url, result.posts);
      final total = result.total;
      return result.posts
          .map(
            (e) => postDtoToPost(
              e,
              PostMetadata(
                page: page,
                search: tags.join(' '),
                limit: pageLimit,
              ),
            ),
          )
          .toList()
          .toResult(
            total: total,
            hasMore: total != null && total >= 0
                ? page * pageLimit < total
                : null,
          );
    },
    getSettings: () async =>
        ref.read(listingSettingsForAuthProvider(config.auth)),
  );
}

Future<void> _saveNozomiTagCategories(
  Ref ref,
  String siteHost,
  Iterable<NozomiPostDto> posts,
) async {
  final tagInfos = {
    for (final tagInfo in posts.expand(
      (post) => postDtoToTagInfos(post, siteHost),
    ))
      tagInfo.tagName: tagInfo,
  }.values.toList();
  if (tagInfos.isEmpty) return;
  final tagCache = await ref.read(tagCacheRepositoryProvider.future);
  final resolved = await tagCache.resolveTags(
    siteHost,
    tagInfos.map((tagInfo) => tagInfo.tagName).toList(),
  );
  final missingTags = resolved.missing.toSet();
  final missingTagInfos = tagInfos
      .where((tagInfo) => missingTags.contains(tagInfo.tagName))
      .toList();
  if (missingTagInfos.isEmpty) return;
  final tagTypeStore = await ref.read(booruTagTypeStoreProvider.future);
  await tagTypeStore.saveOrUpdateTagsBatch(missingTagInfos);
}
