// Dart imports:
import 'dart:math';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:

class TagDetailsRegion extends ConsumerWidget {
  const TagDetailsRegion({
    required this.builder,
    required this.detailsBuilder,
    super.key,
    this.showBackButton = true,
  });

  final bool showBackButton;
  final Widget Function(BuildContext context) builder;
  final Widget Function(BuildContext context) detailsBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return !context.isLargeScreen
        ? builder(context)
        : Material(
            color: Kurumi.themeOf(context).colorScheme.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 4),
                SizedBox(
                  width: max(MediaQuery.widthOf(context) * 0.25, 350),
                  child: SingleChildScrollView(
                    child: SafeArea(
                      left: false,
                      top: showBackButton,
                      child: Column(
                        children: [
                          if (showBackButton)
                            Row(
                              children: [
                                IconButton(
                                  iconSize: 28,
                                  splashRadius: 24,
                                  icon: const Icon(
                                    Symbols.close,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const Spacer(),
                              ],
                            ),
                          detailsBuilder(context),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 12,
                  thickness: 1,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: builder(context),
                ),
              ],
            ),
          );
  }
}
