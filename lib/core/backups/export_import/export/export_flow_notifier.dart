import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import '../../../../foundation/info/package_info.dart';
import '../../../bookmarks/providers.dart';
import '../../../configs/manage/providers.dart';
import '../../../search/subscriptions/providers.dart';
import '../../sources/providers.dart';
import '../models/export_selection.dart';
import '../models/export_item_presentation.dart';
import '../models/export_template.dart';
import '../models/import_action.dart';
import '../package/export_package_writer.dart';
import '../template_repository.dart';
import 'export_filename.dart';
import 'export_service.dart';

final class ExportSelectionLabels {
  const ExportSelectionLabels({required this.children});

  final Map<String, String> children;
}

final exportSelectionPresentationProvider =
    Provider<ExportSelectionPresentation>((ref) {
      final items = <String, ExportItemPresentation>{};
      final profileNames = {
        for (final profile in ref.watch(booruConfigProvider))
          profile.id: profile.name,
      };
      for (final profile in ref.watch(booruConfigProvider)) {
        items['profile:${profile.id}'] = ExportItemPresentation(
          label: profile.name,
        );
      }
      for (final group
          in ref.watch(bookmarkProvider).valueOrNull?.groups ?? const []) {
        items['group:${group.id}'] = ExportItemPresentation(label: group.name);
      }
      final searches = ref.watch(searchSubscriptionsProvider).valueOrNull;
      for (final folder in searches?.organization.folders ?? const []) {
        items['folder:${folder.id}'] = ExportItemPresentation(
          label: folder.name,
        );
      }
      for (final search in searches?.subscriptions ?? const []) {
        items['search:${search.id}'] = ExportItemPresentation(
          label: search.displayName,
          trailingLabel: profileNames[search.profileId],
        );
      }
      for (final feed in searches?.feeds ?? const []) {
        items['feed:${feed.id}'] = ExportItemPresentation(
          label: feed.name,
          trailingLabel: profileNames[feed.profileId],
        );
      }
      return ExportSelectionPresentation(items: Map.unmodifiable(items));
    });

final exportSelectionLabelsProvider = Provider<ExportSelectionLabels>((ref) {
  final presentation = ref.watch(exportSelectionPresentationProvider);
  return ExportSelectionLabels(
    children: Map.unmodifiable({
      for (final entry in presentation.items.entries)
        entry.key: entry.value.label,
    }),
  );
});

enum ExportFlowStatus { choosing, creating, ready, error }

final class ExportFlowState {
  const ExportFlowState({
    required this.isFull,
    required this.nodes,
    required this.includeCredentials,
    required this.status,
    this.recommendedActions = const {},
    this.itemRecommendedActions = const {},
    this.packagePath,
    this.error,
  });

  const ExportFlowState.initial()
    : isFull = true,
      nodes = const {},
      includeCredentials = true,
      status = ExportFlowStatus.choosing,
      recommendedActions = const {},
      itemRecommendedActions = const {},
      packagePath = null,
      error = null;

  final bool isFull;
  final Map<String, ExportNodeSelection> nodes;
  final bool includeCredentials;
  final ExportFlowStatus status;
  final Map<String, ImportAction> recommendedActions;
  final Map<String, Map<String, ImportAction>> itemRecommendedActions;
  final String? packagePath;
  final Object? error;

  ExportFlowState copyWith({
    bool? isFull,
    Map<String, ExportNodeSelection>? nodes,
    bool? includeCredentials,
    ExportFlowStatus? status,
    Map<String, ImportAction>? recommendedActions,
    Map<String, Map<String, ImportAction>>? itemRecommendedActions,
    String? packagePath,
    Object? error,
    bool clearResult = false,
  }) => ExportFlowState(
    isFull: isFull ?? this.isFull,
    nodes: Map.unmodifiable(nodes ?? this.nodes),
    includeCredentials: includeCredentials ?? this.includeCredentials,
    status: status ?? this.status,
    recommendedActions: Map.unmodifiable(
      recommendedActions ?? this.recommendedActions,
    ),
    itemRecommendedActions: Map.unmodifiable(
      itemRecommendedActions ?? this.itemRecommendedActions,
    ),
    packagePath: clearResult ? null : packagePath ?? this.packagePath,
    error: clearResult ? null : error ?? this.error,
  );
}

final exportServiceProvider = Provider<ExportService>((ref) {
  final fs = ref.watch(appFileSystemProvider);
  return ExportService(
    sources: () => ref.read(exportImportSourcesProvider),
    writer: ExportPackageWriter(fs: fs),
    appVersion: ref.watch(appVersionProvider)?.toString() ?? 'unknown',
  );
});

final exportFlowProvider =
    NotifierProvider.autoDispose<ExportFlowNotifier, ExportFlowState>(
      ExportFlowNotifier.new,
    );

class ExportFlowNotifier extends AutoDisposeNotifier<ExportFlowState> {
  @override
  ExportFlowState build() {
    ref.watch(exportImportSourcesProvider);
    return const ExportFlowState.initial();
  }

  List<ExportSelectionDescriptor> get descriptors => [
    for (final source in ref.read(exportImportSourcesProvider))
      source.selectionDescriptor,
  ];

  void useFullExport() => state = state.copyWith(
    isFull: true,
    includeCredentials: true,
    recommendedActions: const {},
    itemRecommendedActions: const {},
    clearResult: true,
    status: ExportFlowStatus.choosing,
  );

  void useCustomExport() => state = state.copyWith(
    isFull: false,
    includeCredentials: false,
    recommendedActions: const {},
    itemRecommendedActions: const {},
    clearResult: true,
    status: ExportFlowStatus.choosing,
  );

  void toggleSource(ExportSelectionDescriptor descriptor) {
    final nodes = {...state.nodes};
    if (nodes.remove(descriptor.id) == null) {
      nodes[descriptor.id] = descriptor.isCollection
          ? ExportNodeSelection.all(descriptor.id)
          : ExportNodeSelection.leaf(descriptor.id);
    }
    state = state.copyWith(nodes: nodes, clearResult: true);
  }

  void toggleChild(ExportSelectionDescriptor descriptor, String childId) {
    final node = descriptor.findNode(childId);
    if (node != null) toggleNode(descriptor, node);
  }

  void toggleNode(
    ExportSelectionDescriptor descriptor,
    ExportSelectionNode node,
  ) {
    final current = state.nodes[descriptor.id];
    final selected = switch (current?.kind) {
      ExportNodeSelectionKind.all => {
        for (final root in descriptor.rootNodes) root.id,
      },
      ExportNodeSelectionKind.explicit => current!.childIds.toSet(),
      null => <String>{},
    };
    final effective = current?.resolve(descriptor) ?? const <String>{};
    if (effective.intersection(node.allIds).isNotEmpty) {
      final roots = switch (current?.kind) {
        ExportNodeSelectionKind.all => descriptor.rootNodes,
        _ => [
          for (final id in selected) ?descriptor.findNode(id),
        ],
      };
      selected
        ..clear()
        ..addAll(_excludingNode(roots, node.id));
    } else {
      selected
        ..removeAll(node.descendantIds)
        ..add(node.id);
    }
    final nodes = {...state.nodes};
    if (selected.isEmpty) {
      nodes.remove(descriptor.id);
    } else {
      nodes[descriptor.id] = ExportNodeSelection.explicit(
        descriptor.id,
        selected,
      );
    }
    state = state.copyWith(nodes: nodes, clearResult: true);
  }

  Set<String> _excludingNode(
    Iterable<ExportSelectionNode> selectedRoots,
    String excludedId,
  ) => {
    for (final root in selectedRoots)
      ..._selectedRootsWithout(root, excludedId),
  };

  Iterable<String> _selectedRootsWithout(
    ExportSelectionNode node,
    String excludedId,
  ) sync* {
    if (node.id == excludedId) return;
    if (!node.contains(excludedId)) {
      yield node.id;
      return;
    }
    for (final child in node.children) {
      yield* _selectedRootsWithout(child, excludedId);
    }
  }

  void setIncludeCredentials(bool value) {
    if (state.isFull || !state.nodes.containsKey('profiles')) return;
    state = state.copyWith(includeCredentials: value, clearResult: true);
  }

  void setItemRecommendedAction(
    String sourceId,
    String itemId,
    ImportAction? action,
  ) {
    final sourceActions = {...?state.itemRecommendedActions[sourceId]};
    if (action == null) {
      sourceActions.remove(itemId);
    } else {
      sourceActions[itemId] = action;
    }
    final actions = {...state.itemRecommendedActions};
    if (sourceActions.isEmpty) {
      actions.remove(sourceId);
    } else {
      actions[sourceId] = Map.unmodifiable(sourceActions);
    }
    state = state.copyWith(itemRecommendedActions: actions, clearResult: true);
  }

  void applyTemplate(ExportTemplate template) {
    state = state.copyWith(
      isFull: false,
      nodes: template.selection.nodes,
      includeCredentials: template.includeCredentials,
      recommendedActions: template.recommendedActions,
      itemRecommendedActions: template.itemRecommendedActions,
      status: ExportFlowStatus.choosing,
      clearResult: true,
    );
  }

  void editSelection() => state = state.copyWith(
    status: ExportFlowStatus.choosing,
    clearResult: true,
  );

  ExportSelection selection() => state.isFull
      ? ExportSelection.full(_Catalog(descriptors))
      : ExportSelection.custom(state.nodes);

  Future<String> createExport() async {
    if (!state.isFull && state.nodes.isEmpty) {
      throw StateError('No data selected');
    }
    state = state.copyWith(
      status: ExportFlowStatus.creating,
      clearResult: true,
    );
    try {
      final directory = await ref
          .read(appFileSystemProvider)
          .createTempDirectory('boorusama_export_');
      final outputPath = p.join(directory, exportFileName(DateTime.now()));
      final path = await ref
          .read(exportServiceProvider)
          .createPackage(
            ExportRequest(
              selection: selection(),
              outputPath: outputPath,
              includeCredentials: state.includeCredentials,
              recommendedActions: state.isFull
                  ? {
                      for (final descriptor in descriptors)
                        descriptor.id: ImportAction.replace,
                    }
                  : state.recommendedActions,
              itemRecommendedActions: state.itemRecommendedActions,
            ),
          );
      state = state.copyWith(status: ExportFlowStatus.ready, packagePath: path);
      return path;
    } catch (error) {
      state = state.copyWith(status: ExportFlowStatus.error, error: error);
      rethrow;
    }
  }
}

final class _Catalog implements ExportSourceCatalog {
  const _Catalog(this.selectionDescriptors);

  @override
  final List<ExportSelectionDescriptor> selectionDescriptors;
}

final exportTemplatesProvider =
    AsyncNotifierProvider<ExportTemplatesNotifier, List<ExportTemplate>>(
      ExportTemplatesNotifier.new,
    );

class ExportTemplatesNotifier extends AsyncNotifier<List<ExportTemplate>> {
  late ExportTemplateRepository _repository;

  @override
  Future<List<ExportTemplate>> build() async {
    final box = await Hive.openBox<dynamic>('export_import_v1');
    _repository = ExportTemplateRepository(box);
    return _repository.load();
  }

  Future<void> save(ExportTemplate template) async {
    await _repository.save(template);
    state = AsyncData(_repository.load());
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = AsyncData(_repository.load());
  }
}
