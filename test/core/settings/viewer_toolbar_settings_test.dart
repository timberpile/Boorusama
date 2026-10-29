import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy settings keep native engine order and omit the optional key', () {
    final settings = Settings.fromJson(Settings.defaultSettings.toJson());
    expect(settings.viewerToolbarLayout, isNull);
    expect(settings.toJson().containsKey('viewerToolbarLayout'), isFalse);
  });

  test('layout round trips through settings used by backup and restore', () {
    final layout = ViewerToolbarLayout.editorDefault();
    final custom = Settings.defaultSettings.copyWith(
      viewerToolbarLayout: () => layout,
    );
    expect(Settings.fromJson(custom.toJson()).viewerToolbarLayout, layout);
    expect(custom.copyWith(showBookmarkCount: true).viewerToolbarLayout, layout);
    expect(custom, isNot(Settings.defaultSettings));
  });

  test('reset clears only the global toolbar override', () {
    final custom = Settings.defaultSettings.copyWith(
      viewerToolbarLayout: ViewerToolbarLayout.editorDefault,
      showBookmarkCount: true,
    );
    final reset = custom.copyWith(viewerToolbarLayout: () => null);
    expect(reset.viewerToolbarLayout, isNull);
    expect(reset.showBookmarkCount, isTrue);
    expect(reset.toJson().containsKey('viewerToolbarLayout'), isFalse);
  });

  test('invalid toolbar data does not reject an otherwise valid backup', () {
    final json = Settings.defaultSettings.toJson()
      ..['viewerToolbarLayout'] = {'version': 999};
    expect(Settings.fromJson(json).viewerToolbarLayout, isNull);
  });

  test('profile-specific viewer serialization cannot shadow global layout', () {
    final profile = ViewerConfigs(
      settings: Settings.defaultSettings.viewer,
      enable: true,
    );
    expect(profile.settings.toJson().containsKey('viewerToolbarLayout'), isFalse);
    expect(profile.toJson().containsKey('viewerToolbarLayout'), isFalse);
  });
}
