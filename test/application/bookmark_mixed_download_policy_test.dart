import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
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

typedef _StoredDownload = ({
  BooruConfigAuth auth,
  BooruConfigDownload download,
  List<Bookmark> bookmarks,
});

class _RecordingBookmarks extends BookmarkLibraryNotifier {
  _RecordingBookmarks(this.library, this.calls);
  final BookmarkLibraryState library;
  final List<_StoredDownload> calls;

  @override
  Future<BookmarkLibraryState> build() async => library;

  @override
  Future<void> downloadBookmarks(
    BooruConfigAuth auth,
    BooruConfigDownload download,
    List<Bookmark> bookmarks,
  ) async {
    calls.add((auth: auth, download: download, bookmarks: List.of(bookmarks)));
  }
}

void main() {
  for (final orphan in [true, false]) {
    testWidgets(
      'supported sources retain normal policy with ${orphan ? 'an orphan' : 'an unsupported bulk group'}',
      (tester) async {
        final backend = FakeBooruBackend();
        final downloads = MemoryDownloadService();
        final fallbackCalls = <_StoredDownload>[];
        Post post(BooruConfig config, int id, {String? source}) =>
            TestPost(
              id: id,
              origin: PostOrigin.fromSource(
                booruType: config.auth.booruType,
                booruId: config.booruId,
                source: source ?? config.url,
                profileIdHint: source == null ? config.id : null,
              ),
            ).copyWith(
              booruData: const LegacyPostData(
                typeKey: 'legacy_fixture',
                custom: {},
              ),
            );
        final selected = <Post>[
          post(backend.config, 42),
          post(
            backend.configB,
            42,
            source: orphan ? 'https://orphan.test/' : null,
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
                snapshot: const StoredPostCodec().encode(post),
                post: post,
                postId: post.id,
              ),
          ],
          groups: const [],
          activeTarget: const BookmarkTarget.defaultGroup(),
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
              () => _RecordingBookmarks(library, fallbackCalls),
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
        await harness.pumpUntil(tester, () => fallbackCalls.isNotEmpty);

        expect(downloads.requests.map((request) => request.url), [
          'https://headless.booru.test/posts/42.jpg',
        ]);
        expect(fallbackCalls, hasLength(1));
        expect(
          fallbackCalls.single.bookmarks.map((bookmark) => bookmark.post),
          selected.skip(1),
        );
        if (!orphan) {
          expect(fallbackCalls.single.auth, backend.configB.auth);
          expect(fallbackCalls.single.download, backend.configB.download);
        }
        expect(
          container.read(currentReadOnlyBooruConfigProvider).id,
          backend.config.id,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
