import 'dart:io';

import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file_share.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'boorusama_link_file_test.dart' show postUri;

class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('bslink-share-'),
  );
  tearDown(() => root.delete(recursive: true));

  test(
    'one standalone document remains readable after handoff returns',
    () async {
      var calls = 0;
      XFile? received;
      final service = BoorusamaLinkFileShare(
        fs: _FileSystem(root.path),
        adapter: ShareActionAdapter((params) async {
          calls++;
          expect(params.files, hasLength(1));
          expect(params.uri, isNull);
          expect(params.text, 'Open in Boorusama');
          received = params.files!.single;
          expect(received!.name, 'boorusama-post-42.bslink');
          expect(received!.mimeType, BoorusamaLinkFile.mimeType);
          expect(
            BoorusamaLinkFile.decode(await received!.readAsBytes()).uri,
            Uri.parse(postUri),
          );
          return const ShareResult('', ShareResultStatus.success);
        }),
      );
      expect(
        await service.share(
          BoorusamaLinkFile.fromUri(postUri),
          text: 'Open in Boorusama',
        ),
        ShareActionOutcome.success,
      );
      expect(calls, 1);
      expect(await received!.length(), greaterThan(0));
    },
  );

  test('cancellation before handoff never invokes the receiving app', () async {
    var calls = 0;
    final service = BoorusamaLinkFileShare(
      fs: _FileSystem(root.path),
      adapter: ShareActionAdapter((params) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      }),
    );
    await expectLater(
      service.share(
        BoorusamaLinkFile.fromUri(postUri),
        beforeHandoff: () => throw const FormatException('Cancelled'),
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });

  test('sharing twice keeps independent readable files', () async {
    final paths = <String>[];
    final service = BoorusamaLinkFileShare(
      fs: _FileSystem(root.path),
      adapter: ShareActionAdapter((params) async {
        paths.add(params.files!.single.path);
        return const ShareResult('', ShareResultStatus.success);
      }),
    );
    await service.share(BoorusamaLinkFile.fromUri(postUri));
    await service.share(BoorusamaLinkFile.fromUri(postUri));
    expect(paths.toSet(), hasLength(2));
    expect(paths.every((path) => File(path).existsSync()), isTrue);
  });
}
