import 'package:boorusama/core/backups/export_import/import/import_change_summarizer.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replace reports created removed and identical records exactly', () {
    final summary = const ImportChangeSummarizer().summarize(
      source: ResolvedImportSource(
        id: 'bookmarks',
        action: ImportAction.replace,
        items: const [],
      ),
      facts: const ImportSourceChangeFacts(
        sourceId: 'bookmarks',
        incomingIds: {'a', 'b'},
        existingIds: {'b', 'c'},
        identicalIds: {'b'},
      ),
    );

    expect(
      summary,
      const PlannedChangeSummary(created: 1, deleted: 1, unchanged: 1),
    );
  });

  test('individual actions report their observable effects', () {
    final summary = const ImportChangeSummarizer().summarize(
      source: ResolvedImportSource(
        id: 'bookmarks',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(id: 'copy', action: ImportAction.copy),
          ResolvedImportItem(id: 'update', action: ImportAction.update),
          ResolvedImportItem(id: 'merge', action: ImportAction.merge),
          ResolvedImportItem(
            id: 'target',
            action: ImportAction.mergeIntoTarget,
            targetId: 'local',
          ),
          ResolvedImportItem(id: 'skip', action: ImportAction.skip),
        ],
      ),
      facts: const ImportSourceChangeFacts(sourceId: 'bookmarks'),
    );

    expect(
      summary,
      const PlannedChangeSummary(
        created: 1,
        updated: 3,
        preserved: 1,
      ),
    );
  });

  test('identical imported items remain visible as no-op changes', () {
    final summary = const ImportChangeSummarizer().summarize(
      source: ResolvedImportSource(
        id: 'pinned_searches',
        action: ImportAction.configureItems,
        items: const [],
      ),
      facts: const ImportSourceChangeFacts(
        sourceId: 'pinned_searches',
        identicalIds: {'search:one', 'search:two'},
      ),
    );

    expect(summary, const PlannedChangeSummary(unchanged: 2));
  });

  test('skipping a source preserves every existing item', () {
    final summary = const ImportChangeSummarizer().summarize(
      source: ResolvedImportSource(
        id: 'bookmarks',
        action: ImportAction.skip,
        items: const [],
      ),
      facts: const ImportSourceChangeFacts(
        sourceId: 'bookmarks',
        existingIds: {'a', 'b'},
      ),
    );

    expect(summary, const PlannedChangeSummary(preserved: 2));
  });
}
