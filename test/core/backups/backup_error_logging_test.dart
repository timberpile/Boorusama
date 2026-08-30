import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:boorusama/core/backups/utils/backup_error_logging.dart';

void main() {
  test('formats the complete backup error and stack trace', () {
    final message = formatBackupError(
      operation: 'clipboard export',
      error: StateError('clipboard transaction failed'),
      stackTrace: StackTrace.fromString('#0 Clipboard.setData'),
    );

    expect(
      message,
      allOf(
        contains('[Backup] clipboard export failed'),
        contains('clipboard transaction failed'),
        contains('#0 Clipboard.setData'),
      ),
    );
  });

  test('recognizes Android clipboard transaction size failures', () {
    final error = PlatformException(
      code: 'clipboard',
      message: 'android.os.TransactionTooLargeException: data parcel size',
    );

    expect(isClipboardTransactionTooLarge(error), isTrue);
    expect(
      isClipboardTransactionTooLarge(StateError('other failure')),
      isFalse,
    );
  });

  test('recognizes backup payloads that exceed the clipboard size limit', () {
    expect(
      isClipboardBackupTooLarge(
        'x' * (maxClipboardBackupBytes + 1),
      ),
      isTrue,
    );
    expect(isClipboardBackupTooLarge('small backup'), isFalse);
  });
}
