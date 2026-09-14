// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/settings/types.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';

  test('active bookmark group defaults to No Group', () {
    final json = Settings.defaultSettings.toJson()
      ..remove('activeBookmarkGroupId');
    expect(Settings.fromJson(json).activeBookmarkGroupId, isNull);
  });

  test('active bookmark group round trips and can be cleared', () {
    final grouped = Settings.defaultSettings.copyWith(
      activeBookmarkGroupId: groupId,
    );
    expect(Settings.fromJson(grouped.toJson()).activeBookmarkGroupId, groupId);
    expect(
      grouped.copyWith(activeBookmarkGroupId: null).activeBookmarkGroupId,
      isNull,
    );
  });
}
