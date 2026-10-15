import 'dart:async';

import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_search_token.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_tag_index.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (draft, expected) in [
    ('one piece', 'one_piece '),
    ('-ONE PIECE', '-one_piece '),
    ('blue_hair one pi', 'blue_hair one_piece '),
    ('blue_hair\t-one   piece', 'blue_hair -one_piece '),
  ]) {
    test('replaces the longest matching phrase in $draft', () {
      expect(insertBookmarkTagSuggestion(draft, 'one_piece'), expected);
    });
  }

  test(
    'late index completion keeps typed and empty-state suggestions isolated',
    () async {
      final pending = Completer<BookmarkTagIndex>();
      final container = ProviderContainer(
        overrides: [
          bookmarkTagIndexProvider.overrideWith((ref, view) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      const view = BookmarkView.all();
      final oldQuery = bookmarkTagSuggestionsProvider((view, 'one piece', ''));
      final newQuery = bookmarkTagSuggestionsProvider((view, '-blue', ''));
      final cleared = bookmarkTagSuggestionsProvider((view, '', ''));
      final subscriptions = [
        container.listen(oldQuery, (_, _) {}),
        container.listen(newQuery, (_, _) {}),
        container.listen(cleared, (_, _) {}),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });
      expect(container.read(cleared).isLoading, isTrue);
      pending.complete(
        BookmarkTagIndex([
          BookmarkTagEntry(tag: 'one_piece', count: 2, sources: const {}),
          BookmarkTagEntry(tag: 'blue_hair', count: 1, sources: const {}),
        ]),
      );
      await container.read(bookmarkTagIndexProvider(view).future);
      await container.pump();
      expect(container.read(newQuery).requireValue.single.tag, 'blue_hair');
      expect(container.read(oldQuery).requireValue.single.tag, 'one_piece');
      expect(
        container.read(cleared).requireValue.map((entry) => entry.tag),
        ['one_piece', 'blue_hair'],
      );
    },
  );

  test(
    'keeps suggestions isolated between bookmark views and selected queries',
    () async {
      final container = ProviderContainer(
        overrides: [
          bookmarkTagIndexProvider.overrideWith(
            (ref, view) => BookmarkTagIndex([
              BookmarkTagEntry(
                tag: view.kind == BookmarkViewKind.all
                    ? 'one_piece'
                    : 'one_punch_man',
                count: 1,
                sources: const {},
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      const all = BookmarkView.all();
      const group = BookmarkView.defaultGroup();
      final allQuery = bookmarkTagSuggestionsProvider((all, 'one', ''));
      final groupQuery = bookmarkTagSuggestionsProvider((group, 'one', ''));
      final subscriptions = [
        container.listen(allQuery, (_, _) {}),
        container.listen(groupQuery, (_, _) {}),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });
      await container.read(bookmarkTagIndexProvider(all).future);
      await container.read(bookmarkTagIndexProvider(group).future);
      await container.pump();
      expect(container.read(allQuery).requireValue.single.tag, 'one_piece');
      expect(
        container.read(groupQuery).requireValue.single.tag,
        'one_punch_man',
      );
      expect(
        container
            .read(bookmarkTagSuggestionsProvider((all, 'one', 'one_piece')))
            .requireValue,
        isEmpty,
      );
      expect(
        container
            .read(bookmarkTagSuggestionsProvider((group, '', '')))
            .requireValue
            .single
            .tag,
        'one_punch_man',
      );
      expect(
        container
            .read(bookmarkTagSuggestionsProvider((all, '', 'one_piece')))
            .requireValue,
        isEmpty,
      );
    },
  );
}
