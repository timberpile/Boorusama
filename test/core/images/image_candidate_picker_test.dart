import 'dart:ui' as ui;

import 'package:boorusama/core/images/image_candidate_picker.dart';
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
  late List<_Candidate> candidates;

  setUp(() {
    candidates = List.generate(5, (index) => _Candidate(index));
  });
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  Widget app({int? preferred, ValueChanged<int?>? onSelected}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: ImageCandidatePicker(
          candidates: [for (final candidate in candidates) candidate.create],
          preferredIndex: preferred,
          onSelected: onSelected ?? (_) {},
          placeholder: const Text('Thumbnail'),
          builder: (provider) =>
              Text('Selected ${(provider as _Candidate).id}'),
        ),
      );

  testWidgets('starts both JPEG probes and chooses a decoded image', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(candidates.map((candidate) => candidate.loads), [1, 1, 0, 0, 0]);
    expect(find.text('Thumbnail'), findsOneWidget);
    final image = decoded.clone();
    candidates[1].stream.complete(image);
    await tester.pump();
    expect(find.text('Selected 1'), findsOneWidget);
    expect(candidates[0].cancelled, isTrue);
    expect(candidates[1].cancelled, isFalse);
    await tester.pump(const Duration(seconds: 10));
    expect(candidates.skip(2).map((candidate) => candidate.loads), [0, 0, 0]);
  });

  testWidgets('waits for the deadline before probing secondary formats', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(
      imageCandidatePrimaryWindow - const Duration(milliseconds: 1),
    );
    expect(candidates.skip(2).map((candidate) => candidate.loads), [0, 0, 0]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(candidates.map((candidate) => candidate.loads), [1, 1, 1, 1, 1]);
    // An initially slow JPEG can still win once the other formats have started.
    candidates[0].stream.complete(decoded.clone());
    await tester.pump();
    expect(find.text('Selected 0'), findsOneWidget);
    expect(
      candidates.skip(1).every((candidate) => candidate.cancelled),
      isTrue,
    );
  });

  testWidgets('decode failures start the next formats without waiting', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    candidates[0].stream.fail();
    expect(candidates[2].loads, 0);
    candidates[1].stream.fail();
    await tester.pump();
    expect(candidates.skip(2).map((candidate) => candidate.loads), [1, 1, 1]);
    candidates[2].stream.complete(decoded.clone());
    await tester.pump();
    expect(find.text('Selected 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a remembered successful format avoids repeated probes', (
    tester,
  ) async {
    await tester.pumpWidget(app(preferred: 3));
    expect(candidates.map((candidate) => candidate.loads), [0, 0, 0, 1, 0]);
    candidates[3].stream.complete(decoded.clone());
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Selected 3'), findsOneWidget);
    expect(candidates.map((candidate) => candidate.loads), [0, 0, 0, 1, 0]);
  });

  testWidgets('a failed remembered format resumes the normal probe order', (
    tester,
  ) async {
    await tester.pumpWidget(app(preferred: 3));
    candidates[3].stream.fail();
    await tester.pump();
    expect(candidates.map((candidate) => candidate.loads), [1, 1, 0, 1, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the final deadline cancels stalled probes and retains the thumbnail',
    (tester) async {
      final selections = <int?>[];
      await tester.pumpWidget(app(onSelected: selections.add));
      await tester.pump(imageCandidatePrimaryWindow);
      await tester.pump(imageCandidateFinalWindow);
      expect(find.text('Thumbnail'), findsOneWidget);
      expect(selections, [null]);
      expect(candidates.every((candidate) => candidate.cancelled), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposing cancels owned requests and prevents later phases', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(
      candidates.take(2).every((candidate) => candidate.cancelled),
      isTrue,
    );
    expect(candidates.skip(2).map((candidate) => candidate.loads), [0, 0, 0]);
    candidates[0].stream.fail();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _Candidate extends ImageProvider<_Candidate> {
  _Candidate(this.id);
  final int id;
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
  void fail() => reportError(
    exception: StateError('Image decoding failed'),
    stack: StackTrace.current,
    silent: true,
  );
}
