import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../foundation/networking/network_provider.dart';
import '../../../../settings/src/types/search_refresh_settings.dart';
import 'conservative_refresh_policy.dart';

class SearchRefreshEnvironment {
  const SearchRefreshEnvironment({
    this.network = RefreshNetwork.unknown,
    this.batterySaver = false,
    this.powerKnown = false,
  });
  final RefreshNetwork network;
  final bool batterySaver;
  final bool powerKnown;
  bool allowed(SearchRefreshSettings settings) =>
      powerKnown &&
      !batterySaver &&
      switch (network) {
        RefreshNetwork.wifi || RefreshNetwork.ethernet => true,
        RefreshNetwork.unmeteredMobile => !settings.wifiEthernetOnly,
        _ => false,
      };
}

const _method = MethodChannel('boorusama/search_refresh_environment');
const _events = EventChannel('boorusama/search_refresh_environment/events');

final nativeSearchRefreshEnvironmentProvider =
    StreamProvider<Map<Object?, Object?>>((ref) async* {
      try {
        final initial = await _method.invokeMapMethod<Object?, Object?>(
          'snapshot',
        );
        if (initial != null) yield initial;
        await for (final value in _events.receiveBroadcastStream()) {
          if (value is Map) yield Map<Object?, Object?>.from(value);
        }
      } on MissingPluginException {
        yield const {};
      } on PlatformException {
        yield const {};
      }
    });

final searchRefreshEnvironmentProvider = Provider<SearchRefreshEnvironment>((
  ref,
) {
  final nativeState = ref.watch(nativeSearchRefreshEnvironmentProvider);
  final native = nativeState.isLoading ? null : nativeState.valueOrNull;
  final connectivityState = ref.watch(currentConnectivityProvider);
  final connections = connectivityState.isLoading
      ? null
      : connectivityState.valueOrNull;
  final transport = switch (native?['transport']) {
    'wifi' => ConnectivityResult.wifi,
    'ethernet' => ConnectivityResult.ethernet,
    'mobile' => ConnectivityResult.mobile,
    'none' => ConnectivityResult.none,
    _ => null,
  };
  // Connectivity can veto an inconsistent transition, but cannot supply native
  // transport or metering proof from a different active network.
  final coherent =
      transport != null &&
      connections?.length == 1 &&
      connections!.single == transport;
  final network = !coherent
      ? RefreshNetwork.unknown
      : transport == ConnectivityResult.none
      ? RefreshNetwork.offline
      : native?['metered'] == true
      ? RefreshNetwork.metered
      : native?['metered'] != false
      ? RefreshNetwork.unknown
      : transport == ConnectivityResult.wifi
      ? RefreshNetwork.wifi
      : transport == ConnectivityResult.ethernet
      ? RefreshNetwork.ethernet
      : transport == ConnectivityResult.mobile
      ? RefreshNetwork.unmeteredMobile
      : RefreshNetwork.unknown;
  return SearchRefreshEnvironment(
    network: network,
    batterySaver: native?['batterySaver'] == true,
    powerKnown: native?['batterySaver'] is bool,
  );
});
