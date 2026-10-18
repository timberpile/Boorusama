import 'package:kurumi/material.dart';

/// Compatibility boundary for pages that previously installed a global
/// context-menu overlay. Kurumi menus manage their own overlay lifecycle.
class CustomContextMenuOverlay extends StatelessWidget {
  const CustomContextMenuOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
