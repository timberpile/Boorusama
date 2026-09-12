/// The manga series an illust belongs to, when any.
class PixivSeries {
  const PixivSeries({this.id, this.title});

  final int? id;
  final String? title;

  static PixivSeries? fromJsonOrNull(Map<String, dynamic>? json) {
    if (json == null) return null;

    return PixivSeries(id: json['id'] as int?, title: json['title'] as String?);
  }
}
