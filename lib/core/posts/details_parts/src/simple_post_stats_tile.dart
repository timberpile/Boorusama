// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../widgets/widgets.dart';
import '_internal/details_widget_frame.dart';

class SimplePostStatsTile extends StatelessWidget {
  const SimplePostStatsTile({
    this.totalComments,
    this.favCount,
    this.score,
    super.key,
    this.padding,
    this.onFavCountTap,
    this.onScoreTap,
    this.onTotalCommentsTap,
    this.votePercentText,
  });

  final int? totalComments;
  final int? favCount;
  final int? score;
  final EdgeInsets? padding;
  final void Function()? onFavCountTap;
  final void Function()? onScoreTap;
  final void Function()? onTotalCommentsTap;
  final String? votePercentText;

  @override
  Widget build(BuildContext context) {
    final favCount = this.favCount;
    final score = this.score;
    final totalComments = this.totalComments;
    if (favCount == null && score == null && totalComments == null)
      return const SizedBox.shrink();
    return DetailsWidgetSeparator(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
      child: Wrap(
        children: [
          if (favCount != null)
            _StatButton(
              enable: onFavCountTap != null,
              onTap: () => onFavCountTap?.call(),
              child: RichText(
                text: TextSpan(
                  text: '$favCount ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Kurumi.themeOf(context).colorScheme.primary,
                  ),
                  children: [
                    TextSpan(
                      text: context.t.favorites.counter(n: favCount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Kurumi.themeOf(context).colorScheme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (score != null)
            _StatButton(
              enable: onScoreTap != null,
              onTap: () => onScoreTap?.call(),
              child: RichText(
                text: TextSpan(
                  text: '$score ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Kurumi.themeOf(context).colorScheme.primary,
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${context.t.post.detail.score(n: score)} ${votePercentText ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Kurumi.themeOf(context).colorScheme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (totalComments != null)
            _StatButton(
              enable: onTotalCommentsTap != null,
              onTap: () => onTotalCommentsTap?.call(),
              child: RichText(
                text: TextSpan(
                  text: '$totalComments ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Kurumi.themeOf(context).colorScheme.primary,
                  ),
                  children: [
                    TextSpan(
                      text: context.t.comment.counter(n: totalComments),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Kurumi.themeOf(context).colorScheme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatButton extends StatelessWidget {
  const _StatButton({
    required this.child,
    required this.enable,
    this.onTap,
  });

  final Widget child;
  final bool enable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConditionalParentWidget(
      condition: enable,
      conditionalBuilder: (child) => InkWell(
        customBorder: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        onTap: onTap,
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: child,
      ),
    );
  }
}
