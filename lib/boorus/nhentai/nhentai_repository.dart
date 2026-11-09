import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/boorus/defaults/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/create.dart';
import '../../core/content/content_access_provider.dart';
import '../../core/content/types.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/content/groups/group_source_provider.dart';
import '../../core/posts/post/providers.dart';
import '../../core/posts/post/types.dart';
import '../../core/search/queries/providers.dart';
import '../../core/settings/providers.dart';
import '../../core/tags/autocompletes/types.dart';
import 'client_provider.dart';
import 'galleries/mapper.dart';
import 'galleries/source.dart';
import 'posts/data.dart';

class NhentaiRepository extends BooruRepositoryDefault {
  const NhentaiRepository({required this.ref});
  @override
  final Ref ref;
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
      EmptyAutocompleteRepository();
  @override
  BooruSiteValidator siteValidator(BooruConfigAuth config) =>
      () => ref
          .read(nhentaiClientProvider(config))
          .getMediaPolicy()
          .then((_) => true);
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
    fetchSingle: (id, {options}) async {
      final identity = switch (id) {
        StringPostId(:final value) => NhentaiPageIdentity.parse(value),
        NumericPostId(:final value) => NhentaiPageIdentity.fromNumericPostId(
          value,
        ),
      };
      final access = ref.read(
        contentAccessForReferenceProvider(
          ContentAccessRequest(
            reference: const ContentReferenceCodec().parse(
              engine: config.auth.booruType,
              site: Uri.parse(config.auth.url),
              kind: ContentKind.post,
              sourceKey: identity.sourceKey,
            ),
          ),
        ),
      );
      if (access == null || access.config?.auth != config.auth) return null;
      final source = ref.read(
        contentGroupSourceProvider(access.key),
      ) as NhentaiGallerySource;
      final gallery = await source.gallery(
        nhentaiGalleryReference(access, identity.galleryId),
      );
      final policy = await source.mediaPolicy();
      return nhentaiGalleryPosts(
        gallery,
        access,
        policy,
      ).where((post) => post.id == identity.numericPostId).firstOrNull;
    },
  );
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
