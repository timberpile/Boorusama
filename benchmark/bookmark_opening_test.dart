// Host attribution probe. Run serially; timings are not Android frame evidence.
// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

void main() {
  test('nine no-search All entries with 9,000 generated rows', () async {
    final library = BookmarkLibraryState(
      bookmarks: [
        for (var id = 1; id <= 9000; id++)
          Bookmark.empty.copyWith(
            id: id,
            sourceUrl: 'https://example.test',
            tags: {for (var tag = 0; tag < 60; tag++) 'tag_${id % 900}_$tag'},
          ),
      ],
      groups: const [],
    );
    for (var run = 0; run < 3; run++) {
      final container = ProviderContainer(
        overrides: [
          bookmarkProvider.overrideWith(() => _Library(library)),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
        ],
      );
      final samples = <int>[];
      performanceRecorder.start();
      try {
        for (var visit = 0; visit < 9; visit++) {
          final watch = Stopwatch()..start();
          final provider = bookmarkTagIndexProvider(const BookmarkView.all());
          final subscription = container.listen(provider, (_, _) {});
          final index = await container.read(provider.future);
          watch.stop();
          expect(index.entries, hasLength(54000));
          samples.add(watch.elapsedMicroseconds);
          subscription.close();
          await container.pump();
        }
        performanceRecorder.stop();
        // Fixed, aggregate vocabulary only; generated tags are never exported.
        print(
          jsonEncode({
            'run': run,
            'entry_us': samples,
            'summary': performanceRecorder.snapshot()['summary'],
          }),
        );
      } finally {
        container.dispose();
        performanceRecorder.clear();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.library);
  final BookmarkLibraryState library;
  @override
  Future<BookmarkLibraryState> build() async => library;
}
