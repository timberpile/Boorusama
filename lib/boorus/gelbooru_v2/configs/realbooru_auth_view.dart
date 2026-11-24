// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/src/website_credentials.dart';
import '../../../core/configs/auth/src/widgets/website_credential_import_button.dart';
import '../../../core/configs/create/providers.dart';
import '../../../foundation/browser/providers.dart';

class RealbooruAuthView extends ConsumerStatefulWidget {
  const RealbooruAuthView({super.key});

  @override
  ConsumerState<RealbooruAuthView> createState() => _RealbooruAuthViewState();
}

class _RealbooruAuthViewState extends ConsumerState<RealbooruAuthView> {
  var _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    final editId = ref.read(editBooruConfigIdProvider);
    final provider = editBooruConfigProvider(editId);
    final draft = ref.read(provider);
    if (WebsiteCredentialSite.forProfile(editId.booruType, draft.url) !=
        WebsiteCredentialSite.realbooru) {
      return;
    }
    final notifier = ref.read(provider.notifier);
    setState(() => _loggingOut = true);
    try {
      final signedOut = await signOutRealbooruBrowser(
        ref.read(embeddedBrowserFactoryProvider),
        userId: draft.login.trim(),
      );
      if (!mounted || ref.read(editBooruConfigIdProvider) != editId) return;
      final current = ref.read(provider);
      if (!identical(ref.read(provider.notifier), notifier) ||
          current.url != draft.url ||
          current.login != draft.login ||
          current.apiKey != draft.apiKey ||
          current.passHash != draft.passHash) {
        return;
      }
      if (!signedOut) {
        _showFailure();
        return;
      }
      notifier.updateWebsiteCredentials(login: '', apiKey: '', passHash: null);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  void _showFailure() => Kurumi.showErrorToast(
    context,
    context.t.booru.authentication.website_import.logout_failed,
  );

  @override
  Widget build(BuildContext context) {
    final editId = ref.watch(editBooruConfigIdProvider);
    final (userId, session) = ref.watch(
      editBooruConfigProvider(editId).select(
        (draft) => (draft.login.trim(), draft.passHash?.trim()),
      ),
    );
    final hasSession = userId.isNotEmpty && (session?.isNotEmpty ?? false);
    final text = context.t.booru.authentication.website_import;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            if (hasSession) ...[
              Text(
                context.t.auth.logged_in,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(text.user_id(id: userId), textAlign: TextAlign.center),
            ],
            WebsiteCredentialImportButton(enabled: !_loggingOut),
            if (hasSession)
              OutlinedButton(
                onPressed: _loggingOut ? null : _logout,
                child: Text(_loggingOut ? text.logging_out : text.logout),
              ),
          ],
        ),
      ),
    );
  }
}
