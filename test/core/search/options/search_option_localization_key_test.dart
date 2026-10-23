import 'package:boorusama/core/search/options/labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native punctuation maps to stable generated localization identifiers',
    () {
      expect(searchOptionLocalizationKey('image-width'), 'image_width');
      expect(searchOptionLocalizationKey('first_seen_at'), 'first_seen_at');
      expect(searchOptionLocalizationKey('system:duration'), 'system_duration');
      expect(searchOptionLocalizationKey('score,desc'), 'score_desc');
    },
  );
}
