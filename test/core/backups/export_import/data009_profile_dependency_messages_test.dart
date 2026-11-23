import 'package:boorusama/core/backups/export_import/import/import_flow_page.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

void main() {
  testWidgets(
    'review blocks Apply for legacy feeds and allows Topics with optional mappings',
    (tester) async {
      const references = [
        BackupProfileReference(
          id: '00000000-0000-4000-8000-000000000022',
          booruType: 'danbooru',
          url: 'https://first.example',
          name: 'Shared',
        ),
        BackupProfileReference(
          id: '00000000-0000-4000-8000-000000000023',
          booruType: 'danbooru',
          url: 'https://second.example',
          name: 'Shared',
        ),
        BackupProfileReference(
          id: '00000000-0000-4000-8000-000000000021',
          booruType: 'danbooru',
          url: 'https://third.example',
          name: 'Third',
        ),
      ];
      Future<void> review(
        List<BackupProfileReference> selected,
      ) async {
        final dependencies = const ProfileDependencyPlanner().plan(
          references: selected,
          localProfiles: [
            for (final id in [
              '00000000-0000-4000-8000-000000000031',
              '00000000-0000-4000-8000-000000000032',
            ])
              BooruConfig.fromJson({
                ...BooruConfig.empty.toJson(),
                'id': id,
                'booruId': BooruType.danbooru.id,
                'booruIdHint': BooruType.danbooru.id,
                'url': references.first.url,
              }),
          ],
          dependentSources: {
            ProfileReferenceKey.fromReference(references[0]): {
              'pinned_searches',
            },
            ProfileReferenceKey.fromReference(references[1]): {
              'following_feeds',
            },
            ProfileReferenceKey.fromReference(references[2]): {
              'pinned_searches',
              'following_feeds',
            },
          },
        );
        await tester.pumpWidget(
          _app(
            ImportReviewValidation(
              preflight: _result(errors: dependencies.errors),
              sourceNames: const {
                'pinned_searches': 'Topics',
                'following_feeds': 'Topic feeds',
              },
              itemLabels: const {},
              onWarningsAcknowledged: (_) {},
              onApply: () {},
              onDone: () {},
            ),
          ),
        );
      }

      await review([...references, references.first]);
      const searches = 'first.example: Select a profile to import Topics.';
      const feeds = 'second.example: Profile required to import Topic feeds.';
      const both =
          'third.example: Profile required to import Topics, Topic feeds.';
      expect(find.text(searches), findsNothing);
      expect(find.text(feeds), findsOneWidget);
      expect(find.text(both), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await review([references.first, references.last]);
      expect(find.text(feeds), findsNothing);
      expect(find.text(both), findsOneWidget);
      await review([references.first]);
      expect(find.text(searches), findsNothing);
      expect(find.text(both), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);
ImportPreflightResult _result({List<ImportPlanIssue> errors = const []}) =>
    ImportPreflightResult(
      warnings: const [],
      errors: errors,
      summary: const PlannedChangeSummary(unchanged: 1),
      validatedPlan: errors.isNotEmpty
          ? null
          : ValidatedImportPlan(
              plan: ResolvedImportPlan(sources: const []),
              revisionTokens: const {},
              summary: const PlannedChangeSummary(unchanged: 1),
            ),
    );
