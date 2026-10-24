import '../search_option.dart';

/// An account ID sent as an API parameter, not a tag or a content rating.
/// No name lookup is advertised unless the engine has a verified endpoint.
class ApiUserIdOption extends SearchOption {
  const ApiUserIdOption({required super.key, required super.labelKey})
    : super(
        kind: SearchOptionKind.metadata,
        input: SearchOptionInput.number,
        descriptionKey: 'user_id',
        allowNegative: false,
      );

  @override
  bool get isComparable => false;

  @override
  bool accepts(String value) =>
      RegExp(r'^[1-9][0-9]*$').hasMatch(value) && int.tryParse(value) != null;
}

List<SearchOption> eshuushuuOptions() => const [
  ApiUserIdOption(key: 'user_id', labelKey: 'uploader'),
  ApiUserIdOption(key: 'favorited_by_user_id', labelKey: 'favorited_by'),
];

List<SearchOption> animePicturesOptions() => const [
  ApiUserIdOption(key: 'stars_by', labelKey: 'favorited_by'),
];
