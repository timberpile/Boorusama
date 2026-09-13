// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Flutter test imports:
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';

// Project imports:
import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_viewer_auto_comic_strip.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_viewer_transformation_scope.dart';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('de-DE');
  });

  testWidgets(
    'positions a detected comic strip only on its first settled load',
    (
      tester,
    ) async {
      final transformationController = TransformationController();
      final settledPage = ValueNotifier<int?>(null);
      addTearDown(transformationController.dispose);
      addTearDown(settledPage.dispose);
      var startedCount = 0;

      await _pumpAutoStarter(
        tester,
        transformationController: transformationController,
        settledPage: settledPage,
        onStarted: () => startedCount++,
      );

      settledPage.value = 0;
      await tester.pump();

      expect(
        transformationController.value.getMaxScaleOnAxis(),
        closeTo(3.2, 0.001),
      );
      expect(
        transformationController.value.getTranslation().y,
        closeTo(0, 0.001),
      );
      expect(startedCount, 1);

      transformationController.value = Matrix4.identity();
      settledPage.value = 1;
      await tester.pump();
      settledPage.value = 0;
      await tester.pump();

      expect(transformationController.value, Matrix4.identity());
      expect(startedCount, 1);
    },
  );

  testWidgets('shows the compact centered comic-strip reading hint', (
    tester,
  ) async {
    final transformationController = TransformationController();
    final settledPage = ValueNotifier<int?>(null);
    addTearDown(transformationController.dispose);
    addTearDown(settledPage.dispose);

    await _pumpAutoStarter(
      tester,
      transformationController: transformationController,
      settledPage: settledPage,
    );

    settledPage.value = 0;
    await tester.pump();
    await tester.pump();

    final title = tester.widget<Text>(find.text('Comic-Strip'));
    final hint = tester.widget<Text>(find.text('Nach unten ↓'));
    expect(title.textAlign, TextAlign.center);
    expect(hint.textAlign, TextAlign.center);
    expect(
      tester.getCenter(find.text('Comic-Strip')).dy,
      greaterThan(400),
    );

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('ignores an activation queued for a page no longer settled', (
    tester,
  ) async {
    final transformationController = TransformationController();
    final settledPage = _ChangingSettledPage();
    addTearDown(transformationController.dispose);
    var startedCount = 0;

    await _pumpAutoStarter(
      tester,
      transformationController: transformationController,
      settledPage: settledPage,
      onStarted: () => startedCount++,
    );

    expect(transformationController.value, Matrix4.identity());
    expect(startedCount, 0);
  });

  testWidgets('a neighboring image cannot constrain the settled comic strip', (
    tester,
  ) async {
    final transformationController = TransformationController();
    final settledPage = ValueNotifier<int?>(null);
    addTearDown(transformationController.dispose);
    addTearDown(settledPage.dispose);

    await tester.pumpWidget(
      OKToast(
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 500,
              child: PostViewerTransformationScope(
                controller: PostViewerTransformationController(
                  transformationController,
                ),
                child: PostViewerTransformationViewport(
                  child: PostViewerAutoComicStrip(
                    index: 0,
                    postId: 42,
                    contentSize: const Size(1000, 4000.25),
                    currentSettledPage: settledPage,
                    enabled: true,
                    onStarted: () {},
                    child: Stack(
                      children: [
                        _ConstrainedViewer(
                          index: 0,
                          contentSize: const Size(1000, 4000.25),
                          controller: transformationController,
                          settledPage: settledPage,
                        ),
                        _ConstrainedViewer(
                          index: 1,
                          contentSize: const Size(1000, 500),
                          controller: transformationController,
                          settledPage: settledPage,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    settledPage.value = 0;
    await tester.pump();

    expect(
      transformationController.value.getTranslation().y,
      closeTo(0, 0.001),
    );
  });
}

class _ConstrainedViewer extends StatelessWidget {
  const _ConstrainedViewer({
    required this.index,
    required this.contentSize,
    required this.controller,
    required this.settledPage,
  });

  final int index;
  final Size contentSize;
  final TransformationController controller;
  final ValueNotifier<int?> settledPage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: settledPage,
      builder: (context, settledPage, child) => KurumiInteractiveViewer(
        contentSize: contentSize,
        controller: controller,
        constrainPanToContent: settledPage == index,
        child: child!,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ChangingSettledPage implements ValueListenable<int?> {
  var _reads = 0;

  @override
  int? get value => _reads++ == 0 ? 0 : 1;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

Future<void> _pumpAutoStarter(
  WidgetTester tester, {
  required TransformationController transformationController,
  required ValueListenable<int?> settledPage,
  VoidCallback? onStarted,
}) {
  final controller = PostViewerTransformationController(
    transformationController,
  );

  return tester.pumpWidget(
    BooruLocalization(
      child: OKToast(
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 500,
              child: PostViewerTransformationScope(
                controller: controller,
                child: PostViewerTransformationViewport(
                  child: PostViewerAutoComicStrip(
                    index: 0,
                    postId: 42,
                    contentSize: const Size(1000, 4000.25),
                    currentSettledPage: settledPage,
                    enabled: true,
                    onStarted: onStarted,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
