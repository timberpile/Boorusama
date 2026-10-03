import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/profile_import_projection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';

void main() {
  test('credential-free update preserves the exact-ID profile secrets', () {
    final local = [
      _profile(4, 'https://same.example', apiKey: 'first-secret'),
      _profile(8, 'https://same.example', apiKey: 'exact-secret'),
    ];
    final imported = [_profile(8, 'https://same.example', name: 'Imported')];

    final result = const ProfileImportProjector().project(
      imported: imported,
      local: local,
      resolution: _configured(8, ImportAction.update),
      credentialsIncluded: false,
    );

    expect(
      result.profiles.singleWhere((profile) => profile.id == 8).name,
      'Imported',
    );
    expect(
      result.profiles.singleWhere((profile) => profile.id == 8).apiKey,
      'exact-secret',
    );
    expect(
      result.profiles.singleWhere((profile) => profile.id == 4).apiKey,
      'first-secret',
    );
  });

  test('credential-free copy creates an unauthenticated profile', () {
    final result = const ProfileImportProjector().project(
      imported: [_profile(4, 'https://same.example')],
      local: [_profile(4, 'https://same.example', apiKey: 'local-secret')],
      resolution: _configured(4, ImportAction.copy),
      credentialsIncluded: false,
    );

    expect(result.profiles, hasLength(2));
    expect(
      result.profiles.singleWhere((profile) => profile.id == 4).apiKey,
      'local-secret',
    );
    expect(
      result.profiles.singleWhere((profile) => profile.id != 4).apiKey,
      isNull,
    );
  });

  test('credential-free replacement preserves matching credentials only', () {
    final result = const ProfileImportProjector().project(
      imported: [
        _profile(8, 'https://same.example', name: 'Updated'),
        _profile(12, 'https://new.example', name: 'New'),
      ],
      local: [
        _profile(4, 'https://removed.example', apiKey: 'removed-secret'),
        _profile(8, 'https://same.example', apiKey: 'kept-secret'),
      ],
      resolution: ResolvedImportSource(
        id: 'profiles',
        action: ImportAction.replace,
        items: const [],
      ),
      credentialsIncluded: false,
    );

    expect(result.profiles.map((profile) => profile.id), [8, 12]);
    expect(result.profiles.first.apiKey, 'kept-secret');
    expect(result.profiles.last.apiKey, isNull);
  });

  test('replacement keeps a new profile when its ID belongs to a later site match', () {
    final result = const ProfileImportProjector().project(
      imported: [
        _profile(0, 'https://rule34.xxx', name: 'Rule34'),
        _profile(5, 'https://safebooru.donmai.us', name: 'Safebooru'),
      ],
      local: [
        _profile(0, 'https://safebooru.donmai.us', name: 'Default'),
      ],
      resolution: ResolvedImportSource(
        id: 'profiles',
        action: ImportAction.replace,
        items: const [],
      ),
      credentialsIncluded: true,
    );

    expect(result.profiles, hasLength(2));
    expect(result.profiles.map((profile) => profile.id).toSet(), hasLength(2));
    expect(result.profiles.singleWhere((profile) => profile.name == 'Rule34').id,
        isNot(0));
    expect(result.profiles.singleWhere((profile) => profile.name == 'Safebooru').id,
        0);
    expect(result.destinationIds[0], isNot(0));
    expect(result.destinationIds[5], 0);
  });

  test('portable unique match updates a profile with a different local ID', () {
    final result = const ProfileImportProjector().project(
      imported: [_profile(99, 'https://same.example', name: 'Updated')],
      local: [_profile(4, 'https://same.example', apiKey: 'secret')],
      resolution: _configured(99, ImportAction.update),
      credentialsIncluded: false,
    );

    expect(result.profiles, hasLength(1));
    expect(result.profiles.single.id, 4);
    expect(result.profiles.single.name, 'Updated');
    expect(result.profiles.single.apiKey, 'secret');
    expect(result.destinationIds, {99: 4});
  });

  test('ambiguous portable update stays unresolved', () {
    expect(
      () => const ProfileImportProjector().project(
        imported: [_profile(99, 'https://same.example')],
        local: [
          _profile(4, 'https://same.example'),
          _profile(8, 'https://same.example'),
        ],
        resolution: _configured(99, ImportAction.update),
        credentialsIncluded: false,
      ),
      throwsA(isA<UnresolvedProfileImportException>()),
    );
  });
}

ResolvedImportSource _configured(int exportedId, ImportAction action) =>
    ResolvedImportSource(
      id: 'profiles',
      action: ImportAction.configureItems,
      items: [
        ResolvedImportItem(id: 'profile:$exportedId', action: action),
      ],
    );

BooruConfig _profile(
  int id,
  String url, {
  String name = 'Profile',
  String? apiKey,
}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruIdHint': BooruType.danbooru.id,
  'url': url,
  'name': name,
  'apiKey': apiKey,
});
