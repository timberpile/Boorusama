// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../developer_options/blocked_media_placeholder.dart';
import '../developer_options/providers.dart';
import '../images/providers.dart';
import '../posts/sources/types.dart';
import '../content/content_media_access.dart';
import '../content/content_access_provider.dart';

const _unknownSize = 26.0;
const kFaviconSize = 32.0;

double? _calcFailedIconSize(
  double size, {
  double defaultSize = _unknownSize,
  double referenceSize = kFaviconSize,
}) {
  final ratio = defaultSize / referenceSize;

  return size * ratio;
}

class WebsiteLogo extends ConsumerWidget {
  const WebsiteLogo({
    required this.url,
    required this.dio,
    super.key,
    this.size = kFaviconSize,
    this.cacheManager,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double size;
  final Dio dio;
  final ImageCacheManager? cacheManager;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = this.url;
    final required = ref.watch(contentAccessRequiredProvider);
    final key = ref.watch(currentContentAccessKeyProvider);
    final access = key == null
        ? null
        : ref.watch(contentAccessContextProvider(key));
    final publicScope = access?.config?.anonymousReadScope;
    final trustedPublicIcon =
        publicScope != null &&
        publicScope.isCurrent &&
        (PostSource.from(publicScope.source.site.toString()).whenWeb(
              (source) => source.faviconUrl == url,
              () => false,
            ) ||
            _usesFaviconService(url));
    // Source links can use the standard favicon service. Arbitrary icon URLs
    // from an imported bookmark do not grant a new network destination.
    if (required &&
        (access == null || (key?.profileId == null && !trustedPublicIcon))) {
      return SizedBox.square(dimension: size, child: _buildFallback());
    }
    final fallbackManager = ref.watch(defaultImageCacheManagerProvider);
    final delegate = cacheManager ?? fallbackManager;
    final scopedCache = key == null || access == null
        ? delegate
        : ref.watch(
            contentMediaCacheManagerProvider((manager: delegate, access: key)),
          );
    final automaticMediaLoadingEnabled = ref.watch(
      automaticMediaLoadingEnabledProvider,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: size,
        maxHeight: size,
        minWidth: size,
        minHeight: size,
      ),
      child: switch ((url, automaticMediaLoadingEnabled)) {
        (final url?, true) => ExtendedImage.network(
          url,
          dio: dio,
          clearMemoryCacheIfFailed: false,
          fit: fit,
          fetchStrategy: const FetchStrategyBuilder(
            maxAttempts: 1,
            timeout: Duration(seconds: 5),
            initialPauseBetweenRetries: Duration(milliseconds: 100),
            silent: true,
          ),
          placeholderWidget: Container(
            padding: const EdgeInsets.all(8),
            child: const CircularProgressIndicator(
              strokeWidth: 1.5,
            ),
          ),
          cacheManager: scopedCache,
          errorWidget: _buildFallback(),
        ),
        (final String _, false) => BlockedMediaPlaceholder(
          width: size,
          height: size,
        ),
        _ => _buildFallback(),
      },
    );
  }

  bool _usesFaviconService(String? url) {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null ||
        uri.host != 'www.google.com' ||
        uri.path != '/s2/favicons') {
      return false;
    }
    final domain = uri.queryParameters['domain'];
    return domain != null && isWebSource(domain) && getFavicon(domain) == url;
  }

  Widget _buildFallback() {
    return Card(
      child: FaIcon(
        FontAwesomeIcons.globe,
        size: _calcFailedIconSize(size),
        color: Colors.blue,
      ),
    );
  }
}
