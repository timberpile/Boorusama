// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../create/create.dart';
import '../../../create/providers.dart';
import '../providers/booru_config_provider.dart';

class UpdateBooruConfigScope extends ConsumerWidget {
  const UpdateBooruConfigScope({
    required this.id,
    required this.child,
    super.key,
  });

  final EditBooruConfigId id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(booruConfigProvider);
    final config = configs.firstWhereOrNull((e) => e.id == id.id);

    if (config == null) {
      return Scaffold(
        appBar: const KurumiAppBar(),
        body: Center(
          child: Text(context.t.generic.no_content),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        editBooruConfigIdProvider.overrideWithValue(id),
        initialBooruConfigProvider.overrideWithValue(config),
      ],
      child: child,
    );
  }
}
