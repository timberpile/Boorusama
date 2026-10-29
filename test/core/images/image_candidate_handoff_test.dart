import 'dart:ui' as ui;

import 'package:boorusama/core/images/image_candidate_picker.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image decoded;
  setUpAll(() async {
    decoded = await createTestImage(cache: false);
  });
  tearDownAll(() => decoded.dispose());
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'the renderer can pause the winning stream without another probe',
    (
      tester,
    ) async {
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      final candidate = _Candidate();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, active, child) => TickerMode(
                enabled: active,
                child: child!,
              ),
              child: ImageCandidatePicker(
                candidates: [candidate.create],
                placeholder: const SizedBox(width: 1, height: 1),
                onSelected: (_) {},
                builder: (provider) => ExtendedImage(
                  image: provider,
                  width: 1,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      );
      candidate.stream.complete(decoded.clone());
      await tester.pump();
      expect(find.byType(ExtendedImage), findsOneWidget);
      expect(candidate.stream.hasListeners, isTrue);
      expect(candidate.loads, 1);
      expect(candidate.cancelled, isFalse);

      enabled.value = false;
      await tester.pump();
      expect(
        candidate.stream.hasListeners,
        isFalse,
        reason: 'The probe must not keep a muted renderer decoding frames.',
      );
      expect(candidate.cancelled, isFalse);

      enabled.value = true;
      await tester.pump();
      expect(candidate.stream.hasListeners, isTrue);
      expect(candidate.loads, 1);
      expect(candidate.cancelled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(candidate.cancelled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Candidate extends ImageProvider<_Candidate> {
  final stream = _Stream();
  var loads = 0;
  var cancelled = false;

  ImageCandidate create() => ImageCandidate(
    image: this,
    cancel: () => cancelled = true,
  );

  @override
  Future<_Candidate> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Candidate key, ImageDecoderCallback decode) {
    loads++;
    return stream;
  }
}

class _Stream extends ImageStreamCompleter {
  void complete(ui.Image image) => setImage(ImageInfo(image: image));
}
