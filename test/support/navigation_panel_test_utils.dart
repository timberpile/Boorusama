import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

Finder navigationPanel() =>
    find.byKey(const ValueKey('navigation-panel-motion'));

/// Read the rendered translation, independently of the motion controller.
Offset navigationPanelTranslation(WidgetTester tester) {
  final transform = find.byKey(const ValueKey('navigation-panel-translation'));
  final displacement = tester
      .widget<Transform>(transform)
      .transform
      .getTranslation();
  return Offset(
    displacement.x,
    displacement.y / tester.getSize(transform).height,
  );
}
