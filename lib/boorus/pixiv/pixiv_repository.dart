// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/boorus/defaults/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/create.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/posts/post/types.dart';
import '../../core/tags/autocompletes/types.dart';
import 'client_provider.dart';
import 'posts/link_generator.dart';
import 'posts/providers.dart';
import 'posts/types.dart';
import 'tags/providers.dart';

const kPixivCustomDownloadFileNameFormat = '{illust_id}_p{page}.{extension}';

class PixivRepository extends BooruRepositoryDefault {
  const PixivRepository({required this.ref});

  @override
  final Ref ref;

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(pixivPostRepoProvider(config));
  }

  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return ref.watch(pixivAutocompleteRepoProvider(config));
  }

  @override
  PostLinkGenerator<Post> postLinkGenerator(BooruConfigAuth config) {
    return const PixivPostLinkGenerator();
  }

  /// Every app-api endpoint requires authentication (there is no anonymous
  /// mode), so before S3 wires real token retrieval this legitimately fails
  /// with an auth error rather than reporting success — the "not
  /// authenticated" outcome the brief calls for, surfaced as a normal
  /// rejected future rather than a crash or a hang.
  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final client = ref.watch(pixivClientProvider(config));

    return () => client.searchIllust(word: 'a').then((_) => true);
  }

  @override
  DownloadFilenameGenerator<Post> downloadFilenameBuilder(
    BooruConfigAuth config,
  ) {
    return DownloadFileNameBuilder<Post>(
      defaultFileNameFormat: kPixivCustomDownloadFileNameFormat,
      defaultBulkDownloadFileNameFormat: kPixivCustomDownloadFileNameFormat,
      sampleData: const [],
      // Pixiv exposes no file hash.
      hasMd5: false,
      extensionHandler: (post, config) =>
          post.format.startsWith('.') ? post.format.substring(1) : post.format,
      tokenHandlers: [
        TokenHandler('illust_id', (post, options) {
          return post is PixivPost ? post.illustId.toString() : '';
        }),
        TokenHandler('page', (post, options) {
          return post is PixivPost ? post.pageIndex.toString() : '';
        }),
        TokenHandler('user_id', (post, options) {
          return post is PixivPost ? post.userId.toString() : '';
        }),
        TokenHandler('user_name', (post, options) {
          return post is PixivPost ? post.userName : '';
        }),
      ],
    );
  }

  @override
  Dio dio(BooruConfigAuth config) {
    return ref.watch(pixivDioProvider(config));
  }

  /// Feeds both image loading and download tasks via `httpHeadersProvider` —
  /// without this, `i.pximg.net` returns 403 for every thumbnail, original,
  /// and downloaded file. This is the *image* referer
  /// (`https://www.pixiv.net/`), distinct from the app-api referer the
  /// client attaches to its own requests.
  @override
  Map<String, String> extraHttpHeaders(BooruConfigAuth config) {
    return {
      'Referer': kPixivImageReferer,
    };
  }
}
