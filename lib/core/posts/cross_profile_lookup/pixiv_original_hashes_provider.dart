import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../../../boorus/pixiv/client_provider.dart';
import '../../../boorus/pixiv/posts/parser.dart';
import '../../../boorus/pixiv/posts/types.dart';
import '../../blacklists/providers.dart';
import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../content/content_access.dart';
import '../../content/content_access_provider.dart';
import '../../proxy/client.dart';
import '../../proxy/types.dart';
import 'src/data/post_lookup_visibility.dart';
import 'src/data/pixiv_original_hashes.dart';
import 'types.dart';

final pixivLookupSourceProfilesProvider = Provider((ref) {
  return ref.watch(
    booruConfigProvider.select(
      (profiles) => profiles
          .where(
            (profile) => profile.auth.booruType == BooruType.pixiv,
          )
          .toList()
          .lock,
    ),
  );
});

final _downloadQueueProvider = Provider((_) => PixivHashDownloadQueue());

final _mediaHasherProvider =
    Provider.family<PixivOriginalMediaHasher, ProxySettings?>((ref, proxy) {
      // No API tokens, cookies, certificate exceptions or authenticated Dio
      // interceptors are inherited by this dedicated public-CDN transport.
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          followRedirects: false,
          headers: const {'User-Agent': 'Boorusama'},
        ),
      );
      if (proxy != null) {
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () =>
              createProxyHttpClient(proxy)..badCertificateCallback = null,
        );
      }
      ref.onDispose(() => dio.close(force: true));
      return PixivOriginalMediaHasher(
        dio: dio,
        queue: ref.watch(_downloadQueueProvider),
      );
    });

final pixivOriginalHashResolverProvider = Provider.autoDispose
    .family<PixivOriginalHashResolver, PixivArtworkReference>((ref, artwork) {
      final source = ref
          .watch(pixivLookupSourceProfilesProvider)
          .where((profile) => profile.auth.apiKey?.trim().isNotEmpty ?? false)
          .firstOrNull;
      return _createHashResolver(ref, artwork, source: source);
    });

final nativePixivOriginalHashResolverProvider = Provider.autoDispose
    .family<PixivOriginalHashResolver, NativePixivLookupRequest>((
      ref,
      request,
    ) {
      final access = ref.watch(
        contentAccessContextProvider(request.sourceAccess),
      );
      return _createHashResolver(
        ref,
        request.artwork,
        source: access?.config,
        access: access,
        pageIndex: request.pageIndex,
      );
    });

PixivOriginalHashResolver _createHashResolver(
  Ref ref,
  PixivArtworkReference artwork, {
  required BooruConfig? source,
  ContentAccessContext? access,
  int? pageIndex,
}) {
  var disposed = false;
  bool current() =>
      !disposed &&
      (source == null || ref.read(booruConfigProvider).contains(source)) &&
      (access == null ||
          identical(
            ref.read(contentAccessContextProvider(access.key)),
            access,
          ));

  final resolver = PixivOriginalHashResolver(
    artworkId: artwork.id,
    pageIndex: pageIndex,
    isSourceCurrent: current,
    loadArtwork: source?.auth.apiKey?.trim().isNotEmpty != true
        ? null
        : () async {
            final profile = source!;
            if (!current()) return null;
            final blocked = await ref.read(
              blacklistTagsProvider(profile.filter).future,
            );
            final artworkId = int.tryParse(artwork.id);
            if (!current() || artworkId == null) return null;
            final client = ref.read(pixivClientProvider(profile.auth));
            final dto = await client.getIllustDetail(illustId: artworkId);
            if (!current() ||
                dto == null ||
                dto.id != artworkId ||
                (pageIndex == null && (dto.pageCount ?? 0) > 20)) {
              return null;
            }
            if (dto.visible == false || (dto.isMuted ?? false)) {
              throw const PixivOriginalAccessDenied();
            }
            final posts = illustDtoToPosts(dto, onlyPage: pageIndex);
            if (!current() || posts.isEmpty) return null;
            if (posts.any(
              (post) =>
                  !isExactLookupPostVisible(post, profile, blocked) ||
                  (pageIndex != null && post.isRestricted),
            )) {
              throw const PixivOriginalAccessDenied();
            }
            return dto;
          },
    hashOriginal: (uri, maxBytes, consume, cancellation) {
      if (source == null || !current()) {
        throw StateError('Pixiv source changed');
      }
      return ref
          .read(_mediaHasherProvider(source.auth.proxySettings))
          .hash(uri, maxBytes, consume, cancellation);
    },
  );
  ref.onDispose(() {
    disposed = true;
    resolver.dispose();
  });
  return resolver;
}
