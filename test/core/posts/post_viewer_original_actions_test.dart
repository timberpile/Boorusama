// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:mocktail/mocktail.dart';

// Project imports:
import 'package:boorusama/core/posts/details_parts/src/common_post_buttons.dart';
import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_viewer_transformation_scope.dart';
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

  testWidgets(
    'offers temporary viewer transformations only in the overflow menu',
    (tester) async {
      final buttons = await _buildButtons(
        tester,
        loadOriginalOnZoom: true,
        includeViewerTransformations: true,
      );

      const expectedTitles = [
        'Fit to width',
        'Scroll to top',
        'Comic-strip start',
      ];
      for (final title in expectedTitles) {
        final button = buttons.singleWhere((button) => button.title == title);
        expect(button.placement, ButtonPlacement.menuOnly);
      }
    },
  );

  testWidgets(
    'omits temporary viewer transformations outside the post viewer',
    (tester) async {
      final buttons = await _buildButtons(
        tester,
        loadOriginalOnZoom: true,
      );

      final titles = buttons.map((button) => button.title);
      expect(titles, isNot(contains('Fit to width')));
      expect(titles, isNot(contains('Scroll to top')));
      expect(titles, isNot(contains('Comic-strip start')));
    },
  );
}

Future<List<ButtonData>> _buildButtons(
  WidgetTester tester, {
  required bool loadOriginalOnZoom,
  bool includeViewerTransformations = false,
}) async {
  final post = _MockPost();
  when(() => post.originalImageUrl).thenReturn('https://example.com/full.jpg');
  when(() => post.isVideo).thenReturn(false);
  when(() => post.width).thenReturn(1000);
  when(() => post.height).thenReturn(4000);

  List<ButtonData>? buttons;
  final viewerSettings = Settings.defaultSettings.viewer.copyWith(
    loadOriginalOnZoom: loadOriginalOnZoom,
  );
  final transformationController = includeViewerTransformations
      ? TransformationController()
      : null;
  if (transformationController != null) {
    addTearDown(transformationController.dispose);
  }

  await tester.pumpWidget(
    BooruLocalization(
      child: ProviderScope(
        overrides: [
          imageViewerSettingsProvider.overrideWithValue(viewerSettings),
          showPremiumFeatsProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final buttonsBuilder = CommonPostButtonsBuilder(
                post: post,
                onStartSlideshow: () {},
                onLoadOriginal: () {},
                config: null,
                configViewer: null,
                builder: (_, value) {
                  buttons = value;
                  return const SizedBox.shrink();
                },
              );

              if (!includeViewerTransformations) return buttonsBuilder;

              return PostViewerTransformationScope(
                controller: PostViewerTransformationController(
                  transformationController!,
                )..viewportSize = const Size(400, 800),
                child: buttonsBuilder,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return buttons!;
}
