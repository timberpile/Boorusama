import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_handler/share_handler.dart';

/// The single Android share listener owns both the initial and warm deliveries.
abstract interface class IncomingSharedTextSource {
  Future<String?> initialText();
  Stream<String> get texts;
  Future<void> resumeWarmDelivery();
  Future<void> pauseWarmDelivery();
}

final incomingSharedTextSourceProvider = Provider<IncomingSharedTextSource>(
  (_) => const PluginIncomingSharedTextSource(),
);

final class PluginIncomingSharedTextSource implements IncomingSharedTextSource {
  const PluginIncomingSharedTextSource();

  static const _delivery = MethodChannel(
    'com.timberpile.boorusama/shared_text_delivery',
  );

  @override
  Future<String?> initialText() async {
    final media = await ShareHandler.instance.getInitialSharedMedia();
    // The plugin retains this value across receiver remounts until consumed.
    if (media != null) await ShareHandler.instance.resetInitialSharedMedia();
    return media?.content;
  }

  @override
  Future<void> resumeWarmDelivery() => _delivery.invokeMethod<void>('resume');

  @override
  Future<void> pauseWarmDelivery() => _delivery.invokeMethod<void>('pause');

  @override
  Stream<String> get texts => ShareHandler.instance.sharedMediaStream
      .map((media) => media.content)
      .where((text) => text != null)
      .cast<String>();
}
