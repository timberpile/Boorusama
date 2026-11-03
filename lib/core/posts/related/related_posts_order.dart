import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

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

  String localize(BuildContext context) => switch (this) {
    oldest => context.t.explore.oldest,
    newest => context.t.explore.newest,
  };
}
