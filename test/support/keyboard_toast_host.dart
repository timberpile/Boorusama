import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

/// OKToast reads native ui.window rather than TestFlutterView. Model its
/// keyboard displacement with the test view's MediaQuery, retaining the inset
/// for the application scope. Real OS displacement needs device acceptance.
class KeyboardToastHost extends StatelessWidget {
  const KeyboardToastHost({
    required this.child,
    this.enabled = true,
    super.key,
  });
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      bottom: enabled ? MediaQuery.viewInsetsOf(context).bottom : 0,
    ),
    child: OKToast(
      movingOnWindowChange: false,
      animationDuration: Duration.zero,
      child: child,
    ),
  );
}
