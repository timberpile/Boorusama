import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import 'labels.dart';
import 'search_modal_back_handler.dart';
import 'search_option.dart';
import 'search_option_choices.dart';
import 'search_option_defaults.dart';
import 'search_option_value_input.dart';

Future<String?> showSearchOptionEditor(
  BuildContext context, {
  required SearchOption option,
  String? initialValue,
  bool exclude = false,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final config = container.read(currentReadOnlyBooruConfigAuthProvider);
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: SearchModalBackHandler(
        child: SafeArea(
          top: false,
          child: SearchOptionEditor(
            option: option,
            initialValue: initialValue,
            exclude: exclude,
            config: config,
          ),
        ),
      ),
    ),
  );
}

class SearchOptionFreeBadge extends StatelessWidget {
  const SearchOptionFreeBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Kurumi.themeOf(context).colorScheme;
    return Tooltip(
      message: context.t.search_options.free_hint,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          context.t.search_options.free,
          style: Kurumi.themeOf(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Apply is the only mutation boundary. Back, barrier taps and Cancel return
/// null, preserving the underlying editor and committed query.
class SearchOptionEditor extends StatefulWidget {
  const SearchOptionEditor({
    required this.option,
    this.initialValue,
    this.exclude = false,
    this.config,
    super.key,
  });
  final SearchOption option;
  final String? initialValue;
  final bool exclude;
  final BooruConfigAuth? config;
  @override
  State<SearchOptionEditor> createState() => _SearchOptionEditorState();
}

class _SearchOptionEditorState extends State<SearchOptionEditor> {
  late bool _exclude = widget.exclude;
  late String _value = initialSearchOptionValue(
    widget.option,
    widget.initialValue,
  );
  String? get _query => widget.option.compose(_value, exclude: _exclude);

  @override
  Widget build(BuildContext context) {
    final t = context.t.search_options;
    final option = widget.option;
    final media = MediaQuery.of(context);
    final insets = media.viewInsets.bottom;
    final height = ((media.size.height - insets - media.padding.vertical) * 0.9)
        .clamp(0.0, double.infinity);
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      searchOptionTitle(context, option),
                      style: Kurumi.themeOf(context).textTheme.titleLarge,
                    ),
                  ),
                  if (option.isFree) const SearchOptionFreeBadge(),
                  IconButton(
                    tooltip: t.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Symbols.close),
                  ),
                ],
              ),
              Text(searchOptionDescription(context, option)),
              const SizedBox(height: 8),
              if (option.supportsExclusion || _exclude) ...[
                SearchOptionChoices(
                  children: [
                    ChoiceChip(
                      label: Text(t.include),
                      selected: !_exclude,
                      onSelected: (_) => setState(() => _exclude = false),
                    ),
                    ChoiceChip(
                      label: Text(t.exclude),
                      selected: _exclude,
                      onSelected: option.supportsExclusion
                          ? (_) => setState(() => _exclude = true)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              SearchOptionValueInput(
                option: option,
                value: _value,
                config: widget.config,
                onChanged: (value) => setState(() => _value = value),
              ),
              const SizedBox(height: 8),
              Text(
                t.preview,
                style: Kurumi.themeOf(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              SelectableText(_query ?? '${option.key}:…'),
              if (_value.isNotEmpty && _query == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _exclude && !option.supportsExclusion
                        ? t.unsupported_exclusion
                        : _exclude &&
                              option.negation ==
                                  SearchOptionNegation.comparison &&
                              SearchOption.complement(_value) == null
                        ? t.comparison_exclusion
                        : t.invalid_value,
                    style: TextStyle(
                      color: Kurumi.themeOf(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.cancel),
                  ),
                  FilledButton(
                    onPressed: _query == null
                        ? null
                        : () => Navigator.of(context).pop(_query),
                    child: Text(t.apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
