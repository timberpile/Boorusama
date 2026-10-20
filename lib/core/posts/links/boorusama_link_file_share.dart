import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../foundation/filesystem.dart';
import '../shares/src/share_action_adapter.dart';
import 'boorusama_link_file.dart';

/// A link is sent as one document. Mixed image/document shares can silently
/// lose the document in receiving apps, so previews are deliberately excluded.
/// Retain each handoff for 24 hours; success does not imply the file was read.
class BoorusamaLinkFileShare {
  const BoorusamaLinkFileShare({required this.fs, required this.adapter});

  final AppFileSystem fs;
  final ShareActionAdapter adapter;
  static final _active = <String>{};

  Future<ShareActionOutcome> share(
    BoorusamaLinkFile document, {
    String? text,
    Rect? sharePositionOrigin,
    void Function()? beforeHandoff,
  }) async {
    final root = await fs.getTemporaryPath();
    if (root == null) {
      throw const FormatException('Temporary storage unavailable');
    }
    final directory = p.join(root, 'boorusama-link-shares');
    await fs.createDirectory(directory, recursive: true);
    await _prune(directory);
    final delivery = p.join(directory, const Uuid().v4());
    _active.add(delivery);
    try {
      await fs.createDirectory(delivery);
      final path = p.join(delivery, document.fileName);
      await fs.writeBytes(path, document.encode());
      beforeHandoff?.call();
      return await adapter.shareFiles(
        [XFile(path, mimeType: BoorusamaLinkFile.mimeType)],
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      // Do not unlink here: the recipient may still be consuming this URI.
      _active.remove(delivery);
    }
  }

  Future<void> _prune(String directory) async {
    // Cleanup is best effort and must not prevent a new share.
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      for (final entry in await fs.listDirectory(
        directory,
        followLinks: false,
      )) {
        if (!entry.isDirectory ||
            _active.contains(entry.path) ||
            !RegExp(r'^[0-9a-f-]{36}$').hasMatch(p.basename(entry.path))) {
          continue;
        }
        if ((await fs.lastModified(entry.path)).isBefore(cutoff)) {
          await fs.deleteDirectory(entry.path, recursive: true);
        }
      }
    } on Exception {
      // Temporary files can already have been removed by the operating system.
    }
  }
}
