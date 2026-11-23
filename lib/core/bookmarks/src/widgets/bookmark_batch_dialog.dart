import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

/// Loose, bounded content lets the shared folder picker shrink to a few rows
/// without using intrinsic measurement on its lazy scroll views.
class BookmarkBatchDialog extends StatelessWidget {
  const BookmarkBatchDialog({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: KurumiDialog(
      width: 420,
      screenInset: 12,
      height: 560,
      semanticLabel: title,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        key: const Key('bookmark-batch-surface'),
        width: 420,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight / 3,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: KurumiFittedText(
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: child),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t.generic.action.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
