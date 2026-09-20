// Package imports:
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../settings/providers.dart';
import '../../../settings/types.dart';
import '../../preparation/version_checking.dart';
import '../../preparation/preparation_pipeline.dart';
import '../../sources/pinned_search_import_preflight.dart';
import '../../sources/pinned_searches_source.dart';
import '../../sources/providers.dart';
import '../../types/types.dart';

final exportCategoriesProvider = Provider<List<ExportCategory>>((ref) {
  // Ensure all backup sources are registered
  ref.watch(allBackupSourcesProvider);

  final registry = ref.watch(backupRegistryProvider);

  // Get categories from the registry system
  final registryCategories = registry
      .getAllSources()
      .map(
        (source) => ExportCategory(
          name: source.id,
          displayName: source.displayName,
          route: source.id,
          handler: source.capabilities.server.export,
        ),
      )
      .toList();

  return registryCategories;
});

final importDataProvider = NotifierProvider.autoDispose
    .family<ImportDataNotifier, ImportDataState, String>(
      ImportDataNotifier.new,
    );

final serverCheckProvider = NotifierProvider.autoDispose
    .family<ServerCheckNotifier, ServerCheckStatus, String>(
      ServerCheckNotifier.new,
    );

enum ServerCheckStatus {
  initial,
  checking,
  available,
  unavailable,
}

class ServerCheckNotifier
    extends AutoDisposeFamilyNotifier<ServerCheckStatus, String> {
  @override
  ServerCheckStatus build(String arg) {
    return ServerCheckStatus.initial;
  }

  Future<void> check() async {
    state = ServerCheckStatus.checking;

    final startTime = DateTime.now();

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: arg,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final res = await dio.get('/health');
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      // Artificial delay to make sure things don't fly by too fast
      if (elapsed < 500) {
        await Future.delayed(Duration(milliseconds: 500 - elapsed));
      }

      final available = res.statusCode == 204;
      state = available
          ? ServerCheckStatus.available
          : ServerCheckStatus.unavailable;
    } catch (_) {
      state = ServerCheckStatus.unavailable;
    }
  }
}

enum SelectStatus {
  unslected,
  selected,
}

sealed class ImportStatus {
  const ImportStatus();
}

final class ImportNotStarted extends ImportStatus {
  const ImportNotStarted();
}

final class Importing extends ImportStatus {
  const Importing();
}

final class ImportQueued extends ImportStatus {
  const ImportQueued();
}

final class ImportDone extends ImportStatus {
  const ImportDone();
}

final class ImportError extends ImportStatus {
  const ImportError(this.message);

  final String message;
}

enum ImportStep {
  selection,
  importing,
  done,
}

class ReloadPayload extends Equatable {
  const ReloadPayload({
    required this.configs,
    required this.selectedConfig,
    this.settings,
  });

  final List<BooruConfig> configs;
  final BooruConfig selectedConfig;
  final Settings? settings;

  ReloadPayload copyWith({
    List<BooruConfig>? configs,
    BooruConfig? selectedConfig,
    Settings? Function()? settings,
  }) {
    return ReloadPayload(
      configs: configs ?? this.configs,
      selectedConfig: selectedConfig ?? this.selectedConfig,
      settings: settings != null ? settings() : this.settings,
    );
  }

  @override
  List<Object?> get props => [configs, selectedConfig, settings];
}

class ImportTask extends Equatable {
  const ImportTask({
    required this.id,
    required this.name,
    required this.status,
    required this.importStatus,
  });

  final String id;
  final String name;
  final SelectStatus status;
  final ImportStatus importStatus;

  ImportTask copyWith({
    String? id,
    String? name,
    SelectStatus? status,
    ImportStatus? importStatus,
  }) {
    return ImportTask(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      importStatus: importStatus ?? this.importStatus,
    );
  }

  @override
  List<Object?> get props => [id, name, status, importStatus];
}

class ImportDataState extends Equatable {
  const ImportDataState({
    required this.tasks,
    required this.step,
    required this.reloadPayload,
    required this.forceReload,
  });

  final List<ImportTask> tasks;
  final ImportStep step;
  final ReloadPayload? reloadPayload;
  final bool forceReload;

  bool get atLeastOneSelected =>
      tasks.any((element) => element.status == SelectStatus.selected);

  ImportDataState copyWith({
    List<ImportTask>? tasks,
    ImportStep? step,
    ReloadPayload? Function()? reloadPayload,
    bool? forceReload,
  }) {
    return ImportDataState(
      tasks: tasks ?? this.tasks,
      step: step ?? this.step,
      reloadPayload: reloadPayload != null
          ? reloadPayload()
          : this.reloadPayload,
      forceReload: forceReload ?? this.forceReload,
    );
  }

  @override
  List<Object?> get props => [
    tasks,
    step,
    reloadPayload,
    forceReload,
  ];
}

class ImportDataNotifier
    extends AutoDisposeFamilyNotifier<ImportDataState, String> {
  @override
  ImportDataState build(String arg) {
    return ImportDataState(
      step: ImportStep.selection,
      reloadPayload: null,
      forceReload: false,
      tasks: ref.watch(exportCategoriesProvider).map((category) {
        return ImportTask(
          id: category.name,
          name: category.displayName,
          status: SelectStatus.selected,
          importStatus: const ImportNotStarted(),
        );
      }).toList(),
    );
  }

  Future<void> startImport(BuildContext uiContext) async {
    state = state.copyWith(
      step: ImportStep.importing,
    );

    final selectedTasks = state.tasks.where((element) {
      return element.status == SelectStatus.selected;
    });

    if (selectedTasks.isEmpty) {
      state = state.copyWith(step: ImportStep.done);
      return;
    }

    final registry = ref.read(backupRegistryProvider);
    final orderedTasks = selectedTasks.toList()
      ..sort(
        (a, b) => (registry.getSource(a.id)?.priority ?? 0).compareTo(
          registry.getSource(b.id)?.priority ?? 0,
        ),
      );
    final prepared = <String, ImportPreparation>{};
    final importedTaskIds = <String>{};
    void updateTask(String id, ImportStatus status) {
      state = state.copyWith(
        tasks: [
          for (final task in state.tasks)
            if (task.id == id) task.copyWith(importStatus: status) else task,
        ],
      );
    }

    void cancelPending() {
      for (final task in orderedTasks) {
        if (!importedTaskIds.contains(task.id)) {
          updateTask(task.id, const ImportNotStarted());
        }
      }
      state = state.copyWith(step: ImportStep.selection);
    }

    for (final task in orderedTasks) {
      updateTask(task.id, const ImportQueued());
    }
    try {
      for (final task in orderedTasks) {
        if (!uiContext.mounted) throw const ImportCancelledException();
        try {
          final source = registry.getSource(task.id);
          if (source == null) {
            throw StateError('Unknown backup source: ${task.id}');
          }
          prepared[task.id] = await source.capabilities.server.prepareImport(
            arg,
            uiContext,
          );
        } on ImportCancelledException {
          rethrow;
        } catch (e) {
          updateTask(task.id, ImportError(e.toString()));
        }
      }
      if (!uiContext.mounted) throw const ImportCancelledException();
      final pinnedSource = registry.getSource('pinned_searches');
      final approval = pinnedSource is PinnedSearchesBackupSource
          ? await preflightPinnedSearches(
              prepared: prepared,
              selectedIds: orderedTasks.map((task) => task.id).toSet(),
              pinnedSource: pinnedSource,
              currentProfiles: () => ref.read(booruConfigRepoProvider).getAll(),
              context: uiContext,
            )
          : null;
      for (final task in orderedTasks) {
        final preparation = prepared[task.id];
        if (preparation == null) continue;
        if (!uiContext.mounted) throw const ImportCancelledException();
        updateTask(task.id, const Importing());
        try {
          await preparation.executeImport(
            deferRestart: true,
            approval: task.id == 'pinned_searches' ? approval : null,
          );
          importedTaskIds.add(task.id);
          updateTask(task.id, const ImportDone());
        } on ImportCancelledException {
          rethrow;
        } catch (e) {
          updateTask(task.id, ImportError(e.toString()));
          if (task.id == 'profiles' &&
              prepared.containsKey('pinned_searches')) {
            updateTask('pinned_searches', ImportError(e.toString()));
            break;
          }
        }
      }
    } on ImportCancelledException {
      cancelPending();
      return;
    } catch (e) {
      for (final task in orderedTasks) {
        if (!importedTaskIds.contains(task.id)) {
          updateTask(task.id, ImportError(e.toString()));
        }
      }
    }

    if (importedTaskIds.contains('profiles')) {
      final configRepo = ref.read(booruConfigRepoProvider);
      final configs = await configRepo.getAll();

      if (configs.isNotEmpty) {
        state = state.copyWith(
          reloadPayload: () => ReloadPayload(
            configs: configs,
            selectedConfig: configs.first,
            settings: ref.read(settingsProvider),
          ),
        );
      }
    }
  }

  void toggleTask(String id) {
    final task = state.tasks.firstWhereOrNull((element) => element.id == id);

    if (task == null) return;

    final newTask = task.copyWith(
      status: task.status == SelectStatus.selected
          ? SelectStatus.unslected
          : SelectStatus.selected,
    );

    state = state.copyWith(
      tasks: [
        for (final tsk in state.tasks)
          if (tsk.id == id) newTask else tsk,
      ],
    );
  }

  void selectAllTasks() {
    state = state.copyWith(
      tasks: state.tasks
          .map(
            (task) => task.copyWith(
              status: SelectStatus.selected,
            ),
          )
          .toList(),
    );
  }

  void deselectAllTasks() {
    state = state.copyWith(
      tasks: state.tasks
          .map(
            (task) => task.copyWith(
              status: SelectStatus.unslected,
            ),
          )
          .toList(),
    );
  }
}
