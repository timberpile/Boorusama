import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../configs/config/providers.dart';
import '../configs/config/types.dart';
import '../configs/manage/providers.dart';
import 'destination_profile_scope.dart';
import 'page_source_context.dart';

/// Global actions choose their own source. Merely opening this picker never
/// changes Browse, Favorites, or any persisted account preference.
Future<BooruConfig?> chooseOperationSource(WidgetRef ref) async {
  if (DestinationScope.maybeOf(ref.context) == null ||
      ref.read(explicitPageSourceProvider) != null) {
    return ref.readConfig;
  }
  final profiles = ref.read(booruConfigProvider);
  final id = await showDialog<String>(
    context: ref.context,
    builder: (context) => KurumiDialog(
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.t.navigation.choose_profile),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final profile in profiles)
                    ListTile(
                      title: Text(profile.name),
                      subtitle: Text(
                        Uri.tryParse(profile.url)?.host ?? profile.url,
                      ),
                      onTap: () => Navigator.pop(context, profile.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (!ref.context.mounted || id == null) return null;
  return ref.read(booruConfigProvider).where((c) => c.id == id).firstOrNull;
}
