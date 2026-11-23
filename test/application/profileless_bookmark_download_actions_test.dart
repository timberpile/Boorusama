import 'dart:typed_data';

import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_media_dio.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/themes/theme/widgets.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:boorusama/foundation/permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:selection_mode/selection_mode.dart';

import '../core/posts/details/progressive_image_test_utils.dart' as image;
import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

const _group = '10000000-0000-4000-8000-000000000001';

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: []);
}

class _Bookmarks extends BookmarkLibraryNotifier {
  _Bookmarks(this.library);
  final BookmarkLibraryState library;
  @override
  BookmarkLibraryState build() => library;
}

class _Permission extends DeviceStoragePermissionNotifier {
  _Permission(this.onRead);
  final void Function() onRead;
  @override
  Future<DeviceStoragePermissionState> build() async {
    onRead();
    return const DeviceStoragePermissionState(
      storagePermission: PermissionStatus.granted,
      isNotificationRead: true,
    );
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options.uri.toString());
    return ResponseBody.fromBytes(image.targetPng, 200);
  }
}

void main() {
  testWidgets('public Bookmark context menu and selection cannot download', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final downloads = MemoryDownloadService();
    final adapter = _Adapter();
    var permissionReads = 0;
    var extractorReads = 0;
    var bypassReads = 0;
    final saved = <PostBookmark>[];
    for (final id in [101, 102]) {
      final legacy = PostBookmark(
        id: id,
        booruId: BooruType.danbooru.id,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        thumbnailUrl: 'https://cdn.donmai.us/sample/$id.jpg',
        sampleUrl: '',
        originalUrl: 'https://foreign.invalid/original/$id.jpg',
        sourceUrl: 'https://danbooru.donmai.us/posts/$id',
        width: 100,
        height: 100,
        md5: '',
        tags: const {'cat'},
        realSourceUrl: null,
        format: 'jpg',
        imageUrlResolver: const DefaultImageUrlResolver(),
        postId: id,
        metadata: const {},
      );
      final post = legacy.post.copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: BooruType.danbooru.id,
          source: 'https://danbooru.donmai.us',
        ),
      );
      saved.add(
        legacy.copyWith(
          post: post,
          snapshot: const StoredPostCodec().encode(post),
        ),
      );
    }
    final library = BookmarkLibraryState(
      bookmarks: saved,
      groups: [
        BookmarkGroup(id: _group, name: 'Saved', bookmarkIds: {101, 102}),
      ],
    );
    final runtime = backend.createRuntime(downloadService: downloads);
    final overrides = [
      bookmarkProvider.overrideWith(() => _Bookmarks(library)),
      booruConfigProvider.overrideWith(_Profiles.new),
      postGridLongPressOpensMenuProvider.overrideWithValue(true),
      deviceStoragePermissionProvider.overrideWith(
        () => _Permission(() => permissionReads++),
      ),
      downloadFileUrlExtractorProvider.overrideWith((_, _) {
        extractorReads++;
        throw StateError('unexpected extractor');
      }),
      bypassDdosHeadersProvider.overrideWith((_, _) {
        bypassReads++;
        return Future.value(<String, String>{});
      }),
      contentMediaDioProvider.overrideWith(
        (_, _) => Dio()..httpClientAdapter = adapter,
      ),
    ];
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      runtime: runtime,
      additionalOverrides: overrides,
      viewportSize: const Size(390, 844),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      BoorusamaAppScope(
        runtime: runtime,
        additionalOverrides: overrides,
        child: MediaQuery.fromView(
          view: tester.view,
          child: ThemeBuilder(
            useProfileAppearance: false,
            builder: (theme, _) => MaterialApp(
              theme: theme,
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
              home: const BookmarkGroupBrowserPage(groupId: _group),
            ),
          ),
        ),
      ),
    );
    await harness.pumpUntilFound(tester, postTile(101));
    await harness.pumpUntilFound(tester, postTile(102));
    expect(
      saved.first.post.thumbnailImageUrl,
      'https://cdn.donmai.us/sample/101.jpg',
    );
    expect(
      saved.first.post.originalImageUrl,
      'https://foreign.invalid/original/101.jpg',
    );
    await tester.longPress(postTile(101));
    await harness.settle(tester);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    await tester.tap(find.text('Select'));
    await harness.settle(tester);
    final selection = SelectionMode.of(tester.element(postTile(101)));
    expect(selection.isActive, isTrue);
    expect(selection.selection, hasLength(1));
    expect(find.widgetWithText(MultiSelectButton, 'Download'), findsNothing);
    await tester.tap(postTile(102));
    await harness.settle(tester);
    expect(selection.selection, hasLength(2));
    expect(find.widgetWithText(MultiSelectButton, 'Download'), findsNothing);
    expect(permissionReads, 0);
    expect(extractorReads, 0);
    expect(bypassReads, 0);
    expect(downloads.requests, isEmpty);
    expect(
      adapter.requests.every((url) => !url.contains('foreign.invalid')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
