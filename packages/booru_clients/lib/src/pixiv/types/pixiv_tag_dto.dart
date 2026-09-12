/// A tag as attached to an illust, or as returned by autocomplete.
///
/// [translatedName] comes back null whenever `Accept-Language` is missing
/// from the request, or when no translation exists for that tag.
class PixivTag {
  const PixivTag({this.name, this.translatedName});

  factory PixivTag.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivTag();

    return PixivTag(
      name: json['name'] as String?,
      translatedName: json['translated_name'] as String?,
    );
  }

  final String? name;
  final String? translatedName;
}
