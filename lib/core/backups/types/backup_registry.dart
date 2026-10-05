// Package imports:
import 'package:collection/collection.dart';

// Project imports:
import '../export_import/models/export_selection.dart';
import 'backup_data_source.dart';

class BackupRegistry implements ExportSourceCatalog {
  final Map<String, BackupDataSource> _sources = {};
  final Map<String, ExportSelectionDescriptor> _descriptors = {};

  void register(BackupDataSource source) {
    _sources[source.id] = source;
    _descriptors[source.id] = switch (source) {
      final BackupSelectionDataSource described =>
        described.selectionDescriptor,
      _ => ExportSelectionDescriptor.leaf(id: source.id),
    };
  }

  void registerDescriptor(ExportSelectionDescriptor descriptor) {
    _descriptors[descriptor.id] = descriptor;
  }

  @override
  List<ExportSelectionDescriptor> get selectionDescriptors =>
      _descriptors.values.toList(growable: false);

  List<BackupDataSource> getAllSources() {
    return _sources.values.sorted((a, b) => a.priority.compareTo(b.priority));
  }

  BackupDataSource? getSource(String id) {
    return _sources[id];
  }

  bool hasSource(String id) {
    return _sources.containsKey(id);
  }
}
