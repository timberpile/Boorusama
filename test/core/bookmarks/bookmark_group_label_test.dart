// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_label.dart';

void main() {
  test('duplicate group names include a short identity suffix', () {
    final labels = bookmarkGroupLabels([
      BookmarkGroup(
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Shared',
        bookmarkIds: const {},
      ),
      BookmarkGroup(
        id: '5f1d7f5e-3114-4dc7-a347-18f95852fc31',
        name: 'Shared',
        bookmarkIds: const {},
      ),
      BookmarkGroup(
        id: '70f55ff0-f00f-457a-88b0-f9232a68e733',
        name: 'Unique',
        bookmarkIds: const {},
      ),
    ]);

    expect(labels['550e8400-e29b-41d4-a716-446655440000'], 'Shared · 550e8400');
    expect(labels['5f1d7f5e-3114-4dc7-a347-18f95852fc31'], 'Shared · 5f1d7f5e');
    expect(
      labels['70f55ff0-f00f-457a-88b0-f9232a68e733'],
      'Unique · 70f55ff0',
    );
  });

  test('identity suffixes expand until duplicate labels are unique', () {
    final labels = bookmarkGroupLabels([
      BookmarkGroup(
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Shared',
        bookmarkIds: const {},
      ),
      BookmarkGroup(
        id: '550e8400-1111-4111-8111-111111111111',
        name: 'Shared',
        bookmarkIds: const {},
      ),
    ]);

    expect(
      labels['550e8400-e29b-41d4-a716-446655440000'],
      'Shared · 550e8400-e',
    );
    expect(
      labels['550e8400-1111-4111-8111-111111111111'],
      'Shared · 550e8400-1',
    );
  });

  test('conflict labels include the complete group identity', () {
    expect(
      bookmarkGroupConflictLabel(
        'Shared',
        '550e8400-e29b-41d4-a716-446655440000',
      ),
      'Shared · 550e8400-e29b-41d4-a716-446655440000',
    );
  });

  test('unique group names still expose their identity', () {
    final labels = bookmarkGroupLabels([
      BookmarkGroup(
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'No Group',
        bookmarkIds: const {},
      ),
    ]);

    expect(
      labels['550e8400-e29b-41d4-a716-446655440000'],
      'No Group · 550e8400',
    );
  });
}
