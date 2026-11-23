// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../settings/providers.dart';
import '../../../manage/providers.dart';
import '../types/booru_config.dart';

final hasBooruConfigsProvider = Provider<bool>((ref) {
  final configs = ref.watch(booruConfigProvider);
  return configs.isNotEmpty;
});

/// Shared presentation order; unknown/stale IDs never hide existing profiles.
final orderedProfileConfigsProvider = Provider<List<BooruConfig>>((ref) {
  return orderProfileConfigs(
    ref.watch(booruConfigProvider),
    ref.watch(settingsProvider.select((value) => value.booruConfigIdOrderList)),
  );
});

/// Pure projection also usable by the profile notifier without reading a
/// derived provider that depends on that same notifier.
List<BooruConfig> orderProfileConfigs(
  Iterable<BooruConfig> configs,
  Iterable<String> orders,
) {
  final byId = {for (final config in configs) config.id: config};
  return [for (final id in orders) ?byId.remove(id), ...byId.values];
}

final orderedConfigsProvider = FutureProvider.autoDispose<IList<BooruConfig>>(
  (ref) => ref.watch(orderedProfileConfigsProvider).toIList(),
);

final firstMatchingConfigBySourceUrlProvider =
    Provider.family<BooruConfig?, (int, String)>(
      (ref, params) {
        final (id, url) = params;
        final configs = ref.watch(booruConfigProvider);
        final idResult = configs
            .where(
              (config) => config.auth.booruIdHint == id || config.booruId == id,
            )
            .toList();

        if (idResult.isEmpty) {
          return null;
        }

        final config = idResult.firstWhereOrNull((config) {
          final authUrl = config.auth.url.endsWith('/')
              ? config.auth.url.substring(0, config.auth.url.length - 1)
              : config.auth.url;

          return url.contains(authUrl);
        });

        return config ?? idResult.firstOrNull;
      },
    );

final firstMatchingConfigByBooruTypeProvider =
    Provider.family<BooruConfig?, (int, String)>(
      (ref, params) {
        final (booruId, host) = params;
        final configs = ref.watch(booruConfigProvider);
        final idResult = configs
            .where(
              (config) =>
                  config.auth.booruIdHint == booruId ||
                  config.booruId == booruId,
            )
            .toList();

        if (idResult.isEmpty) return null;

        if (host.isNotEmpty) {
          final match = idResult.firstWhereOrNull(
            (config) => Uri.tryParse(config.auth.url)?.host == host,
          );

          if (match != null) return match;
        }

        return idResult.first;
      },
    );

final booruLoginDetailsProvider =
    Provider.family<BooruLoginDetails, BooruConfigAuth>(
      (ref, config) {
        final repo = ref
            .watch(booruEngineRegistryProvider)
            .getRepository(config.booruType);

        final loginDetails = repo?.loginDetails(config);

        if (loginDetails != null) {
          return loginDetails;
        }

        return DefaultBooruLoginDetails(
          login: config.login,
          apiKey: config.apiKey,
          url: config.url,
        );
      },
    );

final defaultLoginDetailsProvider =
    Provider.family<BooruLoginDetails, BooruConfigAuth>(
      (ref, config) {
        return DefaultBooruLoginDetails(
          login: config.login,
          apiKey: config.apiKey,
          url: config.url,
        );
      },
    );
