import 'package:boorusama/boorus/gelbooru/gelbooru.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/configs/config/types.dart';
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

class _Saved extends BookmarkLibraryNotifier {
  _Saved(this.library);
  final BookmarkLibraryState library;
  @override
  Future<BookmarkLibraryState> build() async => library;
}

void main() {
  testWidgets(
    'live selected media is not replaced by an older bookmark snapshot',
    (tester) async {
      final backend = FakeBooruBackend(
        additionalBoorus: {BooruType.gelbooru: createGelbooru().parser.parse()},
      )..registry.register(BooruType.gelbooru, createGelbooru());
      final config = BooruConfig.defaultConfig(
        booruType: BooruType.gelbooru,
        url: 'https://gelbooru.com',
        customDownloadFileNameFormat: null,
      );
      final downloads = MemoryDownloadService();
      Post post(String url) => TestPost(
        id: 500,
        format: 'png',
        md5: 'abc',
        originalImageUrl: url,
        origin: PostOrigin.fromSource(
          booruType: BooruType.gelbooru,
          booruId: config.booruId,
          source: config.url,
          profileIdHint: config.id,
        ),
        booruData: const EmptyPostData(typeKey: 'gelbooru'),
      );
      final old = post('https://gelbooru.com/old.png');
      final current = post('https://gelbooru.com/current.png');
      final stored = Bookmark.fromSnapshot(
        id: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        postId: old.id,
        post: old,
        snapshot: const StoredPostCodec().encode(
          old,
          dataCodec: const EmptyPostDataCodec('gelbooru'),
        ),
      );
      final library = BookmarkLibraryState(
        bookmarks: [stored],
        groups: const [],
      );
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(
          configs: [backend.config, config],
          downloadService: downloads,
        ),
        additionalOverrides: [
          bookmarkProvider.overrideWith(() => _Saved(library)),
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
              body: TextButton(
                onPressed: postActionDefinitions(
                  context,
                  ref,
                  PostActionSnapshot([current], [backend.config, config]),
                ).firstWhere((a) => a.id == PostActionId.download).execute,
                child: const Text('Download current'),
              ),
            ),
          ),
        ),
      );
      await harness.settle(tester);
      await tester.tap(find.text('Download current'));
      await harness.pumpUntil(tester, () => downloads.requests.isNotEmpty);
      expect(
        (await container.read(bookmarkProvider.future))
            .items
            .single
            .post
            .originalImageUrl,
        old.originalImageUrl,
      );
      expect(downloads.requests.single.url, current.originalImageUrl);
    },
  );
}
