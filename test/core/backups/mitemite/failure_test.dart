import 'dart:io';

import 'package:boorusama/core/backups/mitemite/activity_log.dart';
import 'package:boorusama/core/backups/mitemite/bookmark_mirror_engine.dart';
import 'package:boorusama/core/backups/mitemite/failure.dart';
import 'package:boorusama/core/backups/mitemite/identity_file.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (error, expected) in <(Object, SyncFailureKind)>[
    (const SyncOwnIdentityUnavailable(), SyncFailureKind.identityFile),
    (const SyncInvalidSignature(), SyncFailureKind.invalidSignature),
    (const SyncReplayRejected(), SyncFailureKind.rollback),
    (const SyncUpdateRequired(), SyncFailureKind.unsupported),
    (const SyncTrustRequired(), SyncFailureKind.identityChanged),
    (const SyncRevisionUnavailable(), SyncFailureKind.missingRevision),
    (const SyncConflict(), SyncFailureKind.conflict),
    (
      PlatformException(code: 'sync_folder_access_required'),
      SyncFailureKind.permission,
    ),
    (
      PlatformException(code: 'sync_storage_failed'),
      SyncFailureKind.retryableIo,
    ),
    (
      const FileSystemException('private URI and credentials'),
      SyncFailureKind.unavailable,
    ),
    (const FormatException('private content'), SyncFailureKind.invalidData),
    (StateError('private diagnostic'), SyncFailureKind.unknown),
  ]) {
    test(
      'classifies ${error.runtimeType} as ${expected.name} without persisting its raw details',
      () {
        final classified = syncFailureKind(error);
        expect(classified, expected);
        final event = SyncEvent(
          kind: SyncEventKind.failed,
          at: DateTime.utc(2026),
          failure: classified,
        );
        expect(SyncEvent.fromJson(event.toJson()), event);
        expect(event.toJson().toString(), isNot(contains('private')));
      },
    );
  }
}
