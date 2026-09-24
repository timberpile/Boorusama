// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/widgets.dart';
import '../../../posts/post/types.dart';
import '../../../router.dart';
import 'pages/show_tag_list_page.dart';

Future<bool?> goToShowTaglistPage(
  WidgetRef ref,
  Post post, {
  required BooruConfig config,
  bool initiallyMultiSelectEnabled = false,
}) {
  final auth = config.auth;
  final booruBuilder = ref.read(booruBuilderProvider(auth));
  final viewTagListBuilder = booruBuilder?.viewTagListBuilder;

  if (viewTagListBuilder == null) {
    return Kurumi.showAdaptiveSheet(
      ref.context,
      expand: true,
      settings: const RouteSettings(
        name: 'view_tag_list',
      ),
      builder: (_) => CurrentBooruConfigScope(
        config: config,
        child: ShowTagListPage(
          post: post,
          initiallyMultiSelectEnabled: initiallyMultiSelectEnabled,
          auth: auth,
        ),
      ),
    );
  }

  return Kurumi.showAdaptiveSheet(
    navigatorKey.currentContext ?? ref.context,
    expand: true,
    settings: const RouteSettings(
      name: 'view_tag_list',
    ),
    builder: (_) => CurrentBooruConfigScope(
      config: config,
      child: Builder(
        builder: (context) => viewTagListBuilder(
          context,
          post,
          initiallyMultiSelectEnabled,
          auth,
        ),
      ),
    ),
  );
}
