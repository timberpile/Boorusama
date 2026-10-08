// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../../foundation/loggers/providers.dart';
import '../../../analytics/providers.dart';
import '../../../analytics/types.dart';
import '../data/providers.dart';
import '../types/settings.dart';

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, Settings>(
  () => throw UnimplementedError(),
  name: 'settingsNotifierProvider',
);

final initialSettingsProvider = Provider<Settings>(
  (ref) => throw UnimplementedError(),
  name: 'initialSettingsProvider',
);

class SettingsNotifier extends Notifier<Settings> {
  SettingsNotifier(this.initialSettings);

  final Settings initialSettings;
  var _writeTail = Future<void>.value();

  @override
  Settings build() {
    return initialSettings;
  }

  Future<bool> updateWith(
    Settings Function(Settings) selector,
  ) => _enqueue(selector);

  Future<bool> replaceSettings(Settings settings) => _enqueue((_) => settings);

  Future<bool> _enqueue(Settings Function(Settings) selector) {
    final result = _writeTail.then(
      (_) => ref
          .read(dataMutationCoordinatorProvider)
          .runExclusive(() => _updateSettings(selector(state))),
    );
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<bool> _updateSettings(Settings settings) async {
    final currentSettings = state;
    final success = await ref.read(settingsRepoProvider).save(settings);

    if (success) {
      for (var i = 0; i < currentSettings.props.length; i++) {
        final cs = currentSettings.props[i];
        final ns = settings.props[i];

        if (cs != ns) {
          ref
              .read(loggerProvider)
              .verbose(
                'Settings',
                'Settings updated: ${cs.runtimeType} $cs -> $ns',
              );
        }
      }
      state = settings;

      ref
          .read(analyticsProvider)
          .whenData(
            (a) => a?.logSettingsChangedEvent(
              oldValue: currentSettings,
              newValue: settings,
            ),
          );
    }

    return success;
  }
}
