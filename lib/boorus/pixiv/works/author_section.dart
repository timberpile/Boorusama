import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/search/search/routes.dart';
import '../client_provider.dart';
import '../posts/query.dart';
import 'work_mapper.dart';
import 'work_preview.dart';

typedef PixivAuthorWorksQuery = ({ContentAccessKey access, int userId});

final pixivAuthorWorksPreviewProvider = FutureProvider.autoDispose
    .family<PixivIllustListResult, PixivAuthorWorksQuery>(
      (ref, query) async {
        final access = ref.watch(contentAccessContextProvider(query.access));
        if (access?.config == null || access?.key.profileId == null) {
          throw StateError('Pixiv author works require their original profile');
        }
        final blacklist = ref
            .watch(contentEffectiveBlacklistProvider(access!.key.profileId!))
            .requireValue;
        final client = ref.watch(pixivClientProvider(access.config!.auth));
        final token = CancelToken();
        ref.onDispose(token.cancel);
        final page = await runWithApiRequestContext(
          ApiRequestContext(cancelToken: token),
          () => client.getUserIllusts(userId: query.userId),
        );
        if (token.isCancelled ||
            ref.read(contentAccessContextProvider(query.access)) != access) {
          throw StateError('Pixiv author work access changed');
        }
        final seen = <int>{};
        return PixivIllustListResult(
          hasMore: page.hasMore,
          illusts: [
            for (final dto in page.illusts)
              if (dto.user?.id == query.userId &&
                  pixivWorkIsVisible(dto) &&
                  pixivWorkPassesFilters(dto, access, blacklist) &&
                  seen.add(dto.id!))
                dto,
          ],
        );
      },
      dependencies: [
        contentAccessContextProvider,
        contentEffectiveBlacklistProvider,
      ],
    );

class PixivAuthorWorksSection extends ConsumerWidget {
  const PixivAuthorWorksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = watchPixivPreviewAccess(ref);
    if (access == null) return const SliverToBoxAdapter();
    final data = pixivPreviewPostData(context, access);
    if (data == null || data.userId <= 0) return const SliverToBoxAdapter();

    final query = (access: access.key, userId: data.userId);
    final author = data.userName.trim();
    final title = context.t.post.detail.artist;
    return PixivWorksPreview(
      key: ValueKey(query),
      access: access,
      provider: pixivAuthorWorksPreviewProvider(query),
      title: author.isEmpty ? title : author,
      subtitle: author.isEmpty ? null : title,
      listing: (page) => page,
      onShowAll: (ref, _) => goToSearchPage(
        ref,
        config: access.config,
        tag: PixivQuery.userTag(data.userId),
      ),
    );
  }
}
