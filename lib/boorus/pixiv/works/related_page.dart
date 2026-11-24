import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/posts/listing/types.dart';
import '../client_provider.dart';
import 'related_source.dart';
import 'work_listing.dart';

typedef PixivRelatedPageArgs = ({
  PixivRelatedQuery query,
  PixivRelatedPage firstPage,
});

class PixivRelatedTimelinePage extends ConsumerStatefulWidget {
  const PixivRelatedTimelinePage({required this.args, super.key});

  final PixivRelatedPageArgs args;

  @override
  ConsumerState<PixivRelatedTimelinePage> createState() =>
      _PixivRelatedTimelinePageState();
}

class _PixivRelatedTimelinePageState
    extends ConsumerState<PixivRelatedTimelinePage> {
  late final _session = PixivRelatedSession(
    firstPage: widget.args.firstPage,
    load: (cursor, token) async {
      final query = widget.args.query;
      final access = ref.read(contentAccessContextProvider(query.access));
      if (access?.config == null || access?.key.profileId == null) {
        throw StateError('Pixiv related artwork access changed');
      }
      final client = ref.read(pixivClientProvider(access!.config!.auth));
      final result = await client.getRelatedIllusts(
        illustId: query.illustId,
        cursor: cursor,
        cancelToken: token,
      );
      if (!mounted ||
          (token?.isCancelled ?? false) ||
          ref.read(contentAccessContextProvider(query.access)) != access) {
        throw StateError('Pixiv related artwork access changed');
      }
      final blacklist = ref
          .read(contentEffectiveBlacklistProvider(access.key.profileId!))
          .requireValue;
      return filterPixivRelatedPage(result, query, access, blacklist);
    },
  );

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(
      contentAccessContextProvider(widget.args.query.access),
    );
    final title = context.t.post.detail.related_works;
    if (access?.config == null) {
      return Scaffold(
        appBar: KurumiAppBar(title: Text(title)),
        body: Center(child: Text(context.t.navigation.unavailable_profile)),
      );
    }
    return Scaffold(
      body: PixivWorkGrid(
        config: access!.config!,
        queryIdentity: widget.args.query,
        pageMode: PageMode.infinite,
        fetchPage: _session.fetch,
        sliverHeaders: [KurumiSliverAppBar(title: Text(title))],
      ),
    );
  }
}
