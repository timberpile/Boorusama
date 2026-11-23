import 'dart:async';

import 'package:boorusama/core/developer_options/zoom_study.dart';
import 'package:boorusama/core/posts/details/src/widgets/zoom_study_overlay.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  for (final exporting in [false, true]) {
    for (final fails in [false, true]) {
      testWidgets(
        '${exporting ? 'export' : 'record'} completion after disposal (failure: $fails)',
        (tester) async {
          final recorder = _Recorder();
          final controller = TransformationController();
          addTearDown(controller.dispose);
          await _pumpOverlay(tester, recorder, controller);

          await tester.tap(
            find.byIcon(
              exporting
                  ? Icons.file_download_outlined
                  : Icons.bookmark_add_outlined,
            ),
          );
          await tester.pump();
          expect(recorder.calls, 1);
          await tester.pumpWidget(const SizedBox.shrink());
          if (fails) {
            recorder.completed.completeError(StateError('write failed'));
          } else {
            recorder.completed.complete();
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets('controls fit narrow width with large text and keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final recorder = _Recorder();
    final controller = TransformationController();
    addTearDown(controller.dispose);
    await _pumpOverlay(tester, recorder, controller);
    expect(
      find.byIcon(Icons.bookmark_add_outlined).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byIcon(Icons.file_download_outlined).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOverlay(
  WidgetTester tester,
  _Recorder recorder,
  TransformationController controller,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      zoomStudyRecorderProvider.overrideWithValue(recorder),
      imageViewerSettingsProvider.overrideWithValue(
        Settings.defaultSettings.viewer,
      ),
    ],
    child: BooruLocalization(
      child: MaterialApp(
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 250),
            ),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: ZoomStudyOverlay(
              post: TestPost(id: 1),
              controller: controller,
            ),
          ),
        ),
      ),
    ),
  ),
);

class _Recorder extends ZoomStudyRecorder {
  final completed = Completer<void>();
  var calls = 0;

  @override
  Future<int> record(Map<String, Object?> observation) async {
    calls++;
    await completed.future;
    return 1;
  }

  @override
  Future<String> export() async {
    calls++;
    await completed.future;
    return '/Download/zoom.json';
  }
}
