import 'package:boorusama/core/premiums/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grants Plus features to every installation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(kForcePremium, isTrue);
    expect(container.read(hasPremiumProvider), isTrue);
    expect(container.read(showPremiumFeatsProvider), isTrue);
  });
}
