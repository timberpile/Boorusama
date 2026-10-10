// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../client_provider.dart';
import '../../providers.dart';
import 'user_list_page.dart';

class DanbooruFavoriterListPage extends ConsumerWidget {
  const DanbooruFavoriterListPage({
    required this.postId,
    super.key,
  });

  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final client = ref.watch(danbooruClientProvider(config));
    final userRepo = ref.watch(danbooruUserRepoProvider(config));

    return Scaffold(
      appBar: KurumiAppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: KurumiFittedText(
                Text(context.t.post.favorites.user_list.title),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: context.t.post.favorites.user_list.disclaimer,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 3),
              child: Icon(
                Icons.info,
                size: 18,
                color: Kurumi.themeOf(context).colorScheme.hintColor,
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          DanbooruSliverUserListPage(
            fetchUsers: (page) async {
              final votes = await client.getFavorites(
                postId: postId,
                page: page,
              );
              final userIds = votes.map((e) => e.userId).toList();
              final users = await userRepo.getUsersByIds(userIds);
              return users;
            },
          ),
        ],
      ),
    );
  }
}
