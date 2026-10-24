// Package imports:
import 'package:booru_clients/nozomi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/search/widgets.dart';
import '../posts/providers.dart';
import '../posts/types.dart';

class NozomiSearchPage extends ConsumerWidget {
  const NozomiSearchPage({required this.params, super.key});
  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final postRepo = OriginAwarePostRepository.fromConfig(
      delegate: ref.watch(
        nozomiPostRepoWithOrderProvider((
          config: config.search,
          order: _parseNozomiPostOrder(params.order),
        )),
      ),
      config: config,
    );
    // The common landing view exposes the index order through Search Options.
    // There is no second sort state competing with the query item.
    return SearchPageScaffold<Post>(
      params: params,
      fetcher: (page, controller) =>
          postRepo.getPostsFromController(controller.tagSet, page),
    );
  }
}

// Keep the existing standalone controls available to their other consumers.
// The search page above deliberately uses the shared catalog instead.
class NozomiSearchLandingView extends StatelessWidget {
  const NozomiSearchLandingView({
    required this.controller,
    required this.order,
    required this.onOrderChanged,
    super.key,
  });
  final SearchPageController controller;
  final NozomiPostOrder order;
  final ValueChanged<NozomiPostOrder> onOrderChanged;
  @override
  Widget build(BuildContext context) => SearchLandingView(
    child: DefaultSearchLandingChildren(
      children: [
        NozomiSearchOrderSection(order: order, onOrderChanged: onOrderChanged),
        DefaultMobileFavoriteTagsSection(controller: controller),
        DefaultMobileSearchHistorySection(controller: controller),
      ],
    ),
  );
}

class NozomiSearchOrderHeader extends StatelessWidget {
  const NozomiSearchOrderHeader({
    required this.order,
    required this.onOrderChanged,
    super.key,
  });
  final NozomiPostOrder order;
  final ValueChanged<NozomiPostOrder> onOrderChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: NozomiSearchOrderControl(
        order: order,
        onOrderChanged: onOrderChanged,
      ),
    ),
  );
}

class NozomiSearchOrderSection extends StatelessWidget {
  const NozomiSearchOrderSection({
    required this.order,
    required this.onOrderChanged,
    super.key,
  });
  final NozomiPostOrder order;
  final ValueChanged<NozomiPostOrder> onOrderChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: NozomiSearchOrderControl(
      order: order,
      onOrderChanged: onOrderChanged,
    ),
  );
}

class NozomiSearchOrderControl extends StatelessWidget {
  const NozomiSearchOrderControl({
    required this.order,
    required this.onOrderChanged,
    super.key,
  });
  final NozomiPostOrder order;
  final ValueChanged<NozomiPostOrder> onOrderChanged;
  @override
  Widget build(BuildContext context) =>
      KurumiMaterialSegmentedButton<NozomiPostOrder>(
        showSelectedIcon: false,
        style: KurumiMaterialSegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
        segments: const [
          KurumiMaterialButtonSegment(
            value: NozomiPostOrder.date,
            label: Text('Date'),
          ),
          KurumiMaterialButtonSegment(
            value: NozomiPostOrder.popular,
            label: Text('Popular'),
          ),
        ],
        selected: {order},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) onOrderChanged(selection.first);
        },
      );
}

NozomiPostOrder _parseNozomiPostOrder(String? value) =>
    value == 'popular' ? NozomiPostOrder.popular : NozomiPostOrder.date;
