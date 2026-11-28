import 'package:boorusama/core/backups/export_import/import/import_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress throttles updates while preserving phase boundaries', () {
    var time = Duration.zero;
    var cancelled = false;
    final seen = <ImportProgressValue>[];
    final progress = ImportProgress(
      seen.add,
      elapsed: () => time,
      cancelled: () => cancelled,
    );

    progress.show(ImportProgressPhase.reading, total: 100);
    time += const Duration(milliseconds: 99);
    progress.show(ImportProgressPhase.reading, completed: 49, total: 100);
    expect(seen.map((sample) => sample.completed), [0]);

    time += const Duration(milliseconds: 1);
    progress.show(ImportProgressPhase.reading, completed: 50, total: 100);
    progress.show(ImportProgressPhase.reading, completed: 100, total: 100);
    progress.show(ImportProgressPhase.decoding);
    expect(seen.map((sample) => sample.completed), [0, 50, 100, 0]);
    expect(seen.last.phase, ImportProgressPhase.decoding);
    expect(seen.last.total, isNull);

    cancelled = true;
    progress.show(ImportProgressPhase.preparing);
    expect(seen, hasLength(4));
  });

  test(
    'worker progress arrives before worker completion is returned',
    () async {
      final seen = <ImportProgressValue>[];
      final result = await ImportProgress(seen.add).run(
        () => runImportWorker(_reportWorkerProgress),
      );

      expect(result, 42);
      expect(seen.map((sample) => sample.completed), [0, 42]);
      expect(seen.every((sample) => sample.total == 42), isTrue);
    },
  );
}

Future<int> _reportWorkerProgress() async {
  final progress = ImportProgress.current!;
  progress.show(ImportProgressPhase.reading, total: 42);
  progress.show(ImportProgressPhase.reading, completed: 42, total: 42);
  return 42;
}
