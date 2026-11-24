import 'package:boorusama/core/backups/export_import/import/import_change_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'query replacement reports removed and added queries, without index noise',
    () {
      final details = importQueryChanges(['cat', 'sky'], ['dog', 'sky']);
      expect(details.map((d) => d.kind), [
        ImportChangeKind.removed,
        ImportChangeKind.added,
      ]);
      expect(details.first.before, 'cat');
      expect(details.last.after, 'dog');
      expect(
        details.every((d) => d.presentation == ImportDetailPresentation.query),
        isTrue,
      );
    },
  );
  test(
    'query insertion does not report shifted existing queries as changes',
    () {
      final details = importQueryChanges(['cat', 'sky'], ['dog', 'cat', 'sky']);
      expect(details.single.after, 'dog');
      expect(details.single.kind, ImportChangeKind.added);
    },
  );
  test('query order changes remain visible alongside membership changes', () {
    final details = importQueryChanges(['cat', 'sky'], ['sky', 'dog', 'cat']);
    expect(details.last.presentation, ImportDetailPresentation.queryOrder);
    expect(details.last.before, 'cat\nsky');
    expect(details.last.after, 'sky\ncat');
  });
  test('populated query lists preserve unchanged and reversed order', () {
    final queries = [
      for (var index = 0; index < 20000; index++) 'query_$index',
    ];
    expect(importQueryChanges(queries, List.of(queries)), isEmpty);
    final reversed = queries.reversed.toList();
    final detail = importQueryChanges(queries, reversed).single;
    expect(detail.presentation, ImportDetailPresentation.queryOrder);
    expect(detail.before, queries.join('\n'));
    expect(detail.after, reversed.join('\n'));
  });

  for (final added in [false, true]) {
    test(
      'duplicate ${added ? 'addition' : 'removal'} retains existing occurrence ordering',
      () {
        final shorter = ['cat', 'sky'];
        final longer = ['cat', 'sky', 'cat'];
        final details = importQueryChanges(
          added ? shorter : longer,
          added ? longer : shorter,
        );
        expect(details, hasLength(2));
        expect(
          details.first.kind,
          added ? ImportChangeKind.added : ImportChangeKind.removed,
        );
        expect(added ? details.first.after : details.first.before, 'cat');
        expect(details.last.presentation, ImportDetailPresentation.queryOrder);
        expect(details.last.before, added ? 'cat\nsky' : 'sky\ncat');
        expect(details.last.after, added ? 'sky\ncat' : 'cat\nsky');
      },
    );
  }

  test('duplicate multiplicity preserves surplus and retained query order', () {
    final details = importQueryChanges(
      ['a', 'b', 'a', 'c', 'b'],
      ['b', 'a', 'b', 'd', 'a', 'a'],
    );
    expect(details.map((detail) => detail.kind), [
      ImportChangeKind.removed,
      ImportChangeKind.added,
      ImportChangeKind.added,
      ImportChangeKind.changed,
    ]);
    expect(details.first.before, 'c');
    expect(details[1].after, 'd');
    expect(details[2].after, 'a');
    expect(details.last.presentation, ImportDetailPresentation.queryOrder);
    expect(details.last.before, 'a\nb\na\nb');
    expect(details.last.after, 'b\nb\na\na');
  });

  test('duplicate queries and credentials retain accurate safe details', () {
    final details = importQueryChanges(
      ['cat', 'cat'],
      ['cat', 'https://example.invalid/?token=private-token'],
    );
    expect(details.first.before, 'cat');
    expect(details.last.after, isNot(contains('private-token')));
    expect(details, hasLength(2));
  });
}
