// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../../posts/post/providers.dart';
import '../routes/params.dart';
import '../widgets/search_page_scaffold.dart';

class DefaultSearchPage extends ConsumerWidget {
  const DefaultSearchPage({
    required this.params,
    super.key,
  });

  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(unifiedPostRepoProvider(ref.watchConfig));

    return SearchPageScaffold(
      params: params,
      fetcher: (page, controler) => postRepo.getPostsFromController(
        controler.tagSet,
        page,
      ),
    );
  }
}
