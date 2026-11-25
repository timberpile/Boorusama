import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'local_media_providers.dart';
import 'local_media_reference.dart';

final localMediaStorageUsageProvider =
    FutureProvider.autoDispose<({int bytes, bool canClear})>((ref) async {
      final busy =
          ref.watch(localMediaImportProvider.select((s) => s.running)) ||
          ref.watch(localMediaClearingProvider);
      final android = ref.watch(localMediaAndroidProvider);
      var disposed = false;
      StreamSubscription<LocalMediaReference>? changes;
      ref.onDispose(() {
        disposed = true;
        unawaited(changes?.cancel());
      });
      final library = await ref.watch(localMediaLibraryProvider.future);
      if (disposed || library == null) return (bytes: 0, canClear: false);
      if (!busy) {
        changes = library.changes.listen((_) {
          if (!disposed) ref.invalidateSelf();
        });
      }
      final stored = await library.storageUsage();
      final thumbnails = await android.thumbnailBytes();
      return (
        bytes: stored.bytes + thumbnails,
        canClear: stored.items > 0 || thumbnails > 0,
      );
    });

class LocalMediaStorageSection extends ConsumerWidget {
  const LocalMediaStorageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.local_media;
    final usage = ref.watch(localMediaStorageUsageProvider);
    final importing = ref.watch(
      localMediaImportProvider.select((s) => s.running),
    );
    final clearing = ref.watch(localMediaClearingProvider);
    return KurumiSettingsCard(
      title: t.title,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(t.storage_usage),
        subtitle: usage.when(
          data: (value) => Text(Filesize.parse(value.bytes)),
          loading: () => Text(context.t.settings.data_and_storage.loading),
          error: (_, _) => Text(t.usage_unavailable),
        ),
        trailing: FilledButton(
          onPressed:
              !importing && !clearing && (usage.valueOrNull?.canClear ?? false)
              ? () => unawaited(_confirmClear(context, ref))
              : null,
          child: Text(t.clear_all),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = context.t.local_media;
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return KurumiDialog(
          width: 460,
          screenInset: 16,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 36,
                  color: colors.error,
                ),
                const SizedBox(height: 12),
                Text(t.clear_title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(t.clear_warning),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        autofocus: true,
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.t.generic.action.cancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.error,
                          foregroundColor: colors.onError,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(t.clear_all),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(localMediaClearingProvider.notifier).clear();
    } on Exception {
      if (context.mounted) {
        Kurumi.showErrorToast(context, context.t.local_media.clear_failed);
      }
    }
  }
}
