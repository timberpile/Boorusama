import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../../core/posts/listing/src/widgets/timeline_option_selector.dart';
import '../../../../../../core/posts/pools/src/types/pool_details_order.dart';

class PoolOrderSelector extends StatelessWidget {
  const PoolOrderSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final PoolDetailsOrder value;
  final ValueChanged<PoolDetailsOrder> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12),
    child: TimelineOptionSelector<PoolDetailsOrder>(
      label: value.localize(context),
      value: value,
      options: PoolDetailsOrder.values,
      optionLabel: (order) => order.localize(context),
      optionIcon: (_) => Symbols.swap_vert,
      onSelected: onChanged,
    ),
  );
}
