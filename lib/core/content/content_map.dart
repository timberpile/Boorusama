/// Hive decodes maps with Object? keys even when the wire format is string-keyed.
Map<String, Object?> contentMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Invalid content object');
  }
  return Map<String, Object?>.from(value);
}

String contentString(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid content string');
  }
  return value;
}
