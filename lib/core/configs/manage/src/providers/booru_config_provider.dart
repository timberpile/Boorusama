// Dart imports:
import 'dart:async';

// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../../foundation/loggers.dart';
import '../../../../../foundation/utils/collection_utils.dart';
import '../../../../analytics/analytics_interface.dart';
import '../../../../analytics/providers.dart';
import '../../../../settings/providers.dart';
import '../../../../search/subscriptions/providers.dart';
import '../../../../search/subscriptions/types.dart';
import '../../../config/data.dart';
import '../../../config/providers.dart';
import '../../../config/types.dart';
import '../../../create/create.dart';
import 'current_booru_providers.dart';

final booruConfigRepoProvider = Provider<BooruConfigRepository>(
  (ref) => throw UnimplementedError(),
);

final booruConfigProvider =
    NotifierProvider<BooruConfigNotifier, List<BooruConfig>>(
      () => throw UnimplementedError(),
      dependencies: [
        booruConfigRepoProvider,
        searchSubscriptionRepositoryProvider,
        searchSubscriptionsProvider,
        settingsProvider,
      ],
      name: 'booruConfigProvider',
    );

class BooruConfigNotifier extends Notifier<List<BooruConfig>> {
  BooruConfigNotifier({
    required this.initialConfigs,
  });

  final List<BooruConfig> initialConfigs;

  @override
  List<BooruConfig> build() {
    return initialConfigs;
  }

  Future<void> fetch() async {
    final configs = await ref.read(booruConfigRepoProvider).getAll();
    state = configs;
  }

  Future<void> _add(BooruConfig booruConfig) async {
    final orders = ref.read(settingsProvider).booruConfigIdOrderList;
    final newOrders = [...orders, booruConfig.id];

    await updateOrder(newOrders);

    state = [...state, booruConfig];
  }

  Future<void> duplicate({
    required BooruConfig config,
  }) {
    final copyData = config.copyWith(
      name: '${config.name} copy',
    );

    return add(
      data: copyData.toBooruConfigData(),
      initialConfig: config,
      isCopy: true,
    );
  }

  Future<void> delete(
    BooruConfig config, {
    void Function(String message)? onFailure,
    void Function(BooruConfig booruConfig)? onSuccess,
  }) async {
    final analyticsAsync = ref.read(analyticsProvider);
    final loginDetails = ref.read(booruLoginDetailsProvider(config.auth));

    const eventName = 'config_delete';
    final baseParams = {
      'url': config.url,
      'hint_site': config.auth.booruType.name,
      'has_login': loginDetails.hasLogin(),
    };

    try {
      await ref.read(searchSubscriptionsProvider.notifier).runSerializedMutation((
        searchRepository,
      ) async {
        final subscriptions = (await searchRepository.getAll())
            .where((subscription) => subscription.profileId == config.id)
            .toList(growable: false);
        final organization = await searchRepository.getOrganization();
        final feeds = (await searchRepository.getFeeds())
            .where((f) => f.profileId == config.id)
            .toList();
        var searchesDeleted = false;
        var profileRemoved = false;

        try {
          await searchRepository.deleteForProfile(config.id);
          searchesDeleted = true;

          // check if deleting the last config
          if (state.length == 1) {
            await ref.read(booruConfigRepoProvider).remove(config);
            profileRemoved = true;
            await ref.read(booruConfigProvider.notifier).fetch();
            // reset order
            await updateOrder([]);
            await ref.read(currentBooruConfigProvider.notifier).setEmpty();

            onSuccess?.call(config);

            analyticsAsync.whenData(
              (a) => a?.logEvent(
                eventName,
                parameters: {
                  ...baseParams,
                  'delete_type': 'last',
                },
              ),
            );

            return;
          }

          // check if deleting current config, if so, set current to the first config
          final currentConfig = ref.read(currentBooruConfigProvider);
          var deleteCurrent = false;
          var deleteFirst = false;
          if (currentConfig.id == config.id) {
            final firstConfig = state.first;

            // check if deleting the first config
            deleteFirst = firstConfig.id == config.id;
            deleteCurrent = true;

            final targetConfig = deleteFirst
                ? state.skip(1).first
                : firstConfig;

            await ref
                .read(currentBooruConfigProvider.notifier)
                .update(targetConfig);
          }

          await ref.read(booruConfigRepoProvider).remove(config);
          profileRemoved = true;
          final orders = ref.read(settingsProvider).booruConfigIdOrderList;
          final newOrders = [...orders..remove(config.id)];

          await updateOrder(newOrders);

          final tmp = [...state]..remove(config);

          state = tmp;
          onSuccess?.call(config);

          analyticsAsync.whenData(
            (a) => a?.logEvent(
              eventName,
              parameters: {
                ...baseParams,
                'delete_type': deleteCurrent
                    ? deleteFirst
                          ? 'current_first'
                          : 'current'
                    : 'normal',
              },
            ),
          );
        } catch (error, stackTrace) {
          if (searchesDeleted && !profileRemoved) {
            await _restoreProfileSubscriptions(
              config,
              searchRepository,
              subscriptions,
              organization,
              feeds,
              error,
            );
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      });
    } catch (e) {
      onFailure?.call(e.toString());
    }
  }

  Future<void> update({
    required BooruConfigData booruConfigData,
    required int oldConfigId,
    void Function(String message)? onFailure,
    void Function(BooruConfig booruConfig)? onSuccess,
  }) async {
    try {
      // Validate inputs
      if (oldConfigId < 0) {
        _logError('Invalid config id: $oldConfigId');
        onFailure?.call('Unable to find this account');
        return;
      }

      // Check if config exists
      final existingConfig = state.firstWhereOrNull((c) => c.id == oldConfigId);
      if (existingConfig == null) {
        _logError('Config not found: $oldConfigId');
        onFailure?.call('This profile no longer exists');
        return;
      }

      final oldConfig = state.firstWhereOrNull(
        (element) => element.id == oldConfigId,
      );

      final proposedConfig = booruConfigData.toBooruConfig(id: oldConfigId);
      if (proposedConfig == null) {
        onFailure?.call('Unable to update profile. Failed to save changes');
        return;
      }
      final siteChanged = !_sameBooruSite(existingConfig, proposedConfig);
      final searches = ref.read(searchSubscriptionsProvider.notifier);
      Future<BooruConfig?> save() => searches.runSerializedMutation((
        searchRepository,
      ) async {
        final oldSearches = siteChanged
            ? (await searchRepository.getAll())
                  .where((search) => search.profileId == oldConfigId)
                  .toList()
            : const <SearchSubscription>[];
        final oldFeeds = siteChanged
            ? (await searchRepository.getFeeds())
                  .where((feed) => feed.profileId == oldConfigId)
                  .toList()
            : const <SearchFollowingFeed>[];
        if (siteChanged) {
          await searchRepository.invalidateRuntimeForProfile(oldConfigId);
        }
        final configRepository = ref.read(booruConfigRepoProvider);
        BooruConfig? updated;
        try {
          updated = await configRepository.update(oldConfigId, booruConfigData);
        } catch (_) {
          updated = null;
        }
        if (updated == null && siteChanged) {
          final stored = (await configRepository.getAll()).firstWhereOrNull(
            (config) => config.id == oldConfigId,
          );
          if (stored != null && _sameBooruSite(stored, existingConfig)) {
            await searchRepository.restoreForProfile(oldConfigId, oldSearches);
            await searchRepository.restoreFeeds(oldConfigId, oldFeeds);
          } else {
            updated = stored;
          }
        }
        if (updated != null) {
          state = [
            for (final config in state)
              if (config.id == oldConfigId) updated else config,
          ];
        }
        return updated;
      });
      final updatedConfig = siteChanged
          ? await searches.runWithProfileRefreshPaused(oldConfigId, save)
          : await save();

      if (updatedConfig == null) {
        _logError('Failed to update config: $oldConfigId');
        onFailure?.call('Unable to update profile. Failed to save changes');
        return;
      }

      _logInfo('Updated config: $oldConfigId');
      onSuccess?.call(updatedConfig);

      ref
          .read(analyticsProvider)
          .whenData(
            (a) => a?.logEvent(
              'config_update',
              parameters: {
                'url': updatedConfig.url,
                'hint_site': updatedConfig.auth.booruType.name,
                'is_current': ref.readConfigAuth == updatedConfig,
              },
            ),
          );

      if (oldConfig != null) {
        ref
            .read(analyticsProvider)
            .whenData(
              (a) => a?.logConfigChangedEvent(
                oldValue: oldConfig,
                newValue: updatedConfig,
              ),
            );
      }
    } catch (e) {
      _logError('Failed to update config: $oldConfigId');
      onFailure?.call(
        'Something went wrong while updating your profile. Please try again',
      );
    }
  }

  Future<void> _restoreProfileSubscriptions(
    BooruConfig config,
    SearchSubscriptionRepository searchRepository,
    List<SearchSubscription> subscriptions,
    SearchOrganization organization,
    List<SearchFollowingFeed> feeds,
    Object originalError,
  ) async {
    try {
      await searchRepository.restoreForProfile(config.id, subscriptions);
      await searchRepository.restoreFeeds(config.id, feeds);
      await searchRepository.replaceOrganization(organization);
    } catch (restoreError) {
      _logError('Failed to remove config ${config.id}: $originalError');
      _logError(
        'Failed to restore pinned searches for config ${config.id}: '
        '$restoreError',
      );
    }
  }

  Future<void> add({
    required BooruConfigData data,
    BooruConfig? initialConfig,
    void Function(String message)? onFailure,
    void Function(BooruConfig booruConfig)? onSuccess,
    bool setAsCurrent = false,
    bool? isCopy,
  }) async {
    try {
      final config = await ref.read(booruConfigRepoProvider).add(data);

      if (config == null) {
        onFailure?.call(
          'Unable to add profile. Please check your inputs and try again',
        );

        return;
      }

      onSuccess?.call(config);

      await _add(config);

      ref
          .read(analyticsProvider)
          .whenData(
            (a) => a?.logEvent(
              'site_add',
              parameters: {
                'url': config.url,
                'total_sites': state.length,
                'hint_site': config.auth.booruType.name,
                'has_login': config.apiKey.toOption().fold(
                  () => false,
                  (a) => a.isNotEmpty,
                ),
                'is_copy': isCopy ?? false,
              },
            ),
          );

      if (initialConfig != null) {
        ref
            .read(analyticsProvider)
            .whenData(
              (a) => a?.logConfigChangedEvent(
                oldValue: initialConfig,
                newValue: config,
              ),
            );
      }

      if (setAsCurrent || state.length == 1) {
        await ref.read(currentBooruConfigProvider.notifier).update(config);
      }
    } catch (e) {
      onFailure?.call(
        'Something went wrong while adding your profile. Please try again',
      );
    }
  }

  Future<void> updateOrder(List<int> configIds) async {
    final notifier = ref.read(settingsNotifierProvider.notifier);

    await notifier.updateWith(
      (settings) => settings.copyWith(
        booruConfigIdOrders: configIds.join(' '),
      ),
    );
  }

  void reorder(
    int oldIndex,
    int newIndex,
    Iterable<BooruConfig> orderedConfigs,
  ) {
    final orders = ref.read(settingsProvider).booruConfigIdOrderList;
    final newOrders =
        orders.isEmpty || orders.length != orderedConfigs.length
              ? [for (final config in orderedConfigs) config.id]
              : orders.toList()
          ..reorder(oldIndex, newIndex);

    updateOrder(newOrders);
  }

  BooruConfig? findConfigById(int id) {
    return state.firstWhereOrNull((config) => config.id == id);
  }

  void _logError(String message) {
    ref.read(loggerProvider).error('Configs', message);
  }

  void _logInfo(String message) {
    ref.read(loggerProvider).verbose('Configs', message);
  }
}

bool _sameBooruSite(BooruConfig left, BooruConfig right) =>
    left.auth.booruType == right.auth.booruType &&
    normalizeBooruSiteUrl(left.url) == normalizeBooruSiteUrl(right.url);

extension BooruConfigNotifierX on BooruConfigNotifier {
  void addOrUpdate({
    required EditBooruConfigId id,
    required BooruConfigData newConfig,
    BooruConfig? initialData,
  }) {
    if (id.isNew) {
      ref
          .read(booruConfigProvider.notifier)
          .add(
            data: newConfig,
            initialConfig: initialData,
          );
    } else {
      ref
          .read(booruConfigProvider.notifier)
          .update(
            booruConfigData: newConfig,
            oldConfigId: id.id,
            onSuccess: (booruConfig) {
              // if edit current config, update current config
              final currentConfig = ref.read(currentBooruConfigProvider);

              if (currentConfig.id == booruConfig.id) {
                ref
                    .read(currentBooruConfigProvider.notifier)
                    .update(booruConfig);
              }
            },
          );
    }
  }
}
