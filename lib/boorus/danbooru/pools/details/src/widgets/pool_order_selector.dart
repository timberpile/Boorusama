import '../../../../../../core/posts/pools/src/widgets/group_sort_icon.dart';

import 'package:kurumi/material.dart';

import '../../../../../../core/posts/listing/src/widgets/timeline_option_selector.dart';
import '../../../../../../core/posts/pools/src/types/pool_details_order.dart';

class PoolOrderSelector extends StatelessWidget {
  const PoolOrderSelector({
    required this.value,
    required this.onChanged,
    this.pending = false,
    super.key,
  });

  final PoolDetailsOrder value;
  final ValueChanged<PoolDetailsOrder> onChanged;
  final bool pending;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12),
    child: TimelineOptionSelector<PoolDetailsOrder>(
      label: value.localize(context),
      value: value,
      pending: pending,
      options: PoolDetailsOrder.values,
      optionLabel: (order) => order.localize(context),
      optionLeading: (order) => GroupSortIcon(order.name, size: 18),
      onSelected: onChanged,
    ),
  );
}
