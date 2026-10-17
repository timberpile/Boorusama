import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/zerochan.dart';
import 'package:boorusama/boorus/zerochan/downloads/file_url_extractor.dart';
import 'package:boorusama/boorus/zerochan/downloads/providers.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/download_activity/activity.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/widgets/reboot.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/boorusama_test_runtime.dart';
import '../application/support/fake_booru_backend.dart';
import '../application/support/headless_app_harness.dart';
import '../application/support/fake_image_dio.dart';
import '../application/support/app_flow_finders.dart';

// Transport responses are fixtures. Resolution, fallback, cache and download
// notification logic all use their actual production implementations.
class _NoOriginalAdapter implements HttpClientAdapter {
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    requests.add(uri);
    if (uri.path != '/101') {
      throw StateError('Unexpected request: $uri');
    }
    final isDetailJson = uri.query == 'json';
    return ResponseBody.fromString(
      isDetailJson
          ? jsonEncode({
              'id': 101,
              'large': 'https://static.zerochan.net/post.101.600.jpg',
              'medium': 'https://static.zerochan.net/post.101.240.jpg',
              'tags': ['cat'],
            })
          : '<html><head><title>Post 101</title></head><body> '
                '<img src="https://static.zerochan.net/post.101.600.jpg"> '
                '</body></html>',
      200,
      headers: {
        Headers.contentTypeHeader: [
          isDetailJson ? 'application/json' : 'text/html',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unresolvable explicit Zerochan Original produces a failed activity', () async {
    final backend = FakeBooruBackend();
    final service = MemoryDownloadService();
    final adapter = _NoOriginalAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://www.zerochan.net'))
      ..httpClientAdapter = adapter;
    final extractor = ZerochanDownloadFileUrlExtractor(
      client: ZerochanClient(dio: dio),
    );
    final runtime = backend.createRuntime(
      settings: Settings.defaultSettings.copyWith(
        downloadQuality: DownloadQuality.original,
        downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
      ),
      downloadService: service,
    );
    final initial = runtime.initialState;
    final container = ProviderContainer(
      overrides: [
        ...buildBoorusamaOverrides(
          runtime,
          RebootData(
            config: initial.initialConfig,
            configs: initial.configs,
            settings: initial.settings,
          ),
        ),
        downloadFileUrlExtractorProvider.overrideWith(
          (ref, config) => extractor,
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
    });
    final params = container.read(
      downloadNotifierParamsProvider((
        backend.config.auth,
        backend.config.download,
      )),
    );

    await container
        .read(downloadNotifierProvider(params).notifier)
        .download(
          TestPost(
            id: 101,
            tags: const {'cat'},
            thumbnailImageUrl: 'https://static.zerochan.net/post.101.240.jpg',
            // A guessed listing URL must not silently replace unresolved Original.
            originalImageUrl: 'https://static.zerochan.net/post.101.full.jpg',
          ),
          quality: 'original',
        );

    // Prove the actual detail API and HTML fallback both ran without an
    // original, and that no thumbnail/sample transfer was dispatched.
    expect(adapter.requests.map((uri) => uri.toString()), [
      'https://www.zerochan.net/101?json',
      'https://www.zerochan.net/101',
    ]);
    expect(service.requests, isEmpty);

    // This is the same retained activity channel consumed by the application
    // download status/toast scope. A silent early return must not lose failure.
    final failures = container
        .read(immediateDownloadActivitiesProvider)
        .where((activity) => activity.phase == DownloadActivityPhase.failed)
        .toList();
    expect(failures, isNotEmpty);
    expect(failures.single.error, isNotEmpty);
  });
  testWidgets(
    'unavailable Zerochan Original shows localized failure from the real toolbar',
    (tester) async {
      final backend = FakeBooruBackend();
      final service = MemoryDownloadService();
      final adapter = _NoOriginalAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://www.zerochan.net'))
        ..httpClientAdapter = adapter;
      final extractor = ZerochanDownloadFileUrlExtractor(
        client: ZerochanClient(dio: dio),
      );
      final harness = HeadlessAppHarness(
        booruBackend: backend,
        runtime: backend.createRuntime(
          settings: Settings.defaultSettings.copyWith(
            downloadQuality: DownloadQuality.preview,
            downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
          ),
          downloadService: service,
        ),
        additionalOverrides: [
          deterministicImageDioOverride(),
          deterministicFaviconDioOverride(),
          downloadFileUrlExtractorProvider.overrideWith(
            (ref, config) => extractor,
          ),
          downloadSourceProvider.overrideWith(
            (ref, config) => const ZerochanDownloadSource(),
          ),
        ],
      );
      try {
        await harness.pump(tester);
        await harness.openFirstPost(tester);
        await tester.tap(find.byType(KurumiInfoCircleIcon).first);
        await harness.pumpUntilFound(tester, find.byType(DownloadPostButton));
        await harness.settle(tester);
        final button = find.byType(DownloadPostButton).last;
        await tester.ensureVisible(button);
        final control = find
            .descendant(
              of: button,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is material_ui.IconButton &&
                    widget.onLongPress != null,
              ),
            )
            .first;
        tester.widget<material_ui.IconButton>(control).onLongPress!.call();
        await harness.pumpUntilFound(tester, find.byType(KurumiPopupMenuItem));
        await harness.settle(tester);
        await tester.tap(find.byType(KurumiPopupMenuItem).last);
        await harness.pumpUntil(tester, () => adapter.requests.length == 2);
        await harness.pumpUntilFound(
          tester,
          find.text(appStrings(tester).post.action.share_media_unavailable),
        );
        expect(service.requests, isEmpty);
        expect(adapter.requests.map((uri) => uri.query), ['json', '']);
      } finally {
        dismissAllToast();
        await harness.teardown(tester);
        // OKToast schedules animation callbacks that outlive its disposed widget.
        await tester.pump(const Duration(seconds: 5));
        dio.close(force: true);
      }
    },
  );
}
