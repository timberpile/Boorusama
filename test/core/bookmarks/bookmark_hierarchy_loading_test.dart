import 'package:boorusama/core/settings/providers.dart';
import 'package:selection_mode/selection_mode.dart';

import 'dart:async';

import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'an initially open Group waits safely for its library and handles load failure',
    (tester) async {
      final ready = Completer<BookmarkLibraryState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectionOptionsProvider.overrideWithValue(
              const SelectionOptions(
                behavior: SelectionBehavior.manual,
                dragSelection: DragSelectionOptions(),
                haptics: null,
              ),
            ),
            bookmarkProvider.overrideWith(() => _PendingLibrary(ready.future)),
            miscDataStoreProvider.overrideWith((ref) => _Store()),
          ],
          child: BooruLocalization(
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
              home: const BookmarkGroupBrowserPage(
                groupId: '11111111-1111-4111-8111-111111111111',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Bookmark Groups'), findsOneWidget);
      final more = tester.widget<KurumiPopupMenuButton>(
        find.byType(KurumiPopupMenuButton),
      );
      expect(more.enabled, isFalse);
      expect(tester.takeException(), isNull);
      ready.completeError(StateError('Fixture load failure'));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PendingLibrary extends BookmarkLibraryNotifier {
  _PendingLibrary(this.ready);
  final Future<BookmarkLibraryState> ready;
  @override
  Future<BookmarkLibraryState> build() => ready;
}

class _Store implements MiscDataStore {
  @override
  String? get(String key) => null;
  @override
  Future<void> put(String key, String value) async {}
}
