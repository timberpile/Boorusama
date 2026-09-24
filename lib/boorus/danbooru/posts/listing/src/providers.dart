// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../core/configs/auth/types.dart';
import '../../../../../core/posts/post/types.dart';
import '../../../tags/edit/routes.dart';

extension DanbooruVoteX on WidgetRef {
  void danbooruEdit(Post post) {
    guardLogin(this, () {
      goToTagEditPage(
        this,
        post: post,
      );
    });
  }
}
