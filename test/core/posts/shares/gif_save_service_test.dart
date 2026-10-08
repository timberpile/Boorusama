import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/shares/src/gif_save_service.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FileSystem extends Mock implements AppFileSystem {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boorusama/gif_save');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final (profile, global, expected) in [
    (
      '/storage/emulated/0/Pictures/profile',
      '/storage/emulated/0/Download/global',
      '/storage/emulated/0/Pictures/profile',
    ),
    (
      null,
      '/storage/emulated/0/Download/global',
      '/storage/emulated/0/Download/global',
    ),
    (
      '',
      '/storage/emulated/0/Download/global',
      '/storage/emulated/0/Download/global',
    ),
    (null, null, '/storage/emulated/0/Download'),
  ]) {
    test(
      'Save uses normal download folder precedence: profile=$profile global=$global',
      () async {
        final fs = _FileSystem();
        when(
          fs.getDownloadPath,
        ).thenAnswer((_) async => '/storage/emulated/0/Download');
        final container = ProviderContainer(
          overrides: [
            appFileSystemProvider.overrideWithValue(fs),
            currentReadOnlyBooruConfigDownloadProvider.overrideWithValue(
              BooruConfigDownload(
                fileNameFormat: null,
                bulkFileNameFormat: null,
                location: profile,
              ),
            ),
            settingsProvider.overrideWithValue(
              Settings.defaultSettings.copyWith(downloadPath: global),
            ),
          ],
        );
        addTearDown(container.dispose);
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'saveToDirectory');
          expect(call.arguments, {
            'source': '/cache/boorusama_share_result.gif',
            'name': 'boorusama_42.gif',
            'directory': expected,
          });
          return true;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        expect(
          await container
              .read(gifSaveServiceProvider)
              .save('/cache/boorusama_share_result.gif', 'boorusama_42.gif'),
          isTrue,
        );
      },
    );
  }
}
