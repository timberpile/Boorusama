// Baseline-compatible regression: no proposed constructor/API is referenced.
import 'dart:async';

import 'package:boorusama/core/bootstrap/boorusama_bootstrap.dart';
import 'package:boorusama/core/bootstrap/boorusama_runtime.dart';
import 'package:boorusama/core/bootstrap/bootstrap_host.dart';
import 'package:boorusama/foundation/boot/failsafe.dart';
import 'package:boorusama/foundation/boot/file_system_crash_report_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'the default diagnostic action contains unavailable dependencies',
    (tester) async {
      final originalBuilder = ErrorWidget.builder;
      try {
        await tester.pumpWidget(BoorusamaBootstrapHost(bootstrap: _Failure()));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(AppFailedToInitialize));
        // No file-picker platform implementation is registered in this headless
        // test. Its absence must be handled by the failsafe writer, not escape as
        // the missing application provider currently does.
        await expectLater(
          Future<void>.sync(
            () => const FileSystemCrashReportWriter().save(
              context,
              'synthetic report',
            ),
          ),
          completes,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        ErrorWidget.builder = originalBuilder;
      }
    },
  );
}

final class _Failure implements BoorusamaBootstrap {
  @override
  Future<BoorusamaRuntime> initialize() async =>
      throw BoorusamaBootstrapFailure(
        error: StateError('controlled bootstrap failure'),
        stackTrace: StackTrace.current,
        logs: 'synthetic boot log',
      );
}
