// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

void main() {
  final translations = Translations();

  for (final testCase in [
    (key: 'bookmark.groups.add_to', expected: 'Add to Shared'),
    (key: 'bookmark.groups.remove_from', expected: 'Remove from Shared'),
  ]) {
    test('formats ${testCase.expected} without exposing identity details', () {
      final translation = translations[testCase.key] as dynamic;

      expect(translation(name: 'Shared'), testCase.expected);
    });
  }
}
