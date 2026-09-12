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
import '../auth/login_page.dart';
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
    final isLoggedIn = configData.apiKey.isNotEmpty;
    final extraData = PixivExtraData.fromPassHash(configData.passHash);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
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
      onChanged: (value) => ref.editNotifier.updateApiKey(value),
    );
  }
}
