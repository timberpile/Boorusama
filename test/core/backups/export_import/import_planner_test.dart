import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planner.dart';
import 'package:boorusama/core/backups/export_import/import/profile_mapping.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/proxy/types.dart';

void main() {
  test('partial collections cannot replace the entire local category', () {
    final source = const ImportPlanner()
        .plan(const [
          ImportSourcePlanningInput(
            id: 'bookmarks',
            kind: ImportSourceKind.collection,
            selectionComplete: false,
          ),
        ])
        .sources
        .single;

    expect(source.availableActions, {
      ImportAction.configureItems,
      ImportAction.skip,
    });
    expect(source.defaultAction, ImportAction.configureItems);
  });

  test('same identity defaults to update and exposes matching actions', () {
    final item = const ImportPlanner()
        .plan(const [
          ImportSourcePlanningInput(
            id: 'bookmarks',
            kind: ImportSourceKind.collection,
            items: [
              ImportItemPlanningInput(
                id: 'group',
                matchingItemId: 'group',
                compatibleTargetIds: {'other'},
              ),
            ],
          ),
        ])
        .sources
        .single
        .items
        .single;

    expect(item.defaultAction, ImportAction.update);
    expect(item.availableActions, {
      ImportAction.update,
      ImportAction.merge,
      ImportAction.mergeIntoTarget,
      ImportAction.copy,
      ImportAction.skip,
    });
  });

  test('missing identity imports as a copy and cannot update or merge', () {
    final item = const ImportPlanner()
        .plan(const [
          ImportSourcePlanningInput(
            id: 'feeds',
            kind: ImportSourceKind.collection,
            items: [ImportItemPlanningInput(id: 'feed')],
          ),
        ])
        .sources
        .single
        .items
        .single;

    expect(item.defaultAction, ImportAction.copy);
    expect(item.availableActions, {ImportAction.copy, ImportAction.skip});
  });

  test(
    'unsupported sender recommendations fall back and produce a warning',
    () {
      final plan = const ImportPlanner().plan(const [
        ImportSourcePlanningInput(
          id: 'bookmarks',
          kind: ImportSourceKind.collection,
          selectionComplete: false,
          recommendedAction: ImportAction.replace,
          items: [
            ImportItemPlanningInput(
              id: 'new-group',
              recommendedAction: ImportAction.update,
            ),
          ],
        ),
      ]);

      expect(plan.sources.single.defaultAction, ImportAction.configureItems);
      expect(plan.sources.single.items.single.defaultAction, ImportAction.copy);
      expect(
        plan.warnings.map((warning) => warning.code),
        ['unsupported_recommended_action', 'unsupported_recommended_action'],
      );
    },
  );

  test('a sole compatible profile is selected automatically', () {
    final mapping = const ProfileMapper()
        .map(
          const [
            BackupProfileReference(
              id: 99,
              booruType: 'danbooru',
              url: 'https://remote.example',
              name: 'Remote',
            ),
          ],
          [_profile(4, 'https://local.example')],
        )
        .single;

    expect(mapping.state, ProfileMappingState.automatic);
    expect(mapping.localProfileId, 4);
  });

  test('several compatible profiles remain unresolved', () {
    final mapping = const ProfileMapper()
        .map(
          const [
            BackupProfileReference(
              id: 99,
              booruType: 'danbooru',
              url: 'https://remote.example',
              name: 'Remote',
            ),
          ],
          [
            _profile(4, 'https://one.example'),
            _profile(5, 'https://two.example'),
          ],
        )
        .single;

    expect(mapping.state, ProfileMappingState.ambiguous);
    expect(mapping.localProfileId, isNull);
    expect(mapping.candidateIds, {4, 5});
  });

  test('credential-free profile updates preserve local secrets', () {
    final existing = BooruConfig.fromJson({
      ..._profile(4, 'https://example.test').toJson(),
      'apiKey': 'local-key',
      'login': 'local-user',
      'passHash': 'local-hash',
      'proxySettings': const ProxySettings(
        type: ProxyType.http,
        host: 'old-proxy',
        port: 8080,
        username: 'proxy-user',
        password: 'proxy-pass',
      ).toJson(),
    });
    final imported = BooruConfig.fromJson({
      ..._profile(4, 'https://example.test').toJson(),
      'name': 'Imported name',
      'apiKey': null,
      'login': null,
      'passHash': null,
      'proxySettings': const ProxySettings(
        type: ProxyType.http,
        host: 'new-proxy',
        port: 9090,
      ).toJson(),
    });

    final merged = mergeImportedProfile(
      imported: imported,
      existing: existing,
      credentialsIncluded: false,
    );

    expect(merged.name, 'Imported name');
    expect(merged.apiKey, 'local-key');
    expect(merged.login, 'local-user');
    expect(merged.passHash, 'local-hash');
    expect(merged.proxySettings?.host, 'new-proxy');
    expect(merged.proxySettings?.username, 'proxy-user');
    expect(merged.proxySettings?.password, 'proxy-pass');
  });

  test('ambiguous profile updates require an explicit compatible target', () {
    final item = const ImportPlanner()
        .plan(const [
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
        ])
        .sources
        .single
        .items
        .single;

    expect(item.defaultAction, ImportAction.update);
    expect(item.defaultTargetId, isNull);
    expect(item.targetRequiredActions, {ImportAction.update});
  });
}

BooruConfig _profile(int id, String url) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruIdHint': BooruType.danbooru.id,
  'url': url,
  'name': 'Local',
});
