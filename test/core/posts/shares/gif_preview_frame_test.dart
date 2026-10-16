import 'package:boorusama/core/posts/shares/src/gif_editor_selection.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_preview_frame.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (width, height, rotation, sar, ratio) in [
    (1152, 720, 0, 1.0, 1.6),
    (720, 1152, 0, 1.0, .625),
    (720, 720, 0, 1.0, 1.0),
    (1152, 720, 90, 1.0, .625),
    (720, 576, 0, 16 / 15, 4 / 3),
    (720, 576, 270, 16 / 15, .75),
  ]) {
    testWidgets(
      'preview fits display dimensions $width/$height rotation=$rotation sar=$sar',
      (tester) async {
        final selection = GifEditorSelection.initial(
          GifSourceMetadata(
            width: width,
            height: height,
            rotationDegrees: rotation,
            sampleAspectRatio: sar,
            duration: const Duration(seconds: 1),
            complete: true,
            frameRate: 30,
          ),
          'video/mp4',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: Column(
                  children: [
                    GifPreviewFrame(
                      aspectRatio: selection.displayAspectRatio,
                      maxHeight: 200,
                      child: const ColoredBox(
                        key: ValueKey('media'),
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final size = tester.getSize(find.byKey(const ValueKey('media')));
        expect(size.width / size.height, closeTo(ratio, .00001));
        expect(size.width, lessThanOrEqualTo(360));
        expect(size.height, lessThanOrEqualTo(200));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
