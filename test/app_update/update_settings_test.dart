// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/settings/src/types/settings.dart';

void main() {
  test('automatic update checks default to enabled for existing settings', () {
    final oldJson = Settings.defaultSettings.toJson()
      ..remove('automaticUpdateChecks');
    expect(Settings.fromJson(oldJson).automaticUpdateChecks, isTrue);
  });

  test('automatic update check preference survives serialization', () {
    final disabled = Settings.defaultSettings.copyWith(
      automaticUpdateChecks: false,
    );
    expect(disabled.toJson()['automaticUpdateChecks'], isFalse);
    expect(Settings.fromJson(disabled.toJson()).automaticUpdateChecks, isFalse);
  });
}
