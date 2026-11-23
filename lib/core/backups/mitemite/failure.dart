import 'dart:io';

import 'package:flutter/services.dart';

import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../../search/following_topics/src/types/following_mirror_state.dart';
import 'activity_log.dart';
import 'bookmark_mirror_engine.dart' show SyncRevisionUnavailable;
import 'identity_file.dart';
import 'protocol.dart';

/// Typed local diagnostics, never raw provider messages or transport content.
SyncFailureKind syncFailureKind(Object error) => switch (error) {
  SyncPublisherUnavailable() => SyncFailureKind.unavailable,
  SyncOwnIdentityUnavailable() => SyncFailureKind.identityFile,
  SyncInvalidSignature() => SyncFailureKind.invalidSignature,
  SyncReplayRejected() => SyncFailureKind.rollback,
  SyncUpdateRequired() => SyncFailureKind.unsupported,
  SyncTrustRequired() => SyncFailureKind.identityChanged,
  SyncRevisionUnavailable() => SyncFailureKind.missingRevision,
  SyncConflict() ||
  BookmarkMirrorReadOnly() ||
  FollowingMirrorReadOnly() ||
  FollowingMirrorConflict() => SyncFailureKind.conflict,
  PlatformException(code: 'sync_folder_access_required') =>
    SyncFailureKind.permission,
  PlatformException(code: 'sync_storage_failed') => SyncFailureKind.retryableIo,
  FileSystemException() => SyncFailureKind.unavailable,
  FormatException() => SyncFailureKind.invalidData,
  _ => SyncFailureKind.unknown,
};
