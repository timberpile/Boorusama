import 'package:boorusama/core/search/options/search_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SearchOption option(SearchOptionInput input) => SearchOption(
    kind: SearchOptionKind.metadata,
    key: 'field',
    input: input,
    allowRange: true,
    allowNegative: false,
    negation: SearchOptionNegation.prefix,
  );
  test('range validation rejects reversed numbers and impossible dates', () {
    expect(option(SearchOptionInput.number).compose('10..20'), 'field:10..20');
    expect(option(SearchOptionInput.number).compose('20..10'), isNull);
    expect(option(SearchOptionInput.number).compose('..20'), 'field:..20');
    expect(option(SearchOptionInput.number).compose('..'), isNull);
    expect(
      option(SearchOptionInput.date).compose('2024-02-29'),
      'field:2024-02-29',
    );
    expect(option(SearchOptionInput.date).compose('2025-02-29'), isNull);
    expect(
      option(SearchOptionInput.date).compose('2026-02-01..2026-01-01'),
      isNull,
    );
  });
  test('size, ratio and decimal values retain units and native separators', () {
    expect(
      option(SearchOptionInput.filesize).compose('>=1.5mb'),
      'field:>=1.5mb',
    );
    expect(option(SearchOptionInput.ratio).compose('16:9'), 'field:16:9');
    expect(option(SearchOptionInput.ratio).compose('16:0'), isNull);
    expect(
      option(SearchOptionInput.decimal).compose('2.5..8.0', exclude: true),
      '-field:2.5..8.0',
    );
    expect(option(SearchOptionInput.number).compose('2.5'), isNull);
    expect(option(SearchOptionInput.decimal).compose('2.5 rating:e'), isNull);
  });
  test('free metadata decoration preserves the complete input contract', () {
    final original = option(SearchOptionInput.decimal);
    final free = original.withFree(true);
    expect(free.allowRange, isTrue);
    expect(free.allowNegative, isFalse);
    expect(free.compose('2.5..4'), original.compose('2.5..4'));
  });
}
