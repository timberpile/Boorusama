import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/developer_options/widgets.dart';
import 'package:boorusama/core/posts/links/open_link_file.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

class _CancellingPicker implements AppFilePicker {
  var calls = 0;

  @override
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    bool customFileType = false,
  }) async {
    calls++;
    return null;
  }

  @override
  Future<String?> pickDirectory({String? initialDirectory}) =>
      throw UnimplementedError();
}

Future<void> _pumpDeveloperOptions(
  WidgetTester tester,
  _CancellingPicker picker, {
  String environment = 'dev',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentEnvironmentProvider.overrideWithValue(environment),
        automaticMediaLoadingEnabledProvider.overrideWithValue(true),
        appFilePickerProvider.overrideWithValue(picker),
      ],
      child: BooruLocalization(
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
          ),
          home: const DeveloperOptionsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(320, 640), const Size(1280, 800)]) {
    testWidgets('manual link opener is usable in developer options at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final picker = _CancellingPicker();
      await _pumpDeveloperOptions(tester, picker);
      final opener = find.byType(OpenLinkFileTile);
      expect(opener, findsOneWidget);
      await tester.ensureVisible(opener);
      await tester.pumpAndSettle();
      expect(opener.hitTestable(), findsOneWidget);
      await tester.tap(opener);
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.byType(DeveloperOptionsPage), findsOneWidget);
      await tester.tap(opener);
      await tester.pumpAndSettle();
      expect(picker.calls, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('production flavor hides the manual link opener', (tester) async {
    final picker = _CancellingPicker();
    await _pumpDeveloperOptions(tester, picker, environment: 'prod');
    expect(find.byType(OpenLinkFileTile), findsNothing);
    expect(picker.calls, 0);
    expect(tester.takeException(), isNull);
  });
}
