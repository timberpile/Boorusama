import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:path/path.dart' as p;

import '../data/providers.dart';

class SidecarFailureNotice extends ConsumerStatefulWidget {
  const SidecarFailureNotice({super.key});

  @override
  ConsumerState<SidecarFailureNotice> createState() =>
      _SidecarFailureNoticeState();
}

class _SidecarFailureNoticeState extends ConsumerState<SidecarFailureNotice>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native background callbacks may have persisted failures in another isolate.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(sidecarFailuresProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failures = ref.watch(sidecarFailuresProvider).valueOrNull;
    if (failures == null || failures.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.warning_amber),
      title: Text(
        '${context.t.settings.download.sidecar.failures_title} (${failures.length})',
      ),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const SidecarFailuresPage()),
      ),
    );
  }
}

class SidecarFailuresPage extends ConsumerStatefulWidget {
  const SidecarFailuresPage({super.key});

  @override
  ConsumerState<SidecarFailuresPage> createState() =>
      _SidecarFailuresPageState();
}

class _SidecarFailuresPageState extends ConsumerState<SidecarFailuresPage> {
  final _retrying = <String>{};
  var _failed = false;

  Future<void> _retry(String id) async {
    if (!_retrying.add(id)) return;
    setState(() => _failed = false);
    try {
      final store = await ref.read(sidecarStoreProvider.future);
      await store.retry(id);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _retrying.remove(id);
      if (mounted) {
        ref.invalidate(sidecarFailuresProvider);
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.download.sidecar;
    return Scaffold(
      appBar: KurumiAppBar(title: Text(strings.failures_title)),
      body: SafeArea(
        child: ref
            .watch(sidecarFailuresProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(strings.retry_failed_error)),
              data: (failures) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(strings.failures_description),
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(strings.retry_failed_error),
                    ),
                  for (final failure in failures)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.basename(failure.path)),
                      trailing: IconButton(
                        tooltip: context.t.generic.action.retry,
                        onPressed: _retrying.contains(failure.id)
                            ? null
                            : () => _retry(failure.id),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}
