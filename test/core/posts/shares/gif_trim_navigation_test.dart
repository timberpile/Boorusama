import 'package:boorusama/core/posts/shares/src/gif_trim_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens a long source at a useful scale without changing trim', () {
    final navigation = GifTrimNavigation(const Duration(minutes: 2));
    navigation.initialize(Duration.zero, const Duration(minutes: 2));
    expect(navigation.visibleDuration.inSeconds, 8);
    navigation.browse(const Duration(seconds: 43));
    expect(navigation.visibleStart.inSeconds, 39);
    expect(navigation.visibleEnd.inSeconds, 47);
    expect(navigation.sourceMode, isTrue);
    navigation.dispose();
  });

  test('focus fits a short selection to half the available width', () {
    final navigation = GifTrimNavigation(const Duration(minutes: 5));
    navigation.focus(
      const Duration(seconds: 120),
      const Duration(seconds: 122),
    );
    expect(navigation.visibleStart, const Duration(seconds: 119));
    expect(navigation.visibleDuration, const Duration(seconds: 4));
    navigation.dispose();
  });

  test('focusing and panning clamp the view at both source boundaries', () {
    final navigation = GifTrimNavigation(const Duration(seconds: 120));
    navigation.focus(Duration.zero, const Duration(seconds: 1));
    expect(navigation.visibleStart, Duration.zero);
    navigation.pan(-1);
    expect(navigation.visibleStart, Duration.zero);
    navigation.focus(
      const Duration(seconds: 119),
      const Duration(seconds: 120),
    );
    expect(navigation.visibleEnd, const Duration(seconds: 120));
    navigation.pan(1);
    expect(navigation.visibleEnd, const Duration(seconds: 120));
    navigation.dispose();
  });

  test('zoom does not require a gesture and retains its focal timestamp', () {
    final navigation = GifTrimNavigation(const Duration(minutes: 2));
    navigation.initialize(Duration.zero, const Duration(minutes: 2));
    navigation.browse(const Duration(seconds: 43));
    navigation.zoom(2, const Duration(seconds: 43));
    expect(navigation.visibleDuration, const Duration(seconds: 4));
    expect(navigation.visibleStart, const Duration(seconds: 41));
    navigation.setPreviewSpeed(.25);
    expect(navigation.previewSpeed, .25);
    navigation.dispose();
  });
}
