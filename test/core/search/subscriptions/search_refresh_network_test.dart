import 'package:boorusama/core/search/subscriptions/src/providers/search_refresh_coordinator.dart';
import 'package:boorusama/foundation/networking/network_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = [
    (connection: [ConnectivityResult.wifi], allowed: true),
    (connection: [ConnectivityResult.ethernet], allowed: true),
    (connection: [ConnectivityResult.mobile], allowed: false),
    (connection: [ConnectivityResult.vpn], allowed: false),
    (connection: [ConnectivityResult.none], allowed: false),
    (connection: <ConnectivityResult>[], allowed: false),
  ];
  for (final c in cases) {
    test(
      'automatic refresh permission is ${c.allowed} on ${c.connection}',
      () async {
        final container = ProviderContainer(
          overrides: [
            currentConnectivityProvider.overrideWith(
              (ref) => Future.value(c.connection),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          container.read(automaticSearchRefreshNetworkAllowedProvider),
          false,
        );
        await container.read(currentConnectivityProvider.future);
        expect(
          container.read(automaticSearchRefreshNetworkAllowedProvider),
          c.allowed,
        );
      },
    );
  }
}
