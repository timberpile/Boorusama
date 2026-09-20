// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../constants.dart';
import '../controllers/home_page_controller.dart';

class HomeNavigationTile extends StatelessWidget {
  const HomeNavigationTile({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.value,
    required this.constraints,
    super.key,
    this.onTap,
    this.forceFillIcon = false,
    this.forceIconColor,
    this.enabled = true,
    this.badgeCount,
  });

  // Will override the onTap function
  final VoidCallback? onTap;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final int value;
  final BoxConstraints constraints;
  final bool forceFillIcon;
  final Color? forceIconColor;
  final bool enabled;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final controller = InheritedHomePageController.of(context);

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, index, child) {
        final selected = value == index;

        return KurumiNavigationTile(
          value: value,
          index: index,
          showIcon:
              constraints.maxWidth > 200 ||
              constraints.maxWidth <= kMinSideBarWidth,
          showTitle: constraints.maxWidth > kMinSideBarWidth,
          selectedIcon: _withBadge(
            Icon(
              selected ? selectedIcon : icon,
              fill: 1,
              color: selected
                  ? Kurumi.themeOf(context).colorScheme.onSecondary
                  : null,
            ),
          ),
          icon: _withBadge(
            Icon(
              icon,
              color:
                  forceIconColor ??
                  (selected
                      ? Kurumi.themeOf(context).colorScheme.onSecondary
                      : null),
              fill: forceFillIcon ? 1 : 0,
            ),
          ),
          title: Text(
            title,
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? Kurumi.themeOf(context).colorScheme.onSecondary
                  : null,
            ),
          ),
          onTap: enabled
              ? (value) => onTap != null ? onTap!() : controller.goToTab(value)
              : null,
        );
      },
    );
  }

  Widget _withBadge(Widget icon) => switch (badgeCount) {
    final count? when count > 0 => Badge.count(count: count, child: icon),
    _ => icon,
  };
}
