// Package imports:
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import 'providers.dart';

class ChangelogPage extends ConsumerWidget {
  const ChangelogPage({
    super.key,
    required this.dialog,
  });

  final bool dialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullChangelog = ref.watch(fullChangelogProvider);

    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(context.t.settings.changelog),
        automaticallyImplyLeading: !dialog,
        actions: [
          if (dialog)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Symbols.close,
                size: 24,
              ),
            ),
        ],
      ),
      body: fullChangelog.when(
        data: (content) => Markdown(
          data: content,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}
