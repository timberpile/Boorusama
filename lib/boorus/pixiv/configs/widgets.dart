// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/create/providers.dart';
import '../../../core/configs/create/widgets.dart';
import '../../../core/http/client/providers.dart';
import '../auth/auth_interceptor.dart';
import '../auth/login_page.dart';
import '../client_provider.dart';
import 'experimental_notice.dart';
import 'extra_data.dart';

class CreatePixivConfigPage extends ConsumerWidget {
  const CreatePixivConfigPage({
    super.key,
    this.backgroundColor,
    this.initialTab,
  });

  final Color? backgroundColor;
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CreateBooruConfigScaffold(
      backgroundColor: backgroundColor,
      initialTab: initialTab,
      authTab: const PixivAuthConfigView(),
    );
  }
}

/// Pixiv has no anonymous mode, so this tab is the only way to a working
/// profile. It offers two routes to the same stored credential: the OAuth
/// login webview (Android/iOS only — `webview_flutter` has no desktop or web
/// implementation) and pasting a refresh token, which works everywhere.
class PixivAuthConfigView extends ConsumerWidget {
  const PixivAuthConfigView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configId = ref.watch(editBooruConfigIdProvider);
    final configData = ref.watch(editBooruConfigProvider(configId));
    final extraData = PixivExtraData.fromPassHash(configData.passHash);
    final isLoggedIn =
        configData.apiKey.isNotEmpty &&
        (int.tryParse(extraData.userId ?? '') ?? 0) > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const PixivExperimentalNotice(),
          const SizedBox(height: 16),
          if (isLoggedIn) ...[
            _LoggedInStatus(extraData: extraData),
            const SizedBox(height: 16),
          ],
          if (isPixivWebViewLoginSupported)
            FilledButton(
              onPressed: () => _login(context, ref),
              child: Text(
                isLoggedIn ? context.t.auth.relogin : context.t.auth.login,
              ),
            )
          else
            DefaultBooruInstructionText(
              context.t.pixiv.auth.webview_unsupported,
            ),
          const SizedBox(height: 24),
          const _RefreshTokenField(),
          if (configData.apiKey.isNotEmpty && !isLoggedIn) ...[
            const SizedBox(height: 8),
            _ManualTokenVerification(key: ValueKey(configId)),
          ],
          const SizedBox(height: 8),
          DefaultBooruInstructionText(
            context.t.pixiv.auth.paste_token_hint,
          ),
          const SizedBox(height: 24),
          KurumiWarningContainer(
            title: context.t.generic.warning,
            contentBuilder: (context) => Text(
              context.t.pixiv.auth.credential_export_warning,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _login(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PixivLoginPage(
          onSuccess: (tokens) => _store(ref, tokens),
        ),
      ),
    );
  }

  void _store(WidgetRef ref, PixivTokens tokens) {
    _storePixivTokens(ref, tokens);
  }
}

void _storePixivTokens(WidgetRef ref, PixivTokens tokens) {
  final refreshToken = tokens.refreshToken;
  if (refreshToken == null || refreshToken.isEmpty) return;
  final user = tokens.user;
  final extraData = PixivExtraData.fromTokenResponse(
    userId: user?.id,
    userName: user?.name,
    isPremium: user?.isPremium,
    xRestrict: user?.xRestrict,
    expiresIn: tokens.expiresIn,
  );
  ref.editNotifier
    ..updateLogin(user?.account ?? '')
    ..updateApiKey(refreshToken)
    ..updatePassHash(extraData.toPassHash());
}

class _ManualTokenVerification extends ConsumerStatefulWidget {
  const _ManualTokenVerification({super.key});

  @override
  ConsumerState<_ManualTokenVerification> createState() =>
      _ManualTokenVerificationState();
}

class _ManualTokenVerificationState
    extends ConsumerState<_ManualTokenVerification> {
  var _verifying = false;
  var _failed = false;
  var _generation = 0;

  Future<void> _verify() async {
    final editId = ref.read(editBooruConfigIdProvider);
    final token = ref.read(editBooruConfigProvider(editId)).apiKey;
    final generation = ++_generation;
    setState(() {
      _verifying = true;
      _failed = false;
    });
    bool isCurrent() =>
        mounted &&
        generation == _generation &&
        ref.read(editBooruConfigIdProvider) == editId &&
        ref.read(editBooruConfigProvider(editId)).apiKey == token;
    try {
      final registry = ref.read(apiAuthRefreshRegistryProvider);
      final tokens = await registry.run(
        ('pixiv', registry.opaqueCredentialIdentity(token)),
        () =>
            createPixivAuthClient(dio: ref.read(pixivOAuthDioProvider))
                .refresh(refreshToken: token),
      );
      if (!isCurrent()) return;
      if ((tokens.accessToken?.isEmpty ?? true) ||
          (tokens.refreshToken?.isEmpty ?? true) ||
          (int.tryParse(tokens.user?.id ?? '') ?? 0) <= 0) {
        setState(() => _failed = true);
        return;
      }
      // Use the same paired credential/identity writer as OAuth login. Only
      // the still-current draft may consume this explicit verification.
      _storePixivTokens(ref, tokens);
    } catch (_) {
      if (isCurrent()) setState(() => _failed = true);
    } finally {
      if (isCurrent()) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editId = ref.watch(editBooruConfigIdProvider);
    ref.listen(editBooruConfigProvider(editId).select((data) => data.apiKey), (
      _,
      _,
    ) {
      _generation++;
      setState(() {
        _verifying = false;
        _failed = false;
      });
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('pixiv-verify-manual-token'),
          onPressed: _verifying ? null : _verify,
          icon: _verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(context.t.generic.action.verify),
        ),
        if (_failed) Text(context.t.pixiv.auth.login_failed),
      ],
    );
  }
}

class _LoggedInStatus extends ConsumerWidget {
  const _LoggedInStatus({
    required this.extraData,
  });

  final PixivExtraData extraData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = extraData.userName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Kurumi.themeOf(context).colorScheme.primary,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  userName == null
                      ? context.t.auth.logged_in
                      : '${context.t.auth.logged_in}: $userName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              KurumiMaterialRawChip(
                backgroundColor: Kurumi.themeOf(
                  context,
                ).colorScheme.secondaryContainer,
                onPressed: () {
                  ref.editNotifier
                    ..updateApiKey('')
                    ..updateLogin('')
                    ..updatePassHash(null);
                },
                label: Text(context.t.auth.clear_credentials),
              ),
            ],
          ),
          if (extraData.isPremium ?? false) ...[
            const SizedBox(height: 4),
            Text(
              context.t.pixiv.auth.premium_account,
              style: Kurumi.themeOf(context).textTheme.bodySmall?.copyWith(
                color: Kurumi.themeOf(context).colorScheme.hintColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The refresh token, obscured with a reveal toggle. This is the credential
/// itself, so it is never rendered in plain text by default and the hint
/// warns against pasting one from anywhere but Pixiv.
class _RefreshTokenField extends ConsumerStatefulWidget {
  const _RefreshTokenField();

  @override
  ConsumerState<_RefreshTokenField> createState() => _RefreshTokenFieldState();
}

class _RefreshTokenFieldState extends ConsumerState<_RefreshTokenField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref
          .read(editBooruConfigProvider(ref.read(editBooruConfigIdProvider)))
          .apiKey,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configId = ref.watch(editBooruConfigIdProvider);

    // Keeps the field in step with a token obtained through the login
    // webview, or cleared from the status card above.
    ref.listen(
      editBooruConfigProvider(configId).select((value) => value.apiKey),
      (_, next) {
        if (_controller.text != next) {
          _controller.text = next;
        }
      },
    );

    return CreateBooruApiKeyField(
      controller: _controller,
      labelText: context.t.pixiv.auth.refresh_token_label,
      onChanged: (value) {
        if (value == ref.read(editBooruConfigProvider(configId)).apiKey) return;

        // A manually entered credential has no verified account identity.
        // Clear the old identity before publishing the new token. Changes
        // from the OAuth callback only update the controller, not onChanged.
        ref.editNotifier
          ..updatePassHash(null)
          ..updateLogin('')
          ..updateApiKey(value);
      },
    );
  }
}
