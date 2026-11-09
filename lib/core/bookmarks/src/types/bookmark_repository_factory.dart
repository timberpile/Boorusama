// Project imports:
import 'bookmark_repository.dart';
import '../../../boorus/booru/types.dart';
import '../../../posts/post/types.dart';
import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../backups/folder_sync/mirror_guard.dart';
import '../../../content/types.dart';

final class BookmarkStorageContext {
  const BookmarkStorageContext({
    required this.coordinator,
    this.groupMetadataCodec = const GroupMetadataCodec(),
    this.mirrorGuard,
  });

  final DataMutationCoordinator coordinator;
  final GroupMetadataCodec groupMetadataCodec;
  final CollectionMirrorGuard? mirrorGuard;
}

abstract interface class BookmarkRepositoryFactory {
  Future<BookmarkRepository> create({
    BooruPostDataCodec? Function(BooruType type)? postDataCodec,
    BookmarkStorageContext? storage,
  });

  Future<void> dispose(BookmarkRepository repository);
}
