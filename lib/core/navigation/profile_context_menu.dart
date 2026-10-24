import 'package:flutter/services.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../config_widgets/website_logo.dart';

final class ProfileMenuEntry {
  const ProfileMenuEntry({
    required this.id,
    required this.caption,
    required this.url,
  });
  final String id;
  final String caption;
  final String url;
}

class ProfileContextMenuButton extends StatefulWidget {
  const ProfileContextMenuButton({
    required this.entries,
    required this.selectedProfileId,
    required this.onSelected,
    required this.tooltip,
    super.key,
  });
  final List<ProfileMenuEntry> entries;
  final String? selectedProfileId;
  final ValueChanged<String> onSelected;
  final String tooltip;
  @override
  State<ProfileContextMenuButton> createState() =>
      _ProfileContextMenuButtonState();
}

class _ProfileContextMenuButtonState extends State<ProfileContextMenuButton> {
  final controller = AnchorController();
  final trigger = FocusNode();
  final nodes = <String, FocusNode>{};
  @override
  void dispose() {
    controller.dispose();
    trigger.dispose();
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _caption(ProfileMenuEntry entry) {
    final host = Uri.tryParse(entry.url)?.host ?? '';
    final name = entry.caption.trim();
    return name.isEmpty ? host : name;
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.entries
        .where((e) => e.id == widget.selectedProfileId)
        .firstOrNull;
    final captions = {
      for (final entry in widget.entries) entry.id: _caption(entry),
    };
    final style = Theme.of(context).textTheme.bodyMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    var contentWidth = 180.0;
    for (final caption in captions.values) {
      final painter = TextPainter(
        text: TextSpan(text: caption, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      contentWidth = contentWidth < painter.width + 96
          ? painter.width + 96
          : contentWidth;
      painter.dispose();
    }
    final width = contentWidth.clamp(
      0.0,
      (MediaQuery.widthOf(context) - 24).clamp(0.0, 320.0),
    );

    return KurumiAnchor(
      controller: controller,
      // RawAnchor already accounts for system padding and keyboard insets.
      viewPadding: const EdgeInsets.all(12),
      overlayBuilder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight:
              (MediaQuery.heightOf(context) -
                      MediaQuery.viewInsetsOf(context).bottom -
                      MediaQuery.viewPaddingOf(context).vertical -
                      80)
                  .clamp(
                    48,
                    480,
                  ),
        ),
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent || widget.entries.isEmpty) {
              return KeyEventResult.ignored;
            }
            final index = widget.entries.indexWhere(
              (entry) => nodes[entry.id]?.hasFocus ?? false,
            );
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              final chosen = widget.entries[index < 0 ? 0 : index];
              controller.hide();
              widget.onSelected(chosen.id);
              return KeyEventResult.handled;
            }
            final next = switch (event.logicalKey) {
              LogicalKeyboardKey.arrowDown =>
                (index + 1) % widget.entries.length,
              LogicalKeyboardKey.arrowUp => (index - 1) % widget.entries.length,
              LogicalKeyboardKey.home => 0,
              LogicalKeyboardKey.end => widget.entries.length - 1,
              _ => null,
            };
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              controller.hide();
              return KeyEventResult.handled;
            }
            if (next == null) return KeyEventResult.ignored;
            final node = nodes[widget.entries[next].id];
            node?.requestFocus();
            if (node?.context case final context?) {
              Scrollable.ensureVisible(context);
            }
            return KeyEventResult.handled;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in widget.entries)
                  KurumiPopupMenuItem(
                    onTap: () {
                      controller.hide();
                      widget.onSelected(entry.id);
                    },
                    title: Focus(
                      focusNode: nodes.putIfAbsent(entry.id, () => FocusNode()),
                      child: Semantics(
                        selected: entry.id == widget.selectedProfileId,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 32),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: ConfigAwareWebsiteLogo(url: entry.url),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  captions[entry.id]!,
                                  style: style,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (entry.id == widget.selectedProfileId)
                                const Icon(Icons.check, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      child: IconButton(
        focusNode: trigger,
        tooltip: widget.tooltip,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () {
          trigger.requestFocus();
          controller.show();
        },
        icon: current == null
            ? const Icon(Icons.account_circle)
            : SizedBox(
                width: 24,
                height: 24,
                child: ConfigAwareWebsiteLogo(url: current.url),
              ),
      ),
    );
  }
}
