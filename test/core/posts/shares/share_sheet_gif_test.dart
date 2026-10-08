// ignore_for_file: avoid_slow_async_io
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_save_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_ffmpeg_runner.dart';
import 'package:boorusama/core/posts/shares/src/gif_output_inspection.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, MethodChannel;
import 'package:i18n/src/gen/strings.g.dart'
    show TranslationProvider, AppLocale, LocaleSettings;
import 'package:image/image.dart' as image;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:share_plus/share_plus.dart';

import '../../../bulk_downloads/common.dart';

class _FileSystem extends Mock implements AppFileSystem {}

class _Cache extends Mock implements ImageCacheManager {}

const _auth = BooruConfigAuth(
  booruId: 1,
  booruIdHint: 1,
  url: 'https://site.test',
  apiKey: null,
  login: null,
  passHash: null,
  proxySettings: null,
  networkSettings: null,
);
const _viewer = BooruConfigViewer(
  imageDetaisQuality: null,
  videoQuality: null,
  viewerNotesFetchBehavior: null,
  settings: null,
);

void main() {
  const backgroundChannel = MethodChannel('boorusama/gif_background');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, null);
  });
  testWidgets('GIF action is absent for images and unsupported platforms', (
    tester,
  ) async {
    await _open(tester, post: dummyPost(), backend: _Encoder());
    expect(find.byKey(const ValueKey('create-gif')), findsNothing);
    await _open(tester, post: _video, backend: null);
    expect(find.byKey(const ValueKey('create-gif')), findsNothing);
  });

  for (final locale in [AppLocale.enUs, AppLocale.deDe]) {
    testWidgets(
      'GIF matches the Video row with a single generate action (${locale.languageCode})',
      (tester) async {
        await tester.runAsync(() => LocaleSettings.setLocale(locale));
        addTearDown(() => LocaleSettings.setLocale(AppLocale.enUs));
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final root = await tester.runAsync(
          () => Directory.systemTemp.createTemp('gif-payload-row-'),
        );
        addTearDown(() => root!.delete(recursive: true));
        await _open(
          tester,
          post: _video,
          root: root,
          backend: _Encoder(),
          textScale: 2,
        );
        final gif = find.byKey(const ValueKey('gif-share-payload'));
        final video = find.byKey(const ValueKey(SharePayloadId.video));
        expect(
          find.descendant(of: gif, matching: find.text('GIF')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: gif,
            matching: find.byIcon(Icons.gif_box_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: gif, matching: find.byIcon(Icons.auto_fix_high)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: gif, matching: find.byType(IconButton)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: video, matching: find.byType(IconButton)),
          findsNWidgets(2),
        );
        final gifMaterial = tester.widget<Material>(
          find.descendant(of: gif, matching: find.byType(Material)).first,
        );
        final videoMaterial = tester.widget<Material>(
          find.descendant(of: video, matching: find.byType(Material)).first,
        );
        expect(gifMaterial.color, videoMaterial.color);
        expect(gifMaterial.borderRadius, videoMaterial.borderRadius);
        expect(tester.getRect(gif).width, tester.getRect(video).width);
        expect(tester.getRect(gif).top, greaterThan(tester.getRect(video).top));
        final generate = find.byKey(const ValueKey('create-gif'));
        expect(
          tester.getRect(generate).right,
          tester
              .getRect(
                find
                    .descendant(of: video, matching: find.byType(IconButton))
                    .last,
              )
              .right,
        );
        expect(generate.hitTestable(), findsOneWidget);
        expect(
          tester.widget<IconButton>(generate).tooltip,
          locale == AppLocale.enUs ? 'Create GIF' : 'GIF erstellen',
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => tester.tap(generate));
        await _driveUntil(
          tester,
          () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
        );
        await tester.runAsync(() => tester.pageBack());
        await tester.pumpAndSettle();
        await _driveUntil(
          tester,
          () => Directory('${root!.path}/boorusama-share').listSync().isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('GIF creation shares the output once and cleans temporary files', (
    tester,
  ) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('gif-sheet-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    final files = <String>[];
    final encoder = _Encoder();
    await _open(
      tester,
      post: _video,
      backend: encoder,
      root: root,
      adapter: ShareActionAdapter((params) async {
        expect(params.files!.single.mimeType, 'image/gif');
        files.add(params.files!.single.path);
        expect(await File(files.single).exists(), isTrue);
        return const ShareResult('', ShareResultStatus.success);
      }),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('create-gif')));
    });
    await _driveUntil(
      tester,
      () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
    );
    expect(encoder.calls, 0);
    await tester.runAsync(
      () => tester.tap(find.byKey(const ValueKey('gif-convert'))),
    );
    await _driveUntil(
      tester,
      () => find.byKey(const ValueKey('gif-share')).evaluate().isNotEmpty,
    );
    await tester.runAsync(
      () => tester.tap(find.byKey(const ValueKey('gif-share'))),
    );
    await _driveUntil(tester, () => files.isNotEmpty);
    await tester.runAsync(() async {
      await tester.pageBack();
    });
    await tester.pumpAndSettle();
    await _driveUntil(
      tester,
      () =>
          tester
              .widget<IconButton>(find.byKey(const ValueKey('create-gif')))
              .onPressed !=
          null,
    );
    await _driveUntil(
      tester,
      () => Directory('${root!.path}/boorusama-share').listSync().isEmpty,
    );
    expect(encoder.calls, 1);
    expect(files, hasLength(1));
    expect(encoder.calls, 1);
    expect(
      find.text(
        'Could not create a GIF from this video. You can still share the video.',
      ),
      findsNothing,
    );
    expect(
      await tester.runAsync(
        () => Directory('${root!.path}/boorusama-share').list().toList(),
      ),
      isEmpty,
    );
    expect(find.byTooltip('Share video'), findsOneWidget);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      '1280 by 720 offers a selectable Original at narrow width and $textScale text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = await tester.runAsync(
          () => Directory.systemTemp.createTemp('gif-original-choice-'),
        );
        addTearDown(() => root!.delete(recursive: true));
        await _open(
          tester,
          post: _video,
          root: root,
          backend: _Encoder(width: 1280, height: 720),
          textScale: textScale,
        );
        await tester.runAsync(
          () => tester.tap(find.byKey(const ValueKey('create-gif'))),
        );
        await _driveUntil(
          tester,
          () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('gif-size-original')),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        final original = find.byKey(const ValueKey('gif-size-original'));
        final smaller = find.byKey(const ValueKey('gif-size-720'));
        expect(original.hitTestable(), findsOneWidget);
        expect(smaller, findsOneWidget);
        expect(
          tester.getTopLeft(original).dy,
          greaterThanOrEqualTo(tester.getTopLeft(smaller).dy),
        );
        expect(find.text('480 × 270 px'), findsOneWidget);
        await tester.tap(original);
        await tester.pump();
        expect(tester.widget<ChoiceChip>(original).selected, isTrue);
        expect(find.text('1280 × 720 px'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => tester.pageBack());
        await tester.pumpAndSettle();
        await _driveUntil(
          tester,
          () => Directory('${root!.path}/boorusama-share').listSync().isEmpty,
        );
      },
    );
  }

  testWidgets(
    'estimated size warns only above 20 MB and updates without blocking conversion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('gif-size-warning-'),
      );
      addTearDown(() => root!.delete(recursive: true));
      await _open(
        tester,
        post: _video,
        root: root,
        backend: _Encoder(
          width: 500,
          height: 500,
          duration: const Duration(seconds: 20),
        ),
        textScale: 2,
      );
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('create-gif'))),
      );
      await _driveUntil(
        tester,
        () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('gif-size-original')),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final original = find.byKey(const ValueKey('gif-size-original'));
      expect(original.hitTestable(), findsOneWidget);
      await tester.tap(original);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(original).selected, isTrue);
      expect(find.text('500 × 500 px'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('gif-source-fps')),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      final fps = tester.widget<Slider>(
        find.byKey(const ValueKey('gif-source-fps')),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      for (final (index, warns) in [(7.0, false), (8.0, true), (6.0, false)]) {
        fps.onChanged!(index);
        await tester.pump();
        final estimate = tester.widget<Text>(
          find.byKey(const ValueKey('gif-estimated-size')),
        );
        final warning = find.byIcon(Icons.warning_amber_rounded);
        expect(warning, warns ? findsOneWidget : findsNothing);
        expect(estimate.style?.color, warns ? Colors.amber : null);
        if (warns) {
          expect(tester.widget<Icon>(warning).color, Colors.amber);
          final trailing = (estimate.textSpan! as TextSpan).children!.last;
          expect(trailing, isA<WidgetSpan>());
        }
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('gif-convert')))
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .getRect(find.byKey(const ValueKey('gif-estimated-size')))
              .right,
          lessThanOrEqualTo(320),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.runAsync(() => tester.pageBack());
      await tester.pumpAndSettle();
      await _driveUntil(
        tester,
        () => Directory('${root!.path}/boorusama-share').listSync().isEmpty,
      );
    },
  );

  for (final locale in [AppLocale.enUs, AppLocale.deDe]) {
    testWidgets(
      'trim and settings work at narrow width with enlarged text and keyboard inset (${locale.languageCode})',
      (tester) async {
        await tester.runAsync(() => LocaleSettings.setLocale(locale));
        addTearDown(() => LocaleSettings.setLocale(AppLocale.enUs));
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = await tester.runAsync(
          () => Directory.systemTemp.createTemp('gif-edit-controls-'),
        );
        addTearDown(() => root!.delete(recursive: true));
        final encoder = _Encoder(
          duration: const Duration(seconds: 9),
          width: 960,
          height: 32,
        );
        await _open(
          tester,
          post: _video,
          root: root,
          backend: encoder,
          textScale: 2,
        );
        await tester.runAsync(
          () => tester.tap(find.byKey(const ValueKey('create-gif'))),
        );
        await _driveUntil(
          tester,
          () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text(locale == AppLocale.enUs ? 'Create GIF' : 'GIF erstellen'),
          findsWidgets,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.text('width & height'), findsNothing);
        final pinnedPreview = tester.getRect(
          find.byKey(const ValueKey('gif-preview')),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('gif-trim-window')),
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        expect(find.text('0.0 s → 9.0 s'), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('gif-trim-1')),
          const Offset(-70, 0),
        );
        await tester.pump();
        await tester.drag(
          find.byKey(const ValueKey('gif-trim-window')),
          const Offset(50, 0),
        );
        await tester.pump();
        expect(find.text('0.0 s → 6.0 s'), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('gif-size-480')),
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(const ValueKey('gif-size-480')))
              .selected,
          isTrue,
        );
        expect(find.byKey(const ValueKey('gif-size-360')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('gif-size-480')));
        await tester.pump();
        expect(find.text('480 × 16 px'), findsOneWidget);
        expect(
          find.text('Frames per source second; speed is separate.'),
          findsNothing,
        );
        expect(find.text('Preview the result before sharing.'), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('gif-source-fps')),
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        final fps = tester.widget<Slider>(
          find.byKey(const ValueKey('gif-source-fps')),
        );
        fps.onChanged!(5);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('gif-speed')),
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        expect(
          tester.getRect(find.byKey(const ValueKey('gif-preview'))),
          pinnedPreview,
        );
        final speed = tester.widget<Slider>(
          find.byKey(const ValueKey('gif-speed')),
        );
        expect(speed.divisions, lessThanOrEqualTo(7));
        speed.onChanged!(1);
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        expect(
          tester.getRect(find.byKey(const ValueKey('gif-convert'))).bottom,
          lessThanOrEqualTo(440),
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => tester.tap(find.byKey(const ValueKey('gif-convert'))),
        );
        await _driveUntil(tester, () => encoder.calls == 1);
        expect(encoder.lastPlan!.width, 480);
        expect(encoder.lastPlan!.frameRate, 6);
        expect(encoder.lastPlan!.playbackFrameRate, 3);
        expect(encoder.lastPlan!.start, greaterThan(Duration.zero));
        tester.view.resetViewInsets();
        await _driveUntil(
          tester,
          () => find.byKey(const ValueKey('gif-share')).evaluate().isNotEmpty,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('gif-result-actions')),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        final adjustRect = tester.getRect(
          find.byKey(const ValueKey('gif-adjust')),
        );
        final saveRect = tester.getRect(find.byKey(const ValueKey('gif-save')));
        final shareRect = tester.getRect(
          find.byKey(const ValueKey('gif-share')),
        );
        expect(saveRect.top, adjustRect.top);
        expect(shareRect.top, adjustRect.top);
        expect(shareRect.right, lessThanOrEqualTo(320));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('gif-save')),
            matching: find.byIcon(Icons.save_alt),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('gif-share')),
            matching: find.byIcon(Icons.share),
          ),
          findsOneWidget,
        );
        expect(
          find.text(locale == AppLocale.enUs ? 'Share' : 'Teilen'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      },
    );
  }

  testWidgets(
    'notification drawer and backgrounding keep conversion running until Cancel',
    (tester) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('gif-inactive-'),
      );
      addTearDown(() => root!.delete(recursive: true));
      final encoder = _Encoder(pending: true);
      await _open(tester, post: _video, root: root, backend: encoder);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('create-gif'))),
      );
      await _driveUntil(
        tester,
        () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
      );
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('gif-convert'))),
      );
      await _driveUntil(tester, () => encoder.entered.isCompleted);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(encoder.lastToken!.isCancelled, isFalse);
      expect(find.byKey(const ValueKey('gif-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('gif-preview')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(encoder.lastToken!.isCancelled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(encoder.lastToken!.isCancelled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('gif-cancel'))),
      );
      await _driveUntil(
        tester,
        () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
      );
      expect(encoder.lastToken!.isCancelled, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() async {
        await tester.pageBack();
      });
      await tester.pumpAndSettle();
      await _driveUntil(
        tester,
        () => Directory('${root!.path}/boorusama-share').listSync().isEmpty,
      );
    },
  );

  testWidgets(
    'Save uses configured folder and keeps result alive while the write is pending',
    (tester) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('gif-save-widget-'),
      );
      addTearDown(() => root!.delete(recursive: true));
      final reply = Completer<bool>();
      String? savedPath;
      const channel = MethodChannel('boorusama/gif_save');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var saveCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        saveCalls++;
        final args = Map<String, Object?>.from(call.arguments as Map);
        savedPath = args['source']! as String;
        expect(call.method, 'saveToDirectory');
        expect(args['name'], 'boorusama_42.gif');
        expect(args['directory'], '/storage/emulated/0/Download/GIFs');
        if (saveCalls == 1) return false;
        return reply.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await _open(tester, post: _video, root: root, backend: _Encoder());
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('create-gif'))),
      );
      await _driveUntil(
        tester,
        () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
      );
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('gif-convert'))),
      );
      await _driveUntil(
        tester,
        () => find.byKey(const ValueKey('gif-save')).evaluate().isNotEmpty,
      );
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('gif-save'))),
      );
      await _driveUntil(tester, () => saveCalls == 1);
      expect(find.text('GIF ready'), findsOneWidget);
      expect(await tester.runAsync(() => File(savedPath!).exists()), isTrue);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('gif-save'))),
      );
      await _driveUntil(tester, () => saveCalls == 2);
      await tester.runAsync(() async {
        await tester.pageBack();
      });
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => File(savedPath!).exists()), isTrue);
      reply.complete(true);
      await _driveUntil(tester, () => !File(savedPath!).existsSync());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long videos offer GIF creation and default to their full duration',
    (tester) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('gif-long-sheet-'),
      );
      addTearDown(() => root!.delete(recursive: true));
      final encoder = _Encoder(duration: const Duration(minutes: 3));
      await _open(tester, post: _video, backend: encoder, root: root);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('create-gif')))
            .onPressed,
        isNotNull,
      );
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('create-gif'))),
      );
      await _driveUntil(
        tester,
        () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
      );
      expect(find.text('0.0 s → 180.0 s'), findsOneWidget);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('gif-convert'))),
      );
      await _driveUntil(
        tester,
        () => find.byKey(const ValueKey('gif-share')).evaluate().isNotEmpty,
      );
      expect(encoder.inspections, 1);
      expect(encoder.lastPlan!.start, Duration.zero);
      expect(encoder.lastPlan!.duration, encoder.duration);
      await tester.runAsync(() => tester.pageBack());
      await tester.pumpAndSettle();
      await _driveUntil(
        tester,
        () => Directory('${root!.path}/boorusama-share').listSync().isEmpty,
      );
      expect(find.byTooltip('Share video'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GIF failure shows the failing stage and reason', (tester) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('gif-error-sheet-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    await _open(
      tester,
      post: _video,
      backend: _Encoder(failure: true),
      root: root,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('create-gif')));
    });
    await _driveUntil(
      tester,
      () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
    );
    await tester.runAsync(
      () => tester.tap(find.byKey(const ValueKey('gif-convert'))),
    );
    await _driveUntil(
      tester,
      () => find.textContaining('[GIF-encoding-encoder]').evaluate().isNotEmpty,
    );
    expect(find.text('Adjust'), findsOneWidget);
  });

  testWidgets('missing native call names only its method and channel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('gif-plugin-sheet-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    await _open(
      tester,
      post: _video,
      root: root,
      textScale: 2,
      backend: _Encoder(
        inspectError: MissingPluginException(
          'No implementation found for method rotation on channel boorusama/gif_metadata',
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('create-gif')));
    });
    await _driveUntil(
      tester,
      () => find
          .textContaining('[NATIVE:rotation@boorusama/gif_metadata]')
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.textContaining('[GIF-inspecting-encoderUnavailable]'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow enlarged sheet can cancel GIF encoding quietly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('gif-cancel-sheet-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    final encoder = _Encoder(pending: true);
    var shares = 0;
    await _open(
      tester,
      post: _video,
      backend: encoder,
      root: root,
      textScale: 2,
      adapter: ShareActionAdapter((_) async {
        shares++;
        return const ShareResult('', ShareResultStatus.success);
      }),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('create-gif')));
    });
    await _driveUntil(
      tester,
      () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => tester.tap(find.byKey(const ValueKey('gif-convert'))),
    );
    await _driveUntil(tester, () => encoder.entered.isCompleted);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gif-cancel')),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('gif-cancel')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await _driveUntil(
      tester,
      () => find.byKey(const ValueKey('gif-convert')).evaluate().isNotEmpty,
    );
    expect(encoder.inspections, 1);
    await tester.runAsync(() async {
      await tester.pageBack();
    });
    await tester.pumpAndSettle();
    await _driveUntil(
      tester,
      () =>
          tester
              .widget<IconButton>(find.byKey(const ValueKey('create-gif')))
              .onPressed !=
          null,
    );
    await _driveUntil(
      tester,
      () => Directory('${root!.path}/boorusama-share').listSync().isEmpty,
    );
    expect(shares, 0);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      await tester.runAsync(
        () => Directory('${root!.path}/boorusama-share').list().toList(),
      ),
      isEmpty,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('create-gif')))
          .onPressed,
      isNotNull,
    );
  });
}

final _video = dummyPost(
  id: 42,
  format: 'mp4',
  originalImageUrl: 'https://site.test/full.mp4',
  videoUrl: 'https://site.test/full.mp4',
);

Future<void> _open(
  WidgetTester tester, {
  required Post post,
  required GifEncoderBackend? backend,
  Directory? root,
  ShareActionAdapter? adapter,
  double textScale = 1,
}) async {
  final fs = _FileSystem();
  when(fs.getTemporaryPath).thenAnswer((_) async => root?.path);
  final cache = _Cache();
  when(() => cache.generateCacheKey(any())).thenReturn('key');
  when(() => cache.getCachedFileBytes(any())).thenReturn(null);
  final dio = Dio()..httpClientAdapter = _Download();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gifEncoderBackendProvider.overrideWithValue(backend),
        gifSaveServiceProvider.overrideWithValue(
          GifSaveService(
            resolveDirectory: () async => '/storage/emulated/0/Download/GIFs',
          ),
        ),
        appFileSystemProvider.overrideWithValue(fs),
        downloadFileUrlExtractorProvider.overrideWith(
          (ref, config) => const UrlInsidePostExtractor(),
        ),
        mediaUrlResolverProvider.overrideWith(
          (ref, config) => const SampleMediaUrlResolver(),
        ),
        postLinkGeneratorProvider.overrideWith(
          (ref, config) => const IntIdPostLinkGenerator(
            baseUrl: 'https://site.test',
            pathTemplate: 'posts/{id}',
          ),
        ),
        bypassDdosHeadersProvider.overrideWith((ref, url) => const {}),
        httpHeadersProvider.overrideWith((ref, config) => const {}),
        dioForWidgetProvider.overrideWith((ref, config) => dio),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: TranslationProvider(
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
        home: Scaffold(
          body: UnifiedPostShareSheet(
            post: post,
            auth: _auth,
            viewer: _viewer,
            imageCacheManager: cache,
            shareAdapter: adapter,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Download implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    [1, 2, 3],
    200,
    headers: {
      Headers.contentTypeHeader: ['video/mp4'],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _Encoder implements GifEncoderBackend {
  _Encoder({
    this.pending = false,
    this.failure = false,
    this.inspectError,
    this.duration = const Duration(seconds: 2),
    this.width = 16,
    this.height = 16,
  });
  final int width;
  final int height;
  final Duration duration;
  var inspections = 0;
  final bool pending;
  final bool failure;
  final Exception? inspectError;
  final entered = Completer<void>();
  var calls = 0;
  GifExportPlan? lastPlan;
  CancelToken? lastToken;
  @override
  Future<GifSourceMetadata> inspect(
    String path, {
    required CancelToken cancelToken,
  }) async {
    inspections++;
    if (inspectError case final error?) throw error;
    return GifSourceMetadata(
      duration: duration,
      complete: true,
      width: width,
      height: height,
      rotationDegrees: 0,
      sampleAspectRatio: 1,
      frameRate: 12,
    );
  }

  @override
  Future<void> encode(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
    void Function(double?)? onProgress,
  }) async {
    calls++;
    lastPlan = request.plan;
    lastToken = cancelToken;
    if (failure) {
      throw const GifConversionException(GifConversionFailure.encoder);
    }
    if (!entered.isCompleted) entered.complete();
    if (pending) {
      await cancelToken.whenCancel;
      return;
    }
    final encoder = image.GifEncoder();
    final frames =
        (request.plan.duration.inMicroseconds /
                1000000 *
                request.plan.encodedSourceFrameRate)
            .ceil();
    final delay = 100 / request.plan.encodedPlaybackFrameRate;
    for (var i = 0; i < frames; i++) {
      encoder.addFrame(
        image.Image(width: request.plan.width, height: request.plan.height),
        duration: ((i + 1) * delay).round() - (i * delay).round(),
      );
    }
    await File(request.outputPath).writeAsBytes(encoder.finish()!);
  }

  @override
  Future<GifOutputValidation> validateOutput(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
  }) async => inspectGifOutput(await File(request.outputPath).readAsBytes());
}

Future<void> _driveUntil(WidgetTester tester, bool Function() complete) async {
  // File I/O uses real time; Riverpod/rendering also need fake-clock pumps.
  for (var attempt = 0; attempt < 100 && !complete(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    complete(),
    isTrue,
    reason: 'The media operation did not reach its expected state',
  );
  await tester.pump(const Duration(seconds: 1));
}
