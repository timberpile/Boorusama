// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../search/search/widgets.dart';
import '../providers/favorite_tags_notifier.dart';

class FavoriteTagLabelsPage extends ConsumerStatefulWidget {
  const FavoriteTagLabelsPage({super.key});

  @override
  ConsumerState<FavoriteTagLabelsPage> createState() =>
      _FavoriteTagLabelsPageState();
}

class _FavoriteTagLabelsPageState extends ConsumerState<FavoriteTagLabelsPage> {
  var query = '';

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(favoriteTagsProvider);
    final labels = ref.watch(favoriteTagLabelsProvider);
    final normalizedQuery = query.toLowerCase();
    final filteredLabels = labels
        .where((label) => label.toLowerCase().contains(normalizedQuery))
        .toList();

    return Scaffold(
      appBar: KurumiAppBar(title: Text(context.t.favorite_tags.labels.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: BooruSearchBar(
                    hintText: context.t.favorite_tags.labels.search_hint,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Symbols.search),
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                Expanded(
                  child: filteredLabels.isEmpty
                      ? Center(
                          child: Text(
                            labels.isEmpty
                                ? context.t.favorite_tags.labels.empty
                                : context.t.favorite_tags.labels.no_match,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Kurumi.themeOf(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: filteredLabels.length,
                          itemBuilder: (context, index) {
                            final label = filteredLabels[index];
                            final count = tags
                                .where(
                                  (tag) => tag.labels?.contains(label) ?? false,
                                )
                                .length;
                            return _LabelTile(
                              label: label,
                              count: count,
                              allLabels: labels,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelTile extends ConsumerWidget {
  const _LabelTile({
    required this.label,
    required this.count,
    required this.allLabels,
  });

  final String label;
  final int count;
  final List<String> allLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(label),
      subtitle: Text(
        context.t.favorite_tags.labels.favorite_count(n: count),
      ),
      trailing: KurumiPopupMenuButton(
        items: [
          KurumiPopupMenuItem(
            title: Text(context.t.favorite_tags.labels.rename),
            icon: const Icon(Symbols.edit),
            onTap: () => _rename(context, ref),
          ),
          if (allLabels.length > 1)
            KurumiPopupMenuItem(
              title: Text(context.t.favorite_tags.labels.merge_into),
              icon: const Icon(Symbols.merge),
              onTap: () => _merge(context, ref),
            ),
          KurumiPopupMenuItem(
            title: Text(context.t.favorite_tags.labels.remove_from_all),
            icon: const Icon(Symbols.label_off),
            onTap: () => _remove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final newLabel = await Kurumi.showAppModalBottomSheet<String>(
      context: context,
      routeSettings: const RouteSettings(name: 'rename_favorite_tag_label'),
      resizeToAvoidBottomInset: true,
      showDragHandle: false,
      builder: (context) => _RenameLabelSheet(
        initialValue: label,
      ),
    );

    if (newLabel == null || newLabel.trim().isEmpty) return;
    await ref.read(favoriteTagsProvider.notifier).renameLabel(label, newLabel);
  }

  Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final target = await Kurumi.showAppModalBottomSheet<String>(
      context: context,
      routeSettings: const RouteSettings(name: 'merge_favorite_tag_label'),
      showDragHandle: false,
      builder: (context) => _MergeLabelSheet(
        sourceLabel: label,
        candidates: allLabels.where((candidate) => candidate != label).toList(),
      ),
    );

    if (target == null) return;
    await ref.read(favoriteTagsProvider.notifier).mergeLabel(label, target);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: 'remove_favorite_tag_label'),
      builder: (context) => _RemoveLabelDialog(
        label: label,
        favoriteCount: count,
      ),
    );

    if (confirmed != true) return;
    await ref.read(favoriteTagsProvider.notifier).removeLabelFromAll(label);
  }
}

class _RemoveLabelDialog extends StatelessWidget {
  const _RemoveLabelDialog({
    required this.label,
    required this.favoriteCount,
  });

  final String label;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    return KurumiDialog(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t.favorite_tags.labels.remove_title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.t.favorite_tags.labels.remove_description(
                n: favoriteCount,
                label: label,
              ),
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                shadowColor: Colors.transparent,
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  context.t.favorite_tags.labels.remove_title,
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  context.t.generic.action.cancel,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RenameLabelSheet extends StatefulWidget {
  const _RenameLabelSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameLabelSheet> createState() => _RenameLabelSheetState();
}

class _RenameLabelSheetState extends State<_RenameLabelSheet> {
  late final controller = TextEditingController(text: widget.initialValue);
  late var value = widget.initialValue;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KurumiBottomSheetHeader(
          title: context.t.favorite_tags.labels.rename_title,
          closeTooltip: context.t.generic.action.cancel,
          confirmTooltip: context.t.favorite_tags.labels.rename,
          onClose: () => Navigator.of(context).pop(),
          onConfirm: value.trim().isEmpty ? null : _submit,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: KurumiTextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (newValue) => setState(() => value = newValue),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: context.t.favorite_tags.labels.label_hint,
            ),
          ),
        ),
      ],
    );
  }
}

class _MergeLabelSheet extends StatefulWidget {
  const _MergeLabelSheet({
    required this.sourceLabel,
    required this.candidates,
  });

  final String sourceLabel;
  final List<String> candidates;

  @override
  State<_MergeLabelSheet> createState() => _MergeLabelSheetState();
}

class _MergeLabelSheetState extends State<_MergeLabelSheet> {
  String? selectedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KurumiBottomSheetHeader(
          title: context.t.favorite_tags.labels.merge_title,
          closeTooltip: context.t.generic.action.cancel,
          confirmTooltip: context.t.favorite_tags.labels.merge,
          onClose: () => Navigator.of(context).pop(),
          onConfirm: selectedLabel == null
              ? null
              : () => Navigator.of(context).pop(selectedLabel),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.t.favorite_tags.labels.merge_source_into(
              label: widget.sourceLabel,
            ),
            style: Kurumi.themeOf(context).textTheme.bodyMedium?.copyWith(
              color: Kurumi.themeOf(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        KurumiSettingsCard(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          padding: EdgeInsets.zero,
          surface: KurumiSettingsCardSurface.high,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var index = 0;
                index < widget.candidates.length;
                index++
              ) ...[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  title: Text(widget.candidates[index]),
                  trailing: selectedLabel == widget.candidates[index]
                      ? Icon(
                          Icons.check_rounded,
                          color: Kurumi.themeOf(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => setState(
                    () => selectedLabel = widget.candidates[index],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
