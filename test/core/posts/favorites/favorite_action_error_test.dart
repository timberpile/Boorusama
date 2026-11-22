import 'dart:async';

import 'package:boorusama/core/posts/favorites/src/widgets/favorite_action.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.receiveTimeout,
    DioExceptionType.badResponse,
    DioExceptionType.cancel,
  ]) {
    testWidgets(
      'Favorite feedback handles ${type.name} without leaking errors',
      (
        tester,
      ) async {
        final context = await _mount(tester);
        final result = await runFavoriteAction<bool>(
          context,
          () => Future.error(
            DioException(
              requestOptions: RequestOptions(path: '/favorite'),
              type: type,
              message: 'synthetic-private-detail',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('synthetic-private-detail'), findsNothing);
        expect(
          find.text('Failed to update favorites'),
          type == DioExceptionType.cancel ? findsNothing : findsOneWidget,
        );
        await tester.pump(KurumiDurations.shortToast);
      },
    );
  }

  testWidgets('a network failure stays silent after its account changes', (
    tester,
  ) async {
    final context = await _mount(tester);
    final response = Completer<bool>();
    var current = true;
    final result = runFavoriteAction(
      context,
      () => response.future,
      isCurrent: () => current,
    );
    current = false;
    response.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/favorite'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(await result, isNull);
    await tester.pumpAndSettle();
    expect(find.text('Failed to update favorites'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<BuildContext> _mount(WidgetTester tester) async {
  late BuildContext feedback;
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: Kurumi.themeFrom(
          KurumiThemeMode.light,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          systemDarkMode: false,
        ),
        builder: (context, child) => OKToast(
          child: KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              feedback = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return feedback;
}
