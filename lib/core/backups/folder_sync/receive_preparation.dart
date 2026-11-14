import '../../../foundation/filesystem.dart';
import '../sources/bookmark_backup_codec.dart';
import 'bookmark_package.dart';
import 'catalog.dart';
import 'catalog_gate.dart';
import 'protocol.dart';
import 'revision_transport.dart';
import 'storage.dart';

/// Prepared outside the shared mutation lock. Apply MUST recheck [catalog]
/// through SyncCatalogGate.withCurrentCatalog and journal domain ownership and
/// last-applied state together. This object cannot remove any local data.
final class PreparedSyncBookmarkRevision {
  const PreparedSyncBookmarkRevision._(
    this.catalog,
    this.revision,
    this.package,
  );
  final VerifiedSyncCatalog catalog;
  final SyncRevision revision;
  final ValidatedSyncBookmarkPackage package;
}

final class SyncReceivePreparation {
  const SyncReceivePreparation({
    required this.storage,
    required this.fs,
    required this.codec,
  });
  final FolderSyncStorage storage;
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;

  Future<PreparedSyncBookmarkRevision?> prepare({
    required VerifiedSyncCatalog catalog,
    required SyncCollectionId collection,
    required List<int> publisherKey,
    int maxPreparedBytes = 64 * 1024 * 1024,
  }) async {
    final key = List<int>.unmodifiable(publisherKey);
    if (collection.publisher != catalog.publisher ||
        syncDigest(key) != catalog.fingerprint) {
      throw const FormatException('Publisher does not match approved catalog');
    }
    final metadata = SyncCatalog.fromJson(catalog.content);
    final entry = metadata.entries
        .where((entry) => entry.id == collection)
        .firstOrNull;
    if (entry == null || entry.state != SyncPublicationState.active) {
      // Neither missing advertisements nor source-deleted policy authorize
      // destructive work. Withdrawal belongs to a separately reviewed path.
      throw const FormatException('No active advertised sync collection');
    }
    final expected = entry.revision!;
    if (collection.kind != 'bookmarks' ||
        expected.schema != ValidatedSyncBookmarkPackage.schema) {
      throw const SyncUpdateRequired();
    }
    final transported = await SyncRevisionTransport(storage)
        .read(expected: expected, publisherKey: key);
    if (transported == null) return null;
    final package =
        await SyncBookmarkPackageValidator(
          fs: fs,
          codec: codec,
        ).validate(
          collection: collection,
          bytes: transported.bytes,
          maxPreparedBytes: maxPreparedBytes,
        );
    if (package.semanticHash != expected.semanticHash) {
      throw const FormatException(
        'Sync semantic content does not match descriptor',
      );
    }
    return PreparedSyncBookmarkRevision._(catalog, expected, package);
  }
}
