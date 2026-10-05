import 'package:boorusama/core/posts/shares/src/share_payload_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'media row hides its URL and preparation placeholder',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePayloadTile(
              title: 'Original',
              value: 'https://site.test/preview.jpg',
              showValue: false,
              unavailable: 'Unavailable',
              copyTooltip: 'Copy original',
              shareTooltip: 'Share original',
              onShare: () {},
            ),
          ),
        ),
      );

      expect(find.text('Prepared when selected'), findsNothing);
      expect(find.text('https://site.test/preview.jpg'), findsNothing);
      expect(find.byTooltip('Share original'), findsOneWidget);
    },
  );
}
