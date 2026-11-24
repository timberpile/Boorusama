import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/bootstrap/boorusama_bootstrap.dart';
import 'package:boorusama/core/bootstrap/boorusama_runtime.dart';
import 'package:boorusama/core/bootstrap/bootstrap_host.dart';
import 'package:boorusama/foundation/boot/file_system_crash_report_writer.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:path/path.dart' as p;

void main() {
  Future<BuildContext> mount(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('writes a real report without an application ProviderScope', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('crash_report_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final context = await mount(tester);
    final writer = FileSystemCrashReportWriter(
      picker: _Picker(() async => directory.path),
    );
    await tester.runAsync(() => writer.save(context, 'synthetic report'));
    await tester.pump();
    expect(
      File(p.join(directory.path, 'boorusama_crash.txt')).readAsStringSync(),
      'synthetic report',
    );
    expect(find.text('Crash report saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bootstrap failure download action uses the real writer', (
    tester,
  ) async {
    final originalBuilder = ErrorWidget.builder;
    try {
      final fs = _RecordingFileSystem();
      await tester.pumpWidget(
        BoorusamaBootstrapHost(
          bootstrap: _FailingBootstrap(),
          crashReportWriter: FileSystemCrashReportWriter(
            picker: _Picker(() async => '/synthetic-diagnostics'),
            fileSystem: fs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();
      expect(fs.writes.keys, [
        p.join('/synthetic-diagnostics', 'boorusama_crash.txt'),
      ]);
      expect(fs.writes.values.single, contains('controlled bootstrap failure'));
      expect(fs.writes.values.single, contains('synthetic boot log'));
      expect(fs.flushed, isTrue);
      expect(find.text('Crash report saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      ErrorWidget.builder = originalBuilder;
    }
  });

  testWidgets('cancelling the picker does not write or report success', (
    tester,
  ) async {
    final context = await mount(tester);
    final fs = _RecordingFileSystem();
    final writer = FileSystemCrashReportWriter(
      picker: _Picker(() async => null),
      fileSystem: fs,
    );
    await writer.save(context, 'synthetic report');
    await tester.pump();
    expect(fs.writes, isEmpty);
    expect(find.text('Crash report saved'), findsNothing);
    expect(find.text('Could not save the crash report'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final failPicker in [false, true]) {
    testWidgets(
      'a ${failPicker ? 'picker' : 'write'} failure is contained by the failsafe UI',
      (tester) async {
        final context = await mount(tester);
        final fs = _RecordingFileSystem(fail: !failPicker);
        final writer = FileSystemCrashReportWriter(
          picker: _Picker(() async {
            if (failPicker) throw StateError('synthetic private diagnostic');
            return '/synthetic-diagnostics';
          }),
          fileSystem: fs,
        );
        await writer.save(context, 'synthetic report');
        await tester.pump();
        expect(fs.writes, isEmpty);
        expect(find.text('Could not save the crash report'), findsOneWidget);
        expect(
          find.textContaining('synthetic private diagnostic'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a completed picker can finish saving after the screen unmounts',
    (tester) async {
      final context = await mount(tester);
      final selected = Completer<String?>();
      final fs = _RecordingFileSystem();
      final writer = FileSystemCrashReportWriter(
        picker: _Picker(() => selected.future),
        fileSystem: fs,
      );
      final operation = writer.save(context, 'synthetic report');
      await tester.pumpWidget(const SizedBox.shrink());
      selected.complete('/synthetic-diagnostics');
      await operation;
      await tester.pump();
      expect(fs.writes.values.single, 'synthetic report');
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Picker implements AppFilePicker {
  const _Picker(this.select);
  final Future<String?> Function() select;
  @override
  Future<String?> pickDirectory({String? initialDirectory}) => select();
  @override
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    bool customFileType = false,
  }) => throw StateError('Only directory selection is expected');
}

class _RecordingFileSystem extends IoFileSystem {
  _RecordingFileSystem({this.fail = false});
  final bool fail;
  final writes = <String, String>{};
  var flushed = false;
  @override
  Future<void> writeString(
    String path,
    String content, {
    bool flush = false,
  }) async {
    if (fail) throw StateError('synthetic private diagnostic');
    writes[path] = content;
    flushed = flush;
  }
}

final class _FailingBootstrap implements BoorusamaBootstrap {
  @override
  Future<BoorusamaRuntime> initialize() async =>
      throw BoorusamaBootstrapFailure(
        error: StateError('controlled bootstrap failure'),
        stackTrace: StackTrace.current,
        logs: 'synthetic boot log',
      );
}
