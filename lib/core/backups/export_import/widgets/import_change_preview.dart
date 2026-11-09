import '../../../bookmarks/src/types/bookmark_group.dart';

import 'package:collection/collection.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../import/import_change_preview.dart';
import 'import_bounded_list.dart';
import '../../../search/following_topics/src/compatibility/topic_storage_contract.dart';

class ImportChangePreview extends StatefulWidget {
  const ImportChangePreview({
    super.key,
    required this.rows,
    required this.sourceNames,
    required this.profileNames,
  });
  final List<ImportChangePreviewRow> rows;
  final Map<String, String> sourceNames;
  final Map<String, String> profileNames;

  @override
  State<ImportChangePreview> createState() => _ImportChangePreviewState();
}

class _ImportChangePreviewState extends State<ImportChangePreview> {
  final _expanded = <Object>{};
  late Map<String, List<ImportChangePreviewRow>> _groups;
  late ImportChangeCounts _counts;
  late Map<String, ImportChangeCounts> _categoryCounts;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(ImportChangePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows.length != widget.rows.length ||
        !oldWidget.rows.indexed.every(
          (entry) => identical(entry.$2, widget.rows[entry.$1]),
        )) {
      _prepare();
    }
  }

  void _prepare() {
    _groups = groupBy(
      widget.rows,
      (row) => row.category == 'topic_folders'
          ? followingTopicsBackupSourceId
          : row.category,
    );
    _categoryCounts = {
      for (final entry in _groups.entries)
        entry.key: entry.value.fold(
          const ImportChangeCounts(),
          (sum, row) => sum + row.counts,
        ),
    };
    _counts = _categoryCounts.values.fold(
      const ImportChangeCounts(),
      (sum, counts) => sum + counts,
    );
  }

  void _recordExpansion(Object id, bool expanded) {
    if (expanded) {
      _expanded.add(id);
    } else {
      _expanded.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.backup_and_restore.export_import;
    String categoryName(String id) => switch (id) {
      'bookmarks' => strings.preview_bookmark_groups,
      'topic_folders' || followingTopicsBackupSourceId =>
        widget.sourceNames[followingTopicsBackupSourceId] ??
            strings.sources.following_topics,
      'bookmark_metadata' => strings.preview_bookmark_data,
      _ => widget.sourceNames[id] ?? id,
    };
    String rowName(ImportChangePreviewRow row) =>
        row.id == defaultBookmarkGroupId
        ? context.t.bookmark.groups.default_group
        : switch (row.label) {
            '__home' => strings.preview_home,
            '__ungrouped' => context.t.bookmark.groups.default_group,
            '__bookmark_metadata' => strings.preview_bookmark_data,
            _ =>
              row.limit == ImportPreviewLimit.database ||
                      row.limit == ImportPreviewLimit.unknown
                  ? categoryName(row.category)
                  : row.label,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          key: const ValueKey('planned-change-summary'),
          initiallyExpanded: _expanded.contains('summary'),
          onExpansionChanged: (value) => _recordExpansion('summary', value),
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.planned_changes,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _Counts(counts: _counts),
            ],
          ),
          children: [
            if (widget.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(strings.nothing_to_import),
              ),
            Builder(
              builder: (context) => Column(
                children: [
                  for (final entry in _groups.entries)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        key: ValueKey('change-category-${entry.key}'),
                        initiallyExpanded: _expanded.contains(entry.key),
                        onExpansionChanged: (value) =>
                            _recordExpansion(entry.key, value),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(categoryName(entry.key)),
                            const SizedBox(height: 8),
                            _Counts(
                              counts: _categoryCounts[entry.key]!,
                            ),
                          ],
                        ),
                        children: [
                          Builder(
                            builder: (context) => ImportBoundedList(
                              storageKey: ('import-preview', entry.key),
                              itemCount: entry.value.length,
                              itemBuilder: (context, index) {
                                final row = entry.value[index];
                                return _ChangeRow(
                                  key: ValueKey((row.category, row.id)),
                                  row: row,
                                  label: rowName(row),
                                  profileNames: widget.profileNames,
                                  expanded: _expanded,
                                  expansionKey: (
                                    entry.key,
                                    row.category,
                                    row.id,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.counts});
  final ImportChangeCounts counts;
  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.backup_and_restore.export_import;
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          strings.preview_count(n: counts.total),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final (kind, number, symbol, label) in [
          (
            ImportChangeKind.added,
            counts.added,
            '+',
            strings.preview_added.replaceAll(
              '{count}',
              counts.added.toString(),
            ),
          ),
          (
            ImportChangeKind.removed,
            counts.removed,
            '−',
            strings.preview_removed.replaceAll(
              '{count}',
              counts.removed.toString(),
            ),
          ),
          (
            ImportChangeKind.changed,
            counts.changed,
            '~',
            strings.preview_changed.replaceAll(
              '{count}',
              counts.changed.toString(),
            ),
          ),
        ])
          Tooltip(
            message: label,
            child: Semantics(
              label: label,
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _color(context, kind).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  child: Text(
                    '$symbol$number',
                    style: TextStyle(
                      color: _color(context, kind),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.row,
    required this.label,
    required this.profileNames,
    required this.expanded,
    required this.expansionKey,
    super.key,
  });
  final ImportChangePreviewRow row;
  final String label;
  final Map<String, String> profileNames;
  final Set<Object> expanded;
  final Object expansionKey;
  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.backup_and_restore.export_import;
    final profile = profileNames[row.profileId] == null
        ? null
        : safeImportDisplayValue('name', profileNames[row.profileId]);
    final symbol = switch (row.kind) {
      ImportChangeKind.added => '+',
      ImportChangeKind.removed => '−',
      ImportChangeKind.changed => '~',
    };
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.previousLabel == null ? label : '${row.previousLabel} → $label',
          style: row.kind == ImportChangeKind.changed && row.entityChanged
              ? TextStyle(color: _color(context, row.kind))
              : null,
        ),
        if (row.category == 'topic_folders' && row.id != 'home')
          Text(
            strings.preview_folder,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (profile != null)
          Text(profile, style: Theme.of(context).textTheme.bodySmall),
        if (row.isContainer) ...[
          const SizedBox(height: 8),
          _Counts(counts: row.counts),
        ],
        if (row.membershipsAdded + row.membershipsRemoved > 0)
          Wrap(
            spacing: 8,
            children: [
              if (row.membershipsAdded > 0)
                Text(
                  '+${row.membershipsAdded}',
                  style: TextStyle(
                    color: _color(context, ImportChangeKind.added),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (row.membershipsRemoved > 0)
                Text(
                  '−${row.membershipsRemoved}',
                  style: TextStyle(
                    color: _color(context, ImportChangeKind.removed),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
      ],
    );
    final leading = row.isContainer && !row.entityChanged
        ? Icon(
            row.label == '__home'
                ? Icons.home_outlined
                : row.category == topicFeedsBackupSourceId
                ? Icons.dynamic_feed_outlined
                : Icons.folder_outlined,
          )
        : Text(
            symbol,
            style: TextStyle(
              color: _color(context, row.kind),
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          );
    final limit = switch (row.limit) {
      ImportPreviewLimit.database => strings.preview_database_limit,
      ImportPreviewLimit.bookmarkMetadata => strings.preview_metadata_limit,
      ImportPreviewLimit.unknown => strings.preview_unknown_limit,
      null => null,
    };
    String detailValue(ImportChangeDetail d, String value) => switch (d.key) {
      'profileId' => safeImportDisplayValue(
        'name',
        profileNames[value] ?? strings.preview_unknown_profile,
      ),
      'position' =>
        int.tryParse(value) == null ? value : '${int.parse(value) + 1}',
      _ => value,
    };
    String detailLabel(ImportChangeDetail d) => switch (d.key) {
      'profileId' => strings.preview_profile,
      'position' => strings.preview_position,
      'query' => strings.preview_query,
      'queryOrder' => strings.preview_query_order,
      _ => d.key,
    };
    String detailText(ImportChangeDetail d) => switch (d.kind) {
      ImportChangeKind.added => '+ ${detailValue(d, d.after)}',
      ImportChangeKind.removed => '− ${detailValue(d, d.before)}',
      ImportChangeKind.changed =>
        '~ ${detailValue(d, d.before)} → ${detailValue(d, d.after)}',
    };
    Widget detail(ImportChangeDetail d, {bool showKey = true}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showKey && d.presentation != ImportDetailPresentation.query)
            Text(detailLabel(d), style: Theme.of(context).textTheme.bodySmall),
          Text(
            detailText(d),
            style: TextStyle(color: _color(context, d.kind)),
          ),
        ],
      ),
    );
    if (row.isContainer ||
        (row.details.isNotEmpty && row.category != 'settings'))
      return ExpansionTile(
        key: ValueKey('change-detail-${row.category}-${row.id}'),
        initiallyExpanded: expanded.contains(expansionKey),
        onExpansionChanged: (value) {
          if (value) {
            expanded.add(expansionKey);
          } else {
            expanded.remove(expansionKey);
          }
        },
        title: title,
        leading: leading,
        children: [
          Builder(
            builder: (context) => ImportBoundedList(
              storageKey: ('import-preview-details', expansionKey),
              itemCount: row.details.length + row.children.length,
              itemBuilder: (context, index) {
                if (index < row.details.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: detail(row.details[index]),
                  );
                }
                final child = row.children[index - row.details.length];
                return Padding(
                  key: ValueKey((child.category, child.id)),
                  padding: const EdgeInsets.only(left: 12),
                  child: _ChangeRow(
                    row: child,
                    label: child.label,
                    profileNames: profileNames,
                    expanded: expanded,
                    expansionKey: (expansionKey, child.category, child.id),
                  ),
                );
              },
            ),
          ),
        ],
      );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (limit != null)
                  Text(limit, style: Theme.of(context).textTheme.bodySmall),
                for (final d in row.details)
                  Text(
                    detailText(d),
                    style: TextStyle(
                      color: _color(context, d.kind),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _color(BuildContext context, ImportChangeKind kind) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (kind) {
    ImportChangeKind.added =>
      dark ? Colors.green.shade300 : Colors.green.shade800,
    ImportChangeKind.removed =>
      dark ? Colors.red.shade300 : Colors.red.shade800,
    ImportChangeKind.changed =>
      dark ? Colors.blue.shade300 : Colors.blue.shade800,
  };
}
