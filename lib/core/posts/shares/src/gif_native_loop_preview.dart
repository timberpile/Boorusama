import 'dart:io';

import 'package:media_kit/media_kit.dart';

import 'gif_loop_preview_controller.dart';

class NativeGifLoopPreview implements GifLoopPreviewBackend {
  const NativeGifLoopPreview(this.player, this.path);
  final Player player;
  final String path;

  @override
  Duration get position => player.state.position;

  @override
  Future<void> open() async {
    await player.setVolume(0);
    // Native EOF repetition also covers a selection ending at source duration.
    await player.setPlaylistMode(PlaylistMode.single);
    await player.open(Media(File(path).uri.toString()), play: false);
    // open() submits loading in media_kit 1.2.6; it does not await file-loaded.
    // Wait for metadata before seeking, otherwise the initial seek can be lost.
    if (player.state.duration <= Duration.zero) {
      await player.stream.duration
          .firstWhere((duration) => duration > Duration.zero)
          .timeout(const Duration(seconds: 10));
    }
  }

  @override
  Future<void> setRange(Duration start, Duration end) async {
    if (player.platform is! NativePlayer) {
      throw UnsupportedError('Native GIF preview required');
    }
    // This Android-only adapter uses the documented libmpv escape hatch. The
    // web stub does not expose setProperty; keep that platform outside the call.
    await _setProperty('ab-loop-b', 'no');
    await _setProperty(
      'ab-loop-a',
      (start.inMicroseconds / 1000000).toStringAsFixed(6),
    );
    await _setProperty(
      'ab-loop-b',
      (end.inMicroseconds / 1000000).toStringAsFixed(6),
    );
    await _setProperty('ab-loop-count', 'inf');
  }

  Future<void> _setProperty(String name, String value) async {
    final dynamic native = player.platform;
    await native.setProperty(name, value);
    // media_kit 1.2.6 ignores mpv_set_property_string's return code. A rejected
    // loop configuration must make the preview unavailable, not play outside it.
    final actual = await native.getProperty(name) as String;
    if (actual != value &&
        (double.tryParse(actual) == null ||
            double.tryParse(actual) != double.tryParse(value))) {
      throw StateError('Native GIF loop property was not applied: $name');
    }
  }

  @override
  Future<void> setSpeed(double speed) => player.setRate(speed);
  @override
  Future<void> seek(Duration position) async {
    // Keep source-frame boundaries precise; do not quantize to milliseconds.
    final dynamic native = player.platform;
    await native.command([
      'seek',
      (position.inMicroseconds / 1000000).toStringAsFixed(6),
      'absolute+exact',
    ]);
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> close() => player.dispose();
}
