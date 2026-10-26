import 'package:oktoast/oktoast.dart';
import 'package:boorusama/boorus/pixiv/pixiv.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/posts/listing/src/types/post_action_snapshot.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_actions.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

class _SavedBookmarks extends BookmarkLibraryNotifier {
  _SavedBookmarks(this.library);
  final BookmarkLibraryState library;

  @override
  Future<BookmarkLibraryState> build() async => library;
}

void main() {
  testWidgets(
    'resolved legacy Pixiv action uses distinct safe snapshot names',
    (tester) async {
      final backend = FakeBooruBackend(
        additionalBoorus: {
          BooruType.pixiv: createPixiv().parser.parse(),
        },
      )..registry.register(BooruType.pixiv, createPixiv());
      final config = BooruConfig.defaultConfig(
        booruType: BooruType.pixiv,
        url: 'https://www.pixiv.net',
        customDownloadFileNameFormat: null,
      );
      final downloads = MemoryDownloadService();
      final posts = [
        for (final id in [101, 202])
          TestPost(
            id: id,
            format: 'png',
            originalImageUrl: 'https://i.pximg.net/$id.png',
            origin: PostOrigin.fromSource(
              booruType: BooruType.pixiv,
              booruId: config.booruId,
              source: config.url,
              profileIdHint: config.id,
            ),
            booruData: const LegacyPostData(
              typeKey: 'legacy_pixiv',
              custom: {},
            ),
          ),
      ];
      final library = BookmarkLibraryState(
        bookmarks: [
          for (final post in posts)
            Bookmark.fromSnapshot(
              id: post.id,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              postId: post.id,
              post: post,
              snapshot: const StoredPostCodec().encode(
                post,
                dataCodec: const EmptyPostDataCodec('test'),
              ),
            ),
        ],
        groups: const [],
      );
      expect(library.bookmarkForPost(posts.first), isNull);
      expect(
        library.storedBookmarkForPost(posts.first),
        same(library.items.first),
      );
      expect(library.storedBookmarkForPost(posts.first.copyWith()), isNull);
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(
          configs: [backend.config, config],
          downloadService: downloads,
        ),
        additionalOverrides: [
          bookmarkProvider.overrideWith(() => _SavedBookmarks(library)),
          bypassDdosHeadersProvider.overrideWith(
            (_, _) => Future.value(<String, String>{}),
          ),
        ],
      );
      await harness.pumpUntilFound(tester, postTile(101));
      final context = tester.element(postTile(101));
      final container = ProviderScope.containerOf(context, listen: false);
      await container.read(bookmarkProvider.future);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Column(
                children: [
                  for (final post in posts)
                    TextButton(
                      onPressed:
                          postActionDefinitions(
                                context,
                                ref,
                                PostActionSnapshot(
                                  [post],
                                  [backend.config, config],
                                ),
                              )
                              .firstWhere((a) => a.id == PostActionId.download)
                              .execute,
                      child: Text('Download ${post.id}'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await harness.settle(tester);
      for (final post in posts) {
        await tester.tap(find.text('Download ${post.id}'));
        await harness.pumpUntil(
          tester,
          () => downloads.requests.length == posts.indexOf(post) + 1,
        );
      }
      expect(
        downloads.requests.map((r) => r.url),
        posts.map((p) => p.originalImageUrl),
      );
      expect(downloads.requests.map((r) => r.filename).toSet(), hasLength(2));
      expect(
        downloads.requests.every(
          (r) => r.headers?['Referer'] == 'https://www.pixiv.net/',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final orphan in [true, false]) {
    testWidgets(
      'supported sources retain normal policy with ${orphan ? 'an orphan' : 'an unsupported bulk group'}',
      (tester) async {
        final backend = FakeBooruBackend();
        final downloads = MemoryDownloadService();
        Post post(BooruConfig config, int id, {String? source}) =>
            TestPost(
              id: id,
              originalImageUrl: '${source ?? config.url}/stored/$id.png',
              origin: PostOrigin.fromSource(
                booruType: config.auth.booruType,
                booruId: config.booruId,
                source: source ?? config.url,
                profileIdHint: source == null ? config.id : null,
              ),
            ).copyWith(
              booruData: source == null && config.id == backend.config.id
                  ? const EmptyPostData(typeKey: 'test')
                  : const LegacyPostData(typeKey: 'legacy_fixture', custom: {}),
            );
        final selected = <Post>[
          post(backend.config, 42),
          post(
            backend.configB,
            42,
            source: orphan ? 'https://orphan.test' : null,
          ),
          if (!orphan) post(backend.configB, 43),
        ];
        final library = BookmarkLibraryState(
          bookmarks: [
            for (final (index, post) in selected.indexed)
              Bookmark.fromSnapshot(
                id: index + 1,
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
                snapshot: const StoredPostCodec().encode(
                  post,
                  dataCodec: const EmptyPostDataCodec('test'),
                ),
                post: post,
                postId: post.id,
              ),
          ],
          groups: const [],
        );
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          runtime: backend.createRuntime(
            configs: [backend.config, backend.configB],
            downloadService: downloads,
          ),
          additionalOverrides: [
            bookmarkProvider.overrideWith(
              () => _SavedBookmarks(library),
            ),
            if (!orphan)
              downloadMultipleFileCheckProvider.overrideWith(
                (ref, auth) =>
                    () => false,
              ),
          ],
        );
        await harness.pumpUntilFound(tester, postTile(101));
        final context = tester.element(postTile(101));
        final container = ProviderScope.containerOf(context, listen: false);
        await container.read(bookmarkProvider.future);
        final snapshot = PostActionSnapshot(selected, [
          backend.config,
          backend.configB,
        ]);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Consumer(
              builder: (context, ref, _) {
                final action = postActionDefinitions(
                  context,
                  ref,
                  snapshot,
                ).firstWhere((action) => action.id == PostActionId.download);
                return Scaffold(
                  body: TextButton(
                    onPressed: action.execute,
                    child: Text(action.label),
                  ),
                );
              },
            ),
          ),
        );
        await harness.settle(tester);
        await tester.tap(find.text('Download'));
        await harness.pumpUntil(
          tester,
          () => downloads.requests.length == (orphan ? 2 : 1),
        );

        expect(downloads.requests.map((request) => request.url), [
          'https://headless.booru.test/posts/42.jpg',
          if (orphan) 'https://orphan.test/stored/42.png',
        ]);
        expect(
          container.read(currentReadOnlyBooruConfigProvider).id,
          backend.config.id,
        );
        if (!orphan) {
          await harness.settle(tester);
          expect(
            find.text('This booru does not support downloading multiple files'),
            findsOneWidget,
          );
          dismissAllToast();
          // Advance the controlled clock through the toast's 3-second lifecycle,
          // including its internal animation futures after explicit dismissal.
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
