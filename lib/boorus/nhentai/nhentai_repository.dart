import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/blacklists/providers.dart';
import '../../core/boorus/defaults/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/create.dart';
import '../../core/configs/manage/providers.dart';
import '../../core/content/content_access_provider.dart';
import '../../core/content/types.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/content/groups/group_source_provider.dart';
import '../../core/http/client/coordination.dart';
import '../../core/posts/post/providers.dart';
import '../../core/posts/post/types.dart';
import '../../core/search/queries/providers.dart';
import '../../core/search/following_topics/src/refresh/gallery_topic_refresh_source.dart';
import '../../core/settings/providers.dart';
import '../../core/tags/autocompletes/types.dart';
import 'availability.dart';
import 'client_provider.dart';
import 'favorites/account.dart';
import 'search/query.dart';
import 'tags/providers.dart';
import 'tags/store.dart';
import 'galleries/followed_search.dart';
import 'galleries/mapper.dart';
import 'galleries/source.dart';
import 'posts/data.dart';

class NhentaiRepository extends BooruRepositoryDefault {
  const NhentaiRepository({required this.ref});
  @override
  final Ref ref;

  @override
  GalleryTopicRefreshSource? galleryTopicRefreshSource(
    BooruConfigAuth config,
  ) => ref.read(nhentaiAvailableProvider) && isNhentaiProfile(config)
      ? _refreshGalleryTopic
      : null;

  Future<GalleryTopicRefreshPage> _refreshGalleryTopic(
    BooruConfig config,
    String rawQuery,
  ) async {
    final query = ref
        .read(defaultTagQueryComposerProvider(config.search))
        .compose([rawQuery])
        .join(' ');
    const limit = GalleryTopicRefreshPage.maxResults;
    final client = ref.read(nhentaiClientProvider(config.auth));
    final pages = ref.read(
      nhentaiFollowedSearchProvider((config.id, config.auth)),
    );
    final page = await pages.load(
      query,
      () => client.getGalleries(
        query: query,
        cancelToken: ApiRequestContext.current().cancelToken,
      ),
      refresh: true,
    );
    final items = page.items.take(limit).toList();
    final hasMore =
        (page.total ?? 0) > items.length ||
        (page.hasMore ?? items.length == limit) ||
        page.items.length > limit;
    return GalleryTopicRefreshPage(
      ids: items.map((item) => item.id).toList(),
      hasMore: hasMore,
    );
  }

  @override
  BooruLoginDetails loginDetails(BooruConfigAuth config) =>
      _NhentaiLoginDetails(
        isNhentaiProfile(config) && isNhentaiApiKey(config.apiKey),
      );
  @override
  BooruPostDataCodec<NhentaiPostData> get postDataCodec =>
      const NhentaiPostCodec();
  @override
  DownloadFilenameGenerator<Post> downloadFilenameBuilder(
    BooruConfigAuth config,
  ) => DownloadFileNameBuilder<Post>(
    defaultFileNameFormat: '{id}.{extension}',
    defaultBulkDownloadFileNameFormat: '{id}.{extension}',
    sampleData: kDanbooruPostSamples,
    hasMd5: false,
    hasRating: false,
    tokenHandlers: const [],
  );
  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) =>
      AutocompleteRepositoryBuilder(
        autocomplete: (query) async {
          final term = NhentaiSearchTerm.trailing(query.text);
          if (!ref.read(nhentaiAvailableProvider) ||
              term == null ||
              term.prefix.isEmpty ||
              term.prefix.length > NhentaiClient.tagSearchQueryLimit) {
            return [];
          }
          final type = term.type ?? query.category;
          if (type != null && !NhentaiClient.tagTypes.contains(type)) return [];
          final token = query.cancelToken;
          try {
            final tags = await runWithApiRequestContext(
              ApiRequestContext(
                replaySafety: ApiReplaySafety.safeRead,
                cancelToken: token,
                allowCooldownRetry: false,
                admissionBehavior: ApiAdmissionBehavior.dropIfUnavailable,
              ),
              () => ref
                  .read(nhentaiClientProvider(config))
                  .searchTags(
                    term.prefix,
                    type: type,
                    cancelToken: token,
                  ),
            );
            if (token?.cancelError case final error?) throw error;
            if (tags.isNotEmpty) {
              unawaited(
                ref
                    .read(nhentaiTagCacheProvider(config))
                    .remember(tags, cancelToken: token)
                    .onError((_, _) {}),
              );
            }
            return tags.map(nhentaiSuggestion).toList();
          } catch (_) {
            if (token?.cancelError case final error?) throw error;
            final cached = await ref
                .read(nhentaiTagStoreProvider)
                .suggest(term.prefix, type);
            if (token?.cancelError case final error?) throw error;
            return cached;
          }
        },
      );
  @override
  BooruSiteValidator siteValidator(BooruConfigAuth config) => () async {
    if (!ref.read(nhentaiAvailableProvider)) return false;
    await ref.read(nhentaiMediaPolicyProvider(config).future);
    return true;
  };
  @override
  Dio dio(BooruConfigAuth config) => ref.watch(nhentaiDioProvider(config));
  @override
  Map<String, String> extraHttpHeaders(BooruConfigAuth config) => const {
    'Referer': 'https://nhentai.net/',
  };
  @override
  PostLinkGenerator<Post> postLinkGenerator(BooruConfigAuth config) =>
      const NhentaiPostLinkGenerator();
  @override
  PostRepository<Post> post(
    BooruConfigSearch config,
  ) => PostRepositoryBuilder<Post>(
    tagComposer: ref.watch(defaultTagQueryComposerProvider(config)),
    getSettings: () async =>
        ref.read(listingSettingsForAuthProvider(config.auth)),
    // Native lists contain Galleries; Post-only consumers do not fabricate a
    // representative Page or issue a detail read for every Gallery card.
    fetch: (_, _, {limit, options}) async => <Post>[].toResult(hasMore: false),
    fetchSingle: (id, {options}) => _loadPage(config, id),
  );

  Future<Post?> _loadPage(BooruConfigSearch config, PostId id) async {
    // A standalone Page lookup owns its reads independently of the engine registry.
    final container = ref.container;
    if (!container.read(nhentaiAvailableProvider)) return null;
    final identity = switch (id) {
      StringPostId(:final value) => NhentaiPageIdentity.parse(value),
      NumericPostId(:final value) => NhentaiPageIdentity.fromNumericPostId(
        value,
      ),
    };
    final ContentAccessContext? access;
    if (config.auth.anonymousReadScope case final scope?) {
      access = container.read(contentAccessContextProvider(scope.key));
    } else {
      final profile = container
          .read(booruConfigProvider)
          .where(
            (profile) =>
                (config.profileId == null || profile.id == config.profileId) &&
                profile.auth == config.auth,
          )
          .singleOrNull;
      if (profile == null) return null;
      final blacklist = container.listen(
        blacklistTagsProvider(profile.filter).future,
        (_, _) {},
      );
      try {
        await blacklist.read();
      } finally {
        blacklist.close();
      }
      access = container.read(contentProfileAccessProvider(profile.id));
    }
    if (access == null || access.config?.auth != config.auth) return null;
    final sourceLease = container.listen(
      contentGroupSourceStateProvider(access.key).future,
      (_, _) {},
    );
    try {
      final source = await sourceLease.read();
      if (source is! NhentaiGallerySource) return null;
      final gallery = await source.gallery(
        nhentaiGalleryReference(access, identity.galleryId),
      );
      final policy = await source.mediaPolicy();
      final current = container.read(contentAccessContextProvider(access.key));
      if (current == null || !current.hasSameAuthorization(access)) return null;
      return nhentaiGalleryPosts(
        gallery,
        access,
        policy,
      ).where((post) => post.id == identity.numericPostId).firstOrNull;
    } finally {
      sourceLease.close();
    }
  }
}

class _NhentaiLoginDetails
    with UnrestrictedBooruLoginDetails
    implements BooruLoginDetails {
  const _NhentaiLoginDetails(this._hasKey);
  final bool _hasKey;

  @override
  bool hasLogin() => _hasKey;
}

class NhentaiPostLinkGenerator implements PostLinkGenerator<Post> {
  const NhentaiPostLinkGenerator();
  @override
  String getLink(Post post) => switch (post.booruData) {
    NhentaiPostData(:final galleryId, :final pageNumber) =>
      'https://nhentai.net/g/$galleryId/$pageNumber/',
    _ => throw const FormatException('Foreign nhentai Page'),
  };
}
