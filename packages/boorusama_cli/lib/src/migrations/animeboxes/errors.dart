final class AnimeBoxesFormatException implements FormatException {
  const AnimeBoxesFormatException(
    this.code,
    this.message, {
    this.section,
    this.row,
  });

  final String code;

  @override
  final String message;

  final String? section;
  final int? row;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => [
    code,
    if (section != null) 'section=$section',
    if (row != null) 'row=$row',
    message,
  ].join(': ');
}
