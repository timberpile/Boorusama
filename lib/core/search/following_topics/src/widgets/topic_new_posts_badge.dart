import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

class TopicNewPostsBadge extends StatelessWidget {
  const TopicNewPostsBadge({this.count, this.isLowerBound = false, super.key});

  final int? count;
  final bool isLowerBound;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final knownCount = count != null && count! > 0 ? count : null;
    final label = knownCount == null
        ? strings.new_badge
        : '$knownCount${isLowerBound ? '+' : ''}';
    final semantics = knownCount == null
        ? strings.new_posts
        : isLowerBound
        ? strings.new_posts_at_least(n: knownCount)
        : strings.new_posts_count(n: knownCount);
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Badge(label: Text(label)),
    );
  }
}
