import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'package:boorusama/core/backups/sources/json_source.dart';
import 'package:boorusama/core/backups/utils/json_handler.dart';

final _sourceProvider = Provider<_TestSource>(_TestSource.new);
final _invalidRoundTripSourceProvider = Provider<_InvalidRoundTripSource>(
  _InvalidRoundTripSource.new,
);

void main() {
  test(
    'revision snapshots stay stable when exported metadata changes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = container.read(_sourceProvider);

      final first = await source.encodeRevisionSnapshot();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final second = await source.encodeRevisionSnapshot();

      expect(second, first);
    },
  );

  test(
    'rollback validation rejects data that cannot be imported again',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = container.read(_invalidRoundTripSourceProvider);

      await expectLater(
        source.validateEncodedImport(await source.encodeForExport()),
        throwsFormatException,
      );
    },
  );
}

class _TestSource extends JsonBackupSource<Map<String, dynamic>> {
  _TestSource(Ref ref)
    : super(
        id: 'test',
        priority: 0,
        version: 1,
        appVersion: null,
        dataGetter: () async => const {'value': 1},
        executor: (_, _) async {},
        handler: SingleHandler(
          parser: (json) => json,
          encoder: (json) => json,
        ),
        ref: ref,
      );

  @override
  String get displayName => 'Test';

  @override
  Widget buildTile(BuildContext context) => const SizedBox.shrink();
}

class _InvalidRoundTripSource extends JsonBackupSource<int> {
  _InvalidRoundTripSource(Ref ref)
    : super(
        id: 'invalid',
        priority: 0,
        version: 1,
        appVersion: null,
        dataGetter: () async => 1,
        executor: (_, _) async {},
        handler: SingleHandler(
          parser: (json) {
            if (json['value'] is! int) {
              throw const FormatException('Missing value');
            }
            return json['value'] as int;
          },
          encoder: (value) => {'other': value},
        ),
        ref: ref,
      );

  @override
  String get displayName => 'Invalid';

  @override
  Widget buildTile(BuildContext context) => const SizedBox.shrink();
}
