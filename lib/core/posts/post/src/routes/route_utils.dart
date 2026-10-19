// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import '../../../../router.dart';
import '../types/post.dart';

void goToOriginalImagePage(WidgetRef ref, Post post) {
  if (post.isMp4) {
    Kurumi.showSimpleSnackBar(
      context: ref.context,
      content: Text('This is a video post, cannot view original image'.hc),
    );
    return;
  }

  ref.pushRoute(
    Uri(
      path: '/original_image_viewer',
    ).toString(),
    extra: post,
  );
}
