// Project imports:
import 'tag.dart';

extension TagDisplayX on Tag {
  String get displayName => (label ?? name).replaceAll('_', ' ');
  String get rawName => name;
}
