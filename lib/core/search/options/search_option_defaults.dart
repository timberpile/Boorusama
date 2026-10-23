import 'search_option.dart';

/// Preserve an explicit draft, and never seed an engine-specific editor with
/// units or comparison operators that its own serializer rejects.
String initialSearchOptionValue(SearchOption option, String? initialValue) {
  if (initialValue != null) return option.editorValue(initialValue);
  if (option.input == SearchOptionInput.duration) {
    if (option.accepts('<7d')) return '<7d';
    for (final choice in option.choices) {
      if (option.accepts(choice.value)) return choice.value;
    }
  }
  if (option.kind == SearchOptionKind.score && option.accepts('>=50')) {
    return '>=50';
  }
  return '';
}
