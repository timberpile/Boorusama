enum RelatedPostsOrder {
  oldest,
  newest;

  static RelatedPostsOrder parse(Object? value) => switch (value) {
    'newest' => newest,
    _ => oldest,
  };

  String get queryOrder => switch (this) {
    oldest => 'order:id_asc',
    newest => 'order:id_desc',
  };
}
