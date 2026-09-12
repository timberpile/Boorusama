// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:mocktail/mocktail.dart';

// Project imports:
import 'package:boorusama/core/posts/details_parts/src/common_post_buttons.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/widgets/adaptive_button_row.dart';

class _MockPost extends Mock implements Post {}

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  testWidgets(
    'omits View original while offering in-place loading when automatic loading is disabled',
    (tester) async {
      final buttons = await _buildButtons(
        tester,
        loadOriginalOnZoom: false,
      );

      expect(
        buttons.map((button) => button.title),
        contains('Load original'),
      );
      expect(
        buttons.map((button) => button.title),
        isNot(contains('View original')),
      );
    },
  );

  testWidgets(
    'omits both original-image actions when automatic loading is enabled',
    (tester) async {
      final buttons = await _buildButtons(
        tester,
        loadOriginalOnZoom: true,
      );

      final titles = buttons.map((button) => button.title);
      expect(titles, isNot(contains('Load original')));
      expect(titles, isNot(contains('View original')));
    },
  );
}

Future<List<ButtonData>> _buildButtons(
  WidgetTester tester, {
  required bool loadOriginalOnZoom,
}) async {
  final post = _MockPost();
  when(() => post.originalImageUrl).thenReturn('https://example.com/full.jpg');
  when(() => post.isVideo).thenReturn(false);

  List<ButtonData>? buttons;
  final viewerSettings = Settings.defaultSettings.viewer.copyWith(
    loadOriginalOnZoom: loadOriginalOnZoom,
  );

  await tester.pumpWidget(
    BooruLocalization(
      child: ProviderScope(
        overrides: [
          imageViewerSettingsProvider.overrideWithValue(viewerSettings),
          showPremiumFeatsProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: CommonPostButtonsBuilder(
            post: post,
            onStartSlideshow: () {},
            onLoadOriginal: () {},
            config: null,
            configViewer: null,
            builder: (_, value) {
              buttons = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return buttons!;
}
