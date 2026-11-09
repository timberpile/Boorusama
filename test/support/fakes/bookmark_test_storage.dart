import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/loggers/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

/// Real Hive payload/index files for existing fixture scenarios. Close these
/// alongside the fixture's Post box before a restart or deleting its directory.
final class BookmarkTestStorage {
  BookmarkTestStorage._(
    this.groupPayloadBox,
    this.metadataBox,
    this.coordinator,
  );

  static Future<BookmarkTestStorage> open(
    Box<BookmarkHiveObject> posts, {
    DataMutationCoordinator? coordinator,
  }) async => BookmarkTestStorage._(
    await Hive.openBox<dynamic>('${posts.name}_unified_payloads'),
    await Hive.openBox<dynamic>('${posts.name}_unified_metadata'),
    coordinator ?? DataMutationCoordinator(),
  );

  final Box<dynamic> groupPayloadBox;
  final Box<dynamic> metadataBox;
  final DataMutationCoordinator coordinator;

  List<Override> get overrides => [
    dataMutationCoordinatorProvider.overrideWithValue(coordinator),
  ];

  BookmarkHiveRepository repository(
    Box<BookmarkHiveObject> posts, {
    BooruPostDataCodec? Function(BooruType type)? postDataCodec,
    GroupMetadataCodec groupMetadataCodec = const GroupMetadataCodec(),
    Logger? logger,
    Future<void> Function(Iterable<BoxBase<dynamic>> boxes)? syncBoxes,
  }) => BookmarkHiveRepository(
    posts,
    groupPayloadBox: groupPayloadBox,
    metadataBox: metadataBox,
    coordinator: coordinator,
    postDataCodec: postDataCodec,
    groupMetadataCodec: groupMetadataCodec,
    logger: logger,
    syncBoxes: syncBoxes,
  );

  Future<void> close() async {
    await groupPayloadBox.close();
    await metadataBox.close();
  }
}
