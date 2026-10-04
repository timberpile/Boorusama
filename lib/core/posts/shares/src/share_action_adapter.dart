// ignore_for_file: avoid_catching_errors
import 'package:share_plus/share_plus.dart';

enum ShareActionOutcome { success, dismissed, unavailable, unsupported }

typedef ShareInvoker = Future<ShareResult> Function(ShareParams params);

final class ShareActionAdapter {
  const ShareActionAdapter(this._invoke);

  final ShareInvoker _invoke;

  Future<ShareActionOutcome> shareText(String text) =>
      _share(ShareParams(text: text));

  Future<ShareActionOutcome> shareLink(Uri uri) =>
      _share(ShareParams(uri: uri));

  Future<ShareActionOutcome> shareMedia(String path, String mimeType) =>
      _share(ShareParams(files: [XFile(path, mimeType: mimeType)]));

  Future<ShareActionOutcome> _share(ShareParams params) async {
    try {
      final result = await _invoke(params);
      return switch (result.status) {
        ShareResultStatus.success => ShareActionOutcome.success,
        ShareResultStatus.dismissed => ShareActionOutcome.dismissed,
        ShareResultStatus.unavailable => ShareActionOutcome.unavailable,
      };
    } on UnimplementedError {
      return ShareActionOutcome.unsupported;
    }
  }
}
