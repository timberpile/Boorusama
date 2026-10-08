import 'dart:async';

import 'package:boorusama/core/posts/shares/src/gif_background_execution.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boorusama/gif_background');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> nativeCancel(int job) async {
    final done = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall('cancel', job)),
      (_) => done.complete(),
    );
    await done.future;
  }

  test(
    'notification Cancel targets its own conversion and stop removes the service',
    () async {
      final background = GifBackgroundExecution(
        title: 'GIF wird erstellt',
        cancelLabel: 'Abbrechen',
      );
      final token = CancelToken();
      await background.start(token);
      final args = calls.single.arguments as Map;
      final job = args['job'] as int;
      expect(args['title'], 'GIF wird erstellt');
      expect(args['cancelLabel'], 'Abbrechen');
      await nativeCancel(job - 1);
      expect(token.isCancelled, isFalse);
      await nativeCancel(job);
      expect(token.isCancelled, isTrue);
      await background.stop();
      expect(calls.last.method, 'stop');
      expect(calls.last.arguments, job);
    },
  );

  test('late notification actions cannot cancel a later conversion', () async {
    final background = GifBackgroundExecution(
      title: 'Creating GIF',
      cancelLabel: 'Cancel',
    );
    final first = CancelToken();
    await background.start(first);
    final oldJob = (calls.single.arguments as Map)['job'] as int;
    await background.stop();
    final second = CancelToken();
    await background.start(second);
    await nativeCancel(oldJob);
    expect(first.isCancelled, isFalse);
    expect(second.isCancelled, isFalse);
    await background.stop();
  });

  test('failed service startup is typed and still permits cleanup', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'start') {
        throw PlatformException(code: 'gif_background_failed');
      }
      return null;
    });
    final background = GifBackgroundExecution(
      title: 'Creating GIF',
      cancelLabel: 'Cancel',
    );
    await expectLater(
      background.start(CancelToken()),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.encoderUnavailable,
        ),
      ),
    );
    await background.stop();
    expect(calls.last.method, 'stop');
  });
}
