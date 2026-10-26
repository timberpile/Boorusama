import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/settings/types.dart';

void main() {
  test('obsolete active group is ignored when importing old settings', () {
    final json = Settings.defaultSettings.toJson()
      ..['activeBookmarkGroupId'] = '550e8400-e29b-41d4-a716-446655440000';
    final restored = Settings.fromJson(json);
    expect(restored, Settings.defaultSettings);
    expect(restored.toJson(), isNot(contains('activeBookmarkGroupId')));
  });
}
