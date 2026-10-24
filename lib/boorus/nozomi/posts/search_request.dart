import 'package:booru_clients/nozomi.dart';

import '../../../core/search/options/adapter_directives.dart';

/// The ordering belongs to the post index, not to the tag index namespace.
class NozomiSearchRequest {
  const NozomiSearchRequest({required this.tags, required this.order});

  factory NozomiSearchRequest.fromTags(
    List<String> tags, {
    NozomiPostOrder fallbackOrder = NozomiPostOrder.date,
  }) {
    var order = fallbackOrder;
    final conditions = extractSearchAdapterDirectives(tags, (tag) {
      switch (tag) {
        case 'order:date':
          order = NozomiPostOrder.date;
          return true;
        case 'order:popular':
          order = NozomiPostOrder.popular;
          return true;
        default:
          return false;
      }
    });
    return NozomiSearchRequest(
      tags: List.unmodifiable(conditions),
      order: order,
    );
  }

  final List<String> tags;
  final NozomiPostOrder order;
}
