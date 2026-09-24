// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import 'package:boorusama/core/posts/details/widgets.dart';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  final cases = [
    (
      reason: PostPresentationFallbackReason.missingProfile,
      message: 'The original site profile is no longer available.',
    ),
    (
      reason: PostPresentationFallbackReason.ambiguousProfile,
      message: 'More than one site profile matches this post.',
    ),
    (
      reason: PostPresentationFallbackReason.unavailableEngine,
      message: 'Support for this post’s site is unavailable.',
    ),
    (
      reason: PostPresentationFallbackReason.malformedData,
      message: 'Some saved site-specific data could not be read.',
    ),
    (
      reason: PostPresentationFallbackReason.unsupportedVersion,
      message: 'This post was saved by a newer data format.',
    ),
    (
      reason: PostPresentationFallbackReason.removedUpstreamPost,
      message: 'The post is no longer available on its original site.',
    ),
    (
      reason: PostPresentationFallbackReason.refreshFailed,
      message: 'The latest site-specific data could not be loaded.',
    ),
  ];

  for (final testCase in cases) {
    testWidgets('${testCase.reason.name} explains the generic fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            home: Scaffold(
              body: PostPresentationFallbackWarning(reason: testCase.reason),
            ),
          ),
        ),
      );

      expect(find.text(testCase.message), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  }

  testWidgets('retry is shown only when fallback recovery is available', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Scaffold(
            body: PostPresentationFallbackWarning(
              reason: PostPresentationFallbackReason.refreshFailed,
              onRetry: () => retries++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));

    expect(retries, 1);
  });
}
