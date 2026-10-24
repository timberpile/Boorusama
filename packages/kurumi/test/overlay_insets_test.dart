import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'replaces only overlay bottom padding and preserves keyboard data',
    (tester) async {
      const data = MediaQueryData(
        size: Size(320, 640),
        padding: EdgeInsets.fromLTRB(3, 20, 4, 88),
        viewPadding: EdgeInsets.fromLTRB(3, 20, 4, 88),
        viewInsets: EdgeInsets.only(bottom: 240),
      );
      late MediaQueryData page;
      late MediaQueryData overlay;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: data,
            child: KurumiOverlayInsetsScope(
              bottomPadding: 0,
              bottomViewPadding: 24,
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      page = MediaQuery.of(context);
                      return const SizedBox();
                    },
                  ),
                  KurumiOverlayMediaQuery(
                    builder: (context) {
                      overlay = MediaQuery.of(context);
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(page, data);
      expect(overlay.padding, const EdgeInsets.fromLTRB(3, 20, 4, 0));
      expect(overlay.viewPadding, const EdgeInsets.fromLTRB(3, 20, 4, 24));
      expect(overlay.viewInsets, data.viewInsets);
      expect(overlay.size, data.size);
    },
  );

  testWidgets('does not change overlays outside a navigation inset scope', (
    tester,
  ) async {
    const data = MediaQueryData(padding: EdgeInsets.only(bottom: 24));
    late MediaQueryData overlay;
    await tester.pumpWidget(
      MediaQuery(
        data: data,
        child: KurumiOverlayMediaQuery(
          builder: (context) {
            overlay = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(overlay, data);
  });
}
