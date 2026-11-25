import 'package:boorusama/core/local_media/local_media_library.dart';
import 'package:boorusama/core/local_media/local_media_providers.dart';
import 'package:boorusama/core/local_media/local_media_reference.dart';
import 'package:boorusama/core/local_media/local_media_storage_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'storage adds thumbnail usage and Clear All requires confirmation',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 480)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final library = _StorageLibrary();
      final android = _ThumbnailStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localMediaLibraryProvider.overrideWith((_) => library),
            localMediaAndroidProvider.overrideWithValue(android),
          ],
          child: const BooruLocalization(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: LocalMediaStorageSection()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(Filesize.parse(5120)), findsOneWidget);

      final clear = find.text('Clear All');
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.text('Clear All Local Media?'), findsOneWidget);
      expect(
        find.textContaining('permanently deletes every file'),
        findsOneWidget,
      );
      expect(library.items, 1);
      final cancel = find.text('Cancel');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel.hitTestable());
      await tester.pumpAndSettle();
      expect(library.items, 1);
      expect(android.bytes, 1024);

      await tester.tap(clear);
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(KurumiDialog),
        matching: clear,
      );
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm.hitTestable());
      await tester.pumpAndSettle();
      expect(library.items, 0);
      expect(android.bytes, 0);
      expect(find.text(Filesize.parse(1024)), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Clear All'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _StorageLibrary implements LocalMediaLibrary {
  var items = 1;

  @override
  Stream<LocalMediaReference> get changes => const Stream.empty();

  @override
  Future<({int bytes, int items})> storageUsage() =>
      Future.value((bytes: items == 0 ? 1024 : 4096, items: items));

  @override
  Future<void> clear() {
    items = 0;
    return Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThumbnailStorage extends LocalMediaAndroid {
  var bytes = 1024;

  @override
  Future<int> thumbnailBytes() => Future.value(bytes);

  @override
  Future<void> clearThumbnails() {
    bytes = 0;
    return Future.value();
  }
}
