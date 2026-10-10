// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../config/types.dart';
import '../../../create/providers.dart';
import '../widgets/theme_section.dart';

class ThemeConfigsPage extends ConsumerWidget {
  const ThemeConfigsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(
      editBooruConfigProvider(
        ref.watch(editBooruConfigIdProvider),
      ).select((value) => value.themeTyped),
    );

    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(context.t.settings.theme.theme),
      ),
      body: ThemeSection(
        theme: theme,
        onThemeUpdated: (theme) {
          ref.editNotifier.updateTheme(theme);
          Kurumi.showSimpleSnackBar(
            context: context,
            duration: const Duration(seconds: 3),
            content: Text(
              'Your theme will be applied when you save this profile'.hc,
            ),
          );
        },
      ),
    );
  }
}
