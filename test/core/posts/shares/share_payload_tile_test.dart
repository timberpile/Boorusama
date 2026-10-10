import 'package:boorusama/core/posts/shares/src/share_payload_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('available media exposes copy and share actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharePayloadTile(
            title: 'Original',
            value: 'https://site.test/full.jpg',
            leading: const Icon(Icons.image),
            unavailable: 'Unavailable',
            copyTooltip: 'Copy original',
            shareTooltip: 'Share original',
            onShare: () {},
            onCopy: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.image), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.byTooltip('Share original'), findsOneWidget);
    expect(find.byTooltip('Copy original'), findsOneWidget);
  });

  testWidgets('missing payload remains visible without enabled actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SharePayloadTile(
            title: 'Source link',
            value: null,
            unavailable: 'Unavailable',
            copyTooltip: 'Copy source link',
            shareTooltip: 'Share source link',
          ),
        ),
      ),
    );

    expect(find.text('Source link'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton).at(0)).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton).at(1)).onPressed,
      isNull,
    );
  });
  testWidgets('lazy Original shows a resolution action without a stored URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharePayloadTile(
            title: 'Original',
            value: null,
            deferred: true,
            showValue: false,
            unavailable: 'Unavailable',
            copyTooltip: 'Copy original',
            shareTooltip: 'Share original',
            onShare: () {},
            onCopy: () {},
          ),
        ),
      ),
    );

    expect(find.text('Prepared when selected'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Copy original'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.byTooltip('Share original'), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(2));
  });

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
