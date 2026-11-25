import '../../bookmarks/types.dart';
import '../../local_media/local_media_reference.dart';

const kRemoteBookmarksBackupVersion = 6;
const kBookmarksBackupVersion = 7;

bool isNestedBookmarkBackup(int? version) =>
    version == kRemoteBookmarksBackupVersion ||
    version == kBookmarksBackupVersion;

int bookmarkTransferVersion(Iterable<Bookmark> records) =>
    records.any(
      (record) =>
          record is PostBookmark && record.post.booruData is LocalMediaPostData,
    )
    ? kBookmarksBackupVersion
    : kRemoteBookmarksBackupVersion;
