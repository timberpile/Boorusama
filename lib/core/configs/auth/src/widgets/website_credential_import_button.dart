// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../config/types.dart';
import '../../../create/providers.dart';
import '../pages/website_credential_import_page.dart';
import '../website_credentials.dart';

class WebsiteCredentialImportButton extends ConsumerStatefulWidget {
  const WebsiteCredentialImportButton({
    this.loginController,
    this.apiKeyController,
    this.enabled = true,
    super.key,
  });

  final TextEditingController? loginController;
  final TextEditingController? apiKeyController;
  final bool enabled;

  @override
  ConsumerState<WebsiteCredentialImportButton> createState() =>
      _WebsiteCredentialImportButtonState();
}

class _WebsiteCredentialImportButtonState
    extends ConsumerState<WebsiteCredentialImportButton> {
  var _open = false;

  Future<void> _connect(WebsiteCredentialSite site) async {
    if (_open) return;
    final id = ref.read(editBooruConfigIdProvider);
    final provider = editBooruConfigProvider(id);
    final draft = ref.read(provider);
    final notifier = ref.read(provider.notifier);
    if (WebsiteCredentialSite.forProfile(id.booruType, draft.url) != site) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _open = true);
    try {
      final imported = await Navigator.of(context).push<WebsiteCredentials>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'website_credential_import'),
          builder: (_) => WebsiteCredentialImportPage(
            site: site,
            proxy: draft.proxySettingsTyped,
          ),
        ),
      );
      if (!mounted ||
          imported == null ||
          ref.read(editBooruConfigIdProvider) != id) {
        return;
      }

      if (!identical(ref.read(provider.notifier), notifier) ||
          _credentialsOf(ref.read(provider)) != _credentialsOf(draft)) {
        return;
      }
      notifier.updateWebsiteCredentials(
        login: imported.login,
        apiKey: imported.apiKey,
        passHash: imported.passHash,
      );
      widget.loginController?.text = imported.login;
      widget.apiKeyController?.text = imported.apiKey;
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(editBooruConfigIdProvider);
    final (url, login, key, session) = ref.watch(
      editBooruConfigProvider(id).select(_credentialsOf),
    );
    final site = WebsiteCredentialSite.forProfile(id.booruType, url);
    if (site == null) return const SizedBox.shrink();

    final hasCredentials =
        (!site.importsLogin || login.trim().isNotEmpty) &&
        ((site.importsKey && key.trim().isNotEmpty) ||
            (site.importsSession && (session?.trim().isNotEmpty ?? false)));
    final text = context.t.booru.authentication.website_import;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: FilledButton(
          onPressed: _open || !widget.enabled ? null : () => _connect(site),
          child: Text(hasCredentials ? context.t.auth.relogin : text.login),
        ),
      ),
    );
  }
}

(String, String, String, String?) _credentialsOf(BooruConfigData draft) =>
    (draft.url, draft.login, draft.apiKey, draft.passHash);
