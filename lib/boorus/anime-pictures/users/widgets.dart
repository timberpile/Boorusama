// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import 'providers.dart';

class AnimePicturesCurrentUserIdScope extends ConsumerWidget {
  const AnimePicturesCurrentUserIdScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(animePicturesCurrentUserIdProvider(ref.watchConfigAuth))
        .when(
          data: (value) => value != null
              ? ProviderScope(
                  overrides: [
                    uidProvider.overrideWithValue(value),
                  ],
                  child: child,
                )
              : _buildInvalidPage(context),
          loading: () => const Scaffold(
            appBar: KurumiAppBar(),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => _buildInvalidPage(context),
        );
  }

  Widget _buildInvalidPage(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(context.t.auth.login_required),
      ),
    );
  }
}
