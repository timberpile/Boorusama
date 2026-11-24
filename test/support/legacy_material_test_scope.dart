import 'package:material_ui/material_ui.dart';

/// Matches the app's legacy Material support for widgets from dependencies
/// that still use Flutter's bundled Material library.
class LegacyMaterialTestScope extends StatelessWidget {
  const LegacyMaterialTestScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      // ignore: deprecated_member_use
      MaterialUiCompatibilityBridge(child: child);
}
