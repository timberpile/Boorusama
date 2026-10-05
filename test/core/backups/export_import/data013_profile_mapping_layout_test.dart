import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_page.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';

void main() {
  for (final scenario in [
    (width: 360.0, scale: 1.0),
    (width: 320.0, scale: 2.0),
    (width: 800.0, scale: 1.0),
  ]) {
    testWidgets(
      'mapping information and choices remain readable at ${scenario.width} with ${scenario.scale} text',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(scenario.width, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const first = '00000000-0000-4000-8000-000000000001';
        const second = '00000000-0000-4000-8000-000000000002';
        const incoming =
            'Incoming profile with a representative long display name';
        const website = 'https://danbooru.donmai.us/a/representative/long/path';
        final notifier = _MappingReviewNotifier(
          ProfileDependencyMapping(
            reference: const BackupProfileReference(
              id: first,
              booruType: 'danbooru',
              url: website,
              name: incoming,
            ),
            candidateIds: const {first, second},
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
                    for (final entry in [
                      (id: first, url: 'https://first.example'),
                      (id: second, url: 'https://second.example'),
                    ])
                      BooruConfig.fromJson({
                        ...BooruConfig.empty.toJson(),
                        'id': entry.id,
                        'name': 'Same long target profile name',
                        'url': entry.url,
                      }),
                  ],
                ),
              ),
            ],
            child: TranslationProvider(
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: ImportFlowPage(packagePath: 'unused'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final information = tester.getRect(
          find.text('danbooru.donmai.us/a/representative/long/path'),
        );
        final selector = tester.getRect(find.byType(DropdownButton<String>));
        expect(information.width, greaterThan(scenario.width - 80));
        expect(selector.top, greaterThan(information.bottom));
        expect(find.text('or'), findsNothing);
        expect(find.text('Create profile'), findsNothing);
        final semantics = tester.ensureSemantics();
        await tester.pump();
        expect(
          find.bySemanticsLabel(
            RegExp('Target: danbooru.donmai.us/a/representative/long/path'),
          ),
          findsOneWidget,
        );
        semantics.dispose();
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Same long target profile name (1)'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Same long target profile name (2)').last);
        await tester.pumpAndSettle();
        expect(notifier.chosen, second);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

ImportPreflightResult _result() => ImportPreflightResult(
  warnings: const [],
  errors: const [],
  summary: const PlannedChangeSummary(unchanged: 1),
);

class _MappingReviewNotifier extends ImportFlowNotifier {
  _MappingReviewNotifier(this.mapping);
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
    preflight: _result(),
    profileMappings: [mapping],
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
