import 'package:boorusama/core/backups/mitemite/providers.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  const cases = <String?, bool>{
    null: false,
    'null': false,
    '[]': false,
    '"text"': false,
    '7': false,
    'true': false,
    '{': false,
    '{}': false,
    '{"location":null}': false,
    '{"location":7}': false,
    '{"location":"/synthetic-sync"}': true,
  };
  for (final entry in cases.entries) {
    test('activation handles stored shape ${entry.key}', () {
      final preferences = _Preferences(entry.key);
      final container = ProviderContainer(
        overrides: [
          miscDataStoreProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(miteMiteActivationProvider), entry.value);
      expect(preferences.value, entry.key);
      expect(preferences.writes, 0);
      expect(container.exists(miteMiteServiceProvider), isFalse);
    });
  }

  testWidgets('malformed optional sync settings do not hide the application', (
    tester,
  ) async {
    final preferences = _Preferences('[]');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [miscDataStoreProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: MiteMiteLifecycle(child: Text('Application remains available')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Application remains available'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
    expect(preferences.value, '[]');
    expect(preferences.writes, 0);
  });
}

class _Preferences implements MiscDataStore {
  _Preferences(this.value);
  String? value;
  var writes = 0;
  @override
  String? get(String key) => key == 'mitemite.v1.settings' ? value : null;
  @override
  Future<void> put(String key, String value) async {
    writes++;
    this.value = value;
  }
}
