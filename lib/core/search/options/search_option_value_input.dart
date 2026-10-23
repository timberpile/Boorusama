import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../configs/config/types.dart';
import 'entity_suggestions.dart';
import 'labels.dart';
import 'search_modal_back_handler.dart';
import 'search_option.dart';
import 'search_option_choices.dart';

/// Produces a draft value only; Apply is owned by the parent sheet.
class SearchOptionValueInput extends StatefulWidget {
  const SearchOptionValueInput({
    required this.option,
    required this.value,
    required this.onChanged,
    this.config,
    super.key,
  });
  final SearchOption option;
  final String value;
  final ValueChanged<String> onChanged;
  final BooruConfigAuth? config;
  @override
  State<SearchOptionValueInput> createState() => _SearchOptionValueInputState();
}

class _SearchOptionValueInputState extends State<SearchOptionValueInput> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  var _operator = '';
  var _between = false;
  var _unit = '';
  var _lastUnit = '';
  String? _selected;
  String? _special;

  @override
  void initState() {
    super.initState();
    _load(widget.value);
  }

  @override
  void didUpdateWidget(covariant SearchOptionValueInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.option != widget.option ||
        (oldWidget.value != widget.value && _value != widget.value)) {
      _load(widget.value);
    }
  }

  (String, String) _splitUnit(String value) {
    final units = [...widget.option.units]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final unit in units) {
      if (unit.isNotEmpty && value.toLowerCase().endsWith(unit)) {
        return (value.substring(0, value.length - unit.length), unit);
      }
    }
    return (
      value,
      widget.option.input == SearchOptionInput.duration && units.contains('d')
          ? 'd'
          : units.firstOrNull ?? '',
    );
  }

  void _load(String input) {
    final value = widget.option.editorValue(input);
    _selected = value;
    _special = null;
    _between = false;
    _operator = '';
    _last.clear();
    if (!widget.option.isComparable) {
      _first.text = value;
      return;
    }
    final range = widget.option.allowRange ? value.split('..') : <String>[];
    String first;
    String last;
    if (range.length == 2) {
      _between = true;
      first = range[0];
      last = range[1];
    } else {
      final match = RegExp(r'^(>=|<=|>|<)?(.*)$').firstMatch(value)!;
      _operator = match[1] ?? '';
      first = match[2]!;
      last = '';
    }
    final (firstText, firstUnit) = _splitUnit(first);
    final (lastText, lastUnit) = _splitUnit(last);
    _first.text = firstText;
    _last.text = lastText;
    _unit = firstUnit;
    _lastUnit = lastUnit;
    if (widget.option.choices.any((choice) => choice.value == value) &&
        RegExp(r'^[a-z_]+$').hasMatch(value)) {
      _special = value;
    }
  }

  String get _value {
    if (!widget.option.isComparable) return _first.text;
    if (_special != null) return _special!;
    final first = _first.text.isEmpty ? '' : '${_first.text}$_unit';
    final last = _last.text.isEmpty ? '' : '${_last.text}$_lastUnit';
    return _between ? '$first..$last' : '$_operator$first';
  }

  void _change(VoidCallback change) {
    setState(change);
    widget.onChanged(_value);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final min = DateTime(1900);
    final max = DateTime(2200, 12, 31);
    final current = SearchOption.parseDate(controller.text) ?? DateTime.now();
    final initial = current.isBefore(min)
        ? min
        : current.isAfter(max)
        ? max
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: min,
      lastDate: max,
      // The framework calendar has seven fixed-width columns. At narrow widths
      // a 2x font clips two-digit days; keep the rest of the editor fully scaled.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: SearchModalBackHandler(child: child!),
      ),
    );
    if (!mounted || picked == null) return;
    _change(() {
      _special = null;
      controller.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Widget _field(TextEditingController controller, {bool last = false}) {
    final option = widget.option;
    return KurumiTextField(
      controller: controller,
      autocorrect: false,
      keyboardType: switch (option.input) {
        SearchOptionInput.number => TextInputType.numberWithOptions(
          signed: option.allowNegative,
        ),
        SearchOptionInput.decimal ||
        SearchOptionInput.filesize => TextInputType.numberWithOptions(
          decimal: true,
          signed: option.allowNegative,
        ),
        SearchOptionInput.duration => TextInputType.number,
        SearchOptionInput.date => TextInputType.datetime,
        _ => TextInputType.text,
      },
      decoration: InputDecoration(
        labelText: _between
            ? '${last ? '≤' : '≥'} ${context.t.search_options.value}'
            : context.t.search_options.value,
        suffixIcon: option.input == SearchOptionInput.date
            ? IconButton(
                tooltip: context.t.search_options.choose_date,
                onPressed: () => _pickDate(controller),
                icon: const Icon(Symbols.calendar_month),
              )
            : null,
      ),
      onChanged: (_) => _change(() => _special = null),
    );
  }

  String _unitLabel(String unit) => switch (unit) {
    'h' => context.t.search_options.hours,
    'd' => context.t.search_options.days,
    'w' => context.t.search_options.weeks,
    'mo' => context.t.search_options.months,
    'y' => context.t.search_options.years,
    _ => unit.isEmpty ? 'b' : unit,
  };

  Widget _units({bool last = false}) => SearchOptionChoices(
    children: [
      for (final unit in widget.option.units)
        ChoiceChip(
          label: Text(_unitLabel(unit)),
          selected: (last ? _lastUnit : _unit) == unit,
          onSelected: (_) => _change(() {
            _special = null;
            if (last) {
              _lastUnit = unit;
            } else {
              _unit = unit;
            }
          }),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final t = context.t.search_options;
    if (option.input == SearchOptionInput.choice) {
      return SearchOptionChoices(
        children: [
          for (final choice in option.choices)
            ChoiceChip(
              label: Text(searchOptionChoiceLabel(context, choice)),
              selected: _selected == choice.value,
              onSelected: (_) => _change(() => _load(choice.value)),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (option.choices.isNotEmpty)
          SearchOptionChoices(
            children: [
              for (final choice in option.choices)
                ActionChip(
                  label: Text(searchOptionChoiceLabel(context, choice)),
                  onPressed: () => _change(() => _load(choice.value)),
                ),
            ],
          ),
        if (option.choices.isNotEmpty && option.isComparable)
          const SizedBox(height: 6),
        if (option.isComparable)
          SearchOptionChoices(
            children: [
              for (final (operator, label) in [
                ('', t.equal_to),
                ('<', t.less_than),
                ('<=', t.at_most),
                ('>=', t.at_least),
                ('>', t.more_than),
              ])
                if (option.comparisons.contains(operator))
                  ChoiceChip(
                    label: Text(label),
                    selected: !_between && _operator == operator,
                    onSelected: (_) => _change(() {
                      _between = false;
                      _operator = operator;
                      _special = null;
                    }),
                  ),
              if (option.allowRange)
                ChoiceChip(
                  label: const Text('↔'),
                  selected: _between,
                  tooltip: '${t.at_least} / ${t.at_most}',
                  onSelected: (_) => _change(() {
                    _between = true;
                    _special = null;
                  }),
                ),
            ],
          ),
        const SizedBox(height: 12),
        _field(_first),
        if (option.units.isNotEmpty) ...[
          const SizedBox(height: 6),
          _units(),
        ],
        if (_between) ...[
          const SizedBox(height: 8),
          _field(_last, last: true),
          if (option.units.isNotEmpty) ...[
            const SizedBox(height: 6),
            _units(last: true),
          ],
        ],
        if (widget.config case final config?)
          if (option.input == SearchOptionInput.text)
            SearchEntitySuggestions(
              config: config,
              optionKey: option.key,
              text: _first.text,
              onSelected: (value) => _change(() => _load(value)),
            ),
      ],
    );
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }
}
