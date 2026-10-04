import 'package:kurumi/material.dart';

class SharePayloadTile extends StatelessWidget {
  const SharePayloadTile({
    required this.title,
    required this.value,
    required this.unavailable,
    required this.copyTooltip,
    required this.shareTooltip,
    super.key,
    this.description,
    this.leading,
    this.deferred = false,
    this.showValue = true,
    this.reserveDescriptionSpace = false,
    this.onCopy,
    this.onShare,
    this.busy = false,
  });

  final Widget? leading;
  final String title;
  final String? value;
  final String? description;
  final bool deferred;
  final bool reserveDescriptionSpace;
  final bool showValue;
  final String unavailable;
  final String copyTooltip;
  final String shareTooltip;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = value != null || deferred;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(
                width: 24,
                height: 24,
                child: leading,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  if (!available ||
                      showValue ||
                      description != null ||
                      reserveDescriptionSpace)
                    Text(
                      !available
                          ? unavailable
                          : description ?? (showValue ? value ?? '' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: available
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.disabledColor,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: copyTooltip,
              icon: const Icon(Icons.content_copy),
              onPressed: available && !busy ? onCopy : null,
            ),
            IconButton(
              tooltip: shareTooltip,
              icon: const Icon(Icons.share),
              onPressed: available && !busy ? onShare : null,
            ),
          ],
        ),
      ),
    );
  }
}
