// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import 'models/export_template.dart';

const _templatesKey = 'export_import:templates';

class ExportTemplateRepository {
  const ExportTemplateRepository(this._box);

  final Box<dynamic> _box;

  List<ExportTemplate> load() {
    final raw = _box.get(_templatesKey);
    if (raw == null) return const [];
    if (raw is! List<dynamic>) {
      throw const FormatException('Invalid stored export templates');
    }
    return List.unmodifiable(
      raw.map((value) {
        if (value is! Map) {
          throw const FormatException('Invalid stored export template');
        }
        return ExportTemplate.fromJson(_normalizeMap(value));
      }),
    );
  }

  Future<void> save(ExportTemplate template) async {
    final templates = load();
    if (templates.any((current) => current.id == template.id)) {
      throw StateError('An export template with this ID already exists');
    }
    await _write([...templates, template]);
  }

  Future<void> replace(ExportTemplate template) async {
    final templates = load();
    final index = templates.indexWhere((current) => current.id == template.id);
    if (index < 0) throw StateError('Export template does not exist');
    final updated = templates.toList()..[index] = template;
    await _write(updated);
  }

  Future<void> delete(String id) async {
    await _write(load().where((template) => template.id != id).toList());
  }

  Future<void> _write(List<ExportTemplate> templates) => _box.put(
    _templatesKey,
    templates.map((template) => template.toJson()).toList(),
  );
}

Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> value) {
  final normalized = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException('Invalid stored export template key');
    }
    normalized[key] = _normalizeValue(entry.value);
  }
  return normalized;
}

dynamic _normalizeValue(dynamic value) => switch (value) {
  null => null,
  Map<dynamic, dynamic>() => _normalizeMap(value),
  List<dynamic>() => value.map(_normalizeValue).toList(growable: false),
  _ => value,
};
