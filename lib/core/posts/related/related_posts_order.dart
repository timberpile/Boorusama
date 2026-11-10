import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'related_posts_order_value.dart';

export 'related_posts_order_value.dart';

extension RelatedPostsOrderLocalization on RelatedPostsOrder {
  String localize(BuildContext context) => switch (this) {
    RelatedPostsOrder.oldest => context.t.explore.oldest,
    RelatedPostsOrder.newest => context.t.explore.newest,
  };
}
