// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booru_clients/generated.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_builder.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/foundation/loggers.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    'opening a Realbooru listing post replaces its thumbnail data with the fetched original',
    (tester) async {
      final fetched = Completer<Post?>();
      var fetches = 0;
      final unresolved = _post(
        originalUrl: _thumbnailUrl,
        metadata: const PostMetadata(page: 1, search: 'portrait', limit: 42),
      );
      final resolved = _post(originalUrl: _originalUrl, thumbnailUrl: '');

      await tester.pumpWidget(
        _Harness(
          post: unresolved,
          onFetch: () {
            fetches++;
            return fetched.future;
          },
        ),
      );
      await tester.pump();

      expect(_visiblePost(tester).originalImageUrl, _thumbnailUrl);
      expect(fetches, 1);

      fetched.complete(resolved);
      await tester.pumpAndSettle();

      expect(_visiblePost(tester).originalImageUrl, _originalUrl);
      expect(_visiblePost(tester).thumbnailImageUrl, _thumbnailUrl);
      expect(fetches, 1);
    },
  );

  testWidgets('an already resolved Realbooru post is not fetched again', (
    tester,
  ) async {
    var fetches = 0;

    await tester.pumpWidget(
      _Harness(
        post: _post(originalUrl: _originalUrl),
        onFetch: () async {
          fetches++;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_visiblePost(tester).originalImageUrl, _originalUrl);
    expect(fetches, 0);
  });

  testWidgets('a failed Realbooru detail fetch keeps the listing thumbnail', (
    tester,
  ) async {
    var fetches = 0;

    await tester.pumpWidget(
      _Harness(
        post: _post(
          originalUrl: _thumbnailUrl,
          metadata: const PostMetadata(
            page: 1,
            search: 'portrait',
            limit: 42,
          ),
        ),
        onFetch: () {
          fetches++;
          return Future<Post?>.error(Exception('unreachable'));
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_visiblePost(tester).originalImageUrl, _thumbnailUrl);
    expect(fetches, 1);
    expect(tester.takeException(), isNull);
  });
}

Post _visiblePost(WidgetTester tester) =>
    tester.widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>)).first.post;

const _thumbnailUrl =
    'https://realbooru.test/thumbnails/ab/cd/'
    'thumbnail_0123456789abcdef0123456789abcdef.jpg';
const _originalUrl =
    'https://realbooru.test/images/ab/cd/'
    '0123456789abcdef0123456789abcdef.jpeg';

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.gelbooruV2,
  url: 'https://realbooru.com/',
  customDownloadFileNameFormat: null,
);

Post _post({
  required String originalUrl,
  String thumbnailUrl = _thumbnailUrl,
  PostMetadata? metadata,
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: BooruType.gelbooruV2.id,
    source: _config.url,
  ),
  core: PostCoreData(
    id: 42,
    thumbnailImageUrl: thumbnailUrl,
    sampleImageUrl: originalUrl,
    originalImageUrl: originalUrl,
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 0,
    height: 0,
    format: 'jpeg',
    md5: '0123456789abcdef0123456789abcdef',
    fileSize: 0,
    duration: 0,
    tags: const {'portrait'},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    metadata: metadata,
  ),
  booruData: const GelbooruV2PostData(hasNotes: false),
);

class _Harness extends StatelessWidget {
  const _Harness({required this.post, required this.onFetch});

  final Post post;
  final Future<Post?> Function() onFetch;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      settingsProvider.overrideWithValue(
        Settings.defaultSettings.copyWith(reduceAnimations: true),
      ),
      colorSchemeProvider.overrideWithValue(
        ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialSettingsBooruConfigProvider.overrideWithValue(_config),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [_config]),
      ),
      gelbooruV2Provider.overrideWithValue(
        GelbooruV2(
          config: BooruYamlConfigs.gelbooruV2,
          globalUserParams:
              BooruYamlConfigs.gelbooruV2.globalUserParams ?? const {},
        ),
      ),
      booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
      booruPostPresentationProvider.overrideWith(
        (ref, request) => GelbooruV2Builder().postPresentation,
      ),
      booruLoginDetailsProvider.overrideWith(
        (ref, config) => DefaultBooruLoginDetails(
          login: config.login,
          apiKey: config.apiKey,
          url: config.url,
        ),
      ),
      gelbooruV2PostProvider.overrideWith((ref, params) => onFetch()),
      mediaUrlResolverProvider.overrideWith(
        (ref, config) => const _MediaResolver(),
      ),
      booruRepoProvider.overrideWith((ref, config) => null),
      booruBuilderProvider.overrideWith((ref, config) => null),
      automaticMediaLoadingEnabledProvider.overrideWithValue(false),
      hasPremiumLayoutProvider.overrideWithValue(false),
      showPremiumFeatsProvider.overrideWithValue(false),
      downloadServiceProvider.overrideWithValue(_DownloadService()),
      httpHeadersProvider.overrideWith((ref, config) => const {}),
      loggerProvider.overrideWithValue(const _Logger()),
      favoriteRepoProvider.overrideWith(
        (ref, config) => EmptyFavoriteRepository(),
      ),
      canFavoriteProvider.overrideWith((ref, config) => false),
    ],
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: MixedPostDetailsPage(
          posts: [post],
          initialIndex: 0,
          initialThumbnailUrl: _thumbnailUrl,
          scrollController: null,
          disclaimer: null,
        ),
      ),
    ),
  );
}

final class _MediaResolver implements MediaUrlResolver {
  const _MediaResolver();

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      post.originalImageUrl;

  @override
  double? resolveMediaAspectRatio(Post post, BooruConfigViewer config) => 1;

  @override
  String resolveVideoUrl(Post post, BooruConfigViewer config) => post.videoUrl;

  @override
  double? resolveVideoAspectRatio(Post post, BooruConfigViewer config) => 1;
}

final class _DownloadService implements DownloadService {
  @override
  Future<DownloadResult> download(DownloadOptions options) async =>
      DownloadEnqueued(DownloadTaskInfo(path: '', id: options.url));

  @override
  Future<bool> cancelAll(String group) async => true;

  @override
  Future<void> pauseAll(String group) async {}

  @override
  Future<void> resumeAll(String group) async {}
}

final class _Logger implements Logger {
  const _Logger();

  @override
  String getDebugName() => 'Realbooru full post loader test';

  @override
  void debug(String serviceName, String message) {}

  @override
  void error(String serviceName, String message) {}

  @override
  void info(String serviceName, String message) {}

  @override
  void verbose(String serviceName, String message) {}

  @override
  void warn(String serviceName, String message) {}
}
