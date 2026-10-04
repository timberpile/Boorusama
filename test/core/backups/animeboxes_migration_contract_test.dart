import 'dart:io';

import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_codec.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/backups/utils/json_handler.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy bookmark artifact is rejected by the breaking export version',
    () {
      final payload = decodeData(data: _fixture('boorusama_bookmarks.json'));

      expect(payload.version, 2);
      expect(
        () => BookmarkBackupCodec().parse(payload),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    },
  );

  test('blacklist artifact decodes through the production list handler', () {
    final payload = decodeData(
      data: _fixture('boorusama_blacklisted_tags.json'),
    );
    final tags = ListHandler<BlacklistedTag>(
      parser: BlacklistedTag.fromJson,
      encoder: (tag) => tag.toJson(),
    ).parse(payload);

    expect(payload.version, 1);
    final tag = tags.single;
    expect(tag.id, 1);
    expect(tag.name, 'blocked, tag');
    expect(tag.isActive, isTrue);
    expect(tag.createdDate, DateTime.parse('2026-08-16T08:48:50+0200'));
    expect(tag.updatedDate, tag.createdDate);
  });

  test('old pinned-search artifact rejects its integer profile ID', () {
    final payload = decodeData(
      data: _fixture('boorusama_pinned_searches.json'),
    );

    expect(payload.version, 1);
    expect(payload.extraFields['source'], 'pinned_searches');
    expect(
      () => PinnedSearchBackupCodec().parse(payload),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });
}

String _fixture(String name) => File(
  'packages/boorusama_cli/test/migrations/animeboxes/fixtures/$name',
).readAsStringSync();
