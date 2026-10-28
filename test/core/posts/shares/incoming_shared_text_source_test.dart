import 'dart:async';

import 'package:boorusama/core/posts/shares/src/incoming_shared_text_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_handler/share_handler.dart';

class _Plugin extends ShareHandlerPlatform {
  _Plugin(this.events);
  SharedMedia? initial;
  final StreamController<SharedMedia> events;
  @override
  Future<SharedMedia?> getInitialSharedMedia() async => initial;
  @override
  Future<void> resetInitialSharedMedia() async => initial = null;
  @override
  Stream<SharedMedia> get sharedMediaStream => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = PluginIncomingSharedTextSource();
  const pixivText =
      'QA artwork | QA artist #pixiv https://www.pixiv.net/en/artworks/151301916';

  test(
    'plugin content survives initial and warm delivery without URL rewriting',
    () async {
      final previous = ShareHandlerPlatform.instance;
      final events = StreamController<SharedMedia>();
      final plugin = _Plugin(events)..initial = SharedMedia(content: pixivText);
      ShareHandlerPlatform.instance = plugin;
      addTearDown(() {
        ShareHandlerPlatform.instance = previous;
      });
      addTearDown(events.close);
      expect(await source.initialText(), pixivText);
      expect(await source.initialText(), isNull);
      final texts = <String>[];
      final subscription = source.texts.listen(texts.add);
      plugin.events.add(SharedMedia());
      plugin.events.add(SharedMedia(content: pixivText));
      await events.close();
      expect(texts, [pixivText]);
      await subscription.cancel();
    },
  );

  test(
    'native delivery is resumed and paused through the existing activity',
    () async {
      const channel = MethodChannel(
        'com.timberpile.boorusama/shared_text_delivery',
      );
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await source.resumeWarmDelivery();
      await source.pauseWarmDelivery();
      expect(calls, ['resume', 'pause']);
    },
  );
}
