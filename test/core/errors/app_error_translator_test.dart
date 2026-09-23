// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import 'package:boorusama/core/errors/types.dart';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  testWidgets('connection errors do not expose transport diagnostics', (
    tester,
  ) async {
    const diagnostic =
        'DioException: request failed for https://secret.example/posts.json';

    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Text(
              DefaultAppErrorTranslator().translateAppError(
                context,
                AppError(
                  type: AppErrorType.cannotReachServer,
                  message: diagnostic,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Cannot reach server, please check your connection'),
      findsOneWidget,
    );
    expect(find.textContaining('secret.example'), findsNothing);
  });
}
