import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_option_value_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../following_topics/following_topic_test_utils.dart';

void main() {
  setUpAll(() async {
    // Calendar geometry needs the real digit widths, not the test Ahem font.
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterRoot = configFile.absolute.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../');
    await (FontLoader('Roboto')..addFont(
          File.fromUri(
            flutterRoot.resolve(
              'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  testWidgets('calendar days remain readable at narrow width and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    final changes = <String>[];
    await harness.pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: SearchOptionValueInput(
            option: capabilitiesFor(
              BooruType.danbooru,
              'https://danbooru.donmai.us',
            ).byKey('date')!,
            value: '2026-10-23',
            onChanged: changes.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Choose date'));
    await tester.pumpAndSettle();
    final day = find.text('31');
    expect(day, findsOneWidget);
    final element = tester.element(day);
    final text = tester.widget<Text>(day);
    final painter = TextPainter(
      text: TextSpan(
        text: text.data,
        style: DefaultTextStyle.of(element).style.merge(text.style),
      ),
      textDirection: Directionality.of(element),
      textScaler: MediaQuery.textScalerOf(element),
    )..layout();
    addTearDown(painter.dispose);
    expect(painter.width, lessThanOrEqualTo(tester.getSize(day).width));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('2026-10-23'), findsOneWidget);
    expect(changes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
