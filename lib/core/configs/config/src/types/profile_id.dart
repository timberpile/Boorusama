import 'package:uuid/uuid.dart';

final _profileIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String createProfileId() => const Uuid().v4().toLowerCase();

bool isCanonicalProfileId(Object? value) =>
    value is String && _profileIdPattern.hasMatch(value);

String readProfileId(Object? value, {String field = 'profile ID'}) {
  if (!isCanonicalProfileId(value)) {
    throw FormatException('Invalid $field');
  }
  return value as String;
}
