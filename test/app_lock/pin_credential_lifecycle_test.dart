import 'dart:io';

import 'package:boorusama/foundation/pincode/src/pin_credential.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Observe actual production disposal without changing its ownership policy.
class _ObservedPinFactory implements PinCredentialRepositoryFactory {
  final production = const HivePinCredentialRepositoryFactory();
  final disposals = <Future<void>>[];
  @override
  PinCredentialRepository create() => production.create();
  @override
  Future<void> dispose(PinCredentialRepository repository) {
    final completion = production.dispose(repository);
    disposals.add(completion);
    return completion;
  }
}

void main() {
  test('replacement PIN scope survives old disposal and persists changed credentials', () async {
    final root = await Directory.systemTemp.createTemp(
      'pin-credential-lifecycle-',
    );
    Hive.init(root.path);
    final factory = _ObservedPinFactory();
    ProviderContainer scope() => ProviderContainer(
      overrides: [
        pinCredentialRepositoryFactoryProvider.overrideWithValue(factory),
      ],
    );
    final firstScope = scope();
    ProviderContainer? replacementScope;
    var firstDisposed = false;
    try {
      final first = firstScope.read(pinCredentialRepositoryProvider);
      await first.setPin('2468');
      expect(await first.verifyPin('2468'), isTrue);
      replacementScope = scope();
      final replacement = replacementScope.read(
        pinCredentialRepositoryProvider,
      );
      expect(identical(first, replacement), isFalse);
      expect(await replacement.verifyPin('2468'), isTrue);
      firstScope.dispose();
      firstDisposed = true;
      await factory.disposals.single;
      expect(await replacement.verifyPin('0000'), isFalse);
      expect(await replacement.verifyPin('2468'), isTrue);
      await replacement.setPin('1357');
      expect(await replacement.verifyPin('2468'), isFalse);
      expect(await replacement.verifyPin('1357'), isTrue);
      await replacement.clearPin();
      expect(await replacement.hasPin(), isFalse);
      expect(await replacement.verifyPin('1357'), isFalse);
      await replacement.setPin('1357');
      replacementScope.dispose();
      replacementScope = null;
      await Future.wait(factory.disposals);
      await replacement.close();

      final cold = factory.create();
      expect(await cold.verifyPin('1357'), isTrue);
      expect(await cold.verifyPin('2468'), isFalse);
      await cold.clearPin();
      expect(await cold.hasPin(), isFalse);
      expect(await cold.verifyPin('1357'), isFalse);
      await cold.close();
      final reopened = factory.create();
      expect(await reopened.hasPin(), isFalse);
      await reopened.close();
    } finally {
      if (!firstDisposed) firstScope.dispose();
      replacementScope?.dispose();
      await Future.wait(
        factory.disposals.map((future) => future.catchError((Object _) {})),
      );
      await Hive.close();
      await root.delete(recursive: true);
    }
  });
}
