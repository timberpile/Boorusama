import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planner.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';

void main() {
  test('a clean valid plan returns only its planned changes', () {
    final proposed = _proposed();
    final result = const ImportPreflight().validate(
      proposed: proposed,
      resolved: proposed.resolveDefaults(),
      sources: [
        SourcePreflightSnapshot(
          sourceId: 'bookmarks',
          revisionToken: 'revision-1',
          summary: const PlannedChangeSummary(created: 2, updated: 1),
          rollbackBytes: 10,
        ),
      ],
      availableBytes: 100,
      stagingBytes: 20,
      warningsAcknowledged: false,
    );

    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
    expect(result.warnings, isEmpty);
    expect(result.summary, const PlannedChangeSummary(created: 2, updated: 1));
    expect(
      result.sourceSummaries,
      const {
        'bookmarks': PlannedChangeSummary(created: 2, updated: 1),
      },
    );
  });

  test('warnings must be acknowledged before a plan is valid', () {
    final proposed = _proposed();
    const warning = ImportPlanIssue(
      code: 'private_data',
      sourceId: 'profiles',
    );
    final blocked = const ImportPreflight().validate(
      proposed: proposed,
      resolved: proposed.resolveDefaults(),
      sources: [
        SourcePreflightSnapshot(
          sourceId: 'bookmarks',
          revisionToken: 'revision-1',
          warnings: const [warning],
        ),
      ],
      availableBytes: 100,
      stagingBytes: 0,
      warningsAcknowledged: false,
    );
    final accepted = const ImportPreflight().validate(
      proposed: proposed,
      resolved: proposed.resolveDefaults(),
      sources: [
        SourcePreflightSnapshot(
          sourceId: 'bookmarks',
          revisionToken: 'revision-1',
          warnings: const [warning],
        ),
      ],
      availableBytes: 100,
      stagingBytes: 0,
      warningsAcknowledged: true,
    );

    expect(blocked.isValid, isFalse);
    expect(blocked.errors.single.code, 'warnings_not_acknowledged');
    expect(accepted.isValid, isTrue);
  });

  test('invalid merge targets and insufficient storage block apply', () {
    final proposed = _proposed();
    final defaults = proposed.resolveDefaults();
    final source = defaults.sources.single;
    final resolved = defaults.replaceSource(
      source.copyWith(
        items: [
          source.items.single.copyWith(
            action: ImportAction.mergeIntoTarget,
            targetId: 'missing',
          ),
        ],
      ),
    );

    final result = const ImportPreflight().validate(
      proposed: proposed,
      resolved: resolved,
      sources: [
        SourcePreflightSnapshot(
          sourceId: 'bookmarks',
          revisionToken: 'revision-1',
          rollbackBytes: 90,
        ),
      ],
      availableBytes: 100,
      stagingBytes: 20,
      warningsAcknowledged: true,
    );

    expect(result.isValid, isFalse);
    expect(result.errors.map((issue) => issue.code), {
      'invalid_merge_target',
      'insufficient_storage',
    });
  });

  test('an unresolved required profile target blocks apply', () {
    final proposed = const ImportPlanner().plan(const [
      ImportSourcePlanningInput(
        id: 'profiles',
        kind: ImportSourceKind.collection,
        items: [
          ImportItemPlanningInput(
            id: 'profile:99',
            compatibleTargetIds: {'profile:4', 'profile:5'},
            availableActions: {
              ImportAction.update,
              ImportAction.copy,
              ImportAction.skip,
            },
            targetRequiredActions: {ImportAction.update},
            fallbackAction: ImportAction.update,
          ),
        ],
      ),
    ]);

    final result = const ImportPreflight().validate(
      proposed: proposed,
      resolved: proposed.resolveDefaults(),
      sources: [
        SourcePreflightSnapshot(
          sourceId: 'profiles',
          revisionToken: 'revision-1',
        ),
      ],
      availableBytes: 100,
      stagingBytes: 0,
      warningsAcknowledged: true,
    );

    expect(result.isValid, isFalse);
    expect(result.errors.single.code, 'unresolved_item_target');
  });
}

ProposedImportPlan _proposed() => const ImportPlanner().plan(const [
  ImportSourcePlanningInput(
    id: 'bookmarks',
    kind: ImportSourceKind.collection,
    items: [
      ImportItemPlanningInput(
        id: 'group',
        matchingItemId: 'group',
        compatibleTargetIds: {'target'},
      ),
    ],
  ),
]);
