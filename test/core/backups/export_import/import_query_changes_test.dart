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
