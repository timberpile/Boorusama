import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_page.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/models/export_item_presentation.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/widgets/import_action_editor.dart';
import 'package:boorusama/core/backups/export_import/widgets/import_recommendation_tree.dart';

void main() {
  for (final count in [0, 1, 2]) {
    testWidgets(
      'shared review shows one site selector only for $count candidates',
      (tester) async {
        const first = '00000000-0000-4000-8000-000000000001';
        const second = '00000000-0000-4000-8000-000000000002';
        const reference = BackupProfileReference(
          id: '00000000-0000-4000-8000-000000000003',
          booruType: 'danbooru',
          url: 'https://site.example',
          name: 'Exported account',
        );
        final mapping = ProfileDependencyMapping(
          reference: reference,
          candidateIds: [if (count > 0) first, if (count > 1) second],
          profileId: count == 1 ? first : null,
          providedByImport: false,
        );
        final notifier = _MappingReviewNotifier(
          mapping,
          profileNames: const {second: 'Imported account'},
          preflight: _result(
            errors: [
              if (count != 1)
                ImportPlanIssue(
                  code: 'unresolved_profile_dependency',
                  sourceId: 'profiles',
                  profileDependency: ProfileDependencyIssueContext(
                    reference: reference,
                    label: 'site.example',
                    missingProfile: count == 0,
                    sourceIds: const {
                      'bookmarks',
                      'pinned_searches',
                      'following_feeds',
                    },
                  ),
                ),
            ],
          ),
        );
        await tester.pumpWidget(_mappingApp(notifier));
        await tester.pumpAndSettle();
        expect(find.text('Create profile'), findsNothing);
        expect(
          find.byType(DropdownButton<String>),
          count == 2 ? findsOneWidget : findsNothing,
        );
        if (count == 0) {
          expect(find.textContaining('site.example'), findsOneWidget);
          expect(find.textContaining('profile management'), findsOneWidget);
        }
        if (count == 2) {
          expect(find.text('Select a matching profile'), findsOneWidget);
          expect(find.text('site.example'), findsOneWidget);
          expect(find.textContaining('profile management'), findsNothing);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('apply-import')),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.byType(DropdownButton<String>));
          await tester.pumpAndSettle();
          expect(find.text('Imported account'), findsOneWidget);
          await tester.tap(find.text('Imported account'));
          await tester.pumpAndSettle();
          expect(notifier.chosen, second);
          expect(find.byType(DropdownButton<String>), findsOneWidget);
          expect(find.text('Imported account'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('resolved dependency mappings stay visible and editable', (
    tester,
  ) async {
    const first = '00000000-0000-4000-8000-000000000001';
    const second = '00000000-0000-4000-8000-000000000002';
    const reference = BackupProfileReference(
      id: first,
      booruType: 'danbooru',
      url: 'https://same.example',
      name: 'Incoming',
    );
    final notifier = _MappingReviewNotifier(
      ProfileDependencyMapping(
        reference: reference,
        candidateIds: const {first, second},
        profileId: first,
        providedByImport: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importFlowProvider.overrideWith(() => notifier),
          backupRegistryProvider.overrideWithValue(BackupRegistry()),
          exportSelectionLabelsProvider.overrideWithValue(
            const ExportSelectionLabels(children: {}),
          ),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(
              initialConfigs: [
                BooruConfig.fromJson({
                  ...BooruConfig.empty.toJson(),
                  'id': first,
                  'name': 'First',
                }),
                BooruConfig.fromJson({
                  ...BooruConfig.empty.toJson(),
                  'id': second,
                  'name': 'Second',
                }),
              ],
            ),
          ),
        ],
        child: _app(const ImportFlowPage(packagePath: 'unused')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('same.example'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Create profile'), findsNothing);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second').last);
    await tester.pumpAndSettle();
    expect(notifier.chosen, second);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('shows only actions that are valid for an imported item', (
    tester,
  ) async {
    final proposed = ProposedImportSource(
      id: 'bookmarks',
      kind: ImportSourceKind.collection,
      selectionComplete: false,
      availableActions: const {
        ImportAction.configureItems,
        ImportAction.skip,
      },
      defaultAction: ImportAction.configureItems,
      items: [
        ProposedImportItem(
          id: 'new',
          availableActions: const {ImportAction.copy, ImportAction.skip},
          defaultAction: ImportAction.copy,
          compatibleTargetIds: const {},
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        ImportActionEditor(
          proposed: proposed,
          resolved: ProposedImportPlan(
            sources: [proposed],
          ).resolveDefaults().sources.single,
          onChanged: (_) {},
          sourceLabel: (_) => 'Bookmark groups',
          itemLabel: (_) => 'New group',
          targetLabel: (id) => id,
        ),
      ),
    );

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Update'), findsNothing);
    expect(find.text('Merge into...'), findsNothing);
    expect(find.byType(DropdownButton<ImportAction>), findsNothing);
    expect(find.byType(KurumiSettingsTile<ImportAction>), findsNWidgets(2));
  });

  testWidgets('uses concise import action names', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Column(
            children: [
              for (final action in const [
                ImportAction.update,
                ImportAction.merge,
                ImportAction.mergeIntoTarget,
                ImportAction.copy,
              ])
                Text(importActionLabel(context, action)),
            ],
          ),
        ),
      ),
    );

    for (final label in ['Update', 'Merge', 'Merge into...', 'Copy']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('shows merge target only after merge into is selected', (
    tester,
  ) async {
    final proposed = ProposedImportSource(
      id: 'bookmarks',
      kind: ImportSourceKind.collection,
      selectionComplete: false,
      availableActions: const {ImportAction.configureItems},
      defaultAction: ImportAction.configureItems,
      items: [
        ProposedImportItem(
          id: 'incoming',
          availableActions: const {
            ImportAction.mergeIntoTarget,
            ImportAction.copy,
          },
          defaultAction: ImportAction.mergeIntoTarget,
          compatibleTargetIds: const {'reference'},
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        ImportActionEditor(
          proposed: proposed,
          resolved: ProposedImportPlan(
            sources: [proposed],
          ).resolveDefaults().sources.single,
          onChanged: (_) {},
          sourceLabel: (_) => 'Bookmark groups',
          itemLabel: (_) => 'Incoming',
          targetLabel: (_) => 'Reference',
        ),
      ),
    );

    expect(find.text('Target'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('shows a target picker for an ambiguous profile update', (
    tester,
  ) async {
    final proposed = ProposedImportSource(
      id: 'profiles',
      kind: ImportSourceKind.collection,
      selectionComplete: false,
      availableActions: const {ImportAction.configureItems},
      defaultAction: ImportAction.configureItems,
      items: [
        ProposedImportItem(
          id: 'profile:99',
          availableActions: const {
            ImportAction.update,
            ImportAction.copy,
            ImportAction.skip,
          },
          defaultAction: ImportAction.update,
          compatibleTargetIds: const {'profile:4', 'profile:5'},
          targetRequiredActions: const {ImportAction.update},
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        ImportActionEditor(
          proposed: proposed,
          resolved: ProposedImportPlan(
            sources: [proposed],
          ).resolveDefaults().sources.single,
          onChanged: (_) {},
          sourceLabel: (_) => 'Booru profiles',
          itemLabel: (_) => 'Remote',
          targetLabel: (id) => id,
        ),
      ),
    );

    expect(find.text('Target'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets(
    'groups incoming item actions and preserves unknown fallback rows',
    (
      tester,
    ) async {
      final proposed = ProposedImportSource(
        id: 'pinned_searches',
        kind: ImportSourceKind.collection,
        selectionComplete: false,
        availableActions: const {ImportAction.configureItems},
        defaultAction: ImportAction.configureItems,
        items: [
          for (final id in ['folder:one', 'search:one', 'search:unknown'])
            ProposedImportItem(
              id: id,
              availableActions: const {ImportAction.copy, ImportAction.skip},
              defaultAction: ImportAction.copy,
              compatibleTargetIds: const {},
            ),
        ],
      );
      await tester.pumpWidget(
        _app(
          ImportActionEditor(
            proposed: proposed,
            resolved: ProposedImportPlan(
              sources: [proposed],
            ).resolveDefaults().sources.single,
            onChanged: (_) {},
            sourceLabel: (_) => 'Pinned searches',
            itemLabel: (id) => id == 'search:unknown' ? 'Unknown search' : id,
            targetLabel: (id) => id,
            itemTree: const ExportSelectionDescriptor.collection(
              id: 'pinned_searches',
              children: [
                ExportSelectionNode(
                  id: 'folder:one',
                  children: [ExportSelectionNode(id: 'search:one')],
                ),
              ],
            ),
            itemPresentation: const ExportSelectionPresentation(
              items: {
                'folder:one': ExportItemPresentation(label: 'Landscapes'),
                'search:one': ExportItemPresentation(
                  label: 'Blue sky',
                  trailingLabel: 'A very long profile name that must fit',
                ),
              },
            ),
          ),
        ),
      );

      expect(find.text('Landscapes'), findsOneWidget);
      expect(find.text('Blue sky'), findsNothing);
      expect(find.text('Unknown search'), findsOneWidget);

      await tester.tap(find.text('Landscapes'));
      await tester.pumpAndSettle();

      expect(find.text('Landscapes'), findsOneWidget);
      expect(find.text('Blue sky'), findsWidgets);
      expect(
        find.text('A very long profile name that must fit'),
        findsOneWidget,
      );
      final folderX = tester.getTopLeft(find.text('Landscapes').first).dx;
      final searchX = tester.getTopLeft(find.text('Blue sky').first).dx;
      expect(searchX - folderX, 8);
      final cardX = tester.getTopLeft(find.byType(Card).first).dx;
      final categoryX = tester.getTopLeft(find.text('Pinned searches')).dx;
      expect(categoryX - cardX, greaterThanOrEqualTo(12));
      expect(find.byType(KurumiSettingsTile<ImportAction>), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long import profile labels fit narrow rows', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 220,
          child: ImportItemLabel(
            item: ExportItemPresentation(
              label: 'A pinned search with a deliberately long title',
              trailingLabel: 'A very long profile name that must fit',
            ),
          ),
        ),
      ),
    );

    expect(find.text('A very long profile name that must fit'), findsOneWidget);
    final profile = tester.widget<Text>(
      find.text('A very long profile name that must fit'),
    );
    final theme = Theme.of(
      tester.element(find.text('A very long profile name that must fit')),
    );
    expect(profile.maxLines, 1);
    expect(profile.style?.fontSize, theme.textTheme.bodySmall?.fontSize);
    expect(
      profile.style?.color,
      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed imports show a friendly recovery action', (
    tester,
  ) async {
    var recovered = false;
    await tester.pumpWidget(
      _app(
        ImportErrorView(
          onChooseAnother: () => recovered = true,
        ),
      ),
    );

    expect(find.text('This export could not be opened'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    await tester.tap(find.text('Choose another export'));
    expect(recovered, true);
  });

  testWidgets('completed imports offer a clear way to leave', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      _app(ImportCompletionView(onDone: () => done = true)),
    );

    expect(find.text('Import complete'), findsOneWidget);
    await tester.tap(find.text('Done'));
    expect(done, true);
  });

  testWidgets('completed imports summarize what changed', (tester) async {
    await tester.pumpWidget(
      _app(
        ImportCompletionView(
          summary: const PlannedChangeSummary(created: 1, updated: 2),
          onDone: () {},
        ),
      ),
    );

    expect(find.text('Created 1 · Updated 2'), findsOneWidget);
  });

  testWidgets('completed imports explain when bookmarks could not refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ImportCompletionView(
          onDone: () {},
          bookmarkRefreshFailed: true,
        ),
      ),
    );

    expect(find.text('Import complete'), findsOneWidget);
    expect(
      find.text('Bookmarks could not refresh. Reopen the app to see them.'),
      findsOneWidget,
    );
  });

  test('only mutations count as import work', () {
    expect(
      const PlannedChangeSummary(
        unchanged: 4,
        preserved: 2,
      ).hasMutations,
      false,
    );
    expect(const PlannedChangeSummary(updated: 1).hasMutations, true);
  });

  testWidgets('warning-only no-op shows Done without empty problems', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ImportReviewValidation(
          preflight: _result(
            warnings: const [
              ImportPlanIssue(code: 'private_data', sourceId: 'profiles'),
            ],
            validated: true,
          ),
          sourceNames: const {'profiles': 'Booru profiles'},
          itemLabels: const {},
          onWarningsAcknowledged: (_) {},
          onApply: () {},
          onDone: () {},
        ),
      ),
    );

    expect(find.text('Warnings'), findsOneWidget);
    expect(find.text('I understand these warnings'), findsNothing);
    expect(find.text('Problems to resolve'), findsNothing);
    expect(find.text('Nothing to import'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('real errors keep a no-op plan blocked', (tester) async {
    await tester.pumpWidget(
      _app(
        ImportReviewValidation(
          preflight: _result(
            errors: const [
              ImportPlanIssue(code: 'invalid_source_action', sourceId: 'x'),
            ],
          ),
          sourceNames: const {'x': 'Settings'},
          itemLabels: const {},
          onWarningsAcknowledged: (_) {},
          onApply: () {},
          onDone: () {},
        ),
      ),
    );

    expect(find.text('Problems to resolve'), findsOneWidget);
    expect(find.text('Nothing to import'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  test('planned changes omit zero and unchanged counters', () {
    final labels = plannedChangeCountLabels(
      const PlannedChangeSummary(created: 2, deleted: 1, unchanged: 8),
      createdTemplate: 'Create {count}',
      updatedTemplate: 'Update {count}',
      deletedTemplate: 'Remove {count}',
    );

    expect(labels, ['Create 2', 'Remove 1']);
  });

  test('planned changes distinguish bookmarks from groups', () {
    final labels = plannedSourceChangeLabels(
      const PlannedChangeSummary(
        created: 11,
        entitySummaries: {
          'bookmark': PlannedChangeSummary(created: 10),
          'bookmark-group': PlannedChangeSummary(created: 1),
        },
      ),
      createdTemplate: 'Create {count}',
      updatedTemplate: 'Update {count}',
      deletedTemplate: 'Remove {count}',
      entityNouns: {
        'bookmark': (count) => count == 1 ? 'bookmark' : 'bookmarks',
        'bookmark-group': (count) => count == 1 ? 'group' : 'groups',
      },
      homeArrangementLabel: 'Home arrangement',
    );

    expect(labels, ['Create 10 bookmarks', 'Create 1 group']);
  });

  test('planned changes identify Home organization separately', () {
    final labels = plannedSourceChangeLabels(
      const PlannedChangeSummary(
        created: 131,
        updated: 1,
        entitySummaries: {
          'pinned-search': PlannedChangeSummary(created: 131),
          'pinned-home': PlannedChangeSummary(updated: 1),
        },
      ),
      createdTemplate: 'Create {count}',
      updatedTemplate: 'Update {count}',
      deletedTemplate: 'Remove {count}',
      entityNouns: {'pinned-search': (count) => 'searches'},
      homeArrangementLabel: 'Home arrangement',
    );

    expect(labels, ['Create 131 searches', 'Update Home arrangement']);
  });
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

ImportPreflightResult _result({
  List<ImportPlanIssue> warnings = const [],
  List<ImportPlanIssue> errors = const [],
  bool validated = false,
}) => ImportPreflightResult(
  warnings: warnings,
  errors: errors,
  summary: const PlannedChangeSummary(unchanged: 1),
  validatedPlan: validated
      ? ValidatedImportPlan(
          plan: ResolvedImportPlan(sources: const []),
          revisionTokens: const {},
          summary: const PlannedChangeSummary(unchanged: 1),
        )
      : null,
);

class _MappingReviewNotifier extends ImportFlowNotifier {
  _MappingReviewNotifier(
    this.mapping, {
    this.preflight,
    this.profileNames = const {},
  });
  final ImportPreflightResult? preflight;
  final Map<String, String> profileNames;
  ProfileDependencyMapping mapping;
  String? chosen;
  @override
  ImportFlowState build() => _review();
  @override
  Future<void> load(String path) async {}
  ImportFlowState _review() => ImportFlowState(
    status: ImportFlowStatus.review,
    proposed: ProposedImportPlan(sources: const []),
    resolved: ResolvedImportPlan(sources: const []),
    preflight: preflight ?? _result(),
    profileMappings: [mapping],
    profileNames: profileNames,
  );
  @override
  void chooseProfileMapping(ProfileSiteKey key, String profileId) {
    chosen = profileId;
    mapping = ProfileDependencyMapping(
      reference: mapping.reference,
      candidateIds: mapping.candidateIds,
      profileId: profileId,
      providedByImport: false,
    );
    state = _review();
  }
}

Widget _mappingApp(_MappingReviewNotifier notifier) => ProviderScope(
  overrides: [
    importFlowProvider.overrideWith(() => notifier),
    backupRegistryProvider.overrideWithValue(BackupRegistry()),
    exportSelectionLabelsProvider.overrideWithValue(
      const ExportSelectionLabels(children: {}),
    ),
    booruConfigProvider.overrideWith(
      () => BooruConfigNotifier(
        initialConfigs: [
          BooruConfig.fromJson({
            ...BooruConfig.empty.toJson(),
            'id': '00000000-0000-4000-8000-000000000001',
            'name': 'First account',
          }),
        ],
      ),
    ),
  ],
  child: _app(const ImportFlowPage(packagePath: 'unused')),
);
