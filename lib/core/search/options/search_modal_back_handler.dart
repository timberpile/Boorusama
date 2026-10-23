import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

/// A root-navigator search sheet must claim Back before the nested search
/// editor. The nested route can still be current while this root route is open.
class SearchModalBackHandler extends StatelessWidget {
  const SearchModalBackHandler({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => KurumiBackHandler(
    enabled: ModalRoute.of(context)?.isCurrent ?? false,
    onBack: () => Navigator.of(context).pop(),
    child: child,
  );
}
