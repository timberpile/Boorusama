import 'dart:io';

import 'package:boorusama/core/backups/auto/repo_io.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'auto_backup_repository_',
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('retention finds legacy ZIP and current export packages only', () {
    File('${directory.path}/legacy.zip').writeAsStringSync('legacy');
    File('${directory.path}/current.bsexport').writeAsStringSync('current');
    File('${directory.path}/notes.json').writeAsStringSync('unrelated');

    final files = const AutoBackupRepositoryIo(
      IoFileSystem(),
    ).listBackupFiles(directory.path);

    expect(files, containsAll(<String>['legacy.zip', 'current.bsexport']));
    expect(files, isNot(contains('notes.json')));
  });
}
