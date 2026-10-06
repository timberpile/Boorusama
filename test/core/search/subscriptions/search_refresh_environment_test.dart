import 'dart:async';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_environment.dart';
import 'package:boorusama/core/search/subscriptions/src/services/conservative_refresh_policy.dart';
import 'package:boorusama/core/settings/src/types/search_refresh_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:boorusama/foundation/networking/network_provider.dart';

void main() {
  for (final nativeFirst in [false, true]) {
    for (final meteredMobile in [false, true]) {
      test(
        'staggered wifi to mobile nativeFirst $nativeFirst metered $meteredMobile cannot mix network proofs',
        () async {
          final signals = StreamController<Map<Object?, Object?>>.broadcast();
          final connectivity = StateProvider<List<ConnectivityResult>>(
            (ref) => [ConnectivityResult.wifi],
          );
          final container = ProviderContainer(
            overrides: [
              nativeSearchRefreshEnvironmentProvider.overrideWith(
                (ref) => signals.stream,
              ),
              currentConnectivityProvider.overrideWith(
                (ref) => Future.value(ref.watch(connectivity)),
              ),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(signals.close);
          final listener = container.listen(
            searchRefreshEnvironmentProvider,
            (_, _) {},
          );
          addTearDown(listener.close);
          await container.read(currentConnectivityProvider.future);
          signals.add({
            'transport': 'wifi',
            'metered': false,
            'batterySaver': false,
          });
          await container.read(nativeSearchRefreshEnvironmentProvider.future);
          expect(
            container
                .read(searchRefreshEnvironmentProvider)
                .allowed(const SearchRefreshSettings()),
            isTrue,
          );
          Future<void> nativeMobile() async {
            signals.add({
              'transport': 'mobile',
              'metered': meteredMobile,
              'batterySaver': false,
            });
            await Future<void>.delayed(Duration.zero);
          }

          Future<void> pluginMobile() async {
            container.read(connectivity.notifier).state = [
              ConnectivityResult.mobile,
            ];
            await container.read(currentConnectivityProvider.future);
          }

          if (nativeFirst) {
            await nativeMobile();
          } else {
            await pluginMobile();
          }
          expect(
            container
                .read(searchRefreshEnvironmentProvider)
                .allowed(
                  SearchRefreshSettings(wifiEthernetOnly: !meteredMobile),
                ),
            isFalse,
          );
          if (nativeFirst) {
            await pluginMobile();
          } else {
            await nativeMobile();
          }
          expect(
            container.read(searchRefreshEnvironmentProvider).network,
            meteredMobile
                ? RefreshNetwork.metered
                : RefreshNetwork.unmeteredMobile,
          );
          expect(
            container
                .read(searchRefreshEnvironmentProvider)
                .allowed(const SearchRefreshSettings()),
            isFalse,
          );
          expect(
            container
                .read(searchRefreshEnvironmentProvider)
                .allowed(const SearchRefreshSettings(wifiEthernetOnly: false)),
            !meteredMobile,
          );
        },
      );
    }
  }
  test(
    'reloading native signals pauses automatic eligibility until fresh data',
    () async {
      final signals = StreamController<Map<Object?, Object?>>.broadcast();
      final container = ProviderContainer(
        overrides: [
          nativeSearchRefreshEnvironmentProvider.overrideWith(
            (ref) => signals.stream,
          ),
          currentConnectivityProvider.overrideWith(
            (ref) => Future.value([ConnectivityResult.wifi]),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(signals.close);
      final subscription = container.listen(
        searchRefreshEnvironmentProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(currentConnectivityProvider.future);
      signals.add({
        'transport': 'wifi',
        'metered': false,
        'batterySaver': false,
      });
      await container.read(nativeSearchRefreshEnvironmentProvider.future);
      expect(
        container
            .read(searchRefreshEnvironmentProvider)
            .allowed(const SearchRefreshSettings()),
        isTrue,
      );
      container.invalidate(nativeSearchRefreshEnvironmentProvider);
      expect(
        container
            .read(searchRefreshEnvironmentProvider)
            .allowed(const SearchRefreshSettings()),
        isFalse,
      );
      signals.add({
        'transport': 'wifi',
        'metered': false,
        'batterySaver': false,
      });
      await container.read(nativeSearchRefreshEnvironmentProvider.future);
      expect(
        container
            .read(searchRefreshEnvironmentProvider)
            .allowed(const SearchRefreshSettings()),
        isTrue,
      );
    },
  );
  for (final c in [
    (
      network: RefreshNetwork.wifi,
      saver: false,
      known: true,
      wifiOnly: true,
      allowed: true,
    ),
    (
      network: RefreshNetwork.wifi,
      saver: true,
      known: true,
      wifiOnly: true,
      allowed: false,
    ),
    (
      network: RefreshNetwork.wifi,
      saver: false,
      known: false,
      wifiOnly: true,
      allowed: false,
    ),
    (
      network: RefreshNetwork.unmeteredMobile,
      saver: false,
      known: true,
      wifiOnly: true,
      allowed: false,
    ),
    (
      network: RefreshNetwork.unmeteredMobile,
      saver: false,
      known: true,
      wifiOnly: false,
      allowed: true,
    ),
    (
      network: RefreshNetwork.metered,
      saver: false,
      known: true,
      wifiOnly: false,
      allowed: false,
    ),
    (
      network: RefreshNetwork.unknown,
      saver: false,
      known: true,
      wifiOnly: false,
      allowed: false,
    ),
  ]) {
    test(
      '${c.network.name} saver${c.saver} known${c.known} wifiOnly${c.wifiOnly} permits${c.allowed}',
      () {
        final environment = SearchRefreshEnvironment(
          network: c.network,
          batterySaver: c.saver,
          powerKnown: c.known,
        );
        expect(
          environment.allowed(
            SearchRefreshSettings(wifiEthernetOnly: c.wifiOnly),
          ),
          c.allowed,
        );
      },
    );
  }
}
