// ignore_for_file: avoid_slow_async_io
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> cleanupExpiredPlatformShareCopies(String rootPath) async {
  final directory = Directory(p.join(rootPath, 'share_plus'));
  if (!await directory.exists()) return;
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  await for (final entry in directory.list(followLinks: false)) {
    if (entry is File &&
        p.basename(entry.path).startsWith('boorusama_share_') &&
        (await entry.lastModified()).isBefore(cutoff)) {
      await entry.delete();
    }
  }
}
