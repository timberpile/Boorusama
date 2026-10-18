// Dart imports:
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/changelogs/repo.dart';
import 'package:boorusama/core/changelogs/types.dart';
import 'package:boorusama/core/cache/hive_persistent_cache_store.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<String> box;
  late ChangelogRepositoryImpl repository;
  late String asset;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('changelog_test_');
    box = await Hive.openBox<String>('changelog', path: directory.path);
    repository = ChangelogRepositoryImpl(HivePersistentCacheStore(box));
    asset = await File('CHANGELOG.md').readAsString();
    rootBundle.clear();
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      if (utf8.decode(message!.buffer.asUint8List()) != 'CHANGELOG.md') {
        return null;
      }
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(asset)));
    });
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
    rootBundle.clear();
    await box.close();
    await directory.delete(recursive: true);
  });

  test('loads all subsections of the bundled latest release', () async {
    final data = await repository.loadLatestChangelog();

    expect(data.version.toString(), '4.6.1-timberpile.1');
    expect(data.content, contains('## Features\n\n'));
    expect(data.content, contains('## Fixes and improvements\n\n'));
    expect(
      data.content,
      contains(
        '- Save tags and post information alongside downloads.',
      ),
    );
    expect(data.content, isNot(contains('# 4.5.0-timberpile.5')));
    expect(data.content, isNot(contains('nested folders')));
  });

  final cases = [
    (
      name: 'preserves blank lines and nested headings before the next release',
      asset: '# 4.6.0\n\n## Changes\n\n- First\n\n### Details\n- Second\n\n# 4.5.0\n- Older\n',
      content: '\n## Changes\n\n- First\n\n### Details\n- Second\n\n',
    ),
    (
      name: 'reads older flat lists without including the next release',
      asset: '# 4.6.0\n- First\n- Second\n\n# 4.5.0\n- Older\n',
      content: '- First\n- Second\n\n',
    ),
    (
      name: 'stops at the next release even without a separating blank line',
      asset: '# 4.6.0\n- First\n# 4.5.0\n- Older\n',
      content: '- First\n',
    ),
    (
      name: 'reads the final release through the end of the file',
      asset: '# 4.6.0\n\n## Changes\n\n- First',
      content: '\n## Changes\n\n- First\n',
    ),
  ];
  for (final c in cases) {
    test(c.name, () async {
      asset = c.asset;

      final data = await repository.loadLatestChangelog();

      expect(data.content, c.content);
      expect(data.version.toString(), '4.6.0');
    });
  }

  test('retains previous release metadata and persists seen state', () async {
    asset = '# 4.6.0\n\n## Changes\n\n- First\n';
    await box.put(kPreviousVersionKey, 'changelog_4.5.0_seen');

    final data = await repository.loadLatestChangelog();

    expect(data.previousVersion.toString(), '4.5.0');
    expect(await repository.shouldShowChangelog(data.version), isTrue);
    await repository.markChangelogAsSeen(data.version);
    expect(await repository.shouldShowChangelog(data.version), isFalse);

    await box.close();
    box = await Hive.openBox<String>('changelog', path: directory.path);
    repository = ChangelogRepositoryImpl(HivePersistentCacheStore(box));
    expect(await repository.shouldShowChangelog(data.version), isFalse);
    expect(
      (await repository.loadLatestChangelog()).previousVersion.toString(),
      '4.6.0',
    );
  });
}
