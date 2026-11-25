import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/following_topics/following_topic_test_utils.dart';

void main() {
  final layout = ViewerToolbarLayout(
    toolbar: const [ViewerToolbarAction.favorite],
  );

  test(
    'older profile records and global trial layouts use native defaults',
    () {
      final viewer = ViewerConfigs.undefined();
      expect(ViewerConfigs.fromJson(viewer.toJson()).toolbarLayout, isNull);
      expect(
        ViewerConfigs.fromJson({
          ...viewer.toJson(),
          'toolbarLayout': const {'version': 999},
        }).toolbarLayout,
        isNull,
      );
      final settings = Settings.fromJson({
        ...Settings.defaultSettings.toJson(),
        'viewerToolbarLayout': layout.toJson(),
      });
      expect(settings.toJson(), isNot(contains('viewerToolbarLayout')));
    },
  );

  test('viewer layout round trips with image overrides disabled', () {
    final viewer = ViewerConfigs.undefined().copyWith(
      toolbarLayout: () => layout,
    );
    final profile = testProfile.copyWith(viewerConfigs: () => viewer);
    final restored = BooruConfig.fromJson(profile.toJson()).viewerConfigs!;
    expect(restored, viewer);
    expect(restored.enable, isFalse);
    expect(restored.toolbarLayout, layout);
    expect(restored.copyWith(enable: true).toolbarLayout, layout);
    expect(restored.copyWith(toolbarLayout: () => null).toolbarLayout, isNull);
  });

  test('editing visible actions retains the hidden action and its section', () {
    final saved = ViewerToolbarLayout(
      toolbar: const [
        ViewerToolbarAction.upvote,
        ViewerToolbarAction.bookmark,
      ],
      more: const [ViewerToolbarAction.share],
    );
    final available = {ViewerToolbarAction.bookmark, ViewerToolbarAction.share};
    final visible = saved.availableOnly(available);
    final changed = visible.move(
      ViewerToolbarAction.share,
      toToolbar: true,
      index: 0,
    );
    final merged = saved.withAvailableOrder(changed, available);
    expect(merged.toolbar, [
      ViewerToolbarAction.upvote,
      ViewerToolbarAction.share,
      ViewerToolbarAction.bookmark,
    ]);
    expect(merged.availableOnly(available), changed);
  });
}
