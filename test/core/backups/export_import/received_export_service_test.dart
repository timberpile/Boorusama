// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/platform/received_export_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('received_export_');
  });

  tearDown(() => directory.delete(recursive: true));

  test('emits a private copy before deleting the transient source', () async {
    final source = File('${directory.path}/transient/input')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3, 4]);
    final platform = _FakeReceivedExportPlatform(
      pending: [
        {
          'id': 'cold-id',
          'path': source.path,
          'displayName': 'shared.bsexport',
        },
      ],
    );
    final service = ReceivedExportService(
      platform: platform,
      stagingDirectoryPath: '${directory.path}/private',
    );

    final received = await service.exports.first;

    expect(received.displayName, 'shared.bsexport');
    expect(received.path, isNot(source.path));
    expect(received.path, startsWith('${directory.path}/private/'));
    expect(await File(received.path).readAsBytes(), [1, 2, 3, 4]);
    expect(source.existsSync(), isFalse);
  });

  test('deduplicates the same export across cold and warm delivery', () async {
    final first = File('${directory.path}/transient/first')
      ..createSync(recursive: true)
      ..writeAsStringSync('first');
    final duplicate = File('${directory.path}/transient/duplicate')
      ..createSync(recursive: true)
      ..writeAsStringSync('duplicate');
    final second = File('${directory.path}/transient/second')
      ..createSync(recursive: true)
      ..writeAsStringSync('second');
    final platform = _FakeReceivedExportPlatform(
      pending: [
        {'id': 'same-id', 'path': first.path},
      ],
      live: Stream.fromIterable([
        {'id': 'same-id', 'path': duplicate.path},
        {'id': 'new-id', 'path': second.path},
      ]),
    );
    final service = ReceivedExportService(
      platform: platform,
      stagingDirectoryPath: '${directory.path}/private',
    );

    final received = await service.exports.take(2).toList();

    expect(received.map((export) => export.id), ['same-id', 'new-id']);
    expect(
      await Future.wait(
        received.map((export) => File(export.path).readAsString()),
      ),
      ['first', 'second'],
    );
    expect(duplicate.existsSync(), isFalse);
  });
}

class _FakeReceivedExportPlatform implements ReceivedExportPlatform {
  _FakeReceivedExportPlatform({
    this.pending = const [],
    this.live = const Stream.empty(),
  });

  final List<Object?> pending;
  final Stream<Object?> live;

  @override
  Stream<Object?> get exportEvents => live;

  @override
  Future<List<Object?>> takePendingExports() async => pending;
}
