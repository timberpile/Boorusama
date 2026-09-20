import 'package:boorusama/core/backups/sources/search_backup_envelope.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a version one payload for its selected source', () {
    expect(
      () => requireSearchBackupEnvelope(
        _payload(source: 'following_feeds'),
        'following_feeds',
      ),
      returnsNormally,
    );
  });

  for (final c in [
    (name: 'a different source', source: 'pinned_searches', version: 1),
    (name: 'a missing source', source: null, version: 1),
    (name: 'an unsupported version', source: 'following_feeds', version: 2),
  ]) {
    test('rejects ${c.name} before importing', () {
      expect(
        () => requireSearchBackupEnvelope(
          _payload(source: c.source, version: c.version),
          'following_feeds',
        ),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }

  const reference = BackupProfileReference(
    id: 4,
    booruType: 'danbooru',
    url: 'https://EXAMPLE.test/Posts/',
    name: 'Remote',
  );
  for (final c in [
    (
      name: 'matching ID among duplicate sites',
      profiles: [_profile(9), _profile(4)],
      expectedId: 4,
    ),
    (
      name: 'unique site after an ID change',
      profiles: [_profile(9)],
      expectedId: 9,
    ),
    (
      name: 'ambiguous site without the original ID',
      profiles: [_profile(9), _profile(10)],
      expectedId: null,
    ),
    (
      name: 'same ID on another booru type',
      profiles: [_profile(4, type: BooruType.gelbooru)],
      expectedId: null,
    ),
  ]) {
    test('resolves ${c.name}', () {
      expect(resolveBackupProfile(reference, c.profiles)?.id, c.expectedId);
    });
  }

  test('parses a portable profile URL without credentials or query data', () {
    final parsed = parseBackupProfile({
      'id': 4,
      'booruType': 'danbooru',
      'url': 'https://user:secret@EXAMPLE.test/Posts/?token=private',
      'name': 'Remote',
    }, 'profile');
    expect(parsed.url, 'https://example.test/Posts');
    expect(parsed.toJson()['url'], 'https://example.test/Posts');
  });

  test('rejects an invalid portable profile reference', () {
    expect(
      () => parseBackupProfile({
        'id': 4,
        'booruType': 'danbooru',
        'url': 'javascript:alert(1)',
        'name': 'Remote',
      }, 'profile'),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });
}

ExportDataPayload _payload({String? source, int version = 1}) =>
    ExportDataPayload(
      version: version,
      exportDate: null,
      exportVersion: null,
      data: const [],
      extraFields: {if (source != null) 'source': source},
    );

BooruConfig _profile(int id, {BooruType type = BooruType.danbooru}) =>
    BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': id,
      'booruIdHint': type.id,
      'url': 'https://example.test/Posts',
      'name': 'Local',
    });
