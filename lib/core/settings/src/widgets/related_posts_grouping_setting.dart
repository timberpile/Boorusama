import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../providers/settings_notifier.dart';

/// Both Appearance and Timeline View Options edit the same global preference.
class RelatedPostsGroupingSetting extends ConsumerWidget {
  const RelatedPostsGroupingSetting({
    super.key,
    this.contentPadding,
    this.visualDensity,
  });

  final EdgeInsetsGeometry? contentPadding;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KurumiSwitchListTile(
    title: Text(context.t.posts.actions.group_related_posts),
    value: ref.watch(
      settingsNotifierProvider.select((s) => s.groupRelatedPosts),
    ),
    onChanged: (enabled) => ref
        .read(settingsNotifierProvider.notifier)
        .updateWith(
          (settings) => settings.copyWith(groupRelatedPosts: enabled),
        ),
    contentPadding: contentPadding,
    visualDensity: visualDensity,
  );
}
