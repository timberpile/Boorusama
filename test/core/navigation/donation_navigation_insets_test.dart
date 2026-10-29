import 'package:boorusama/core/donate/src/donation_page.dart';
import 'package:boorusama/foundation/info/app_info.dart';
import 'package:boorusama/foundation/networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final inset in [24.0, 104.0]) {
      testWidgets(
        'donation actions remain reachable at $scale text and $inset inset',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final info = AppInfo(
            discordUrl: '',
            githubUrl: '',
            patreonUrl: 'https://patreon.example/support',
            koFiUrl: 'https://ko-fi.example/support',
            buyMeCoffeeUrl: 'https://coffee.example/support',
            playStoreUrl: '',
            appName: 'Boorusama',
            translationProjectUrl: '',
            translationStatusUrl: '',
            translationBadgeUrl: '',
            supportEmail: '',
            booruDefUrl: '',
            termsOfServiceUrl: '',
            privacyPolicyUrl: '',
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appInfoProvider.overrideWithValue(info),
                networkStateProvider.overrideWithValue(
                  NetworkDisconnectedState(),
                ),
              ],
              child: MaterialApp(
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      padding: EdgeInsets.only(bottom: inset),
                    ),
                    child: child!,
                  ),
                ),
                home: const DonationPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final last = find.text(info.buyMeCoffeeUrl);
          await tester.ensureVisible(last);
          await tester.pumpAndSettle();
          expect(last.hitTestable(), findsOneWidget);
          expect(tester.getRect(last).bottom, lessThanOrEqualTo(480 - inset));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
