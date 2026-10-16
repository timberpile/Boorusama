import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/providers.dart';
import '../providers/search_options_provider.dart';
import '../types/search_option.dart';

class SharedSearchOptionsSection extends ConsumerWidget {
  const SharedSearchOptionsSection({required this.onTagAdded, super.key});
  final ValueChanged<String> onTagAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(searchOptionsProvider(ref.watchConfigAuth));
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ActionChip(
              label: Text(searchOptionLabel(context, option.kind)),
              onPressed: () async {
                final query = await showDialog<String>(
                  context: context,
                  routeSettings: const RouteSettings(name: 'search_option'),
                  builder: (_) => SearchOptionDialog(option: option),
                );
                if (query != null && context.mounted) onTagAdded(query);
              },
            ),
        ],
      ),
    );
  }
}

String searchOptionLabel(BuildContext context, SearchOptionKind kind) {
  final strings = context.t.search.options;
  return switch (kind) {
    SearchOptionKind.rating => strings.rating,
    SearchOptionKind.date => strings.date,
    SearchOptionKind.order => strings.order,
    SearchOptionKind.user => strings.user,
    SearchOptionKind.pool => strings.pool,
    SearchOptionKind.favorites => strings.favorites,
  };
}

class SearchOptionDialog extends StatefulWidget {
  const SearchOptionDialog({required this.option, super.key});
  final SearchOption option;

  @override
  State<SearchOptionDialog> createState() => _SearchOptionDialogState();
}

class _SearchOptionDialogState extends State<SearchOptionDialog> {
  var _value = '';

  void _submit() {
    final query = widget.option.compose(_value);
    if (query != null) Navigator.of(context).pop(query);
  }

  String _choiceLabel(String value) {
    final strings = context.t.search.options;
    return switch (widget.option.valueLabels[value]) {
      SearchOptionValueLabel.safe => strings.safe,
      SearchOptionValueLabel.sensitive => strings.sensitive,
      SearchOptionValueLabel.questionable => strings.questionable,
      SearchOptionValueLabel.explicit => strings.explicit,
      SearchOptionValueLabel.general => strings.general,
      SearchOptionValueLabel.newest => strings.newest,
      SearchOptionValueLabel.score => strings.score,
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final label = searchOptionLabel(context, option.kind);
    return AlertDialog(
      title: Text(label),
      content: SingleChildScrollView(
        child: option.values.isEmpty
            ? KurumiTextField(
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: option.kind == SearchOptionKind.date
                      ? context.t.search.options.date_hint
                      : null,
                ),
                onChanged: (value) => setState(() => _value = value),
                onSubmitted: (_) => _submit(),
              )
            : DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  for (final value in option.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_choiceLabel(value)),
                    ),
                ],
                onChanged: (value) => setState(() => _value = value ?? ''),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed: option.compose(_value) == null ? null : _submit,
          child: Text(context.t.generic.action.add),
        ),
      ],
    );
  }
}
