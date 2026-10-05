import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  final cases = [
    (status: ShareResultStatus.success, outcome: ShareActionOutcome.success),
    (
      status: ShareResultStatus.dismissed,
      outcome: ShareActionOutcome.dismissed,
    ),
    (
      status: ShareResultStatus.unavailable,
      outcome: ShareActionOutcome.unavailable,
    ),
  ];

  for (final testCase in cases) {
    test('link sharing reports ${testCase.status}', () async {
      final adapter = ShareActionAdapter((params) async {
        expect(params.uri, Uri.parse('https://site.test/posts/42'));
        expect(params.files, isNull);
        return ShareResult('', testCase.status);
      });

      expect(
        await adapter.shareLink(Uri.parse('https://site.test/posts/42')),
        testCase.outcome,
      );
    });

    test('media sharing reports ${testCase.status}', () async {
      final adapter = ShareActionAdapter((params) async {
        expect(params.files?.single.path, '/tmp/share-test.png');
        expect(params.files?.single.mimeType, 'image/png');
        expect(params.uri, isNull);
        return ShareResult('', testCase.status);
      });

      expect(
        await adapter.shareMedia('/tmp/share-test.png', 'image/png'),
        testCase.outcome,
      );
    });
  }

  test('unsupported file sharing reports a platform outcome', () async {
    final adapter = ShareActionAdapter(
      (_) => Future.error(UnimplementedError('Sharing files not supported')),
    );

    expect(
      await adapter.shareMedia('/tmp/share-test.png', 'image/png'),
      ShareActionOutcome.unsupported,
    );
  });

  test('plain text sharing sends text without a URI or file', () async {
    final adapter = ShareActionAdapter((params) async {
      expect(params.text, '42');
      expect(params.uri, isNull);
      expect(params.files, isNull);
      return const ShareResult('', ShareResultStatus.success);
    });

    expect(await adapter.shareText('42'), ShareActionOutcome.success);
  });
}
