// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/foundation.dart';

const maxClipboardBackupBytes = 512 * 1024;

bool isClipboardBackupTooLarge(String data) =>
    utf8.encode(data).length > maxClipboardBackupBytes;

bool isClipboardTransactionTooLarge(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('transactiontoolargeexception') ||
      message.contains('failed binder transaction') ||
      message.contains('data parcel size');
}

String formatBackupError({
  required String operation,
  required Object error,
  required StackTrace stackTrace,
}) => '[Backup] $operation failed: $error\nStack trace:\n$stackTrace';

void logBackupError({
  required String operation,
  required Object error,
  required StackTrace stackTrace,
}) {
  if (!kDebugMode) return;

  debugPrintSynchronously(
    formatBackupError(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
    ),
  );
}
