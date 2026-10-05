import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/foundation/filesystem.dart';

ValidatedImportPlan buildValidatedPlan(List<String> ids) => ValidatedImportPlan(
  plan: ResolvedImportPlan(
    sources: [
      for (final id in ids)
        ResolvedImportSource(
          id: id,
          action: ImportAction.replace,
          items: const [],
        ),
    ],
  ),
  revisionTokens: {for (final id in ids) id: 'revision'},
  summary: const PlannedChangeSummary(),
);

final class FakeImportSource implements ImportTransactionSource {
  FakeImportSource(
    this.id,
    this.fs, {
    this.revision = 'revision',
    this.log,
    this.failApply = false,
    this.failRestore = false,
  }) : value = 'old:$id';

  @override
  final String id;
  final AppFileSystem fs;
  final String revision;
  final List<String>? log;
  final bool failApply;
  bool failRestore;
  String value;
  var applyCount = 0;

  @override
  Future<void> apply(ResolvedImportSource plan) async {
    applyCount++;
    log?.add('apply:$id');
    value = 'imported:$id';
    if (failApply) throw StateError('apply failed: $id');
  }

  @override
  Future<void> captureRollback(String outputPath) =>
      fs.writeString(outputPath, value);

  @override
  Future<void> durableSync() async => log?.add('sync:$id');

  @override
  Future<String> revisionToken() async => revision;

  @override
  Future<void> restore(String rollbackPath) async {
    log?.add('restore:$id');
    if (failRestore) throw StateError('restore failed: $id');
    value = await fs.readString(rollbackPath);
  }
}
