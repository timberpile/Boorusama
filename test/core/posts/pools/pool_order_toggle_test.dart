import 'package:boorusama/core/posts/pools/src/types/pool_details_order.dart';
import 'package:boorusama/core/posts/pools/src/widgets/pool_order_toggle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'pool order stays inside the reported 363.4 pixel width at $scale text',
      (tester) async {
        PoolDetailsOrder? selected;
        await tester.pumpWidget(
          BooruLocalization(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: SizedBox(
                      width: 363.4,
                      child: PoolOrderToggle(
                        value: PoolDetailsOrder.order,
                        onChanged: (value) => selected = value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(PoolOrderToggle));
        await tester.tap(find.text(PoolDetailsOrder.oldest.localize(context)));
        await tester.pumpAndSettle();
        expect(selected, PoolDetailsOrder.oldest);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
